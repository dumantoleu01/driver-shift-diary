from datetime import UTC, date, timedelta, timezone

import pytest

from shift_diary.domain.day import count_by_day, day_bounds, local_date, parse_utc_offset
from tests.helpers import SERVICE_ZONE, at


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("+05:00", timedelta(hours=5)),
        ("-03:30", -timedelta(hours=3, minutes=30)),
        ("+00:00", timedelta(0)),
        (" +05:00 ", timedelta(hours=5)),
    ],
)
def test_parse_utc_offset(text: str, expected: timedelta) -> None:
    assert parse_utc_offset(text).utcoffset(None) == expected


@pytest.mark.parametrize("text", ["", "5", "+5", "+05", "05:00", "+05:60", "+15:00", "Asia/Almaty"])
def test_parse_utc_offset_rejects_garbage(text: str) -> None:
    """Опечатка в конфиге должна остановить запуск, а не сдвинуть все дни."""
    with pytest.raises(ValueError, match="смещени"):
        parse_utc_offset(text)


def test_just_after_midnight_belongs_to_new_day() -> None:
    """00:35 по времени водителя — уже 1 октября, хотя по UTC ещё 30 сентября."""
    moment = at("2026-10-01T00:35:00+05:00")

    assert moment.astimezone(UTC).date() == date(2026, 9, 30)
    assert local_date(moment, SERVICE_ZONE) == date(2026, 10, 1)


def test_local_date_ignores_notation_of_the_moment() -> None:
    """Тот же момент, присланный в UTC или в другом поясе, даёт тот же день."""
    as_utc = at("2026-09-30T19:35:00+00:00")
    as_tokyo = at("2026-10-01T04:35:00+09:00")

    assert as_utc.date() == date(2026, 9, 30)  # дата в смещении самой записи — не та
    assert local_date(as_utc, SERVICE_ZONE) == date(2026, 10, 1)
    assert local_date(as_tokyo, SERVICE_ZONE) == date(2026, 10, 1)


def test_local_date_follows_configured_zone() -> None:
    """Со смещением +06:00 тот же момент относится уже к другому дню."""
    moment = at("2026-10-01T23:30:00+05:00")

    assert local_date(moment, SERVICE_ZONE) == date(2026, 10, 1)
    assert local_date(moment, timezone(timedelta(hours=6))) == date(2026, 10, 2)


def test_day_bounds_are_local_midnights() -> None:
    start, end = day_bounds(date(2026, 10, 1), SERVICE_ZONE)

    assert start == at("2026-10-01T00:00:00+05:00") == at("2026-09-30T19:00:00+00:00")
    assert end == at("2026-10-02T00:00:00+05:00")
    assert end - start == timedelta(days=1)


def test_day_bounds_of_neighbours_touch_without_overlap() -> None:
    """Конец одного дня — начало следующего: поездка в 00:00 попадает ровно в один день."""
    _, end_of_first = day_bounds(date(2026, 9, 30), SERVICE_ZONE)
    start_of_second, _ = day_bounds(date(2026, 10, 1), SERVICE_ZONE)

    assert end_of_first == start_of_second


def test_count_by_day_groups_by_local_date_in_order() -> None:
    starts = [
        at("2026-10-01T08:10:00+05:00"),
        at("2026-09-30T23:48:00+05:00"),
        at("2026-10-01T00:35:00+05:00"),
        at("2026-09-30T19:35:00+00:00"),  # это тоже 1 октября, 00:35
    ]

    assert count_by_day(starts, SERVICE_ZONE) == {date(2026, 9, 30): 1, date(2026, 10, 1): 3}


def test_count_by_day_of_nothing_is_empty() -> None:
    assert count_by_day([], SERVICE_ZONE) == {}
