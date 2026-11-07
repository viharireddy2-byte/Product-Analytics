-- Historical sample: freshness means a successful processing run, not recent event dates.
DECLARE max_refresh_age_hours INT64 DEFAULT 24;
WITH latest AS (
 SELECT * FROM commerce_analytics.refresh_audit
 QUALIFY ROW_NUMBER() OVER(ORDER BY started_at DESC,run_id DESC)=1
), successful AS (
 SELECT MAX(completed_at) AS last_success_at FROM commerce_analytics.refresh_audit WHERE status='succeeded'
)
SELECT l.run_id,l.status AS latest_status,l.error_message,s.last_success_at,
CASE WHEN s.last_success_at IS NULL THEN 'no successful refresh'
 WHEN l.status='failed' THEN 'latest refresh failed'
 WHEN TIMESTAMP_DIFF(CURRENT_TIMESTAMP(),s.last_success_at,HOUR)>max_refresh_age_hours THEN 'refresh overdue'
 ELSE 'healthy' END AS health
FROM successful s LEFT JOIN latest l ON TRUE;
