import sqlite3
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path
from threading import Barrier

import pytest

from shift_diary.domain.day import day_bounds
from shift_diary.domain.driver import DEFAULT_DRIVER
from shift_diary.domain.trip import Payment, Trip
from shift_diary.storage import AddOutcome, AddResult, TripStore
from tests.helpers import SERVICE_ZONE, at, ride

#: Сколько одновременных отправок изображают «клиент повторил запрос, пока первый ещё шёл».
RIVALS = 20

#: Водитель, от имени которого работает большинство тестов, и второй — для проверки границ.
ME = "driver-me"
OTHER = "driver-other"


@pytest.fixture
def store(tmp_path: Path) -> TripStore:
    return TripStore(tmp_path / "trips.sqlite3")


def stored_ids(store: TripStore, day: date = date(2026, 10, 1), *, driver: str = ME) -> list[str]:
    return [trip.id for trip in store.starting_between(driver, *day_bounds(day, SERVICE_ZONE))]


# --- добавление -----------------------------------------------------------------------------


def test_new_trip_is_created_and_readable(store: TripStore) -> None:
    trip = ride(id="t1")

    result = store.add(ME, trip)

    assert result.outcome is AddOutcome.CREATED
    [stored] = store.starting_between(ME, *day_bounds(date(2026, 10, 1), SERVICE_ZONE))
    assert stored == trip


def test_time_survives_storage_to_the_microsecond(store: TripStore) -> None:
    trip = ride("2026-10-01T08:10:00.123456+05:00", "2026-10-01T08:32:00.654321+05:00")

    store.add(ME, trip)

    [stored] = store.starting_between(ME, *day_bounds(date(2026, 10, 1), SERVICE_ZONE))
    assert stored.start == trip.start
    assert stored.end == trip.end


def test_trips_survive_restart(tmp_path: Path) -> None:
    """Новый экземпляр на том же файле видит прежние поездки — данные лежат на диске."""
    path = tmp_path / "trips.sqlite3"
    TripStore(path).add(ME, ride(id="t1"))

    assert stored_ids(TripStore(path)) == ["t1"]


# --- защита от дублей -----------------------------------------------------------------------


def test_same_trip_twice_is_one_record(store: TripStore) -> None:
    """Повторная отправка той же поездки дубля не создаёт."""
    first = store.add(ME, ride(id="t1"))
    second = store.add(ME, ride(id="t1"))

    assert first.outcome is AddOutcome.CREATED
    assert second.outcome is AddOutcome.DUPLICATE
    assert stored_ids(store) == ["t1"]


def test_same_moment_in_other_notation_is_the_same_trip(store: TripStore) -> None:
    """Повтор, в котором то же время записано в UTC, — всё ещё повтор."""
    store.add(ME, ride("2026-10-01T08:10:00+05:00", "2026-10-01T08:32:00+05:00", id="t1"))

    again = store.add(ME, ride("2026-10-01T03:10:00+00:00", "2026-10-01T03:32:00+00:00", id="t1"))

    assert again.outcome is AddOutcome.DUPLICATE
    assert stored_ids(store) == ["t1"]


def test_same_content_under_new_id_is_one_record(store: TripStore) -> None:
    """Тот же JSON с другим `id` — та же поездка; в ответе прежняя запись с прежним `id`."""
    store.add(ME, ride(id="first"))

    again = store.add(ME, ride(id="second"))

    assert again.outcome is AddOutcome.DUPLICATE
    assert again.trip.id == "first"
    assert stored_ids(store) == ["first"]


@pytest.mark.parametrize(
    "changed",
    [
        ride(id="t1", amount=9900),
        ride(id="t1", commission=1),
        ride(id="t1", payment=Payment.CASH),
        ride("2026-10-01T08:10:00+05:00", "2026-10-01T09:00:00+05:00", id="t1"),
        ride("2026-10-01T08:11:00+05:00", "2026-10-01T08:30:00+05:00", id="t1"),
    ],
    ids=["сумма", "комиссия", "оплата", "конец", "начало"],
)
def test_same_id_with_other_content_is_conflict(store: TripStore, changed: Trip) -> None:
    """Под занятым `id` нельзя ни завести вторую поездку, ни переписать первую."""
    original = ride("2026-10-01T08:10:00+05:00", "2026-10-01T08:30:00+05:00", id="t1")
    store.add(ME, original)

    result = store.add(ME, changed)

    assert result.outcome is AddOutcome.CONFLICT
    assert result.trip == original
    assert store.starting_between(ME, *day_bounds(date(2026, 10, 1), SERVICE_ZONE)) == [original]


def test_different_trips_are_both_kept(store: TripStore) -> None:
    store.add(ME, ride("2026-10-01T08:10:00+05:00", id="t1"))
    store.add(ME, ride("2026-10-01T09:05:00+05:00", id="t2"))

    assert stored_ids(store) == ["t1", "t2"]


def add_at_once(store: TripStore, trips: list[Trip]) -> list[AddResult]:
    """Отправить все поездки одновременно: потоки стартуют по общему сигналу."""
    barrier = Barrier(len(trips))

    def send(trip: Trip) -> AddResult:
        barrier.wait()
        return store.add(ME, trip)

    with ThreadPoolExecutor(max_workers=len(trips)) as pool:
        return list(pool.map(send, trips))


def test_simultaneous_retries_create_one_record(store: TripStore) -> None:
    """Двадцать одновременных повторов одной поездки: создаёт ровно один, остальные — повтор."""
    results = add_at_once(store, [ride(id="t1") for _ in range(RIVALS)])

    outcomes = [result.outcome for result in results]
    assert outcomes.count(AddOutcome.CREATED) == 1
    assert outcomes.count(AddOutcome.DUPLICATE) == RIVALS - 1
    assert stored_ids(store) == ["t1"]


def test_simultaneous_copies_under_different_ids_create_one_record(store: TripStore) -> None:
    """То же, но у каждой копии свой `id`: победивший `id` получают все."""
    results = add_at_once(store, [ride(id=f"copy-{n}") for n in range(RIVALS)])

    outcomes = [result.outcome for result in results]
    assert outcomes.count(AddOutcome.CREATED) == 1
    assert outcomes.count(AddOutcome.DUPLICATE) == RIVALS - 1
    [winner] = stored_ids(store)
    assert {result.trip.id for result in results} == {winner}


# --- выборка за день ------------------------------------------------------------------------


def test_day_takes_trips_from_midnight_to_midnight(store: TripStore) -> None:
    """Полночь входит в новый день, а не в прошедший."""
    store.add(ME, ride("2026-09-30T23:59:59+05:00", id="накануне"))
    store.add(ME, ride("2026-10-01T00:00:00+05:00", id="ровно-в-полночь"))
    store.add(ME, ride("2026-10-01T23:59:59+05:00", id="последняя-секунда"))
    store.add(ME, ride("2026-10-02T00:00:00+05:00", id="уже-завтра"))

    assert stored_ids(store, date(2026, 10, 1)) == ["ровно-в-полночь", "последняя-секунда"]


def test_trip_over_midnight_belongs_to_the_day_it_started(store: TripStore) -> None:
    """Поездка 23:48–00:14 считается один раз — в день начала."""
    store.add(ME, ride("2026-09-30T23:48:00+05:00", "2026-10-01T00:14:00+05:00", id="t13"))

    assert stored_ids(store, date(2026, 9, 30)) == ["t13"]
    assert stored_ids(store, date(2026, 10, 1)) == []


def test_trip_sent_in_utc_lands_on_local_day(store: TripStore) -> None:
    """19:35Z 30 сентября — это 00:35 1 октября у водителя."""
    store.add(ME, ride("2026-09-30T19:35:00+00:00", id="t14"))

    assert stored_ids(store, date(2026, 9, 30)) == []
    assert stored_ids(store, date(2026, 10, 1)) == ["t14"]


def test_day_is_sorted_by_start(store: TripStore) -> None:
    store.add(ME, ride("2026-10-01T19:05:00+05:00", id="вечер"))
    store.add(ME, ride("2026-10-01T00:35:00+05:00", id="ночь"))
    store.add(ME, ride("2026-10-01T08:10:00+05:00", id="утро"))

    assert stored_ids(store) == ["ночь", "утро", "вечер"]


def test_empty_day_is_empty_list(store: TripStore) -> None:
    assert stored_ids(store) == []


def test_starts_lists_every_trip(store: TripStore) -> None:
    store.add(ME, ride("2026-10-01T08:10:00+05:00", id="t1"))
    store.add(ME, ride("2026-09-30T23:48:00+05:00", id="t13"))

    assert store.starts(ME) == [at("2026-09-30T23:48:00+05:00"), at("2026-10-01T08:10:00+05:00")]


# --- дневники разных водителей ----------------------------------------------------------------


def test_drivers_do_not_see_each_other(store: TripStore) -> None:
    store.add(ME, ride("2026-10-01T08:10:00+05:00", id="mine"))
    store.add(OTHER, ride("2026-10-01T09:05:00+05:00", id="theirs"))

    assert stored_ids(store) == ["mine"]
    assert stored_ids(store, driver=OTHER) == ["theirs"]
    assert store.starts(ME) == [at("2026-10-01T08:10:00+05:00")]


def test_same_trip_of_two_drivers_is_two_trips(store: TripStore) -> None:
    """Повтор ищется только в своём дневнике: одинаковые поездки двух водителей — не дубль."""
    mine = store.add(ME, ride(id="t1"))
    theirs = store.add(OTHER, ride(id="t1"))
    again = store.add(OTHER, ride(id="t1"))

    assert mine.outcome is AddOutcome.CREATED
    assert theirs.outcome is AddOutcome.CREATED
    assert again.outcome is AddOutcome.DUPLICATE
    assert stored_ids(store) == ["t1"]
    assert stored_ids(store, driver=OTHER) == ["t1"]


def test_same_id_of_two_drivers_can_hold_different_trips(store: TripStore) -> None:
    """Занятый у одного водителя `id` свободен у другого."""
    store.add(ME, ride(id="t1", amount=2400))

    theirs = store.add(OTHER, ride(id="t1", amount=9900))

    assert theirs.outcome is AddOutcome.CREATED
    [mine] = store.starting_between(ME, *day_bounds(date(2026, 10, 1), SERVICE_ZONE))
    assert mine.amount == 2400


# --- новый дневник ---------------------------------------------------------------------------

SAMPLE = [
    ride("2026-10-01T08:10:00+05:00", id="t1"),
    ride("2026-10-01T09:05:00+05:00", id="t2", payment=Payment.CASH),
]


def test_new_diary_starts_with_the_sample(store: TripStore) -> None:
    assert store.register(ME, SAMPLE) is True

    assert stored_ids(store) == ["t1", "t2"]
    assert stored_ids(store, driver=OTHER) == []


def test_known_driver_is_not_given_the_sample_again(store: TripStore) -> None:
    """Второе обращение ничего не добавляет — даже если образец с тех пор изменился."""
    store.register(ME, SAMPLE)

    again = store.register(ME, [*SAMPLE, ride("2026-10-01T11:40:00+05:00", id="t15")])

    assert again is False
    assert stored_ids(store) == ["t1", "t2"]


def test_simultaneous_first_requests_fill_the_diary_once(store: TripStore) -> None:
    """Двадцать одновременных первых обращений: дневник заведён один раз и заполнен целиком."""
    barrier = Barrier(RIVALS)

    def enter(_: int) -> tuple[bool, list[str]]:
        barrier.wait()
        created = store.register(ME, SAMPLE)
        # Кто бы ни пришёл, после регистрации он видит дневник полным, а не наполовину.
        return created, stored_ids(store)

    with ThreadPoolExecutor(max_workers=RIVALS) as pool:
        results = list(pool.map(enter, range(RIVALS)))

    assert [created for created, _ in results].count(True) == 1
    assert {tuple(seen) for _, seen in results} == {("t1", "t2")}


# --- база первой версии -----------------------------------------------------------------------


def test_database_without_drivers_is_upgraded_in_place(tmp_path: Path) -> None:
    """Файл, созданный до появления водителей: поездки переходят водителю по умолчанию."""
    path = tmp_path / "trips.sqlite3"
    old = sqlite3.connect(path)
    old.execute(
        "CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY, start_us INTEGER NOT NULL,"
        " end_us INTEGER NOT NULL, amount INTEGER NOT NULL, payment TEXT NOT NULL,"
        " commission INTEGER NOT NULL,"
        " UNIQUE (start_us, end_us, amount, payment, commission)) STRICT"
    )
    # 08:10–08:32 1 октября по времени сервиса, в микросекундах от начала эпохи.
    old.execute(
        "INSERT INTO trips VALUES ('t1', 1790824200000000, 1790825520000000, 2400, 'card', 360)"
    )
    old.commit()
    old.close()

    store = TripStore(path)

    assert stored_ids(store, driver=DEFAULT_DRIVER) == ["t1"]
    # Водитель по умолчанию уже известен: образец ему повторно не выдаётся.
    assert store.register(DEFAULT_DRIVER, SAMPLE) is False
    # Повторное открытие ничего не меняет.
    assert stored_ids(TripStore(path), driver=DEFAULT_DRIVER) == ["t1"]
