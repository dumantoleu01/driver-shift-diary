"""Правила, которым должна удовлетворять поездка.

Коды нарушений — часть договора с клиентом: приложение показывает по ним текст под полем
формы. Переименовать код значит сломать клиента.
"""

from datetime import UTC, datetime, timedelta
from enum import StrEnum


class Violation(StrEnum):
    """Что не так с полем поездки."""

    # Форма данных — эти коды ставит разбор запроса.
    REQUIRED = "required"
    INVALID_TYPE = "invalid_type"
    INVALID_VALUE = "invalid_value"
    INVALID_DATETIME = "invalid_datetime"
    OFFSET_REQUIRED = "offset_required"

    # Смысл данных — эти коды ставит `violations`.
    OUT_OF_RANGE = "out_of_range"
    MUST_BE_AFTER_START = "must_be_after_start"
    TOO_LONG = "too_long"
    MUST_BE_POSITIVE = "must_be_positive"
    TOO_LARGE = "too_large"
    MUST_NOT_BE_NEGATIVE = "must_not_be_negative"
    MUST_NOT_EXCEED_AMOUNT = "must_not_exceed_amount"


# Границы нужны не для красоты. Год 0001 или 9999 при переводе в пояс сервиса выходит за
# пределы календаря, а сумма в 10**30 не помещается в целое число базы — без проверки оба
# случая заканчивались бы ошибкой 500 вместо понятного отказа.
EARLIEST = datetime(2000, 1, 1, tzinfo=UTC)
LATEST = datetime(2100, 1, 1, tzinfo=UTC)
MAX_AMOUNT = 100_000_000

# Поездку нельзя ни исправить, ни удалить, поэтому явную опечатку в дате лучше не принять вовсе:
# «окончание через двое суток» — это ошибка ввода, а не поездка.
MAX_DURATION = timedelta(hours=24)


def violations(
    *, start: datetime, end: datetime, amount: int, commission: int
) -> dict[str, Violation]:
    """Нарушения правил: поле → код. Пустой словарь — поездка годится.

    Возвращаются все нарушения сразу: форме незачем узнавать о них по одному.
    """
    found: dict[str, Violation] = {}

    start_in_range = EARLIEST <= start < LATEST
    if not start_in_range:
        found["start"] = Violation.OUT_OF_RANGE
    if not EARLIEST <= end < LATEST:
        found["end"] = Violation.OUT_OF_RANGE
    elif start_in_range:
        # С негодным началом сравнивать окончание не с чем.
        if end <= start:
            found["end"] = Violation.MUST_BE_AFTER_START
        elif end - start > MAX_DURATION:
            found["end"] = Violation.TOO_LONG

    if amount <= 0:
        found["amount"] = Violation.MUST_BE_POSITIVE
    elif amount > MAX_AMOUNT:
        found["amount"] = Violation.TOO_LARGE

    if commission < 0:
        found["commission"] = Violation.MUST_NOT_BE_NEGATIVE
    elif "amount" not in found and commission > amount:
        # С негодной суммой сравнивать комиссию не с чем — второе сообщение только запутало бы.
        found["commission"] = Violation.MUST_NOT_EXCEED_AMOUNT

    return found
