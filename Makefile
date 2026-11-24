.PHONY: install db-up db-down seed run test lint

install:
	python -m pip install -e ".[dev]"

db-up:
	docker compose up -d postgres

db-down:
	docker compose down

seed:
	python -m productpulse.etl --generate --load

run:
	streamlit run app.py

test:
	pytest -q

lint:
	ruff check src tests app.py
