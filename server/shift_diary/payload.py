"""Разбор поездки, пришедшей извне, — из запроса или из файла с образцом.

Оба пути проходят через один и тот же разбор, поэтому в хранилище не может оказаться запись,
которую API отклонил бы.
"""

from collections.abc import Iterable, Mapping
from datetime import datetime
from typing import Annotated, Any
from uuid import uuid4

from pydantic import (
    BaseModel,
    BeforeValidator,
    ConfigDict,
    StrictInt,
    StringConstraints,
    ValidationError,
)
from pydantic_core import PydanticCustomError

from shift_diary.domain.rules import Violation, violations
from shift_diary.domain.trip import Payment, Trip

# Встроенные ошибки pydantic → наши коды. Всё незнакомое считается негодным значением.
_BUILTIN: dict[str, Violation] = {
    "missing": Violation.REQUIRED,
    "int_type": Violation.INVALID_TYPE,
    "string_type": Violation.INVALID_TYPE,
}


class InvalidTrip(Exception):
    """Поездка не прошла проверку."""

    def __init__(self, fields: Mapping[str, Violation]) -> None:
        super().__init__(", ".join(f"{field}: {code}" for field, code in fields.items()))
        self.fields = dict(fields)


def _parse_moment(value: object) -> datetime:
    """Момент времени: только строка ISO 8601 и только со смещением.

    Разбор свой, а не встроенный в pydantic: тот принимает ещё и числа, считая их секундами
    от начала эпохи, и строку `"1759300000"` молча превратил бы в дату.
    """
    if not isinstance(value, str):
        raise PydanticCustomError(Violation.INVALID_TYPE, "Ожидается строка ISO 8601")
    try:
        moment = datetime.fromisoformat(value)
    except ValueError:
        raise PydanticCustomError(Violation.INVALID_DATETIME, "Не похоже на дату и время") from None
    if moment.utcoffset() is None:
        raise PydanticCustomError(Violation.OFFSET_REQUIRED, "Нужно смещение, например +05:00")
    return moment


Moment = Annotated[datetime, BeforeValidator(_parse_moment)]

# В образце `id` — это `t1`, `t2`, клиент присылает UUID: годится любая короткая строка без
# пробелов и служебных знаков.
TripId = Annotated[
    str, StringConstraints(min_length=1, max_length=64, pattern=r"^[A-Za-z0-9._:-]+$")
]


class TripPayload(BaseModel):
    """Поездка в том виде, в каком её присылают.

    Числа — `StrictInt`: обычный режим pydantic молча принял бы `"2400"`, `2400.0` и `true`.
    """

    # Пример подставляется в форму на странице /docs: «Execute» дважды — и видно `201`, затем `200`.
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "demo-1",
                    "start": "2026-10-05T08:10:00+05:00",
                    "end": "2026-10-05T08:32:00+05:00",
                    "amount": 2400,
                    "payment": "card",
                    "commission": 360,
                }
            ]
        }
    )

    id: TripId | None = None
    start: Moment
    end: Moment
    amount: StrictInt
    payment: Payment
    commission: StrictInt

    def to_trip(self) -> Trip:
        """Проверить правила и собрать поездку. Без `id` сервер назначает свой."""
        problems = violations(
            start=self.start, end=self.end, amount=self.amount, commission=self.commission
        )
        if problems:
            raise InvalidTrip(problems)
        return Trip(
            id=self.id or str(uuid4()),
            start=self.start,
            end=self.end,
            amount=self.amount,
            payment=self.payment,
            commission=self.commission,
        )


def field_errors(errors: Iterable[Mapping[str, Any]], *, skip: int = 0) -> dict[str, Violation]:
    """Ошибки pydantic → `поле: код`.

    `skip` — сколько первых звеньев пути отбросить: у FastAPI путь начинается с `body`.
    """
    found: dict[str, Violation] = {}
    for error in errors:
        path = error["loc"][skip:]
        if not path:
            continue
        kind = str(error["type"])
        code = Violation(kind) if kind in Violation else _BUILTIN.get(kind, Violation.INVALID_VALUE)
        found.setdefault(str(path[0]), code)
    return found


def parse_trip(raw: object) -> Trip:
    """Разобрать поездку из уже прочитанного JSON."""
    try:
        payload = TripPayload.model_validate(raw)
    except ValidationError as error:
        fields = field_errors(error.errors())
        # Ошибка без поля — на месте объекта оказалось что-то другое (строка, список).
        raise InvalidTrip(fields or {"trip": Violation.INVALID_TYPE}) from error
    return payload.to_trip()
