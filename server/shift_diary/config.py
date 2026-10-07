"""Настройки сервера из переменных окружения."""

import os
from dataclasses import dataclass
from pathlib import Path

_SERVER_DIR = Path(__file__).resolve().parent.parent


@dataclass(frozen=True, slots=True)
class Settings:
    #: Файл базы. Создаётся при первом запуске.
    db_path: Path
    #: Файл с образцом поездок; `None` — запуск с пустой базой.
    seed_path: Path | None
    #: Пояс сервиса: по нему определяется, к какому дню относится поездка.
    utc_offset: str = "+05:00"

    @classmethod
    def from_env(cls) -> "Settings":
        """Настройки запуска. Без переменных окружения сервер работает из папки репозитория."""
        seed = os.environ.get("SHIFT_DIARY_SEED", str(_SERVER_DIR.parent / "data" / "trips.json"))
        return cls(
            db_path=Path(os.environ.get("SHIFT_DIARY_DB", _SERVER_DIR / "var" / "trips.sqlite3")),
            # Пустая строка — явный отказ от образца.
            seed_path=Path(seed) if seed else None,
            utc_offset=os.environ.get("SHIFT_DIARY_UTC_OFFSET", "+05:00"),
        )
