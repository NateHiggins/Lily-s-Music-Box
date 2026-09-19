"""Admit committed V2 work without altering the sealed optional provider inputs."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREVIOUS = HERE.parent / "f01_provider_execution_05"
OUT = ROOT / "design/astra/evidence/f01_provider_execution_06"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding="utf-8-sig"))

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode().strip()

def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

assert not OUT.exists(), "fresh evidence folder required"
assert not (HERE / "run.py").exists(), "never overwrite a prior continuation"
admission = read(PREVIOUS / "preflight.json")
old_head = admission["head"]
current_head = git("rev-parse", "HEAD")
assert git("status", "--porcelain", "--untracked-files=no", "--", "game") == ""
for rel, row in admission["protected"].items():
    assert sha(ROOT / rel) == row["sha256"], rel
    assert git("rev-parse", "HEAD:" + rel) == row["head"], rel
    assert git("rev-parse", ":" + rel) == row["index"], rel
for rel, digest in admission["additional_inputs"].items():
    assert sha(ROOT / rel) == digest, rel
for row in admission["install_paths"]:
    assert sha(Path(row["source"])) == row["expected_sha256"], row["source"]
    if row["target"] != "game/scripts/building/building_root.gd":
        assert sha(ROOT / row["target"]) == row["expected_sha256"], row["target"]

spec = importlib.util.spec_from_file_location("previous_provider_run", PREVIOUS / "run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
assert not runner.engines(runner.census()), "native lane must be empty"
before = dict(runner.core.all_game_rows())
previous_install = ROOT / "design/astra/evidence/f01_provider_execution_05/install.json"
previous_files = read(previous_install)["game_files"]
committed_changes = set(git("diff", "--name-only", old_head, current_head, "--", "game").splitlines())
changes = []
for rel in sorted(before.keys() | previous_files.keys()):
    if before.get(rel) == previous_files.get(rel):
        continue
    if rel in committed_changes:
        if rel in before:
            committed = subprocess.check_output(["git", "show", "HEAD:" + rel], cwd=ROOT)
            # Compare Git's canonical content to the index; the clean worktree
            # check above permits the configured Windows newline conversion.
            assert hashlib.sha256(committed).hexdigest() == hashlib.sha256(
                subprocess.check_output(["git", "show", ":" + rel], cwd=ROOT)).hexdigest()
        provenance = "committed V2 implementation"
    elif rel.endswith(".gd.uid") and rel[:-4] in committed_changes:
        assert re.fullmatch(r"uid://[a-z0-9]+\s*", (ROOT / rel).read_text()), rel
        provenance = "generated UID for a committed GDScript"
    else:
        raise AssertionError("Unreviewed source drift: " + rel)
    changes.append({"path": rel, "before": previous_files.get(rel), "after": before.get(rel), "provenance": provenance})

original = ROOT / "design/astra/evidence/f01_provider_execution_05/original_root.gd"
assert sha(ROOT / runner.OWNER) == sha(original)
admission["head"] = current_head
admission["status"] = "FRESH_BASELINE_SEALED_PROVIDER_INPUTS_UNCHANGED"
admission["previous_preflight_sha256"] = sha(PREVIOUS / "preflight.json")
dump(HERE / "preflight.json", admission)
(HERE / "inherited_art_warning.json").write_bytes((PREVIOUS / "inherited_art_warning.json").read_bytes())
source = (PREVIOUS / "run.py").read_text()
assert source.count("evidence/f01_provider_execution_05") == 1
(HERE / "run.py").write_text(source.replace("evidence/f01_provider_execution_05", "evidence/f01_provider_execution_06"), encoding="utf-8")
OUT.mkdir()
(OUT / "original_root.gd").write_bytes(original.read_bytes())
dump(OUT / "install.json", {"status": "OPTIONAL_INPUTS_INSTALLED_ORIGINAL_ROOT_RETAINED",
    "game_files": before, "engines": runner.core.engine_manifest(),
    "head": current_head, "previous_head": old_head,
    "previous_install_sha256": sha(previous_install), "admitted_source_changes": changes,
    "sealed_provider_inputs_unchanged": True, "engine_launched": False,
    "prior_overlap_not_accepted": True, "previous_runner_sha256": sha(PREVIOUS / "run.py")})
print(json.dumps({"status": "FRESH_BASELINE_PREPARED", "source_changes": len(changes), "engine_launched": False}))
