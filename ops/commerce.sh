#!/usr/bin/env bash
# Operator tooling only. Analytics logic remains in BigQuery SQL.
set -Eeuo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mode=${1:-verify}
case "$mode" in verify|deploy|refresh|export|benchmark|recovery-drill) ;; *) echo "Unknown mode: $mode" >&2; exit 2;; esac
: "${BQ_PROJECT_ID:?Set BQ_PROJECT_ID to your billing and data project}"
BQ_DATASET=${BQ_DATASET:-commerce_analytics}
BQ_MAX_BYTES=${BQ_MAX_BYTES:-50000000000}
BENCHMARK_RUNS=${BENCHMARK_RUNS:-5}
[[ $BQ_PROJECT_ID =~ ^[a-z][a-z0-9-]{4,61}[a-z0-9]$ ]] || { echo 'Invalid project ID' >&2; exit 2; }
[[ $BQ_DATASET =~ ^[A-Za-z_][A-Za-z0-9_]{0,1023}$ ]] || { echo 'Invalid dataset ID' >&2; exit 2; }
[[ $BQ_MAX_BYTES =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid byte budget' >&2; exit 2; }
[[ $BENCHMARK_RUNS =~ ^([5-9]|1[0-9]|20)$ ]] || { echo 'BENCHMARK_RUNS must be 5–20' >&2; exit 2; }
command -v bq >/dev/null || { echo 'Install and authenticate the Google Cloud CLI (bq)' >&2; exit 2; }
run_tag="$(date -u +%Y%m%dT%H%M%S)_${RANDOM}"
out=${COMMERCE_OUTPUT_DIR:-$root/artifacts/$run_tag}
mkdir -p "$out"
stage=configuration
scratch_dataset=''
cleanup() {
 local status=$?
 trap - EXIT
 if [[ -n $scratch_dataset ]]; then
  bq --project_id="$BQ_PROJECT_ID" --location=US rm -r -f -d "$BQ_PROJECT_ID:$scratch_dataset" >/dev/null 2>&1 || {
   echo "Disposable recovery dataset requires cleanup: $scratch_dataset" >&2
   status=1
  }
 fi
 if ((status)); then echo "Commerce operation failed at stage: $stage" >&2; fi
 exit "$status"
}
trap cleanup EXIT
render() { sed "s/commerce_analytics\./${BQ_DATASET}./g; s/commerce_recovery_drill\./${scratch_dataset:-commerce_recovery_drill}./g" "$1"; }
query() {
 local file=$1 label=$2
 stage=$label
 render "$file" | bq --project_id="$BQ_PROJECT_ID" --location=US --format=csv --job_id="commerce_${run_tag}_${label}" query \
  --use_legacy_sql=false --use_cache=false --maximum_bytes_billed="$BQ_MAX_BYTES" \
  --max_rows=100000 >"$out/$label.csv"
}
inline_query() {
 local label=$1
 stage=$label
 bq --project_id="$BQ_PROJECT_ID" --location=US --format=csv --job_id="commerce_${run_tag}_${label}" query \
  --use_legacy_sql=false --use_cache=false --maximum_bytes_billed="$BQ_MAX_BYTES" \
  --max_rows=100000 >"$out/$label.csv"
}
snapshot() {
 inline_query snapshot <<SQL
CREATE SNAPSHOT TABLE ${BQ_DATASET}.sessions_release_${run_tag}
CLONE ${BQ_DATASET}.sessions
OPTIONS(expiration_timestamp=TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY));
SQL
 echo "Recovery snapshot: ${BQ_PROJECT_ID}.${BQ_DATASET}.sessions_release_${run_tag}"
}
export_dashboard() {
 query "$root/sql/17_dashboard_export.sql" dashboard_daily
 # Atomic local file replacement: an unsuccessful query leaves the prior export intact.
 query "$root/sql/19_funnel_export.sql" funnel
 query "$root/sql/05_cohort_retention.sql" retention
 mkdir -p "$root/tableau/data"
 cp "$out/dashboard_daily.csv" "$root/tableau/data/dashboard_daily.csv.next"
 mv "$root/tableau/data/dashboard_daily.csv.next" "$root/tableau/data/dashboard_daily.csv"
 cp "$out/funnel.csv" "$root/tableau/data/funnel.csv.next"
 mv "$root/tableau/data/funnel.csv.next" "$root/tableau/data/funnel.csv"
 cp "$out/retention.csv" "$root/tableau/data/retention.csv.next"
 mv "$root/tableau/data/retention.csv.next" "$root/tableau/data/retention.csv"
}
case "$mode" in
 verify) query "$root/sql/14_regression_tests.sql" regression
 query "$root/sql/20_cohort_regression_tests.sql" cohort_regression;;
 deploy)
  query "$root/sql/14_regression_tests.sql" regression
  query "$root/sql/20_cohort_regression_tests.sql" cohort_regression
  # This optional entry point refuses to overwrite an existing mart; use refresh for updates.
  stage=dataset
  if ! bq --project_id="$BQ_PROJECT_ID" --location=US show "$BQ_PROJECT_ID:$BQ_DATASET" >/dev/null 2>&1; then
   bq --project_id="$BQ_PROJECT_ID" --location=US mk --dataset "$BQ_PROJECT_ID:$BQ_DATASET"
  fi
  stage=existing_mart
  if bq --project_id="$BQ_PROJECT_ID" --location=US show "$BQ_PROJECT_ID:$BQ_DATASET.sessions" >/dev/null 2>&1; then
   echo 'Mart already exists; use refresh. Existing SQL 00 remains available for explicit full rebuilds.' >&2
   exit 2
  fi
  query "$root/sql/00_build_session_mart.sql" initial_build
  query "$root/sql/08_quality_checks.sql" quality
  query "$root/sql/11_validated_refresh.sql" install_refresh
  query "$root/sql/12_dashboard_publish.sql" dashboard_publish
  export_dashboard;;
 refresh)
  query "$root/sql/14_regression_tests.sql" regression
  query "$root/sql/20_cohort_regression_tests.sql" cohort_regression
  snapshot
  # Fixed historical window: no claim of recent live source data.
  inline_query refresh <<SQL
CALL ${BQ_DATASET}.refresh_sessions(DATE '2017-01-01',DATE '2017-01-31');
SQL
  query "$root/sql/08_quality_checks.sql" quality
  query "$root/sql/18_health_gate.sql" health
  query "$root/sql/12_dashboard_publish.sql" dashboard_publish
  export_dashboard;;
 export) export_dashboard;;
 recovery-drill)
  scratch_dataset="commerce_recovery_${run_tag}"
  stage=recovery_dataset
  bq --project_id="$BQ_PROJECT_ID" --location=US mk --dataset --default_table_expiration=86400 "$BQ_PROJECT_ID:$scratch_dataset"
  query "$root/sql/16_recovery_drill.sql" recovery_drill;;
 benchmark)
  jobs=()
  for ((i=1;i<=BENCHMARK_RUNS;i++)); do
   # Alternate order to reduce systematic warm-cache / load ordering bias.
   if ((i%2)); then variants=(raw mart); else variants=(mart raw); fi
   for variant in "${variants[@]}"; do
    label="bench_${variant}_${i}"
    query "$root/sql/benchmarks/${variant}_funnel.sql" "$label"
    jobs+=("'commerce_${run_tag}_${label}'")
   done
   stage=benchmark_equivalence
   diff -u "$out/bench_raw_${i}.csv" "$out/bench_mart_${i}.csv" >"$out/equivalence_${i}.diff"
  done
  job_list=$(IFS=,; echo "${jobs[*]}")
  inline_query benchmark_evidence <<SQL
WITH runs AS (
 SELECT job_id,IF(STRPOS(job_id,'bench_raw_')>0,'raw','mart') AS variant,
 TIMESTAMP_DIFF(end_time,start_time,MILLISECOND) AS execution_ms,
 total_bytes_processed,total_bytes_billed,total_slot_ms,cache_hit,error_result.reason AS error_reason
 FROM \`region-us\`.INFORMATION_SCHEMA.JOBS_BY_USER
 WHERE creation_time>=TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 DAY)
 AND job_id IN ($job_list)
)
SELECT * FROM runs ORDER BY variant,job_id;
SQL
  inline_query benchmark_gate <<SQL
ASSERT (SELECT COUNT(*)=${BENCHMARK_RUNS}*2 AND COUNTIF(cache_hit OR error_result IS NOT NULL)=0
 FROM \`region-us\`.INFORMATION_SCHEMA.JOBS_BY_USER
 WHERE creation_time>=TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 DAY) AND job_id IN ($job_list))
 AS 'Missing, cached or failed benchmark jobs';
SQL
  inline_query benchmark_summary <<SQL
WITH runs AS (
 SELECT IF(STRPOS(job_id,'bench_raw_')>0,'raw','mart') AS variant,
 TIMESTAMP_DIFF(end_time,start_time,MILLISECOND) AS execution_ms,
 total_bytes_processed,total_slot_ms,cache_hit,error_result.reason AS error_reason
 FROM \`region-us\`.INFORMATION_SCHEMA.JOBS_BY_USER
 WHERE creation_time>=TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 1 DAY) AND job_id IN ($job_list)
), summary AS (
 SELECT variant,COUNT(*) OVER(PARTITION BY variant) AS runs,
 PERCENTILE_CONT(execution_ms,0.5) OVER(PARTITION BY variant) AS median_execution_ms,
 PERCENTILE_CONT(execution_ms,0.95) OVER(PARTITION BY variant) AS p95_execution_ms,
 AVG(total_bytes_processed) OVER(PARTITION BY variant) AS mean_bytes_processed,
 AVG(total_slot_ms) OVER(PARTITION BY variant) AS mean_slot_ms,
 COUNTIF(cache_hit OR error_reason IS NOT NULL) OVER(PARTITION BY variant) AS invalid_runs FROM runs
)
SELECT DISTINCT * FROM summary ORDER BY variant;
SQL
 ;;
esac
printf 'Completed %s. Aggregate results and execution evidence: %s\n' "$mode" "$out"
