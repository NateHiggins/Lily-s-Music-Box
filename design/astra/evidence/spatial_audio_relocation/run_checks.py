"""Reproduce the narrow manifest relocation controls without editing production."""

from pathlib import Path
import hashlib
import io
import json
import subprocess
import sys
import unittest

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[3]
sys.path.insert(0, str(ROOT / "tools/tests"))
import test_orison_spatial_dependencies as suite


def main():
    receipt_path = EVIDENCE / "receipt.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    source = ROOT / "game/scripts/audio/audio_policy.gd"
    before_source = hashlib.sha256(source.read_bytes()).hexdigest()
    original = suite.run_main
    phases = []
    names = ["fixture_baseline", "fixture_relocated_old_manifest",
             "fixture_exact_mapping", "fixture_unreviewed_family"]

    def recorded(*argv):
        code, out, err = original(*argv)
        name = names[len(phases)]
        (EVIDENCE / (name + ".stdout.txt")).write_text(out, encoding="utf-8")
        (EVIDENCE / (name + ".stderr.txt")).write_text(err, encoding="utf-8")
        phases.append({"name": name, "exit_code": code,
                       "arguments": list(argv)})
        return code, out, err

    suite.run_main = recorded
    report = io.StringIO()
    test = suite.DriftTests("test_generated_name_relocation_requires_exact_review")
    result = unittest.TextTestRunner(stream=report, verbosity=2).run(test)
    suite.run_main = original
    (EVIDENCE / "fixture_selftest.txt").write_text(report.getvalue(), encoding="utf-8")
    assert result.wasSuccessful(), report.getvalue()
    assert [p["exit_code"] for p in phases] == [0, 1, 0, 1], phases
    receipt["fixture_phases"] = phases

    for name, arguments in (
            ("production_new", ["tools/audit_orison_spatial_dependencies.py", "--json"]),
            ("full_selftest", ["tools/tests/test_orison_spatial_dependencies.py"])):
        command = [sys.executable, *arguments]
        run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        (EVIDENCE / (name + ".stdout.txt")).write_text(run.stdout, encoding="utf-8")
        (EVIDENCE / (name + ".stderr.txt")).write_text(run.stderr, encoding="utf-8")
        receipt[name] = {"command": command, "exit_code": run.returncode}
        assert run.returncode == 0, run.stdout + run.stderr

    after_source = hashlib.sha256(source.read_bytes()).hexdigest()
    assert after_source == before_source
    receipt["production_audio_source_unchanged"] = after_source
    receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"fixture_exits": [p["exit_code"] for p in phases],
                      "production_exit": receipt["production_new"]["exit_code"],
                      "selftest_exit": receipt["full_selftest"]["exit_code"]}, indent=2))


if __name__ == "__main__":
    main()
