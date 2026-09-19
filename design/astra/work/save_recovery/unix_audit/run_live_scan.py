"""Compare the original and proposed scanner on a stable, read-only live tree.

This captures real native exits; it never updates a baseline or live source.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]
parser = argparse.ArgumentParser()
parser.add_argument("name")
args = parser.parse_args()
if not args.name.replace("_", "").isalnum():
    raise SystemExit("Use a fresh plain evidence name.")
out = HERE / "live_evidence" / args.name
out.mkdir(parents=True, exist_ok=False)


def sha(value):
    return hashlib.sha256(value).hexdigest()


def snapshot():
    paths = sorted((REPO / "game/scripts").rglob("*.gd"))
    paths += sorted((REPO / "game/data").rglob("*.json"))
    paths += [REPO / "tools/systemic_situation_authority_baseline.json"]
    return {path.relative_to(REPO).as_posix(): sha(path.read_bytes()) for path in paths}


before = snapshot()
(out / "inputs.before.json").write_text(json.dumps(before, indent=2) + "\n", encoding="utf-8")
receipt = {"scope": "read-only production source scan; no runtime or human proof",
           "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO).decode().strip(),
           "runs": []}
for label, tool in [("original", HERE / "originals/audit_systemic_situation_authority.py"),
                    ("candidate", HERE / "proposed/tools/audit_systemic_situation_authority.py")]:
    command = [sys.executable, str(tool), "--root", str(REPO), "--production-only", "--domain", "host-clock", "--json"]
    process = subprocess.run(command, cwd=REPO, capture_output=True)
    (out / (label + ".stdout.json")).write_bytes(process.stdout)
    (out / (label + ".stderr.txt")).write_bytes(process.stderr)
    (out / (label + ".source.py")).write_bytes(tool.read_bytes())
    receipt["runs"].append({"label": label, "command": command, "exit": process.returncode,
                            "tool_sha256": sha(tool.read_bytes()), "stdout_sha256": sha(process.stdout),
                            "stderr_sha256": sha(process.stderr)})
after = snapshot()
(out / "inputs.after.json").write_text(json.dumps(after, indent=2) + "\n", encoding="utf-8")
receipt["source_unchanged"] = before == after
receipt["input_count"] = len(before)
(out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps(receipt, indent=2))
raise SystemExit(0 if before == after else 1)
