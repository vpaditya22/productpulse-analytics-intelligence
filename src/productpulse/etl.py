"""Generate synthetic CSVs and load them into PostgreSQL."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from productpulse.config import database_url
from productpulse.synthetic import write_csvs

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATA_DIR = ROOT / "data" / "generated"
SCHEMA = ROOT / "sql" / "schema.sql"
TABLE_COLUMNS = {
    "customers": ("customer_id", "created_at", "acquisition_channel", "country", "plan", "is_synthetic"),
    "events": ("event_id", "customer_id", "event_name", "occurred_at", "feature_name"),
    "subscriptions": ("subscription_id", "customer_id", "started_at", "ended_at", "plan", "monthly_price", "status"),
    "experiment_assignments": ("experiment_id", "customer_id", "variant", "exposed_at", "converted"),
}


def load_csvs(data_dir: str | Path = DEFAULT_DATA_DIR, url: str | None = None) -> dict[str, int]:
    """Create tables and transactionally replace them from generated CSV files."""
    import psycopg
    from psycopg import sql

    counts: dict[str, int] = {}
    with psycopg.connect(url or database_url()) as conn:
        conn.execute(SCHEMA.read_text(encoding="utf-8"))
        conn.execute("TRUNCATE experiment_assignments, events, subscriptions, customers CASCADE")
        for table, columns in TABLE_COLUMNS.items():
            file_path = Path(data_dir) / f"{table}.csv"
            if not file_path.is_file():
                raise FileNotFoundError(f"Missing {file_path}; run with --generate first.")
            with file_path.open(newline="", encoding="utf-8") as csv_file:
                query = sql.SQL("COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE)").format(
                    sql.Identifier(table), sql.SQL(", ").join(map(sql.Identifier, columns))
                )
                # PostgreSQL COPY protocol streams rows without loading a full file into memory.
                with conn.cursor().copy(query) as copy:
                    copy.write(csv_file.read().encode("utf-8"))
            with file_path.open(newline="", encoding="utf-8") as count_file:
                counts[table] = sum(1 for _ in csv.DictReader(count_file))
        conn.execute("ANALYZE customers; ANALYZE events; ANALYZE subscriptions; ANALYZE experiment_assignments;")
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate", action="store_true", help="regenerate reproducible synthetic CSV files")
    parser.add_argument("--load", action="store_true", help="load generated CSV files into PostgreSQL")
    parser.add_argument("--customers", type=int, default=300, help="number of synthetic customers (default: 300)")
    parser.add_argument("--seed", type=int, default=20261124, help="random seed (default: 20261124)")
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    args = parser.parse_args()
    if not args.generate and not args.load:
        parser.error("choose --generate, --load, or both")
    if args.generate:
        counts = write_csvs(args.data_dir, seed=args.seed, customers=args.customers)
        print(f"Generated synthetic demo tables in {args.data_dir}: {counts}")
    if args.load:
        print(f"Loaded rows: {load_csvs(args.data_dir)}")


if __name__ == "__main__":
    main()
