#!/usr/bin/env python3
"""Cast intake: built people in, checked game files out. CPU only.

    python art/tools/cast_intake.py export <build dir> <out dir> [--people id ...] [--jobs 4] [--blender exe]
    python art/tools/cast_intake.py check  <out dir>
    python art/tools/cast_intake.py recipes <out dir> [--write]

`export` runs art/blender/scripts/export_cast_actor.py for each person in <build dir> (what
art/blender/scripts/build_cast_wardrobe.py wrote), moves every picture that two or more people share
byte for byte into <out dir>/shared, then checks everything and writes <out dir>/CAST_INTAKE.json:
each file's size and SHA-256, and what the checks found.

`check` repeats the checks on an existing <out dir>. They are:
  - every model: indexed triangles, 76 joints, tangents by art/tools/check_cast_tangents.py;
  - every material: named cast_<id>_..., with a colour, a roughness-metal and a normal picture;
  - the body: eight skin parts, Hair and HairCap, and the face shapes the game's face controller needs;
  - every part: a note beside it naming this person, this part and a known slot;
  - no picture larger than 1024 on a side, and no file missing or left over.

`recipes` lists the material rows the catalogue needs for these people; with --write it adds them to
art/data/material_registry.json and regenerates the catalogues with art/tools/material_registry.py.

It accepts nothing about appearance. Look at the people in the engine.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "art/tools"))
import check_cast_tangents  # noqa: E402

BLENDER = "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
SKIN_AREAS = ["arms", "chest", "feet", "hands", "head", "hips", "legs", "trunk"]
SLOTS = ("top", "bottom", "over", "head", "feet")
# game/scripts/characters/cast_model_presentation.gd REQUIRED_FACE
REQUIRED_FACE = ["eyeBlinkLeft", "eyeBlinkRight", "viseme_PP", "viseme_kk", "viseme_SS", "viseme_E", "viseme_aa", "viseme_O", "viseme_U", "viseme_FF",
                 "viseme_nn", "viseme_DD", "jawOpen", "eyeLookInLeft", "eyeLookOutLeft", "eyeLookInRight", "eyeLookOutRight", "eyeLookUpLeft",
                 "eyeLookUpRight", "eyeLookDownLeft", "eyeLookDownRight"]
PICTURE_LIMIT = 1024
SHARED = "shared"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_size(path: Path) -> tuple[int, int]:
    head = path.read_bytes()[:24]
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG: %s" % path)
    return struct.unpack(">II", head[16:24])


def people_in(build: Path) -> list[str]:
    return sorted(path.stem for path in build.glob("*.blend") if "__" not in path.stem and (build / (path.stem + "__parts.blend")).exists())


def export_one(blender: str, who: str, build: Path, out: Path) -> tuple[str, int, str]:
    target = out / who
    if target.exists():
        shutil.rmtree(target)
    log = out / ("_%s_export.log" % who)
    with log.open("w", encoding="utf-8") as handle:
        done = subprocess.run([blender, "--factory-startup", "-b", "--python-exit-code", "1", "--python", str(ROOT / "art/blender/scripts/export_cast_actor.py"),
                               "--", who, str(build), str(target)], stdout=handle, stderr=subprocess.STDOUT)
    text = log.read_text(encoding="utf-8", errors="replace")
    last = [line for line in text.splitlines() if "CAST EXPORT COMPLETE" in line or "Error" in line]
    return who, done.returncode, (last[-1] if last else "")[:200]


def share_pictures(out: Path, people: list[str]) -> dict:
    """Pictures two or more people carry byte for byte are kept once, in <out>/shared."""
    owners: dict[str, list[Path]] = {}
    for who in people:
        for picture in sorted((out / who).glob("*.png")):
            owners.setdefault(sha(picture), []).append(picture)
    shared = out / SHARED
    moved = {}
    for digest, copies in sorted(owners.items()):
        if len({copy.parent for copy in copies}) < 2:
            continue
        shared.mkdir(exist_ok=True)
        kept = shared / ("%s_%s" % (digest[:10], copies[0].name))
        shutil.copyfile(copies[0], kept)
        for copy in copies:
            moved.setdefault(copy.parent.name, {})[copy.name] = "../%s/%s" % (SHARED, kept.name)
            copy.unlink()
    for who, table in moved.items():
        for model in sorted((out / who).glob("*.gltf")):
            document = json.loads(model.read_text(encoding="utf-8"))
            changed = False
            for image in document.get("images", []):
                if image.get("uri") in table:
                    image["uri"] = table[image["uri"]]
                    changed = True
            if changed:
                model.write_text(json.dumps(document, indent="\t", ensure_ascii=False), encoding="utf-8", newline="\n")
    return {"pictures_kept_once": len(list(shared.glob("*.png"))) if shared.exists() else 0, "copies_removed": sum(len(t) for t in moved.values())}


def check_person(out: Path, who: str) -> dict:
    folder = out / who
    problems: list[str] = []
    models = sorted(folder.glob("*.gltf"))
    body = folder / (who + ".gltf")
    if body not in models:
        return {"person": who, "problems": ["no body model"], "status": "FAIL"}
    used: set[Path] = set()
    vertices = 0
    triangles = 0
    for model in models:
        document = json.loads(model.read_text(encoding="utf-8"))
        tangents = check_cast_tangents.check(model, 0.5)
        vertices += tangents["vertices"]
        triangles += tangents["triangles"]
        problems += ["%s: %s" % (model.name, failure) for failure in tangents["failures"]]
        skins = document.get("skins", [])
        if len(skins) != 1 or len(skins[0].get("joints", [])) != 76:
            problems.append("%s: needs one skin of 76 joints" % model.name)
        for buffer in document.get("buffers", []):
            used.add(folder / buffer["uri"])
        for material in document.get("materials", []):
            name = material.get("name", "")
            if not name.startswith("cast_%s_" % who):
                problems.append("%s: material %s is not named cast_%s_..." % (model.name, name, who))
            spec = material.get("pbrMetallicRoughness", {})
            for label, entry in (("colour", spec.get("baseColorTexture")), ("roughness-metal", spec.get("metallicRoughnessTexture")), ("normal", material.get("normalTexture"))):
                if entry is None:
                    problems.append("%s: %s has no %s picture" % (model.name, name, label))
        for image in document.get("images", []):
            picture = (folder / image.get("uri", "")).resolve()
            used.add(picture)
            if not picture.is_file():
                problems.append("%s: picture missing: %s" % (model.name, image.get("uri")))
            elif max(png_size(picture)) > PICTURE_LIMIT:
                problems.append("%s: picture larger than %d: %s" % (model.name, PICTURE_LIMIT, image.get("uri")))
        if model == body:
            nodes = {node.get("name", ""): node for node in document.get("nodes", [])}
            areas = sorted(name[5:] for name in nodes if name.startswith("Skin_"))
            if areas != SKIN_AREAS:
                problems.append("body: skin parts are %s" % areas)
            for wanted in ("Hair", "HairCap"):
                if wanted not in nodes:
                    problems.append("body: no %s" % wanted)
            head = nodes.get("Skin_head")
            shapes = document["meshes"][head["mesh"]].get("extras", {}).get("targetNames", []) if head and "mesh" in head else []
            missing = [shape for shape in REQUIRED_FACE if shape not in shapes]
            if missing:
                problems.append("body: the head lacks face shapes %s" % missing)
        else:
            part = model.stem.split("__", 1)[1]
            note_path = folder / (model.stem + ".json")
            used.add(note_path)
            if not note_path.is_file():
                problems.append("%s: no note" % model.name)
            else:
                note = json.loads(note_path.read_text(encoding="utf-8"))
                if int(note.get("schema_version", 0)) != 1 or note.get("person") != who or note.get("part") != part or note.get("slot") not in SLOTS:
                    problems.append("%s: note does not name this person, this part and a known slot" % model.name)
    look = folder / (who + "_hair_look.json")
    if look.is_file():
        used.add(look.resolve())
        settings = json.loads(look.read_text(encoding="utf-8"))
        # game/scripts/characters/cast_hair_presentation.gd LOOK_KEYS
        lacking = [key for key in ("cap_shade", "cap_feather", "cap_bald", "underside", "roundness", "gloss", "hair_centre") if key not in settings]
        if lacking:
            problems.append("hair look lacks %s" % lacking)
    else:
        problems.append("no hair look file")
    present = {path.resolve() for path in folder.iterdir() if path.is_file() and path.name != who + "_EXPORT.json"}
    stray = sorted(path.name for path in present - {m.resolve() for m in models} - {Path(p).resolve() for p in used})
    if stray:
        problems.append("files no model uses: %s" % stray)
    size = sum(path.stat().st_size for path in folder.iterdir() if path.is_file() and path.name != who + "_EXPORT.json")
    return {"person": who, "models": len(models), "parts": len(models) - 1, "vertices": vertices, "triangles": triangles, "bytes": size,
            "problems": problems, "status": "PASS" if not problems else "FAIL"}


def check_all(out: Path) -> dict:
    people = sorted(path.name for path in out.iterdir() if path.is_dir() and path.name != SHARED and (path / (path.name + ".gltf")).exists())
    rows = [check_person(out, who) for who in people]
    shared = out / SHARED
    used_shared = set()
    for who in people:
        for model in (out / who).glob("*.gltf"):
            for image in json.loads(model.read_text(encoding="utf-8")).get("images", []):
                if image.get("uri", "").startswith("../%s/" % SHARED):
                    used_shared.add(image["uri"].rsplit("/", 1)[1])
    stray = sorted(path.name for path in shared.glob("*") if path.name not in used_shared) if shared.exists() else []
    files = {}
    for path in sorted(out.rglob("*")):
        if path.is_file() and not path.name.startswith("_") and path.name != "CAST_INTAKE.json" and not path.name.endswith("_EXPORT.json"):
            files[path.relative_to(out).as_posix()] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    return {"schema": "orison.cast-intake.v1", "people": rows, "shared_pictures": len(used_shared), "stray_shared": stray,
            "bytes": sum(entry["bytes"] for entry in files.values()), "files": files,
            "status": "PASS" if rows and not stray and all(row["status"] == "PASS" for row in rows) else "FAIL"}


def recipes(out: Path) -> dict:
    """The catalogue rows these people need: one per material, the factors as the models carry them."""
    rows: dict[str, dict] = {}
    for model in sorted(out.glob("*/*.gltf")):
        for material in json.loads(model.read_text(encoding="utf-8")).get("materials", []):
            spec = material.get("pbrMetallicRoughness", {})
            row = {"base_color": spec.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0]), "roughness": spec.get("roughnessFactor", 1.0), "metallic": spec.get("metallicFactor", 1.0)}
            if rows.setdefault(material["name"], row) != row:
                raise ValueError("one material, two recipes: " + material["name"])
    return rows


def write_recipes(rows: dict) -> int:
    registry_path = ROOT / "art/data/material_registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8"))
    known = {record["id"]: record for record in registry["materials"]}
    added = 0
    for name, row in rows.items():
        record = {"id": name, "catalog": row, "source_set": None, "in_game_catalog": True, "texture_status": "no_maps", "import_tier": "surface"}
        if name in known:
            if known[name] != record:
                known[name].update(record)
        else:
            registry["materials"].append(record)
            added += 1
    registry_path.write_text(json.dumps(registry, indent=1) + "\n", encoding="utf-8", newline="\n")
    done = subprocess.run([sys.executable, str(ROOT / "art/tools/material_registry.py"), "--write"])
    return added if done.returncode == 0 else -1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    exporting = commands.add_parser("export")
    exporting.add_argument("build")
    exporting.add_argument("out")
    exporting.add_argument("--people", nargs="*")
    exporting.add_argument("--jobs", type=int, default=4)
    exporting.add_argument("--blender", default=BLENDER)
    checking = commands.add_parser("check")
    checking.add_argument("out")
    listing = commands.add_parser("recipes")
    listing.add_argument("out")
    listing.add_argument("--write", action="store_true")
    args = parser.parse_args(argv)
    out = Path(args.out).resolve()
    if args.command == "export":
        build = Path(args.build).resolve()
        people = args.people or people_in(build)
        out.mkdir(parents=True, exist_ok=True)
        if (out / SHARED).exists():
            shutil.rmtree(out / SHARED)
        failed = []
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            for who, code, line in pool.map(lambda who: export_one(args.blender, who, build, out), people):
                print(who, "exit", code, line, flush=True)
                if code:
                    failed.append(who)
        if failed:
            print("export failed for", failed)
            return 1
        print("shared", share_pictures(out, people))
    if args.command in ("export", "check"):
        report = check_all(out)
        (out / "CAST_INTAKE.json").write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8", newline="\n")
        for row in report["people"]:
            print("%-22s %-4s parts %2d vertices %6d  %5.1f MB" % (row["person"], row["status"], row.get("parts", 0), row.get("vertices", 0), row.get("bytes", 0) / 1e6))
            for problem in row["problems"][:12]:
                print("    " + problem)
        print("total %.1f MB, %d shared pictures, status %s" % (report["bytes"] / 1e6, report["shared_pictures"], report["status"]))
        return 0 if report["status"] == "PASS" else 1
    rows = recipes(out)
    print(len(rows), "material rows")
    if args.write:
        added = write_recipes(rows)
        print("added", added)
        return 0 if added >= 0 else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
