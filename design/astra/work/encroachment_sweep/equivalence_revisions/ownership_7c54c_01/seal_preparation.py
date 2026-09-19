"""Record only the bounded offline preparation checks; never launch Godot."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


command = [sys.executable, "-m", "unittest", "discover", "-s", str(HERE), "-p", "test_*.py", "-v"]
run = subprocess.run(command, cwd=ROOT, capture_output=True)
(HERE / "controls.stdout.log").write_bytes(run.stdout)
(HERE / "controls.stderr.log").write_bytes(run.stderr)
artifacts = {}
for path in sorted(HERE.rglob("*")):
    if not path.is_file() or "__pycache__" in path.parts or path.name == "preparation_receipt.json":
        continue
    artifacts[path.relative_to(HERE).as_posix()] = digest(path)
dependencies = {}
for name in [
    "game/scripts/building/surface_pass.gd", "game/scripts/reality/living_field.gd",
    "game/scripts/dream/dream_organelle_lifecycle.gd", "game/scripts/props/functional_prop.gd",
    "game/shaders/orison_surface.gdshader", "game/shaders/orison_surface_cutout.gdshader",
    "game/shaders/orison_surface.gdshaderinc",
]:
    path = ROOT / name
    assert path.is_file(), name
    dependencies[name] = digest(path)
receipt = {
    "status": "PREPARATION_COMPLETE_ENGINE_UNRUN_LIVE_GAME_UNCHANGED",
    "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
    "source_binding": json.loads((HERE / "preparation.json").read_text()),
    "pure_python_controls": {"command": command, "exit": run.returncode, "tests": 19,
                             "stdout": "controls.stdout.log", "stderr": "controls.stderr.log"},
    "engine_checks": "NOT_RUN", "expected_complete_fixture_check_count": 171,
    "direct_dependency_hashes_at_preparation": dependencies,
    "dependency_limit": "Bounded direct seam sources only. Freeze and bind complete runtime inputs again at execution.",
    "static_review": [
        "Exact reach_props-only delta reviewed; no definite semantic blocker found.",
        "Independent draft review found detached row path diagnostic risk; ancestry guard now labels detached rows.",
        "Nullable has_living parameters use direct comparison, never bool(null).",
        "Actual lifecycle stage_name strings verified lowercase; STAIN/EXCHANGE assertions corrected before any run.",
    ],
    "open_boundaries": ["Godot parse/runtime clearance", "production build and actual case finish ownership",
                        "real-root callbacks and governor/lifecycle composition", "rendered content and sampled transition cost"],
    "artifacts": artifacts,
}
(HERE / "preparation_receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"status": receipt["status"], "control_exit": run.returncode,
                  "artifact_count": len(artifacts), "receipt": str(HERE / "preparation_receipt.json")}, indent=2))
raise SystemExit(run.returncode)
