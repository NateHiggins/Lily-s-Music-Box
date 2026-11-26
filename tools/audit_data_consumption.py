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
import ast
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

TOOL_VERSION = 5
DEFAULT_EXCEPTIONS = "tools/data_consumption_exceptions.json"
DEFAULT_BASELINE = "tools/data_consumption_baseline.json"
BASELINE_SCHEMA = "orison.data-consumption-baseline.v1"
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

# These containers are schema-declared identity maps: their keys are authored
# record identities, not independently consumable schema fields.  Their values
# are still traversed, so a new field inside an alias target remains visible to
# the audit.  Keep this closed over explicit schema identities; an unfamiliar
# document or container continues to fail conservatively.
DYNAMIC_MAP_PATHS_BY_SCHEMA = {
    # Paths identify exact hash witnesses; runtime enforces the full path set
    # and reads each binding's kind/sha256. Unknown value fields stay audited.
    "orison.v2.arcade-cobbler-field.v1": frozenset({"source_bindings"}),
    "orison.floor01.cell-registry.v1": frozenset({
        "compatibility_alias_index",
        "semantic_owner_index",
    }),
}


# Existing catalogs without a unique schema string need an exact game/data
# relative path, never a basename or a globally recognized container name.
# These declarations classify record identities only. They grant neither a
# FILE reader nor a reader for any field in a record value.
DYNAMIC_MAP_PATHS_BY_FILE = {
    # Entry material/stock IDs are resolved by the actual native/retirement owners.
    # Descendant value fields and FILE_UNREAD remain independently audited.
    'orison_v2/harukiya_entry.json': frozenset({'materials'}),
    'orison_v2/harukiya_entry_retirement.json': frozenset({'retirement[].owners', 'stock_counts', 'stock_counts[]'}),
    # Reviewed Harukiya native record IDs; value fields remain audited.
    'orison_v2/harukiya_destination_layout.json': frozenset({'materials'}),
    'orison_v2/harukiya_destination_retirement.json': frozenset({'retirement[].owners', 'stock_counts', 'stock_counts[]'}),
    'orison_v2/harukiya_drumkit.json': frozenset({'contacts', 'pivots'}),
    # CastMaterialRecipes.validate resolves imported cast_<person>_* identities
    # through _recipes[key]. This declares only root record IDs; every recipe
    # value (base_color, roughness, metallic, etc.) still needs a real reader.
    "material_catalog.json": frozenset({""}),
    # OrisonAudioPolicy._load_catalog iterates cues[cue_id]; values still
    # require readers for bus, stream_key, limits, captions and every new field.
    "audio_cues.json": frozenset({"cues"}),
    # Readable library cache resolves authored stock/finish/plate identities;
    # record values still need ordinary production field readers.
    "orison_v2/readable_library.json": frozenset({"parts", "books", "cases", "bookends", "finishes", "illustrations", "page_designs", "formats", "publishers", "publication_layouts", "decorations"}),
    "orison_v2/nook_readable_books.json": frozenset({"books", "parts"}),
    "orison_v2/book_spreads.json": frozenset({"spreads"}),
    # FunctionalProp._ready: _catalog.get(prop_type).
    "prop_catalog.json": frozenset({""}),
    # RealityCaseManager/RealityRuleDirector: definitions.get(case_id).
    "reality_cases.json": frozenset({""}),
    "reality_rules.json": frozenset({""}),
    # OrisonMusicDirector: tracks[track_id], residents.get(resident_id).
    "music_catalog.json": frozenset({"tracks", "residents"}),
    # ScheduleDirector: data.residents[raw_slug], and the staff it also clocks.
    "resident_schedules.json": frozenset({"residents", "staff"}),
    # MaintenanceActivityLibrary: authored[activity_id].
    "maintenance_activities.json": frozenset({"activities"}),
    # OrisonV2UpperFloorDoors: source.doors[identity].
    "orison_v2/upper_floor_programs.json": frozenset({"doors"}),
    # ResidentAgenda: needs/activities/places/residents keyed by need,
    # activity, place and resident; each value's fields are read by name.
    "resident_motives.json": frozenset({"needs", "activities", "activities[]", "places", "places[]",
                                        "residents", "residents[].shadow[].needs",
                                        "residents[].growth[].needs"}),
    # KitchenLarder/CookbookPanel: shops, ingredients and icebox looks keyed
    # by id; household recipes keyed by ingredient. Record fields read by name.
    "kitchen/groceries.json": frozenset({"shops", "ingredients", "icebox_looks", "pantry_looks", "pantry_shapes", "household.lighting",
                                         "household.washing_up", "household.plain_supper"}),
    # OrisonV2MinaRoutine: places.get(destination).
    "orison_v2/mina_routine.json": frozenset({"places"}),
    # OrisonV2ResidentRoute: the same route schema for each walking resident.
    "orison_v2/lena_routine.json": frozenset({"places"}),
    "orison_v2/sacha_reed_routine.json": frozenset({"places"}),
    "orison_v2/evelyn_marsh_routine.json": frozenset({"places"}),
    "orison_v2/rhea_sato_routine.json": frozenset({"places"}),
    "orison_v2/transient_guests_routine.json": frozenset({"places"}),
    "orison_v2/juno_kells_routine.json": frozenset({"places"}),
    "orison_v2/nadia_quell_routine.json": frozenset({"places"}),
    "orison_v2/cal_dwyer_routine.json": frozenset({"places"}),
    "orison_v2/cam_ortiz_routine.json": frozenset({"places"}),
    "orison_v2/iris_bell_routine.json": frozenset({"places"}),
    "orison_v2/jonah_price_routine.json": frozenset({"places"}),
    "orison_v2/mae_kessler_routine.json": frozenset({"places"}),
    "orison_v2/malcolm_reed_routine.json": frozenset({"places"}),
    "orison_v2/noel_price_routine.json": frozenset({"places"}),
    "orison_v2/omar_bell_routine.json": frozenset({"places"}),
    "orison_v2/peter_wren_routine.json": frozenset({"places"}),
    "orison_v2/teresa_vale_routine.json": frozenset({"places"}),
    # ResidentConversations/CaseDialoguePanel: nodes[node_id] by authored id;
    # every record field (line, role, choices, silence_goto, flag...) is read by name.
    # Field notes are keyed by note id; the director reads each note's fields.
    "field_notes.json": frozenset({"notes"}),
    # The daily papers: papers keyed by id; every issue field is read by the
    # catalogue's validator and printed by the panel.
    "newspapers/papers.json": frozenset({"papers"}),
    # The advertising book: firms keyed by name, read by NewspaperAd.
    "newspapers/advertisements.json": frozenset({"firms"}),
    # The mystery threads: nodes and entries keyed by id, read by ResidentConversations.
    "mystery/adela_voss.json": frozenset({"entries", "nodes"}),
    "mystery/cal_dwyer.json": frozenset({"entries", "nodes"}),
    "mystery/cam_ortiz.json": frozenset({"entries", "nodes"}),
    "mystery/emil_voss.json": frozenset({"entries", "nodes"}),
    "mystery/evelyn_marsh.json": frozenset({"entries", "nodes"}),
    "mystery/h_vantry.json": frozenset({"entries", "nodes"}),
    "mystery/iris_bell.json": frozenset({"entries", "nodes"}),
    "mystery/jonah_price.json": frozenset({"entries", "nodes"}),
    "mystery/juno_kells.json": frozenset({"entries", "nodes"}),
    "mystery/lena_ortiz.json": frozenset({"entries", "nodes"}),
    "mystery/lily.json": frozenset({"entries", "nodes"}),
    "mystery/mae_kessler.json": frozenset({"entries", "nodes"}),
    "mystery/malcolm_reed.json": frozenset({"entries", "nodes"}),
    "mystery/mina_vale.json": frozenset({"entries", "nodes"}),
    "mystery/mr_ewald.json": frozenset({"entries", "nodes"}),
    "mystery/nadia_quell.json": frozenset({"entries", "nodes"}),
    "mystery/noel_price.json": frozenset({"entries", "nodes"}),
    "mystery/omar_bell.json": frozenset({"entries", "nodes"}),
    "mystery/patrolman.json": frozenset({"entries", "nodes"}),
    "mystery/peter_wren.json": frozenset({"entries", "nodes"}),
    "mystery/rhea_sato.json": frozenset({"entries", "nodes"}),
    "mystery/sacha_reed.json": frozenset({"entries", "nodes"}),
    "mystery/stacy.json": frozenset({"entries", "nodes"}),
    # Lily and Stacy name their parts per outfit: person, then outfit, both read by key (WardrobeRules.parts_for).
    "characters/wardrobe_rules.json": frozenset({"person_looks", "person_looks[]"}),
    # MoodReading indexes cue and gesture maps by feeling, punctuation by
    # mark, and temperament by trait. _apply iterates the nested score maps.
    "characters/mood_reading.json": frozenset({
        "subject_cues", "punctuation", "punctuation[]", "traits", "traits[]",
        "trust.warm", "trust.cold", "choice.trust_gained", "choice.trust_lost",
        "choice.inferred", "choice.evidence", "emote.clips",
    }),
    "mystery/teresa_vale.json": frozenset({"entries", "nodes"}),
    "mystery/the_party.json": frozenset({"entries", "nodes"}),
    "mystery/transient_guests.json": frozenset({"entries", "nodes"}),
    "mystery/carriers.json": frozenset({"carriers"}),
    "mystery/companion_mystery.json": frozenset({"surfaces"}),
    # Shop catalogues: stock groups keyed by id, read by ShopCatalogue and ShopStock.
    # V1 sets rebuilt for V2: placements keyed by catalogue prop id and by
    # case id, clock styles keyed by style. The composers read each record's fields.
    "orison_v2/case_prop_placements.json": frozenset({"props"}),
    "orison_v2/witness_clock_placements.json": frozenset({"witness"}),
    "orison_v2/witness_clocks.json": frozenset({"styles"}),
    # The temporal loop: anchors and deductions keyed by id, read by temporal_loop.gd.
    "temporal/anchors.json": frozenset({"anchors", "deductions"}),
    # LoopPerformances indexes profiles by resident and phases by anchor/resident.
    # Only those identity keys are dynamic; every profile/phase field is audited.
    "temporal/performances.json": frozenset({"profiles", "anchors", "anchors[].actors"}),
    "carried_case.json": frozenset({"forms"}),
    "shops/bodega.json": frozenset({"groups"}),
    "shops/funeral_parlour.json": frozenset({"groups"}),
    "shops/hardware_paint.json": frozenset({"groups"}),
    "shops/harukiya.json": frozenset({"groups"}),
    "shops/keys_cut.json": frozenset({"groups"}),
    "shops/luncheonette.json": frozenset({"groups"}),
    "shops/model_laundry.json": frozenset({"groups"}),
    "shops/news_cigars.json": frozenset({"groups"}),
    "shops/otis_son.json": frozenset({"groups"}),
    "shops/pawnbroker.json": frozenset({"groups"}),
    "shops/photo_supplies.json": frozenset({"groups"}),
    "shops/radio_service.json": frozenset({"groups"}),
    "shops/shoe_rebuilding.json": frozenset({"groups"}),
    "opinions/cal_dwyer.json": frozenset(), "opinions/cam_ortiz.json": frozenset(),
    "opinions/evelyn_marsh.json": frozenset(), "opinions/iris_bell.json": frozenset(),
    "opinions/jonah_price.json": frozenset(), "opinions/juno_kells.json": frozenset(),
    "opinions/lena_ortiz.json": frozenset(), "opinions/mae_kessler.json": frozenset(),
    "opinions/malcolm_reed.json": frozenset(), "opinions/nadia_quell.json": frozenset(),
    "opinions/noel_price.json": frozenset(), "opinions/omar_bell.json": frozenset(),
    "opinions/peter_wren.json": frozenset(), "opinions/rhea_sato.json": frozenset(),
    "opinions/sacha_reed.json": frozenset(), "opinions/stacy.json": frozenset(),
    "opinions/teresa_vale.json": frozenset(),
    "opinions/transient_guests.json": frozenset(),
    "dialogue/cal_dwyer.json": frozenset({"nodes"}),
    "dialogue/cam_ortiz.json": frozenset({"nodes"}),
    "dialogue/evelyn_marsh.json": frozenset({"nodes"}),
    "dialogue/iris_bell.json": frozenset({"nodes"}),
    "dialogue/jonah_price.json": frozenset({"nodes"}),
    "dialogue/juno_kells.json": frozenset({"nodes"}),
    "dialogue/lena_ortiz.json": frozenset({"nodes"}),
    "dialogue/mae_kessler.json": frozenset({"nodes"}),
    "dialogue/malcolm_reed.json": frozenset({"nodes"}),
    "dialogue/nadia_quell.json": frozenset({"nodes"}),
    "dialogue/noel_price.json": frozenset({"nodes"}),
    "dialogue/omar_bell.json": frozenset({"nodes"}),
    "dialogue/peter_wren.json": frozenset({"nodes"}),
    "dialogue/rhea_sato.json": frozenset({"nodes"}),
    "dialogue/sacha_reed.json": frozenset({"nodes"}),
    "dialogue/stacy.json": frozenset({"nodes"}),
    "dialogue/lily.json": frozenset({"nodes"}),
    "dialogue/adela_voss.json": frozenset({"nodes"}),
    "dialogue/teresa_vale.json": frozenset({"nodes"}),
    "dialogue/transient_guests.json": frozenset({"nodes"}),
    # Build-time mirror: finish IDs produced by generate_runtime_materials.py.
    # Its FILE_UNREAD and unread value schema remain reported independently.
    "runtime_material_sets.json": frozenset({"materials"}),
}


def json_fields(value, prefix="", dynamic_map_paths=frozenset()):
    out = Counter()
    if isinstance(value, dict):
        if prefix in dynamic_map_paths:
            for child in value.values():
                out.update(json_fields(
                    child, prefix + "[]", dynamic_map_paths))
            return out
        for key, child in value.items():
            path = f"{prefix}.{key}" if prefix else key
            out[path] += 1
            out.update(json_fields(child, path, dynamic_map_paths))
    elif isinstance(value, list):
        for child in value:
            out.update(json_fields(child, prefix + "[]", dynamic_map_paths))
    return out


def data_json_fields(value, rel_data=None):
    schema = value.get("schema") if isinstance(value, dict) else None
    dynamic_map_paths = DYNAMIC_MAP_PATHS_BY_SCHEMA.get(
        schema, frozenset()) | DYNAMIC_MAP_PATHS_BY_FILE.get(
        rel_data, frozenset())
    return json_fields(value, dynamic_map_paths=dynamic_map_paths)


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


def binding_access_paths(rhs: str, aliases, constants):
    """Only a direct state expression establishes a durable alias.

    State passed to a constructor is read, but its returned value is not an
    alias to that argument. General reads still use access_chains separately.
    """
    expression = rhs.strip()
    direct = re.match(r"RealityState\.data\b", expression)
    if not direct:
        direct = any(re.match(rf"{re.escape(name)}\b", expression)
                     for name in aliases)
    return access_chains(expression, aliases, constants) if direct else []


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
            bound_paths = binding_access_paths(binding.group("rhs"), aliases, constants)
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


def _split_call_arguments(text: str):
    """Split a call without mistaking nested calls or literals for arguments."""
    arguments = []
    start = 0
    depth = 0
    strings = _string_spans(text)
    for index, char in enumerate(text):
        if any(lo <= index < hi for lo, hi in strings):
            continue
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        elif char == "," and depth == 0:
            arguments.append(text[start:index].strip())
            start = index + 1
    if text[start:].strip():
        arguments.append(text[start:].strip())
    return arguments


def _script_functions(text: str):
    definitions = list(re.finditer(
        r"^(?:static\s+)?func\s+(\w+)\s*\(([^\n]*)\)[^\n]*:\s*$",
        text, re.MULTILINE))
    functions = {}
    for index, match in enumerate(definitions):
        end = definitions[index + 1].start() if index + 1 < len(definitions) else len(text)
        parameters = [re.match(r"\w+", p).group(0)
                      for p in _split_call_arguments(match.group(2))
                      if re.match(r"\w+", p)]
        functions[match.group(1)] = (parameters, text[match.start():end])
    return functions


def _direct_json_alias(expression: str, aliases, constants):
    expression = expression.strip()
    for name, base in sorted(aliases.items(), key=lambda item: -len(item[0])):
        match = re.match(rf"{re.escape(name)}\b", expression)
        if not match:
            continue
        path, end = _parse_access_tail(expression, match.end(), base, constants)
        if not expression[end:].strip():
            return path
    return None


def _parameter_accesses(text, aliases, constants):
    strings = _string_spans(text)
    for name, base in aliases.items():
        for match in re.finditer(rf"(?<![\w.]){re.escape(name)}\b", text):
            if any(lo <= match.start() < hi for lo, hi in strings):
                continue
            path, _end = _parse_access_tail(text, match.end(), base, constants)
            yield path


def _parameter_reads(body, parameter, origin):
    """Read only local aliases descending from the passed helper parameter."""
    aliases = {parameter: origin}
    constants = {}
    for statement in logical_statements(body):
        if statement.startswith(("func ", "static func ")):
            continue
        assignment = assignment_match(statement)
        rhs = statement[assignment.end():] if assignment else statement
        yield from _parameter_accesses(rhs, aliases, constants)
        binding = _binding(statement)
        if binding:
            name, expression = binding.group("name"), binding.group("rhs")
            bound = _direct_json_alias(expression, aliases, constants)
            if bound:
                aliases[name] = bound
            else:
                aliases.pop(name, None)
            literal = _string_binding(expression)
            if literal is not None:
                constants[name] = literal
            else:
                constants.pop(name, None)
        loop = re.match(r"^for\s+(\w+)(?:\s*:\s*\w+)?\s+in\s+(.+):$", statement)
        if loop:
            bound = _direct_json_alias(loop.group(2), aliases, constants)
            if bound:
                aliases[loop.group(1)] = bound + ("*",)
            else:
                aliases.pop(loop.group(1), None)


def inherited_parameter_reads(root: Path, texts):
    """Follow one direct argument into a method in the literal base chain.

    Only an actual JSON parse creates file identity. A direct alias or array
    item can reach a non-overridden inherited method, where reads must descend
    from its matching parameter. Constructors, general return values, unrelated
    dictionaries and entire base-file token lists grant no credit.
    """
    reads = {}
    for caller, text in texts.items():
        parent = re.search(r'^extends\s+["\']res://(scripts/[^"\']+\.gd)["\']',
                           text, re.MULTILINE)
        if not parent:
            continue
        parent_path = root / "game" / parent.group(1)
        if parent_path not in texts:
            continue
        methods = {}
        visited = {caller}
        # Resolve the nearest implementation, including intermediate overrides.
        # Cycles and bases outside the scanned production sources stop traversal.
        while parent_path in texts and parent_path not in visited:
            visited.add(parent_path)
            base_text = texts[parent_path]
            for name, definition in _script_functions(base_text).items():
                methods.setdefault(name, definition)
            ancestor = re.search(r'^extends\s+["\']res://(scripts/[^"\']+\.gd)["\']',
                                 base_text, re.MULTILINE)
            if not ancestor:
                break
            parent_path = root / "game" / ancestor.group(1)
        overrides = _script_functions(text)
        class_constants, _numbers = source_constants("\n".join(
            line for line in text.splitlines() if not line[:1].isspace()))
        constants = class_constants.copy()
        aliases = {}
        for statement in logical_statements(text):
            if statement.startswith(("func ", "static func ")):
                aliases = {}
                constants = class_constants.copy()
                continue
            binding = _binding(statement)
            if binding:
                name, rhs = binding.group("name"), binding.group("rhs")
                parsed = re.fullmatch(
                    r"JSON\.parse_string\(\s*FileAccess\.get_file_as_string\((.*?)\)\s*\)",
                    rhs.strip())
                source = None
                if parsed:
                    argument = parsed.group(1).strip()
                    value = constants.get(argument, _string_binding(argument))
                    source = PATH_RE.fullmatch(value) if isinstance(value, str) else None
                bound = (source.group(1),) if source else _direct_json_alias(rhs, aliases, constants)
                if bound:
                    aliases[name] = bound
                else:
                    aliases.pop(name, None)
                literal = _string_binding(rhs)
                if literal is not None:
                    constants[name] = literal
                else:
                    constants.pop(name, None)
            loop = re.match(r"^for\s+(\w+)(?:\s*:\s*\w+)?\s+in\s+(.+):$", statement)
            if loop:
                bound = _direct_json_alias(loop.group(2), aliases, constants)
                if bound:
                    aliases[loop.group(1)] = bound + ("*",)
                else:
                    aliases.pop(loop.group(1), None)
            strings = _string_spans(statement)
            for call in re.finditer(r"(?<![\w.])(\w+)\s*\(", statement):
                if any(lo <= call.start() < hi for lo, hi in strings):
                    continue
                name = call.group(1)
                if name not in methods or name in overrides:
                    continue
                opening = statement.find("(", call.start())
                closing = _matching_close(statement, opening, "(", ")")
                if closing < 0:
                    continue
                parameters, body = methods[name]
                arguments = _split_call_arguments(statement[opening + 1:closing])
                for parameter, argument in zip(parameters, arguments):
                    bound = _direct_json_alias(argument, aliases, constants)
                    if not bound:
                        continue
                    for path in _parameter_reads(body, parameter, bound):
                        if len(path) > 1:
                            reads.setdefault(path[0], set()).add(path[1:])
    return reads


# Reviewed proof of FULL source-record consumption, not an unread-field waiver.
# The guard compares both entry documents, then every complete record against
# the actual F01 furniture row. Binding its caller path prevents a comparison
# against a fabricated layout from receiving the same credit. Only the prefix
# through mounting is bound; later lighting/actors in _ready are out of scope.
ENTRY_RECORD_CONTRACT = (
    ("game/scripts/building/harukiya_entry_retirement.gd", "apply",
     "\tif FileAccess.get_file_as_string(CELL)",
     "f7de39c4c4c7b3309fe92fe9f9cc4ff4ae75cf7f8f461539dbc2ab5c94a13b51"),
    ("game/scripts/building/orison_v2_bar_region.gd", "_ready",
     "\tadd_child(geometry)",
     "38923c298f01e5592082480cee25b61d5124d2dad10dfc5638e9ed4432a8a02c"),
    ("game/scripts/building/orison_v2_bar_entry.gd", "mount_cell", None,
     "cee850f6eb70bb8750610459e03d68607eb07582a51eff11d745667507797808"),
    ("game/scripts/building/harukiya_entry_retirement.gd", "_fail", None,
     "6270851d4b0c56f76b0ba2e344bde84d7b110546473518d924609c9a7265254d"),
)
ENTRY_RECORD_CONSTANTS = {
    "game/scripts/building/harukiya_entry_retirement.gd": {
        "DATA": '"res://data/orison_v2/harukiya_entry_retirement.json"',
        "ENTRY_DATA": '"res://data/orison_v2/harukiya_entry.json"',
    },
    "game/scripts/building/orison_v2_bar_region.gd": {
        "LAYOUT": '"res://data/building_layout.json"',
        "Entry": 'preload("res://scripts/building/orison_v2_bar_entry.gd")',
    },
    "game/scripts/building/orison_v2_bar_entry.gd": {
        "Retirement": 'preload("res://scripts/building/harukiya_entry_retirement.gd")',
    },
}


def entry_whole_record_paths(root: Path, texts):
    """Fail closed unless the reviewed comparator and authoritative lineage match.

    Digests cover function/prefix source including indentation and comments.
    Only CRLF, trailing line whitespace and outer blank lines are normalized.
    Refactors require explicit re-review, never automatic digest refresh.
    This is a bounded source contract, not a general GDScript verifier.
    """
    for relative, constants in ENTRY_RECORD_CONSTANTS.items():
        text = texts.get(root / relative)
        if text is None:
            return {}
        for name, expression in constants.items():
            declarations = re.findall(
                rf'^const\s+{re.escape(name)}\s*:=\s*(.*?)\s*$', text, re.MULTILINE)
            if declarations != [expression]:
                return {}
    for relative, method, stop, expected in ENTRY_RECORD_CONTRACT:
        text = texts.get(root / relative)
        if text is None:
            return {}
        definition = _script_functions(text).get(method)
        if definition is None:
            return {}
        body = definition[1]
        if stop is not None:
            if body.count(stop) != 1:
                return {}
            body = body[:body.index(stop)]
        canonical = "\n".join(line.rstrip() for line in body.replace("\r\n", "\n").splitlines()).strip("\n") + "\n"
        if hashlib.sha256(canonical.encode("utf-8")).hexdigest() != expected:
            return {}
    return {name: frozenset({"source_records[]"}) for name in (
        "orison_v2/harukiya_entry.json", "orison_v2/harukiya_entry_retirement.json")}


def _expression(source):
    """Accept only the expression syntax GDScript shares with Python. Never execute it."""
    try:
        return ast.parse(source.strip(), mode="eval").body
    except (SyntaxError, ValueError, RecursionError):
        return None


def _member_projection(node, origins):
    """Follow a data value through property, subscript and Dictionary.get reads."""
    if isinstance(node, ast.Name):
        return origins.get(node.id)
    if isinstance(node, ast.Attribute):
        if isinstance(node.value, ast.Name):
            direct = origins.get(f"{node.value.id}.{node.attr}")
            if direct:
                return direct
        base = _member_projection(node.value, origins)
        return base + (node.attr,) if base else None
    if isinstance(node, ast.Subscript) and not isinstance(node.slice, ast.Slice):
        container, key = node.value, node.slice
    elif (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
          and node.func.attr == "get" and 1 <= len(node.args) <= 2 and not node.keywords):
        container, key = node.func.value, node.args[0]
    else:
        return None
    base = _member_projection(container, origins)
    if base:
        part = None
        if isinstance(key, ast.Constant):
            if isinstance(key.value, str) or (isinstance(node, ast.Subscript) and type(key.value) is int):
                part = key.value
            else:
                return None
        return base + (part,)
    return None


def _file_identity(argument, constants):
    value = constants.get(argument, _string_binding(argument))
    match = PATH_RE.fullmatch(value) if isinstance(value, str) else None
    return (match.group(1),) if match else None


def _simple_member_scopes(text):
    # The small function scanner handles single-line, named signatures. An
    # unknown scope can introduce a different binding for any name inside it.
    return (not re.search(r"\bfunc[ \t]*\(", text)
            and all(re.search(r"\)[^#]*:\s*(?:#.*)?$", line)
                    for line in text.splitlines() if re.match(r"^(?:static )?func ", line)))


def _changes_collection(text, qualified):
    # Mutating an exported value breaks the chain even when the reference
    # itself is stable. A read on the right of an assignment is still valid.
    target = re.escape(qualified)
    return re.search(
        rf"(?m)^[ \t]*(?:self\.)?{target}\b"
        r"(?:[ \t]*(?:\[[^\n]+?\]|\.\w+))+[ \t]*(?:[+*/%-]?=(?!=))"
        rf"|\b{target}\.(?:assign|merge|fill|insert|set|append|append_array|push_back|push_front|resize)\s*\(",
        text)


def _exported_data_members(text):
    """Find single-writer members obtained from a JSON parse or another such member."""
    members = _member_names(text)
    constants, _ = source_constants("\n".join(line for line in text.splitlines()
                                              if not line[:1].isspace()))
    functions = []
    member_writes = Counter()
    for method, (params, body) in _script_functions(text).items():
        statements = list(logical_statements(body))[1:]
        locals_ = set(params)
        locals_.update(re.findall(r"^\s*(?:var|const|for)\s+(\w+)", body, re.MULTILINE))
        assignments = []
        for statement in statements:
            binding = _binding(statement.removeprefix("self."))
            if not binding:
                continue
            name, rhs = binding.group("name", "rhs")
            writes_member = name in members and (name not in locals_ or statement.startswith("self."))
            if writes_member:
                member_writes[name] += 1
            assignments.append((name, rhs, writes_member))
        functions.append((method, assignments, locals_))

    known = {}
    # Pass one traces the file into its loaded collection. Pass two can trace
    # a dealt card, for example, back through that collection in another method.
    for _ in range(2):
        discovered = {}
        for method, assignments, locals_ in functions:
            visible_constants = {k: v for k, v in constants.items() if k not in locals_}
            origins = {k: v for k, v in known.items() if k not in locals_}
            origins.update({f"self.{k}": v for k, v in known.items()})
            handles = {}
            writes = Counter(name for name, _, _ in assignments)
            for name, rhs, member in assignments:
                if (writes[name] != 1 or (member and member_writes[name] != 1)
                        or _changes_collection(text, name)):
                    continue
                opened = re.fullmatch(r"FileAccess\.open\(\s*(.+?)\s*,\s*FileAccess\.READ\s*\)", rhs)
                if opened:
                    handles[name] = _file_identity(opened[1], visible_constants)
                    continue
                parsed = re.fullmatch(r"JSON\.parse_string\(\s*(\w+)\.get_as_text\(\)\s*\)", rhs)
                direct = re.fullmatch(
                    r"JSON\.parse_string\(\s*FileAccess\.get_file_as_string\(\s*(.+?)\s*\)\s*\)", rhs)
                if parsed:
                    origin = handles.get(parsed[1])
                elif direct:
                    origin = _file_identity(direct[1], visible_constants)
                else:
                    origin = _member_projection(_expression(rhs), origins)
                if origin and (parsed or direct):
                    origin = (frozenset(), *origin)
                if origin:
                    if member:
                        origin = (origin[0] | {method}, *origin[1:])
                        discovered[name] = origin
                    origins[name] = origin
        known.update(discovered)
    return known


def constructed_member_reads(texts):
    """Prove reads on a specific, directly constructed production class instance."""
    classes = defaultdict(list)
    consumers = []
    ctor = re.compile(r"^var\s+(\w+)(?:\s*:\s*\w+)?\s*:?=\s*(\w+)\.new\(\)\s*(?:#.*)?$", re.MULTILINE)
    for text in texts.values():
        # Multiline literals can contain text that looks like top-level code.
        if '"""' in text or "'''" in text:
            continue
        declaration = re.search(r"^class_name\s+(\w+)\b", text, re.MULTILINE)
        if declaration:
            classes[declaration[1]].append(text)
        if instances := ctor.findall(text):
            consumers.append((text, instances))

    used_types = {kind for _, instances in consumers for _, kind in instances}
    exports = {kind: _exported_data_members(bodies[0]) for kind, bodies in classes.items()
               if kind in used_types and len(bodies) == 1 and "JSON.parse_string" in bodies[0]
               and "res://data/" in bodies[0] and _simple_member_scopes(bodies[0])}
    reads = defaultdict(set)
    for text, instances in consumers:
        for receiver, kind in instances:
            fields = exports.get(kind)
            if not fields or re.search(rf"^(?:const|class|var)\s+{kind}\b", text, re.MULTILINE):
                continue
            # A reassigned receiver or a shadow has no unique source here.
            if (re.search(rf"^[ \t]+(?:(?:var|const|for)\s+{receiver}\b|(?:self\.)?{receiver}\s*=(?!=))",
                          text, re.MULTILINE) or _changes_collection(text, receiver)):
                continue
            origins = {f"{receiver}.{key}": path for key, path in fields.items()}
            calls = {"_init"}
            candidates = set()
            # Split at every function, including signatures our scanner cannot
            # parse. Their statements must not leak into the preceding scope.
            for body in re.split(r"(?=^(?:static )?func )", text, flags=re.MULTILINE)[1:]:
                if not _simple_member_scopes(body):
                    continue
                definition = _script_functions(body)
                if not definition:
                    continue
                parameters, _ = next(iter(definition.values()))
                if receiver in parameters or f"{receiver}." not in body:
                    continue
                for statement in logical_statements(body):
                    if f"{receiver}." not in statement:
                        continue
                    assignment = assignment_match(statement)
                    rhs = statement[assignment.end():] if assignment else statement.removeprefix("return ")
                    expression = _expression(rhs)
                    if expression is None:
                        continue
                    nodes = list(ast.walk(expression))
                    callees = {node.func for node in nodes if isinstance(node, ast.Call)}
                    calls.update(func.attr for func in callees if isinstance(func, ast.Attribute)
                                 and isinstance(func.value, ast.Name) and func.value.id == receiver)
                    for node in nodes:
                        # The terminal key must be named by the consumer. A
                        # lookup by variable cannot credit every key in a map.
                        if node in callees:
                            continue
                        path = _member_projection(node, origins)
                        if path and len(path) > 2 and isinstance(path[-1], str):
                            candidates.add(path)
            for required, data_file, *keys in candidates:
                if required <= calls:
                    reads[data_file].add(tuple(keys))
    return reads


def _autoload_map_getters(owner):
    """Resolve a single-key getter for an unchanged, startup-loaded dictionary."""
    if ("JSON.parse_string" not in owner or '"""' in owner or "'''" in owner
            or re.search(r"^class\s|\bfunc[ \t]*\(", owner, re.MULTILINE)):
        return {}
    methods = re.split(r"(?=^(?:static )?func )", owner, flags=re.MULTILINE)
    ready = [body for body in methods[1:] if re.match(r"func _ready\(\s*\)", body)]
    if len(ready) != 1 or not _simple_member_scopes(ready[0]):
        return {}
    # Other methods may have multiline headers. Only _ready establishes
    # origin; check writes across the whole script before using that origin.
    members = _exported_data_members(methods[0] + ready[0])
    getters = {}
    for body in methods[1:]:
        statements = list(logical_statements(body))
        if len(statements) != 2:
            continue
        header = re.fullmatch(r"func (\w+)\((\w+)(?:\s*:\s*String)?\)\s*->\s*Dictionary:", statements[0])
        if not header:
            continue
        method, argument = header.groups()
        returned = re.fullmatch(
            rf"return (?:self\.)?(\w+)\.get\(\s*{argument}\s*,\s*\{{\s*\}}\s*\)", statements[1])
        if not returned:
            continue
        member = returned[1]
        origin = members.get(member)
        writes = re.findall(rf"^[ \t]+(?:self\.)?{member}\s*[-+*/%:]?=(?!=)", owner, re.MULTILINE)
        if (member == argument or not origin or origin[0] != {"_ready"}
                or len(writes) != 1 or _changes_collection(owner, member)):
            continue
        # A nonempty initial member could supply records independently of the JSON.
        if re.search(rf"^var {member}(?:\s*:\s*Dictionary)?\s*:?=\s*\{{\s*\}}\s*$", owner, re.MULTILINE):
            getters[method] = (member, origin)
    return getters


def _loop_statements(lines, index):
    """Statements in this loop only, stopping at an unconditional direct exit."""
    indent = len(lines[index]) - len(lines[index].lstrip())
    children = []
    body_indent = None
    for child in lines[index + 1:]:
        if not child.strip() or child.lstrip().startswith("#"):
            continue
        child_indent = len(child) - len(child.lstrip())
        if child_indent <= indent:
            break
        if body_indent is None:
            body_indent = child_indent
        children.append(child)
        if child_indent == body_indent and re.match(r"(?:break|continue|return)\b", child.lstrip()):
            break
    return "\n".join(children)


def _configured_row_fields(root, texts, child, method):
    """An explicit one-argument super forward reaches the actual literal base."""
    receiver = texts.get(root / "game" / child, "")
    parent = re.search(r'^extends\s+["\x27]res://(scripts/[\w./-]+\.gd)["\x27]$', receiver, re.MULTILINE)
    if not parent:
        return ()
    base = texts.get(root / "game" / parent[1], "")
    if any('"""' in text or "'''" in text for text in (receiver, base)):
        return ()
    for is_forwarder, text in ((True, receiver), (False, base)):
        # Split even at unsupported headers, so another function's statements
        # cannot accidentally become evidence for this method.
        bodies = [b for b in re.split(r"(?=^(?:static )?func )", text, flags=re.MULTILINE)
                  if re.match(rf"func {method}\(", b)]
        if len(bodies) != 1 or not _simple_member_scopes(bodies[0]):
            return ()
        lines = bodies[0].expandtabs(4).splitlines()
        body = _loop_statements(lines, 0)
        statements = list(logical_statements(lines[0] + "\n" + body))
        signature = re.fullmatch(rf"func {method}\((\w+)\s*:\s*Dictionary\)\s*->\s*void:", statements[0])
        if not signature:
            return ()
        arg = signature[1]
        if re.search(rf"(?m)^\s*(?:(?:var|for|const)\s+{arg}\b|{arg}\s*=(?!=))", body) or _changes_collection(body, arg):
            return ()
        if is_forwarder and (len(statements) < 2 or statements[1] != f"super.{method}({arg})"):
            return ()
    return {path[0] for path in _parameter_reads(body, arg, ())
            if len(path) == 1 and path[0].isidentifier()}


def collaborator_parameter_reads(root, texts):
    """Find potential field reads of a source array row passed to a fresh local collaborator."""
    reads = defaultdict(lambda: defaultdict(set))
    for text in texts.values():
        if ("JSON.parse_string" not in text or '.new()' not in text
                or '"""' in text or "'''" in text):
            continue
        preloads = dict(re.findall(
            r'^const (\w+)\s*:?=\s*preload\("res://(scripts/[\w./-]+\.gd)"\)\s*$', text, re.MULTILINE))
        if not preloads:
            continue
        constants, _ = source_constants("\n".join(s for s in text.splitlines() if not s[:1].isspace()))
        for body in re.split(r"(?=^(?:static )?func )", text, flags=re.MULTILINE)[1:]:
            if 'JSON.parse_string' not in body or not _simple_member_scopes(body):
                continue
            function = _script_functions(body)
            if not function:
                continue
            locals_ = set(next(iter(function.values()))[0])
            locals_.update(re.findall(r"^\s*(?:var|const|for)\s+(\w+)", body, re.MULTILINE))
            visible = {k: v for k, v in constants.items() if k not in locals_}
            lines = _loop_statements(body.expandtabs(4).splitlines(), 0).splitlines()
            if not lines:
                continue
            function_indent = len(lines[0]) - len(lines[0].lstrip())
            origins = {}
            for i, line in enumerate(lines):
                statement = line.partition("#")[0].strip()
                binding = _binding(statement)
                if binding:
                    name, rhs = binding.group("name", "rhs")
                    source = re.fullmatch(r"JSON\.parse_string\(FileAccess\.get_file_as_string\(([^()]+)\)\)", rhs)
                    if (source and len(line) - len(line.lstrip()) == function_indent
                            and statement.startswith("var ") and not _changes_collection(body, name)
                            and len(re.findall(rf"(?m)^\s*(?:var\s+)?{name}(?:\s*:\s*\w+)?\s*:?=(?!=)", body)) == 1):
                        origins[name] = _file_identity(source[1], visible)
                loop = re.fullmatch(r"for (\w+)\s*:\s*Dictionary in (\w+)(?:\.(\w+)|\.get\(\"(\w+)\",\s*\[\]\)):", statement)
                if not loop or not origins.get(loop[2]):
                    continue
                row, container = loop[1], loop[3] or loop[4]
                block = _loop_statements(lines, i)
                if (re.search(rf"(?m)^\s*(?:(?:var|const|for)\s+{row}\b|{row}\s*=(?!=))", block)
                        or _changes_collection(block, row) or re.search(rf"\b{row}\.(?:erase|clear|get_or_add)\(", block)):
                    continue
                if not block:
                    continue
                indent = len(block) - len(block.lstrip())
                for ctor in re.finditer(rf"(?m)^ {{{indent}}}var (\w+)\s*:?=\s*(\w+)\.new\(\)[ \t]*$", block):
                    local, kind = ctor.groups()
                    if kind not in preloads or kind in locals_:
                        continue
                    if len(re.findall(rf"(?m)^\s*(?:(?:var|const|for)\s+{local}\b|{local}\s*=(?!=))", block)) != 1:
                        continue
                    call_pattern = re.compile(rf"(?m)^[ \t]*{local}\.(\w+)\({row}\)[ \t]*$")
                    for call in call_pattern.finditer(block, ctor.end()):
                        # A bare row escaping earlier could be replaced or
                        # mutated by an unknown collaborator.
                        if re.search(rf"\b{row}\b(?!\s*(?:\.|\[))", block[:call.start()]):
                            continue
                        for field in _configured_row_fields(root, texts, preloads[kind], call[1]):
                            reads[origins[loop[2]][0]][(container, None, field)].add(f"{kind}.{call[1]}")
    return reads


def _getter_loop_fields(text, receiver, method, member):
    """The current key of the getter's own map identifies a real source entry."""
    if (f"{receiver}.{method}(" not in text or '"""' in text or "'''" in text
            or re.search(rf"\b(?:var|const|for|class_name|class)\s+{receiver}\b", text)):
        return
    loop = re.compile(rf"for (\w+)(?:\s*:\s*String)?\s+in\s+{receiver}\.{member}\s*:")
    for body in re.split(r"(?=^(?:static )?func )", text, flags=re.MULTILINE)[1:]:
        if f"{receiver}.{method}(" not in body or not _simple_member_scopes(body):
            continue
        defs = _script_functions(body)
        if not defs or receiver in next(iter(defs.values()))[0]:
            continue
        lines = body.expandtabs(4).splitlines()
        for i, line in enumerate(lines):
            match = loop.fullmatch(line.partition("#")[0].strip())
            if not match:
                continue
            key = match[1]
            block = _loop_statements(lines, i)
            if re.search(rf"(?m)^\s*(?:(?:var|const|for)\s+{key}\b|{key}\s*[-+*/%:]?=(?!=))", block):
                continue
            for statement in logical_statements(block):
                if f"{receiver}.{method}(" not in statement:
                    continue
                assignment = assignment_match(statement)
                rhs = statement[assignment.end():] if assignment else statement.removeprefix("return ")
                if rhs.startswith(("if ", "elif ")) and rhs.endswith(":"):
                    rhs = rhs.split(" ", 1)[1][:-1]
                expr = _expression(rhs)
                if expr is None:
                    continue
                for call in ast.walk(expr):
                    if (isinstance(call, ast.Call) and isinstance(call.func, ast.Attribute)
                            and call.func.attr == "get" and 1 <= len(call.args) <= 2 and not call.keywords
                            and isinstance(call.args[0], ast.Constant) and isinstance(call.args[0].value, str)
                            and ast.unparse(call.func.value) == f"{receiver}.{method}({key})"):
                        yield call.args[0].value


def autoload_getter_reads(root, texts):
    # A syntactic call may sit behind a diagnostic guard, short circuit or
    # early exit. Record a potential read; never mark every entry consumed.
    reads = defaultdict(lambda: defaultdict(set))
    project = root / "game/project.godot"
    if not project.is_file():
        return reads
    config = project.read_text(encoding="utf-8")
    section = re.search(r"(?ms)^\[autoload\][ \t]*\n(.*?)(?=^\[|\Z)", config)
    if not section:
        return reads
    for receiver, path in re.findall(r'^(\w+)\s*=\s*"\*res://(scripts/[\w./-]+\.gd)"\s*$', section[1], re.MULTILINE):
        if len(re.findall(rf"^{receiver}\s*=", section[1], re.MULTILINE)) != 1:
            continue
        owner = texts.get(root / "game" / path, "")
        for method, (member, origin) in _autoload_map_getters(owner).items():
            qualified = f"{receiver}.{member}"
            if any(qualified in text and (re.search(rf"\b{re.escape(qualified)}\s*=(?!=)", text)
                                          or _changes_collection(text, qualified))
                   for text in texts.values()):
                continue
            _, file, *keys = origin
            for text in texts.values():
                for field in _getter_loop_fields(text, receiver, method, member):
                    reads[file][(*keys, None, field)].add(f"{receiver}.{method}")
    return reads


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

    inherited_reads = inherited_parameter_reads(root, texts)
    member_reads = constructed_member_reads(texts)
    getter_reads = autoload_getter_reads(root, texts)
    collaborator_reads = collaborator_parameter_reads(root, texts)
    whole_records = entry_whole_record_paths(root, texts)
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
        fields = data_json_fields(parsed, rel_data)
        # Declared identity-map keys have already been removed above. The
        # existing token-reader rule reports remaining schema leaves per
        # file, retaining their occurrence counts.
        leaves = Counter()
        conditional = set()
        potential_getters = defaultdict(set)
        potential_collaborators = defaultdict(set)
        possible_row_occurrences = Counter()
        for field, occurrences in fields.items():
            # Credit only this exact validated subtree before collapsing leaves.
            # An equally named sibling (e.g. metadata.rect) still needs a reader.
            if any(field.startswith(prefix + ".") for prefix in whole_records.get(rel_data, ())):
                continue
            declared = field.replace("[]", ".[]").strip(".").split(".")
            # A dynamic lookup can select a record from an array or declared
            # identity map. It does not establish every named dictionary key.
            leaf = field.replace("[]", "").rsplit(".", 1)[-1]
            getter_path = tuple(None if segment == "[]" else segment for segment in declared)
            potential_getters[leaf].update(getter_reads.get(rel_data, {}).get(getter_path, ()))
            if callees := collaborator_reads.get(rel_data, {}).get(getter_path):
                potential_collaborators[leaf].update(callees)
                possible_row_occurrences[leaf] += occurrences
            proven = False
            for access in member_reads.get(rel_data, ()):
                if len(declared) != len(access) or access[-1] != leaf:
                    continue
                pairs = list(zip(declared, access))
                if all(key == step or (key == "[]" and (step is None or type(step) is int))
                       for key, step in pairs):
                    proven = True
                    break
                if all(key == step or step is None or (key == "[]" and type(step) is int)
                       for key, step in pairs):
                    conditional.add(leaf)
            if proven:
                continue
            leaves[leaf] += occurrences
        for leaf, occurrences in sorted(leaves.items()):
            field = leaf
            # A same-named token in an unrelated subsystem is not a reader.
            # Field proof must occur in a source that opens this exact file.
            users = sorted(set(token_users.get(leaf, set())) & set(readers))
            # Inherited helper credit is path/parameter-specific, never every
            # token present in the parent script. Preserve the existing leaf
            # reporting format after proving an actual matching JSON path.
            forwarded = any(
                candidate.replace("[]", "").rsplit(".", 1)[-1] == leaf
                and path_matches(tuple(candidate.replace("[]", ".*").strip(".").split(".")),
                                 accessed[:len(candidate.replace("[]", ".*").strip(".").split("."))])
                for candidate in fields for accessed in inherited_reads.get(rel_data, ()))
            key = f"{rel_repo}:{field}"
            field_exception = exceptions.get("fields", {}).get(key)
            if not users and not forwarded:
                detail = ("a consumer reads this field through a dynamic dictionary key; "
                          "the individual named entries are unproven"
                          if leaf in conditional else "zero production token readers")
                if potential_getters.get(leaf):
                    methods = ", ".join(sorted(potential_getters[leaf]))
                    detail = (f"potential read through JSON-backed getter {methods}; "
                              "runtime reachability and individual entry coverage are unproven")
                if potential_collaborators.get(leaf):
                    methods = ", ".join(sorted(potential_collaborators[leaf]))
                    count = possible_row_occurrences[leaf]
                    note = (f"potential source-row parameter read through {methods} "
                            f"({count} source-row occurrences); per-entry runtime coverage is unproven")
                    detail = detail + "; " + note if potential_getters.get(leaf) or leaf in conditional else note
                records.append({"kind": "FIELD_UNREAD", "file": rel_repo,
                                "field": field, "occurrences": occurrences,
                                "detail": field_exception or detail,
                                "excepted": bool(field_exception)})

    state_file = root / "game/scripts/game/reality_game_state.gd"
    state_text = state_file.read_text(encoding="utf-8")
    numeric = durable_numeric_defaults(state_text)
    records.extend(numeric_state_records(texts, numeric))
    return records


def record_key(record: dict) -> str:
    """Stable identity of a finding: kind, file and (for fields) the path.

    Occurrence counts and prose details are deliberately not part of the key,
    so a baseline survives a reader being added elsewhere in the same file.
    """
    return "|".join([record["kind"], record["file"], record.get("field") or ""])


def load_baseline(path: Path) -> set[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or data.get("schema") != BASELINE_SCHEMA or             not isinstance(data.get("records"), list):
        raise ValueError(f"baseline {path} is not {BASELINE_SCHEMA}")
    return {str(key) for key in data["records"]}


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--exceptions", default=DEFAULT_EXCEPTIONS)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--baseline", nargs="?", const=DEFAULT_BASELINE, default=None,
                        help="report-and-fail only on findings absent from this "
                             "frozen baseline (default %s); a baseline is a "
                             "snapshot of known debt, never an exception" % DEFAULT_BASELINE)
    parser.add_argument("--write-baseline", nargs="?", const=DEFAULT_BASELINE, default=None,
                        help="freeze the current non-excepted findings and exit 0")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()

    def rooted(value: str) -> Path:
        path = Path(value)
        return path if path.is_absolute() else root / path

    try:
        records = scan(root, rooted(args.exceptions))
        baseline = load_baseline(rooted(args.baseline)) if args.baseline else None
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"MALFORMED: {exc}", file=sys.stderr)
        return 4
    blockers = [r for r in records if not r.get("excepted")]
    if args.write_baseline:
        target = rooted(args.write_baseline)
        target.write_text(json.dumps({
            "schema": BASELINE_SCHEMA, "tool_version": TOOL_VERSION,
            "note": "Known unread data frozen as a snapshot so new work can be "
                    "held to zero NEW findings. Triage is still owed; a key "
                    "here is debt, not permission.",
            "records": sorted({record_key(r) for r in blockers}),
        }, indent=1) + "\n", encoding="utf-8", newline="\n")
        print(f"wrote {len(blockers)} findings to {target}")
        return 0
    new = blockers if baseline is None else         [r for r in blockers if record_key(r) not in baseline]
    resolved = [] if baseline is None else         sorted(baseline - {record_key(r) for r in blockers})
    payload = {"tool_version": TOOL_VERSION, "records": records,
               "summary": dict(Counter(r["kind"] for r in records)),
               "blocking": len(new)}
    if baseline is not None:
        payload["baseline"] = {"known": len(blockers) - len(new),
                               "new": [record_key(r) for r in new],
                               "resolved": resolved}
    if args.json:
        print(json.dumps(payload, indent=1, sort_keys=True))
    else:
        print("data consumption audit")
        for key, count in sorted(payload["summary"].items()):
            print(f"  {key}: {count}")
        if baseline is not None:
            print(f"  known (in baseline): {len(blockers) - len(new)}")
            print(f"  resolved since baseline: {len(resolved)}")
            print(f"  NEW: {len(new)}")
        else:
            print(f"  blocking: {len(blockers)}")
        for record in new[:80]:
            suffix = f":{record['field']}" if record.get("field") else ""
            print(f"  - {record['kind']} {record['file']}{suffix} ({record['detail']})")
    return 1 if new else 0


if __name__ == "__main__":
    raise SystemExit(main())
