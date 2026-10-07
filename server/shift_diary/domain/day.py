"""День в поясе сервиса.

«Поездки за 1 октября» — это поездки, начавшиеся с 00:00 до 24:00 по времени водителя, а не
по UTC и не по часам сервера. Пояс задаётся фиксированным смещением: имя пояса зависит от
версии базы часовых поясов на машине (Алматы перешёл с UTC+6 на UTC+5 в марте 2024 года), а
смещение — нет.
"""

import re
from collections import Counter
from collections.abc import Iterable
from datetime import date, datetime, time, timedelta, timezone, tzinfo

_OFFSET = re.compile(r"([+-])(\d{2}):(\d{2})")

# Дальше UTC+14 и UTC−12 поясов не бывает; всё, что за пределами, — опечатка в конфиге.
_MAX_OFFSET = timedelta(hours=14)


def parse_utc_offset(text: str) -> timezone:
    """Разобрать смещение вида `+05:00` из конфига."""
    match = _OFFSET.fullmatch(text.strip())
    if match is None:
        raise ValueError(f"смещение должно быть вида +05:00, получено: {text!r}")

    sign, hours, minutes = match.groups()
    if int(minutes) >= 60:
        raise ValueError(f"минут в смещении не может быть 60 и больше: {text!r}")

    offset = timedelta(hours=int(hours), minutes=int(minutes))
    if offset > _MAX_OFFSET:
        raise ValueError(f"смещение больше 14 часов не бывает: {text!r}")

    return timezone(-offset if sign == "-" else offset)


def local_date(moment: datetime, zone: tzinfo) -> date:
    """Календарная дата момента в поясе сервиса.

    Брать `moment.date()` напрямую нельзя: это дата в смещении самой записи, и поездка,
    присланная как `19:35Z`, осталась бы во вчерашнем дне, хотя у водителя уже 00:35.
    """
    return moment.astimezone(zone).date()


def day_bounds(day: date, zone: tzinfo) -> tuple[datetime, datetime]:
    """Начало дня и начало следующего дня в поясе сервиса.

    Интервал полуоткрытый: поездка ровно в 00:00 относится к новому дню.
    """
    start = datetime.combine(day, time.min, tzinfo=zone)
    return start, start + timedelta(days=1)


def count_by_day(starts: Iterable[datetime], zone: tzinfo) -> dict[date, int]:
    """Сколько поездок началось в каждый из дней, по возрастанию даты."""
    counts = Counter(local_date(start, zone) for start in starts)
    return dict(sorted(counts.items()))
