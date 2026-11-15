# Operations and benchmark methodology

## Verification

Run `14_regression_tests.sql` in BigQuery before deployment. The fixtures cover duplicate sessions, composite identities, empty events, reversed events, tied timestamps and repeated carts. No production table is read or written. This fixture transformation must stay aligned with script 00. Run script 08 on deployed data as a separate integration check. Local parsing and translated fixture execution do not replace a BigQuery integration run.

## Release checks

Execute the mart build and `08_quality_checks.sql` in a separate validation dataset before publishing warehouse changes. Replace dataset names consistently across scripts. Compare sessions, visitors, stage counts and segment totals against the prior release over identical dates. Confirm no missing source days. Reconcile Tableau totals against SQL before publishing an extract. An assertion failure stops release; inspect source records rather than loosening checks.

The full rebuild includes all available sample dates. For a live source, define ingestion completeness and late-arrival policy before changing it to incremental loading. Required partition filters prevent accidental unbounded mart scans. They do not impose a monetary budget.

## Reproducible capacity workload

For a connected multi-day 50M-session pipeline, use [scale deployment](../ops/scale.md). The single-day utility below is a separate diagnostic workload.

`09_scale_workload.sql` creates exactly `target_rows`, default 50,000,000, from one populated source day. Each replica receives a distinct visitor and session identity. Device and funnel distributions are copied, all rows retain the source date, and traffic is correlated. This tests row volume and cluster filtering on a single partition; it cannot demonstrate multi-day partition pruning, realistic cohort behavior, independent-user experiment power, or 50M real visitors.

For a partition-pruning experiment use the real multi-day mart, with a bounded full-history control query and a single-day candidate using identical selected columns. Do not compare different date ranges as equivalent business results. For a repeated-dashboard experiment compare repeated raw-hit queries against the equivalent session mart aggregates, validating counts first. Report mart build cost separately and calculate the query count needed to amortize it.

Disable result caching in Query settings. Run each candidate at least five times in alternating order under the same reservation and concurrency. Retain job IDs, query text, dates, row counts, bytes, slot milliseconds, elapsed time, errors, and cache status. Report median and tail latency, distinguish cold and warm storage effects, and exclude script parent jobs. `10_benchmark_jobs.sql` returns job-level evidence; correlate it to the exact workload job IDs. Dynamic scripts may need an actual execution rather than a dry run for accurate estimates.

## Recovery and access

Keep an approved copy or snapshot before a schema migration. A failed single-statement rebuild leaves the prior table available; if validation fails after publication, restore the approved version and rerun downstream extracts. Test recovery in the deployment project. Use a dedicated writer for builds and read-only BI identities. Restrict row-level identifiers and export only aggregate cohorts and segments to public Tableau workbooks. Review Amplitude data handling before uploading visitor-level records.

## Validated partition refresh

After the initial full build, install script 11 once. Call:

```sql
CALL commerce_analytics.refresh_sessions(DATE '2017-01-01', DATE '2017-01-31');
```

The procedure stages and validates the requested dates before touching the session table. A transaction replaces only that window and writes a success audit record atomically. Repeating a call replaces the same window, avoiding accumulated duplicate rows. Missing dates or invalid candidate rows abort before publication. Failure audit entries capture the warehouse error; restrict audit-table access because errors may contain identifiers. Overlapping writers may encounter transaction conflicts: serialize refresh scheduling, inspect audit status, and retry the same bounded window. The dataset is a historical sample, so schedule an explicit fixed window rather than CURRENT_DATE.

Run script 12 after a successful refresh to validate and publish the dashboard aggregate. Session mart and dashboard publication are separate jobs: the dashboard can lag; expose `published_at` and alert on failures. Schedule script 15 after each run and alert on any health value other than healthy through the deployment team's monitoring integration. It supplies health status; it does not send alerts itself. The optional GitHub Actions cloud workflow and failure notification integration are documented in ops/README.md. External notification preferences and cloud identity still require deployment configuration.

The build identity needs table DML access and routine creation/execution permission. BI identities should read only dashboard_daily. There are no credentials in the repository. Keep aggregate publication behind validation and use an approved snapshot for recovery drills.

## Experiment guardrails

Script 13 tests assigned-arm balance against the configured allocation using a one-degree-of-freedom chi-square threshold at alpha 0.001. The normal approximation requires sufficient expected arm counts. A mismatch flags randomization or logging defects; balance alone cannot prove randomization. Sample-size planning assumes equal allocation, a fixed two-sided alpha 0.05 test and 80% power. The minimum detectable lift is absolute percentage-point change. Unequal allocation requires different planning. No automatic rollout decision follows from these outputs.

## Runnable operations

The runner in `ops/commerce.sh` executes the release sequence, takes pre-refresh snapshots and stops after failed checks. The isolated shell tests cover failure ordering and CLI settings; authenticated SQL suites cover the funnel and retention contracts. `sql/16_recovery_drill.sql` exercises snapshot recovery on an isolated bounded sample. The benchmark pair under `sql/benchmarks/` uses matching January windows and ordered-funnel definitions. `tableau/commerce_analytics.twb` consumes exports generated only after all export queries succeed. See [operator setup](../ops/README.md) for configuration and [workbook setup](../tableau/README.md) for visualization validation.
