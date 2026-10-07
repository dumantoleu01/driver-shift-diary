import json
from datetime import date
from pathlib import Path

import pytest

from shift_diary.domain.day import count_by_day
from shift_diary.seed import load_seed
from shift_diary.storage import TripStore
from tests.helpers import SERVICE_ZONE

SAMPLE = Path(__file__).resolve().parents[2] / "data" / "trips.json"

T1 = {
    "id": "t1",
    "start": "2026-10-01T08:10:00+05:00",
    "end": "2026-10-01T08:32:00+05:00",
    "amount": 2400,
    "payment": "card",
    "commission": 360,
}


@pytest.fixture
def store(tmp_path: Path) -> TripStore:
    return TripStore(tmp_path / "trips.sqlite3")


def write(tmp_path: Path, content: object) -> Path:
    path = tmp_path / "seed.json"
    path.write_text(json.dumps(content), encoding="utf-8")
    return path


def test_sample_file_loads_completely(store: TripStore) -> None:
    """Образец из репозитория проходит ту же проверку, что и запросы, без единого отказа."""
    report = load_seed(SAMPLE, store)

    assert report.created == 27
    assert report.rejected == []
    assert count_by_day(store.starts(), SERVICE_ZONE) == {
        date(2026, 9, 29): 5,
        date(2026, 9, 30): 6,
        date(2026, 10, 1): 6,
        date(2026, 10, 3): 4,
        date(2026, 10, 4): 6,
    }


def test_loading_twice_adds_nothing(store: TripStore) -> None:
    """Образец читается при каждом запуске сервера — второй раз он ничего не удваивает."""
    load_seed(SAMPLE, store)

    again = load_seed(SAMPLE, store)

    assert again.created == 0
    assert again.duplicates == 27
    assert len(store.starts()) == 27


def test_records_without_id_are_not_doubled_either(tmp_path: Path, store: TripStore) -> None:
    """Без `id` сервер назначает новый при каждой загрузке — спасает совпадение по содержимому."""
    record = {key: value for key, value in T1.items() if key != "id"}
    path = write(tmp_path, [record])

    load_seed(path, store)
    again = load_seed(path, store)

    assert again.duplicates == 1
    assert len(store.starts()) == 1


def test_bad_record_is_skipped_and_reported(tmp_path: Path, store: TripStore) -> None:
    path = write(tmp_path, [T1, {**T1, "id": "t2", "amount": 0}, "мусор"])

    report = load_seed(path, store)

    assert report.created == 1
    assert len(report.rejected) == 2
    assert "запись 2" in report.rejected[0]
    assert "must_be_positive" in report.rejected[0]
    assert "запись 3" in report.rejected[1]


def test_same_id_with_other_content_is_reported(tmp_path: Path, store: TripStore) -> None:
    path = write(tmp_path, [T1, {**T1, "amount": 9900}])

    report = load_seed(path, store)

    assert report.created == 1
    assert len(report.rejected) == 1
    assert "занят" in report.rejected[0]


def test_file_with_bom_is_still_valid(tmp_path: Path, store: TripStore) -> None:
    """Редактор мог сохранить файл с меткой BOM — от этого он не перестал быть JSON."""
    path = tmp_path / "seed.json"
    path.write_text(json.dumps([T1]), encoding="utf-8-sig")

    assert load_seed(path, store).created == 1


@pytest.mark.parametrize("content", ['{"id": "t1"}', "не json", ""])
def test_unreadable_file_stops_startup(tmp_path: Path, store: TripStore, content: str) -> None:
    """Сервер с пустой базой вместо данных выглядел бы исправным — лучше не запускаться."""
    path = tmp_path / "seed.json"
    path.write_text(content, encoding="utf-8")

    with pytest.raises(ValueError, match="образец"):
        load_seed(path, store)


def test_missing_file_stops_startup(tmp_path: Path, store: TripStore) -> None:
    with pytest.raises(ValueError, match="образец"):
        load_seed(tmp_path / "нет-такого.json", store)
