DECLARE start_date DATE DEFAULT DATE '2016-08-01';
DECLARE end_date DATE DEFAULT DATE '2017-08-01';
CREATE TEMP TABLE checked AS SELECT * FROM commerce_analytics.sessions
WHERE session_date BETWEEN start_date AND end_date;
ASSERT (SELECT COUNT(*)>0 FROM checked) AS 'No sessions';
ASSERT (SELECT COUNT(*)=COUNT(DISTINCT session_key) FROM checked) AS 'Duplicate session keys';
ASSERT (SELECT COUNTIF(visitor_id IS NULL OR visit_id IS NULL)=0 FROM checked) AS 'Missing identity';
ASSERT (SELECT COUNTIF(cart_ms IS NOT NULL AND (view_ms IS NULL OR cart_ms<=view_ms))=0 FROM checked) AS 'Invalid cart ordering';
ASSERT (SELECT COUNTIF(purchase_ms IS NOT NULL AND (cart_ms IS NULL OR purchase_ms<=cart_ms))=0 FROM checked) AS 'Invalid purchase ordering';
SELECT COUNT(*) AS checked_sessions,
 COUNTIF(has_cart AND cart_ms IS NULL) AS unordered_cart_sessions,
 COUNTIF(has_purchase AND purchase_ms IS NULL) AS unordered_purchase_sessions
FROM checked;
