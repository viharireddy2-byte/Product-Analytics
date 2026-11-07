-- Fails a scheduled run if the latest procedure run failed or no recent success exists.
DECLARE latest_status STRING;
DECLARE last_success TIMESTAMP;
SET latest_status=(SELECT status FROM commerce_analytics.refresh_audit ORDER BY started_at DESC,run_id DESC LIMIT 1);
SET last_success=(SELECT MAX(completed_at) FROM commerce_analytics.refresh_audit WHERE status='succeeded');
ASSERT latest_status='succeeded' AS 'Latest refresh failed or audit is empty';
ASSERT last_success>=TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 24 HOUR) AS 'No successful refresh within 24 hours';
SELECT 'healthy' AS refresh_health,last_success;
