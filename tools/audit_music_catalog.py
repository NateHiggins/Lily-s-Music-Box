#!/usr/bin/env python3
"""Fail closed when the Orison music catalogue confuses lore with rights."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


LORE_FIELD = "tracks.*.provenance"
REQUIRED_TRACK_FIELDS = {
    "title", "artist", "year", "provenance", "mood", "path", "cover"
}


def fail(message: str) -> None:
    print(f"FAIL: {message}")


def audit(catalog: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    semantics = catalog.get("field_semantics", {}).get(LORE_FIELD, {})
    if semantics.get("classification") != "in_world_fiction":
        failures.append(f"{LORE_FIELD} is not classified as in_world_fiction")
    if "rights_record" not in semantics:
        failures.append(f"{LORE_FIELD} does not declare a rights_record")
    if semantics.get("rights_record") is not None:
        failures.append("rights_record must remain null until a real record exists")
    warning = str(semantics.get("warning", "")).lower()
    for required in ("licence", "attribution", "distribution authority"):
        if required not in warning:
            failures.append(f"semantic warning does not name {required!r}")

    tracks = catalog.get("tracks")
    if not isinstance(tracks, dict) or not tracks:
        return failures + ["tracks must be a non-empty object"]

    paths: dict[str, str] = {}
    covers: dict[str, str] = {}
    for track_id, track in tracks.items():
        if not isinstance(track, dict):
            failures.append(f"track {track_id!r} is not an object")
            continue
        missing = sorted(REQUIRED_TRACK_FIELDS - set(track))
        if missing:
            failures.append(f"track {track_id!r} lacks {', '.join(missing)}")
        lore = track.get("provenance")
        if not isinstance(lore, str) or not lore.strip():
            failures.append(f"track {track_id!r} has no diegetic provenance")
        for field, owners in (("path", paths), ("cover", covers)):
            value = str(track.get(field, ""))
            if not value:
                continue
            if value in owners:
                failures.append(
                    f"tracks {owners[value]!r} and {track_id!r} share {field} {value!r}"
                )
            owners[value] = track_id
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    args = parser.parse_args()
    try:
        catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read catalogue: {exc}")
        return 2
    if not isinstance(catalog, dict):
        fail("catalogue root is not an object")
        return 2
    failures = audit(catalog)
    for message in failures:
        fail(message)
    if failures:
        print(f"MUSIC CATALOG AUDIT: FAIL ({len(failures)})")
        return 1
    print(f"MUSIC CATALOG AUDIT: PASS ({len(catalog['tracks'])} tracks; "
          "lore explicitly barred from rights inference)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
