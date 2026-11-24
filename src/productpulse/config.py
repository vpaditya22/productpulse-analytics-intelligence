"""Environment-backed application configuration."""

from __future__ import annotations

import os


def database_url() -> str:
    """Return the PostgreSQL connection URL or a helpful setup error."""
    value = os.getenv("DATABASE_URL")
    if not value:
        raise RuntimeError("DATABASE_URL is missing. Copy .env.example to .env and set it.")
    if not value.startswith(("postgresql://", "postgres://")):
        raise ValueError("ProductPulse requires a PostgreSQL DATABASE_URL.")
    return value
