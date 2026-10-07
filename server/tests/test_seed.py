import json
from pathlib import Path

import pytest

from shift_diary.seed import read_sample

SAMPLE = Path(__file__).resolve().parents[2] / "data" / "trips.json"

T1 = {
    "id": "t1",
    "start": "2026-10-01T08:10:00+05:00",
    "end": "2026-10-01T08:32:00+05:00",
    "amount": 2400,
    "payment": "card",
    "commission": 360,
}


def write(tmp_path: Path, content: object) -> Path:
    path = tmp_path / "seed.json"
    path.write_text(json.dumps(content), encoding="utf-8")
    return path


def test_sample_file_is_accepted_completely() -> None:
    """Образец из репозитория проходит ту же проверку, что и запросы, без единого отказа."""
    sample = read_sample(SAMPLE)

    assert len(sample.trips) == 27
    assert sample.duplicates == 0
    assert sample.rejected == ()
    assert {"t1", "t2", "t13", "t14"} <= {trip.id for trip in sample.trips}


def test_bad_record_is_skipped_and_reported(tmp_path: Path) -> None:
    sample = read_sample(write(tmp_path, [T1, {**T1, "id": "t2", "amount": 0}, "мусор"]))

    assert [trip.id for trip in sample.trips] == ["t1"]
    assert len(sample.rejected) == 2
    assert "запись 2" in sample.rejected[0]
    assert "must_be_positive" in sample.rejected[0]
    assert "запись 3" in sample.rejected[1]


def test_repeated_record_is_taken_once(tmp_path: Path) -> None:
    """Повтор в самом файле — по `id` или по содержимому — не становится второй поездкой."""
    sample = read_sample(write(tmp_path, [T1, T1, {**T1, "id": "copy"}]))

    assert [trip.id for trip in sample.trips] == ["t1"]
    assert sample.duplicates == 2
    assert sample.rejected == ()


def test_same_id_with_other_content_is_reported(tmp_path: Path) -> None:
    sample = read_sample(write(tmp_path, [T1, {**T1, "amount": 9900}]))

    assert [trip.amount for trip in sample.trips] == [2400]
    assert len(sample.rejected) == 1
    assert "занят" in sample.rejected[0]


def test_record_without_id_gets_one(tmp_path: Path) -> None:
    record = {key: value for key, value in T1.items() if key != "id"}

    [trip] = read_sample(write(tmp_path, [record])).trips

    assert trip.id


def test_file_with_bom_is_still_valid(tmp_path: Path) -> None:
    """Редактор мог сохранить файл с меткой BOM — от этого он не перестал быть JSON."""
    path = tmp_path / "seed.json"
    path.write_text(json.dumps([T1]), encoding="utf-8-sig")

    assert len(read_sample(path).trips) == 1


@pytest.mark.parametrize("content", ['{"id": "t1"}', "не json", ""])
def test_unreadable_file_stops_startup(tmp_path: Path, content: str) -> None:
    """Сервер с пустыми дневниками вместо данных выглядел бы исправным — лучше не запускаться."""
    path = tmp_path / "seed.json"
    path.write_text(content, encoding="utf-8")

    with pytest.raises(ValueError, match="образец"):
        read_sample(path)


def test_missing_file_stops_startup(tmp_path: Path) -> None:
    with pytest.raises(ValueError, match="образец"):
        read_sample(tmp_path / "нет-такого.json")
