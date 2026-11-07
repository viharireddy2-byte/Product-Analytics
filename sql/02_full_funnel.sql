DECLARE start_date DATE DEFAULT DATE '2017-01-01';
DECLARE end_date DATE DEFAULT DATE '2017-01-31';
SELECT COUNT(*) AS total_sessions,
 COUNTIF(view_ms IS NOT NULL) AS product_views,
 COUNTIF(cart_ms IS NOT NULL) AS add_to_cart,
 COUNTIF(purchase_ms IS NOT NULL) AS purchases,
 SAFE_DIVIDE(COUNTIF(purchase_ms IS NOT NULL),COUNT(*)) AS conversion_rate
FROM commerce_analytics.sessions
WHERE session_date BETWEEN start_date AND end_date;
