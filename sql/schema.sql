-- ProductPulse relational model. Synthetic records are marked on customers.
CREATE TABLE IF NOT EXISTS customers (
    customer_id TEXT PRIMARY KEY,
    created_at DATE NOT NULL,
    acquisition_channel TEXT NOT NULL,
    country CHAR(2) NOT NULL,
    plan TEXT NOT NULL CHECK (plan IN ('free', 'starter', 'growth', 'scale')),
    is_synthetic BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS events (
    event_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    event_name TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    feature_name TEXT
);

CREATE TABLE IF NOT EXISTS subscriptions (
    subscription_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    started_at DATE NOT NULL,
    ended_at DATE,
    plan TEXT NOT NULL,
    monthly_price NUMERIC(10, 2) NOT NULL CHECK (monthly_price >= 0),
    status TEXT NOT NULL CHECK (status IN ('active', 'cancelled', 'past_due'))
);

CREATE TABLE IF NOT EXISTS experiment_assignments (
    experiment_id TEXT NOT NULL,
    customer_id TEXT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    variant TEXT NOT NULL CHECK (variant IN ('control', 'treatment')),
    exposed_at TIMESTAMPTZ NOT NULL,
    converted BOOLEAN NOT NULL,
    PRIMARY KEY (experiment_id, customer_id)
);

CREATE INDEX IF NOT EXISTS idx_events_customer_time ON events(customer_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_name_time ON events(event_name, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_customers_created_channel ON customers(created_at, acquisition_channel);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status_started ON subscriptions(status, started_at);
CREATE INDEX IF NOT EXISTS idx_experiment_variant ON experiment_assignments(experiment_id, variant);

ANALYZE customers;
ANALYZE events;
ANALYZE subscriptions;
