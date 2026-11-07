-- First observed cohort in the available history, not guaranteed lifetime acquisition.
DECLARE history_start DATE DEFAULT DATE '2016-08-01';
DECLARE cohort_start DATE DEFAULT DATE '2017-01-01';
DECLARE observation_end DATE DEFAULT DATE '2017-06-30';
WITH visits AS (
 SELECT DISTINCT visitor_id, session_date FROM commerce_analytics.sessions
 WHERE session_date BETWEEN history_start AND observation_end
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
