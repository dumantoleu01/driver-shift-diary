from datetime import datetime, timedelta

import pytest

from shift_diary.domain.rules import MAX_AMOUNT, Violation, violations
from tests.helpers import at

START = at("2026-10-01T08:10:00+05:00")
END = at("2026-10-01T08:32:00+05:00")


def check(
    *, start: datetime = START, end: datetime = END, amount: int = 2400, commission: int = 360
) -> dict[str, Violation]:
    return violations(start=start, end=end, amount=amount, commission=commission)


def test_good_trip_has_no_violations() -> None:
    assert check() == {}


@pytest.mark.parametrize("amount", [0, -1, -2400])
def test_amount_must_be_positive(amount: int) -> None:
    """Правило из задания: сумма больше нуля."""
    assert check(amount=amount, commission=0) == {"amount": Violation.MUST_BE_POSITIVE}


def test_smallest_amount_is_one() -> None:
    assert check(amount=1, commission=0) == {}


def test_amount_has_upper_bound() -> None:
    """Иначе число не поместилось бы в базу и отказ выглядел бы как ошибка сервера."""
    assert check(amount=MAX_AMOUNT) == {}
    assert check(amount=MAX_AMOUNT + 1) == {"amount": Violation.TOO_LARGE}
    assert check(amount=10**30) == {"amount": Violation.TOO_LARGE}


@pytest.mark.parametrize("gap", [timedelta(0), -timedelta(seconds=1), -timedelta(hours=3)])
def test_end_must_be_after_start(gap: timedelta) -> None:
    """Правило из задания: окончание позже начала. Равенство — тоже отказ."""
    assert check(end=START + gap) == {"end": Violation.MUST_BE_AFTER_START}


def test_shortest_trip_is_one_second() -> None:
    assert check(end=START + timedelta(seconds=1)) == {}


def test_end_is_compared_as_moment_not_as_text() -> None:
    """`09:00+06:00` — это 08:00 по времени водителя, то есть раньше начала в 08:10."""
    assert check(end=at("2026-10-01T09:00:00+06:00")) == {"end": Violation.MUST_BE_AFTER_START}


def test_trip_over_midnight_is_fine() -> None:
    assert check(start=at("2026-09-30T23:48:00+05:00"), end=at("2026-10-01T00:14:00+05:00")) == {}


def test_commission_cannot_be_negative() -> None:
    assert check(commission=-1) == {"commission": Violation.MUST_NOT_BE_NEGATIVE}


def test_commission_cannot_exceed_amount() -> None:
    assert check(amount=2400, commission=2401) == {"commission": Violation.MUST_NOT_EXCEED_AMOUNT}


@pytest.mark.parametrize("commission", [0, 360, 2400])
def test_commission_from_zero_to_amount_is_fine(commission: int) -> None:
    assert check(amount=2400, commission=commission) == {}


def test_commission_is_not_compared_with_bad_amount() -> None:
    """С негодной суммой сообщение «комиссия больше суммы» только запутало бы."""
    assert check(amount=0, commission=100) == {"amount": Violation.MUST_BE_POSITIVE}


@pytest.mark.parametrize(
    "moment",
    ["0001-01-01T00:00:00+05:00", "1999-12-31T23:59:59+00:00", "2100-01-01T00:00:00+00:00"],
)
def test_dates_far_from_today_are_rejected(moment: str) -> None:
    """Год 0001 при переводе в пояс сервиса выходит за пределы календаря — отказываем заранее."""
    assert check(start=at(moment), end=END)["start"] is Violation.OUT_OF_RANGE


def test_end_out_of_range_is_reported_on_end() -> None:
    assert check(end=at("9999-12-31T23:59:59-12:00")) == {"end": Violation.OUT_OF_RANGE}


def test_all_violations_are_reported_together() -> None:
    assert check(end=START, amount=0, commission=-5) == {
        "end": Violation.MUST_BE_AFTER_START,
        "amount": Violation.MUST_BE_POSITIVE,
        "commission": Violation.MUST_NOT_BE_NEGATIVE,
    }
