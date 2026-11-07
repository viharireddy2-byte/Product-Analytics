-- BigQuery-only, no production tables read or written.
-- Fixture transformation follows 00; update both when changing funnel semantics.
CREATE TEMP TABLE actual AS
WITH normalized AS (
 SELECT DATE '2017-01-01' AS session_date, visitor_id, visit_id,
 'mobile' AS device_type, 'direct' AS traffic_medium, 0 AS transactions, events
 FROM UNNEST([
 STRUCT('a' AS visitor_id, 1 AS visit_id,[STRUCT(1 AS hit_number,0 AS time_ms,'2' AS action_type),(2,10,'3'),(3,20,'6')] AS events),
 ('a',1,[(1,0,'2'),(2,10,'3'),(3,20,'6')]),
 ('b',1,ARRAY<STRUCT<hit_number INT64,time_ms INT64,action_type STRING>>[]),
 ('c',2,[(1,0,'6'),(2,10,'3'),(3,20,'2')]),
 ('d',3,[(1,0,'2'),(2,0,'3'),(3,0,'6')]),
 ('e',4,[(1,0,'2'),(2,10,'3'),(3,20,'3'),(4,30,'6')])
 ])
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

ASSERT (SELECT COUNT(*)=5 FROM actual) AS 'Deduplication regression';
ASSERT (SELECT COUNTIF(view_ms IS NOT NULL)=4 AND COUNTIF(cart_ms IS NOT NULL)=2 AND COUNTIF(purchase_ms IS NOT NULL)=2 FROM actual) AS 'Ordered funnel regression';
ASSERT (SELECT COUNT(*)=2 FROM actual WHERE visit_id=1) AS 'Composite identity collision';
ASSERT (SELECT purchase_ms IS NULL AND cart_ms IS NULL FROM actual WHERE visitor_id='c') AS 'Reverse order accepted';
ASSERT (SELECT purchase_ms IS NULL AND cart_ms IS NULL FROM actual WHERE visitor_id='d') AS 'Tied timestamps accepted';
ASSERT (SELECT cart_ms=10 AND purchase_ms=30 FROM actual WHERE visitor_id='e') AS 'Repeated cart regression';
ASSERT (SELECT view_ms IS NULL AND NOT has_purchase AND NOT has_cart FROM actual WHERE visitor_id='b') AS 'Empty event regression';
SELECT 'passed' AS regression_status;
