from shift_diary.domain.summary import PaymentTotals, summarize
from shift_diary.domain.trip import Payment
from tests.helpers import ride


def test_empty_day_is_all_zeros() -> None:
    """Пустой день — не ошибка, а нулевая сводка."""
    summary = summarize([])

    assert summary.trips == 0
    assert summary.revenue == 0
    assert summary.commission == 0
    assert summary.net == 0
    assert summary.cash == PaymentTotals(trips=0, amount=0)
    assert summary.card == PaymentTotals(trips=0, amount=0)


def test_sample_from_assignment() -> None:
    """Две поездки из текста задания: карта 2400/360 и наличные 1500/225."""
    summary = summarize(
        [
            ride(id="t1", amount=2400, payment=Payment.CARD, commission=360),
            ride(id="t2", amount=1500, payment=Payment.CASH, commission=225),
        ]
    )

    assert summary.trips == 2
    assert summary.revenue == 3900
    assert summary.commission == 585
    assert summary.net == 3315
    assert summary.card == PaymentTotals(trips=1, amount=2400)
    assert summary.cash == PaymentTotals(trips=1, amount=1500)


def test_net_is_revenue_minus_commission() -> None:
    summary = summarize([ride(amount=1000, commission=150), ride(amount=3000, commission=450)])

    assert summary.net == 4000 - 600


def test_cash_only_day_has_empty_card_totals() -> None:
    summary = summarize(
        [
            ride(amount=2100, payment=Payment.CASH, commission=315),
            ride(amount=1600, payment=Payment.CASH, commission=240),
        ]
    )

    assert summary.cash == PaymentTotals(trips=2, amount=3700)
    assert summary.card == PaymentTotals(trips=0, amount=0)


def test_breakdown_adds_up_to_totals() -> None:
    """Разбивка по оплате не теряет и не удваивает поездки."""
    trips = [
        ride(amount=amount, payment=payment, commission=amount * 15 // 100)
        for amount, payment in [
            (1800, Payment.CARD),
            (2200, Payment.CASH),
            (3400, Payment.CARD),
            (1200, Payment.CASH),
            (4600, Payment.CARD),
        ]
    ]

    summary = summarize(trips)

    assert summary.cash.trips + summary.card.trips == summary.trips == 5
    assert summary.cash.amount + summary.card.amount == summary.revenue == 13200
    assert summary.commission == 1980


def test_zero_commission_leaves_revenue_untouched() -> None:
    summary = summarize([ride(amount=2400, commission=0)])

    assert summary.net == summary.revenue == 2400


def test_accepts_any_iterable() -> None:
    """Сводку можно считать по генератору — он читается ровно один раз."""
    summary = summarize(ride(amount=amount, commission=0) for amount in (100, 200, 300))

    assert summary.trips == 3
    assert summary.revenue == 600
