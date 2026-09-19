"""Contact sheets: our frames on top, licensed references below, facts in the header."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

THUMB = (400, 300)
GAP = 12
HEADER_H = 92
CAPTION_H = 34
BG = (28, 29, 32)
FG = (232, 234, 238)
DIM = (150, 154, 162)


def _font(size: int):
    for candidate in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf",
                      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _thumb(path: Path) -> Image.Image:
    try:
        with Image.open(path) as source:
            image = source.convert("RGB")
    except (OSError, ValueError):
        image = Image.new("RGB", THUMB, (60, 30, 30))
        ImageDraw.Draw(image).text((10, 10), f"unreadable\n{path.name}", fill=FG, font=_font(16))
        return image
    image.thumbnail(THUMB)
    canvas = Image.new("RGB", THUMB, (18, 18, 20))
    canvas.paste(image, ((THUMB[0] - image.width) // 2, (THUMB[1] - image.height) // 2))
    return canvas


def build_sheet(facts: dict, our_frames: list[tuple[Path, str]],
                references: list[tuple[Path, str]], out_path: Path) -> Path:
    """One sheet: header line of facts, a row of our frames, rows of references."""
    per_row = max(1, max(len(our_frames), 4))
    ref_rows = (len(references) + per_row - 1) // per_row if references else 1
    width = GAP + per_row * (THUMB[0] + GAP)
    height = HEADER_H + (1 + ref_rows) * (THUMB[1] + CAPTION_H + GAP) + GAP
    sheet = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    title = _font(26)
    small = _font(15)
    draw.text((GAP, 10), f"{facts.get('kind', '?')}  -  {facts.get('label', '')}", fill=FG, font=title)
    size = facts.get("size_m") or [0, 0, 0]
    line2 = (f"{size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f} m (w x h x d)   mount {facts.get('mount', '?')}   "
             f"installed {facts.get('installed_count', 0)}   tier {facts.get('tier', '?')}   "
             f"{'reviewed' if facts.get('reviewed_before') else 'unreviewed'}   "
             f"{facts.get('triangles', 0)} tris   {facts.get('surfaces', 0)} surfaces, "
             f"{int(round(100 * facts.get('flat_colour_share', 1.0)))}% flat colour")
    draw.text((GAP, 48), line2, fill=DIM, font=small)
    draw.text((GAP, 68), f"real object: {facts.get('real_object', '')[:160]}", fill=DIM, font=small)

    def row(items: list[tuple[Path, str]], y: int, label: str) -> None:
        draw.text((GAP, y - 18), label, fill=DIM, font=small)
        x = GAP
        for path, caption in items[:per_row]:
            sheet.paste(_thumb(path), (x, y))
            draw.text((x, y + THUMB[1] + 4), caption[:60], fill=FG, font=small)
            x += THUMB[0] + GAP

    y = HEADER_H + 18
    row(our_frames, y, "OURS (warehouse, flat light)")
    y += THUMB[1] + CAPTION_H + GAP
    if references:
        for start in range(0, len(references), per_row):
            row(references[start:start + per_row], y,
                "REFERENCE (Wikimedia Commons; licence in caption; see provenance.json)")
            y += THUMB[1] + CAPTION_H + GAP
    else:
        draw.text((GAP, y), "no permissively licensed reference found for these queries", fill=DIM, font=small)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path, quality=88)
    return out_path


def downscale(source: Path, dest: Path, width: int = 640) -> Path:
    """A committable copy of one of our frames: JPEG, bounded width."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        rgb = image.convert("RGB")
        ratio = width / rgb.width if rgb.width > width else 1.0
        if ratio < 1.0:
            rgb = rgb.resize((int(rgb.width * ratio), int(rgb.height * ratio)), Image.LANCZOS)
        rgb.save(dest, quality=82)
    return dest


def write_index(entries: list[dict], out_dir: Path) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "comparison_index.json"
    json_path.write_text(json.dumps({"schema": "orison.prop-reference.comparison.v1",
                                     "specimens": entries}, indent=1), encoding="utf-8")
    lines = ["# Prop reference comparison index", "",
             "One row per warehouse specimen. Sheets contain third-party imagery and",
             "live outside git; the references are cited by Commons URL and licence.", "",
             "| specimen | kind | label | installed | tier | flat colour | references | sheet |",
             "|---|---|---:|---:|---|---:|---:|---|"]
    for e in entries:
        lines.append(f"| {e['id']} | {e['kind']} | {e['label']} | {e['installed_count']} | {e['tier']} | "
                     f"{int(round(100 * e['flat_colour_share']))}% | {len(e.get('references', []))} | "
                     f"{e.get('sheet', '')} |")
    md_path = out_dir / "index.md"
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return json_path, md_path
