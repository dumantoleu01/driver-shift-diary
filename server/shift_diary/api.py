"""HTTP API дневника смен.

Ошибки всех видов отдаются в одном формате:
`{"error": {"code": "...", "message": "...", "fields": {"поле": "код"}}}` — клиент разбирает
его одним способом, а текст под полем формы выбирает по коду.
"""

import contextlib
import datetime as dt
import logging
import re
from collections.abc import Mapping

from fastapi import FastAPI, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

from shift_diary.config import Settings
from shift_diary.domain.day import count_by_day, day_bounds, parse_utc_offset
from shift_diary.domain.rules import EARLIEST, LATEST
from shift_diary.domain.summary import summarize
from shift_diary.domain.trip import Payment, Trip
from shift_diary.payload import InvalidTrip, TripPayload, field_errors
from shift_diary.seed import load_seed
from shift_diary.storage import AddOutcome, TripStore

logger = logging.getLogger(__name__)

_DAY = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")


class TripOut(BaseModel):
    id: str
    start: dt.datetime
    end: dt.datetime
    amount: int
    payment: Payment
    commission: int


class PaymentTotalsOut(BaseModel):
    trips: int
    amount: int


class ByPaymentOut(BaseModel):
    cash: PaymentTotalsOut
    card: PaymentTotalsOut


class SummaryOut(BaseModel):
    trips: int
    revenue: int
    commission: int
    net: int
    by_payment: ByPaymentOut


class DayOut(BaseModel):
    date: dt.date
    summary: SummaryOut
    trips: list[TripOut]


class DayCountOut(BaseModel):
    date: dt.date
    trips: int


class DaysOut(BaseModel):
    #: Пояс сервиса вида `+05:00`. Клиент берёт его отсюда, а не из своих настроек: в этом
    #: поясе он показывает время и переводит в момент то, что водитель ввёл в форме.
    utc_offset: str
    days: list[DayCountOut]


class ErrorDetail(BaseModel):
    code: str
    message: str
    fields: dict[str, str] | None = None


class ErrorOut(BaseModel):
    error: ErrorDetail


class ApiError(Exception):
    """Отказ, о котором клиенту надо сообщить кодом, а не текстом исключения."""

    def __init__(
        self, status: int, code: str, message: str, fields: Mapping[str, str] | None = None
    ) -> None:
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message
        self.fields = fields


def _error_response(error: ApiError) -> JSONResponse:
    detail: dict[str, object] = {"code": error.code, "message": error.message}
    if error.fields:
        detail["fields"] = dict(error.fields)
    return JSONResponse(status_code=error.status, content={"error": detail})


def _invalid_trip(fields: Mapping[str, str]) -> ApiError:
    return ApiError(
        422, "validation_failed", "Поездка не прошла проверку — причины в поле fields", fields
    )


# Поездка проверяется по моменту времени, а день считается в поясе сервиса: поездка на самом
# краю допустимого диапазона может относиться к соседней дате. Поэтому дней на сутки больше с
# каждой стороны — иначе поездку можно было бы записать, а её день открыть нельзя.
_FIRST_DAY = EARLIEST.date() - dt.timedelta(days=1)
_LAST_DAY = LATEST.date()


def _parse_day(text: str) -> dt.date:
    """Дата из адреса. Только `ГГГГ-ММ-ДД`: `fromisoformat` сам по себе принял бы и `20261001`."""
    day = None
    if _DAY.fullmatch(text):
        # Запись вида 2026-02-30 проходит по шаблону, но такой даты нет.
        with contextlib.suppress(ValueError):
            day = dt.date.fromisoformat(text)
    if day is None:
        raise ApiError(
            400, "invalid_date", "Дата должна быть в формате ГГГГ-ММ-ДД, например 2026-10-01"
        )
    if not _FIRST_DAY <= day <= _LAST_DAY:
        raise ApiError(400, "invalid_date", f"Дата должна быть от {_FIRST_DAY} до {_LAST_DAY}")
    return day


def create_app(settings: Settings | None = None) -> FastAPI:
    """Собрать приложение: хранилище, образец данных и маршруты."""
    settings = settings or Settings.from_env()
    zone = parse_utc_offset(settings.utc_offset)
    store = TripStore(settings.db_path)
    if settings.seed_path is not None:
        load_seed(settings.seed_path, store)

    app = FastAPI(
        title="Дневник смен водителя",
        version="1.0.0",
        description=(
            f"Поездки и сводка за день. День считается в поясе сервиса (UTC{settings.utc_offset}); "
            "поездка относится к дню своего начала."
        ),
    )

    def trip_out(trip: Trip) -> TripOut:
        # Время отдаётся в поясе сервиса, в каком бы поясе его ни прислали: клиент показывает
        # часы как есть и не зависит от пояса телефона.
        return TripOut(
            id=trip.id,
            start=trip.start.astimezone(zone),
            end=trip.end.astimezone(zone),
            amount=trip.amount,
            payment=trip.payment,
            commission=trip.commission,
        )

    @app.get("/health", include_in_schema=False)
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/api/days", summary="Дни, в которых есть поездки")
    def list_days() -> DaysOut:
        counts = count_by_day(store.starts(), zone)
        return DaysOut(
            utc_offset=settings.utc_offset.strip(),
            days=[DayCountOut(date=day, trips=trips) for day, trips in counts.items()],
        )

    @app.get(
        "/api/days/{day}",
        summary="Сводка и поездки за день",
        responses={400: {"model": ErrorOut, "description": "Дата не в формате ГГГГ-ММ-ДД"}},
    )
    def get_day(day: str) -> DayOut:
        # Сводка и список отдаются одним ответом, из одной выборки: между двумя запросами
        # могла бы добавиться поездка, и итог перестал бы сходиться со списком.
        chosen = _parse_day(day)
        trips = store.starting_between(*day_bounds(chosen, zone))
        summary = summarize(trips)
        return DayOut(
            date=chosen,
            summary=SummaryOut(
                trips=summary.trips,
                revenue=summary.revenue,
                commission=summary.commission,
                net=summary.net,
                by_payment=ByPaymentOut(
                    cash=PaymentTotalsOut(trips=summary.cash.trips, amount=summary.cash.amount),
                    card=PaymentTotalsOut(trips=summary.card.trips, amount=summary.card.amount),
                ),
            ),
            trips=[trip_out(trip) for trip in trips],
        )

    @app.post(
        "/api/trips",
        status_code=201,
        summary="Добавить поездку",
        description=(
            "Повторная отправка той же поездки не создаёт дубль: ответ `200` с уже записанной "
            "поездкой. Той же считается поездка с тем же `id` или с теми же началом, концом, "
            "суммой, оплатой и комиссией."
        ),
        responses={
            200: {"model": TripOut, "description": "Такая поездка уже записана — повтор"},
            400: {"model": ErrorOut, "description": "Тело запроса — не JSON-объект"},
            409: {"model": ErrorOut, "description": "Под этим id записана другая поездка"},
            422: {"model": ErrorOut, "description": "Поездка не прошла проверку"},
        },
    )
    def add_trip(payload: TripPayload, response: Response) -> TripOut:
        try:
            trip = payload.to_trip()
        except InvalidTrip as error:
            raise _invalid_trip(error.fields) from error

        result = store.add(trip)
        if result.outcome is AddOutcome.CONFLICT:
            raise ApiError(409, "id_conflict", f"Под id {trip.id!r} уже записана другая поездка")
        if result.outcome is AddOutcome.DUPLICATE:
            response.status_code = 200
        return trip_out(result.trip)

    @app.exception_handler(ApiError)
    def on_api_error(_: Request, error: ApiError) -> JSONResponse:
        return _error_response(error)

    @app.exception_handler(RequestValidationError)
    def on_invalid_request(_: Request, error: RequestValidationError) -> JSONResponse:
        errors = error.errors()
        if any(item["type"] == "json_invalid" for item in errors):
            return _error_response(ApiError(400, "invalid_json", "Тело запроса — не JSON"))

        fields = field_errors(errors, skip=1)
        if not fields:
            # Ошибка относится ко всему телу: его нет, это не объект или не тот Content-Type.
            return _error_response(
                ApiError(
                    400,
                    "invalid_body",
                    "Ожидается JSON-объект поездки с заголовком Content-Type: application/json",
                )
            )
        return _error_response(_invalid_trip(fields))

    @app.exception_handler(StarletteHTTPException)
    def on_http_error(_: Request, error: StarletteHTTPException) -> JSONResponse:
        known = {
            404: ("not_found", "Такого адреса нет"),
            405: ("method_not_allowed", "Метод не поддерживается"),
        }
        code, message = known.get(error.status_code, ("http_error", str(error.detail)))
        return _error_response(ApiError(error.status_code, code, message))

    @app.exception_handler(Exception)
    def on_unexpected(_: Request, error: Exception) -> JSONResponse:
        # Текст исключения остаётся в журнале сервера и наружу не уходит.
        logger.exception("Необработанная ошибка", exc_info=error)
        return _error_response(ApiError(500, "internal_error", "Внутренняя ошибка сервера"))

    return app
