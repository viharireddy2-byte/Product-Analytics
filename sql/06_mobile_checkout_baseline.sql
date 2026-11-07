DECLARE start_date DATE DEFAULT DATE '2017-01-01';
DECLARE end_date DATE DEFAULT DATE '2017-01-31';
SELECT COUNTIF(cart_ms IS NOT NULL) AS mobile_add_to_cart,
COUNTIF(purchase_ms IS NOT NULL) AS mobile_purchases,
SAFE_DIVIDE(COUNTIF(purchase_ms IS NOT NULL),COUNTIF(cart_ms IS NOT NULL)) AS checkout_conversion
FROM commerce_analytics.sessions
WHERE session_date BETWEEN start_date AND end_date AND device_type='mobile';
