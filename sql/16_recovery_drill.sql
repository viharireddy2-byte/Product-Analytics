-- commerce_recovery_drill is an isolated disposable dataset configured by ops/commerce.sh.
-- Never mutates the sessions mart. Uses a bounded sample to limit restore cost.
CREATE TABLE commerce_recovery_drill.drill_source
PARTITION BY session_date
OPTIONS(require_partition_filter=TRUE) AS
SELECT * FROM commerce_analytics.sessions
WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31'
ORDER BY session_key LIMIT 10000;
ASSERT (SELECT COUNT(*)>0 FROM commerce_recovery_drill.drill_source WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31') AS 'No recovery sample';
CREATE SNAPSHOT TABLE commerce_recovery_drill.drill_snapshot
CLONE commerce_recovery_drill.drill_source
OPTIONS(expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY));
DELETE FROM commerce_recovery_drill.drill_source WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31';
ASSERT (SELECT COUNT(*)=0 FROM commerce_recovery_drill.drill_source WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31') AS 'Fault injection failed';
CREATE TABLE commerce_recovery_drill.drill_restored CLONE commerce_recovery_drill.drill_snapshot;
ASSERT (
 (SELECT COUNT(*) FROM commerce_recovery_drill.drill_restored WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31')=
 (SELECT COUNT(*) FROM commerce_recovery_drill.drill_snapshot WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31')
) AS 'Restored row count differs';
ASSERT (SELECT COUNT(*)=0 FROM (
 SELECT * FROM commerce_recovery_drill.drill_restored WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31'
 EXCEPT DISTINCT
 SELECT * FROM commerce_recovery_drill.drill_snapshot WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31'
)) AS 'Restored rows differ';
ASSERT (SELECT COUNT(*)=0 FROM (
 SELECT * FROM commerce_recovery_drill.drill_snapshot WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31'
 EXCEPT DISTINCT
 SELECT * FROM commerce_recovery_drill.drill_restored WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31'
)) AS 'Restored rows are missing';
SELECT 'passed' AS recovery_status, COUNT(*) AS restored_rows
FROM commerce_recovery_drill.drill_restored WHERE session_date BETWEEN DATE '2017-01-01' AND DATE '2017-01-31';
