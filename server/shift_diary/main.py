"""Точка входа: `uvicorn shift_diary.main:app`."""

import logging

from shift_diary.api import create_app

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")

app = create_app()
