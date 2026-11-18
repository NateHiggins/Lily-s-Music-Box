#!/usr/bin/env python3
"""Measure the shipped texture library and sort it by runtime load evidence.

Phase 0 of design/TEXTURE_LIBRARY_OPTIMIZATION_PLAN_2026-11-09.md. Read-only:
it changes no texture, import or material.

Static facts per texture: source and imported bytes, pixel size and mode, import
settings, exact duplicates, and how it is referenced (a res:// path or uid, its
file stem only, its folder only, or nothing).

Load evidence: pass one or more Godot logs written with --verbose. Godot prints
"Loading resource: <path>" for every resource it loads, including paths built at
runtime, so a texture absent from every trace was never loaded on those routes.
That is the plan's only accepted evidence of deprecation. Folders listed in
NOT_TRACED are presentation art whose use is not a route (UI, newspaper, book
plates); they are reported separately and never called deprecated by a trace.

    python tools/audit_textures.py --out C:/ov/reports/x
    python tools/audit_textures.py --out C:/ov/reports/x --trace a.log --trace b.log
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from collections import Counter, defaultdict
from pathlib import Path

TOOL_VERSION = 1
SCHEMA = "orison.texture-audit.v1"
IMAGE_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp", ".exr", ".hdr", ".tga", ".bmp", ".svg")
TEXT_SUFFIXES = (".tscn", ".tres", ".gd", ".gdshader", ".gdshaderinc", ".json", ".cfg",
                 ".godot", ".gltf")
# Mirrors the exclude_filter of both presets in game/export_presets.cfg.
EXPORT_EXCLUDES = ("tests/", "docs/", "assets/audio/freesound/source/",
                   "assets/audio/soundbits/")
NOT_TRACED = ("assets/ui/", "assets/book_illustrations/", "assets/2d art/",
              "assets/arcade/", "assets/audio/")
REF_RE = re.compile(r"(res://[^\"'\s)\]]+|uid://[a-z0-9]+)")
# Synchronous loads print the first form; threaded loads only the second.
LOAD_RE = re.compile(r"(?:Loading resource: |Completed load for: ')(res://[^'\s]+)")
IMPORT_KEY_RE = re.compile(r"^([a-z_/0-9]+)=(.*)$", re.M)


def import_settings(text: str) -> dict:
    """Return the keys of a .import file that decide its runtime cost."""
    values = {k: v.strip() for k, v in IMPORT_KEY_RE.findall(text)}
    dest = re.search(r"dest_files=\[(.*?)\]", text, re.S)
    uid = re.search(r'^uid="(.*?)"', text, re.M)
    return {
        "importer": values.get("importer", "").strip('"') or None,
        "compress": values.get("compress/mode"),
        "mipmaps": values.get("mipmaps/generate"),
        "normal_map": values.get("compress/normal_map"),
        "size_limit": values.get("process/size_limit"),
        "dest_files": re.findall(r'"res://(.*?)"', dest.group(1)) if dest else [],
        "uid": uid.group(1) if uid else None,
    }


def image_size(data: bytes) -> tuple[int, int, str]:
    """Width, height and mode, from the header only where possible."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        width, height, depth, colour = struct.unpack(">IIBB", data[16:26])
        mode = {0: "L", 2: "RGB", 3: "P", 4: "LA", 6: "RGBA"}.get(colour, "?")
        return width, height, mode
    try:
        from PIL import Image
        import io
        with Image.open(io.BytesIO(data)) as image:
            return image.size[0], image.size[1], image.mode
    except Exception:
        return 0, 0, "?"


def trace_paths(logs: list[Path], imported_to_source: dict[str, str]) -> dict[str, list[str]]:
    """Map each loaded source path (relative to game/) to the logs that load it."""
    loaded: dict[str, list[str]] = defaultdict(list)
    for log in logs:
        text = log.read_text(encoding="utf8", errors="replace")
        sources = set()
        for path in set(LOAD_RE.findall(text)):
            rel = path[len("res://"):]
            sources.add(imported_to_source.get(rel, rel))
        for rel in sources:
            loaded[rel].append(log.name)
    return loaded


def is_power_of_two(value: int) -> bool:
    return value > 0 and value & (value - 1) == 0


def audit(repo: Path, logs: list[Path]) -> dict:
    game = repo / "game"
    files = [p for p in game.rglob("*") if p.is_file() and ".godot" not in p.parts]
    rel = {p: p.relative_to(game).as_posix() for p in files}
    corpus = {}
    for path in files:
        if path.suffix in TEXT_SUFFIXES:
            corpus[rel[path]] = path.read_text(encoding="utf8", errors="replace")
        elif path.suffix == ".glb":
            data = path.read_bytes()
            if data[:4] == b"glTF":
                length = struct.unpack_from("<I", data, 12)[0]
                corpus[rel[path]] = data[20:20 + length].decode("utf8", "replace")
    everything = "\n".join(corpus.values())
    # One pass over the corpus: which files name each res:// path or uid.
    named_by: dict[str, set[str]] = defaultdict(set)
    for key, text in corpus.items():
        for token in REF_RE.findall(text):
            named_by[token].add(key)
    textures, imported_to_source, by_hash = [], {}, defaultdict(list)
    for path in files:
        name = rel[path]
        if path.suffix.lower() not in IMAGE_SUFFIXES or name.startswith(EXPORT_EXCLUDES):
            continue
        data = path.read_bytes()
        width, height, mode = image_size(data)
        digest = hashlib.sha256(data).hexdigest()
        row = {"path": name, "bytes": len(data), "width": width, "height": height,
               "mode": mode, "sha256": digest, "imported_bytes": 0}
        sidecar = path.with_name(path.name + ".import")
        if sidecar.exists():
            row.update(import_settings(sidecar.read_text(encoding="utf8", errors="replace")))
            for dest in row["dest_files"]:
                imported_to_source[dest] = name
                target = game / dest
                if target.exists():
                    row["imported_bytes"] += target.stat().st_size
        uid = row.get("uid")
        exact = sorted((named_by.get("res://" + name, set())
                        | (named_by.get(uid, set()) if uid else set())) - {name})
        stem = Path(name).stem
        if exact:
            row["reference"] = "path"
        elif stem in everything:
            row["reference"] = "stem"
        elif ("res://" + str(Path(name).parent.as_posix())) in everything:
            row["reference"] = "folder"
        else:
            row["reference"] = "none"
        row["referenced_by"] = exact[:5]
        by_hash[digest].append(name)
        textures.append(row)
    loaded = trace_paths(logs, imported_to_source) if logs else {}
    for row in textures:
        row["duplicate_of"] = sorted(by_hash[row["sha256"]])[0] \
            if len(by_hash[row["sha256"]]) > 1 and sorted(by_hash[row["sha256"]])[0] != row["path"] else None
        row["power_of_two"] = is_power_of_two(row["width"]) and is_power_of_two(row["height"])
        if row["path"].startswith(NOT_TRACED):
            row["trace"] = "not_traced"
        elif not logs:
            row["trace"] = "no_trace_given"
        else:
            row["trace"] = "loaded" if row["path"] in loaded else "never_loaded"
        row["loaded_in"] = sorted(loaded.get(row["path"], []))
    return {"schema": SCHEMA, "tool_version": TOOL_VERSION,
            "traces": [str(p) for p in logs], "textures": textures,
            "summary": summarize(textures)}


def summarize(textures: list[dict]) -> dict:
    mb = 1048576

    def total(rows, key="imported_bytes"):
        return round(sum(r[key] for r in rows) / mb, 1)

    groups = defaultdict(list)
    for row in textures:
        groups[row["sha256"]].append(row)
    extra = [r for rows in groups.values() if len(rows) > 1 for r in rows[1:]]
    tiers = Counter(f"compress={r.get('compress')} mipmaps={r.get('mipmaps')}" for r in textures)
    lossless_3d = [r for r in textures if r.get("compress") == "0" and r.get("mipmaps") == "true"]
    return {
        "textures": len(textures),
        "source_mb": total(textures, "bytes"),
        "imported_mb": total(textures),
        "duplicate_extra_copies": len(extra),
        "duplicate_extra_mb": total(extra),
        "lossless_with_mipmaps": len(lossless_3d),
        "lossless_with_mipmaps_mb": total(lossless_3d),
        "not_power_of_two": sum(1 for r in textures if r["width"] and not r["power_of_two"]),
        "over_2048": sum(1 for r in textures if max(r["width"], r["height"]) > 2048),
        "import_settings": dict(tiers.most_common()),
        "reference": {k: {"count": len(v), "imported_mb": total(v)} for k, v in
                      _group(textures, "reference").items()},
        "trace": {k: {"count": len(v), "imported_mb": total(v)} for k, v in
                  _group(textures, "trace").items()},
    }


def _group(rows: list[dict], key: str) -> dict[str, list[dict]]:
    out: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        out[row[key]].append(row)
    return dict(out)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--out", required=True, help="report folder (outside the repo)")
    parser.add_argument("--trace", action="append", default=[],
                        help="a Godot log written with --verbose; repeatable")
    args = parser.parse_args(argv)
    report = audit(Path(args.repo), [Path(p) for p in args.trace])
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "texture_audit.json").write_text(json.dumps(report, indent=1), encoding="utf8")
    never = sorted((r for r in report["textures"] if r["trace"] == "never_loaded"),
                   key=lambda r: -r["imported_bytes"])
    (out / "never_loaded.txt").write_text(
        "".join(f"{r['imported_bytes'] / 1048576:8.2f} MB  {r['reference']:6}  {r['path']}\n"
                for r in never), encoding="utf8")
    print(json.dumps(report["summary"], indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
