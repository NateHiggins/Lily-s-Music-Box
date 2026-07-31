#!/usr/bin/env python3
"""Turn generated material plates into validated, game-ready texture sets.

AI generation is intentionally outside this deterministic script. Codex (or a
human) generates one flat source plate from the manifest prompt and saves it as
art/textures/source/<material>.png. This tool normalizes it and derives modest
height, roughness, and tangent-space normal maps without inventing geometry.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import (
    Image,
    ImageChops,
    ImageDraw,
    ImageEnhance,
    ImageFilter,
    ImageOps,
    ImageStat,
)

ROOT = Path(__file__).resolve().parents[1]
TEXTURE_ROOT = ROOT / "art" / "textures"
MANIFEST = TEXTURE_ROOT / "materials.json"


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def paths(material: str) -> tuple[Path, Path]:
    return (
        TEXTURE_ROOT / "source" / f"{material}.png",
        TEXTURE_ROOT / "generated" / material,
    )


def fit_square(image: Image.Image, size: int) -> Image.Image:
    image = ImageOps.exif_transpose(image).convert("RGB")
    edge = min(image.size)
    left = (image.width - edge) // 2
    top = (image.height - edge) // 2
    image = image.crop((left, top, left + edge, top + edge))
    return image.resize((size, size), Image.Resampling.LANCZOS)


def seamless(image: Image.Image, feather_fraction: float = 0.12) -> Image.Image:
    """Move original borders to the center, then softly heal the center seams."""
    w, h = image.size
    shifted = ImageChops.offset(image, w // 2, h // 2)
    blur = shifted.filter(ImageFilter.GaussianBlur(max(2, int(w * 0.018))))
    band = max(8, int(w * feather_fraction))
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    for d in range(band):
        alpha = int(255 * (1.0 - d / band) ** 2)
        draw.rectangle((w // 2 - d, 0, w // 2 + d, h), fill=alpha)
        draw.rectangle((0, h // 2 - d, w, h // 2 + d), fill=alpha)
    return Image.composite(blur, shifted, mask)


def make_height(albedo: Image.Image, detail_radius: int) -> Image.Image:
    gray = ImageOps.grayscale(albedo)
    broad = gray.filter(ImageFilter.GaussianBlur(detail_radius))
    detail = ImageChops.subtract(gray, broad, scale=1.0, offset=128)
    detail = ImageEnhance.Contrast(detail).enhance(1.35)
    return detail.filter(ImageFilter.GaussianBlur(0.7))


def make_roughness(height: Image.Image, base: float, variation: float) -> Image.Image:
    # Center the derived variation around the catalog's authored roughness.
    lut = [
        max(0, min(255, round((base + ((v - 128) / 127) * variation) * 255)))
        for v in range(256)
    ]
    return height.point(lut)


def make_normal(height: Image.Image, strength: float) -> Image.Image:
    px = height.load()
    w, h = height.size
    out = Image.new("RGB", (w, h))
    dst = out.load()
    for y in range(h):
        ym, yp = (y - 1) % h, (y + 1) % h
        for x in range(w):
            xm, xp = (x - 1) % w, (x + 1) % w
            dx = (px[xp, y] - px[xm, y]) / 255.0 * strength
            dy = (px[x, yp] - px[x, ym]) / 255.0 * strength
            length = math.sqrt(dx * dx + dy * dy + 1.0)
            nx, ny, nz = -dx / length, -dy / length, 1.0 / length
            dst[x, y] = (
                round((nx * 0.5 + 0.5) * 255),
                round((ny * 0.5 + 0.5) * 255),
                round((nz * 0.5 + 0.5) * 255),
            )
    return out


def edge_error(image: Image.Image) -> tuple[float, float]:
    rgb = image.convert("RGB")
    left = rgb.crop((0, 0, 1, rgb.height))
    right = rgb.crop((rgb.width - 1, 0, rgb.width, rgb.height))
    top = rgb.crop((0, 0, rgb.width, 1))
    bottom = rgb.crop((0, rgb.height - 1, rgb.width, rgb.height))

    def mean_diff(a: Image.Image, b: Image.Image) -> float:
        channels = ImageStat.Stat(ImageChops.difference(a, b)).mean
        return sum(channels) / (len(channels) * 255)

    return mean_diff(left, right), mean_diff(top, bottom)


def tile_preview(image: Image.Image) -> Image.Image:
    w, h = image.size
    preview = Image.new("RGB", (w * 2, h * 2))
    for y in range(2):
        for x in range(2):
            preview.paste(image, (x * w, y * h))
    return preview.resize((1024, 1024), Image.Resampling.LANCZOS)


def process(material: str) -> None:
    manifest = load_manifest()
    spec = manifest["materials"].get(material)
    if spec is None:
        raise SystemExit(f"Unknown material: {material}")
    source, output = paths(material)
    if not source.exists():
        raise SystemExit(f"Missing source plate: {source}")
    output.mkdir(parents=True, exist_ok=True)
    size = int(spec.get("size", manifest["defaults"].get("output_size", 1024)))
    albedo = seamless(fit_square(Image.open(source), size))
    height = make_height(albedo, int(spec.get("height_detail_radius", 16)))
    roughness = make_roughness(
        height,
        float(spec["roughness"]),
        float(spec.get("roughness_variation", 0.08)),
    )
    normal = make_normal(
        height, float(manifest["defaults"].get("normal_strength", 2.0))
    )
    albedo.save(output / "albedo.png", optimize=True)
    roughness.save(output / "roughness.png", optimize=True)
    height.save(output / "height.png", optimize=True)
    normal.save(output / "normal.png", optimize=True)
    tile_preview(albedo).save(output / "preview_2x2.png", optimize=True)
    horizontal, vertical = edge_error(albedo)
    metadata = {
        "material": material,
        "source": source.relative_to(ROOT).as_posix(),
        "meters_per_tile": spec["meters_per_tile"],
        "edge_error_horizontal": round(horizontal, 5),
        "edge_error_vertical": round(vertical, 5),
        "maps": {
            "albedo": "albedo.png",
            "roughness": "roughness.png",
            "height": "height.png",
            "normal": "normal.png",
        },
    }
    (output / "material.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{material}: wrote {output.relative_to(ROOT)}")
    print(f"edge error: horizontal={horizontal:.4f}, vertical={vertical:.4f}")


def show_prompt(material: str) -> None:
    spec = load_manifest()["materials"].get(material)
    if spec is None:
        raise SystemExit(f"Unknown material: {material}")
    print(
        f"""Use case: stylized-concept
Asset type: seamless PBR base-color texture source for Orison Apartments
Primary request: {spec["prompt"]}
Composition/framing: perfectly orthographic flat square surface sample, uniform texel density, edge-to-edge material only, designed to tile seamlessly on all four edges
Lighting/mood: neutral diffuse capture; absolutely no directional lighting, shadows, highlights, vignette, ambient occlusion, or perspective
Constraints: base-color/albedo information only; seamless tile
Avoid: {spec["avoid"]}"""
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    prompt = sub.add_parser("prompt", help="Print the generation prompt")
    prompt.add_argument("material")
    build = sub.add_parser("process", help="Build maps from a source plate")
    build.add_argument("material")
    args = parser.parse_args()
    if args.command == "prompt":
        show_prompt(args.material)
    else:
        process(args.material)


if __name__ == "__main__":
    main()
