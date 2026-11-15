-- Default adapter; use only in a new public-sample dataset.
CREATE OR REPLACE VIEW commerce_analytics.raw_sessions AS
SELECT date, fullVisitorId, visitId, device, trafficSource, totals, hits,
_TABLE_SUFFIX AS source_suffix
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`;
