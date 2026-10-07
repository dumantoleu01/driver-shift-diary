"""Загрузка образца поездок из JSON-файла."""

import json
import logging
from dataclasses import dataclass, field
from pathlib import Path

from shift_diary.payload import InvalidTrip, parse_trip
from shift_diary.storage import AddOutcome, TripStore

logger = logging.getLogger(__name__)


@dataclass(slots=True)
class SeedReport:
    created: int = 0
    #: Уже были в хранилище — так выглядит каждый запуск после первого.
    duplicates: int = 0
    #: Записи, которые не загружены, с причиной.
    rejected: list[str] = field(default_factory=list)


def load_seed(path: Path, store: TripStore) -> SeedReport:
    """Загрузить поездки из файла тем же путём, каким их добавляет API.

    Загрузка идёт при каждом запуске и ничего не удваивает: повтор отсекает хранилище.
    Негодная запись пропускается с предупреждением, а нечитаемый файл останавливает запуск —
    сервер с пустой базой вместо данных выглядел бы исправным, не будучи им.
    """
    try:
        # utf-8-sig: файл, сохранённый редактором с меткой BOM, — тоже годный JSON.
        records = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as error:
        raise ValueError(f"не удалось прочитать образец {path}: {error}") from error
    if not isinstance(records, list):
        raise ValueError(f"образец {path} должен быть JSON-массивом поездок")

    report = SeedReport()
    for number, record in enumerate(records, start=1):
        try:
            trip = parse_trip(record)
        except InvalidTrip as error:
            report.rejected.append(f"запись {number}: {error}")
            continue

        outcome = store.add(trip).outcome
        if outcome is AddOutcome.CREATED:
            report.created += 1
        elif outcome is AddOutcome.DUPLICATE:
            report.duplicates += 1
        else:
            report.rejected.append(f"запись {number}: id {trip.id!r} занят другой поездкой")

    for problem in report.rejected:
        logger.warning("Образец %s, %s", path.name, problem)
    logger.info(
        "Образец %s: добавлено %d, уже было %d, пропущено %d",
        path.name,
        report.created,
        report.duplicates,
        len(report.rejected),
    )
    return report
