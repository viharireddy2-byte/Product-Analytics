-- Execute in the same BigQuery region as the workload (US public sample).
SELECT job_id, creation_time, statement_type,
 TIMESTAMP_DIFF(end_time,start_time,MILLISECOND) AS execution_ms,
 total_bytes_processed, total_bytes_billed, total_slot_ms, cache_hit,
 error_result.reason AS error_reason
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_USER
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 DAY)
AND job_type='QUERY' AND statement_type!='SCRIPT'
ORDER BY creation_time DESC;
