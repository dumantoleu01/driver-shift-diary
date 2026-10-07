"""Хранилище поездок на SQLite.

Защита от дублей живёт здесь, в ограничениях таблицы, а не в коде выше: запросы обрабатываются
в нескольких потоках (а сервер может работать и в нескольких процессах), и проверка «есть ли
уже такая поездка» перед вставкой пропустила бы два одновременных повтора.
"""

import sqlite3
from collections.abc import Iterable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import Enum
from pathlib import Path

from shift_diary.domain.driver import DEFAULT_DRIVER
from shift_diary.domain.trip import Payment, Trip

# У каждого водителя свой дневник, и поездки сравниваются только внутри него.
#
# Два ограничения уникальности — два способа узнать повтор:
#   * по `id` — клиент повторил запрос после обрыва связи;
#   * по содержимому — тот же JSON пришёл с другим `id` или вовсе без него. Один водитель не
#     может вести две поездки в одну и ту же секунду, так что это та же поездка.
# Время хранится целым числом микросекунд от начала эпохи в UTC: сравнение идёт по моменту,
# а не по записи, и `08:10+05:00` совпадает с `03:10Z`.
_SCHEMA = (
    """
    CREATE TABLE drivers (
        id TEXT NOT NULL PRIMARY KEY
    ) STRICT
    """,
    """
    CREATE TABLE trips (
        driver_id  TEXT    NOT NULL,
        id         TEXT    NOT NULL,
        start_us   INTEGER NOT NULL,
        end_us     INTEGER NOT NULL,
        amount     INTEGER NOT NULL,
        payment    TEXT    NOT NULL,
        commission INTEGER NOT NULL,
        PRIMARY KEY (driver_id, id),
        UNIQUE (driver_id, start_us, end_us, amount, payment, commission)
    ) STRICT
    """,
)

#: Номер схемы в `PRAGMA user_version`. 0 — пустой файл или база первой версии без водителей.
_SCHEMA_VERSION = 2

_COLUMNS = "id, start_us, end_us, amount, payment, commission"
_INSERT = (
    f"INSERT INTO trips (driver_id, {_COLUMNS}) VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING"
)

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
    """Дневники водителей в файле SQLite.

    Соединение открывается на каждую операцию: так хранилищем можно пользоваться из любого
    потока, а для сервиса такого размера цена открытия незаметна.
    """

    def __init__(self, path: Path) -> None:
        self._path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        with self._open() as db:
            # WAL: чтение сводки не ждёт, пока другой запрос дописывает поездку.
            db.execute("PRAGMA journal_mode = WAL")
            with _transaction(db):
                _migrate(db)

    def register(self, driver: str, initial: Iterable[Trip] = ()) -> bool:
        """Завести дневник водителя; `True` — если его ещё не было.

        Новый дневник сразу получает поездки `initial` — образец. Запись о водителе и его
        поездки появляются одной транзакцией: одновременный запрос того же водителя либо не
        видит дневника вовсе и ждёт, либо видит его целиком, но не наполовину заполненным.
        """
        with self._open() as db:
            # Знакомый водитель — обычный случай, и он обходится чтением, без блокировки записи.
            if db.execute("SELECT 1 FROM drivers WHERE id = ?", (driver,)).fetchone():
                return False
            with _transaction(db):
                created = db.execute(
                    "INSERT INTO drivers (id) VALUES (?) ON CONFLICT DO NOTHING", (driver,)
                ).rowcount
                if created:
                    db.executemany(_INSERT, [(driver, *_to_row(trip)) for trip in initial])
        return bool(created)

    def add(self, driver: str, trip: Trip) -> AddResult:
        """Добавить поездку в дневник водителя; повтор не создаёт вторую запись.

        Вставка — один запрос с `ON CONFLICT DO NOTHING`: одновременные повторы разводит сама
        база. Кто из них записал строку, видно по числу вставленных строк, а остальным остаётся
        выяснить, с чем именно они совпали.
        """
        row = _to_row(trip)
        with self._open() as db:
            if db.execute(_INSERT, (driver, *row)).rowcount:
                return AddResult(AddOutcome.CREATED, trip)

            same_id = db.execute(
                f"SELECT {_COLUMNS} FROM trips WHERE driver_id = ? AND id = ?", (driver, trip.id)
            ).fetchone()
            if same_id is not None:
                stored = _to_trip(same_id)
                outcome = AddOutcome.DUPLICATE if stored.same_ride(trip) else AddOutcome.CONFLICT
                return AddResult(outcome, stored)

            same_ride = db.execute(
                f"SELECT {_COLUMNS} FROM trips WHERE driver_id = ? AND start_us = ?"
                " AND end_us = ? AND amount = ? AND payment = ? AND commission = ?",
                (driver, *row[1:]),
            ).fetchone()

        if same_ride is None:
            # Вставку отклонило ограничение, но совпавшей строки нет. Поездки не удаляются,
            # поэтому такого быть не может; молча вернуть «создано» было бы хуже, чем упасть.
            raise RuntimeError(f"поездка {trip.id!r} не вставлена, но и совпадений нет")
        return AddResult(AddOutcome.DUPLICATE, _to_trip(same_ride))

    def starting_between(self, driver: str, start: datetime, end: datetime) -> list[Trip]:
        """Поездки водителя, начавшиеся в полуинтервале `[start, end)`, по времени начала."""
        with self._open() as db:
            rows = db.execute(
                f"SELECT {_COLUMNS} FROM trips"
                " WHERE driver_id = ? AND start_us >= ? AND start_us < ? ORDER BY start_us, id",
                (driver, _to_microseconds(start), _to_microseconds(end)),
            ).fetchall()
        return [_to_trip(row) for row in rows]

    def starts(self, driver: str) -> list[datetime]:
        """Время начала всех поездок водителя — по нему считается список дней."""
        with self._open() as db:
            rows = db.execute(
                "SELECT start_us FROM trips WHERE driver_id = ? ORDER BY start_us", (driver,)
            ).fetchall()
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


@contextmanager
def _transaction(db: sqlite3.Connection) -> Iterator[None]:
    """Несколько команд как одно целое.

    `IMMEDIATE` берёт блокировку записи сразу: два потока, пришедшие одновременно, встают в
    очередь на входе, а не сталкиваются посреди транзакции.
    """
    db.execute("BEGIN IMMEDIATE")
    try:
        yield
    except BaseException:
        db.execute("ROLLBACK")
        raise
    db.execute("COMMIT")


def _migrate(db: sqlite3.Connection) -> None:
    """Привести файл базы к текущей схеме.

    База первой версии хранила один дневник без водителей. Её поездки не теряются: они
    переходят водителю по умолчанию — тому, чьим дневником и были.
    """
    (version,) = db.execute("PRAGMA user_version").fetchone()
    if version >= _SCHEMA_VERSION:
        return

    had_trips = db.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'trips'"
    ).fetchone()
    if had_trips:
        db.execute("ALTER TABLE trips RENAME TO trips_v1")

    for statement in _SCHEMA:
        db.execute(statement)

    if had_trips:
        db.execute("INSERT INTO drivers (id) VALUES (?)", (DEFAULT_DRIVER,))
        db.execute(
            f"INSERT INTO trips (driver_id, {_COLUMNS}) SELECT ?, {_COLUMNS} FROM trips_v1",
            (DEFAULT_DRIVER,),
        )
        db.execute("DROP TABLE trips_v1")

    db.execute(f"PRAGMA user_version = {_SCHEMA_VERSION}")


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
