-- Execute only after validation or a successful validated refresh.
-- Separate BI materialization; failure leaves previously published aggregate table intact.
CREATE TEMP TABLE dashboard_candidate AS
SELECT session_date, device_type, traffic_medium,
COUNT(*) AS sessions, COUNT(DISTINCT visitor_id) AS daily_visitors,
COUNTIF(view_ms IS NOT NULL) AS product_views,
COUNTIF(cart_ms IS NOT NULL) AS carts,
COUNTIF(purchase_ms IS NOT NULL) AS purchases,
COUNTIF(has_purchase AND purchase_ms IS NULL) AS unordered_purchases,
CURRENT_TIMESTAMP() AS published_at
FROM commerce_analytics.sessions
WHERE session_date BETWEEN DATE '2016-08-01' AND DATE '2017-08-01'
GROUP BY session_date,device_type,traffic_medium;
-- Daily visitors are non-additive across dates and segments. Query 01 for range visitors.
ASSERT (SELECT SUM(sessions) FROM dashboard_candidate)=
(SELECT COUNT(*) FROM commerce_analytics.sessions WHERE session_date BETWEEN DATE '2016-08-01' AND DATE '2017-08-01') AS 'Dashboard session reconciliation failed';
ASSERT (SELECT COUNTIF(purchases>carts OR carts>product_views OR product_views>sessions) FROM dashboard_candidate)=0 AS 'Dashboard funnel nesting failed';

CREATE OR REPLACE TABLE commerce_analytics.dashboard_daily
PARTITION BY session_date CLUSTER BY device_type, traffic_medium AS SELECT * FROM dashboard_candidate;
