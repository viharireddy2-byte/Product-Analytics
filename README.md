# Product Analytics

BigQuery SQL analytics for understanding where shoppers leave the purchase journey, which acquisition channels convert, and whether customers return. Amplitude supports event-level exploration; Tableau supports executive reporting. The warehouse remains the source of metric definitions.

## Capabilities

- Session and visitor counts using composite visitor/visit identities.
- Strict product-view → add-to-cart → purchase funnels, with device and traffic-medium breakdowns.
- First-observed monthly cohorts, retention rates, zero-filled months, and partial-period flags.
- Mobile checkout baseline and two-proportion experiment inference with uncertainty intervals.
- Partitioned, clustered session mart with repeatable rebuilds and SQL quality assertions.
- Opt-in synthetic workload supporting exactly 50 million rows; query-job cost and latency inspection.

## Stack and structure

BigQuery Standard SQL, Google Analytics public session data, Amplitude, and Tableau. All analysis stays in SQL. Optional Bash/Google Cloud CLI tooling and GitHub Actions provide deployment operations; no application server or additional analytics runtime is introduced.

```text
sql/          numbered warehouse build, analysis, quality, and workload scripts
memo/         metric contract, operating guide, analysis and performance methodology
screenshots/  instructions for reproducible dashboard exports
ops/          bounded cloud operations, snapshots and benchmark runner
tests/        isolated operational failure-path tests
tableau/      native Tableau workbook connected to aggregate exports
.github/      local checks and optional authenticated cloud workflow
```

## Architecture

Raw date-sharded Google Analytics sessions are normalized into `commerce_analytics.sessions`. Nested hits are processed within each session; deduplication produces one visitor/visit row. The table partitions by session date and clusters by device, medium, and visitor. Analysis scripts query this table with mandatory date filters. Tableau consumes query results; Amplitude consumes event exports with equivalent identity and funnel rules.

The build is a bounded full refresh, published through one `CREATE OR REPLACE TABLE` statement. The optional operations runner performs validated partition refreshes after initial installation, with pre-refresh snapshots and audit history. Candidate validation and transactional replacement protect the mart. A separate validated aggregate publication feeds Tableau. GitHub Actions can schedule the runner; manual SQL remains supported.

## Deploy and run

1. Use a Google Cloud project with billing and BigQuery enabled. Create `commerce_analytics` in the **US** location, matching the public dataset. The executing identity needs query-job permission on the billing project and table read/write permission on the target dataset.
2. In BigQuery Studio, select that project, use GoogleSQL, and execute `sql/00_build_session_mart.sql`.
3. Execute `sql/08_quality_checks.sql`. Any failed assertion blocks dashboard publication.
4. Run `01`–`06` for the January 2017 analysis. Date variables at the top of each script control the window. The sample covers August 2016 through August 1, 2017; do not interpret absent later data as zero traffic.
5. Run `07` to inspect the illustrative experiment calculation. Replace demonstration counts only with validated randomized experiment aggregates.
6. Connect Tableau to the query outputs, or save results as CSV and import extracts. Follow [visualization setup](screenshots/README.md) for dashboard definitions and Amplitude reconciliation.

Optional CLI setup and execution (Google Cloud CLI is an operator tool):

```bash
bq --location=US mk --dataset commerce_analytics
bq query --location=US --use_legacy_sql=false < sql/00_build_session_mart.sql
bq query --location=US --use_legacy_sql=false < sql/08_quality_checks.sql
bq query --location=US --use_legacy_sql=false < sql/02_full_funnel.sql
```

Review query estimates and set job byte limits appropriate to your budget. Script estimates may not cover every statement. `09_scale_workload.sql` writes a large table and must be run explicitly. It is excluded from normal deployment. Delete `commerce_analytics.synthetic_sessions` after testing. Never publish visitor identifiers or row-level event exports to a public dashboard.

## Database and metric documentation

See [metric and table contracts](memo/data_contract.md), [analysis guide](memo/analysis.md), and [operations and benchmark guide](memo/operations.md). The SQL result sets are the integration interface; this project exposes no HTTP API.

## Performance and scale

The 50M-row workload is executable synthetic capacity testing, not a claim of 50M observed customer sessions. Production latency and cost depend on the actual project and reservation. No cloud execution measurements are claimed in this repository. The operating guide defines a reproducible measurement protocol; script 10 captures real job evidence.

## Engineering choices

The SQL-first folder layout and BigQuery/Amplitude/Tableau approach remain intact. Added SQL modules introduce a reusable mart, ordered conversion semantics, quality gates, uncertainty estimates, and a scale harness. Ordered funnels intentionally differ from independent event-presence counts. Retention measures observed activity, not repeat purchases. Additional modules provide validated transactional partition refreshes, audit history, dashboard aggregate reconciliation, experiment allocation checks and executable regression fixtures. The repository includes optional scheduling, failure notifications, a snapshot recovery drill, a benchmark collector and a Tableau workbook. Cloud identity, access policy, workflow variables, live BI validation and measured execution evidence belong to the deployment environment.

## Operational modules

| Script | Purpose |
|---|---|
| 11 | Install validated partition-refresh procedure and audit table |
| 12 | Validate and publish daily dashboard aggregates |
| 13 | Experiment allocation check and approximate sample-size planning |
| 14 | Self-contained SQL regression fixtures |
| 15 | Refresh failure and processing-freshness health status |

Recommended release order: run 14, build with 00, validate with 08, install 11, publish with 12. Subsequent bounded refreshes use the procedure from 11, then 08 and 12. Run 15 to inspect refresh health after procedure calls. Script 00 remains the original full-refresh entry point and does not populate procedure audit history. See the operating guide for recovery and scheduler integration.

Tableau can read `commerce_analytics.dashboard_daily` directly. Sum stage counts to compute conversion rates. `daily_visitors` is non-additive across dates and segments; use query 01 for distinct visitors over a reporting window. `published_at` records aggregate publication time. Amplitude setup remains documented in screenshots/README.md; no live workbook or account integration is claimed.

## Automated operations and dashboard

See [operator setup](ops/README.md) for first-time installation, Workload Identity Federation, byte budgets, scheduling, alerts, recovery and repeated benchmarks. Start with `bash tests/operations_test.sh`; these tests use an isolated fake CLI and incur no cloud cost. The authenticated cloud workflow runs the actual SQL fixture suites. Existing SQL files can still be executed directly.

[Open the Tableau workbook setup](tableau/README.md). The native workbook includes nine worksheets: four funnel KPI cards, daily conversion, device and medium conversion, a stage funnel, and January cohort retention. The export runner writes its aggregate data files; it does not publish a Tableau Public site automatically.

SQL 16 performs the isolated snapshot recovery drill; 17 and 19 define Tableau exports; 18 is an executable freshness/failure gate; 20 adds retention regression cases. SQL under `sql/benchmarks/` provides equivalent raw-hit and mart queries over January 2017. No schedule, cloud deployment, benchmark outcome or Tableau rendering is represented as already verified without the corresponding account execution.
