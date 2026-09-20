"""Named terminal-only staging; preserve historical failures and additive recovery."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
OUT = ROOT / "design/astra/work/v2_terminal_checkpoint_01"
HEAD = "af9c5b6fdc42079d4bd64549b709a49ababa9e50"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding="utf-8"))
git = lambda *args: subprocess.check_output(["git", *args], cwd=ROOT, stderr=subprocess.PIPE)
write = lambda p, value: p.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
sources = {
    "game/scripts/building/orison_v2_runtime_root.gd": "03d68b7a8f55572c722bb97d0de8b6d1b6644b2072e4d10bfce2a7605c8fe955",
    "game/scripts/call/desk_zone.gd": "2208e7549bf7ec3a7acb8ba73d689575a2f7193c5888e5de92800b044e114a4a",
    "game/tests/orison_v2_terminal_access_test.gd": "800d7bf531758e2720d70d3167378c5bb77a90b0cb054ddad0347010feec47e3",
    "game/tests/OrisonV2TerminalAccessTest.tscn": "58efa825834b160032e80ed9bdd5b754e942ffdd09aec995acc4e11919f5fd60",
}
assert git("rev-parse", "HEAD").decode().strip() == HEAD
assert not git("diff", "--cached", "--name-only")
assert {rel: sha(ROOT / rel) for rel in sources} == sources
assert set(git("diff", "HEAD", "--name-only", "--", "game", "tools", "art").decode().splitlines()) == set(list(sources)[:2])
assert set(git("ls-files", "--others", "--exclude-standard", "--", "game", "tools", "art").decode().splitlines()) == set(list(sources)[2:])
assert sha(ROOT / "game/tests/vulkan_composed_root_test.gd") == "5ec63c36c6181b33c02bd2255039e9bf4e8db0c4465a45ac641d1481f422d6d3"
protected = read(ROOT / "design/astra/evidence/f01_source_replay/installed_01/protected.after.json")
assert len(protected) == 17
for rel, row in protected.items():
    assert sha(ROOT / rel) == row["raw_sha256"]
    assert git("rev-parse", "HEAD:" + rel).decode().strip() == row["working_clean_blob"]
roots = [
    "design/astra/work/v2_terminal_access_01", "design/astra/work/v2_terminal_access_arrival_02",
    "design/astra/work/vulkan_composed/revisions/terminal_operator_view_01",
    "design/astra/evidence/v2_terminal_access", "design/astra/evidence/v2_terminal_access_arrival_02",
    "design/astra/evidence/v2_terminal_access_invocations",
    "design/astra/evidence/vulkan_composed/invocations/terminal_operator_view_v2_01",
    "design/astra/evidence/vulkan_composed/invocations/terminal_operator_view_v2_02",
    "design/astra/evidence/vulkan_composed/invocations/terminal_candidate_view_v2_01",
    "design/astra/evidence/vulkan_composed/runs/terminal_operator_view_v2_01",
    "design/astra/evidence/vulkan_composed/runs/terminal_candidate_view_v2_01",
    "design/astra/work/f01_source_checkpoint_review_01",
]
names = list(sources) + [
    "design/astra/DECISION_LOG.md", "design/astra/LIVE_STATE.json", "design/astra/MASTER_COMPLETION_LEDGER.json",
    "design/astra/MASTER_COMPLETION_LEDGER.md", "design/astra/reviews/production_obligations.json",
    "design/astra/reviews/v2_terminal_operator_view_review.json", "design/astra/reviews/v2_terminal_operator_view_review.md",
    "design/astra/reviews/v2_terminal_access_startup_review_01.json", "design/astra/reviews/v2_terminal_access_arrival_02_review.json",
    "design/astra/reviews/v2_terminal_candidate_view_01.json", "design/astra/reviews/v2_terminal_checkpoint_review_01.json",
    "design/astra/reviews/v2_terminal_checkpoint_review_01.md",
    "design/astra/work/capture_v2_terminal_candidate_01.py", "design/astra/work/review_v2_terminal_access_arrival_02.py",
    "design/astra/work/continue_v2_terminal_arrival_02.py", "design/astra/work/review_v2_terminal_candidate_view_01.py",
    "design/astra/work/record_v2_terminal_repair_01.py", "design/astra/work/v2_terminal_checkpoint_01.py",
    "design/astra/work/f01_source_checkpoint_01/commit.stderr.log", "design/astra/work/f01_source_checkpoint_01/commit.stdout.log",
    "design/astra/work/f01_source_checkpoint_01/commit_verification.json", "design/astra/work/f01_source_checkpoint_01/stage.stderr.log",
    "design/astra/work/f01_source_checkpoint_01/stage.stdout.log", "design/astra/work/f01_source_checkpoint_01/staging.json",
]
for family in roots:
    assert (ROOT / family).is_dir()
    names.extend(p.relative_to(ROOT).as_posix() for p in (ROOT / family).rglob("*") if p.is_file() and "APPDATA" not in p.relative_to(ROOT).parts and "__pycache__" not in p.parts and p.suffix != ".pyc")
names = sorted(set(names))
assert all((ROOT / rel).is_file() for rel in names)
assert set(rel for rel in names if rel.startswith(("game/", "tools/", "art/"))) == set(sources)
OUT.mkdir(exist_ok=False)
write(OUT / "selection.json", {"base_head": HEAD, "selected": {rel: sha(ROOT / rel) for rel in names},
    "live_sources": sources, "protected_17": protected,
    "scope": "Two production terminal owners and two focused test files. Historical failed setup, selective negatives, busy-lane refusals/recovery, final input and actual operator capture retained. No provider, reservation cleanup, selector or release adoption."})
names.extend(["design/astra/work/v2_terminal_checkpoint_01/selection.json", "design/astra/work/v2_terminal_checkpoint_01/paths.nul"])
names.sort()
(OUT / "paths.nul").write_bytes(b"".join(rel.encode() + b"\0" for rel in names))
result = subprocess.run(["git", "add", "--pathspec-from-file=" + str(OUT / "paths.nul"), "--pathspec-file-nul"], cwd=ROOT, capture_output=True)
(OUT / "stage.stdout.log").write_bytes(result.stdout)
(OUT / "stage.stderr.log").write_bytes(result.stderr)
assert result.returncode == 0
assert set(git("diff", "--cached", "--name-only", "-z").decode().split("\0")) - {""} == set(names)
rows = []
for rel in names:
    blob = git("rev-parse", ":" + rel).decode().strip()
    assert blob == git("hash-object", "--path=" + rel, rel).decode().strip()
    if rel.startswith(("design/astra/evidence/", "design/astra/work/")):
        assert git("show", ":" + rel) == (ROOT / rel).read_bytes()
    rows.append({"path": rel, "raw_sha256": sha(ROOT / rel), "staged_blob": blob})
write(OUT / "staging.json", {"base_head": HEAD, "paths": rows, "path_count": len(rows), "game_paths": 4, "production_paths": 2, "protected_unchanged": True})
print(json.dumps({"status": "EXACT_NAMED_TERMINAL_STAGE", "paths": len(rows), "selection_sha256": sha(OUT / "selection.json")}))
