from pathlib import Path
import json
import shutil
import subprocess
import sys
import marker_omission

HERE = Path(__file__).resolve().parent
archive = HERE / "controls/marker_preparation_failure_01"
assert not archive.exists()
archive.mkdir(parents=True)
for name in ("marker_omission.py", "test_marker_omission.py"):
    shutil.copy2(HERE / name, archive / name)
result = subprocess.run([sys.executable, "-m", "unittest", "test_marker_omission", "-v"],
                        cwd=HERE, capture_output=True)
(archive / "stdout.log").write_bytes(result.stdout)
(archive / "stderr.log").write_bytes(result.stderr)
raw = marker_omission.BASE.read_bytes()
lines = [repr(line) for line in raw.splitlines(keepends=True) if b'material.set_meta("living_storey", floor_id)' in line]
(archive / "receipt.json").write_text(json.dumps({"exit": result.returncode, "scope": "offline transform preparation, no engine",
    "reason": "exact reviewed source has LF line endings; initial control assumed CRLF", "matching_source_lines": lines}, indent=2) + "\n")
print(json.dumps({"exit": result.returncode, "lines": lines}, indent=2))
