"""QA contact sheets only; retain all native captures byte-for-byte."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageOps
ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / "design/astra/evidence/vulkan_composed/runs"
LEGACY = BASE / "f01_provider_legacy_03/frames"
CELLS = BASE / "f01_provider_owner_first_cells_04/frames"
OUT = ROOT / "design/astra/evidence/f01_provider_visual_review_01"
assert not OUT.exists() or not any(OUT.iterdir())
names = sorted(p.name for p in LEGACY.glob("*.png"))
assert names == sorted(p.name for p in CELLS.glob("*.png")) and len(names) == 18
OUT.mkdir(exist_ok=True)
for start in range(0, len(names), 3):
    canvas = Image.new("RGB", (1280, 1140), "#171717")
    draw = ImageDraw.Draw(canvas)
    for row, name in enumerate(names[start:start+3]):
        for col, (label, directory) in enumerate([("LEGACY", LEGACY), ("CELLS", CELLS)]):
            image = Image.open(directory / name).convert("RGB")
            image = ImageOps.contain(image, (640, 360))
            canvas.paste(image, (col * 640 + (640 - image.width) // 2, row * 380 + 20 + (360 - image.height) // 2))
            draw.text((col * 640 + 5, row * 380 + 3), label + " / " + name, fill="white")
    canvas.save(OUT / ("comparison_%02d.png" % (start // 3 + 1)))
(OUT / "index.json").write_text(json.dumps({"legacy": str(LEGACY), "cells": str(CELLS), "pairs": names, "native_images_modified": False}, indent=2) + "\n")
print(OUT)
