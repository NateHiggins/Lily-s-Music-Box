import json
from pathlib import Path
import tempfile
import unittest
from classify_result import inspect


class ResultBindingControls(unittest.TestCase):
    def test_missing_consumed_artifacts_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = Path(temporary) / "result.json"
            result.write_text(json.dumps({"before": {"files": {}}, "after": {"files": {}}, "artifacts": {}}))
            report = inspect(result, "owner", "fixture")
            self.assertEqual(report["diagnostic_gate_exit"], 1)
            self.assertTrue(any("consumed artifact" in reason for reason in report["artifact_binding_reasons"]))

    def test_pretend_source_stability_does_not_override_binding(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = Path(temporary) / "result.json"
            result.write_text(json.dumps({"source_unchanged": True, "before": {"files": {"fake": "a"}},
                                         "after": {"files": {"fake": "a"}}, "artifacts": {}}))
            report = inspect(result, "owner", "fixture")
            self.assertIn("exact owner/fixture source binding does not match request", report["artifact_binding_reasons"])


if __name__ == "__main__":
    unittest.main()
