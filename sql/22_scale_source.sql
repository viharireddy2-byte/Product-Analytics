-- Dedicated scale dataset only. Exactly 50M deterministic synthetic sessions.
-- 5M visitors return across ten visits, spanning 365 days. No customer data.
CREATE OR REPLACE TABLE commerce_analytics.raw_scale_sessions
PARTITION BY session_date CLUSTER BY fullVisitorId
OPTIONS(require_partition_filter=TRUE) AS
WITH ids AS (
 SELECT a*1000+b AS id FROM UNNEST(GENERATE_ARRAY(0,49999)) a
 CROSS JOIN UNNEST(GENERATE_ARRAY(0,999)) b
), base AS (
 SELECT *, DATE_ADD(DATE '2016-08-01', INTERVAL MOD(id,365) DAY) AS session_date FROM ids
)
SELECT session_date, FORMAT_DATE('%Y%m%d',session_date) AS date,
CAST(MOD(id,5000000) AS STRING) AS fullVisitorId, DIV(id,5000000) AS visitId,
STRUCT(IF(MOD(id,3)=0,'mobile','desktop') AS deviceCategory) AS device,
STRUCT(IF(MOD(id,7)=0,'cpc','organic') AS medium) AS trafficSource,
STRUCT(IF(MOD(id,5)=0,1,0) AS transactions) AS totals,
ARRAY(SELECT AS STRUCT n AS hitNumber,n*1000 AS time,
 STRUCT(CASE WHEN n=1 THEN '2' WHEN n=4 AND MOD(id,2)=0 THEN '3'
 WHEN n=8 AND MOD(id,5)=0 THEN '6' ELSE '0' END AS action_type) AS eCommerceAction
 FROM UNNEST(GENERATE_ARRAY(1,12)) n) AS hits
FROM base;
ASSERT (SELECT COUNT(*) FROM commerce_analytics.raw_scale_sessions
 WHERE session_date BETWEEN DATE '2016-08-01' AND DATE '2017-07-31')=50000000 AS 'Scale source must contain 50M sessions';
CREATE OR REPLACE VIEW commerce_analytics.raw_sessions AS
SELECT date,fullVisitorId,visitId,device,trafficSource,totals,hits,
FORMAT_DATE('%Y%m%d',session_date) AS source_suffix
FROM commerce_analytics.raw_scale_sessions
WHERE session_date BETWEEN DATE '2016-08-01' AND DATE '2017-07-31';
