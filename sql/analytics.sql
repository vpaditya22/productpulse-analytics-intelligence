-- 50+ portfolio-ready PostgreSQL business questions.
-- Run any numbered SELECT independently after applying schema.sql and loading demo data.

-- Q01: Activation funnel, overall
SELECT COUNT(DISTINCT customer_id) FILTER (WHERE event_name='signup') AS signups,
       COUNT(DISTINCT customer_id) FILTER (WHERE event_name='onboarding_complete') AS onboarded,
       COUNT(DISTINCT customer_id) FILTER (WHERE event_name='project_created') AS created_project
FROM events;

-- Q02: Daily signups
SELECT created_at, COUNT(*) AS signups FROM customers GROUP BY 1 ORDER BY 1;

-- Q03: Weekly active users (WAU)
SELECT date_trunc('week', occurred_at)::date AS week, COUNT(DISTINCT customer_id) AS wau
FROM events GROUP BY 1 ORDER BY 1;

-- Q04: Monthly active users (MAU)
SELECT date_trunc('month', occurred_at)::date AS month, COUNT(DISTINCT customer_id) AS mau
FROM events GROUP BY 1 ORDER BY 1;

-- Q05: New customer acquisition by channel
SELECT acquisition_channel, COUNT(*) AS customers FROM customers GROUP BY 1 ORDER BY 2 DESC;

-- Q06: Signup-to-onboarding conversion by acquisition channel
SELECT c.acquisition_channel, COUNT(*) AS signups,
       COUNT(*) FILTER (WHERE e.customer_id IS NOT NULL) AS onboarded,
       ROUND(COUNT(e.customer_id)::numeric / NULLIF(COUNT(*),0), 3) AS activation_rate
FROM customers c LEFT JOIN (SELECT DISTINCT customer_id FROM events WHERE event_name='onboarding_complete') e USING(customer_id)
GROUP BY 1 ORDER BY activation_rate DESC;

-- Q07: Monthly acquisition cohorts
SELECT date_trunc('month', created_at)::date AS cohort_month, COUNT(*) AS cohort_size
FROM customers GROUP BY 1 ORDER BY 1;

-- Q08: Cohort retention by age in months
WITH activity AS (SELECT DISTINCT c.customer_id, date_trunc('month',c.created_at)::date cohort,
                  date_trunc('month',e.occurred_at)::date active_month
                  FROM customers c JOIN events e USING(customer_id))
SELECT cohort, ((EXTRACT(YEAR FROM active_month)-EXTRACT(YEAR FROM cohort))*12+
       EXTRACT(MONTH FROM active_month)-EXTRACT(MONTH FROM cohort))::int AS month_age,
       COUNT(DISTINCT customer_id) AS retained_users
FROM activity GROUP BY 1,2 ORDER BY 1,2;

-- Q09: Cohort retention rates (retained / cohort size)
WITH sizes AS (SELECT date_trunc('month',created_at)::date cohort, COUNT(*) n FROM customers GROUP BY 1),
active AS (SELECT DISTINCT date_trunc('month',c.created_at)::date cohort,
       ((EXTRACT(YEAR FROM e.occurred_at)-EXTRACT(YEAR FROM c.created_at))*12+
        EXTRACT(MONTH FROM e.occurred_at)-EXTRACT(MONTH FROM c.created_at))::int age,c.customer_id
       FROM customers c JOIN events e USING(customer_id))
SELECT a.cohort,a.age,COUNT(*) retained,s.n cohort_size,
       ROUND(COUNT(*)::numeric/s.n,3) retention_rate
FROM active a JOIN sizes s USING(cohort) GROUP BY a.cohort,a.age,s.n ORDER BY 1,2;

-- Q10: Monthly recurring revenue (MRR) by month
SELECT date_trunc('month',started_at)::date AS month, SUM(monthly_price) AS new_mrr
FROM subscriptions GROUP BY 1 ORDER BY 1;

-- Q11: Current MRR, active subscriptions only
SELECT SUM(monthly_price) AS current_mrr FROM subscriptions WHERE status='active';

-- Q12: Average revenue per paying customer (ARPPU)
SELECT SUM(monthly_price)/NULLIF(COUNT(DISTINCT customer_id),0) AS arppu
FROM subscriptions WHERE status='active';

-- Q13: Paying customer count and paid share
SELECT COUNT(DISTINCT customer_id) AS paying_customers,
       COUNT(DISTINCT customer_id)::numeric/(SELECT COUNT(*) FROM customers) AS paid_share
FROM subscriptions WHERE status='active';

-- Q14: Monthly subscription starts by plan
SELECT date_trunc('month',started_at)::date month, plan, COUNT(*) starts
FROM subscriptions GROUP BY 1,2 ORDER BY 1,2;

-- Q15: Monthly churned subscriptions
SELECT date_trunc('month',ended_at)::date month, COUNT(*) churned
FROM subscriptions WHERE status='cancelled' AND ended_at IS NOT NULL GROUP BY 1 ORDER BY 1;

-- Q16: Churn rate by plan (cancelled / all subscriptions)
SELECT plan, COUNT(*) FILTER(WHERE status='cancelled')::numeric/NULLIF(COUNT(*),0) churn_rate,
       COUNT(*) subscriptions FROM subscriptions GROUP BY 1 ORDER BY 2 DESC;

-- Q17: Customer lifetime value proxy (monthly price × observed tenure in months)
SELECT plan, ROUND(AVG(monthly_price * GREATEST(1,
       EXTRACT(DAY FROM (COALESCE(ended_at,CURRENT_DATE)-started_at))/30.44)),2) avg_observed_ltv
FROM subscriptions GROUP BY 1 ORDER BY 2 DESC;

-- Q18: Median days from signup to onboarding completion
SELECT percentile_cont(0.5) WITHIN GROUP(ORDER BY e.occurred_at::date-c.created_at) median_days
FROM customers c JOIN events e USING(customer_id) WHERE e.event_name='onboarding_complete';

-- Q19: Feature adoption among customers
SELECT feature_name, COUNT(DISTINCT customer_id) adopters,
       ROUND(COUNT(DISTINCT customer_id)::numeric/(SELECT COUNT(*) FROM customers),3) adoption_rate
FROM events WHERE event_name='feature_used' AND feature_name IS NOT NULL
GROUP BY 1 ORDER BY adopters DESC;

-- Q20: Feature adoption by plan
SELECT c.plan,e.feature_name,COUNT(DISTINCT c.customer_id) adopters
FROM customers c JOIN events e USING(customer_id)
WHERE e.event_name='feature_used' GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Q21: Average events per customer
SELECT AVG(event_count) avg_events_per_customer FROM
 (SELECT c.customer_id,COUNT(e.event_id) event_count FROM customers c LEFT JOIN events e USING(customer_id)
  GROUP BY c.customer_id) x;

-- Q22: DAU / MAU stickiness
WITH d AS (SELECT occurred_at::date day,COUNT(DISTINCT customer_id) dau FROM events GROUP BY 1),
m AS (SELECT date_trunc('month',occurred_at)::date month,COUNT(DISTINCT customer_id) mau FROM events GROUP BY 1)
SELECT date_trunc('month',d.day)::date month,ROUND(AVG(d.dau)::numeric/MAX(m.mau),3) avg_dau_mau
FROM d JOIN m ON m.month=date_trunc('month',d.day)::date GROUP BY 1 ORDER BY 1;

-- Q23: Most engaged customers (event count)
SELECT c.customer_id,c.plan,COUNT(e.event_id) events
FROM customers c JOIN events e USING(customer_id) GROUP BY 1,2 ORDER BY 3 DESC LIMIT 20;

-- Q24: Activation by country
SELECT c.country,COUNT(*) customers,COUNT(*) FILTER(WHERE a.customer_id IS NOT NULL) activated,
       ROUND(COUNT(a.customer_id)::numeric/COUNT(*),3) activation_rate
FROM customers c LEFT JOIN (SELECT DISTINCT customer_id FROM events WHERE event_name='onboarding_complete') a USING(customer_id)
GROUP BY 1 ORDER BY activation_rate DESC;

-- Q25: Paid conversion by country
SELECT c.country,COUNT(DISTINCT c.customer_id) signups,COUNT(DISTINCT s.customer_id) paid,
       ROUND(COUNT(DISTINCT s.customer_id)::numeric/COUNT(DISTINCT c.customer_id),3) paid_rate
FROM customers c LEFT JOIN subscriptions s USING(customer_id) GROUP BY 1 ORDER BY 4 DESC;

-- Q26: Current subscription plan mix
SELECT plan,COUNT(*) subscriptions,SUM(monthly_price) mrr,
       ROUND(COUNT(*)::numeric/(SELECT COUNT(*) FROM subscriptions WHERE status='active'),3) share
FROM subscriptions WHERE status='active' GROUP BY 1 ORDER BY 3 DESC;

-- Q27: Signup-to-paid conversion overall
SELECT COUNT(DISTINCT c.customer_id) signups,COUNT(DISTINCT s.customer_id) paid,
       ROUND(COUNT(DISTINCT s.customer_id)::numeric/COUNT(DISTINCT c.customer_id),3) conversion
FROM customers c LEFT JOIN subscriptions s USING(customer_id);

-- Q28: Signup-to-invite conversion by cohort month
SELECT date_trunc('month',c.created_at)::date cohort,COUNT(*) signups,
       COUNT(*) FILTER(WHERE i.customer_id IS NOT NULL) invited
FROM customers c LEFT JOIN (SELECT DISTINCT customer_id FROM events WHERE event_name='invite_sent') i USING(customer_id)
GROUP BY 1 ORDER BY 1;

-- Q29: Acquisition signup weekday mix
SELECT EXTRACT(ISODOW FROM created_at) weekday,COUNT(*) signups FROM customers GROUP BY 1 ORDER BY 1;

-- Q30: Monthly signup growth rate
WITH m AS (SELECT date_trunc('month',created_at)::date month,COUNT(*) signups FROM customers GROUP BY 1)
SELECT month,signups,LAG(signups) OVER(ORDER BY month) prior_month,
       ROUND((signups-LAG(signups) OVER(ORDER BY month))::numeric/NULLIF(LAG(signups) OVER(ORDER BY month),0),3) growth
FROM m ORDER BY month;

-- Q31: Weekly retained users (active this week and previous week)
WITH w AS (SELECT DISTINCT date_trunc('week',occurred_at)::date week,customer_id FROM events)
SELECT cur.week,COUNT(*) retained_from_prior_week FROM w cur JOIN w prev
ON prev.customer_id=cur.customer_id AND prev.week=cur.week-7 GROUP BY 1 ORDER BY 1;

-- Q32: A/B experiment sample sizes and converted users
SELECT experiment_id,variant,COUNT(*) assigned,COUNT(*) FILTER(WHERE converted) conversions
FROM experiment_assignments GROUP BY 1,2 ORDER BY 1,2;

-- Q33: A/B experiment conversion rate and Wilson ingredients
SELECT experiment_id,variant,COUNT(*) n,AVG(converted::int)::numeric conversion_rate
FROM experiment_assignments GROUP BY 1,2 ORDER BY 1,2;

-- Q34: A/B sample-ratio mismatch diagnostic (expected 50/50, chi-square)
WITH c AS (SELECT COUNT(*) FILTER(WHERE variant='control') control_n,
                  COUNT(*) FILTER(WHERE variant='treatment') treatment_n,COUNT(*) total
           FROM experiment_assignments WHERE experiment_id='EXP_ONBOARDING_01')
SELECT control_n,treatment_n,((control_n-total/2.0)^2+(treatment_n-total/2.0)^2)/(total/2.0) chi_square_df1 FROM c;

-- Q35: Revenue by acquisition channel
SELECT c.acquisition_channel,COUNT(DISTINCT c.customer_id) acquired,
       SUM(s.monthly_price) current_mrr
FROM customers c LEFT JOIN subscriptions s USING(customer_id)
GROUP BY 1 ORDER BY current_mrr DESC;

-- Q36: Feature re-use (customers with 2+ feature events)
SELECT feature_name,COUNT(*) customers_with_repeat_use FROM
 (SELECT customer_id,feature_name,COUNT(*) n FROM events WHERE event_name='feature_used'
  GROUP BY 1,2 HAVING COUNT(*)>=2) x GROUP BY 1 ORDER BY 2 DESC;

-- Q37: Time to first paid subscription by channel
SELECT c.acquisition_channel,AVG(s.started_at-c.created_at) avg_days_to_paid,
       percentile_cont(0.5) WITHIN GROUP(ORDER BY s.started_at-c.created_at) median_days
FROM customers c JOIN subscriptions s USING(customer_id) GROUP BY 1 ORDER BY 2;

-- Q38: Churned subscription share by plan
SELECT plan,COUNT(*) total,COUNT(*) FILTER(WHERE status='cancelled') cancelled,
       ROUND(COUNT(*) FILTER(WHERE status='cancelled')::numeric/COUNT(*),3) churn_share
FROM subscriptions GROUP BY 1 ORDER BY 4 DESC;

-- Q39: Revenue concentration across paying customers
WITH r AS (SELECT customer_id,SUM(monthly_price) mrr FROM subscriptions WHERE status='active' GROUP BY 1),
ranked AS (SELECT *,SUM(mrr) OVER(ORDER BY mrr DESC ROWS UNBOUNDED PRECEDING) running_mrr,
           SUM(mrr) OVER() total_mrr FROM r)
SELECT customer_id,mrr,ROUND(running_mrr/NULLIF(total_mrr,0),3) cumulative_revenue_share
FROM ranked ORDER BY mrr DESC LIMIT 20;

-- Q40: Monthly cohort cumulative acquired paid MRR
SELECT date_trunc('month',c.created_at)::date cohort,SUM(s.monthly_price) cohort_mrr
FROM customers c JOIN subscriptions s USING(customer_id) GROUP BY 1 ORDER BY 1;

-- Q41: Weekly feature usage trend
SELECT date_trunc('week',occurred_at)::date week,feature_name,COUNT(*) events,
       COUNT(DISTINCT customer_id) users
FROM events WHERE event_name='feature_used' GROUP BY 1,2 ORDER BY 1,2;

-- Q42: Event taxonomy and volume
SELECT event_name,COUNT(*) event_count,COUNT(DISTINCT customer_id) users,
       MIN(occurred_at) first_seen,MAX(occurred_at) last_seen
FROM events GROUP BY 1 ORDER BY 2 DESC;

-- Q43: Seven-day activation after signup
SELECT COUNT(*) signups,COUNT(*) FILTER(WHERE a.customer_id IS NOT NULL) activated_7d,
       ROUND(COUNT(a.customer_id)::numeric/COUNT(*),3) activation_rate_7d
FROM customers c LEFT JOIN (SELECT DISTINCT c.customer_id FROM customers c JOIN events e USING(customer_id)
 WHERE e.event_name='onboarding_complete' AND e.occurred_at < c.created_at+INTERVAL '7 days') a USING(customer_id);

-- Q44: 30-day paid conversion by acquisition channel
SELECT c.acquisition_channel,COUNT(*) signups,
       COUNT(*) FILTER(WHERE s.customer_id IS NOT NULL) paid_30d,
       ROUND(COUNT(s.customer_id)::numeric/COUNT(*),3) conversion_30d
FROM customers c LEFT JOIN subscriptions s ON s.customer_id=c.customer_id
AND s.started_at<c.created_at+30 GROUP BY 1 ORDER BY 4 DESC;

-- Q45: Ordered funnel by channel (signup -> onboarding -> project)
WITH f AS (SELECT c.customer_id,c.acquisition_channel,
 BOOL_OR(e.event_name='onboarding_complete') onboarded,BOOL_OR(e.event_name='project_created') project_created
 FROM customers c LEFT JOIN events e USING(customer_id) GROUP BY 1,2)
SELECT acquisition_channel,COUNT(*) signups,COUNT(*) FILTER(WHERE onboarded) onboarded,
 COUNT(*) FILTER(WHERE onboarded AND project_created) reached_project
FROM f GROUP BY 1 ORDER BY 1;

-- Q46: Channel contribution to active MRR per acquired user
SELECT c.acquisition_channel,SUM(s.monthly_price)/NULLIF(COUNT(DISTINCT c.customer_id),0) mrr_per_acquired_user
FROM customers c LEFT JOIN subscriptions s ON s.customer_id=c.customer_id AND s.status='active'
GROUP BY 1 ORDER BY 2 DESC;

-- Q47: Signup cohort feature activation
SELECT date_trunc('month',c.created_at)::date cohort,e.feature_name,
       COUNT(DISTINCT e.customer_id) adopters
FROM customers c JOIN events e USING(customer_id) WHERE e.event_name='feature_used'
GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Q48: Geographic plan mix
SELECT c.country,c.plan,COUNT(*) customers FROM customers c GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Q49: Product activity anomaly screen (daily events vs trailing 7-day mean)
WITH d AS (SELECT occurred_at::date day,COUNT(*) events FROM events GROUP BY 1),
x AS (SELECT day,events,AVG(events) OVER(ORDER BY day ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) prior_7d_avg FROM d)
SELECT day,events,ROUND(prior_7d_avg,1) prior_7d_avg,
       ROUND(events/NULLIF(prior_7d_avg,0),2) vs_average FROM x ORDER BY day;

-- Q50: Recently inactive customers (no event in the last 14 days of the data)
WITH last_event AS (SELECT customer_id,MAX(occurred_at) last_seen FROM events GROUP BY 1),
anchor AS (SELECT MAX(occurred_at) max_event FROM events)
SELECT c.customer_id,c.plan,l.last_seen,(a.max_event-l.last_seen)::int inactive_days
FROM customers c JOIN last_event l USING(customer_id) CROSS JOIN anchor a
WHERE l.last_seen<a.max_event-INTERVAL '14 days' ORDER BY l.last_seen;

-- Q51: Repeat purchase behavior
SELECT COUNT(*) customers_with_purchase,COUNT(*) FILTER(WHERE purchases>1) repeat_purchasers
FROM (SELECT customer_id,COUNT(*) purchases FROM events WHERE event_name='purchase' GROUP BY 1) p;

-- Q52: Active customer count by plan and acquisition channel
SELECT c.acquisition_channel,c.plan,COUNT(DISTINCT e.customer_id) active_customers
FROM customers c JOIN events e USING(customer_id) GROUP BY 1,2 ORDER BY 1,3 DESC;

-- Q53: RFM-style behavioral segmentation (recency, frequency, monetary proxy)
WITH activity AS (SELECT c.customer_id,MAX(e.occurred_at)::date last_seen,COUNT(e.event_id) frequency,
 COALESCE(MAX(s.monthly_price),0) monthly_value FROM customers c LEFT JOIN events e USING(customer_id)
 LEFT JOIN subscriptions s USING(customer_id) GROUP BY 1)
SELECT customer_id,(SELECT MAX(occurred_at)::date FROM events)-last_seen recency_days,
 frequency,monthly_value,CASE WHEN monthly_value>=59 AND frequency>=10 THEN 'high_value_engaged'
 WHEN frequency>=10 THEN 'engaged_free_or_low_value' ELSE 'needs_nurture' END segment FROM activity;

-- Q54: First-week engagement intensity by conversion outcome
WITH first_week AS (SELECT c.customer_id,COUNT(e.event_id) events_7d
 FROM customers c LEFT JOIN events e ON e.customer_id=c.customer_id AND e.occurred_at<c.created_at+7
 GROUP BY 1)
SELECT (s.customer_id IS NOT NULL) paid,COUNT(*) customers,AVG(events_7d) avg_events_first_week
FROM first_week f LEFT JOIN subscriptions s USING(customer_id) GROUP BY 1;

-- Q55: Top feature by paid-plan adoption
SELECT c.plan,e.feature_name,COUNT(DISTINCT c.customer_id) adopters,
 RANK() OVER(PARTITION BY c.plan ORDER BY COUNT(DISTINCT c.customer_id) DESC) feature_rank
FROM customers c JOIN events e USING(customer_id) WHERE e.event_name='feature_used'
GROUP BY 1,2 ORDER BY 1,4;
