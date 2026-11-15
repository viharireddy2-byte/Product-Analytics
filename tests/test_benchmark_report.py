import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('report', Path(__file__).parents[1] / 'ops/benchmark_report.py')
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


def evidence(raw=10000, mart=4000):
    return [dict(job_id=f'{variant}_{i}', variant=variant, execution_ms=str(ms),
                 cache_hit='false', error_reason='')
            for variant, ms in [('raw', raw), ('mart', mart)] for i in range(5)]


class BenchmarkTests(unittest.TestCase):
    def test_latency_reduction(self):
        result = report.assess(evidence())
        self.assertEqual(result['latency_reduction_percent'], 60)

    def test_regression_reports_negative_reduction(self):
        self.assertEqual(report.assess(evidence(mart=12000))['latency_reduction_percent'], -20)

    def test_reject_invalid_evidence(self):
        for field, value in [('cache_hit', 'true'), ('error_reason', 'timeout'), ('execution_ms', '0')]:
            rows = evidence()
            rows[0][field] = value
            with self.assertRaises(ValueError):
                report.assess(rows)
        with self.assertRaises(ValueError):
            report.assess(evidence()[:-1])
        rows = evidence()
        rows[1]['job_id'] = rows[0]['job_id']
        with self.assertRaises(ValueError):
            report.assess(rows)


if __name__ == '__main__':
    unittest.main()
