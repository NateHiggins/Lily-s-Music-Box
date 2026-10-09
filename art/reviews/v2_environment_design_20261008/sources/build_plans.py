"""Per-level V2 plan drawings for the environment dossier.

Draws every semantic space of one level from game/data/orison_v2_blockout.json
(rects, ids, doors, openings, windows, furniture/fixture/interaction anchors)
and, when a dossier_sweep.json is supplied, the capture stations with their
view directions. Pure PIL; read-only; INERT. Scale is metres to pixels with a
north arrow derived from the layout's orientation block.

usage: build_plans.py OUT_DIR [dossier_sweep.json ...]
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, math, sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "game/project.godot").is_file())
layout = json.loads((ROOT / "game/data/orison_v2_blockout.json").read_text(encoding="utf-8"))
out_dir = Path(sys.argv[1]); out_dir.mkdir(parents=True, exist_ok=True)
sweeps = []
for extra in sys.argv[2:]:
    sweeps.append(json.loads(Path(extra).read_text(encoding="utf-8")))

PALETTE = {"public": (214, 226, 236), "private": (238, 232, 218), "service": (226, 226, 220), "wet": (204, 226, 230), "core": (232, 216, 214)}
INK = (28, 40, 48); MUTED = (110, 120, 128); DOOR = (170, 90, 30); WINDOW = (40, 120, 190); OPEN = (120, 120, 120)
STATION = {"overview": (0, 130, 110), "reverse": (0, 90, 160), "threshold": (170, 90, 30), "detail": (140, 40, 120)}
SCALE = 26  # px per metre

try:
    FONT = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 11)
    FONT_B = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 13)
    FONT_S = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 9)
except OSError:
    FONT = FONT_B = FONT_S = ImageFont.load_default()

levels = [l["id"] for l in layout["levels"]]
captures = {}
for sweep in sweeps:
    for space in sweep.get("spaces", []):
        for cap in space.get("captures", []):
            if "feet" in cap:
                captures.setdefault(space["id"], []).append(cap)

for level in levels:
    spaces = [s for s in layout["spaces"] if s["level"] == level]
    if not spaces:
        continue
    xs = [v for s in spaces for v in (s["rect"][0], s["rect"][2])]
    zs = [v for s in spaces for v in (s["rect"][1], s["rect"][3])]
    minx, maxx, minz, maxz = min(xs) - 1.5, max(xs) + 1.5, min(zs) - 1.5, max(zs) + 1.5
    W = int((maxx - minx) * SCALE); H = int((maxz - minz) * SCALE) + 40
    im = Image.new("RGB", (W, H), (250, 250, 248)); dr = ImageDraw.Draw(im)
    def px(x, z):
        # Godot: +x east, +z south (toward the street). Draw with north up.
        return (int((x - minx) * SCALE), int((z - minz) * SCALE) + 34)
    for s in spaces:
        r = s["rect"]; a = px(r[0], r[1]); b = px(r[2], r[3])
        dr.rectangle([a, b], fill=PALETTE.get(s.get("class", ""), (235, 235, 235)), outline=INK, width=1)
    for a in layout["anchors"]:
        if a.get("level") != level or a.get("kind") in ("clearance", "review"):
            continue
        p = a["position"]; c = px(p[0], p[2])
        col = {"furniture": (120, 100, 70), "fixture": (90, 90, 150), "interaction": (170, 60, 60)}.get(a.get("kind"), MUTED)
        dr.ellipse([c[0] - 2, c[1] - 2, c[0] + 2, c[1] + 2], fill=col)
    for f in layout["fixtures"]:
        if f.get("level") != level or not f.get("position") or not f.get("size"):
            continue
        p, sz = f["position"], f["size"]
        a = px(p[0] - sz[0] / 2, p[2] - sz[2] / 2); b = px(p[0] + sz[0] / 2, p[2] + sz[2] / 2)
        dr.rectangle([a, b], outline=(90, 90, 90), width=1)
    for d in layout["doors"]:
        if d["level"] != level:
            continue
        c = px(d["center"][0], d["center"][1]); w = d.get("width", 0.9) * SCALE / 2
        if abs(math.cos(d.get("yaw", 0))) > 0.5:
            dr.line([(c[0] - w, c[1]), (c[0] + w, c[1])], fill=DOOR, width=4)
        else:
            dr.line([(c[0], c[1] - w), (c[0], c[1] + w)], fill=DOOR, width=4)
    for o in layout["openings"]:
        if o["level"] != level:
            continue
        c = px(o["center"][0], o["center"][1]); w = o.get("width", 1.0) * SCALE / 2
        if o.get("axis", "x") == "x":
            dr.line([(c[0] - w, c[1]), (c[0] + w, c[1])], fill=OPEN, width=3)
        else:
            dr.line([(c[0], c[1] - w), (c[0], c[1] + w)], fill=OPEN, width=3)
    for wdw in layout["windows"]:
        if wdw["level"] != level:
            continue
        c = px(wdw["center"][0], wdw["center"][1]); w = wdw.get("width", 1.0) * SCALE / 2
        if wdw.get("axis", "x") == "x":
            dr.line([(c[0] - w, c[1]), (c[0] + w, c[1])], fill=WINDOW, width=3)
        else:
            dr.line([(c[0], c[1] - w), (c[0], c[1] + w)], fill=WINDOW, width=3)
    for s in spaces:
        r = s["rect"]; a = px(r[0], r[1])
        label = s["id"].replace(level + "_", "", 1)
        dr.text((a[0] + 3, a[1] + 2), label, fill=INK, font=FONT_S)
        for cap in captures.get(s["id"], []):
            fx, fz = cap["feet"][0], cap["feet"][2]; c = px(fx, fz)
            col = STATION.get(cap.get("kind"), MUTED)
            dr.ellipse([c[0] - 3, c[1] - 3, c[0] + 3, c[1] + 3], fill=col, outline=(255, 255, 255))
            fwd = cap.get("forward")
            if fwd:
                dr.line([c, (c[0] + fwd[0] * 14, c[1] + fwd[2] * 14)], fill=col, width=2)
    dr.text((8, 6), f"ORISON V2 {level}  plan from orison_v2_blockout.json; north up, street side south (+z)", fill=INK, font=FONT_B)
    dr.text((8, 20), "fill: public/private/service/wet/core  |  orange door  grey opening  blue window  |  dots: furniture brown, fixture violet, interaction red  |  stations: OV green, RV blue, TH orange, DT purple", fill=MUTED, font=FONT_S)
    im.save(out_dir / f"plan_{level}.png")
    print("plan", level, im.size)
