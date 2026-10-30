"""Write the newspapers' advertising data and ink the chosen pictures.

    python art/tools/build_ad_book.py --cuts <dir of generated PNGs> --picks picks.json

The picks file maps an advertisement's id to the seed chosen after looking at the
generator's output. A pick turns the drawing into ink on transparency, so the
newsprint shows through; all lettering is set live by NewspaperAd. Without --cuts
this only rewrites advertisements.json from the briefs and the book.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib

from PIL import Image, ImageFilter, ImageOps

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/ui/newspaper/ads"
DATA = ROOT / "game/data/newspapers/advertisements.json"
BRIEFS = ROOT / "art/data/newspaper_ad_briefs.json"
INK = (28, 25, 22)
CUT_WIDTH = {"T": 512, "W": 768, "B": 768, "S": 640}
# Grey below this is ink; the band above it is the soft edge of the line.
INK_LEVEL, EDGE = 118, 40


def load_book():
    spec = importlib.util.spec_from_file_location("book", ROOT / "art/data/newspaper_ad_book.py")
    book = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(book)
    return book


def ink(source: pathlib.Path, width: int, target: pathlib.Path) -> None:
    grey = ImageOps.autocontrast(ImageOps.grayscale(Image.open(source)), cutoff=1)
    height = round(grey.height * width / grey.width)
    grey = grey.resize((width, height), Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 120, 2))
    alpha = grey.point(lambda v: 255 if v <= INK_LEVEL else 0 if v >= INK_LEVEL + EDGE
                       else round(255 * (INK_LEVEL + EDGE - v) / EDGE))
    # Drop the sheet: anything cut off by the frame's white border stays clear.
    print_ = Image.new("RGBA", (width, height), INK + (0,))
    print_.putalpha(alpha)
    bounds = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    print_.crop(bounds).save(target, optimize=True)


def write_data(book, images: set[str]) -> int:
    ads = []
    for brief in json.loads(BRIEFS.read_text(encoding="utf8"))["ads"]:
        row = book.AD[brief["id"]]
        ad = {"paper": brief["paper"], "firm": brief["advertiser"], "style": row[0], "size": row[1],
              "headline": brief["headline"], "body": brief["body"],
              "image": f"res://assets/ui/newspaper/ads/{brief['id']}.png"}
        ad.update(row[3] if len(row) > 3 else {})
        ads.append(ad)
    firms = {name: dict(zip(("mark", "mark_shape", "id_line", "address", "telephone", "hours", "slogan"), row), name=name)
             for name, row in book.FIRMS.items()}
    DATA.write_text(json.dumps({"firms": firms, "ads": ads}, ensure_ascii=False, indent=1) + "\n",
                    encoding="utf8", newline="\n")
    return len(ads)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cuts", type=pathlib.Path)
    parser.add_argument("--picks", type=pathlib.Path)
    args = parser.parse_args()
    book = load_book()
    if args.cuts:
        OUT.mkdir(parents=True, exist_ok=True)
        picks = json.loads(args.picks.read_text(encoding="utf8"))
        for ad_id, seed in picks.items():
            ink(args.cuts / f"{ad_id}_s{seed}.png", CUT_WIDTH[book.AD[ad_id][1]], OUT / f"{ad_id}.png")
    print(write_data(book, set()), "advertisements")


if __name__ == "__main__":
    main()
