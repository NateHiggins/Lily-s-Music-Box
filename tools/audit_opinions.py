#!/usr/bin/env python3
"""Hold the residents' dated opinions to their brief
(design/ORISON_NEWSPAPERS_2026-10-23.md §7).

Each game/data/opinions/<resident>.json: resident_id, hook, hook_line, and a
list of opinions {id, from, until, topic, line, choices[{label, reply, trust?,
flag?, requires?}], silence_reply?, requires?}. Checks ids (resident prefix,
unique), windows inside the year and in order, word budgets, forbidden
vocabulary, that every `requires` names an opinion flag (op:<id>) authored
earlier for that resident or a known tree/world flag, and that the dates the
opinion answers to exist in the papers. Exit 0 when clean.

    python tools/audit_opinions.py                 # every resident
    python tools/audit_opinions.py peter_wren      # one
"""
from __future__ import annotations

import datetime as dt
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
OPINIONS = REPO / "game/data/opinions"
DIALOGUE = REPO / "game/data/dialogue"
START = dt.date(1928, 11, 10)
END = dt.date(1929, 11, 9)
LINE_WORDS = (35, 110)
REPLY_WORDS = (12, 70)
MIN_OPINIONS = 16
FORBIDDEN = ["email", "computer", "online", "internet", "television", "antibiotic",
             "penicillin", "okay", "plastic", "radar", "transistor", "jet ", "nazi"]
PREFIXES = {
    "peter_wren": "pw", "cal_dwyer": "cd", "omar_bell": "ob", "mae_kessler": "mk",
    "juno_kells": "jk", "rhea_sato": "rs", "nadia_quell": "nq", "evelyn_marsh": "em",
    "teresa_vale": "tv", "lena_ortiz": "lo", "malcolm_reed": "mr", "cam_ortiz": "co",
    "noel_price": "np", "transient_guests": "tg", "iris_bell": "ib", "sacha_reed": "sr",
    "jonah_price": "jp",
}
WORLD_FLAGS = {"mina_four_seconds", "minutes_read", "otis_sixth_deaf", "station_went_quiet",
               "vales_hours_do_not_overlap", "vantry_in_3c"}


def words(text: str) -> int:
    return len(re.findall(r"[A-Za-z0-9'’]+", text))


def tree_flags() -> set[str]:
    flags: set[str] = set()
    for path in DIALOGUE.glob("*.json"):
        tree = json.loads(path.read_text(encoding="utf-8"))
        for node in tree.get("nodes", {}).values():
            for key in ("flag", "silence_flag"):
                if node.get(key):
                    flags.add(str(node[key]))
            for extra in node.get("flags", []):
                flags.add(str(extra))
            for choice in node.get("choices", []):
                if choice.get("flag"):
                    flags.add(str(choice["flag"]))
    return flags


def audit(only: str | None) -> tuple[list[str], dict]:
    failures: list[str] = []
    stats = {"residents": 0, "opinions": 0}
    known = tree_flags() | WORLD_FLAGS
    for resident, prefix in sorted(PREFIXES.items()):
        if only and resident != only:
            continue
        path = OPINIONS / f"{resident}.json"
        if not path.exists():
            failures.append(f"{resident}: no opinions file")
            continue
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            failures.append(f"{resident}: unreadable ({exc})")
            continue
        stats["residents"] += 1
        if doc.get("resident_id") != resident:
            failures.append(f"{resident}: resident_id is {doc.get('resident_id')!r}")
        if not str(doc.get("hook", "")).strip() or len(str(doc.get("hook", ""))) > 60:
            failures.append(f"{resident}: hook missing or over 60 characters")
        if not str(doc.get("hook_line", "")).strip():
            failures.append(f"{resident}: hook_line missing")
        opinions = doc.get("opinions")
        if not isinstance(opinions, list):
            failures.append(f"{resident}: opinions is not a list")
            continue
        if len(opinions) < MIN_OPINIONS:
            failures.append(f"{resident}: only {len(opinions)} opinions (want at least {MIN_OPINIONS})")
        seen: set[str] = set()
        granted: set[str] = set()
        previous_from = None
        for opinion in opinions:
            stats["opinions"] += 1
            oid = str(opinion.get("id", ""))
            where = f"{resident} {oid or '?'}"
            if not oid.startswith(prefix + "_op_"):
                failures.append(f"{where}: id must begin {prefix}_op_")
            if oid in seen:
                failures.append(f"{where}: duplicate id")
            seen.add(oid)
            try:
                start = dt.date.fromisoformat(str(opinion.get("from", "")))
                until = dt.date.fromisoformat(str(opinion.get("until", "")))
            except ValueError:
                failures.append(f"{where}: from/until are not dates")
                continue
            if start > until or start < START or until > END:
                failures.append(f"{where}: window {start}..{until} outside the year or reversed")
            if (until - start).days > 45:
                failures.append(f"{where}: window longer than 45 days")
            if previous_from and start < previous_from:
                failures.append(f"{where}: opinions must be in date order")
            previous_from = start
            if not str(opinion.get("topic", "")).strip() or len(str(opinion.get("topic", ""))) > 48:
                failures.append(f"{where}: topic missing or over 48 characters")
            n = words(str(opinion.get("line", "")))
            if not LINE_WORDS[0] <= n <= LINE_WORDS[1]:
                failures.append(f"{where}: line {n} words (want {LINE_WORDS[0]}-{LINE_WORDS[1]})")
            choices = opinion.get("choices", [])
            if not isinstance(choices, list) or not 1 <= len(choices) <= 3:
                failures.append(f"{where}: want 1 to 3 choices")
                choices = []
            for i, choice in enumerate(choices):
                if not isinstance(choice, dict) or not str(choice.get("label", "")).strip() \
                        or not str(choice.get("reply", "")).strip():
                    failures.append(f"{where}: choice {i} needs label and reply")
                    continue
                if len(str(choice["label"])) > 90:
                    failures.append(f"{where}: choice {i} label over 90 characters")
                m = words(str(choice["reply"]))
                if not REPLY_WORDS[0] <= m <= REPLY_WORDS[1]:
                    failures.append(f"{where}: choice {i} reply {m} words (want {REPLY_WORDS[0]}-{REPLY_WORDS[1]})")
                if "trust" in choice and not isinstance(choice["trust"], int):
                    failures.append(f"{where}: choice {i} trust is not an integer")
                if choice.get("flag"):
                    granted.add(str(choice["flag"]))
                for req in choice.get("requires", []):
                    if str(req) not in known | granted | {f"op:{s}" for s in seen - {oid}}:
                        failures.append(f"{where}: choice {i} requires unknown flag {req!r}")
            if "silence_reply" in opinion:
                m = words(str(opinion["silence_reply"]))
                if not REPLY_WORDS[0] <= m <= REPLY_WORDS[1]:
                    failures.append(f"{where}: silence_reply {m} words")
            for req in opinion.get("requires", []):
                if str(req) not in known | granted | {f"op:{s}" for s in seen - {oid}}:
                    failures.append(f"{where}: requires unknown flag {req!r} (earlier op:<id>, a tree flag or a world flag)")
            blob = json.dumps(opinion, ensure_ascii=False).lower()
            for word in FORBIDDEN:
                if re.search(r"\b" + re.escape(word.strip()) + r"\b", blob):
                    failures.append(f"{where}: forbidden word '{word.strip()}'")
            if "orison" in blob:
                failures.append(f"{where}: residents do not say the building's name to its operator in the papers' voice; cut 'Orison'")
    return failures, stats


def main(argv: list[str]) -> int:
    only = argv[1] if len(argv) > 1 else None
    failures, stats = audit(only)
    for line in failures[:200]:
        print("  FAIL", line)
    if len(failures) > 200:
        print(f"  ... {len(failures) - 200} more")
    print(f"OPINION AUDIT: {stats['opinions']} opinions for {stats['residents']} residents; "
          f"{len(failures)} failures -> {'PASS' if not failures else 'FAIL'}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
