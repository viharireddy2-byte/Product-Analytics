-- Aggregate-only export, at most ~15K rows for this bounded public sample.
SELECT session_date, COALESCE(device_type,'unknown') AS device_type,
COALESCE(traffic_medium,'unknown') AS traffic_medium,
sessions, product_views, carts, purchases, unordered_purchases, published_at
FROM commerce_analytics.dashboard_daily
WHERE session_date BETWEEN DATE '2016-08-01' AND DATE '2017-08-01'
ORDER BY session_date,device_type,traffic_medium;
