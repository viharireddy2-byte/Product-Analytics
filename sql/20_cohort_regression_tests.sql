DECLARE cohort_start DATE DEFAULT DATE '2017-01-01';
DECLARE observation_end DATE DEFAULT DATE '2017-03-15';
CREATE TEMP TABLE actual_cohorts AS
WITH visits AS (
 SELECT * FROM UNNEST([
 STRUCT('new_a' AS visitor_id,DATE '2017-01-01' AS session_date),
 ('new_a',DATE '2017-03-01'),('new_b',DATE '2017-01-10'),
 ('old',DATE '2016-12-20'),('old',DATE '2017-01-10')
 ])
), first_seen AS (
 SELECT visitor_id, MIN(session_date) AS first_date FROM visits GROUP BY visitor_id
), cohort AS (
 SELECT visitor_id FROM first_seen
 WHERE DATE_TRUNC(first_date, MONTH)=cohort_start
), months AS (
 SELECT month_number FROM UNNEST(GENERATE_ARRAY(0, DATE_DIFF(DATE_TRUNC(observation_end,MONTH),cohort_start,MONTH))) month_number
), active AS (
 SELECT DATE_DIFF(DATE_TRUNC(v.session_date,MONTH),cohort_start,MONTH) AS month_number,
 COUNT(DISTINCT v.visitor_id) AS active_users FROM visits v JOIN cohort USING(visitor_id)
 WHERE v.session_date >= cohort_start GROUP BY month_number
)
SELECT m.month_number, COALESCE(a.active_users,0) AS active_users,
 (SELECT COUNT(*) FROM cohort) AS cohort_size,
 SAFE_DIVIDE(COALESCE(a.active_users,0),(SELECT COUNT(*) FROM cohort)) AS retention_rate,
 LAST_DAY(DATE_ADD(cohort_start,INTERVAL m.month_number MONTH)) > observation_end AS is_partial_month
FROM months m LEFT JOIN active a USING(month_number) ORDER BY month_number;

ASSERT (SELECT COUNT(*)=3 FROM actual_cohorts) AS 'Missing cohort month';
ASSERT (SELECT cohort_size=2 AND active_users=2 AND retention_rate=1 FROM actual_cohorts WHERE month_number=0) AS 'Cohort lookback or denominator regression';
ASSERT (SELECT active_users=0 AND retention_rate=0 FROM actual_cohorts WHERE month_number=1) AS 'Zero month not filled';
ASSERT (SELECT active_users=1 AND retention_rate=0.5 AND is_partial_month FROM actual_cohorts WHERE month_number=2) AS 'Partial-month retention regression';
SELECT 'passed' AS cohort_regression_status;
