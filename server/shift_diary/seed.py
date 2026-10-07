"""Образец поездок из JSON-файла.

С образца начинается дневник каждого нового водителя: файл читается один раз при запуске, а
его поездки записываются водителю при первом обращении.
"""

import json
import logging
from dataclasses import dataclass
from pathlib import Path

from shift_diary.domain.trip import Trip
from shift_diary.payload import InvalidTrip, parse_trip

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class Sample:
    #: Поездки, годные для записи: без повторов и без двух разных поездок под одним `id`.
    trips: tuple[Trip, ...] = ()
    #: Сколько записей файла повторяли уже принятую поездку.
    duplicates: int = 0
    #: Записи, которые не приняты, с причиной.
    rejected: tuple[str, ...] = ()


def read_sample(path: Path) -> Sample:
    """Прочитать образец, проверив каждую запись теми же правилами, что и запросы.

    Негодная запись пропускается с предупреждением, а нечитаемый файл останавливает запуск —
    сервер с пустыми дневниками вместо данных выглядел бы исправным, не будучи им.
    """
    try:
        # utf-8-sig: файл, сохранённый редактором с меткой BOM, — тоже годный JSON.
        records = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as error:
        raise ValueError(f"не удалось прочитать образец {path}: {error}") from error
    if not isinstance(records, list):
        raise ValueError(f"образец {path} должен быть JSON-массивом поездок")

    accepted: list[Trip] = []
    duplicates = 0
    rejected: list[str] = []
    for number, record in enumerate(records, start=1):
        try:
            trip = parse_trip(record)
        except InvalidTrip as error:
            rejected.append(f"запись {number}: {error}")
            continue

        # Те же два признака повтора, что и в хранилище: по `id` и по содержимому.
        same_id = next((other for other in accepted if other.id == trip.id), None)
        if same_id is not None and not same_id.same_ride(trip):
            rejected.append(f"запись {number}: id {trip.id!r} занят другой поездкой")
        elif same_id is not None or any(other.same_ride(trip) for other in accepted):
            duplicates += 1
        else:
            accepted.append(trip)

    for problem in rejected:
        logger.warning("Образец %s, %s", path.name, problem)
    logger.info(
        "Образец %s: поездок %d, повторов %d, пропущено %d",
        path.name,
        len(accepted),
        duplicates,
        len(rejected),
    )
    return Sample(trips=tuple(accepted), duplicates=duplicates, rejected=tuple(rejected))
