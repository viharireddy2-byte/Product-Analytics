# Scale deployment

## Workload

SQL 22 generates exactly 50M distinct synthetic sessions for 5M returning visitor identities, with 12 nested hits per session across 365 days. Device, acquisition medium, and event patterns are deterministic. This workload measures pipeline capacity; it is not observed customer traffic or an independent behavioral sample.

The shared `raw_sessions` adapter connects this source to the same mart build, refresh procedure, raw benchmark, funnel queries, cohort queries, and Tableau exports used by the public-sample deployment. Both source and mart cardinality are checked during scale deployment.

## Run

Use a dedicated US-location dataset ending in `_scale`. The build creates 600M nested hits. Set compute capacity and per-job byte limits before running.

```bash
export BQ_PROJECT_ID=your-project-id
export BQ_DATASET=commerce_analytics_scale
export BQ_MAX_BYTES=100000000000
bash ops/commerce.sh scale-deploy
bash ops/commerce.sh refresh
bash ops/commerce.sh benchmark
bash ops/commerce.sh recovery-drill
```

The byte limit applies per query job, not to the combined operation. Scale deployment is explicit; scheduled refreshes do not regenerate the raw source. Deployment refuses to overwrite an existing mart. For manual installation, execute SQL 22, 00, 08, 11, and 12 in that order after creating the dataset.

SQL 09 provides a separate single-day replication utility. It does not feed the connected scale pipeline.

## Benchmark outputs

| Artifact | Contents |
|---|---|
| `benchmark_scope.csv` | Project, dataset, total source and mart counts, and reporting dates |
| `benchmark_evidence.csv` | Per-job timing, bytes, slots, cache status, and errors |
| `benchmark_summary.csv` | Median, p95, and average resource use per variant |
| `benchmark_report.json` | Median latency and measured percentage reduction |
| `scale_source.csv` / `scale_mart_gate.csv` | Scale deployment checks |

Benchmarks query the January reporting window over the configured source. Total mart size and reporting-window size are distinct. Result reconciliation, uncached execution, and at least five successful runs per variant are required before producing the report. Include mart construction cost when evaluating amortized query savings.

## Tableau and recovery

Exports are written to `tableau/data`. Open `tableau/commerce_analytics.twb` and follow the workbook guide. GitHub Actions retains generated extracts and metrics as run artifacts.

The recovery drill tests snapshot restoration and row equivalence on a bounded sample in a disposable dataset. It does not measure full-volume recovery time.
