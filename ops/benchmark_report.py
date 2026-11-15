#!/usr/bin/env python3
"""Turn successful, uncached BigQuery job evidence into a performance report."""
import csv
import json
import statistics
import sys
from pathlib import Path


def assess(rows):
    groups = {'raw': [], 'mart': []}
    seen = set()
    for row in rows:
        job = row['job_id']
        if job in seen:
            raise ValueError('Duplicate benchmark job')
        seen.add(job)
        if row['cache_hit'].lower() != 'false' or row['error_reason'].strip().lower() not in ('', 'null'):
            raise ValueError('Cached, failed, or incomplete job evidence')
        value = int(row['execution_ms'])
        if value <= 0:
            raise ValueError('Nonpositive execution time')
        groups[row['variant']].append(value)
    if len(groups['raw']) != len(groups['mart']) or len(groups['raw']) < 5:
        raise ValueError('At least five equal raw/mart runs required')
    raw, mart = (statistics.median(groups[k]) for k in ('raw', 'mart'))
    reduction = 100 * (raw - mart) / raw
    return {'runs_per_variant': len(groups['raw']), 'raw_median_ms': raw,
            'mart_median_ms': mart, 'latency_reduction_percent': reduction,
            'scope': 'Reporting-window funnel over configured source; synthetic when scale-deploy was used'}


def main():
    output = Path(sys.argv[1])
    with (output / 'benchmark_evidence.csv').open(newline='') as stream:
        result = assess(list(csv.DictReader(stream)))
    (output / 'benchmark_report.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
