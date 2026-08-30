#!/usr/bin/env python3
"""Audit the Orison's dated data and every structural GDScript year consumer.

This deliberately distinguishes a date existing in data from a date being
shown to a player.  It does not turn quarantined generated flavour into canon.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path
from typing import Any


YEAR_ACCESS = re.compile(r'(?:\.year\b|get\(\s*["\']year["\']|\[["\']year["\']\])')
INSTALLATION_YEAR = re.compile(r"\binstalled\s+(\d{4})\b", re.IGNORECASE)
EXPECTED_CONSUMERS = {
    "game/scripts/audio/music_director.gd": "player_readable_catalogue",
    "game/scripts/building/celestial_ephemeris.gd": "astronomy_calculation_only",
    # Reads the host date ONCE, at campaign creation, to seed the campaign
    # epoch; simulation time then advances from accumulated engine delta and
    # never re-reads the wall clock. The year is never shown to a player --
    # PhoneOS pins the displayed year to fictional 1928 -- so this is an
    # epoch seed, not a period surface. Landed 5c1a96a (ADMIN-PREREQ-1).
    "game/scripts/game/campaign_clock.gd": "campaign_epoch_seed_only",
    "game/scripts/minigames/shelf_sort.gd": "player_readable_period_library",
    "game/scripts/songbook/songbook_store.gd": "local_filename_only",
    "game/scripts/ui/bookshelf_panel.gd": "player_readable_period_library",
}
FIXTURE_FIELD = "fixtures.*.provenance"


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} root is not an object")
    return value


def consumer_paths(repo: Path) -> dict[str, list[int]]:
    found: dict[str, list[int]] = {}
    scripts = repo / "game" / "scripts"
    for path in sorted(scripts.rglob("*.gd")):
        lines = path.read_text(encoding="utf-8").splitlines()
        hits = [number for number, line in enumerate(lines, 1) if YEAR_ACCESS.search(line)]
        if hits:
            found[path.relative_to(repo).as_posix()] = hits
    return found


def audit(repo: Path) -> tuple[list[str], list[str]]:
    failures: list[str] = []
    notes: list[str] = []

    wire = load_object(repo / "game/data/prop_service_wire.json")
    try:
        cutoff = date.fromisoformat(str(wire["period_cutoff"]))
    except (KeyError, TypeError, ValueError) as exc:
        return [f"period_cutoff is absent or invalid: {exc}"], notes

    runtime_provenance_path = repo / "game/data/light_provenance.json"
    authored_provenance_path = repo / "art/data/light_provenance.json"
    provenance = load_object(runtime_provenance_path)
    authored_provenance = load_object(authored_provenance_path)
    if authored_provenance != provenance:
        failures.append(
            "light_provenance.json authoring/runtime mirrors differ; "
            "regenerate both from tools/author_light_provenance.py"
        )
    else:
        notes.append("light provenance: authoring/runtime mirrors agree")
    semantics = provenance.get("field_semantics", {}).get(FIXTURE_FIELD, {})
    required = {
        "classification": "generated_flavor",
        "authored": False,
        "generator": "tools/author_light_provenance.py",
        "canonical_authority": None,
        "player_surface": "debug_overlay_only",
    }
    for field, expected in required.items():
        if semantics.get(field) != expected:
            failures.append(f"{FIXTURE_FIELD} {field} must be {expected!r}")
    if "UNRULED" not in str(semantics.get("temporal_status", "")):
        failures.append(f"{FIXTURE_FIELD} temporal_status must remain explicitly UNRULED")

    fixtures = provenance.get("fixtures", {})
    if not isinstance(fixtures, dict) or not fixtures:
        failures.append("light provenance fixtures must be a non-empty object")
    else:
        years: list[int] = []
        missing: list[str] = []
        for fixture_id, fixture in fixtures.items():
            match = INSTALLATION_YEAR.search(str(fixture.get("provenance", "")))
            if match:
                years.append(int(match.group(1)))
            else:
                missing.append(str(fixture_id))
        if missing:
            failures.append(f"{len(missing)} fixture records lack a parseable installation year")
        declared = provenance.get("fixture_count")
        if declared != len(fixtures):
            failures.append(f"fixture_count says {declared!r}, data contains {len(fixtures)}")
        after = sum(year > cutoff.year for year in years)
        if years:
            notes.append(
                f"fixture data: {len(years)} parsed; {after} after {cutoff.year}; "
                "contained as generated, debug-only, UNRULED flavour"
            )

    found = consumer_paths(repo)
    unknown = sorted(set(found) - set(EXPECTED_CONSUMERS))
    missing = sorted(set(EXPECTED_CONSUMERS) - set(found))
    for path in unknown:
        failures.append(f"unclassified structural year consumer: {path}:{found[path]}")
    for path in missing:
        failures.append(f"classified year consumer disappeared or stopped being detected: {path}")
    for path in sorted(set(found) & set(EXPECTED_CONSUMERS)):
        notes.append(f"year consumer: {path}:{found[path]} [{EXPECTED_CONSUMERS[path]}]")

    phone_source = (repo / "game/scripts/phoneos/phone_os.gd").read_text(encoding="utf-8")
    if 'FICTIONAL_PRESENT_YEAR := "1928"' not in phone_source:
        failures.append("PhoneOS does not pin its displayed date to fictional 1928")
    if '_fictional_datetime(Time.get_datetime_string_from_system())' not in phone_source:
        failures.append("PhoneOS date command can bypass the fictional-year guard")
    notes.append("PhoneOS date: host month/day/time permitted; host year barred")

    library = load_object(repo / "game/data/library.json")
    books = library.get("books", [])
    if not isinstance(books, list) or not books:
        failures.append("period library books must be a non-empty array")
    else:
        bad = sorted(
            str(book.get("id", "<unnamed>")) for book in books
            if not isinstance(book.get("year"), int) or int(book["year"]) > cutoff.year
        )
        if bad:
            failures.append(f"library has invalid or post-cutoff book years: {', '.join(bad)}")
        notes.append(f"period library: {len(books)} player-readable years at or before cutoff")

    return failures, notes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", nargs="?", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    repo = args.repo.resolve()
    try:
        failures, notes = audit(repo)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"PERIOD DATE AUDIT: FAIL (cannot inspect repository: {exc})")
        return 2
    for note in notes:
        print(f"PERIOD DATE INFO {note}")
    for failure in failures:
        print(f"PERIOD DATE FAIL {failure}")
    if failures:
        print(f"PERIOD DATE AUDIT: FAIL ({len(failures)})")
        return 1
    print(f"PERIOD DATE AUDIT: PASS ({len(notes)} classified findings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
