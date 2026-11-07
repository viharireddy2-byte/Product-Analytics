-- Same ordered definitions and reporting dates as mart_funnel.sql.
WITH sessions AS (
WITH normalized AS (
 SELECT PARSE_DATE('%Y%m%d', date) AS session_date,
 fullVisitorId AS visitor_id, visitId AS visit_id,
 device.deviceCategory AS device_type, trafficSource.medium AS traffic_medium,
 totals.transactions AS transactions,
 ARRAY(SELECT AS STRUCT h.hitNumber AS hit_number, h.time AS time_ms,
 h.eCommerceAction.action_type AS action_type FROM UNNEST(hits) h) AS events
 FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
 WHERE _TABLE_SUFFIX BETWEEN '20170101' AND '20170131'
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
FROM carted
)
SELECT COUNT(*) AS total_sessions, COUNTIF(view_ms IS NOT NULL) AS product_views,
COUNTIF(cart_ms IS NOT NULL) AS add_to_cart, COUNTIF(purchase_ms IS NOT NULL) AS purchases
FROM sessions;
