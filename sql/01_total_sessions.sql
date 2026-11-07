DECLARE start_date DATE DEFAULT DATE '2017-01-01';
DECLARE end_date DATE DEFAULT DATE '2017-01-31';
SELECT COUNT(*) AS total_sessions, COUNT(DISTINCT visitor_id) AS total_visitors
FROM commerce_analytics.sessions
WHERE session_date BETWEEN start_date AND end_date;
