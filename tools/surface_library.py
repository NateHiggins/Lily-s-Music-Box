#!/usr/bin/env python3
"""Process generated stain/wear overlays and furniture/appliance surfaces."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageOps, ImageStat

import material_textures as mt

ROOT = Path(__file__).resolve().parents[1]
TEXTURE_ROOT = ROOT / "art" / "textures"
MANIFEST = TEXTURE_ROOT / "surface_library.json"


def manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def asset_paths(asset_id: str) -> tuple[Path, Path]:
    return (
        TEXTURE_ROOT / "source_library" / f"{asset_id}.png",
        TEXTURE_ROOT / "library" / asset_id,
    )


def prompt(asset_id: str) -> None:
    spec = manifest()["assets"].get(asset_id)
    if spec is None:
        raise SystemExit(f"Unknown asset: {asset_id}")
    intent = (
        "reusable stain or wear mask source"
        if spec["kind"] == "overlay"
        else "seamless PBR base-color texture source"
    )
    print(
        f"""Use case: stylized-concept
Asset type: {intent} for Orison Apartments
Primary request: {spec["prompt"]}
Composition/framing: perfectly orthographic flat square sample, uniform texel density, edge-to-edge material only, designed to tile seamlessly on all four edges
Lighting/mood: neutral diffuse capture; no directional light, shadows, highlights, vignette, ambient occlusion, or perspective
Constraints: seamless; no text or watermark
Avoid: {spec["avoid"]}"""
    )


def process(asset_id: str) -> None:
    data = manifest()
    spec = data["assets"].get(asset_id)
    if spec is None:
        raise SystemExit(f"Unknown asset: {asset_id}")
    source, output = asset_paths(asset_id)
    if not source.exists():
        raise SystemExit(f"Missing source: {source}")
    output.mkdir(parents=True, exist_ok=True)
    size = int(data["defaults"]["output_size"])
    plate = mt.seamless(mt.fit_square(Image.open(source), size))
    metadata = {
        "id": asset_id,
        "kind": spec["kind"],
        "source": source.relative_to(ROOT).as_posix(),
        "meters_per_tile": spec["meters_per_tile"],
    }
    if spec["kind"] == "overlay":
        # AI supplies placement/shape; runtime supplies color and blend mode.
        gray = ImageOps.grayscale(plate)
        median = int(ImageStat.Stat(gray).median[0])
        background = Image.new("L", gray.size, median)
        mask = ImageChops.difference(gray, background)
        mask = ImageOps.autocontrast(mask, cutoff=2)
        mask = ImageEnhance.Contrast(mask).enhance(1.4)
        mask.save(output / "mask.png", optimize=True)
        mt.tile_preview(mask.convert("RGB")).save(
            output / "preview_2x2.png", optimize=True
        )
        metadata["maps"] = {"mask": "mask.png"}
        check_image = mask
    else:
        height = mt.make_height(plate, int(spec["height_detail_radius"]))
        roughness = mt.make_roughness(
            height, float(spec["roughness"]), float(spec["roughness_variation"])
        )
        normal = mt.make_normal(
            height, float(data["defaults"].get("normal_strength", 1.5))
        )
        plate.save(output / "albedo.png", optimize=True)
        roughness.save(output / "roughness.png", optimize=True)
        height.save(output / "height.png", optimize=True)
        normal.save(output / "normal.png", optimize=True)
        mt.tile_preview(plate).save(output / "preview_2x2.png", optimize=True)
        metadata["maps"] = {
            "albedo": "albedo.png",
            "roughness": "roughness.png",
            "height": "height.png",
            "normal": "normal.png",
        }
        check_image = plate
    horizontal, vertical = mt.edge_error(check_image)
    metadata["edge_error_horizontal"] = round(horizontal, 5)
    metadata["edge_error_vertical"] = round(vertical, 5)
    (output / "asset.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{asset_id}: horizontal={horizontal:.4f}, vertical={vertical:.4f}")


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("prompt", "process"):
        command = sub.add_parser(name)
        command.add_argument("asset")
    args = parser.parse_args()
    prompt(args.asset) if args.command == "prompt" else process(args.asset)


if __name__ == "__main__":
    main()
