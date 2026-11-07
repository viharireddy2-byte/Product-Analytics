WITH totals AS (
 SELECT SUM(sessions) AS sessions,SUM(product_views) AS views,SUM(carts) AS carts,SUM(purchases) AS purchases
 FROM commerce_analytics.dashboard_daily
 WHERE session_date BETWEEN DATE '2016-08-01' AND DATE '2017-08-01'
)
SELECT stage.ordinal,stage.stage,stage.sessions
FROM totals CROSS JOIN UNNEST([
 STRUCT(1 AS ordinal,'1 Sessions' AS stage,sessions AS sessions),
 (2,'2 Product views',views),(3,'3 Add to cart',carts),(4,'4 Purchases',purchases)
]) AS stage ORDER BY ordinal;
