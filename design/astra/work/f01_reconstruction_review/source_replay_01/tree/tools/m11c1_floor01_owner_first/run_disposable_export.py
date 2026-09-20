#!/usr/bin/env python3
"""Generate, partition, and receipt a disposable M11C1 owner-first export."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.m11c1_floor01_owner_first.owner_first_export import (  # noqa: E402
    OwnerFirstError,
    _sha256_file,
    run_owner_first_export,
    write_json,
)


DEFAULT_PROTECTED = REPO_ROOT / "game/assets/building/floor_01.gltf"
DEFAULT_LAYOUT = REPO_ROOT / "art/data/building_layout.json"
DEFAULT_LAYOUT_MIRROR = REPO_ROOT / "game/data/building_layout.json"
DEFAULT_OWNERSHIP = REPO_ROOT / "art/data/m11c1/floor01_source_ownership.json"
DEFAULT_GENERATOR = REPO_ROOT / "art/blender/scripts/build_orison.py"
DEFAULT_ADAPTER = Path(__file__).with_name("generate_owner_first_candidate.py")
DEFAULT_REGIONS = REPO_ROOT / "game/data/orison_v2/exterior/regions.json"


def _protected_paths(protected_gltf: Path) -> dict[str, Path]:
    document = json.loads(protected_gltf.read_text(encoding="utf-8"))
    buffers = document.get("buffers", [])
    if len(buffers) != 1 or not buffers[0].get("uri"):
        raise OwnerFirstError("protected glTF must name exactly one external BIN")
    protected_bin = (protected_gltf.parent / str(buffers[0]["uri"])).resolve()
    paths = {
        "floor_01_gltf": protected_gltf.resolve(),
        "floor_01_bin": protected_bin,
        "authoritative_layout": DEFAULT_LAYOUT.resolve(),
        "runtime_layout_mirror": DEFAULT_LAYOUT_MIRROR.resolve(),
    }
    for index in range(10):
        for kind in ("albedo", "roughness", "normal"):
            label = f"legacy_wallfinish_f01_w{index:02d}_{kind}"
            paths[label] = (
                REPO_ROOT / "game/assets/building/textures" /
                f"T_wallfinish_f01_w{index:02d}_{kind}.png"
            ).resolve()
    return paths


def _hash_paths(paths: dict[str, Path]) -> dict[str, str]:
    missing = [str(path) for path in paths.values() if not path.is_file()]
    if missing:
        raise OwnerFirstError(f"protected input is missing: {missing}")
    return {label: _sha256_file(path) for label, path in paths.items()}


def run_disposable_export(
        *, output_root: Path, blender: Path, protected_gltf: Path,
        layout: Path, ownership: Path, generator: Path, adapter: Path,
        exterior_regions: Path) -> dict[str, Any]:
    output_root = output_root.resolve()
    if output_root == REPO_ROOT or output_root.is_relative_to(REPO_ROOT) \
            or REPO_ROOT.is_relative_to(output_root):
        raise OwnerFirstError("output must be an external disposable root")
    if output_root.exists() and any(output_root.iterdir()):
        raise OwnerFirstError(f"output is not empty: {output_root}")
    protected_paths = _protected_paths(protected_gltf.resolve())
    protected_before = _hash_paths(protected_paths)
    command = [
        str(blender.resolve()),
        "--background",
        "--factory-startup",
        "--python", str(adapter.resolve()),
        "--",
        "--generator", str(generator.resolve()),
        "--layout", str(layout.resolve()),
        "--ownership-sidecar", str(ownership.resolve()),
        "--output", str(output_root),
    ]
    process = subprocess.run(
        command, cwd=str(REPO_ROOT), capture_output=True, text=True,
        encoding="utf-8", errors="replace", check=False,
    )
    marker = "M11C1_OWNER_FIRST_GENERATION="
    summaries = [
        line[len(marker):] for line in process.stdout.splitlines()
        if line.startswith(marker)
    ]
    if process.returncode != 0 or len(summaries) != 1:
        raise OwnerFirstError(
            "Blender owner-first generation failed: "
            f"exit={process.returncode} marker_count={len(summaries)} "
            f"stderr_tail={process.stderr[-2000:]!r} "
            f"stdout_tail={process.stdout[-2000:]!r}")
    generation_summary = json.loads(summaries[0])
    candidate_gltf = Path(str(generation_summary["candidate_gltf"])).resolve()
    generated_lineage = Path(
        str(generation_summary["generated_lineage"])).resolve()
    if (not candidate_gltf.is_relative_to(output_root)
            or not generated_lineage.is_relative_to(output_root)):
        raise OwnerFirstError("Blender reported candidate paths outside output root")
    process_receipt = {
        "schema": "orison.floor01.owner-first-blender-process.v1",
        "status": "PASS",
        "command": command,
        "exit_code": process.returncode,
        "stdout_sha256": __import__("hashlib").sha256(
            process.stdout.encode("utf-8")).hexdigest(),
        "stderr_sha256": __import__("hashlib").sha256(
            process.stderr.encode("utf-8")).hexdigest(),
        "stderr_empty": not bool(process.stderr.strip()),
        "generation": generation_summary,
    }
    write_json(
        output_root / "candidate/blender_generation_process.json",
        process_receipt,
    )
    # Close the read-only production boundary before core receipt generation.
    # Core will bind this receipt and the process receipt to its run ID, then
    # emit the transaction as the final JSON file in the disposable root.
    protected_after = _hash_paths(protected_paths)
    if protected_after != protected_before:
        raise OwnerFirstError("protected floor/layout assets changed during generation")
    protection = {
        "schema": "orison.floor01.owner-first-protection.v1",
        "status": "PASS",
        "paths": {label: str(path) for label, path in protected_paths.items()},
        "hashes_before": protected_before,
        "hashes_after": protected_after,
        "unchanged": True,
    }
    write_json(output_root / "receipts/protected_assets.json", protection)
    summary = run_owner_first_export(
        protected_gltf.resolve(),
        candidate_gltf,
        generated_lineage,
        layout.resolve(),
        ownership.resolve(),
        generator.resolve(),
        adapter.resolve(),
        exterior_regions.resolve(),
        output_root,
        prepare_output=False,
        require_orchestrator_receipts=True,
    )
    protected_final = _hash_paths(protected_paths)
    if protected_final != protected_before:
        raise OwnerFirstError("protected floor/layout assets changed during export")
    summary["protected_assets"] = protected_before
    summary["blender_exit"] = process.returncode
    return summary


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--blender", type=Path,
        default=Path(r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"))
    parser.add_argument("--protected-gltf", type=Path, default=DEFAULT_PROTECTED)
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--ownership", type=Path, default=DEFAULT_OWNERSHIP)
    parser.add_argument("--generator", type=Path, default=DEFAULT_GENERATOR)
    parser.add_argument("--adapter", type=Path, default=DEFAULT_ADAPTER)
    parser.add_argument("--exterior-regions", type=Path, default=DEFAULT_REGIONS)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        result = run_disposable_export(
            output_root=args.output,
            blender=args.blender,
            protected_gltf=args.protected_gltf,
            layout=args.layout,
            ownership=args.ownership,
            generator=args.generator,
            adapter=args.adapter,
            exterior_regions=args.exterior_regions,
        )
    except Exception as error:
        print(f"M11C1 DISPOSABLE EXPORT FAIL: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
