.PHONY: help server check docker app app-check apk

help: ## список команд
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

server: ## сервер на http://localhost:8000 (виден и телефону в той же сети)
	cd server && uv run uvicorn shift_diary.main:app --reload --host 0.0.0.0

check: ## все проверки сервера: линтер, формат, типы, тесты
	cd server && uv run ruff check . && uv run ruff format --check . \
		&& uv run mypy shift_diary tests && uv run pytest -q

docker: ## сервер в Docker, без установки Python
	docker compose up --build

app: ## приложение на запущенном эмуляторе, против локального сервера
	cd app && flutter run

app-check: ## все проверки приложения: анализатор и тесты
	cd app && flutter analyze && flutter test

apk: ## релизный APK; адрес сервера: make apk API_BASE_URL=https://…
	cd app && flutter build apk --release --dart-define=API_BASE_URL=$(API_BASE_URL)
