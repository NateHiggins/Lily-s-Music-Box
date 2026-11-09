#!/usr/bin/env python3
"""Import every roughness map at half its albedo's size (ruling tex_orm_resolution_20261109).

Lily ruled ORM maps at half the albedo's size. The library has no metallic maps
and one AO map, so an ORM map would carry nothing but roughness, and changing the
channel layout would change what every consumer reads (StandardMaterial3D reads
red, glTF reads green for roughness and blue for metal, several shaders read .r).
The size is the whole of the saving, so this tool takes it in the import:
it owns one key, `process/size_limit`, on roughness maps only. Source PNGs,
material tables and consumers stay as they are.

The limit is half the albedo's longer side, rounded down to a multiple of four:
BPTC/S3TC need whole 4x4 blocks, and Godot silently leaves a texture uncompressed
when they do not fit. Only square maps are capped, so the short side cannot land
off the block grid. fix_runtime_texture_imports.py owns the other import keys and
leaves size_limit alone.

    python art/tools/cap_roughness_imports.py --check
    python art/tools/cap_roughness_imports.py            # then re-import twice
"""
from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
ROUGH = re.compile(r"_rough(?:ness)?\.png$")
# The dream's plates are packed substance data under a tested residency ceiling,
# and two sidecars are pinned by fixtures (orison_work_tables, orison_bar_ceiling_finish).
EXCLUDE_PREFIXES = ("assets/dream/",)
PINNED_SIDECARS = (
    "assets/building/textures/T_ai_materials_oak_work_surface_rough.png",
    "assets/building/textures/T_ai_materials_smoked_plaster_rough.png",
)
LIMIT_KEY = "process/size_limit"


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        return 0, 0
    return struct.unpack(">II", header[16:24])


def albedo_for(rough: Path) -> Path:
    return rough.with_name(ROUGH.sub("_albedo.png", rough.name))


def wanted_limit(rough: Path) -> int | None:
    """The size limit this map should import with, or None to leave it alone."""
    rel = rough.relative_to(GAME).as_posix()
    if rel.startswith(EXCLUDE_PREFIXES) or rel in PINNED_SIDECARS:
        return None
    sidecar = rough.with_name(rough.name + ".import")
    if not sidecar.is_file() or not re.search(r"^compress/mode=2$", sidecar.read_text(encoding="utf8"), re.M):
        return None
    width, height = png_size(rough)
    albedo = albedo_for(rough)
    if width != height or width == 0 or not albedo.is_file():
        return None
    limit = max(png_size(albedo)) // 2 // 4 * 4
    return limit if 0 < limit < width else None


def current_limit(text: str) -> int:
    match = re.search(r"^%s=(\d+)$" % re.escape(LIMIT_KEY), text, re.M)
    return int(match.group(1)) if match else 0


def set_limit(text: str, limit: int) -> str:
    pattern = re.compile(r"^%s=.*$" % re.escape(LIMIT_KEY), re.M)
    if pattern.search(text):
        return pattern.sub("%s=%d" % (LIMIT_KEY, limit), text)
    return text.rstrip("\n") + "\n%s=%d\n" % (LIMIT_KEY, limit)


def plan(game: Path = GAME) -> list[tuple[Path, int]]:
    return [(path, limit) for path in sorted(game.rglob("*.png"))
            if ROUGH.search(path.name) and ".godot" not in path.parts
            and (limit := wanted_limit(path)) is not None]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    wrong = []
    for path, limit in plan():
        sidecar = path.with_name(path.name + ".import")
        text = sidecar.read_text(encoding="utf8")
        if current_limit(text) == limit:
            continue
        wrong.append(path.relative_to(GAME).as_posix())
        if not args.check:
            sidecar.write_text(set_limit(text, limit), encoding="utf8", newline="\n")
    if args.json:
        print(json.dumps({"wrong": wrong, "fixed": [] if args.check else wrong}))
    else:
        verb = "need the cap" if args.check else "capped"
        print("%d roughness maps %s" % (len(wrong), verb))
    return 1 if args.check and wrong else 0


if __name__ == "__main__":
    sys.exit(main())
