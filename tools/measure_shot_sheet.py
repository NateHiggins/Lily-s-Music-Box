#!/usr/bin/env python3
"""Measure and tile an Orison capture without invoking Godot.

Manifest schema:
{
  "pairs": [
    {"name":"floor", "a":"00_control_a.png", "b":"00_control_b.png",
     "kind":"control", "crop":[x,y,w,h]},
    {"name":"answer", "a":"00_control_a.png", "b":"02_yes.png",
     "kind":"claim", "floor":"floor", "crop":[x,y,w,h],
     "min_rmse":0.01, "min_floor_ratio":3.0}
  ]
}
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def linear_rgb(path: Path, crop=None) -> np.ndarray:
    image = Image.open(path).convert("RGB")
    if crop:
        x, y, w, h = map(int, crop)
        if w <= 0 or h <= 0 or x < 0 or y < 0 \
                or x + w > image.width or y + h > image.height:
            raise ValueError(f"crop {crop} is outside {image.size}: {path.name}")
        image = image.crop((x, y, x + w, y + h))
    value = np.asarray(image, dtype=np.float32) / 255.0
    return np.where(value <= 0.04045, value / 12.92,
                    ((value + 0.055) / 1.055) ** 2.4)


def rmse(a: Path, b: Path, crop=None) -> float:
    left = linear_rgb(a, crop)
    right = linear_rgb(b, crop)
    if left.shape != right.shape:
        raise ValueError(f"shape mismatch {a.name} {left.shape} != {b.name} {right.shape}")
    return math.sqrt(float(np.mean((left - right) ** 2)))


def frame_record(path: Path) -> dict:
    image = Image.open(path).convert("RGB")
    raw = np.asarray(image, dtype=np.uint8)
    luma = (raw[..., 0] * 0.2126 + raw[..., 1] * 0.7152
            + raw[..., 2] * 0.0722)
    return {
        "file": path.name,
        "width": image.width,
        "height": image.height,
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "luma_p01": round(float(np.percentile(luma, 1)), 3),
        "luma_p50": round(float(np.percentile(luma, 50)), 3),
        "luma_p99": round(float(np.percentile(luma, 99)), 3),
        "black_fraction": round(float(np.mean(luma <= 1.0)), 6),
        "clipped_fraction": round(float(np.mean(luma >= 254.0)), 6),
    }


def contact_sheet(paths: list[Path], output: Path, thumb=(384, 216)) -> None:
    if not paths:
        return
    columns = min(4, len(paths))
    rows = math.ceil(len(paths) / columns)
    label_h = 30
    sheet = Image.new("RGB", (columns * thumb[0], rows * (thumb[1] + label_h)),
                      (20, 20, 20))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, path in enumerate(paths):
        image = Image.open(path).convert("RGB")
        image.thumbnail(thumb, Image.Resampling.LANCZOS)
        col, row = index % columns, index // columns
        x = col * thumb[0] + (thumb[0] - image.width) // 2
        y = row * (thumb[1] + label_h) + (thumb[1] - image.height) // 2
        sheet.paste(image, (x, y))
        draw.text((col * thumb[0] + 7, row * (thumb[1] + label_h) + thumb[1] + 8),
                  path.name, fill=(235, 235, 235), font=font)
    sheet.save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--no-contact-sheet", action="store_true")
    args = parser.parse_args()
    directory = args.directory.resolve()
    paths = sorted(path for path in directory.glob("*.png")
                   if path.name != "contact_sheet.png")
    result = {"schema_version": 1, "directory": str(directory),
              "status": "PASS", "frames": [], "pairs": [], "failures": []}
    if not paths:
        result["status"] = "FAIL"
        result["failures"].append("no PNG frames")
    for path in paths:
        result["frames"].append(frame_record(path))

    manifest = {"pairs": []}
    if args.manifest:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    controls = {}
    for spec in manifest.get("pairs", []):
        name = str(spec["name"])
        try:
            value = rmse(directory / spec["a"], directory / spec["b"],
                         spec.get("crop"))
        except (FileNotFoundError, OSError, ValueError) as error:
            result["failures"].append(f"{name}: {error}")
            continue
        record = {"name": name, "kind": spec.get("kind", "claim"),
                  "a": spec["a"], "b": spec["b"], "crop": spec.get("crop"),
                  "linear_rgb_rmse": value}
        if record["kind"] == "control":
            controls[name] = value
        else:
            floor_name = spec.get("floor")
            floor = controls.get(floor_name) if floor_name else None
            if floor is not None:
                record["floor"] = floor_name
                record["floor_rmse"] = floor
                record["floor_ratio"] = None if floor == 0.0 else value / floor
                if floor == 0.0:
                    record["floor_ratio_note"] = "undefined_zero_floor"
            minimum = float(spec.get("min_rmse", 0.0))
            ratio = float(spec.get("min_floor_ratio", 0.0))
            if value < minimum:
                result["failures"].append(
                    f"{name}: RMSE {value:.8f} < declared minimum {minimum:.8f}")
            if floor is not None and ratio > 0.0:
                if floor == 0.0 and minimum <= 0.0:
                    result["failures"].append(
                        f"{name}: zero floor makes ratio undefined; declare min_rmse")
                elif floor > 0.0 and value < floor * ratio:
                    result["failures"].append(
                        f"{name}: RMSE {value:.8f} < {ratio:.2f}x floor {floor:.8f}")
        result["pairs"].append(record)
    if result["failures"]:
        result["status"] = "FAIL"
    (directory / "shot_metrics.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    if not args.no_contact_sheet:
        contact_sheet(paths, directory / "contact_sheet.png")
    print(f"[SHOT METRICS] {result['status']} frames={len(paths)} "
          f"pairs={len(result['pairs'])} failures={len(result['failures'])}")
    for record in result["pairs"]:
        print(f"[SHOT PAIR] {record['name']} kind={record['kind']} "
              f"rmse={record['linear_rgb_rmse']:.8f}")
    for failure in result["failures"]:
        print(f"[SHOT FAIL] {failure}")
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
