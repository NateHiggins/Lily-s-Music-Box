"""Contact sheets for the M-COVER probe.

    python art/tools/build_coverage_contact_sheets.py <frames_dir> <out_dir>

Reads <frames_dir>/<station>__<option>.png and coverage.json, writes one
sheet per station with every option side by side (labelled with its measured
GPU median) and one "close" sheet of a centre crop at 2x so the tile edge,
ghosting and lattice can be judged without zooming the originals.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

STATIONS = ["corridor", "corridor_floor", "lobby", "flat_4b"]
OPTIONS = ["current", "plain", "mirror", "hex", "detail", "hex_detail",
           "mirror_detail", "split", "rows"]
CROP = {  # centre crops (left, top, right, bottom) in 1280x720 frame space
    "corridor": (440, 430, 840, 720),
    "corridor_floor": (300, 300, 980, 720),
    "lobby": (440, 480, 1040, 720),
    "flat_4b": (80, 420, 560, 720),
}


def font(size):
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def label(img, text, size=18):
    draw = ImageDraw.Draw(img)
    f = font(size)
    pad = 6
    box = draw.textbbox((0, 0), text, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.rectangle((0, 0, w + pad * 2, h + pad * 2), fill=(0, 0, 0))
    draw.text((pad, pad), text, fill=(232, 214, 160), font=f)
    return img


def main(frames_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    meta = json.load(open(os.path.join(frames_dir, "coverage.json")))
    for station in STATIONS:
        rows = meta["stations"].get(station, {})
        tiles, crops = [], []
        for opt in OPTIONS:
            path = os.path.join(frames_dir, "%s__%s.png" % (station, opt))
            if not os.path.exists(path):
                continue
            im = Image.open(path).convert("RGB")
            gpu = rows.get(opt, {}).get("gpu_ms")
            text = "%s  %s" % (opt, ("%.2f ms GPU" % gpu) if gpu is not None else "")
            tiles.append(label(im.resize((640, 360), Image.LANCZOS), text))
            c = im.crop(CROP[station])
            crops.append(label(c.resize((c.width * 2, c.height * 2), Image.LANCZOS),
                               text, 22))
        if not tiles:
            continue
        cols = 3
        rows_n = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (640 * cols, 360 * rows_n), (12, 12, 12))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * 640, (i // cols) * 360))
        sheet.save(os.path.join(out_dir, "%s_sheet.png" % station))
        cw, ch = crops[0].size
        csheet = Image.new("RGB", (cw * cols, ch * rows_n), (12, 12, 12))
        for i, c in enumerate(crops):
            csheet.paste(c, ((i % cols) * cw, (i // cols) * ch))
        csheet.save(os.path.join(out_dir, "%s_close.png" % station))
        print("wrote", station, len(tiles), "options")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
