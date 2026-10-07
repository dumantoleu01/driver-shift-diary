"""Поездка — единственная сущность сервиса."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class Payment(StrEnum):
    """Способ оплаты поездки."""

    CASH = "cash"
    CARD = "card"


@dataclass(frozen=True, slots=True)
class Trip:
    """Поездка водителя.

    Деньги хранятся целыми числами: на дробных `float` сумма за день может не сойтись со
    списком поездок, а сводка обязана сходиться с ним точно.
    """

    id: str
    start: datetime
    end: datetime
    amount: int
    payment: Payment
    commission: int

    def __post_init__(self) -> None:
        # Время без смещения Python молча трактует как время машины, где запущен сервер:
        # та же поездка на ноутбуке и в облаке попала бы в разные дни. Поэтому такое время
        # не доходит даже до расчётов.
        for name in ("start", "end"):
            moment: datetime = getattr(self, name)
            if moment.utcoffset() is None:
                raise ValueError(f"{name}: время без смещения не принимается")

    @property
    def net(self) -> int:
        """Сколько водитель получает за поездку «на руки»."""
        return self.amount - self.commission

    def same_ride(self, other: "Trip") -> bool:
        """Та же ли это поездка, если не смотреть на `id`.

        Время сравнивается как момент, а не как запись: `08:10+05:00` и `03:10Z` — одна и та
        же секунда, и поездка с ними одна и та же.
        """
        return (self.start, self.end, self.amount, self.payment, self.commission) == (
            other.start,
            other.end,
            other.amount,
            other.payment,
            other.commission,
        )
