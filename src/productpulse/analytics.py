"""Reusable PostgreSQL analytics and experiment calculations."""

from __future__ import annotations

import math
from numbers import Integral

import pandas as pd


def query_df(query: str, params: tuple = (), url: str | None = None) -> pd.DataFrame:
    """Run a read-only analytics query and return a dataframe."""
    import psycopg

    from productpulse.config import database_url

    try:
        with psycopg.connect(url or database_url(), options="-c default_transaction_read_only=on") as conn, conn.cursor() as cur:
            cur.execute(query, params)
            columns = [field.name for field in cur.description]
            return pd.DataFrame(cur.fetchall(), columns=columns)
    except psycopg.Error as exc:
        raise RuntimeError("PostgreSQL query failed; check the database and schema.") from exc


def two_proportion_test(control_converted: int, control_total: int,
                        treatment_converted: int, treatment_total: int) -> dict[str, float | bool]:
    """Two-sided pooled z-test for independent conversion proportions."""
    counts = {
        "control_converted": control_converted,
        "control_total": control_total,
        "treatment_converted": treatment_converted,
        "treatment_total": treatment_total,
    }
    if any(isinstance(value, bool) or not isinstance(value, Integral) for value in counts.values()):
        raise TypeError("Experiment counts must be integers.")
    if min(control_converted, treatment_converted) < 0 or min(control_total, treatment_total) <= 0:
        raise ValueError("Counts must be non-negative and sample sizes must be positive.")
    if control_converted > control_total or treatment_converted > treatment_total:
        raise ValueError("Conversions cannot exceed assigned users.")
    p0 = control_converted / control_total
    p1 = treatment_converted / treatment_total
    pooled = (control_converted + treatment_converted) / (control_total + treatment_total)
    se = math.sqrt(pooled * (1 - pooled) * (1 / control_total + 1 / treatment_total))
    z = 0.0 if se == 0 else (p1 - p0) / se
    p_value = math.erfc(abs(z) / math.sqrt(2))
    return {"control_rate": p0, "treatment_rate": p1, "absolute_lift": p1 - p0,
            "relative_lift": ((p1 / p0) - 1) if p0 else math.nan,
            "z_score": z, "p_value": p_value, "significant_95": p_value < 0.05}
