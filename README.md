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

Requirements: Python 3.11+, Docker Desktop with Compose, and the three project languages/technologies: Python, SQL, PostgreSQL. Python packages provide the dashboard and database driver.

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -e ".[dev]"
docker compose up -d postgres
Copy-Item .env.example .env
python -m productpulse.etl --generate --load
streamlit run app.py
```

Open the local Streamlit URL shown in the terminal. The database credentials in Compose are for local learning only; change them before using a shared or hosted environment.

## ETL and reproducibility

Generate the default CSVs without loading a database:

```powershell
python -m productpulse.etl --generate
```

The outputs go to `data/generated/` (ignored by Git); `--seed` and `--customers` customize the run. The same seed and customer count produce the same records:

```powershell
python -m productpulse.etl --generate --seed 20261124 --customers 300
python -m productpulse.etl --load
```

Loading applies `sql/schema.sql`, then replaces the demo tables in a single transaction. The customer `is_synthetic` column explicitly labels the generated data.

## Data model

| Table | Grain | Key relationships |
| --- | --- | --- |
| `customers` | One row per acquired customer | Primary key `customer_id` |
| `events` | One row per product event | Foreign key to customers; indexed by customer/time and event/time |
| `subscriptions` | One row per subscription | Foreign key to customers; stores plan, price, status |
| `experiment_assignments` | One row per experiment/customer | Composite primary key; control/treatment assignment and conversion |

The schema and indexes are in [`sql/schema.sql`](sql/schema.sql). The 55 standalone, labeled SQL examples are in [`sql/analytics.sql`](sql/analytics.sql). They use PostgreSQL features such as filtered aggregates, window functions, `date_trunc`, percentiles, and CTEs.

## Experiment method

The dashboard compares a two-sided pooled two-proportion z-test for control and treatment conversion. It shows absolute and relative lift, z-score, and p-value with a 5% threshold. The SQL library also includes a 50/50 sample-ratio mismatch diagnostic. This fixed-seed, modest synthetic sample is only for demonstrating analysis; check randomization, exposure definitions, power, guardrails, and practical impact before making a real product decision.

## Tests and checks

```powershell
pytest -q
ruff check src tests app.py
```

The automated tests do not require a running PostgreSQL server. To validate a local database end-to-end, run the ETL command and inspect row counts with `psql` or the dashboard.

## Project layout

```text
app.py                         Streamlit dashboard
src/productpulse/synthetic.py  Deterministic fictional data generator
src/productpulse/etl.py        PostgreSQL schema apply and CSV loader
src/productpulse/analytics.py  Read-only query helper and experiment test
sql/schema.sql                 Relational schema and indexes
sql/analytics.sql              55 business analytics queries
tests/                         Unit and asset-coverage tests
docker-compose.yml             Local PostgreSQL service
```

## Resume-ready description

Built ProductPulse, a PostgreSQL product analytics platform using Python ETL and Streamlit; modeled customer, event, subscription, and experiment data; wrote 55 advanced SQL analyses for funnels, cohorts, retention, revenue, feature adoption, and experiments; and added deterministic synthetic data, validation tests, and query-focused indexes.
