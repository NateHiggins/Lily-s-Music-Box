"""One approved owner install; invoke the unchanged 63-check producer runner."""
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[6]
REUSED = ROOT / "design/astra/work/apartment_floor_ownership_01/runtime_01"
sys.path.insert(0, str(REUSED))
import run as producer_run
import core

OWNER = producer_run.OWNER
OLD = "2a440504ab80404f4d9f4ab16138df7db9255801ca879ff91aabafe3c7f4d0ca"
NEW = "1a1b067ff5b95c03fea739747c97deaaf9621e03a635b318b3379cef07bd3776"
HEAD = "da68962aaeaabf56851abb7190dda14d7ff5675f"
OUT = ROOT / "design/astra/evidence/encroachment_sweep/one_census_wardrobe_01"
CANDIDATE = HERE.parent / "proposed" / OWNER


def main():
    package = json.loads((HERE / "package.json").read_text(encoding="utf-8"))
    for relative, fingerprint in package["reused_instruments"].items():
        if core.sha(ROOT / relative) != fingerprint:
            raise ValueError("reused instrument changed: " + relative)
    if core.sha(HERE / "execute.py") != package["launcher_sha256"]:
        raise ValueError("integration launcher changed")
    if core.sha(CANDIDATE) != NEW or core.sha(ROOT / OWNER) != OLD:
        raise ValueError("exact approved old/candidate bytes required")
    for relative, fingerprint in {**package["install"], **package["production_bindings"]}.items():
        if core.sha(ROOT / relative) != fingerprint:
            raise ValueError("selected current source changed: " + relative)
    census = core.godot_processes()
    if census:
        raise ValueError("Godot lane is occupied")
    if core.git("rev-parse", "HEAD").decode().strip() != HEAD:
        raise ValueError("HEAD differs from frozen integration parent")
    OUT.mkdir(parents=True, exist_ok=False)
    core.dump(OUT / "preinstall_processes.json", census)
    shutil.copy2(ROOT / OWNER, OUT / "owner_before.gd")
    shutil.copy2(CANDIDATE, OUT / "owner_candidate.gd")
    rows = core.all_game_rows()
    core.dump(OUT / "preinstall.all_game_files.json", rows)
    state = {"head": HEAD, "files": dict(rows)}
    core.dump(OUT / "install.json", {"schema": "astra.one-census.exact-owner-install.v1",
        "head": HEAD, "old_sha256": OLD, "candidate_sha256": NEW,
        "only_mutated_game_path": OWNER, "fixtures_already_installed_unchanged": package["install"],
        "runtime_package_sha256": core.sha(HERE / "package.json"),
        "before_game_manifest_digest": core.digest(rows)})
    core.HERE = HERE
    core.BRIDGE = REUSED / "runner_bridge.ps1"
    core.instrument_paths = lambda: {
        **{Path(name).name: ROOT / name for name in package["reused_instruments"]},
        "integration_execute.py": HERE / "execute.py", "integration_package.json": HERE / "package.json"}
    outcome = None
    shutil.copy2(CANDIDATE, ROOT / OWNER)
    try:
        outcome = producer_run.run_installed("one_census_wardrobe_regression", "green",
            "proposed", OUT, "01_candidate", state, package)
        return outcome
    finally:
        if core.sha(ROOT / OWNER) != NEW:
            raise ValueError("unexpected owner edit; refusing automatic overwrite")
        if outcome != 0:
            shutil.copy2(OUT / "owner_before.gd", ROOT / OWNER)
        remaining = core.godot_processes()
        core.dump(OUT / "final_state.json", {"status": "CANDIDATE_RETAINED" if outcome == 0 else "OLD_OWNER_RESTORED",
            "owner_sha256": core.sha(ROOT / OWNER), "expected_candidate_sha256": NEW,
            "godot_processes": remaining, "head_observed": core.git("rev-parse", "HEAD").decode().strip(),
            "control_acceptance_exit": outcome, "at_utc": core.utc()})
        if remaining:
            raise ValueError("Godot processes remain; lane not released")


if __name__ == "__main__":
    raise SystemExit(main())
