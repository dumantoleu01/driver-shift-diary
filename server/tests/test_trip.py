from datetime import datetime

import pytest

from shift_diary.domain.trip import Payment, Trip
from tests.helpers import at, ride


def test_naive_start_is_rejected() -> None:
    """Время без смещения не становится поездкой — иначе день зависел бы от часов сервера."""
    with pytest.raises(ValueError, match="start"):
        Trip(
            id="t",
            start=datetime(2026, 10, 1, 8, 10),  # noqa: DTZ001 — в этом и проверка
            end=at("2026-10-01T08:32:00+05:00"),
            amount=2400,
            payment=Payment.CARD,
            commission=360,
        )


def test_naive_end_is_rejected() -> None:
    with pytest.raises(ValueError, match="end"):
        Trip(
            id="t",
            start=at("2026-10-01T08:10:00+05:00"),
            end=datetime(2026, 10, 1, 8, 32),  # noqa: DTZ001 — в этом и проверка
            amount=2400,
            payment=Payment.CARD,
            commission=360,
        )


def test_net_is_amount_minus_commission() -> None:
    assert ride(amount=2400, commission=360).net == 2040


def test_same_ride_ignores_id() -> None:
    """Повтор с новым `id`, но тем же содержимым — та же поездка."""
    assert ride(id="a").same_ride(ride(id="b"))


def test_same_ride_compares_moments_not_notation() -> None:
    """Одна и та же секунда, записанная в разных поясах, — одна и та же поездка."""
    local = ride("2026-10-01T08:10:00+05:00", "2026-10-01T08:32:00+05:00")
    utc = ride("2026-10-01T03:10:00+00:00", "2026-10-01T03:32:00+00:00")
    assert local.same_ride(utc)


@pytest.mark.parametrize(
    "other",
    [
        ride("2026-10-01T08:11:00+05:00", "2026-10-01T08:30:00+05:00"),
        ride(end="2026-10-01T08:31:00+05:00"),
        ride(amount=2500),
        ride(payment=Payment.CASH),
        ride(commission=361),
    ],
    ids=["начало", "конец", "сумма", "оплата", "комиссия"],
)
def test_same_ride_sees_any_difference(other: Trip) -> None:
    assert not ride(end="2026-10-01T08:30:00+05:00").same_ride(other)
