"""Verify a private storefront export and reproduce its runtime declaration."""

import argparse
import json
from pathlib import Path

from prepare_arcade_native_projection import NativeGLB, require, sha

ROOT = Path(__file__).resolve().parents[1]
ASSET = Path("game/assets/props/arcade_storefront_identity.glb")
MASTER = Path("art/blender/arcade_storefront_identity.blend")
OUTPUT = ROOT / "game/data/orison_v2/arcade_storefront_identity.json"


def build(delivery: Path) -> dict:
    report = json.loads((delivery/"STOREFRONT_NATIVE.json").read_text(encoding="utf-8"))
    for name, expected in report["source_bindings"].items():
        path = (ROOT/name).resolve()
        require(path.is_relative_to(ROOT), "Native source binding escapes checkout")
        require(sha(path, lf=path.suffix != ".png") == expected, f"Changed native source: {name}")
    for path, key in ((ASSET, "glb_sha256"), (MASTER, "blend_sha256")):
        require(sha(delivery/path) == report[key] == sha(ROOT/path), f"Changed native payload: {path}")
    parts = report["parts"]
    native = NativeGLB(delivery/ASSET)
    require(report["derivatives"]["status"] == "PASS", "Native tangent validation failed")
    require(len(report["stocks"]) == 78 and len(parts) == len(native.names) == 49,
            "Incomplete original storefront trim")
    require({part["name"] for part in parts} == set(native.names), "Native part names differ")
    for part in parts:
        require(native.triangles(part["name"]) == part["triangles"], "Native triangle count changed")
    plan = json.loads((ROOT/"art/data/arcade_plaza/source_plan.json").read_text(encoding="utf-8"))
    return dict(schema="orison.v2.arcade-storefront-identity.v1",
                asset="res://"+ASSET.relative_to("game").as_posix(),
                asset_sha256=report["glb_sha256"],
                materials=[dict(id=key, **recipe) for key, recipe in report["materials"].items()],
                native_parts=parts, cells=[shop["id"] for shop in plan["shops"]])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delivery", required=True, type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    declaration = json.dumps(build(args.delivery), indent=2)+"\n"
    if args.check:
        require(OUTPUT.read_text(encoding="utf-8") == declaration, "Stale storefront declaration")
    else:
        OUTPUT.write_text(declaration, encoding="utf-8", newline="\n")
    print("ARCADE STOREFRONT INTAKE PASS: 49 draws from 78 original stocks")


if __name__ == "__main__":
    main()
