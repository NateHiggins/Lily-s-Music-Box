"""Make a cast body's skin opaque when nothing in its picture is see-through.

Lily's and Stacy's bodies came out of their export with the skin materials in BLEND mode, double-sided. Their skin
pictures carry no transparent pixel, so blending buys nothing; it only takes the skin out of depth sorting, and a
sheer gown drawn after it shows the legs from behind. Adela's body is OPAQUE and does not.

Only materials named in SKIN are touched, and only when every pixel of their colour picture is fully opaque and the
colour factor has no alpha below one. Everything else in the glTF is left byte for byte, apart from the JSON it
rewrites with its existing layout (compact, as the exporter writes it).

    python art/tools/cast_opaque_skin.py game/assets/characters/lily/lily.gltf [...] [--check]
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image

SKIN = ("_human_body", "_concept_skin_pbr")


def opaque_picture(path: Path) -> bool:
    with Image.open(path) as image:
        if "A" not in image.getbands():
            return True
        low, _high = image.getchannel("A").getextrema()
        return low == 255


def plan(gltf: Path) -> list[str]:
    doc = json.loads(gltf.read_text(encoding="utf-8"))
    names = []
    for material in doc.get("materials", []):
        if not material.get("name", "").endswith(SKIN) or material.get("alphaMode", "OPAQUE") == "OPAQUE":
            continue
        pbr = material.get("pbrMetallicRoughness", {})
        if len(pbr.get("baseColorFactor", [1, 1, 1, 1])) == 4 and pbr.get("baseColorFactor", [1, 1, 1, 1])[3] < 1.0:
            continue
        texture = pbr.get("baseColorTexture")
        if texture is not None:
            uri = doc["images"][doc["textures"][texture["index"]]["source"]]["uri"]
            if not opaque_picture(gltf.parent / uri):
                continue
        names.append(material["name"])
    return names


def apply(gltf: Path, names: list[str]) -> None:
    text = gltf.read_text(encoding="utf-8")
    doc = json.loads(text)
    for material in doc["materials"]:
        if material.get("name") in names:
            material.pop("alphaMode", None)       # OPAQUE is the glTF default
            material.pop("alphaCutoff", None)
    # Keep the exporter's layout: compact, or one tab per level with no space after the colon.
    compact = "\n" not in text.strip()
    out = json.dumps(doc, separators=(",", ":")) if compact else json.dumps(doc, indent="\t", separators=(",", ":"))
    gltf.write_text(out + ("\n" if text.endswith("\n") else ""), encoding="utf-8", newline="\n")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("gltf", nargs="+", type=Path)
    parser.add_argument("--check", action="store_true", help="report only; exit 1 if any skin would change")
    args = parser.parse_args(argv)
    pending = 0
    for gltf in args.gltf:
        names = plan(gltf)
        pending += len(names)
        for name in names:
            print(("WOULD MAKE OPAQUE " if args.check else "OPAQUE ") + "%s: %s" % (gltf.as_posix(), name))
        if names and not args.check:
            apply(gltf, names)
    print("%d skin material(s) %s" % (pending, "to change" if args.check else "made opaque"))
    return 1 if args.check and pending else 0


if __name__ == "__main__":
    sys.exit(main())
