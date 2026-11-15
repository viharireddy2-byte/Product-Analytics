-- BigQuery Standard SQL. Run in a project with a dataset named commerce_analytics.
-- Atomic, repeatable full rebuild of the bounded public sample.
CREATE OR REPLACE TABLE commerce_analytics.sessions
PARTITION BY session_date
CLUSTER BY device_type, traffic_medium, visitor_id
OPTIONS(require_partition_filter=TRUE, description='One row per visitor and visit ID; ordered funnel timestamps in milliseconds') AS
WITH normalized AS (
 SELECT PARSE_DATE('%Y%m%d', date) AS session_date,
 fullVisitorId AS visitor_id, visitId AS visit_id,
 device.deviceCategory AS device_type, trafficSource.medium AS traffic_medium,
 totals.transactions AS transactions,
 ARRAY(SELECT AS STRUCT h.hitNumber AS hit_number, h.time AS time_ms,
 h.eCommerceAction.action_type AS action_type FROM UNNEST(hits) h) AS events
 FROM commerce_analytics.raw_sessions
 WHERE source_suffix BETWEEN '20160801' AND '20170801'
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
