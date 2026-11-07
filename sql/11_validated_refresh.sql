-- Install once after 00. CALL commerce_analytics.refresh_sessions(DATE '2017-01-01', DATE '2017-01-31');
-- Existing analysis queries and full rebuild remain supported.
CREATE TABLE IF NOT EXISTS commerce_analytics.refresh_audit (
 run_id STRING, started_at TIMESTAMP, completed_at TIMESTAMP,
 refresh_start DATE, refresh_end DATE, staged_rows INT64, status STRING, error_message STRING
) PARTITION BY DATE(started_at);
CREATE OR REPLACE PROCEDURE commerce_analytics.refresh_sessions(refresh_start DATE, refresh_end DATE)
BEGIN
 DECLARE run_id STRING DEFAULT GENERATE_UUID();
 DECLARE started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
 DECLARE staged_rows INT64;
 BEGIN
 ASSERT refresh_start IS NOT NULL AND refresh_end IS NOT NULL AND refresh_start<=refresh_end AS 'Invalid refresh window';
 ASSERT refresh_start>=DATE '2016-08-01' AND refresh_end<=DATE '2017-08-01' AS 'Window outside available sample';
 CREATE OR REPLACE TEMP TABLE candidate AS
WITH normalized AS (
 SELECT PARSE_DATE('%Y%m%d', date) AS session_date,
 fullVisitorId AS visitor_id, visitId AS visit_id,
 device.deviceCategory AS device_type, trafficSource.medium AS traffic_medium,
 totals.transactions AS transactions,
 ARRAY(SELECT AS STRUCT h.hitNumber AS hit_number, h.time AS time_ms,
 h.eCommerceAction.action_type AS action_type FROM UNNEST(hits) h) AS events
 FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
 WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', refresh_start) AND FORMAT_DATE('%Y%m%d', refresh_end)
), deduplicated AS (
 SELECT * FROM normalized
 QUALIFY ROW_NUMBER() OVER (PARTITION BY visitor_id, visit_id
 ORDER BY session_date, TO_JSON_STRING(events), device_type, traffic_medium, transactions) = 1
), viewed AS (
 SELECT *, (SELECT MIN(time_ms) FROM UNNEST(events) WHERE action_type='2') AS view_ms,
 EXISTS(SELECT 1 FROM UNNEST(events) WHERE action_type='3') AS has_cart,
 EXISTS(SELECT 1 FROM UNNEST(events) WHERE action_type='6') AS has_purchase
 FROM deduplicated
), carted AS (
 SELECT *, (SELECT MIN(time_ms) FROM UNNEST(events)
 WHERE action_type='3' AND time_ms > view_ms) AS cart_ms FROM viewed
)
SELECT session_date, visitor_id, visit_id,
 TO_JSON_STRING(STRUCT(visitor_id, visit_id)) AS session_key,
 device_type, traffic_medium, COALESCE(transactions,0) AS transactions,
 view_ms, cart_ms,
 (SELECT MIN(time_ms) FROM UNNEST(events)
 WHERE action_type='6' AND time_ms > cart_ms) AS purchase_ms,
 has_cart, has_purchase
FROM carted;

 SET staged_rows=(SELECT COUNT(*) FROM candidate);
 ASSERT staged_rows>0 AS 'Candidate is empty';
 ASSERT (SELECT COUNT(*)=COUNT(DISTINCT session_key) FROM candidate) AS 'Duplicate identity';
 ASSERT (SELECT COUNTIF(visitor_id IS NULL OR visit_id IS NULL)=0 FROM candidate) AS 'Missing identity';
 ASSERT (SELECT COUNT(DISTINCT session_date)=DATE_DIFF(refresh_end,refresh_start,DAY)+1 FROM candidate) AS 'Missing source dates';
 ASSERT (SELECT COUNTIF(cart_ms IS NOT NULL AND (view_ms IS NULL OR cart_ms<=view_ms))=0 FROM candidate) AS 'Invalid cart order';
 ASSERT (SELECT COUNTIF(purchase_ms IS NOT NULL AND (cart_ms IS NULL OR purchase_ms<=cart_ms))=0 FROM candidate) AS 'Invalid purchase order';
 BEGIN
  BEGIN TRANSACTION;
  DELETE FROM commerce_analytics.sessions WHERE session_date BETWEEN refresh_start AND refresh_end;
  INSERT INTO commerce_analytics.sessions
  (session_date,visitor_id,visit_id,session_key,device_type,traffic_medium,transactions,view_ms,cart_ms,purchase_ms,has_cart,has_purchase)
  SELECT session_date,visitor_id,visit_id,session_key,device_type,traffic_medium,transactions,view_ms,cart_ms,purchase_ms,has_cart,has_purchase FROM candidate;
  INSERT INTO commerce_analytics.refresh_audit VALUES(run_id,started_at,CURRENT_TIMESTAMP(),refresh_start,refresh_end,staged_rows,'succeeded',NULL);
  COMMIT TRANSACTION;
 EXCEPTION WHEN ERROR THEN
  ROLLBACK TRANSACTION;
  RAISE;
 END;
 EXCEPTION WHEN ERROR THEN
 INSERT INTO commerce_analytics.refresh_audit VALUES(run_id,started_at,CURRENT_TIMESTAMP(),refresh_start,refresh_end,staged_rows,'failed',@@error.message);
 RAISE;
 END;
END;
