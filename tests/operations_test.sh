#!/usr/bin/env bash
# Runs against a fake bq executable; no credentials, cloud access or billable jobs.
set -Eeuo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo/ops" "$tmp/repo/sql"
# Test an isolated repository copy so export-mode tests cannot overwrite real extracts.
cp "$root/ops/commerce.sh" "$tmp/repo/ops/"
cp -R "$root/sql/." "$tmp/repo/sql/"
export PATH="$tmp/bin:$PATH" BQ_PROJECT_ID=commerce-test-project BQ_DATASET=commerce_test
export BQ_MAX_BYTES=2000000000 COMMERCE_OUTPUT_DIR="$tmp/results" MOCK_LOG="$tmp/calls"
cat > "$tmp/bin/bq" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$MOCK_LOG"
args="$*"
if [[ $args == *' show '* ]]; then
 if [[ $args == *'.sessions' ]]; then exit "${MOCK_MART_EXISTS:-1}"; fi
 exit 0
fi
if [[ $args == *' query '* ]]; then
 sql=$(cat)
 printf '%s\n' "$sql" >> "$MOCK_LOG"
 if [[ -n ${MOCK_FAIL_ON:-} && $sql == *"$MOCK_FAIL_ON"* ]]; then exit 1; fi
 if [[ $args == *'bench_raw_'* && ${MOCK_MISMATCH:-false} == true ]]; then
  printf 'total_sessions,product_views,add_to_cart,purchases\n6,4,2,2\n'
 else
  printf 'total_sessions,product_views,add_to_cart,purchases\n5,4,2,2\n'
 fi
fi
MOCK
chmod +x "$tmp/bin/bq"
run() { bash "$tmp/repo/ops/commerce.sh" "$1" >"$tmp/stdout" 2>"$tmp/stderr"; }
reset_log() { : > "$MOCK_LOG"; unset MOCK_FAIL_ON MOCK_MISMATCH MOCK_MART_EXISTS; }
reset_log
run verify
grep -q 'Cohort lookback or denominator regression' "$MOCK_LOG"
! grep -q 'CREATE OR REPLACE TABLE commerce_test.sessions' "$MOCK_LOG"
echo 'PASS: verify executes both fixture suites without building the mart'
reset_log
export MOCK_FAIL_ON='Composite identity collision'
if run refresh; then echo 'Failed regression accepted' >&2; exit 1; fi
! grep -q 'CREATE SNAPSHOT TABLE' "$MOCK_LOG"
echo 'PASS: failed regression blocks snapshot and refresh'
reset_log
export MOCK_FAIL_ON='CALL commerce_test.refresh_sessions'
if run refresh; then echo 'Failed refresh accepted' >&2; exit 1; fi
grep -q 'CREATE SNAPSHOT TABLE commerce_test.sessions_release_' "$MOCK_LOG"
! grep -q 'CREATE TEMP TABLE dashboard_candidate' "$MOCK_LOG"
echo 'PASS: snapshot precedes refresh; failed refresh blocks dashboard publication'
reset_log
export MOCK_FAIL_ON='Dashboard session reconciliation failed'
if run refresh; then echo 'Failed dashboard validation accepted' >&2; exit 1; fi
! grep -q 'COALESCE(device_type' "$MOCK_LOG"
echo 'PASS: dashboard failure blocks exports'
reset_log
run recovery-drill
grep -q 'CREATE SNAPSHOT TABLE commerce_recovery_' "$MOCK_LOG"
grep -q ' rm -r -f -d commerce-test-project:commerce_recovery_' "$MOCK_LOG"
! grep -q 'DELETE FROM commerce_test.sessions' "$MOCK_LOG"
echo 'PASS: recovery drill mutates disposable tables and cleans its dataset'
reset_log
export MOCK_FAIL_ON='Fault injection failed'
if run recovery-drill; then echo 'Failed drill accepted' >&2; exit 1; fi
grep -q ' rm -r -f -d ' "$MOCK_LOG"
echo 'PASS: failed recovery drill still cleans its dataset'
reset_log
export MOCK_MART_EXISTS=0
if run deploy; then echo 'Existing mart overwrite accepted' >&2; exit 1; fi
! grep -q 'CREATE OR REPLACE TABLE commerce_test.sessions' "$MOCK_LOG"
echo 'PASS: deployment refuses to overwrite an existing mart'
reset_log
export MOCK_MISMATCH=true
if run benchmark; then echo 'Unequal benchmark accepted' >&2; exit 1; fi
! grep -q 'PERCENTILE_CONT' "$MOCK_LOG"
echo 'PASS: unequal benchmark outputs block performance summary'
reset_log
run benchmark
grep -q 'PERCENTILE_CONT' "$MOCK_LOG"
grep -q -- '--use_cache=false' "$MOCK_LOG"
grep -q -- '--maximum_bytes_billed=2000000000' "$MOCK_LOG"
[[ $(grep -c 'job_id=.*bench_\(raw\|mart\)_.* query ' "$MOCK_LOG") == 10 ]]
echo 'PASS: benchmark repeats five pairs with cache disabled and byte limits'
reset_log
export MOCK_FAIL_ON='Latest refresh failed or audit is empty'
if run refresh; then echo 'Unhealthy refresh accepted' >&2; exit 1; fi
! grep -q 'CREATE TEMP TABLE dashboard_candidate' "$MOCK_LOG"
echo 'PASS: failed health gate blocks dashboard publication'
reset_log
mkdir -p "$tmp/repo/tableau/data"
printf 'prior export' > "$tmp/repo/tableau/data/dashboard_daily.csv"
export MOCK_FAIL_ON='First observed cohort'
if run export; then echo 'Failed retention export accepted' >&2; exit 1; fi
[[ $(cat "$tmp/repo/tableau/data/dashboard_daily.csv") == 'prior export' ]]
echo 'PASS: failed final query preserves previous Tableau export'
reset_log
export MOCK_FAIL_ON='Missing, cached or failed benchmark jobs'
if run benchmark; then echo 'Invalid benchmark evidence accepted' >&2; exit 1; fi
! grep -q 'PERCENTILE_CONT' "$MOCK_LOG"
echo 'PASS: invalid benchmark job evidence blocks summary'
reset_log
export BQ_DATASET='bad;DROP'
if run verify; then echo 'Unsafe dataset accepted' >&2; exit 1; fi
[[ ! -s $MOCK_LOG ]]
echo 'PASS: invalid identifiers fail before CLI invocation'

# Detect drift between the production transformation and the bundled funnel fixtures.
production_tail=$(sed -n '/), deduplicated AS (/,$p' "$root/sql/00_build_session_mart.sql")
fixture_tail=$(sed -n '/), deduplicated AS (/,$p' "$root/sql/14_regression_tests.sql" | sed '/^ASSERT/,$d')
[[ $production_tail == "$fixture_tail" ]]
echo 'PASS: funnel fixture transformation matches the production SQL'
