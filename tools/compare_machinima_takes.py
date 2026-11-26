"""Compare decoded MovieWriter PNG sequences or matched cast mattes by movie frame."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops


def compare(first, second, start, count, prefix="take"):
    if first.resolve() == second.resolve() or start < 0 or count < 1:
        raise ValueError("Use distinct take directories and a positive frame range")
    differences = []
    for index in range(start, start + count):
        name = f"{prefix}{index:08d}.png"
        with Image.open(first / name) as left, Image.open(second / name) as right:
            if left.size != right.size:
                raise ValueError(f"{name} dimensions differ: {left.size} and {right.size}")
            # A changed RGB channel with unchanged alpha must count as a difference.
            delta = ImageChops.difference(left.convert("RGBA"), right.convert("RGBA"))
            boxes = [box for channel in delta.split() if (box := channel.getbbox())]
            if boxes:
                bounds = [min(b[0] for b in boxes), min(b[1] for b in boxes),
                          max(b[2] for b in boxes), max(b[3] for b in boxes)]
                differences.append({"frame": index, "bounds": bounds})
    return {"first_frame": start, "frame_count": count, "different_frames": len(differences),
            "first_difference": differences[0] if differences else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("first", type=Path)
    parser.add_argument("second", type=Path)
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--count", type=int, required=True)
    parser.add_argument("--prefix", default="take")
    args = parser.parse_args()
    try:
        result = compare(args.first, args.second, args.start, args.count, args.prefix)
    except (ValueError, OSError) as error:
        parser.exit(2, f"Incomplete comparison: {error}\n")
    print(json.dumps(result, indent=2))
    return int(result["different_frames"] > 0)


if __name__ == "__main__":
    raise SystemExit(main())
