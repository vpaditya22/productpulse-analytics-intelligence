from productpulse.synthetic import generate_records


def test_synthetic_generator_is_deterministic_and_labeled():
    first = generate_records(seed=7, customers=12)
    second = generate_records(seed=7, customers=12)
    assert first == second
    assert len(first["customers"]) == 12
    assert all(row["is_synthetic"] is True for row in first["customers"])


def test_event_and_experiment_rows_reference_customers():
    tables = generate_records(seed=9, customers=25)
    ids = {row["customer_id"] for row in tables["customers"]}
    assert all(row["customer_id"] in ids for row in tables["events"])
    assert all(row["customer_id"] in ids for row in tables["experiment_assignments"])
    assert {row["variant"] for row in tables["experiment_assignments"]} <= {"control", "treatment"}
