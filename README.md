# ProductPulse — Product Analytics & Growth Intelligence

ProductPulse is an end-to-end product analytics portfolio project built with **Python, SQL, and PostgreSQL**. It models product behavior, loads reproducible synthetic data, answers 55 business questions in PostgreSQL, and presents key results in a Streamlit dashboard.

> **Demo data notice:** Every included/generated record is fictional and generated locally with a fixed random seed. It is not customer data and must not be presented as real company evidence. The default generator creates 300 synthetic customers with acquisition, product events, subscriptions, and experiment assignments spanning January–June 2025.

## What it demonstrates

- Relational modeling, primary/foreign keys, checks, and workload-aware indexes.
- A repeatable Python ETL flow that generates CSV extracts and transactionally loads PostgreSQL.
- 55 documented PostgreSQL analyses: acquisition, funnels, cohort retention, DAU/WAU/MAU, revenue, ARPPU, LTV proxy, churn, feature adoption, A/B testing and a sample-ratio diagnostic.
- A Streamlit dashboard for KPIs, acquisition, activity, retention, feature adoption, and experiment interpretation.
- Automated tests for deterministic data generation, relational consistency, SQL coverage, and experiment statistics.

## Quick start

Requirements: Python 3.11+, Docker Desktop with Compose.

```powershell
python -m venv .venv
.venv\\Scripts\\Activate.ps1
python -m pip install -e ".[dev]"
docker compose up -d postgres
Copy-Item .env.example .env
python -m productpulse.etl --generate --load
streamlit run app.py
```

See the project files for schema, analytics, ETL, and validation details. All demo rows are synthetic.