"""Project the reviewed license notice into its shipped display data.

The full research record (citations, access notes and limits) stays in design.
This projection does not schedule broadcasts or assert programme hours.
"""
from __future__ import annotations
import argparse
import copy
import datetime
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "design/historical_radio_reallocation.json"
OUTPUT = ROOT / "game/data/historical_radio_reallocation.json"


def runtime_notice(source):
    if type(source.get("schema_version")) is not int or source["schema_version"] != 1:
        raise ValueError("unsupported research schema")
    if source.get("medium") != "authored_hand_copy_of_published_license_notice":
        raise ValueError("only the reviewed printed-notice medium is supported")
    effective = source.get("effective", {})
    if effective.get("time_standard") != "Eastern Standard Time":
        raise ValueError("the campaign notice requires Eastern Standard Time")
    date = {key: effective.get(key) for key in ("year", "month", "day_of_month", "minute_of_day")}
    if any(type(value) is not int for value in date.values()):
        raise ValueError("effective date must use whole civil values")
    datetime.date(date["year"], date["month"], date["day_of_month"])
    if not 0 <= date["minute_of_day"] < 1440:
        raise ValueError("invalid effective minute")
    shared = source.get("shared_after", {})
    if shared.get("program_hours", "missing") is not None:
        raise ValueError("this notice cannot claim a programme schedule")
    citations = source.get("sources", {})

    def check_sources(ids):
        if not isinstance(ids, list) or not ids or any(identity not in citations for identity in ids):
            raise ValueError("notice assignment has a missing research source")

    def frequency(value):
        if type(value) is not int or value <= 0:
            raise ValueError("frequency must be a positive whole kilocycle value")
        return value

    rows = []
    for row in source.get("assignments", []):
        check_sources(row.get("before_sources"))
        check_sources(row.get("after_sources"))
        if not isinstance(row.get("station"), str) or not row["station"]:
            raise ValueError("missing station identity")
        rows.append({"station": row["station"], "before_kc": frequency(row.get("before_kc")),
                     "after_kc": frequency(row.get("after_kc"))})
    if not rows:
        raise ValueError("notice requires assignments")
    check_sources(shared.get("sources"))
    stations = shared.get("stations")
    if not isinstance(stations, list) or not stations or any(not isinstance(v, str) or not v for v in stations):
        raise ValueError("shared assignment requires station identities")
    result = {"schema_version": 1}
    for key in ("id", "notice_heading", "notice_date_line"):
        if not isinstance(source.get(key), str) or not source[key]:
            raise ValueError("missing printed notice field: " + key)
        result[key] = source[key]
    result.update(effective=date, assignments=rows,
                  shared_after={"stations": copy.deepcopy(stations), "kc": frequency(shared.get("kc"))})
    return result


def encoded_notice(source):
    return (json.dumps(runtime_notice(source), indent=2) + "\n").encode("utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    encoded = encoded_notice(json.loads(SOURCE.read_text(encoding="utf-8")))
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != encoded:
            print("historical notice runtime projection is stale")
            return 1
    else:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(encoded)
    print("historical notice runtime projection matches its research source")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
