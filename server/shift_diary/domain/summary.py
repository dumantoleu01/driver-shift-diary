"""Сводка за день."""

from collections.abc import Iterable
from dataclasses import dataclass

from shift_diary.domain.trip import Payment, Trip


@dataclass(frozen=True, slots=True)
class PaymentTotals:
    """Итог по одному способу оплаты."""

    trips: int
    amount: int


@dataclass(frozen=True, slots=True)
class DaySummary:
    """Сводка по набору поездок.

    «На руки» не хранится отдельным полем, а считается из выручки и комиссии — так три числа
    не могут разойтись между собой.
    """

    trips: int
    revenue: int
    commission: int
    cash: PaymentTotals
    card: PaymentTotals

    @property
    def net(self) -> int:
        """«На руки»: выручка минус комиссия."""
        return self.revenue - self.commission


def summarize(trips: Iterable[Trip]) -> DaySummary:
    """Посчитать сводку.

    Какие поездки относятся к дню, решает вызывающий (см. `day_bounds`): здесь только
    арифметика, чтобы её можно было проверить на любом наборе поездок.
    """
    rides = list(trips)

    def totals(payment: Payment) -> PaymentTotals:
        paid = [ride for ride in rides if ride.payment == payment]
        return PaymentTotals(trips=len(paid), amount=sum(ride.amount for ride in paid))

    return DaySummary(
        trips=len(rides),
        revenue=sum(ride.amount for ride in rides),
        commission=sum(ride.commission for ride in rides),
        cash=totals(Payment.CASH),
        card=totals(Payment.CARD),
    )
