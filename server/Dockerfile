# Сервер дневника смен. Собирается из корня репозитория (нужна папка data/):
#   docker compose up --build
FROM python:3.13-slim

# Та же версия uv, что в разработке и в CI: зависимости ставятся строго по uv.lock.
COPY --from=ghcr.io/astral-sh/uv:0.12.0 /uv /usr/local/bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1

WORKDIR /app/server

# Зависимости — отдельным слоем: правка кода не переустанавливает их заново.
COPY server/pyproject.toml server/uv.lock server/.python-version ./
RUN uv sync --frozen --no-dev

COPY server/shift_diary ./shift_diary
COPY data /app/data

# Сервер не работает от root; писать ему нужно только в папку с базой.
RUN useradd --system --no-create-home shiftdiary \
    && mkdir -p /var/lib/shift-diary \
    && chown shiftdiary /var/lib/shift-diary
USER shiftdiary

ENV PATH="/app/server/.venv/bin:$PATH" \
    SHIFT_DIARY_SEED=/app/data/trips.json \
    SHIFT_DIARY_DB=/var/lib/shift-diary/trips.sqlite3

EXPOSE 8000

# Порт берётся из PORT: хостинг назначает его сам, локально остаётся 8000.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD python -c "import os, urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.environ.get(\"PORT\", \"8000\")}/health')"

CMD ["sh", "-c", "exec uvicorn shift_diary.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
