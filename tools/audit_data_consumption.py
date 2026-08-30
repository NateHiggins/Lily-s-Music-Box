#!/usr/bin/env python3
"""Find shipped data and durable numeric fields that have no real consumer.

This is deliberately source-only and conservative. JSON prose never counts as
proof of consumption. A file needs a production GDScript path reference; each
field needs a production token reader. Durable numeric fields whose only read
is self-feedback in their own monotonic assignment are reported separately.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

TOOL_VERSION = 1
DEFAULT_EXCEPTIONS = "tools/data_consumption_exceptions.json"
PATH_RE = re.compile(r"res://data/([A-Za-z0-9_./-]+\.json)")
STRING_RE = re.compile(r"['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]")
DOT_RE = re.compile(r"\.(?P<key>[A-Za-z_][A-Za-z0-9_]*)\b")
STATE_RE = re.compile(r"RealityState\.data(?:\.([A-Za-z_][A-Za-z0-9_]*))")
DEFAULT_NUM_RE = re.compile(r'^\s*"([A-Za-z_][A-Za-z0-9_]*)"\s*:\s*(-?\d+(?:\.\d+)?)')


def json_fields(value, prefix=""):
    out = Counter()
    if isinstance(value, dict):
        for key, child in value.items():
            path = f"{prefix}.{key}" if prefix else key
            out[path] += 1
            out.update(json_fields(child, path))
    elif isinstance(value, list):
        for child in value:
            out.update(json_fields(child, prefix + "[]"))
    return out


def production_sources(root: Path):
    return sorted(p for p in (root / "game/scripts").rglob("*.gd")
                  if "/tests/" not in p.as_posix())


def load_exceptions(path: Path):
    if not path.exists():
        return {"files": {}, "fields": {}}
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("exceptions root must be an object")
    return value


def scan(root: Path, exception_path: Path):
    exceptions = load_exceptions(exception_path)
    sources = production_sources(root)
    texts = {p: p.read_text(encoding="utf-8", errors="replace") for p in sources}
    path_users = {}
    token_users = {}
    for path, text in texts.items():
        rel = path.relative_to(root).as_posix()
        for match in PATH_RE.finditer(text):
            path_users.setdefault(match.group(1), set()).add(rel)
        for match in STRING_RE.finditer(text):
            token_users.setdefault(match.group(1), set()).add(rel)
        for match in DOT_RE.finditer(text):
            token_users.setdefault(match.group("key"), set()).add(rel)

    records = []
    data_root = root / "game/data"
    for path in sorted(data_root.glob("*.json")):
        rel_data = path.relative_to(data_root).as_posix()
        rel_repo = path.relative_to(root).as_posix()
        try:
            parsed = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            records.append({"kind": "MALFORMED", "file": rel_repo,
                            "detail": str(exc)})
            continue
        readers = sorted(path_users.get(rel_data, set()))
        file_exception = exceptions.get("files", {}).get(rel_repo)
        if not readers:
            records.append({"kind": "FILE_UNREAD", "file": rel_repo,
                            "detail": file_exception or "no production path reader",
                            "excepted": bool(file_exception)})
        fields = json_fields(parsed)
        # Instance-map keys (resident ids, fixture ids, room ids) are data,
        # not thousands of distinct schema fields. Consumption is therefore
        # reported by leaf token per file, with occurrence counts retained.
        leaves = Counter()
        for field, occurrences in fields.items():
            leaves[field.replace("[]", "").rsplit(".", 1)[-1]] += occurrences
        for leaf, occurrences in sorted(leaves.items()):
            field = leaf
            # A same-named token in an unrelated subsystem is not a reader.
            # Field proof must occur in a source that opens this exact file.
            users = sorted(set(token_users.get(leaf, set())) & set(readers))
            key = f"{rel_repo}:{field}"
            field_exception = exceptions.get("fields", {}).get(key)
            if not users:
                records.append({"kind": "FIELD_UNREAD", "file": rel_repo,
                                "field": field, "occurrences": occurrences,
                                "detail": field_exception or "zero production token readers",
                                "excepted": bool(field_exception)})

    state_file = root / "game/scripts/game/reality_game_state.gd"
    state_text = state_file.read_text(encoding="utf-8")
    # Only the top-level durable schema belongs to this gate. Nested case
    # records have dynamic keys and separate owners; treating their defaults
    # as global state manufactured false unread findings.
    fresh = state_text.partition("func _fresh_data()")[2]
    fresh = fresh.partition("\nfunc ")[0]
    numeric = {m.group(1) for m in map(DEFAULT_NUM_RE.match, fresh.splitlines()) if m}
    all_text = "\n".join(texts.values())
    for field in sorted(numeric):
        access = rf"(?:RealityState\.data\.{re.escape(field)}\b|RealityState\.data\.get\(\s*['\"]{re.escape(field)}['\"]|RealityState\.data\[['\"]{re.escape(field)}['\"]\])"
        hits = list(re.finditer(access, all_text))
        if not hits:
            records.append({"kind": "DURABLE_NUMERIC_UNREAD", "file":
                            "game/scripts/game/reality_game_state.gd", "field": field,
                            "detail": "zero production readers or writers", "excepted": False})
            continue
        meaningful = []
        monotonic = []
        for match in hits:
            line_start = all_text.rfind("\n", 0, match.start()) + 1
            line_end = all_text.find("\n", match.end())
            line = all_text[line_start: line_end if line_end >= 0 else None]
            window = all_text[max(0, line_start - 180): min(len(all_text), line_end + 180)]
            if re.search(rf"RealityState\.data\.{re.escape(field)}\s*=", window) and \
                    ("clampf(" in window or "+" in window):
                monotonic.append(line.strip())
            elif not re.search(rf"RealityState\.data\.{re.escape(field)}\s*=", line):
                meaningful.append(line.strip())
        if not meaningful and monotonic:
            records.append({"kind": "DURABLE_NUMERIC_MONOTONIC_ONLY",
                            "file": "game/scripts/game/reality_game_state.gd",
                            "field": field, "detail": "only self-feedback in monotonic writes",
                            "excepted": False})
    return records


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--exceptions", default=DEFAULT_EXCEPTIONS)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    try:
        exception_path = Path(args.exceptions)
        if not exception_path.is_absolute():
            exception_path = root / exception_path
        records = scan(root, exception_path)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"MALFORMED: {exc}", file=sys.stderr)
        return 4
    blockers = [r for r in records if not r.get("excepted")]
    payload = {"tool_version": TOOL_VERSION, "records": records,
               "summary": dict(Counter(r["kind"] for r in records)),
               "blocking": len(blockers)}
    if args.json:
        print(json.dumps(payload, indent=1, sort_keys=True))
    else:
        print("data consumption audit")
        for key, count in sorted(payload["summary"].items()):
            print(f"  {key}: {count}")
        print(f"  blocking: {len(blockers)}")
        for record in blockers[:80]:
            suffix = f":{record['field']}" if record.get("field") else ""
            print(f"  - {record['kind']} {record['file']}{suffix} ({record['detail']})")
    return 1 if blockers else 0


if __name__ == "__main__":
    raise SystemExit(main())
