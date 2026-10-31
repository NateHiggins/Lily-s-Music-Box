#!/usr/bin/env python3
"""Build the papers' pictures from the generator's chosen cuts.

    python art/tools/build_newspaper_pictures.py --jobs jobs.json --seeds 3
    python art/tools/imagegen.py --batch jobs.json --out <dir>
    python art/tools/build_newspaper_pictures.py --cuts <dir of generated PNGs>

art/data/newspaper_picture_book.json holds every picture: its prompt, the seed chosen
after looking at the output, and for the printed ones where it runs and its caption.
Pictures are kept as small greyscale images; the panel's shader prints them as halftone
dots, gravure or ink at screen resolution. A composograph pastes a cut-out figure over
a second cut, with the white seam left showing, as the Speaker's art room would.
Captions are set live; the book also writes game/data/newspapers/pictures.json.
"""
from __future__ import annotations

import argparse
import json
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = pathlib.Path(__file__).resolve().parents[2]
BOOK = ROOT / "art/data/newspaper_picture_book.json"
ASSETS = ROOT / "game/assets/ui/newspaper"
DATA = ROOT / "game/data/newspapers/pictures.json"
RES = "res://assets/ui/newspaper"
SECTIONS = ("fronts", "features")
NEGATIVE = {
    "photo": "text, letters, words, numbers, signage, caption, logo, watermark, signature, color, modern, cartoon, painting, nude",
    "line": "text, letters, words, numbers, signature, logo, watermark, color, grey wash, photograph, modern, speech bubble, frame, nude",
}
PREFIX = {
    "photo": "1920s newspaper press photograph, black and white, grainy, documentary, ",
    "line": "pen and ink, black ink on white paper, 1920s newspaper illustration, ",
    "gravure": "1920s sepia rotogravure newspaper photograph, sharp, documentary, ",
    "drama": "1920s newspaper press photograph, black and white, grainy, staged melodrama studio still, dramatic lighting, ",
    "none": "",
}


def cuts_in(book: dict) -> list[dict]:
    """Every picture in the book, each with the folder it is built into."""
    found = []
    for item in book.get("furniture", []):
        found.append({**item, "folder": "furniture"})
    for section in SECTIONS:
        for item in book.get(section, []):
            found.append({**item["cut"], "folder": "pictures"})
    for drama in book.get("dramas", []):
        found.extend({**still["cut"], "folder": "pictures"} for still in drama["stills"])
    for section in book.get("sections", []):
        found.extend({**picture["cut"], "folder": "pictures"} for picture in section["pictures"])
    return found


def write_jobs(book: dict, out: pathlib.Path, seeds: int) -> None:
    jobs = {}
    def add(job_id: str, cut: dict) -> None:
        style = cut.get("style", "photo")
        jobs[job_id] = {"id": job_id, "prompt": PREFIX[style] + cut["prompt"],
                        "negative": NEGATIVE["line" if style == "line" else "photo"], "seeds": seeds,
                        "width": cut.get("width", 1216), "height": cut.get("height", 832)}
    for cut in cuts_in(book):
        if "prompt" in cut:
            add(cut.get("src", cut["id"]), cut)
        if "prompt" in cut.get("paste", {}):
            add(cut["paste"]["id"], cut["paste"])
    out.write_text(json.dumps(list(jobs.values()), indent=1), encoding="utf-8")
    print(f"{len(jobs)} prompts, {len(jobs) * seeds} images")


def source(cuts: pathlib.Path, cut: dict) -> Image.Image:
    return Image.open(cuts / f"{cut.get('src', cut['id'])}_s{cut.get('seed', 0)}.png").convert("L")


def paste_figure(scene: Image.Image, cuts: pathlib.Path, paste: dict) -> Image.Image:
    """Cut the dark figure from a studio plate and paste it on, seam showing."""
    plate = source(cuts, paste)
    if "ellipses" in paste:
        alpha = Image.new("L", plate.size, 0)
        draw = ImageDraw.Draw(alpha)
        for box in paste["ellipses"]:
            draw.ellipse(tuple(box), fill=255)
    else:
        dark = (np.asarray(plate) < paste.get("threshold", 80)).astype(np.uint8) * 255
        alpha = Image.fromarray(dark).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
    for box in paste.get("clear", []):
        ImageDraw.Draw(alpha).rectangle(tuple(box), fill=0)
    box = alpha.getbbox()
    figure = Image.merge("LA", (plate, alpha.filter(ImageFilter.GaussianBlur(0.7)))).crop(box)
    scale = paste["height"] / figure.height
    figure = figure.resize((round(figure.width * scale), paste["height"]), Image.LANCZOS)
    if paste.get("rotate"):
        figure = figure.rotate(paste["rotate"], expand=True, resample=Image.BICUBIC)
    out = scene.convert("RGBA")
    figure = figure.convert("RGBA")
    seam = Image.new("RGBA", figure.size, (235, 235, 235, 0))
    seam.putalpha(figure.getchannel("A").filter(ImageFilter.MaxFilter(5)))
    at = tuple(paste["at"])
    out.alpha_composite(seam, at)
    out.alpha_composite(figure, at)
    return out.convert("L")


def build_cut(cuts: pathlib.Path, cut: dict) -> Image.Image:
    image = source(cuts, cut)
    if "paste" in cut:
        image = paste_figure(image, cuts, cut["paste"])
    if "crop" in cut:
        image = image.crop(tuple(cut["crop"]))
    width = cut.get("shown", 1024)
    image = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
    if cut.get("style", "photo") != "line":
        image = ImageOps.autocontrast(image, cutoff=1)
    return image


def build_all(book: dict, cuts: pathlib.Path) -> None:
    built = 0
    for cut in cuts_in(book):
        folder = ASSETS / cut["folder"]
        folder.mkdir(parents=True, exist_ok=True)
        build_cut(cuts, cut).save(folder / f"{cut['id']}.webp", quality=cut.get("quality", 78), method=6)
        built += 1
    print(f"built {built} pictures")


def res_of(cut: dict, folder: str = "pictures") -> str:
    return f"{RES}/{folder}/{cut['id']}.webp"


def write_data(book: dict) -> None:
    data: dict = {"fronts": [], "features": [], "dramas": [], "sections": []}
    for section in SECTIONS:
        for item in book.get(section, []):
            row = {key: value for key, value in item.items() if key != "cut"}
            data[section].append({**row, "image": res_of(item["cut"])})
    for drama in book.get("dramas", []):
        row = {key: value for key, value in drama.items() if key != "stills"}
        data["dramas"].append({**row, "stills": [{"image": res_of(s["cut"]), "caption": s["caption"]} for s in drama["stills"]]})
    for section in book.get("sections", []):
        data["sections"].append({"paper": section.get("paper", "speaker"), "date": section["date"],
                                 "pictures": [{"image": res_of(p["cut"]), "caption": p["caption"]} for p in section["pictures"]]})
    DATA.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cuts", type=pathlib.Path)
    parser.add_argument("--jobs", type=pathlib.Path)
    parser.add_argument("--seeds", type=int, default=3)
    parser.add_argument("--book", type=pathlib.Path, default=BOOK)
    args = parser.parse_args()
    book = json.loads(args.book.read_text(encoding="utf-8"))
    if args.jobs:
        write_jobs(book, args.jobs, args.seeds)
        return
    if args.cuts:
        build_all(book, args.cuts)
    write_data(book)


if __name__ == "__main__":
    main()
