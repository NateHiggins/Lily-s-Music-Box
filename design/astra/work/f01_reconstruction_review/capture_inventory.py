"""Read-only F01 source/protection inventory. Writes only this review's JSON.

Does not import a generator, export assets, create a worktree or launch Godot.
Historical Git objects and current worktree bytes are deliberately separate.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
BASE = Path(__file__).resolve().parent
C1 = "c34ad283df148496fbd98e68638470835c930c5c"
M11B = "a9e455bfede9f89193c9acd0796eb8fc5a0c3548"
C2 = "46d40e9a916ffa7c7cc2ae5031fa6bcbcdeb7777"


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def row(path: str, reference: str) -> dict:
    data = git("show", f"{reference}:{path}")
    live = ROOT / path
    return {
        "path": path,
        "reference": reference,
        "git_blob": git("rev-parse", f"{reference}:{path}").decode().strip(),
        "reference_sha256": sha(data),
        "bytes": len(data),
        "current_exists": live.is_file(),
        "current_sha256": sha(live.read_bytes()) if live.is_file() else None,
        "current_exact_reference_bytes": live.read_bytes() == data if live.is_file() else False,
        "current_matches_reference_after_crlf_to_lf": live.read_bytes().replace(b"\r\n", b"\n") == data.replace(b"\r\n", b"\n") if live.is_file() else False,
    }


def main() -> None:
    protected = [
        "art/data/building_layout.json", "game/data/building_layout.json",
        "game/scripts/building/building_root_selector.gd",
        *[f"game/assets/building/floor_{floor}.{suffix}"
          for floor in ("01", "02", "03", "04", "05", "06", "b1")
          for suffix in ("gltf", "bin")],
    ]
    c1_tree = git("ls-tree", "-r", "--name-only", C1).decode().splitlines()
    minimum = [
        "art/data/m11c1/floor01_source_ownership.json",
        "tools/rehearse_orison_floor01_partition.py",
        *[p for p in c1_tree if p.startswith("tools/m11c1_floor01_owner_first/") and p.endswith(".py")],
    ]
    rehearsal = [
        "design/ORISON_V2_M11C0_FLOOR01_PARTITION_MANIFEST_2026-08-31.json",
        *[p for p in c1_tree if p.startswith(("tools/m11c1_floor01_rehearsal/", "game/tests/orison_v2_m11c1_owner_first/"))],
        *[p for p in c1_tree if p.startswith("tools/tests/test_m11c1_")],
    ]
    current_inputs = [
        "art/data/gen_layout.py", "art/blender/scripts/build_orison.py",
        "game/data/orison_v2/exterior/regions.json",
    ]
    protected_rows = []
    for p in protected:
        r = row(p, C1)
        r["current_head_blob"] = git("rev-parse", f"HEAD:{p}").decode().strip()
        r["current_git_clean_blob"] = git("hash-object", "--path=" + p, p).decode().strip()
        r["accepted_m11b_blob"] = git("rev-parse", f"{M11B}:{p}").decode().strip()
        r["unchanged_since_accepted_m11b"] = r["git_blob"] == r["current_head_blob"] == r["accepted_m11b_blob"] == r["current_git_clean_blob"]
        protected_rows.append(r)
    c2_tree = git("ls-tree", "-r", "--name-only", C2).decode().splitlines()
    c2_deployment = [p for p in c2_tree if p.startswith("game/assets/building/floor_01_cells/") and not p.endswith(".import")]
    c2_deployment += ["game/data/floor_01_cell_registry.json", "tools/m11c2_floor01_production/export_floor01_cells.py", "tools/tests/test_m11c2_floor01_production_export.py"]
    gltf = json.loads((ROOT / "game/assets/building/floor_01.gltf").read_bytes())
    texture_rows = []
    for image in gltf.get("images", []):
        uri = image.get("uri", "")
        if not uri or uri.startswith("data:"):
            raise ValueError(f"Unexpected source image form: {image}")
        p = (ROOT / "game/assets/building" / uri).resolve()
        if not p.is_relative_to(ROOT):
            raise ValueError(f"Image escaped repository: {uri}")
        texture_rows.append({"uri": uri, "path": p.relative_to(ROOT).as_posix(), "sha256": sha(p.read_bytes()), "bytes": p.stat().st_size})
    status = git("status", "--porcelain=v1", "--untracked-files=no").decode().splitlines()
    foundation = []
    for line in status:
        p = line[3:]
        if p.startswith(("game/", "tools/")) and (ROOT / p).is_file():
            foundation.append({"status": line[:2], "path": p, "sha256": sha((ROOT / p).read_bytes())})
    engines = [Path(r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")]
    engines += list(Path.home().joinpath("AppData/Local/Microsoft/WinGet/Packages").glob("GodotEngine.GodotEngine_*/Godot_v4.7.1-stable_win64*.exe"))
    result = {
        "schema": "astra.f01-reconstruction-read-only-inventory.v1",
        "canonical_head": git("rev-parse", "HEAD").decode().strip(),
        "clean_c1_source_reference": C1,
        "accepted_m11b_reference": M11B,
        "historical_c2_reference_for_comparison_only": C2,
        "generator_or_engine_executed": False,
        "production_mutated": False,
        "protected_17": protected_rows,
        "all_17_git_clean_equal_c1_and_accepted_m11b": all(r["unchanged_since_accepted_m11b"] for r in protected_rows),
        "all_17_match_reference_with_only_crlf_normalization": all(r["current_matches_reference_after_crlf_to_lf"] for r in protected_rows),
        "current_authored_inputs_compared_with_c1": [row(p, C1) for p in current_inputs],
        "clean_c1_export_dependency_closure": [row(p, C1) for p in sorted(minimum)],
        "clean_c1_rehearsal_and_test_dependency_closure": [row(p, C1) for p in sorted(set(rehearsal))],
        "c2_deployment_reference_only": [row(p, C2) for p in sorted(c2_deployment)],
        "protected_floor01_image_dependencies": texture_rows,
        "uncommitted_foundation_source_snapshot": foundation,
        "installed_binary_files_without_launch": [{"path": str(p), "exists": p.is_file(), "bytes": p.stat().st_size if p.is_file() else None, "sha256": sha(p.read_bytes()) if p.is_file() else None} for p in engines],
        "notes": [
            "Hashes bind this inventory instant; the parent owns continuing foundation edits. Rebind before implementation.",
            "C1 source is attributable but its isolated runtime/human-pending receipt is not production acceptance.",
            "C2 generated artifacts and registry are comparison targets, never adopted output in this review.",
            "Only the historical 17-path protection boundary is called protected_17; the roof, textures, generator and other current files are not implicitly writable.",
            "Git blobs use LF while materialized text assets use CRLF. Raw reference and current hashes are recorded separately; no file is normalized or written. Sidecar layout raw hash 68838c... matches the materialized layout, not the Git LF blob.",
        ],
    }
    (BASE / "source_inventory.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"protected": len(protected_rows), "all_protected_git_clean_equal": result["all_17_git_clean_equal_c1_and_accepted_m11b"], "all_protected_only_crlf_difference": result["all_17_match_reference_with_only_crlf_normalization"], "export_dependencies": len(minimum), "rehearsal_dependencies": len(set(rehearsal)), "image_dependencies": len(texture_rows), "output": str(BASE / "source_inventory.json")}, indent=2))


if __name__ == "__main__":
    main()
