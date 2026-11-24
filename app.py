"""ProductPulse Streamlit dashboard."""

from __future__ import annotations

import streamlit as st
import plotly.express as px

from productpulse.analytics import query_df, two_proportion_test

st.set_page_config(page_title="ProductPulse | Product Analytics", page_icon="📈", layout="wide")
st.title("📈 ProductPulse")
st.caption("Product analytics & growth intelligence · PostgreSQL-backed portfolio demo")

try:
    kpis = query_df("""
        SELECT (SELECT COUNT(*) FROM customers) customers,
               (SELECT COUNT(DISTINCT customer_id) FROM events WHERE occurred_at >= CURRENT_DATE - INTERVAL '30 days') mau_30d,
               (SELECT COUNT(*) FROM subscriptions WHERE status='active') paid_customers,
               (SELECT COALESCE(SUM(monthly_price),0) FROM subscriptions WHERE status='active') mrr
    """)
    a, b, c, d = st.columns(4)
    a.metric("Synthetic customers", f"{int(kpis.customers.iloc[0]):,}")
    b.metric("Active in last 30 days", f"{int(kpis.mau_30d.iloc[0]):,}")
    c.metric("Active subscriptions", f"{int(kpis.paid_customers.iloc[0]):,}")
    d.metric("Monthly recurring revenue", f"${float(kpis.mrr.iloc[0]):,.0f}")

    left, right = st.columns(2)
    with left:
        st.subheader("Activation funnel")
        funnel = query_df("""
            SELECT step,users FROM (
              SELECT 1 sort,'Signed up' step,COUNT(DISTINCT customer_id) users FROM events WHERE event_name='signup'
              UNION ALL SELECT 2,'Completed onboarding',COUNT(DISTINCT customer_id) FROM events WHERE event_name='onboarding_complete'
              UNION ALL SELECT 3,'Created a project',COUNT(DISTINCT customer_id) FROM events WHERE event_name='project_created'
            ) x ORDER BY sort
        """)
        st.plotly_chart(px.funnel(funnel, x="users", y="step", title="Signup → activation"), use_container_width=True)
    with right:
        st.subheader("Monthly acquisition")
        signups = query_df("SELECT date_trunc('month',created_at)::date month,acquisition_channel,COUNT(*) signups FROM customers GROUP BY 1,2 ORDER BY 1")
        st.plotly_chart(px.bar(signups, x="month", y="signups", color="acquisition_channel", title="New customers by channel"), use_container_width=True)

    left, right = st.columns(2)
    with left:
        st.subheader("Monthly active users")
        mau = query_df("SELECT date_trunc('month',occurred_at)::date month,COUNT(DISTINCT customer_id) mau FROM events GROUP BY 1 ORDER BY 1")
        st.plotly_chart(px.line(mau, x="month", y="mau", markers=True), use_container_width=True)
    with right:
        st.subheader("Feature adoption")
        features = query_df("SELECT feature_name,COUNT(DISTINCT customer_id) users FROM events WHERE event_name='feature_used' GROUP BY 1 ORDER BY 2 DESC")
        st.plotly_chart(px.bar(features, x="users", y="feature_name", orientation="h"), use_container_width=True)

    st.subheader("Retention by signup cohort")
    retention = query_df("""
        WITH activity AS (
          SELECT DISTINCT date_trunc('month',c.created_at)::date cohort,
            ((EXTRACT(YEAR FROM e.occurred_at)-EXTRACT(YEAR FROM c.created_at))*12 +
             EXTRACT(MONTH FROM e.occurred_at)-EXTRACT(MONTH FROM c.created_at))::int age,
            c.customer_id FROM customers c JOIN events e USING(customer_id)
        ), sizes AS (SELECT date_trunc('month',created_at)::date cohort,COUNT(*) n FROM customers GROUP BY 1)
        SELECT a.cohort,a.age,ROUND(COUNT(*)::numeric/s.n,3) retention
        FROM activity a JOIN sizes s USING(cohort) GROUP BY 1,2,s.n ORDER BY 1,2
    """)
    if not retention.empty:
        heat = retention.pivot(index="cohort", columns="age", values="retention")
        st.dataframe(heat.style.format("{:.0%}").background_gradient(cmap="Blues", axis=None), use_container_width=True)

    st.subheader("A/B experiment: onboarding conversion")
    experiment = query_df("SELECT variant,COUNT(*) assigned,COUNT(*) FILTER(WHERE converted) converted FROM experiment_assignments WHERE experiment_id='EXP_ONBOARDING_01' GROUP BY 1 ORDER BY 1")
    if set(experiment.variant) == {"control", "treatment"}:
        counts = experiment.set_index("variant")
        result = two_proportion_test(int(counts.loc["control", "converted"]), int(counts.loc["control", "assigned"]),
                                     int(counts.loc["treatment", "converted"]), int(counts.loc["treatment", "assigned"]))
        x, y, z = st.columns(3)
        x.metric("Control conversion", f"{result['control_rate']:.1%}")
        y.metric("Treatment conversion", f"{result['treatment_rate']:.1%}", f"{result['absolute_lift']:+.1%}")
        z.metric("Two-sided p-value", f"{result['p_value']:.3f}", "Significant at 5%" if result["significant_95"] else "Not significant at 5%")
        st.caption("Two-sided pooled two-proportion z-test; interpret as an educational demo, not a launch decision.")
        st.dataframe(experiment, hide_index=True, use_container_width=True)
except Exception as exc:  # Streamlit should show friendly setup guidance for database failures.
    st.warning("Connect the PostgreSQL database to explore the dashboard.")
    st.code("docker compose up -d postgres\npython -m productpulse.etl --generate --load\nstreamlit run app.py")
    st.caption(f"Connection detail: {exc}")
