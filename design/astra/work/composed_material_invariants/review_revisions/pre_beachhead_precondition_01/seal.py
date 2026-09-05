from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
command = [sys.executable, "-m", "unittest", "discover", "-s", str(HERE), "-p", "test_*.py", "-v"]
run = subprocess.run(command, cwd=HERE, capture_output=True)
(HERE / "controls.stdout.log").write_bytes(run.stdout)
(HERE / "controls.stderr.log").write_bytes(run.stderr)
artifacts = {}
for path in sorted(HERE.rglob("*")):
    if path.is_file() and "__pycache__" not in path.parts and path.name != "preparation_receipt.json":
        artifacts[path.relative_to(HERE).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
receipt = {"status": "PREPARED_ONLY_NO_LIVE_GAME_INSTALL_NO_ENGINE",
           "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
           "fixture_binding": json.loads((HERE / "preparation.json").read_text()),
           "marker_control": json.loads((HERE / "controls/build_marker_omission/receipt.json").read_text()),
           "pure_controls": {"command": command, "exit": run.returncode, "tests": 20},
           "expected_complete_v1_checks": {"full": 314, "root_retirement": 305},
           "runtime_status": "NOT_RUN; counts are declared expectations, not observed results",
           "source_review": ["Exact original transition method and all original assertion calls retained",
                             "Actual installed cache requires ancestry/mesh/slot/no-full-override guard",
                             "Every active field requires registry key coverage",
                             "Synchronous force/lifecycle probe restores original dictionary and actual material state before any await"],
           "pending": ["Final reviewed source/lane handoff", "Godot parser/setup verification",
                       "Actual composed ownership baseline", "Selective build-marker red and exact restored green",
                       "Matched one-census comparison only after separate equivalence", "Final uninstrumented full renderer scope"],
           "artifacts": artifacts}
(HERE / "preparation_receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps({"status": receipt["status"], "tests": 20, "exit": run.returncode,
                  "fixture_sha256": receipt["fixture_binding"]["proposed_fixture_sha256"],
                  "artifact_count": len(artifacts)}, indent=2))
raise SystemExit(run.returncode)
