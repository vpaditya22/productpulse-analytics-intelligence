from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_schema_has_relational_constraints_and_indexes():
    schema = (ROOT / "sql" / "schema.sql").read_text().lower()
    assert "references customers(customer_id)" in schema
    assert "primary key (experiment_id, customer_id)" in schema
    assert schema.count("create index") >= 5


def test_analytics_library_has_at_least_50_labeled_queries():
    queries = (ROOT / "sql" / "analytics.sql").read_text()
    labels = [line for line in queries.splitlines() if line.startswith("-- Q")]
    assert len(labels) >= 50
