#!/usr/bin/env python3
"""Find shipped data and durable numeric fields that have no real consumer.

This is deliberately source-only and conservative. JSON prose never counts as
proof of consumption. A file needs a production GDScript path reference; each
field needs a production token reader. Durable numeric fields retain their
full nested schema path; path-aware aliases, constant keys and generic
container iteration are followed. Fields whose only read is self-feedback in
their own monotonic assignment are reported separately.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

TOOL_VERSION = 2
DEFAULT_EXCEPTIONS = "tools/data_consumption_exceptions.json"
PATH_RE = re.compile(r"res://data/([A-Za-z0-9_./-]+\.json)")
STRING_RE = re.compile(r"['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]")
DOT_RE = re.compile(r"\.(?P<key>[A-Za-z_][A-Za-z0-9_]*)\b")
STATE_RE = re.compile(r"RealityState\.data(?:\.([A-Za-z_][A-Za-z0-9_]*))")
DEFAULT_FIELD_RE = re.compile(
    r'^(?P<indent>\s*)"(?P<field>[A-Za-z_][A-Za-z0-9_]*)"\s*:\s*(?P<value>.*)$')
NUMBER_RE = re.compile(
    r"^[+-]?(?:(?:\d(?:_?\d)*)?(?:\.\d(?:_?\d)*)|"
    r"\d(?:_?\d)*)(?:e[+-]?\d(?:_?\d)*)?$", re.IGNORECASE)
CONST_STRING_RE = re.compile(
    r"^\s*const\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:\s*:\s*[^=]+)?\s*(?::=|=)\s*['\"](?P<value>[^'\"]+)['\"]")
CONST_NUMBER_RE = re.compile(
    r"^\s*const\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:\s*:\s*[^=]+)?\s*(?::=|=)\s*(?P<value>[^#]+?)\s*$")
ASSIGNMENT_RE = re.compile(r"(?<![=!<>])(?P<op>\+=|-=|\*=|/=|=(?!=))")


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


def source_constants(text: str):
    strings = {}
    numbers = {}
    for line in text.splitlines():
        string_match = CONST_STRING_RE.match(line)
        if string_match:
            strings[string_match.group("name")] = string_match.group("value")
        number_match = CONST_NUMBER_RE.match(line)
        if not number_match:
            continue
        value = number_match.group("value").strip().rstrip(",")
        if NUMBER_RE.fullmatch(value):
            numbers[number_match.group("name")] = value
    return strings, numbers


def durable_numeric_defaults(state_text: str):
    """Return numeric defaults from RealityState._fresh_data by full path.

    The durable state is a nested dictionary, even though most of today's
    top-level owners begin as empty maps.  Indentation is authoritative inside
    this literal: it lets the audit follow future bucket schemas without
    mistaking dynamic dictionaries declared elsewhere for global save facts.
    """
    marker = "func _fresh_data()"
    if marker not in state_text:
        raise ValueError("RealityState has no _fresh_data durable schema")
    fresh = state_text.partition(marker)[2]
    fresh = fresh.partition("\nfunc ")[0]
    if not re.search(r"\breturn\s*\{", fresh):
        raise ValueError("RealityState._fresh_data has no dictionary literal")
    _strings, numeric_constants = source_constants(state_text)
    stack = []
    numeric = {}
    for line in fresh.splitlines():
        match = DEFAULT_FIELD_RE.match(line)
        if not match:
            continue
        indent = len(match.group("indent").expandtabs(4))
        while stack and indent <= stack[-1][0]:
            stack.pop()
        field = match.group("field")
        value = match.group("value").split("#", 1)[0].strip().rstrip(",")
        prefix = tuple(segment for _indent, segments in stack
                       for segment in segments)
        path = prefix + (field,)
        if value == "{":
            stack.append((indent, (field,)))
        elif value == "[":
            stack.append((indent, (field, "*")))
        elif NUMBER_RE.fullmatch(value) or value in numeric_constants:
            numeric[path] = value
        elif ((value.startswith("{") and value != "{}") or
              (value.startswith("[") and value != "[]")):
            raise ValueError(
                f"inline durable container for {'.'.join(path)} is not auditable")
        elif re.search(r"\d", value) and not re.fullmatch(r"['\"].*['\"]", value):
            raise ValueError(
                f"unsupported numeric durable default for {'.'.join(path)}: {value}")
    if not numeric:
        raise ValueError("RealityState._fresh_data declares no numeric fields")
    return numeric


def _matching_close(text: str, start: int, opening: str, closing: str):
    depth = 0
    quote = ""
    for index in range(start, len(text)):
        char = text[index]
        if quote:
            if char == quote and (index == 0 or text[index - 1] != "\\"):
                quote = ""
            continue
        if char in "'\"":
            quote = char
        elif char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return index
    return -1


def _key_value(token: str, constants):
    token = token.strip()
    if len(token) >= 2 and token[0] == token[-1] and token[0] in "'\"":
        return token[1:-1]
    if token in constants:
        return constants[token]
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", token):
        return "*"
    return None


def _parse_access_tail(text: str, start: int, base, constants):
    path = list(base)
    index = start
    while index < len(text):
        if text.startswith(".get", index):
            open_at = text.find("(", index + 4)
            if open_at < 0:
                break
            close_at = _matching_close(text, open_at, "(", ")")
            if close_at < 0:
                break
            first_arg = text[open_at + 1:close_at].split(",", 1)[0]
            key = _key_value(first_arg, constants)
            if key is None:
                break
            path.append(key)
            index = close_at + 1
            continue
        if text.startswith(".values()", index) or text.startswith(".keys()", index):
            index += len(".values()")
            break
        dot = re.match(r"\.([A-Za-z_][A-Za-z0-9_]*)", text[index:])
        if dot:
            if index + dot.end() < len(text) and text[index + dot.end()] == "(":
                break
            path.append(dot.group(1))
            index += dot.end()
            continue
        if text[index] == "[":
            close_at = _matching_close(text, index, "[", "]")
            if close_at < 0:
                break
            key = _key_value(text[index + 1:close_at], constants)
            if key is None:
                break
            path.append(key)
            index = close_at + 1
            continue
        break
    return tuple(path), index


def _string_spans(text: str):
    spans = []
    start = -1
    quote = ""
    for index, char in enumerate(text):
        if quote:
            if char == quote and (index == 0 or text[index - 1] != "\\"):
                spans.append((start, index + 1))
                quote = ""
        elif char in "'\"":
            start = index
            quote = char
    if quote:
        spans.append((start, len(text)))
    return spans


def assignment_match(statement: str):
    strings = _string_spans(statement)
    for match in ASSIGNMENT_RE.finditer(statement):
        if not any(lo <= match.start() < hi for lo, hi in strings):
            return match
    return None


def access_chains(text: str, aliases, constants):
    found = []
    occupied = []
    strings = _string_spans(text)
    inside_string = lambda position: any(lo <= position < hi for lo, hi in strings)
    for match in re.finditer(r"RealityState\.data\b", text):
        if inside_string(match.start()):
            continue
        path, end = _parse_access_tail(text, match.end(), (), constants)
        if path:
            found.append(path)
            occupied.append((match.start(), end))
    for alias, base in sorted(aliases.items(), key=lambda item: -len(item[0])):
        for match in re.finditer(rf"\b{re.escape(alias)}\b", text):
            if inside_string(match.start()) or any(
                    lo <= match.start() < hi for lo, hi in occupied):
                continue
            path, end = _parse_access_tail(text, match.end(), base, constants)
            if len(path) >= len(base):
                found.append(path)
    return found


def path_matches(declared, accessed):
    return len(declared) == len(accessed) and all(
        expected == actual or expected == "*" or actual == "*"
        for expected, actual in zip(declared, accessed))


def _binding(statement: str):
    return re.match(
        r"^(?:var\s+|const\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
        r"(?:\s*:\s*[^:=]+)?\s*(?::=|=)(?!=)\s*(?P<rhs>.+)$", statement)


def _member_names(text: str):
    return set(re.findall(
        r"^(?:@[A-Za-z_][A-Za-z0-9_]*(?:\([^\n]*\))?\s+)*"
        r"var\s+([A-Za-z_][A-Za-z0-9_]*)\b", text, re.MULTILINE))


def _string_binding(rhs: str):
    match = re.fullmatch(r"\s*(['\"])(?P<value>.*)\1\s*", rhs)
    return match.group("value") if match else None


def _numeric_source_pass(text: str, root_aliases, member_aliases):
    class_constants, _numbers = source_constants(text)
    constants = class_constants.copy()
    members = _member_names(text)
    root_aliases = dict(root_aliases or {})
    aliases = {**root_aliases, **member_aliases}
    events = []
    for statement in logical_statements(text):
        if statement.startswith("func "):
            aliases = {**root_aliases, **member_aliases}
            constants = class_constants.copy()
        assignment = assignment_match(statement)
        if assignment:
            lhs = statement[:assignment.start()]
            rhs = statement[assignment.end():]
            lhs_paths = access_chains(lhs, aliases, constants)
            rhs_paths = access_chains(rhs, aliases, constants)
            op = assignment.group("op")
        else:
            lhs_paths = []
            rhs_paths = access_chains(statement, aliases, constants)
            op = ""
        for path in lhs_paths:
            self_read = any(path_matches(path, candidate) for candidate in rhs_paths)
            monotonic = op in {"+=", "-="} or (self_read and (
                "+" in rhs or "clampf(" in rhs or "maxf(" in rhs or "minf(" in rhs))
            events.append((path, "monotonic" if monotonic else "write"))
        for path in rhs_paths:
            if not any(path_matches(path, target) for target in lhs_paths):
                events.append((path, "read"))
        binding = _binding(statement)
        if binding:
            name = binding.group("name")
            bound_paths = access_chains(binding.group("rhs"), aliases, constants)
            string_value = _string_binding(binding.group("rhs"))
            if name in root_aliases:
                aliases[name] = root_aliases[name]
            elif bound_paths:
                aliases[name] = bound_paths[0]
                if name in members:
                    previous = member_aliases.get(name)
                    if previous is not None and previous != bound_paths[0]:
                        raise ValueError(
                            f"ambiguous durable member alias {name}: "
                            f"{'.'.join(previous)} vs {'.'.join(bound_paths[0])}")
                    member_aliases[name] = bound_paths[0]
            else:
                aliases.pop(name, None)
                # Runtime teardown may clear a member after its consumer has
                # run. Static ownership is a set of possible valid bindings,
                # not the final source-order assignment, so a non-state clear
                # cannot erase a binding already proved elsewhere.
            if string_value is not None:
                constants[name] = string_value
            elif name not in class_constants:
                constants.pop(name, None)
        loop_binding = re.match(
            r"^for\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s+in\s+(?P<rhs>.+):$",
            statement)
        if loop_binding:
            bound_paths = access_chains(loop_binding.group("rhs"), aliases, constants)
            if bound_paths:
                aliases[loop_binding.group("name")] = bound_paths[0] + ("*",)
    return events, member_aliases


def numeric_source_events(text: str, root_aliases=None):
    root_aliases = dict(root_aliases or {})
    member_aliases = {}
    for _attempt in range(4):
        before = member_aliases.copy()
        _events, member_aliases = _numeric_source_pass(
            text, root_aliases, member_aliases)
        if member_aliases == before:
            break
    events, _member_aliases = _numeric_source_pass(
        text, root_aliases, member_aliases)
    return events


def logical_statements(text: str):
    """Yield small GDScript statements with multiline calls kept together."""
    pending = []
    depth = 0
    for line in text.splitlines():
        code = line.split("#", 1)[0].strip()
        if not code and not pending:
            continue
        pending.append(code)
        depth += sum(code.count(char) for char in "([{")
        depth -= sum(code.count(char) for char in ")]}")
        if depth <= 0:
            yield " ".join(part for part in pending if part)
            pending = []
            depth = 0
    if pending:
        yield " ".join(part for part in pending if part)


def numeric_state_records(texts, numeric):
    records = []
    state_file = "game/scripts/game/reality_game_state.gd"
    events = []
    for source, text in texts.items():
        root_aliases = {"data": ()} if source.as_posix().endswith(
            "/game/reality_game_state.gd") else {}
        events.extend((source, path, kind)
                      for path, kind in numeric_source_events(text, root_aliases))
    for path, _default in sorted(numeric.items()):
        display = ".".join(path)
        matching = [(source, kind) for source, accessed, kind in events
                    if path_matches(path, accessed)]
        if not matching:
            records.append({"kind": "DURABLE_NUMERIC_UNREAD", "file": state_file,
                            "field": display,
                            "detail": "zero production readers or writers",
                            "excepted": False})
            continue
        kinds = {kind for _source, kind in matching}
        if "read" not in kinds and "monotonic" in kinds:
            records.append({"kind": "DURABLE_NUMERIC_MONOTONIC_ONLY",
                            "file": state_file, "field": display,
                            "detail": "only self-feedback in monotonic writes",
                            "excepted": False})
        elif "read" not in kinds and "write" in kinds:
            records.append({"kind": "DURABLE_NUMERIC_UNREAD",
                            "file": state_file, "field": display,
                            "detail": "written but never read by production",
                            "excepted": False})
    return records


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
    # Recursive: game/data/ has subdirectories (songbook/), and PATH_RE
    # already accepts a nested res://data/<dir>/<file>.json reference, so a
    # flat glob silently passed every file the loader could legitimately name.
    for path in sorted(data_root.rglob("*.json")):
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
    numeric = durable_numeric_defaults(state_text)
    records.extend(numeric_state_records(texts, numeric))
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
