from pathlib import Path
from collections import Counter
import hashlib
import json

out = Path(__file__).resolve().parent
root = out.parents[3]
source = root / "game/tests/orison_v2_m08f_runtime_shot.gd"
before = source.read_bytes().replace(b"var path: String =", b"var path :=")
assert hashlib.sha256(before).hexdigest() == "91cb0949c6e902fadcbc7065b9f6b3a01a7d7280b8e629959fe40cb9ba9869f4"
(out / "parse_failure_source.gd").write_bytes(before)
green = out / "typed_path_green"
frames = green / "frames"
manifest = json.loads((frames / "composition_capture_receipt.json").read_text())
assert manifest["capture_result"] == "PASS" and len(manifest["records"]) == 12
assert not (frames / "runtime_authority_receipt.json").exists()
diagnostics = Counter(line for line in (green / "capture.stdout.log.stderr").read_text().splitlines()
                      if line.startswith(("WARNING:", "ERROR:", "SCRIPT ERROR:")))
receipt = {
    "kind": "windowed_composition_capture_validation",
    "source_path": source.relative_to(root).as_posix(),
    "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    "parse_failure": {"exit": 1, "source_sha256": hashlib.sha256(before).hexdigest(),
        "reason": "Untyped dynamic shots.output_dir cannot infer path with :=. Godot loaded no running capture script. Root terminated only the identified owned GUI process; its console wrapper returned exit 1. Logs retained.",
        "fix": "Explicit String annotation for the output path."},
    "corrected_run": {"exit": 0, "captures": 12, "diagnostics": dict(diagnostics),
        "mode": "windowed Forward+ on RTX 4080, Godot 4.7.1", "clean_runtime_claim": False},
    "files": {p.relative_to(out).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in [out / "capture.stdout.log", out / "capture.stdout.log.stderr",
                        green / "capture.stdout.log", green / "capture.stdout.log.stderr", *sorted(frames.iterdir())] if p.is_file()},
    "visual_inspection": {"frames": ["01_2b_radiator_real_prompt.png", "05_night_register.png", "08_b1_inspection.png"],
        "findings": "Rooms are underexposed and plainly blocked out; small apparatus details are hard to read; carried device obscures part of every inspection. No new human acceptance.",
        "scope": "Teleported inspection camera with direct test calls. No traversal, save, denial, controller-completion or retention measurement."},
}
(out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
