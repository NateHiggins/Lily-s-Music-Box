#!/usr/bin/env python3
"""Hold the two daily papers to their brief (design/ORISON_NEWSPAPERS_2026-10-23.md).

Checks every slice file under game/data/newspapers: each date of the year
present exactly once with the right weekday, both papers on every day, the
front-page shape, word budgets, forbidden vocabulary, and that nobody from the
building is named. Exit 0 when clean.

    python tools/audit_newspapers.py            # the whole year
    python tools/audit_newspapers.py 1929-03a   # one slice (dates outside it are not required)
"""
from __future__ import annotations

import datetime as dt
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DATA = REPO / "game/data/newspapers"
START = dt.date(1928, 11, 10)
END = dt.date(1929, 11, 9)
PAPERS = ("record", "speaker")
LEAD_WORDS = (50, 100)
COLUMN_WORDS = (22, 62)
COLUMNS = 3
FORBIDDEN = [
    "email", "e-mail", "computer", "online", "internet", "television", "televis",
    "app ", "antibiotic", "penicillin", "nazi", "hitler", "world war ii",
    "second world war", "orison", "okay", "ok ", "teenager", "robot", "laser",
    "nylon", "plastic", "microwave", "jet ", "radar", "transistor",
]
RESIDENTS = [
    "peter wren", "cal dwyer", "omar bell", "mae kessler", "juno kells",
    "rhea sato", "nadia quell", "evelyn marsh", "teresa vale", "lena ortiz",
    "malcolm reed", "cam ortiz", "noel price", "iris bell", "sacha reed",
    "jonah price", "mina vale", "vantry, h", "h. vantry", "dorothy ash",
]
WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


def slices() -> list[tuple[str, dt.date, dt.date]]:
    out: list[list] = []
    day = START
    while day <= END:
        key = f"{day.year}-{day.month:02d}{'a' if day.day <= 15 else 'b'}"
        if not out or out[-1][0] != key:
            out.append([key, day, day])
        else:
            out[-1][2] = day
        day += dt.timedelta(days=1)
    return [tuple(row) for row in out]


def words(text: str) -> int:
    return len(re.findall(r"[A-Za-z0-9'’]+", text))


def check_page(page: object, where: str, failures: list[str]) -> None:
    if not isinstance(page, dict):
        failures.append(f"{where}: not an object")
        return
    for key in ("ear", "lead", "columns", "wire"):
        if key not in page:
            failures.append(f"{where}: missing {key}")
    ear = str(page.get("ear", ""))
    if not ear.strip() or "\n" in ear:
        failures.append(f"{where}: ear must be one non-empty line")
    lead = page.get("lead", {})
    if not isinstance(lead, dict):
        failures.append(f"{where}: lead is not an object")
    else:
        for key in ("headline", "deck", "body"):
            if not str(lead.get(key, "")).strip():
                failures.append(f"{where}: lead.{key} empty")
        headline = str(lead.get("headline", ""))
        if len(headline) >= 80:
            failures.append(f"{where}: lead headline {len(headline)} characters (want under 80)")
        if headline.isupper() and len(headline) > 8:
            failures.append(f"{where}: lead headline is shouted in capitals; author in sentence case")
        n = words(str(lead.get("body", "")))
        if not LEAD_WORDS[0] <= n <= LEAD_WORDS[1]:
            failures.append(f"{where}: lead body {n} words (want {LEAD_WORDS[0]}-{LEAD_WORDS[1]})")
    columns = page.get("columns", [])
    if not isinstance(columns, list) or len(columns) != COLUMNS:
        failures.append(f"{where}: want exactly {COLUMNS} columns")
    else:
        for i, column in enumerate(columns):
            if not isinstance(column, dict) or not str(column.get("headline", "")).strip() \
                    or not str(column.get("body", "")).strip():
                failures.append(f"{where}: column {i} needs headline and body")
                continue
            if len(str(column["headline"])) >= 80:
                failures.append(f"{where}: column {i} headline {len(str(column['headline']))} characters (want under 80)")
            n = words(str(column["body"]))
            if not COLUMN_WORDS[0] <= n <= COLUMN_WORDS[1]:
                failures.append(f"{where}: column {i} body {n} words (want {COLUMN_WORDS[0]}-{COLUMN_WORDS[1]})")
            if str(column["headline"]).isupper() and len(str(column["headline"])) > 8:
                failures.append(f"{where}: column {i} headline shouted in capitals")
    wire = str(page.get("wire", ""))
    if not wire.startswith("LATE WIRE:") or "\n" in wire:
        failures.append(f"{where}: wire must be one line beginning 'LATE WIRE:'")
    blob = json.dumps(page, ensure_ascii=False).lower()
    for word in FORBIDDEN:
        if re.search(r"\b" + re.escape(word.strip()) + (r"\b" if not word.strip().endswith("televis") else ""), blob):
            failures.append(f"{where}: forbidden word '{word.strip()}'")
    for name in RESIDENTS:
        if name in blob:
            failures.append(f"{where}: names a resident ('{name}')")


def audit(only: str | None) -> tuple[list[str], dict]:
    failures: list[str] = []
    stats = {"issues": 0, "files": 0}
    mastheads = DATA / "papers.json"
    if not mastheads.exists():
        failures.append("papers.json missing")
    seen: dict[str, str] = {}
    for key, first, last in slices():
        if only and key != only:
            continue
        path = DATA / f"{key}.json"
        if not path.exists():
            failures.append(f"{key}.json missing ({first} to {last})")
            continue
        stats["files"] += 1
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            failures.append(f"{key}.json unreadable: {exc}")
            continue
        issues = doc.get("issues") if isinstance(doc, dict) else None
        if not isinstance(issues, list):
            failures.append(f"{key}.json: no issues list")
            continue
        expected = {first + dt.timedelta(days=i) for i in range((last - first).days + 1)}
        for issue in issues:
            if not isinstance(issue, dict) or "date" not in issue:
                failures.append(f"{key}.json: issue without a date")
                continue
            try:
                day = dt.date.fromisoformat(str(issue["date"]))
            except ValueError:
                failures.append(f"{key}.json: bad date {issue['date']!r}")
                continue
            where = f"{key}.json {day}"
            if day not in expected:
                failures.append(f"{where}: outside this slice")
            if str(day) in seen:
                failures.append(f"{where}: duplicate (also in {seen[str(day)]})")
            seen[str(day)] = key
            expected.discard(day)
            weekday = WEEKDAYS[day.weekday()]
            if str(issue.get("weekday", "")) != weekday:
                failures.append(f"{where}: weekday is {weekday}")
            for paper in PAPERS:
                if paper not in issue:
                    failures.append(f"{where}: missing the {paper}")
                    continue
                check_page(issue[paper], f"{where} {paper}", failures)
            stats["issues"] += 1
        for missing in sorted(expected):
            failures.append(f"{key}.json: no issue for {missing}")
    return failures, stats


def main(argv: list[str]) -> int:
    only = argv[1] if len(argv) > 1 else None
    failures, stats = audit(only)
    for line in failures[:200]:
        print("  FAIL", line)
    if len(failures) > 200:
        print(f"  ... {len(failures) - 200} more")
    print(f"NEWSPAPER AUDIT: {stats['issues']} issues in {stats['files']} files; "
          f"{len(failures)} failures -> {'PASS' if not failures else 'FAIL'}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
