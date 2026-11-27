import pytest

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


def test_paid_demo_data_has_active_and_cancelled_subscriptions():
    statuses = {row["status"] for row in generate_records(seed=20261124, customers=300)["subscriptions"]}
    assert statuses == {"active", "cancelled"}


@pytest.mark.parametrize(
    ("customers", "error"),
    [(0, ValueError), (-1, ValueError), (1.5, TypeError), (True, TypeError), ("12", TypeError)],
)
def test_synthetic_generator_rejects_invalid_customer_counts(customers, error):
    with pytest.raises(error, match="customers must"):
        generate_records(customers=customers)


@pytest.mark.parametrize("seed", [True, 1.5, "not-an-integer"])
def test_synthetic_generator_rejects_invalid_seeds(seed):
    with pytest.raises(TypeError, match="seed must be an integer"):
        generate_records(seed=seed)
