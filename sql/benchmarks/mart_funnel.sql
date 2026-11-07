SELECT COUNT(*) AS total_sessions, COUNTIF(view_ms IS NOT NULL) AS product_views,
COUNTIF(cart_ms IS NOT NULL) AS add_to_cart, COUNTIF(purchase_ms IS NOT NULL) AS purchases
FROM commerce_analytics.sessions
WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31';
