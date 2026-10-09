"""Contact sheets for dossier review: one JPEG per space (OV, RV, TH, DT1..n)
and grouped sheets for city stations. Captions carry the capture id, kind,
owner and feet. Read-only over SHOT_DIR + dossier_sweep.json. INERT.

usage: build_sheets.py SHOT_DIR OUT_DIR [--tile 640x360]
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, sys, math

shots = Path(sys.argv[1]); out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
tile = (640, 360)
for arg in sys.argv[3:]:
    if arg.startswith("--tile"):
        w, h = sys.argv[sys.argv.index(arg) + 1].split("x"); tile = (int(w), int(h))
sweep = json.loads((shots / "dossier_sweep.json").read_text(encoding="utf-8"))
try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 13)
    FONT_B = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 15)
except OSError:
    FONT = FONT_B = ImageFont.load_default()

def sheet(title, entries, path, cols=3):
    entries = [e for e in entries if (shots / e.get("image", "")).is_file()]
    if not entries:
        return False
    rows = math.ceil(len(entries) / cols)
    W = cols * tile[0]; H = 34 + rows * (tile[1] + 36)
    im = Image.new("RGB", (W, H), (18, 20, 22)); dr = ImageDraw.Draw(im)
    dr.text((8, 8), title, fill=(235, 235, 230), font=FONT_B)
    for i, e in enumerate(entries):
        x = (i % cols) * tile[0]; y = 34 + (i // cols) * (tile[1] + 36)
        src = Image.open(shots / e["image"]).convert("RGB"); src.thumbnail(tile)
        im.paste(src, (x + (tile[0] - src.width) // 2, y))
        feet = e.get("feet", [0, 0, 0])
        cap = f"{e['image'][:-4]}  [{e.get('kind','')}]  {e.get('owner','')}  feet=({feet[0]:.1f},{feet[1]:.1f},{feet[2]:.1f})"
        dr.text((x + 6, y + tile[1] + 4), cap[:120], fill=(200, 205, 200), font=FONT)
    im.save(path, quality=86)
    return True

index = []
for space in sweep.get("spaces", []):
    caps = [c for c in space.get("captures", []) if "image" in c]
    title = f"{space['id']}  ({space.get('level')}, {space.get('class')})  {space.get('purpose','')}  clear_stations={space.get('clear_stations')}"
    if sheet(title, caps, out / f"{space['id']}.jpg"):
        index.append({"id": space["id"], "sheet": f"{space['id']}.jpg", "captures": len(caps)})
city = sweep.get("city", [])
buckets = {}
for e in city:
    buckets.setdefault(e.get("bucket", "city"), []).append(e)
for bucket, entries in buckets.items():
    entries = [e for e in entries if "image" in e]
    for chunk in range(0, len(entries), 9):
        part = entries[chunk:chunk + 9]
        name = f"city_{bucket.replace(' ', '_')}_{chunk // 9 + 1:02d}.jpg"
        if sheet(f"CITY / {bucket}  stations {chunk + 1}-{chunk + len(part)} of {len(entries)}", part, out / name):
            index.append({"id": f"city:{bucket}:{chunk // 9 + 1}", "sheet": name, "captures": len(part)})
(out / "index.json").write_text(json.dumps({"evidence_class": "INERT", "sheets": index}, indent=1), encoding="utf-8")
print(json.dumps({"sheets": len(index), "out": str(out)}))
