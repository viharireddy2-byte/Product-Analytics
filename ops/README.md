# Warehouse operations

Analytics remains BigQuery SQL with Tableau and Amplitude. Bash is a thin operator wrapper around `bq`; GitHub Actions runs the wrapper. Neither is an application service. The existing numbered SQL entry points still work independently.

## Local prerequisites and configuration

Use Bash 4+, Google Cloud CLI with `bq`, a billable project, the BigQuery API, and authentication with the deployment identity. All datasets must be US multi-region to match the public source. The pipeline uses the configured project for both billing and tables.

```bash
export BQ_PROJECT_ID="$(gcloud config get-value project)"
export BQ_DATASET=commerce_analytics
export BQ_MAX_BYTES=50000000000
bash tests/operations_test.sh
bash ops/commerce.sh verify
bash ops/commerce.sh deploy
```

`deploy` is a first-time install and refuses to overwrite an existing mart. If the dataset was already created, use its existing location; the first query will reject an incompatible region. If a first-time installation stops after creating the mart, fix the failing check, execute the remaining SQL 08/11/12 manually, and use refresh for subsequent operations. Script 00 remains available for an explicit full rebuild.

| Mode | Behavior |
|---|---|
| scale-deploy | Install a connected 50M-session synthetic source and mart in a dedicated `_scale` dataset; see [scale guide](scale.md) |
| verify | Run self-contained funnel and retention regression fixtures in BigQuery |
| deploy | Verify, create dataset if absent, build once, validate, install procedure, publish and export |
| refresh | Verify, take a seven-day snapshot, refresh January partitions, validate, health-gate, publish and export |
| export | Export published daily totals, funnel and retention to Tableau CSV files |
| benchmark | Run 5–20 alternating pairs of raw-hit and session-mart funnel queries with result equivalence and job-evidence checks |
| recovery-drill | Sample up to 10K mart rows, snapshot, delete, restore and compare in a disposable dataset |

```bash
bash ops/commerce.sh refresh
bash ops/commerce.sh benchmark
bash ops/commerce.sh recovery-drill
```

Refresh deliberately reprocesses January 2017, not today's date. This is a historical-source application. Change the procedure call only when selecting another valid historical window. Serialize manual writers with scheduled runs; GitHub concurrency only covers this repository's cloud workflow.

`BQ_MAX_BYTES` is the per-query-job billed-byte limit, not a total pipeline spending cap; BigQuery also applies statement-specific behavior to scripts. The pipeline has multiple jobs. Review each query estimate and configure project/reservation budgets separately. Default benchmark repetitions are five; set `BENCHMARK_RUNS` to an integer between 5 and 20. Synthetic script 09 is never executed by the runner or scheduled workflow.

Results are written to an ignored run directory under `artifacts/`. `COMMERCE_OUTPUT_DIR` can select another output directory. No real performance values are prepopulated. Benchmark evidence includes exact job IDs, execution milliseconds, bytes and slot milliseconds. Result caching is disabled. Output mismatch, cached jobs, failed jobs or missing job evidence block summary generation. Summaries report exact median and interpolated p95 over the observed repetitions; five runs are a small sample, not a service latency guarantee. Include mart build cost separately when discussing amortized query savings.

## GitHub Actions

`checks.yml` runs shell syntax and isolated CLI failure-path tests on pushes and pull requests. It has no cloud credentials. `cloud.yml` runs real warehouse tests and operations using short-lived Workload Identity Federation, only on manual dispatch or an explicitly enabled schedule. It never authenticates on pull requests.

Create a GitHub environment named `commerce-cloud`. Configure these **repository variables** (the scheduled-job condition is evaluated before environment variables are available):

| Variable | Value to configure |
|---|---|
| BQ_PROJECT_ID | Your existing Google Cloud project ID |
| BQ_DATASET | Target dataset; defaults to commerce_analytics when empty |
| BQ_MAX_BYTES | Positive per-job byte ceiling; defaults to 50,000,000,000 |
| WORKLOAD_IDENTITY_PROVIDER | Full resource name of your GitHub OIDC provider |
| SERVICE_ACCOUNT | Dedicated deployment service-account email |
| COMMERCE_SCHEDULE_ENABLED | Set to true only after manual verify, deploy and refresh succeed |

Configure the Google identity provider to restrict both the repository identity and the permitted deployment environment/ref. Grant only the selected GitHub principal permission to impersonate the deployment service account. Do not use long-lived JSON keys. Environment protection rules can restrict deployment branches and require approval if your organization needs it.

Run manual **verify**, then **deploy** (or complete installation for an existing mart), **refresh**, **benchmark** and **recovery-drill**. Enabling the schedule runs refresh at 12:17 UTC daily. GitHub schedules can be delayed and are not a strict-time scheduler. The concurrency group serializes all cloud modes for the configured project/dataset. Change the cron or disable the repository variable to pause scheduled runs.

Failed jobs produce GitHub error annotations and a failed workflow status. Configure GitHub Actions notification preferences for the repository to receive failure notifications. No Slack/email destination is hard-coded or contacted by this project. Set an independent missed-run alert in your cloud monitoring if an overdue GitHub schedule must be detected even when no workflow starts. Script 18 gates processing freshness during refresh; it cannot detect a workflow that never ran.

## Access boundaries

The deployment identity needs project-level query-job creation, target dataset table/routine read/write permissions, and snapshot creation/restoration permissions. Dataset creation during deploy and the isolated drill also require dataset-create permission. For tighter deployments, precreate datasets and use a separate drill identity/project; the supplied drill runner creates its disposable dataset itself. Keep public sample reads permitted and restrict routine execution to trusted writers.

Grant BI readers table-level access to `dashboard_daily`, rather than broad access to `sessions` or `refresh_audit`. Tableau files contain aggregates only. Do not grant a public Tableau connection the deployment identity. Audit errors may contain warehouse identifiers. Review artifact visibility in public GitHub repositories; the workflow uploads aggregates and execution evidence, never visitor-level session exports. Generated credential files and Tableau data are ignored by git.

## Recovery and promotion

Every runner refresh creates `sessions_release_<run-tag>` before calling the refresh procedure. The snapshot expires after seven days. The operation prints its fully qualified name. For a failed candidate validation or transaction, the existing mart stays available; inspect the failure before retrying the same window. A snapshot failure blocks refresh.

A logical defect discovered after publication requires restoring an approved snapshot. Pause scheduled runs and serialize other writers. In BigQuery, restore the selected snapshot into a **new** table using `CREATE TABLE ... CLONE ...`, run script 08 against that restored table by replacing its sessions reference, and compare counts and schema before promoting it with a reviewed BigQuery table copy. Keep the current table's snapshot before promotion, republish aggregates with script 12, then export. Do not overwrite the source table merely to test recovery.

The `recovery-drill` mode automates fault injection and restore comparison in a uniquely named disposable dataset, cleans it even after a failure, and sets default one-day table expiry as a fallback. A failed cleanup exits nonzero and prints the dataset requiring removal. This is a bounded recovery exercise, not a full-volume RTO/RPO measurement. Record real drill duration and job IDs from cloud runs before quoting recovery metrics.

## Platform references

- [bq CLI reference](https://docs.cloud.google.com/bigquery/docs/reference/bq-cli-reference)
- [Create snapshots](https://docs.cloud.google.com/bigquery/docs/table-snapshots-create)
- [Restore snapshots](https://docs.cloud.google.com/bigquery/docs/table-snapshots-restore)
- [GitHub authentication action](https://github.com/google-github-actions/auth)
- [Cloud SDK setup action](https://github.com/google-github-actions/setup-gcloud)
