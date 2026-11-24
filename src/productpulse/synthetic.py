"""Deterministic, explicitly synthetic product analytics data generator."""

from __future__ import annotations

import csv
import random
from datetime import UTC, date, datetime, time, timedelta
from pathlib import Path
from typing import Any

SEED = 20261124
START = date(2025, 1, 1)
END = date(2025, 6, 30)
PLANS = (("free", 0), ("starter", 19), ("growth", 59), ("scale", 149))
CHANNELS = ("organic", "paid_search", "referral", "social", "content")
FEATURES = ("dashboard", "collaboration", "automation", "integrations", "reports")
EVENTS = ("signup", "onboarding_complete", "project_created", "invite_sent", "feature_used", "subscription_started", "purchase")


def generate_records(seed: int = SEED, customers: int = 300) -> dict[str, list[dict[str, Any]]]:
    """Generate stable demo tables; every row is fictional and not user data."""
    rng = random.Random(seed)
    customer_rows: list[dict[str, Any]] = []
    event_rows: list[dict[str, Any]] = []
    subscription_rows: list[dict[str, Any]] = []
    experiment_rows: list[dict[str, Any]] = []
    for i in range(1, customers + 1):
        customer_id = f"C{i:05d}"
        created = START + timedelta(days=rng.randrange((END - START).days + 1))
        channel = rng.choice(CHANNELS)
        plan, price = rng.choices(PLANS, weights=(48, 25, 20, 7))[0]
        customer_rows.append({"customer_id": customer_id, "created_at": created.isoformat(), "acquisition_channel": channel,
                              "country": rng.choice(("US", "GB", "IN", "CA", "DE")), "plan": plan,
                              "is_synthetic": True})
        signup_at = datetime.combine(created, time(9 + rng.randrange(10), rng.randrange(60)), tzinfo=UTC)
        user_events = [("signup", signup_at)]
        if rng.random() < 0.76:
            user_events.append(("onboarding_complete", signup_at + timedelta(hours=rng.randrange(2, 48))))
        if rng.random() < 0.62:
            user_events.append(("project_created", signup_at + timedelta(days=rng.randrange(0, 8))))
        for _ in range(rng.randrange(2, 19)):
            event_date = min(END, created + timedelta(days=rng.randrange(0, max(1, (END - created).days + 1))))
            event_name = rng.choice(EVENTS[2:5] + ("feature_used", "feature_used", "purchase"))
            user_events.append((event_name, datetime.combine(event_date, time(rng.randrange(24), rng.randrange(60)), tzinfo=UTC)))
        for event_index, (event_name, occurred_at) in enumerate(user_events, 1):
            event_rows.append({"event_id": f"E{i:05d}-{event_index:03d}", "customer_id": customer_id,
                               "event_name": event_name, "occurred_at": occurred_at.isoformat(),
                               "feature_name": rng.choice(FEATURES) if event_name == "feature_used" else ""})
        if plan != "free":
            cancelled = rng.random() < 0.18
            ended_at = min(END, created + timedelta(days=rng.randrange(14, 181))) if cancelled else None
            subscription_rows.append({"subscription_id": f"S{i:05d}", "customer_id": customer_id,
                                      "started_at": created.isoformat(), "ended_at": ended_at.isoformat() if ended_at else "", "plan": plan,
                                      "monthly_price": price, "status": "cancelled" if cancelled else "active"})
        variant = "treatment" if rng.random() < 0.5 else "control"
        converted = rng.random() < (0.145 if variant == "treatment" else 0.12)
        experiment_rows.append({"experiment_id": "EXP_ONBOARDING_01", "customer_id": customer_id,
                                "variant": variant, "exposed_at": signup_at.isoformat(), "converted": converted})
    return {"customers": customer_rows, "events": event_rows,
            "subscriptions": subscription_rows, "experiment_assignments": experiment_rows}


def write_csvs(output_dir: str | Path, seed: int = SEED, customers: int = 300) -> dict[str, int]:
    """Write deterministic CSV extracts and return row counts by table."""
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    tables = generate_records(seed=seed, customers=customers)
    for name, rows in tables.items():
        path = output / f"{name}.csv"
        fields = list(rows[0]) if rows else []
        with path.open("w", newline="", encoding="utf-8") as file:
            writer = csv.DictWriter(file, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)
    return {name: len(rows) for name, rows in tables.items()}
