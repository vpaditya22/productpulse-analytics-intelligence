"""Environment-backed application configuration."""

from __future__ import annotations

import os
from pathlib import Path


def database_url() -> str:
    """Return the PostgreSQL connection URL or a helpful setup error."""
    value = os.getenv("DATABASE_URL")
    if not value:
        env_file = Path(__file__).resolve().parents[2] / ".env"
        if env_file.is_file():
            for line in env_file.read_text(encoding="utf-8").splitlines():
                key, separator, candidate = line.partition("=")
                if separator and key.strip() == "DATABASE_URL":
                    value = candidate.strip().strip("\"'")
                    break
    if not value:
        raise RuntimeError("DATABASE_URL is missing. Copy .env.example to .env and set it.")
    if not value.startswith(("postgresql://", "postgres://")):
        raise ValueError("ProductPulse requires a PostgreSQL DATABASE_URL.")
    return value
