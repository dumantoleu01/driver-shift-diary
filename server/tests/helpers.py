"""Общие заготовки для тестов."""

from datetime import datetime, timedelta, timezone

from shift_diary.domain.trip import Payment, Trip

#: Пояс сервиса по умолчанию — тот же, что в образце данных.
SERVICE_ZONE = timezone(timedelta(hours=5))


def at(text: str) -> datetime:
    """Момент из строки ISO 8601 со смещением."""
    return datetime.fromisoformat(text)


def ride(
    start: str = "2026-10-01T08:10:00+05:00",
    end: str | None = None,
    *,
    id: str = "t",
    amount: int = 2400,
    payment: Payment = Payment.CARD,
    commission: int = 360,
) -> Trip:
    """Поездка с разумными значениями по умолчанию; длится 20 минут, если конец не задан."""
    started = at(start)
    return Trip(
        id=id,
        start=started,
        end=at(end) if end is not None else started + timedelta(minutes=20),
        amount=amount,
        payment=payment,
        commission=commission,
    )
