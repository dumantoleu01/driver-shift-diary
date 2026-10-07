from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path
from threading import Barrier

import pytest

from shift_diary.domain.day import day_bounds
from shift_diary.domain.trip import Payment, Trip
from shift_diary.storage import AddOutcome, AddResult, TripStore
from tests.helpers import SERVICE_ZONE, at, ride

#: Сколько одновременных отправок изображают «клиент повторил запрос, пока первый ещё шёл».
RIVALS = 20


@pytest.fixture
def store(tmp_path: Path) -> TripStore:
    return TripStore(tmp_path / "trips.sqlite3")


def stored_ids(store: TripStore, day: date = date(2026, 10, 1)) -> list[str]:
    return [trip.id for trip in store.starting_between(*day_bounds(day, SERVICE_ZONE))]


# --- добавление -----------------------------------------------------------------------------


def test_new_trip_is_created_and_readable(store: TripStore) -> None:
    trip = ride(id="t1")

    result = store.add(trip)

    assert result.outcome is AddOutcome.CREATED
    [stored] = store.starting_between(*day_bounds(date(2026, 10, 1), SERVICE_ZONE))
    assert stored == trip


def test_time_survives_storage_to_the_microsecond(store: TripStore) -> None:
    trip = ride("2026-10-01T08:10:00.123456+05:00", "2026-10-01T08:32:00.654321+05:00")

    store.add(trip)

    [stored] = store.starting_between(*day_bounds(date(2026, 10, 1), SERVICE_ZONE))
    assert stored.start == trip.start
    assert stored.end == trip.end


def test_trips_survive_restart(tmp_path: Path) -> None:
    """Новый экземпляр на том же файле видит прежние поездки — данные лежат на диске."""
    path = tmp_path / "trips.sqlite3"
    TripStore(path).add(ride(id="t1"))

    assert stored_ids(TripStore(path)) == ["t1"]


# --- защита от дублей -----------------------------------------------------------------------


def test_same_trip_twice_is_one_record(store: TripStore) -> None:
    """Повторная отправка той же поездки дубля не создаёт."""
    first = store.add(ride(id="t1"))
    second = store.add(ride(id="t1"))

    assert first.outcome is AddOutcome.CREATED
    assert second.outcome is AddOutcome.DUPLICATE
    assert stored_ids(store) == ["t1"]


def test_same_moment_in_other_notation_is_the_same_trip(store: TripStore) -> None:
    """Повтор, в котором то же время записано в UTC, — всё ещё повтор."""
    store.add(ride("2026-10-01T08:10:00+05:00", "2026-10-01T08:32:00+05:00", id="t1"))

    again = store.add(ride("2026-10-01T03:10:00+00:00", "2026-10-01T03:32:00+00:00", id="t1"))

    assert again.outcome is AddOutcome.DUPLICATE
    assert stored_ids(store) == ["t1"]


def test_same_content_under_new_id_is_one_record(store: TripStore) -> None:
    """Тот же JSON с другим `id` — та же поездка; в ответе прежняя запись с прежним `id`."""
    store.add(ride(id="first"))

    again = store.add(ride(id="second"))

    assert again.outcome is AddOutcome.DUPLICATE
    assert again.trip.id == "first"
    assert stored_ids(store) == ["first"]


@pytest.mark.parametrize(
    "changed",
    [
        ride(id="t1", amount=9900),
        ride(id="t1", commission=1),
        ride(id="t1", payment=Payment.CASH),
        ride("2026-10-01T08:10:00+05:00", "2026-10-01T09:00:00+05:00", id="t1"),
        ride("2026-10-01T08:11:00+05:00", "2026-10-01T08:30:00+05:00", id="t1"),
    ],
    ids=["сумма", "комиссия", "оплата", "конец", "начало"],
)
def test_same_id_with_other_content_is_conflict(store: TripStore, changed: Trip) -> None:
    """Под занятым `id` нельзя ни завести вторую поездку, ни переписать первую."""
    original = ride("2026-10-01T08:10:00+05:00", "2026-10-01T08:30:00+05:00", id="t1")
    store.add(original)

    result = store.add(changed)

    assert result.outcome is AddOutcome.CONFLICT
    assert result.trip == original
    assert store.starting_between(*day_bounds(date(2026, 10, 1), SERVICE_ZONE)) == [original]


def test_different_trips_are_both_kept(store: TripStore) -> None:
    store.add(ride("2026-10-01T08:10:00+05:00", id="t1"))
    store.add(ride("2026-10-01T09:05:00+05:00", id="t2"))

    assert stored_ids(store) == ["t1", "t2"]


def add_at_once(store: TripStore, trips: list[Trip]) -> list[AddResult]:
    """Отправить все поездки одновременно: потоки стартуют по общему сигналу."""
    barrier = Barrier(len(trips))

    def send(trip: Trip) -> AddResult:
        barrier.wait()
        return store.add(trip)

    with ThreadPoolExecutor(max_workers=len(trips)) as pool:
        return list(pool.map(send, trips))


def test_simultaneous_retries_create_one_record(store: TripStore) -> None:
    """Двадцать одновременных повторов одной поездки: создаёт ровно один, остальные — повтор."""
    results = add_at_once(store, [ride(id="t1") for _ in range(RIVALS)])

    outcomes = [result.outcome for result in results]
    assert outcomes.count(AddOutcome.CREATED) == 1
    assert outcomes.count(AddOutcome.DUPLICATE) == RIVALS - 1
    assert stored_ids(store) == ["t1"]


def test_simultaneous_copies_under_different_ids_create_one_record(store: TripStore) -> None:
    """То же, но у каждой копии свой `id`: победивший `id` получают все."""
    results = add_at_once(store, [ride(id=f"copy-{n}") for n in range(RIVALS)])

    outcomes = [result.outcome for result in results]
    assert outcomes.count(AddOutcome.CREATED) == 1
    assert outcomes.count(AddOutcome.DUPLICATE) == RIVALS - 1
    [winner] = stored_ids(store)
    assert {result.trip.id for result in results} == {winner}


# --- выборка за день ------------------------------------------------------------------------


def test_day_takes_trips_from_midnight_to_midnight(store: TripStore) -> None:
    """Полночь входит в новый день, а не в прошедший."""
    store.add(ride("2026-09-30T23:59:59+05:00", id="накануне"))
    store.add(ride("2026-10-01T00:00:00+05:00", id="ровно-в-полночь"))
    store.add(ride("2026-10-01T23:59:59+05:00", id="последняя-секунда"))
    store.add(ride("2026-10-02T00:00:00+05:00", id="уже-завтра"))

    assert stored_ids(store, date(2026, 10, 1)) == ["ровно-в-полночь", "последняя-секунда"]


def test_trip_over_midnight_belongs_to_the_day_it_started(store: TripStore) -> None:
    """Поездка 23:48–00:14 считается один раз — в день начала."""
    store.add(ride("2026-09-30T23:48:00+05:00", "2026-10-01T00:14:00+05:00", id="t13"))

    assert stored_ids(store, date(2026, 9, 30)) == ["t13"]
    assert stored_ids(store, date(2026, 10, 1)) == []


def test_trip_sent_in_utc_lands_on_local_day(store: TripStore) -> None:
    """19:35Z 30 сентября — это 00:35 1 октября у водителя."""
    store.add(ride("2026-09-30T19:35:00+00:00", id="t14"))

    assert stored_ids(store, date(2026, 9, 30)) == []
    assert stored_ids(store, date(2026, 10, 1)) == ["t14"]


def test_day_is_sorted_by_start(store: TripStore) -> None:
    store.add(ride("2026-10-01T19:05:00+05:00", id="вечер"))
    store.add(ride("2026-10-01T00:35:00+05:00", id="ночь"))
    store.add(ride("2026-10-01T08:10:00+05:00", id="утро"))

    assert stored_ids(store) == ["ночь", "утро", "вечер"]


def test_empty_day_is_empty_list(store: TripStore) -> None:
    assert stored_ids(store) == []


def test_starts_lists_every_trip(store: TripStore) -> None:
    store.add(ride("2026-10-01T08:10:00+05:00", id="t1"))
    store.add(ride("2026-09-30T23:48:00+05:00", id="t13"))

    assert store.starts() == [at("2026-09-30T23:48:00+05:00"), at("2026-10-01T08:10:00+05:00")]
