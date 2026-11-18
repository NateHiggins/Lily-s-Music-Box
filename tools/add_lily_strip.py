"""Add one of Lily's daily strips to the game: the art into the build, a row into the catalogue.

    python tools/add_lily_strip.py <strip.png> --title "Progress" [--date 2026-11-07]

The real date (today if omitted) runs as the same day in the paper year, 10 Nov 1928 to 9 Nov 1929, so
10 Nov to 31 Dec are 1928 and every other day is 1929. The strip goes on sale at the Harukiya from that
in-world date, a penny, 19:00 to 02:00 (game/data/lily_strips.json, design/ORISON_LILY_STRIPS_2026-11-07.md).

Only the finished, lettered strip ships; prompts, LoRAs and renders stay outside the repository.
After adding, Godot must import the new picture once (the lane's --import) and its .webp.import is
staged with `git add -f`, as every newspaper picture is.
"""
import argparse
import datetime as dt
import json
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "game/data/lily_strips.json"
ART = ROOT / "game/assets/ui/comics/strips"
WIDTH = 1600


def game_date(real: dt.date) -> dt.date:
    """The same day in the paper year: November 10 onward is 1928, everything before it 1929."""
    year = 1928 if (real.month, real.day) >= (11, 10) else 1929
    return dt.date(year, real.month, real.day)


def add(png: pathlib.Path, title: str, real: dt.date) -> dict:
    day = game_date(real)
    ART.mkdir(parents=True, exist_ok=True)
    picture = Image.open(png).convert("RGB")
    picture = picture.resize((WIDTH, round(picture.height * WIDTH / picture.width)), Image.LANCZOS)
    out = ART / f"{day.isoformat()}.webp"
    picture.save(out, quality=88, method=6)
    doc = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    row = {"id": f"strip_{day.isoformat().replace('-', '_')}", "date": day.isoformat(), "title": title,
           "image": f"res://assets/ui/comics/strips/{out.name}"}
    doc["strips"] = [s for s in doc["strips"] if s["date"] != row["date"]] + [row]
    doc["strips"].sort(key=lambda s: s["date"])
    CATALOGUE.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    return row


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("png", type=pathlib.Path)
    parser.add_argument("--title", required=True)
    parser.add_argument("--date", type=dt.date.fromisoformat, default=dt.date.today(), help="the real date (default today)")
    args = parser.parse_args()
    row = add(args.png, args.title, args.date)
    print(f"{row['id']}: '{row['title']}' on sale from {row['date']} -> {row['image']}")
    print("Next: import it once on the lane (--import), then `git add -f` the .webp.import with the .webp and the catalogue.")


if __name__ == "__main__":
    main()
