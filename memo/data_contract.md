# Data and metric contracts

## Session table

`commerce_analytics.sessions` has one row per `(visitor_id, visit_id)`. `session_key` serializes the pair as JSON to avoid ambiguous concatenations. Duplicate source keys use the earliest date and deterministic event/dimension ordering. This deterministic policy does not infer which source duplicate is freshest; quality investigations should review conflicting records upstream.

| Column | BigQuery type | Meaning |
|---|---|---|
| session_date | DATE | Source session calendar date; partition key |
| visitor_id | STRING | Source pseudonymous fullVisitorId; not a verified person |
| visit_id | INT64 | Source visitId; unique only with visitor_id |
| session_key | STRING | JSON composite session identity |
| device_type | STRING | Source device category |
| traffic_medium | STRING | Source trafficSource.medium, including null/unknown |
| transactions | INT64 | Reported session transactions, null normalized to zero |
| view_ms | INT64 | Earliest product-view offset |
| cart_ms | INT64 | Earliest cart strictly after earliest view |
| purchase_ms | INT64 | Earliest purchase strictly after eligible cart |
| has_cart | BOOL | Any source cart event, regardless of ordering |
| has_purchase | BOOL | Any source purchase event, regardless of ordering |

Action types: product view `2`, cart `3`, purchase `6`. Offsets are milliseconds from the session start. Same-time events do not qualify as ordered progression. A purchase without a recorded view/cart remains visible in diagnostics but is excluded from the strict funnel. This is instrumentation completeness, not necessarily abandoned checkout.

## Query outputs

| SQL | Output grain | Contract |
|---|---|---|
| 01 | one reporting window | session rows and distinct visitors |
| 02 | one reporting window | nested stage counts and session-to-purchase fraction |
| 03 | device | same funnel contract, grouped by device |
| 04 | traffic medium | same funnel contract, grouped by medium |
| 05 | cohort age month | distinct active visitors / initial observed cohort size |
| 06 | mobile window | ordered carts, ordered purchases, purchase/cart fraction |
| 07 | experiment | rates, absolute and relative lift, z statistic, lift interval and decision |
| 08 | validation run | checked sessions plus excluded unordered-event diagnostics |
| 09 | synthetic session | replicated source schema and namespaced identities |
| 10 | query job | latency, bytes, slot milliseconds, cache and failure state |

All rates are fractions (0–1), except signed lift and relative lift. Format as percentages only in the visualization layer. Zero denominators produce null rather than artificial zeros. Cohorts use the earliest visit observed since the configured history start; earlier unobserved history is left-censored. Month zero includes any observed session, not just purchases.

Experiments assume independent randomized units, a binary outcome per unit, no peeking or multiple-testing adjustment, and two-sided alpha 0.05. The z test uses a pooled null standard error; the approximate 95% lift interval uses the unpooled standard error. Sparse samples require exact inference before a shipping decision. Session counts are unsuitable if assignment is at visitor level and visitors repeat.

## Operational tables

`refresh_audit`: run_id STRING, started_at/completed_at TIMESTAMP, refresh_start/refresh_end DATE, staged_rows INT64, status STRING and error_message STRING. Status is succeeded or failed. Pre-publication errors are recorded by the procedure's exception handler when audit writes are permitted; a lost permission or job cancellation can prevent recording, so monitor job failures as well.

`dashboard_daily`: one row per session_date DATE, device_type STRING and traffic_medium STRING; sessions, daily_visitors, product_views, carts, purchases and unordered_purchases are INT64. published_at TIMESTAMP records publication time. Counts are additive except daily_visitors. No visitor identifiers are included. Source ranges remain bounded to the historical public sample.

## Tableau interfaces

SQL 17 exports daily segment rows with session_date, device_type, traffic_medium, sessions, product_views, carts, purchases, unordered_purchases and published_at. It intentionally omits daily_visitors to prevent accidental summation. SQL 19 exports four ordered funnel stages (ordinal, stage, sessions). SQL 05 exports cohort age, active users, cohort size, retention rate and the partial-month flag. The workbook binds to these column names. The daily and funnel exports cover the full sample; the cohort export uses the January defaults. Keep windows aligned when creating additional cross-panel calculations.
