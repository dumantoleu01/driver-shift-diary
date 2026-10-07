from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from shift_diary.api import create_app
from shift_diary.config import Settings
from shift_diary.storage import TripStore

SAMPLE = Path(__file__).resolve().parents[2] / "data" / "trips.json"

#: Первая поездка из текста задания.
T1: dict[str, Any] = {
    "id": "t1",
    "start": "2026-10-01T08:10:00+05:00",
    "end": "2026-10-01T08:32:00+05:00",
    "amount": 2400,
    "payment": "card",
    "commission": 360,
}


def trip(**changes: Any) -> dict[str, Any]:
    return {**T1, **changes}


def without(field: str) -> dict[str, Any]:
    return {key: value for key, value in T1.items() if key != field}


@pytest.fixture
def app(tmp_path: Path) -> FastAPI:
    """Сервер с пустой базой."""
    return create_app(Settings(db_path=tmp_path / "trips.sqlite3", seed_path=None))


@pytest.fixture
def client(app: FastAPI) -> TestClient:
    return TestClient(app)


@pytest.fixture
def sample(tmp_path: Path) -> TestClient:
    """Сервер с образцом данных из репозитория."""
    return TestClient(create_app(Settings(db_path=tmp_path / "trips.sqlite3", seed_path=SAMPLE)))


def day(client: TestClient, date: str = "2026-10-01") -> dict[str, Any]:
    response = client.get(f"/api/days/{date}")
    assert response.status_code == 200
    body: dict[str, Any] = response.json()
    return body


# --- сводка и список за день ------------------------------------------------------------------


def test_day_with_cash_and_card(sample: TestClient) -> None:
    body = day(sample, "2026-10-01")

    assert body["date"] == "2026-10-01"
    assert body["summary"] == {
        "trips": 6,
        "revenue": 17000,
        "commission": 2550,
        "net": 14450,
        "by_payment": {
            "cash": {"trips": 2, "amount": 4700},
            "card": {"trips": 4, "amount": 12300},
        },
    }
    assert [item["id"] for item in body["trips"]] == ["t14", "t1", "t2", "t15", "t16", "t17"]


def test_trip_is_returned_as_in_assignment(sample: TestClient) -> None:
    """Поездка из задания возвращается в том же виде, в каком лежит в файле."""
    trips = {item["id"]: item for item in day(sample)["trips"]}

    assert trips["t1"] == T1


def test_trip_just_after_midnight_is_in_the_new_day(sample: TestClient) -> None:
    """t14 началась в 00:35 1 октября; по UTC это ещё 30 сентября."""
    assert "t14" in [item["id"] for item in day(sample, "2026-10-01")["trips"]]
    assert "t14" not in [item["id"] for item in day(sample, "2026-09-30")["trips"]]


def test_trip_over_midnight_is_counted_once_on_start_day(sample: TestClient) -> None:
    """t13 шла с 23:48 до 00:14: вся её сумма в 30 сентября, в 1 октября её нет."""
    eve = day(sample, "2026-09-30")

    assert eve["trips"][-1]["id"] == "t13"
    assert eve["trips"][-1]["end"] == "2026-10-01T00:14:00+05:00"
    assert eve["summary"] == {
        "trips": 6,
        "revenue": 14500,
        "commission": 2175,
        "net": 12325,
        "by_payment": {
            "cash": {"trips": 3, "amount": 6100},
            "card": {"trips": 3, "amount": 8400},
        },
    }
    assert "t13" not in [item["id"] for item in day(sample, "2026-10-01")["trips"]]


def test_cash_only_day(sample: TestClient) -> None:
    summary = day(sample, "2026-10-03")["summary"]

    assert summary["net"] == 9500 - 1425
    assert summary["by_payment"] == {
        "cash": {"trips": 4, "amount": 9500},
        "card": {"trips": 0, "amount": 0},
    }


def test_empty_day_is_zeros_not_an_error(sample: TestClient) -> None:
    assert day(sample, "2026-10-02") == {
        "date": "2026-10-02",
        "summary": {
            "trips": 0,
            "revenue": 0,
            "commission": 0,
            "net": 0,
            "by_payment": {
                "cash": {"trips": 0, "amount": 0},
                "card": {"trips": 0, "amount": 0},
            },
        },
        "trips": [],
    }


def test_summary_always_matches_the_list(sample: TestClient) -> None:
    """Сводка сходится со списком, который пришёл в том же ответе, — для каждого дня."""
    for entry in sample.get("/api/days").json()["days"]:
        body = day(sample, entry["date"])
        trips, summary = body["trips"], body["summary"]

        assert summary["trips"] == len(trips) == entry["trips"]
        assert summary["revenue"] == sum(item["amount"] for item in trips)
        assert summary["commission"] == sum(item["commission"] for item in trips)
        assert summary["net"] == summary["revenue"] - summary["commission"]
        for payment in ("cash", "card"):
            paid = [item for item in trips if item["payment"] == payment]
            assert summary["by_payment"][payment] == {
                "trips": len(paid),
                "amount": sum(item["amount"] for item in paid),
            }


@pytest.mark.parametrize(
    "date",
    [
        "2026-13-01",
        "2026-02-30",
        "2026-10-1",
        "20261001",
        "01.10.2026",
        "today",
        "1999-12-30",
        "2100-01-02",
    ],
)
def test_bad_date_is_400(client: TestClient, date: str) -> None:
    response = client.get(f"/api/days/{date}")

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_date"


@pytest.mark.parametrize(
    ("offset", "start", "day"),
    [
        ("+05:00", "2099-12-31T23:00:00Z", "2100-01-01"),
        ("-05:00", "2000-01-01T00:00:00Z", "1999-12-31"),
    ],
)
def test_day_of_any_accepted_trip_can_be_opened(
    tmp_path: Path, offset: str, start: str, day: str
) -> None:
    """Поездка на краю допустимых дат попадает в соседний день — он тоже должен открываться."""
    client = TestClient(
        create_app(Settings(db_path=tmp_path / "t.sqlite3", seed_path=None, utc_offset=offset))
    )
    end = start.replace(":00:00Z", ":20:00Z")
    assert client.post("/api/trips", json=trip(start=start, end=end)).status_code == 201

    [listed] = client.get("/api/days").json()["days"]
    opened = client.get(f"/api/days/{listed['date']}")

    assert listed["date"] == day
    assert opened.status_code == 200
    assert opened.json()["summary"]["trips"] == 1


def test_out_of_range_date_says_so(client: TestClient) -> None:
    """Верно записанная дата вне диапазона — не «неверный формат»."""
    message = client.get("/api/days/2100-01-02").json()["error"]["message"]

    assert "от 1999-12-31 до 2100-01-01" in message


# --- список дней ----------------------------------------------------------------------------


def test_days_with_trips(sample: TestClient) -> None:
    """Пустого 2 октября в списке нет; t13 и t14 посчитаны в своих днях."""
    assert sample.get("/api/days").json() == {
        "utc_offset": "+05:00",
        "days": [
            {"date": "2026-09-29", "trips": 5},
            {"date": "2026-09-30", "trips": 6},
            {"date": "2026-10-01", "trips": 6},
            {"date": "2026-10-03", "trips": 4},
            {"date": "2026-10-04", "trips": 6},
        ],
    }


def test_no_days_without_trips(client: TestClient) -> None:
    assert client.get("/api/days").json() == {"utc_offset": "+05:00", "days": []}


def test_restart_does_not_double_the_sample(tmp_path: Path) -> None:
    settings = Settings(db_path=tmp_path / "trips.sqlite3", seed_path=SAMPLE)
    before = TestClient(create_app(settings)).get("/api/days").json()

    after = TestClient(create_app(settings)).get("/api/days").json()

    assert after == before


# --- добавление поездки ---------------------------------------------------------------------


def test_new_trip_is_created(client: TestClient) -> None:
    response = client.post("/api/trips", json=T1)

    assert response.status_code == 201
    assert response.json() == T1
    assert day(client)["trips"] == [T1]


def test_trip_without_id_gets_one(client: TestClient) -> None:
    response = client.post("/api/trips", json=without("id"))

    assert response.status_code == 201
    assert response.json()["id"]


def test_time_sent_in_utc_comes_back_in_service_zone(client: TestClient) -> None:
    """Клиент может прислать время в любом поясе — день и показ всё равно по поясу сервиса."""
    response = client.post(
        "/api/trips",
        json=trip(start="2026-09-30T19:35:00Z", end="2026-09-30T19:58:00Z"),
    )

    assert response.status_code == 201
    assert response.json()["start"] == "2026-10-01T00:35:00+05:00"
    assert len(day(client, "2026-10-01")["trips"]) == 1
    assert day(client, "2026-09-30")["trips"] == []


def test_zone_comes_from_settings(tmp_path: Path) -> None:
    """При поясе +06:00 поездка в 23:30 (+05:00) относится уже к следующему дню."""
    client = TestClient(
        create_app(Settings(db_path=tmp_path / "t.sqlite3", seed_path=None, utc_offset="+06:00"))
    )
    client.post(
        "/api/trips", json=trip(start="2026-10-01T23:30:00+05:00", end="2026-10-01T23:50:00+05:00")
    )

    [stored] = day(client, "2026-10-02")["trips"]
    assert stored["start"] == "2026-10-02T00:30:00+06:00"
    assert client.get("/api/days").json()["utc_offset"] == "+06:00"


# --- защита от дублей -----------------------------------------------------------------------


def test_repeat_does_not_create_a_duplicate(client: TestClient) -> None:
    """Главное требование: повторная отправка той же поездки не создаёт дубль."""
    first = client.post("/api/trips", json=T1)
    summary_after_first = day(client)["summary"]

    second = client.post("/api/trips", json=T1)

    assert (first.status_code, second.status_code) == (201, 200)
    assert second.json() == first.json()
    assert day(client)["trips"] == [T1]
    assert day(client)["summary"] == summary_after_first


def test_repeat_without_id_does_not_create_a_duplicate(client: TestClient) -> None:
    """Тот же JSON без `id`, отправленный дважды, — одна поездка с одним `id`."""
    first = client.post("/api/trips", json=without("id"))
    second = client.post("/api/trips", json=without("id"))

    assert (first.status_code, second.status_code) == (201, 200)
    assert second.json()["id"] == first.json()["id"]
    assert day(client)["summary"]["trips"] == 1


def test_repeat_under_new_id_returns_the_first_record(client: TestClient) -> None:
    client.post("/api/trips", json=T1)

    again = client.post("/api/trips", json=trip(id="another-id"))

    assert again.status_code == 200
    assert again.json()["id"] == "t1"
    assert day(client)["summary"]["trips"] == 1


def test_repeat_with_time_in_other_notation_is_still_a_repeat(client: TestClient) -> None:
    client.post("/api/trips", json=T1)

    again = client.post(
        "/api/trips", json=trip(start="2026-10-01T03:10:00Z", end="2026-10-01T03:32:00Z")
    )

    assert again.status_code == 200
    assert day(client)["summary"]["trips"] == 1


def test_same_id_with_other_content_is_409(client: TestClient) -> None:
    """Под занятым `id` нельзя ни завести вторую поездку, ни переписать первую."""
    client.post("/api/trips", json=T1)

    response = client.post("/api/trips", json=trip(amount=9900))

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "id_conflict"
    assert day(client)["trips"] == [T1]


def test_simultaneous_repeats_create_one_trip(app: FastAPI) -> None:
    """Двадцать одновременных запросов с одной поездкой: один `201`, остальные `200`."""
    rivals = 20
    barrier = Barrier(rivals)

    def send(_: int) -> int:
        # У каждого потока свой клиент — запросы действительно идут параллельно.
        client = TestClient(app)
        barrier.wait()
        return client.post("/api/trips", json=T1).status_code

    with ThreadPoolExecutor(max_workers=rivals) as pool:
        statuses = list(pool.map(send, range(rivals)))

    assert sorted(statuses) == [200] * (rivals - 1) + [201]
    assert day(TestClient(app))["summary"] == {
        "trips": 1,
        "revenue": 2400,
        "commission": 360,
        "net": 2040,
        "by_payment": {"cash": {"trips": 0, "amount": 0}, "card": {"trips": 1, "amount": 2400}},
    }


# --- проверка данных ------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("body", "field", "code"),
    [
        # Правила из задания.
        (trip(amount=0), "amount", "must_be_positive"),
        (trip(amount=-100, commission=0), "amount", "must_be_positive"),
        (trip(end=T1["start"]), "end", "must_be_after_start"),
        (trip(end="2026-10-01T08:09:59+05:00"), "end", "must_be_after_start"),
        (trip(end="2026-10-01T09:00:00+06:00"), "end", "must_be_after_start"),
        # Сумма и комиссия — только целые числа, без молчаливого приведения.
        (trip(amount="2400"), "amount", "invalid_type"),
        (trip(amount=2400.5), "amount", "invalid_type"),
        (trip(amount=2400.0), "amount", "invalid_type"),
        (trip(amount=True), "amount", "invalid_type"),
        (trip(amount=None), "amount", "invalid_type"),
        (without("amount"), "amount", "required"),
        (trip(amount=10**12), "amount", "too_large"),
        (trip(commission="360"), "commission", "invalid_type"),
        (trip(commission=-1), "commission", "must_not_be_negative"),
        (trip(commission=2401), "commission", "must_not_exceed_amount"),
        (without("commission"), "commission", "required"),
        # Время — строка ISO 8601 со смещением.
        (trip(start="2026-10-01T08:10:00"), "start", "offset_required"),
        (trip(start="2026-10-01"), "start", "offset_required"),
        (trip(start="вчера"), "start", "invalid_datetime"),
        (trip(start="2026-13-45T08:10:00+05:00"), "start", "invalid_datetime"),
        (trip(start=1759300000), "start", "invalid_type"),
        (trip(start="1759300000"), "start", "invalid_datetime"),
        (trip(start="0001-01-01T00:00:00+05:00"), "start", "out_of_range"),
        (trip(end="9999-12-31T23:59:59-12:00"), "end", "out_of_range"),
        (trip(end="2026-10-03T08:10:00+05:00"), "end", "too_long"),
        (without("start"), "start", "required"),
        (without("end"), "end", "required"),
        # Оплата — только cash или card.
        (trip(payment="bitcoin"), "payment", "invalid_value"),
        (trip(payment="CASH"), "payment", "invalid_value"),
        (trip(payment=1), "payment", "invalid_value"),
        (without("payment"), "payment", "required"),
        # id — короткая строка без пробелов.
        (trip(id=""), "id", "invalid_value"),
        (trip(id="два слова"), "id", "invalid_value"),
        (trip(id="x" * 65), "id", "invalid_value"),
        (trip(id=42), "id", "invalid_type"),
    ],
)
def test_bad_trip_is_422_and_not_stored(
    client: TestClient, body: dict[str, Any], field: str, code: str
) -> None:
    response = client.post("/api/trips", json=body)

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "validation_failed"
    assert error["fields"] == {field: code}
    assert client.get("/api/days").json()["days"] == []


@pytest.mark.parametrize(
    "body",
    [
        trip(commission=0),
        trip(commission=2400),
        trip(amount=1, commission=0),
        trip(end="2026-10-01T08:10:01+05:00"),
        trip(id="550e8400-e29b-41d4-a716-446655440000"),
        trip(id=None),
        trip(start="2026-10-01T08:10:00.250+05:00"),
    ],
    ids=[
        "без комиссии",
        "комиссия равна сумме",
        "сумма 1",
        "одна секунда",
        "uuid",
        "id null",
        "доли секунды",
    ],
)
def test_edge_but_valid_trip_is_accepted(client: TestClient, body: dict[str, Any]) -> None:
    assert client.post("/api/trips", json=body).status_code == 201


def test_all_problems_are_reported_at_once(client: TestClient) -> None:
    response = client.post("/api/trips", json=trip(end=T1["start"], amount=0, commission=-5))

    assert response.json()["error"]["fields"] == {
        "end": "must_be_after_start",
        "amount": "must_be_positive",
        "commission": "must_not_be_negative",
    }


def test_unknown_fields_are_ignored(client: TestClient) -> None:
    """Лишнее поле не мешает: клиент новой версии может прислать больше, чем знает сервер."""
    response = client.post("/api/trips", json=trip(tips=500))

    assert response.status_code == 201
    assert response.json() == T1


@pytest.mark.parametrize(
    ("request_kwargs", "code"),
    [
        ({"content": "{oops", "headers": {"content-type": "application/json"}}, "invalid_json"),
        ({"content": "", "headers": {"content-type": "application/json"}}, "invalid_body"),
        ({"json": [T1]}, "invalid_body"),
        ({"json": "поездка"}, "invalid_body"),
        ({"content": "null", "headers": {"content-type": "application/json"}}, "invalid_body"),
        ({"content": '{"amount": 1}', "headers": {"content-type": "text/plain"}}, "invalid_body"),
        ({"data": {"amount": "2400"}}, "invalid_body"),
    ],
    ids=["битый json", "пустое тело", "массив", "строка", "null", "text/plain", "форма"],
)
def test_malformed_request_is_400(
    client: TestClient, request_kwargs: dict[str, Any], code: str
) -> None:
    response = client.post("/api/trips", **request_kwargs)

    assert response.status_code == 400
    assert response.json()["error"]["code"] == code


# --- прочее ---------------------------------------------------------------------------------


def test_unknown_address_uses_the_same_error_format(client: TestClient) -> None:
    response = client.get("/api/nope")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_wrong_method_uses_the_same_error_format(client: TestClient) -> None:
    response = client.delete("/api/trips")

    assert response.status_code == 405
    assert response.json()["error"]["code"] == "method_not_allowed"


def test_unexpected_failure_is_500_without_internals(
    app: FastAPI, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Сбой внутри сервера — тот же формат ошибки; текст исключения наружу не уходит."""

    def broken(_: TripStore) -> list[object]:
        raise RuntimeError("секретный путь /var/lib/trips.sqlite3")

    monkeypatch.setattr(TripStore, "starts", broken)

    response = TestClient(app, raise_server_exceptions=False).get("/api/days")

    assert response.status_code == 500
    assert response.json() == {
        "error": {"code": "internal_error", "message": "Внутренняя ошибка сервера"}
    }


def test_health(client: TestClient) -> None:
    assert client.get("/health").json() == {"status": "ok"}


def test_openapi_describes_the_trip_body(client: TestClient) -> None:
    """Страница /docs показывает тело запроса — поездку можно отправить прямо из браузера."""
    schema = client.get("/openapi.json").json()

    body = schema["paths"]["/api/trips"]["post"]["requestBody"]["content"]["application/json"]
    assert body["schema"] == {"$ref": "#/components/schemas/TripPayload"}
    assert set(schema["components"]["schemas"]["TripPayload"]["required"]) == {
        "start",
        "end",
        "amount",
        "payment",
        "commission",
    }
