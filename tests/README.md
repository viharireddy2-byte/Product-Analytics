# Verification

Run `bash tests/operations_test.sh` for offline operational checks. The harness copies the operator and SQL files into a temporary repository, installs a fake `bq` executable on PATH, and removes its files on exit. It does not use cloud credentials, mutate Tableau data or incur query charges.

The checks cover credential-free verify mode, failed regression and refresh ordering, snapshot-before-refresh, blocked dashboard exports, recovery dataset isolation and cleanup, existing-mart protection, benchmark equivalence and evidence gates, byte limits, disabled result cache, invalid configuration and transformation consistency. Mock results prove control flow only; they do not establish BigQuery compatibility or measured performance.

For real SQL assertions run `bash ops/commerce.sh verify` after configuring your cloud project. Script 14 covers ordered funnels and composite identity. Script 20 covers lookback exclusion, cohort denominators, zero-filled months and partial-month retention. Then deploy to a validation dataset, run quality checks, compare aggregates, execute a recovery drill and collect repeated benchmark evidence. Local SQL translation or parsing cannot validate BigQuery procedure control flow, snapshots, IAM, billing or dashboard rendering.

The GitHub repository-check workflow executes the offline harness on every push and pull request. The separately configured cloud workflow runs warehouse operations with short-lived authentication.
