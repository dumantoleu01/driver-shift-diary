"""Хранилище поездок на SQLite.

Защита от дублей живёт здесь, в ограничениях таблицы, а не в коде выше: запросы обрабатываются
в нескольких потоках (а сервер может работать и в нескольких процессах), и проверка «есть ли
уже такая поездка» перед вставкой пропустила бы два одновременных повтора.
"""

import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import Enum
from pathlib import Path

from shift_diary.domain.trip import Payment, Trip

# Два ограничения уникальности — два способа узнать повтор:
#   * по `id` — клиент повторил запрос после обрыва связи;
#   * по содержимому — тот же JSON пришёл с другим `id` или вовсе без него. Один водитель не
#     может вести две поездки в одну и ту же секунду, так что это та же поездка.
# Время хранится целым числом микросекунд от начала эпохи в UTC: сравнение идёт по моменту,
# а не по записи, и `08:10+05:00` совпадает с `03:10Z`.
_SCHEMA = """
CREATE TABLE IF NOT EXISTS trips (
    id         TEXT    NOT NULL PRIMARY KEY,
    start_us   INTEGER NOT NULL,
    end_us     INTEGER NOT NULL,
    amount     INTEGER NOT NULL,
    payment    TEXT    NOT NULL,
    commission INTEGER NOT NULL,
    UNIQUE (start_us, end_us, amount, payment, commission)
) STRICT
"""

_COLUMNS = "id, start_us, end_us, amount, payment, commission"

# Сколько ждать, пока другой поток или процесс допишет свою строку.
_BUSY_TIMEOUT_SECONDS = 5.0

_EPOCH = datetime(1970, 1, 1, tzinfo=UTC)
_MICROSECOND = timedelta(microseconds=1)

type _Row = tuple[str, int, int, int, str, int]


class AddOutcome(Enum):
    """Чем закончилась попытка добавить поездку."""

    CREATED = "created"
    #: Такая поездка уже есть — повтор, а не ошибка.
    DUPLICATE = "duplicate"
    #: Под этим `id` лежит другая поездка.
    CONFLICT = "conflict"


@dataclass(frozen=True, slots=True)
class AddResult:
    outcome: AddOutcome
    #: Поездка, которая лежит в хранилище. При повторе и конфликте — прежняя, а не присланная.
    trip: Trip


class TripStore:
    """Поездки в файле SQLite.

    Соединение открывается на каждую операцию: так хранилищем можно пользоваться из любого
    потока, а для сервиса такого размера цена открытия незаметна.
    """

    def __init__(self, path: Path) -> None:
        self._path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        with self._open() as db:
            # WAL: чтение сводки не ждёт, пока другой запрос дописывает поездку.
            db.execute("PRAGMA journal_mode = WAL")
            db.execute(_SCHEMA)

    def add(self, trip: Trip) -> AddResult:
        """Добавить поездку; повтор не создаёт вторую запись.

        Вставка — один запрос с `ON CONFLICT DO NOTHING`: одновременные повторы разводит сама
        база. Кто из них записал строку, видно по числу вставленных строк, а остальным остаётся
        выяснить, с чем именно они совпали.
        """
        row = _to_row(trip)
        with self._open() as db:
            inserted = db.execute(
                f"INSERT INTO trips ({_COLUMNS}) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING",
                row,
            ).rowcount
            if inserted:
                return AddResult(AddOutcome.CREATED, trip)

            same_id = db.execute(
                f"SELECT {_COLUMNS} FROM trips WHERE id = ?", (trip.id,)
            ).fetchone()
            if same_id is not None:
                stored = _to_trip(same_id)
                outcome = AddOutcome.DUPLICATE if stored.same_ride(trip) else AddOutcome.CONFLICT
                return AddResult(outcome, stored)

            same_ride = db.execute(
                f"SELECT {_COLUMNS} FROM trips WHERE start_us = ? AND end_us = ?"
                " AND amount = ? AND payment = ? AND commission = ?",
                row[1:],
            ).fetchone()

        if same_ride is None:
            # Вставку отклонило ограничение, но совпавшей строки нет. Поездки не удаляются,
            # поэтому такого быть не может; молча вернуть «создано» было бы хуже, чем упасть.
            raise RuntimeError(f"поездка {trip.id!r} не вставлена, но и совпадений нет")
        return AddResult(AddOutcome.DUPLICATE, _to_trip(same_ride))

    def starting_between(self, start: datetime, end: datetime) -> list[Trip]:
        """Поездки, начавшиеся в полуинтервале `[start, end)`, по времени начала."""
        with self._open() as db:
            rows = db.execute(
                f"SELECT {_COLUMNS} FROM trips WHERE start_us >= ? AND start_us < ?"
                " ORDER BY start_us, id",
                (_to_microseconds(start), _to_microseconds(end)),
            ).fetchall()
        return [_to_trip(row) for row in rows]

    def starts(self) -> list[datetime]:
        """Время начала всех поездок — по нему считается список дней."""
        with self._open() as db:
            rows = db.execute("SELECT start_us FROM trips ORDER BY start_us").fetchall()
        return [_to_moment(start_us) for (start_us,) in rows]

    @contextmanager
    def _open(self) -> Iterator[sqlite3.Connection]:
        # autocommit: каждая команда — отдельная завершённая транзакция, читать после вставки
        # можно сразу, и незакрытых транзакций не остаётся.
        db = sqlite3.connect(self._path, timeout=_BUSY_TIMEOUT_SECONDS, autocommit=True)
        try:
            yield db
        finally:
            db.close()


def _to_microseconds(moment: datetime) -> int:
    return (moment - _EPOCH) // _MICROSECOND


def _to_moment(microseconds: int) -> datetime:
    return _EPOCH + timedelta(microseconds=microseconds)


def _to_row(trip: Trip) -> _Row:
    return (
        trip.id,
        _to_microseconds(trip.start),
        _to_microseconds(trip.end),
        trip.amount,
        trip.payment.value,
        trip.commission,
    )


def _to_trip(row: _Row) -> Trip:
    trip_id, start_us, end_us, amount, payment, commission = row
    return Trip(
        id=trip_id,
        start=_to_moment(start_us),
        end=_to_moment(end_us),
        amount=amount,
        payment=Payment(payment),
        commission=commission,
    )
