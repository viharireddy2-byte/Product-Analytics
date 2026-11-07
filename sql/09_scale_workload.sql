-- Opt-in synthetic workload. Replicates sessions, not independent users or real traffic.
-- Lower target_rows before running to control cost. Source date must contain sessions.
DECLARE target_rows INT64 DEFAULT 50000000;
DECLARE source_date DATE DEFAULT DATE '2017-01-01';
DECLARE source_count INT64;
ASSERT target_rows BETWEEN 1 AND 50000000 AS 'Target outside allowed range';
SET source_count=(SELECT COUNT(*) FROM commerce_analytics.sessions WHERE session_date=source_date);
ASSERT source_count>0 AS 'Source date is empty';
CREATE OR REPLACE TABLE commerce_analytics.synthetic_sessions
PARTITION BY session_date CLUSTER BY device_type, traffic_medium
OPTIONS(require_partition_filter=TRUE) AS
WITH numbered AS (
 SELECT *, ROW_NUMBER() OVER(ORDER BY session_key)-1 AS row_index
 FROM commerce_analytics.sessions WHERE session_date=source_date
)
SELECT s.* EXCEPT(row_index,session_key,visitor_id),
 TO_JSON_STRING(STRUCT(s.visitor_id,replica)) AS visitor_id,
 TO_JSON_STRING(STRUCT(s.session_key,replica)) AS session_key
FROM numbered s CROSS JOIN UNNEST(GENERATE_ARRAY(0,CAST(CEIL(SAFE_DIVIDE(target_rows,source_count)) AS INT64)-1)) replica
WHERE replica*source_count+row_index<target_rows;
