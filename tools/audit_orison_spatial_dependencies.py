#!/usr/bin/env python3
"""ADMIN-ARCH1 spatial dependency audit: what the building accidentally promised.

Source-only audit of every repository dependency on current Orison spatial
identity - room/floor/unit/marker/furniture/socket/vantry ids, generated node
names, hardcoded plan (`GameBoot.b2g`) and Godot (`Vector3`) coordinates,
building node paths, floor asset paths and layout loads - classified by
authority, spatial binding and migration disposition so the architectural
rebuild owner knows what may move freely, what needs a named-anchor migration
and what must stay stable.

This is a HEURISTIC source scan, not GDScript semantic analysis:

  - the identifier universe is built from the authoritative layout JSON
    (art/data/building_layout.json by default): floors, rooms, units
    (meta.residents), markers, furniture, sockets, vantry points,
    ventilation registers, bookshelves, stairs and elevator;
  - consumers are scanned textually: exact quoted-string matches against the
    universe, `b2g(` plan-coordinate calls, `Vector3(` literals whose line
    context suggests a gameplay binding (position/spawn/camera/distance...),
    generated `.name =` templates, node-path lookups that embed spatial
    identity, res:// building asset paths and layout-file loads;
  - `Vector3` literals with no gameplay context (mesh vertices, sizes,
    colors, presentation offsets) are counted in stats but deliberately kept
    OUT of the manifest - see the false-positive policy in ADMIN-ARCH1;
  - string literals that look like layout ids but match nothing in the
    universe are reported as dynamic/stale candidates (UNKNOWN_DYNAMIC or
    stale target), never silently dropped;
  - classification is rule-based plus a curated KNOWN_CONTRACTS overlay for
    the load-bearing contracts confirmed by hand during ADMIN-ARCH1.

Manifest identity is line-independent: each record's key hashes
(kind, file, token-or-symbol, tier) only.  Line numbers are carried for
reporting and never compared, so edits that merely move code do not drift.

Record vocabulary (documented, testable):

  authority:   SAVE_CONTRACT DATA_FOREIGN_KEY RUNTIME_LOOKUP
               GENERATED_IDENTITY SCENE_NODE_PATH TEST_CONTRACT
               CAPTURE_EVIDENCE DEBUG_ONLY PROSE_ONLY
  spatial:     SEMANTIC_ANCHOR ROOM_MEMBERSHIP FLOOR_MEMBERSHIP
               RAW_PLAN_COORDINATE RAW_GODOT_COORDINATE
               DERIVED_LAYOUT_LOOKUP CONTAINMENT_ASSUMPTION
               DISTANCE_THRESHOLD CAMERA_STATION PERFORMANCE_STATION
               ASSET_PATH UNKNOWN_DYNAMIC
  disposition: MUST_PRESERVE_ID PRESERVE_OR_ALIAS REPLACE_WITH_NAMED_ANCHOR
               REGENERATE_CONSUMER UPDATE_TEST_FIXTURE
               HISTORICAL_EVIDENCE_ONLY SAFE_TO_CHANGE OWNER_DECISION
               UNRESOLVED
  confidence:  HIGH MEDIUM LOW

Default mode compares the live scan against the checked-in manifest
(tools/orison_spatial_dependency_manifest.json) and reports drift.

Drift policy (stable, tested):

  FAIL (exit 1)  a new production record appears that the manifest does not
                 cover (unclassified spatial dependency, including a new raw
                 gameplay coordinate group); a manifest record's referenced
                 target no longer exists in the layout universe; a record
                 changes authority class; a SAVE_CONTRACT record goes stale.
  STALE (exit 4) a MUST_PRESERVE_ID / PRESERVE_OR_ALIAS / SAVE_CONTRACT
                 record disappears from source (never silently); other
                 disappeared records are reported as cleanup opportunities
                 and do NOT fail.
  exit 5         both 1 and 4.
  exit 3         malformed or duplicate manifest, usage error.
  exit 70        internal failure.
  exit 0         clean (cleanup opportunities, stats-only Vector3 pools,
                 LOW-confidence dynamic candidates all report without
                 failing).

Usage:
  python tools/audit_orison_spatial_dependencies.py
      [--root .] [--layout art/data/building_layout.json]
      [--manifest tools/orison_spatial_dependency_manifest.json]
      [--json] [--verbose] [--production-only] [--include-tests]
      [--update-manifest]

The audit reads sources only.  It never runs Godot, Blender or Git, and it
never modifies production code.  `--update-manifest` is the only write path
and rewrites only the manifest file, deterministically.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
from pathlib import Path

TOOL_VERSION = 1
MANIFEST_VERSION = 1

DEFAULT_LAYOUT = "art/data/building_layout.json"
DEFAULT_MANIFEST = "tools/orison_spatial_dependency_manifest.json"

# Scan scope, relative to --root.  Tools and docs are deliberately excluded:
# tools are audit/debug machinery audited elsewhere, and Markdown mentions are
# PROSE_ONLY by policy (never a runtime dependency).
PRODUCTION_SCRIPT_DIRS = ("game/scripts",)
SCENE_DIRS = ("game/scenes",)
TEST_DIRS = ("game/tests",)
DATA_DIRS = ("game/data",)
DATA_EXCLUDE_NAMES = {"building_layout.json"}

FLOOR_ID_RE = re.compile(r"^(B1|F0[1-9]|ROOF)$")
UNIT_ID_RE = re.compile(r"^[1-6][A-D]$")
# Id-looking fragments used to catch dynamically assembled or stale ids.
# Lower-case tails (generated mesh names like F01_glazing) are cosmetic and
# deliberately excluded.
ID_FRAGMENT_RE = re.compile(r"^(?:B1|F0\d|ROOF|SITE)_[A-Z0-9_]+$")

GD_STRING_RE = re.compile(r'&?"((?:[^"\\]|\\.)*)"')
B2G_RE = re.compile(r"\bb2g\s*\(")
NUM = r"-?\d+(?:\.\d+)?"
LITERAL_ARRAY3_RE = re.compile(
    rf"\[\s*({NUM})\s*,\s*({NUM})\s*,\s*({NUM})\s*\]")
VECTOR3_LITERAL_RE = re.compile(
    rf"Vector3\s*\(\s*({NUM})\s*,\s*({NUM})\s*,\s*({NUM})\s*\)")
FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)")
NAME_ASSIGN_RE = re.compile(r"\.name\s*=\s*(.+)$")
NODE_LOOKUP_RE = re.compile(
    r'\b(?:get_node|get_node_or_null|find_child|has_node|NodePath)\s*\(\s*&?"([^"]+)"')
RES_PATH_RE = re.compile(r'"(res://[^"]+)"')
DISTANCE_RE = re.compile(r"\bdistance_(?:to|squared_to)\s*\(")

# Coordinate context tiers.  STRONG marks a world/gameplay binding on its
# own; WEAK needs magnitude (>= WEAK_MAGNITUDE on some component) to count,
# which keeps sub-metre local prop offsets (eye.position, muzzle offsets)
# out of the manifest while catching building-space placements.
STRONG_GAMEPLAY_RE = re.compile(
    r"global_position|global_transform|look_at|teleport|warp|spawn|camera|"
    r"station|waypoint|route|travel|distance_|patrol|respawn|arrival",
    re.IGNORECASE)
WEAK_GAMEPLAY_RE = re.compile(
    r"\.position\b|origin|target|dest|stand\b|move_to|\beye\b|return",
    re.IGNORECASE)
LOCAL_CONTEXT_RE = re.compile(
    r"\bsize\b|\bscale\b|scaled|basis|extents|aabb|vertex|uv\b|normal|"
    r"tangent|color|albedo|emission|mesh\.|add_vertex|set_radius",
    re.IGNORECASE)
WEAK_MAGNITUDE = 8.0
# Plan-space literal arrays ([x, y, z] in Blender floor-plan space) are
# recorded when the line binds them: a b2g conversion, a camera/look helper,
# or a position-ish key ("at"/"pos").
PLAN_ARRAY_CONTEXT_RE = re.compile(
    r'b2g\s*\(|_look\s*\(|look|cam|frame|shot|station|\beye\b|aim|'
    r'"at"|"pos"|\bpos\b', re.IGNORECASE)
PLAN_ARRAY_MIN_MAG = 1.5

ASSET_PATH_MARKERS = ("assets/building/", "scenes/building/")

PRESERVE_DISPOSITIONS = {"MUST_PRESERVE_ID", "PRESERVE_OR_ALIAS"}

# Secondary identifier authorities: data files that DEFINE spatial ids of
# their own (loaded into the universe when present).  Their self-defining
# occurrences are skipped during consumer scanning; references from any
# OTHER file are foreign keys.
SECONDARY_AUTHORITIES = (
    # (relative path, universe domain, id field)
    ("game/data/acoustic_graph.json", "acoustic_node", "id"),
    ("game/data/fixture_light_map.json", "fixture", "id"),
    # The Orison v2 blockout (two-root rebuild): a deliberate second layout
    # authority.  Ids it defines that ALSO exist in the v1 universe are the
    # parity surface; v2-only ids (envelopes, capsule stations, thresholds)
    # are its own vocabulary and do not spam the inventory.
    ("game/data/orison_v2_blockout.json", "v2_blockout", "id"),
)
DOMAIN_AUTHORITY_FILE = {
    "acoustic_node": "acoustic_graph.json",
    "fixture": "fixture_light_map.json",
    "v2_blockout": "orison_v2_blockout.json",
}

# Stable identifiers CREATED AT RUNTIME by production code (not present in
# the layout JSON): gameplay stations, registers, guards and service
# anchors authored by orison_detail_pass.gd / building_root.gd and consumed
# by props, saves and tests.  These are contracts of the current building
# even though no data file defines them.
RUNTIME_CREATED_IDS = {
    "F01_NIGHT_REGISTER", "F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD",
    "F01_WATCHMAN_DETECTOR", "F01_HOUSE_TELEPHONE_BOARD",
    "F01_FIRE_LINE_STAIR", "F03_EXTINGUISHER_STAIR",
    "B1_HOUSE_PANEL", "B1_STATION_BOILER", "B1_WATCH_STATION_01",
    "F02_WATCH_STATION_01", "F02_STATION_2A_LANDING",
    "ROOF_DOOR_CHECK", "ROOF_TANK_BALLCOCK",
    "F04_B_BED", "F01_ENTRY_SCONCE",
    "LobbyPorterBoard", "LobbyMailBank", "LobbyPostTray", "LobbyMailChute",
    "LobbyServiceDumbwaiter", "F01LandingInterlock",
    "StreetEndHoardingFaces", "AtriumShaft", "AtriumSkylightPool",
    "F04_B_DOOR_ANOMALY",
    # Registered live by OrisonV2RuntimeRoot on the house telephone line.
    "F02_A_TELEPHONE",
}

AUTHORITY_CLASSES = {
    "SAVE_CONTRACT", "DATA_FOREIGN_KEY", "RUNTIME_LOOKUP",
    "GENERATED_IDENTITY", "SCENE_NODE_PATH", "TEST_CONTRACT",
    "CAPTURE_EVIDENCE", "DEBUG_ONLY", "PROSE_ONLY"}
SPATIAL_CLASSES = {
    "SEMANTIC_ANCHOR", "ROOM_MEMBERSHIP", "FLOOR_MEMBERSHIP",
    "RAW_PLAN_COORDINATE", "RAW_GODOT_COORDINATE", "DERIVED_LAYOUT_LOOKUP",
    "CONTAINMENT_ASSUMPTION", "DISTANCE_THRESHOLD", "CAMERA_STATION",
    "PERFORMANCE_STATION", "ASSET_PATH", "UNKNOWN_DYNAMIC"}
DISPOSITIONS = {
    "MUST_PRESERVE_ID", "PRESERVE_OR_ALIAS", "REPLACE_WITH_NAMED_ANCHOR",
    "REGENERATE_CONSUMER", "UPDATE_TEST_FIXTURE", "HISTORICAL_EVIDENCE_ONLY",
    "SAFE_TO_CHANGE", "OWNER_DECISION", "UNRESOLVED"}
CONFIDENCES = {"HIGH", "MEDIUM", "LOW"}


class AuditError(Exception):
    """Usage or manifest-format error (exit 3)."""


# --------------------------------------------------------------------------
# Curated contracts.  Keys are "kind:file:token" with file repo-relative and
# forward-slashed; "*" matches any token for that kind+file.  Values override
# the heuristic classification for contracts confirmed by hand.
# --------------------------------------------------------------------------
KNOWN_CONTRACTS: dict[str, dict] = {
    # -- Two-root rebuild composition (v2 parity surface). ------------------
    "asset_path:game/scripts/building/building_root_selector.gd:*": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["ASSET_PATH"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "BuildingRootSelector is the single non-persistent "
                     "authority for waking-scene selection (v1 default, "
                     "ORISON_BUILDING_ROOT override); both scene paths are "
                     "composition contracts and cutover/rollback changes "
                     "DEFAULT_ID only.",
    },
    "id_reference:game/scripts/building/orison_v2_anchor_adapter.gd:bed": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "V1-ONLY anonymous-bed fallback: scans production "
                     "layout F04 furniture for id=='bed'.  Must stay until "
                     "cutover retires the v1 root; its removal is a "
                     "deliberate migration act, never incidental.",
    },
    "id_reference:game/scripts/campaign/core_loop_director.gd:bed": {
        "authority": ["RUNTIME_LOOKUP", "SAVE_CONTRACT"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "V1-ONLY anonymous-bed fallback behind the explicit "
                     "v2 anchor resolver: wake placement re-derives the "
                     "bedside from the unique F04 'bed' furniture record "
                     "when no resolver is bound.  Not migrated - the "
                     "fallback is the v1 root's contract.",
    },
    "id_reference:game/scripts/building/orison_v2_anchor_adapter.gd:*": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "MUST_PRESERVE_ID",
        "confidence": "HIGH",
        "rationale": "OrisonV2AnchorAdapter.REQUIRED is the two-root "
                     "parity contract: each identity must resolve to "
                     "exactly one node in the selected root (doors, vantry "
                     "point, monitors, bed, bedside return stance, lobby "
                     "service anchors).",
    },
    "runtime_id:game/scripts/building/orison_v2_anchor_adapter.gd:*": {
        "authority": ["RUNTIME_LOOKUP", "GENERATED_IDENTITY"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "MUST_PRESERVE_ID",
        "confidence": "HIGH",
        "rationale": "Runtime-created identity on the v2 parity surface "
                     "(OrisonV2AnchorAdapter.REQUIRED).",
    },
    "id_reference:game/scripts/building/orison_v2_runtime_root.gd:*": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "MUST_PRESERVE_ID",
        "confidence": "HIGH",
        "rationale": "OrisonV2RuntimeRoot mounts production props onto "
                     "blockout anchors by these identities; each must stay "
                     "unique in the v2 scene.",
    },
    "runtime_id:game/scripts/building/orison_v2_runtime_root.gd:*": {
        "authority": ["RUNTIME_LOOKUP", "GENERATED_IDENTITY"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "MUST_PRESERVE_ID",
        "confidence": "HIGH",
        "rationale": "Runtime-created identity mounted by "
                     "OrisonV2RuntimeRoot.",
    },
    # -- Save boundary (P0). RealityState owns user://reality_maintenance_
    # save.json (version 4); the entries below are the spatial identities
    # that actually reach that document.
    "unit_reference:game/scripts/reality/organism_incidents.gd:*": {
        "authority": ["SAVE_CONTRACT", "RUNTIME_LOOKUP"],
        "spatial": ["ROOM_MEMBERSHIP", "SEMANTIC_ANCHOR"],
        "disposition": "MUST_PRESERVE_ID",
        "confidence": "HIGH",
        "rationale": "Organism ledger serializes unit ids as dictionary "
                     "keys, a raw world-space 'at' coordinate and a scene "
                     "node path per incident; a missing path is silently "
                     "skipped on load and permanently strands its ORG- "
                     "work order.",
    },
    "id_reference:game/scripts/cases/mina_caption_manifestation.gd:*": {
        "authority": ["SAVE_CONTRACT", "RUNTIME_LOOKUP"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "Waking-residue facts commit anchor_id (acoustic node "
                     "F02_2A_FRIDGE_01) and display_socket_id (layout "
                     "socket 2A_FRIDGE_FACE) into the save; reconstruction "
                     "currently re-reads the consts and falls back to the "
                     "acoustic node when the socket is missing.",
    },
    "runtime_id:game/scripts/campaign/core_loop_director.gd:F04_B_BED": {
        "authority": ["SAVE_CONTRACT", "GENERATED_IDENTITY"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "MUST_PRESERVE_ID",
        "confidence": "HIGH",
        "rationale": "Serialized as core_loop.safe_return_anchor; position "
                     "is re-derived live from the unique F04 'bed' "
                     "furniture record, so the rebuild must keep both the "
                     "id and a unique F04 bed (or alias the anchor).",
    },
    "floor_reference:game/scripts/reality/building_personality_director.gd:*": {
        "authority": ["SAVE_CONTRACT", "RUNTIME_LOOKUP"],
        "spatial": ["FLOOR_MEMBERSHIP", "CONTAINMENT_ASSUMPTION"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "favorite_floor and floor_dwell serialize floor ids "
                     "as keys; floor-of-Y is derived from a hardcoded "
                     "3.2 m storey model, not the layout.",
    },
    # -- Player spawn / return (top named-anchor candidates).
    "vector3_coordinate:game/scripts/game/first_shift_director.gd:<module>": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["RAW_PLAN_COORDINATE"],
        "disposition": "REPLACE_WITH_NAMED_ANCHOR",
        "confidence": "HIGH",
        "rationale": "ARRIVAL_POSITION_B/look target: the player's arrival "
                     "spawn on every boot and waking reload is a code "
                     "constant at the south curb.",
    },
    "plan_coordinate:game/scripts/building/building_root.gd:_ready": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["RAW_PLAN_COORDINATE"],
        "disposition": "REPLACE_WITH_NAMED_ANCHOR",
        "confidence": "HIGH",
        "rationale": "Fallback player spawn b2g([0,-9,0.1]) in the lobby.",
    },
    "plan_coordinate:game/scripts/building/building_root.gd:teleport_player": {
        "authority": ["RUNTIME_LOOKUP", "DEBUG_ONLY"],
        "spatial": ["RAW_PLAN_COORDINATE"],
        "disposition": "REPLACE_WITH_NAMED_ANCHOR",
        "confidence": "HIGH",
        "rationale": "Debug floor-teleport stations at fixed lobby/ring "
                     "coordinates per floor.",
    },
    # -- Case one / golden route stations.
    "plan_coordinate:game/scripts/cases/mina_case_gameplay.gd:<module>": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["RAW_PLAN_COORDINATE"],
        "disposition": "REPLACE_WITH_NAMED_ANCHOR",
        "confidence": "HIGH",
        "rationale": "Case-one evidence props, calibrator, voice source, "
                     "shift clock and 4B letter are raw plan coordinates "
                     "inside 2A/lobby/4B; if those rooms move, case one "
                     "strands.",
    },
    # -- Resident navigation authorities.
    "plan_coordinate:game/scripts/characters/resident_nav.gd:passage_route": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["RAW_PLAN_COORDINATE"],
        "disposition": "REPLACE_WITH_NAMED_ANCHOR",
        "confidence": "HIGH",
        "rationale": "Passage aisle spine waypoints are literals "
                     "duplicating gen_layout's site routes.",
    },
    "plan_coordinate:game/scripts/building/maintenance_headquarters.gd:*": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["RAW_PLAN_COORDINATE"],
        "disposition": "REPLACE_WITH_NAMED_ANCHOR",
        "confidence": "HIGH",
        "rationale": "The entire headquarters fit-out (bench, gear wall, "
                     "case wall, interaction area) is ~20 plan literals "
                     "bound to the current F01_OFFICE with no layout "
                     "consult.",
    },
    "plan_coordinate:game/scripts/building/harukiya_interactables.gd:*": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["RAW_PLAN_COORDINATE"],
        "disposition": "REPLACE_WITH_NAMED_ANCHOR",
        "confidence": "HIGH",
        "rationale": "Bar pictures, barrels, pool table and seats are all "
                     "independent literals for the Harukiya interior.",
    },
    # -- Floor asset paths.
    "asset_path:game/scripts/building/building_root.gd:*": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["ASSET_PATH", "FLOOR_MEMBERSHIP"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "Floor-id -> res://assets/building/*.gltf map is the "
                     "load-bearing bridge from layout ids to baked "
                     "geometry; the rebuild replaces the assets but must "
                     "keep (or remap) the floor-id keys and paths "
                     "together.",
    },
    # -- Service-system endpoints.
    "id_reference:game/scripts/audio/virus_sound_director.gd:*": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "BAND_ORIGINS pins the 4B intro route to five "
                     "acoustic-graph node ids.",
    },
    "id_reference:game/scripts/props/night_register_prop.gd:*": {
        "authority": ["RUNTIME_LOOKUP", "SAVE_CONTRACT"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "HOOK_DOORS binds register hooks to generated door "
                     "ids (find_child by name); register lines serialize "
                     "unit-bearing job ids.",
    },
    "id_reference:game/scripts/building/vantry_point_network.gd:F01_D_BED_VANTRY_POINT": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["SEMANTIC_ANCHOR"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "Teresa's telltale shutter mounts on this vantry "
                     "point; silently absent if the id goes away.",
    },
    "id_reference:game/scripts/building/commensal_director.gd:F04_B_KITCHEN": {
        "authority": ["RUNTIME_LOOKUP"],
        "spatial": ["ROOM_MEMBERSHIP"],
        "disposition": "PRESERVE_OR_ALIAS",
        "confidence": "HIGH",
        "rationale": "Roach scatter listens for this room id on the "
                     "switch system's room_toggled signal.",
    },
}


# --------------------------------------------------------------------------
# Manual contracts: dependencies a textual token scan cannot see - scalar
# envelope constants, serialization behaviour, arithmetic contracts.  Each
# is emitted as a record whenever its file still exists, so a stale
# preserved contract is reported rather than silently dropped.  Confirmed
# by hand during ADMIN-ARCH1 (see the dependency-map report).
# --------------------------------------------------------------------------
MANUAL_CONTRACTS: list[dict] = [
    {"file": "game/scripts/reality/organism_incidents.gd",
     "token": "organism_ledger_spatial_payload",
     "authority": ["SAVE_CONTRACT", "RUNTIME_LOOKUP"],
     "spatial": ["RAW_GODOT_COORDINATE", "SEMANTIC_ANCHOR"],
     "disposition": "REPLACE_WITH_NAMED_ANCHOR", "confidence": "HIGH",
     "rationale": "The organism ledger serializes a raw world-space 'at' "
                  "Vector3 and a scene node path ('prop') per incident; "
                  "load silently skips a missing path, permanently "
                  "stranding the ORG- work order.  The only place raw "
                  "coordinates and node paths reach the save file."},
    {"file": "game/scripts/reality/organism_incidents.gd",
     "token": "organism_ledger_unit_keys",
     "authority": ["SAVE_CONTRACT"],
     "spatial": ["ROOM_MEMBERSHIP"],
     "disposition": "MUST_PRESERVE_ID", "confidence": "HIGH",
     "rationale": "Ledger dictionary keys and ORG-<unit>-NNN order ids "
                  "embed unit ids in the save document."},
    {"file": "game/scripts/dream/dream_atlas.gd",
     "token": "dream_spawn_path_mix",
     "authority": ["SAVE_CONTRACT"],
     "spatial": ["UNKNOWN_DYNAMIC"],
     "disposition": "MUST_PRESERVE_ID", "confidence": "HIGH",
     "rationale": "dream.spawn_anchor is an integer address in seed-space; "
                  "spawn_path()'s arithmetic mix is the contract - "
                  "changing it silently relocates every existing save's "
                  "waking room (golden-vector comment in source)."},
    {"file": "game/scripts/building/building_root.gd",
     "token": "zone_envelope_scalars",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["CONTAINMENT_ASSUMPTION"],
     "disposition": "REPLACE_WITH_NAMED_ANCHOR", "confidence": "HIGH",
     "rationale": "Hand-coded containment law: passage boxes (throat x "
                  "11..17, z 28.316..38.6; hall to z 64.6 - duplicated in "
                  "_envelope_side and _point_is_in_passage), Harukiya "
                  "core, atrium eye, roof plane, street bands, shelter "
                  "footprint, OUTSIDE_HALF_X/Z.  Scalar floats, below "
                  "token-scan granularity."},
    {"file": "game/scripts/building/exterior_detail_pass.gd",
     "token": "street_stage_envelope_scalars",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["CONTAINMENT_ASSUMPTION"],
     "disposition": "REPLACE_WITH_NAMED_ANCHOR", "confidence": "HIGH",
     "rationale": "STAGE_E 20.60 / STAGE_W -20.10 / walk and road "
                  "centrelines appear four times in this file and are "
                  "mirrored by street_traffic.gd, weather_fx.gd road mist "
                  "and the street containment test."},
    {"file": "game/scripts/building/street_traffic.gd",
     "token": "street_lane_scalars",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["RAW_GODOT_COORDINATE", "CONTAINMENT_ASSUMPTION"],
     "disposition": "REPLACE_WITH_NAMED_ANCHOR", "confidence": "HIGH",
     "rationale": "Lane x, spawn x, carriageway z band, transit stop x, "
                  "kerb y, storm-mouth tear x are code constants reading "
                  "nothing from the layout."},
    {"file": "game/scripts/building/light_rig.gd",
     "token": "floor_elevation_table_copy",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["FLOOR_MEMBERSHIP", "CONTAINMENT_ASSUMPTION"],
     "disposition": "REGENERATE_CONSUMER", "confidence": "HIGH",
     "rationale": "LEVELS {B1:-2.8 .. ROOF:19.2} duplicates floors[].z; "
                  "same table again in wayfinding_signage_pass.gd and "
                  "inline in orison_detail_pass.gd - none read "
                  "meta.levels."},
    {"file": "game/scripts/building/wayfinding_signage_pass.gd",
     "token": "floor_elevation_table_copy",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["FLOOR_MEMBERSHIP"],
     "disposition": "REGENERATE_CONSUMER", "confidence": "HIGH",
     "rationale": "Second literal copy of the storey datum table."},
    {"file": "game/scripts/characters/resident_nav.gd",
     "token": "nav_geometry_scalars",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["RAW_PLAN_COORDINATE", "CONTAINMENT_ASSUMPTION"],
     "disposition": "REPLACE_WITH_NAMED_ANCHOR", "confidence": "HIGH",
     "rationale": "Corridor core half-extents (CORE 3.43/6.93), F01 ring "
                  "envelope (5.33/9.65), full dog-leg stair flight "
                  "geometry (x +/-2.31) duplicate built geometry; only a "
                  "runtime raycast validates them."},
    {"file": "game/scripts/characters/resident_routines.gd",
     "token": "street_route_polylines",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["RAW_PLAN_COORDINATE"],
     "disposition": "REPLACE_WITH_NAMED_ANCHOR", "confidence": "HIGH",
     "rationale": "STREET_ROUTES and 18 resident HAUNTS pin authored "
                  "street polylines and per-resident haunt points as "
                  "literals."},
    {"file": "game/scripts/audio/ambient_soundscape.gd",
     "token": "audio_zone_envelope_scalars",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["CONTAINMENT_ASSUMPTION"],
     "disposition": "REPLACE_WITH_NAMED_ANCHOR", "confidence": "MEDIUM",
     "rationale": "Zone classification by raw coordinates (roof y>18.5, "
                  "outside z>9.72, basement y<-1.2) duplicates the "
                  "building envelope."},
    {"file": "game/scripts/building/elevator.gd",
     "token": "elevator_shaft_scalars",
     "authority": ["RUNTIME_LOOKUP"],
     "spatial": ["CONTAINMENT_ASSUMPTION"],
     "disposition": "OWNER_DECISION", "confidence": "MEDIUM",
     "rationale": "FRONT_Z 1.1 and WALL_T 0.18 hardcode shaft half-depth "
                  "and core wall; a resized shaft misplaces every landing "
                  "door and plate.  Stops/levels themselves are derived."},
    {"file": "game/scripts/reality/building_personality_director.gd",
     "token": "floor_height_model",
     "authority": ["RUNTIME_LOOKUP", "SAVE_CONTRACT"],
     "spatial": ["CONTAINMENT_ASSUMPTION", "FLOOR_MEMBERSHIP"],
     "disposition": "REGENERATE_CONSUMER", "confidence": "HIGH",
     "rationale": "floor-of-Y from FLOOR_HEIGHT 3.2 and y<-1.6; feeds "
                  "floor ids into the saved dwell ledger."},
]


def sha_key(kind: str, file: str, token: str, tier: str) -> str:
    basis = "|".join((kind, file, token, tier))
    return hashlib.sha1(basis.encode("utf-8")).hexdigest()[:16]


# --------------------------------------------------------------------------
# Layout universe
# --------------------------------------------------------------------------

def build_universe(layout_path: Path, root: Path | None = None) -> dict:
    try:
        data = json.loads(layout_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AuditError(f"cannot read layout {layout_path}: {exc}")
    ids: dict[str, dict] = {}

    def add(token, domain, floor=None, extra=None):
        token = str(token)
        if not token:
            return
        rec = ids.setdefault(token, {"domains": [], "floor": floor})
        if domain not in rec["domains"]:
            rec["domains"].append(domain)
        if rec.get("floor") is None and floor:
            rec["floor"] = floor
        if extra:
            rec.update({k: v for k, v in extra.items() if k not in rec})

    meta = data.get("meta", {})
    for level in meta.get("levels", {}):
        add(level, "floor")
    for unit in meta.get("residents", {}):
        add(unit, "unit")
    for floor in data.get("floors", []):
        fid = str(floor.get("id", ""))
        add(fid, "floor")
        for room in floor.get("rooms", []):
            add(room.get("id"), "room", fid, {"kind": room.get("kind")})
        for marker in floor.get("markers", []):
            add(marker.get("id"), "marker", fid, {"kind": marker.get("kind")})
        for item in floor.get("furniture", []):
            add(item.get("id"), "furniture", fid)
        for sock in floor.get("sockets", []):
            add(sock.get("id"), "socket", fid)
        for vent in floor.get("vent_registers", []):
            add(vent.get("id"), "vent", fid)
    for vp in data.get("vantry_points", []):
        add(vp.get("id"), "vantry", vp.get("floor"))
    for reg in data.get("ventilation_registers", []):
        add(reg.get("id"), "vent", reg.get("floor"))
    for shelf in data.get("bookshelves", []):
        if isinstance(shelf, dict):
            add(shelf.get("id"), "bookshelf", shelf.get("floor"))
    for extra_key in ("stairs", "elevator"):
        node = data.get(extra_key)
        if isinstance(node, dict) and node.get("id"):
            add(node.get("id"), extra_key)
        elif isinstance(node, list):
            for entry in node:
                if isinstance(entry, dict):
                    add(entry.get("id"), extra_key, entry.get("floor"))
    if root is not None:
        for rel, domain, id_field in SECONDARY_AUTHORITIES:
            sec_path = root / rel
            if not sec_path.is_file():
                continue
            try:
                sec = json.loads(sec_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue

            def collect(node):
                if isinstance(node, dict):
                    value = node.get(id_field)
                    if isinstance(value, str) and value:
                        add(value, domain, node.get("floor"))
                    for child in node.values():
                        collect(child)
                elif isinstance(node, list):
                    for child in node:
                        collect(child)

            collect(sec)
    for token in RUNTIME_CREATED_IDS:
        add(token, "runtime_created")
    counts: dict[str, int] = {}
    for rec in ids.values():
        for domain in rec["domains"]:
            counts[domain] = counts.get(domain, 0) + 1
    return {"ids": ids, "counts": counts}


# --------------------------------------------------------------------------
# Scanning
# --------------------------------------------------------------------------

class Finding:
    __slots__ = ("kind", "file", "token", "tier", "symbols", "lines",
                 "count", "context", "distance", "gameplay")

    def __init__(self, kind, file, token, tier):
        self.kind = kind
        self.file = file
        self.token = token
        self.tier = tier
        self.symbols: list[str] = []
        self.lines: list[int] = []
        self.count = 0
        self.context: list[str] = []
        self.distance = False
        self.gameplay = False

    def hit(self, line_no, symbol, context=None, distance=False,
            gameplay=False):
        self.count += 1
        if len(self.lines) < 20:
            self.lines.append(line_no)
        if symbol and symbol not in self.symbols and len(self.symbols) < 12:
            self.symbols.append(symbol)
        if context and len(self.context) < 4 and context not in self.context:
            self.context.append(context)
        self.distance = self.distance or distance
        self.gameplay = self.gameplay or gameplay


class Scanner:
    def __init__(self, root: Path, universe: dict):
        self.root = root
        self.universe = universe["ids"]
        self.findings: dict[tuple, Finding] = {}
        self.stats = {
            "files_scanned": 0,
            "vector3_total": 0,
            "vector3_stats_only": 0,
            "b2g_derived": 0,
            "gd_strings_seen": 0,
        }
        # Floor-id substring matcher for node paths / templates.
        self._floor_tokens = sorted(
            (t for t, r in self.universe.items() if "floor" in r["domains"]),
            key=len, reverse=True)

    # -- helpers -----------------------------------------------------------
    def _get(self, kind, file, token, tier) -> Finding:
        key = (kind, file, token, tier)
        finding = self.findings.get(key)
        if finding is None:
            finding = Finding(kind, file, token, tier)
            self.findings[key] = finding
        return finding

    def _rel(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix()

    # -- GDScript / tscn ---------------------------------------------------
    def scan_gd(self, path: Path, tier: str):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return
        self.stats["files_scanned"] += 1
        rel = self._rel(path)
        symbol = "<module>"
        loads_layout = "building_layout" in text
        if loads_layout:
            line_no = next((i + 1 for i, ln in enumerate(text.splitlines())
                            if "building_layout" in ln), 1)
            self._get("layout_load", rel, "building_layout.json", tier).hit(
                line_no, symbol)
        for i, raw in enumerate(text.splitlines(), 1):
            line = raw.split("#", 1)[0] if not raw.lstrip().startswith("#") \
                else ""
            if not line.strip():
                continue
            m = FUNC_RE.match(line.strip())
            if m:
                symbol = m.group(1)
            distance = bool(DISTANCE_RE.search(line))
            strong_ctx = bool(STRONG_GAMEPLAY_RE.search(line)) or \
                bool(STRONG_GAMEPLAY_RE.search(symbol))
            weak_ctx = bool(WEAK_GAMEPLAY_RE.search(line))
            local_ctx = bool(LOCAL_CONTEXT_RE.search(line))

            for sm in GD_STRING_RE.finditer(line):
                literal = sm.group(1)
                self.stats["gd_strings_seen"] += 1
                self._classify_string(literal, rel, tier, i, symbol, line)

            has_b2g = bool(B2G_RE.search(line))
            plan_arrays = LITERAL_ARRAY3_RE.findall(line)
            if has_b2g and not plan_arrays:
                # b2g over layout data (marker/furniture positions): a
                # coordinate-space bridge, not a hardcoded contract.
                self.stats["b2g_derived"] += 1
            if plan_arrays and (
                    has_b2g or PLAN_ARRAY_CONTEXT_RE.search(line)):
                mag = max(abs(float(c)) for triple in plan_arrays
                          for c in triple)
                if mag >= PLAN_ARRAY_MIN_MAG:
                    finding = self._get("plan_coordinate", rel, symbol, tier)
                    for _ in plan_arrays:
                        finding.hit(i, symbol, context=line.strip()[:160],
                                    distance=distance, gameplay=True)

            v3 = VECTOR3_LITERAL_RE.findall(line)
            if v3:
                self.stats["vector3_total"] += len(v3)
                mag = max(abs(float(c)) for triple in v3 for c in triple)
                gameplay = (strong_ctx or distance or
                            (weak_ctx and mag >= WEAK_MAGNITUDE))
                if gameplay and not local_ctx:
                    finding = self._get("vector3_coordinate", rel, symbol,
                                        tier)
                    for _ in v3:
                        finding.hit(i, symbol, context=line.strip()[:160],
                                    distance=distance, gameplay=True)
                else:
                    self.stats["vector3_stats_only"] += len(v3)

            nm = NAME_ASSIGN_RE.search(line)
            if nm:
                expr = nm.group(1).strip()
                if ("%" in expr or "str(" in expr or "+" in expr) and \
                        '"' in expr:
                    self._get("generated_name", rel, symbol, tier).hit(
                        i, symbol, context=expr[:160])

            for lm in NODE_LOOKUP_RE.finditer(line):
                target = lm.group(1)
                if self._path_is_spatial(target):
                    self._get("node_path", rel, target, tier).hit(
                        i, symbol, context=line.strip()[:160])

    def _path_is_spatial(self, target: str) -> bool:
        if target.startswith("/root/") and target.count("/") <= 2:
            return False  # autoload singleton, not a building path
        parts = re.split(r"[/_]", target)
        if any(p in self.universe for p in parts):
            return True
        return any(seg in self.universe for seg in target.split("/"))

    def _classify_string(self, literal, rel, tier, line_no, symbol, line):
        if literal.startswith("res://"):
            if any(mark in literal for mark in ASSET_PATH_MARKERS):
                self._get("asset_path", rel, literal, tier).hit(
                    line_no, symbol)
            return
        rec = self.universe.get(literal)
        if rec is not None:
            self._get(kind_for_domains(rec["domains"]), rel, literal,
                      tier).hit(line_no, symbol, context=line.strip()[:160])
            return
        if ID_FRAGMENT_RE.match(literal):
            # Looks like a layout id but is not one: stale reference or a
            # fragment of a dynamically assembled id.
            self._get("id_candidate", rel, literal, tier).hit(
                line_no, symbol, context=line.strip()[:160])

    # -- JSON data ---------------------------------------------------------
    def scan_json(self, path: Path, tier: str = "data"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return
        self.stats["files_scanned"] += 1
        rel = self._rel(path)

        def walk(node, crumb):
            if isinstance(node, dict):
                for k, v in node.items():
                    self._json_token(k, rel, crumb, is_key=True)
                    walk(v, crumb + "/" + str(k)[:40])
            elif isinstance(node, list):
                for idx, v in enumerate(node):
                    walk(v, crumb + f"[{idx}]" if idx < 3 else crumb + "[*]")
            elif isinstance(node, str):
                self._json_token(node, rel, crumb, is_key=False)

        walk(data, "")

    def _json_token(self, token, rel, crumb, is_key):
        rec = self.universe.get(token)
        if rec is None:
            if ID_FRAGMENT_RE.match(token):
                self._get("id_candidate", rel, token, "data").hit(
                    0, crumb or "/")
            return
        # A secondary authority's own defining ids are definitions, not
        # dependencies (its references to OTHER domains still count).
        base = rel.rsplit("/", 1)[-1]
        domains = [d for d in rec["domains"]
                   if DOMAIN_AUTHORITY_FILE.get(d) != base]
        if not domains:
            return
        self._get(kind_for_domains(domains), rel, token, "data").hit(
            0, crumb or "/")


def kind_for_domains(domains) -> str:
    if "floor" in domains:
        return "floor_reference"
    if "unit" in domains:
        return "unit_reference"
    # An id the running game creates stays a runtime identity even when the
    # v2 blockout also declares it as an anchor (the parity surface); only
    # a v1 layout definition makes it a plain layout reference.
    if "runtime_created" in domains and not \
            (set(domains) - {"runtime_created", "v2_blockout"}):
        return "runtime_id"
    return "id_reference"


# --------------------------------------------------------------------------
# Classification
# --------------------------------------------------------------------------

def _base_classification(finding: Finding, universe: dict) -> dict:
    kind, tier = finding.kind, finding.tier
    authority: list[str] = []
    spatial: list[str] = []
    disposition = "UNRESOLVED"
    confidence = "MEDIUM"
    rationale = ""
    rec = universe["ids"].get(finding.token)
    target_exists = rec is not None if kind in (
        "id_reference", "floor_reference", "unit_reference", "id_candidate",
        "runtime_id") else None

    if tier == "test":
        authority.append("TEST_CONTRACT")
    if tier == "data":
        authority.append("DATA_FOREIGN_KEY")

    if kind == "runtime_id":
        authority.append("GENERATED_IDENTITY")
        spatial.append("SEMANTIC_ANCHOR")
        disposition = "MUST_PRESERVE_ID" if tier in ("production", "data") \
            else "UPDATE_TEST_FIXTURE"
        confidence = "HIGH"
        rationale = "Stable identifier created at runtime by production " \
                    "code (station/register/service anchor); not in the " \
                    "layout JSON but a contract for props, saves and tests."
    elif kind in ("id_reference", "floor_reference", "unit_reference"):
        if tier in ("production", "scene"):
            authority.append("RUNTIME_LOOKUP")
        domains = rec["domains"] if rec else []
        if "room" in domains:
            spatial.append("ROOM_MEMBERSHIP")
        if "floor" in domains:
            spatial.append("FLOOR_MEMBERSHIP")
        if any(d in domains for d in
               ("marker", "socket", "vantry", "vent", "furniture",
                "bookshelf", "stairs", "elevator", "acoustic_node",
                "fixture", "runtime_created")):
            spatial.append("SEMANTIC_ANCHOR")
        if "unit" in domains and "SEMANTIC_ANCHOR" not in spatial:
            spatial.append("SEMANTIC_ANCHOR")
        if tier == "data":
            disposition = "PRESERVE_OR_ALIAS"
            rationale = "Data file keys on a layout id; the id (or an alias) " \
                        "must survive or this data silently stops applying."
        elif tier == "test":
            disposition = "UPDATE_TEST_FIXTURE"
            rationale = "Test names a layout id; regenerate or update the " \
                        "fixture when the id moves."
        else:
            disposition = "PRESERVE_OR_ALIAS"
            rationale = "Production code looks up a layout id at runtime."
    elif kind == "id_candidate":
        spatial.append("UNKNOWN_DYNAMIC")
        confidence = "LOW"
        disposition = "UNRESOLVED"
        rationale = "Id-shaped literal not present in the layout universe: " \
                    "stale reference, runtime-created name or dynamic " \
                    "fragment; resolve by hand."
        if tier in ("production", "scene"):
            authority.append("RUNTIME_LOOKUP")
    elif kind == "plan_coordinate":
        spatial.append("RAW_PLAN_COORDINATE")
        if tier == "test":
            spatial.append("CAMERA_STATION")
            disposition = "UPDATE_TEST_FIXTURE"
            rationale = "Test/capture plan-space coordinate; restation when " \
                        "the geometry moves."
        else:
            authority.append("RUNTIME_LOOKUP")
            disposition = "REPLACE_WITH_NAMED_ANCHOR"
            rationale = "Production plan-space coordinate literal binds " \
                        "gameplay to the current geometry."
    elif kind == "vector3_coordinate":
        spatial.append("RAW_GODOT_COORDINATE")
        if finding.distance:
            spatial.append("DISTANCE_THRESHOLD")
        if tier == "test":
            spatial.append("CAMERA_STATION")
            disposition = "UPDATE_TEST_FIXTURE"
            rationale = "Test/capture Godot-space coordinate."
        else:
            authority.append("RUNTIME_LOOKUP")
            disposition = "REPLACE_WITH_NAMED_ANCHOR"
            confidence = "MEDIUM"
            rationale = "Production Godot-space coordinate with gameplay " \
                        "context; candidate named anchor."
    elif kind == "generated_name":
        authority.append("GENERATED_IDENTITY")
        spatial.append("SEMANTIC_ANCHOR")
        disposition = "REGENERATE_CONSUMER"
        rationale = "Node name is generated from layout data; consumers of " \
                    "the pattern regenerate with the new layout, but the " \
                    "TEMPLATE is a contract for any find_child/save use."
    elif kind == "node_path":
        authority.append("SCENE_NODE_PATH")
        spatial.append("SEMANTIC_ANCHOR")
        disposition = "PRESERVE_OR_ALIAS" if tier != "test" \
            else "UPDATE_TEST_FIXTURE"
        rationale = "Node-path lookup embeds spatial identity."
    elif kind == "asset_path":
        spatial.append("ASSET_PATH")
        if tier == "test":
            disposition = "UPDATE_TEST_FIXTURE"
        else:
            authority.append("RUNTIME_LOOKUP")
            disposition = "PRESERVE_OR_ALIAS"
        rationale = "Building asset path; the rebuild will re-bake these " \
                    "files or remap the reference."
    elif kind == "layout_load":
        spatial.append("DERIVED_LAYOUT_LOOKUP")
        if tier != "test":
            authority.append("RUNTIME_LOOKUP")
        disposition = "REGENERATE_CONSUMER"
        confidence = "HIGH"
        rationale = "Reads the layout authority; follows the layout " \
                    "wherever it goes, subject to the ids it names."
    if "debug" in finding.file.rsplit("/", 1)[-1] and \
            "DEBUG_ONLY" not in authority:
        authority.append("DEBUG_ONLY")
    if not authority:
        authority.append("RUNTIME_LOOKUP"
                         if tier in ("production", "scene") else
                         "TEST_CONTRACT")
    return {
        "authority": sorted(set(authority)),
        "spatial": sorted(set(spatial)),
        "disposition": disposition,
        "confidence": confidence,
        "rationale": rationale,
        "target_exists": target_exists,
    }


def classify(finding: Finding, universe: dict) -> dict:
    result = _base_classification(finding, universe)
    for pattern in (f"{finding.kind}:{finding.file}:{finding.token}",
                    f"{finding.kind}:{finding.file}:*"):
        override = KNOWN_CONTRACTS.get(pattern)
        if override:
            for src, dst in (("authority", "authority"),
                             ("spatial", "spatial")):
                if src in override:
                    result[dst] = sorted(set(override[src]))
            for field in ("disposition", "confidence", "rationale"):
                if field in override:
                    result[field] = override[field]
            break
    return result


def finding_to_record(finding: Finding, universe: dict) -> dict:
    cls = classify(finding, universe)
    rec = universe["ids"].get(finding.token, {})
    resolved = None
    if rec:
        resolved = "/".join(filter(None, [
            str(rec.get("floor") or ""),
            "+".join(rec.get("domains", []))]))
    return {
        "key": sha_key(finding.kind, finding.file, finding.token,
                       finding.tier),
        "kind": finding.kind,
        "token": finding.token,
        "file": finding.file,
        "tier": finding.tier,
        "subsystem": subsystem_of(finding.file),
        "symbols": finding.symbols,
        "lines": finding.lines,
        "count": finding.count,
        "context": finding.context,
        "gameplay_binding": finding.gameplay,
        "authority": cls["authority"],
        "spatial": cls["spatial"],
        "disposition": cls["disposition"],
        "confidence": cls["confidence"],
        "rationale": cls["rationale"],
        "resolved_target": resolved,
        "target_exists": cls["target_exists"],
    }


def subsystem_of(file: str) -> str:
    parts = file.split("/")
    if file.startswith("game/scripts/") and len(parts) > 2:
        return parts[2] if parts[2].endswith(".gd") is False else "scripts"
    if file.startswith("game/tests/"):
        return "tests"
    if file.startswith("game/data/"):
        return "data"
    if file.startswith("game/scenes/"):
        return "scenes"
    return parts[0] if parts else "unknown"


# --------------------------------------------------------------------------
# Manifest
# --------------------------------------------------------------------------

def load_manifest(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise AuditError(f"cannot read manifest {path}: {exc}")
    except json.JSONDecodeError as exc:
        raise AuditError(f"malformed manifest {path}: {exc}")
    if not isinstance(data, dict) or "records" not in data or \
            not isinstance(data["records"], list):
        raise AuditError(f"malformed manifest {path}: missing records list")
    seen = set()
    for record in data["records"]:
        if not isinstance(record, dict) or "key" not in record:
            raise AuditError(f"malformed manifest {path}: record without key")
        if record["key"] in seen:
            raise AuditError(
                f"duplicate manifest identity {record['key']} "
                f"({record.get('kind')}:{record.get('file')}:"
                f"{record.get('token')})")
        seen.add(record["key"])
        for field, allowed in (("authority", AUTHORITY_CLASSES),
                               ("spatial", SPATIAL_CLASSES)):
            values = record.get(field, [])
            if not isinstance(values, list) or \
                    not set(values) <= allowed:
                raise AuditError(
                    f"malformed manifest {path}: bad {field} on "
                    f"{record['key']}")
        if record.get("disposition") not in DISPOSITIONS:
            raise AuditError(
                f"malformed manifest {path}: bad disposition on "
                f"{record['key']}")
    return data


def scan_repository(root: Path, layout_path: Path, include_tests: bool,
                    production_only: bool) -> tuple[dict, list[dict]]:
    universe = build_universe(layout_path, root)
    scanner = Scanner(root, universe)
    for base in PRODUCTION_SCRIPT_DIRS:
        for path in sorted((root / base).rglob("*.gd")):
            scanner.scan_gd(path, "production")
    for base in SCENE_DIRS:
        for path in sorted((root / base).rglob("*.tscn")):
            scanner.scan_gd(path, "scene")
    if not production_only:
        for base in DATA_DIRS:
            base_path = root / base
            if base_path.is_dir():
                for path in sorted(base_path.rglob("*.json")):
                    if path.name in DATA_EXCLUDE_NAMES:
                        continue
                    scanner.scan_json(path)
        if include_tests:
            for base in TEST_DIRS:
                for path in sorted((root / base).rglob("*.gd")):
                    scanner.scan_gd(path, "test")
    records = [finding_to_record(f, universe)
               for f in scanner.findings.values()]
    for manual in MANUAL_CONTRACTS:
        if not (root / manual["file"]).is_file():
            continue
        records.append({
            "key": sha_key("manual_contract", manual["file"],
                           manual["token"], "production"),
            "kind": "manual_contract",
            "token": manual["token"],
            "file": manual["file"],
            "tier": "production",
            "subsystem": subsystem_of(manual["file"]),
            "symbols": [],
            "lines": [],
            "count": 1,
            "context": [],
            "gameplay_binding": True,
            "authority": sorted(manual["authority"]),
            "spatial": sorted(manual["spatial"]),
            "disposition": manual["disposition"],
            "confidence": manual["confidence"],
            "rationale": manual["rationale"],
            "resolved_target": None,
            "target_exists": None,
        })
    records.sort(key=lambda r: (r["file"], r["kind"], r["token"], r["tier"]))
    return {"universe": universe, "stats": scanner.stats}, records


def summarize(records: list[dict]) -> dict:
    def tally(field):
        out: dict[str, int] = {}
        for record in records:
            values = record[field] if isinstance(record[field], list) \
                else [record[field]]
            for value in values:
                out[value] = out.get(value, 0) + 1
        return dict(sorted(out.items()))
    return {
        "records": len(records),
        "by_tier": tally("tier"),
        "by_kind": tally("kind"),
        "by_authority": tally("authority"),
        "by_spatial": tally("spatial"),
        "by_disposition": tally("disposition"),
        "by_confidence": tally("confidence"),
    }


# --------------------------------------------------------------------------
# Drift
# --------------------------------------------------------------------------

ID_KINDS = ("id_reference", "floor_reference", "unit_reference",
            "runtime_id")


def diff_against_manifest(manifest: dict, live: list[dict],
                          scanned_tiers: set[str],
                          universe_ids=None) -> dict:
    live_by_key = {r["key"]: r for r in live}
    manifest_records = [r for r in manifest["records"]
                        if r.get("tier") in scanned_tiers]
    man_by_key = {r["key"]: r for r in manifest_records}

    new_failing, new_reported = [], []
    for key, record in live_by_key.items():
        if key in man_by_key:
            continue
        if record["tier"] in ("production", "scene", "data") and (
                record["gameplay_binding"] or
                record["kind"] in ("id_reference", "floor_reference",
                                   "unit_reference", "runtime_id",
                                   "asset_path", "layout_load", "node_path",
                                   "generated_name")):
            new_failing.append(record)
        else:
            new_reported.append(record)

    stale_preserved, cleanup = [], []
    class_changes, target_vanished, save_unresolved = [], [], []
    for key, record in man_by_key.items():
        live_record = live_by_key.get(key)
        if live_record is None:
            if universe_ids is not None and \
                    record.get("kind") in ID_KINDS and \
                    record.get("target_exists") is True and \
                    record.get("token") not in universe_ids:
                # The identifier itself left the layout universe: the
                # reference did not go away, its target did.
                target_vanished.append(record)
            elif record.get("disposition") in PRESERVE_DISPOSITIONS or \
                    "SAVE_CONTRACT" in record.get("authority", []):
                stale_preserved.append(record)
            else:
                cleanup.append(record)
            continue
        if sorted(record.get("authority", [])) != live_record["authority"]:
            class_changes.append({"manifest": record, "live": live_record})
        elif record.get("gameplay_binding") != \
                live_record["gameplay_binding"]:
            # A coordinate group flipping between contract and
            # non-contract is a classification event, never silent.
            class_changes.append({"manifest": record, "live": live_record})
        elif record.get("kind") in ID_KINDS and \
                record.get("resolved_target") != \
                live_record["resolved_target"]:
            # Same identifier, different domain/floor resolution: the id
            # changed meaning under the consumer.
            class_changes.append({"manifest": record, "live": live_record})
        if record.get("target_exists") is True and \
                live_record["target_exists"] is False:
            target_vanished.append(live_record)
        if "SAVE_CONTRACT" in record.get("authority", []) and \
                live_record["disposition"] == "UNRESOLVED":
            save_unresolved.append(live_record)
    return {
        "new_failing": new_failing,
        "new_reported": new_reported,
        "stale_preserved": stale_preserved,
        "cleanup_opportunities": cleanup,
        "class_changes": class_changes,
        "target_vanished": target_vanished,
        "save_unresolved": save_unresolved,
    }


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Source-only Orison spatial dependency audit "
                    "(ADMIN-ARCH1).")
    parser.add_argument("--root", default=".")
    parser.add_argument("--layout", default=None,
                        help=f"layout authority (default {DEFAULT_LAYOUT}, "
                             "falling back to game/data/building_layout.json)")
    parser.add_argument("--manifest", default=None)
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--production-only", action="store_true")
    parser.add_argument("--include-tests", action="store_true", default=True,
                        help="scan game/tests (default on; --production-only "
                             "wins)")
    parser.add_argument("--update-manifest", action="store_true",
                        help="rewrite the manifest from the live scan "
                             "(explicit request only)")
    return parser


def main(argv=None) -> int:
    try:
        args = build_parser().parse_args(argv)
    except SystemExit as exc:
        return 3 if exc.code not in (0,) else 0
    try:
        return run(args)
    except AuditError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3
    except Exception as exc:  # pragma: no cover - defensive
        print(f"INTERNAL: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 70


def run(args) -> int:
    root = Path(args.root).resolve()
    if not root.is_dir():
        raise AuditError(f"root {root} is not a directory")
    layout = Path(args.layout) if args.layout else None
    if layout is None:
        for candidate in (root / DEFAULT_LAYOUT,
                          root / "game/data/building_layout.json"):
            if candidate.is_file():
                layout = candidate
                break
        if layout is None:
            raise AuditError("no building_layout.json found; pass --layout")
    elif not layout.is_absolute():
        layout = root / layout
    manifest_path = Path(args.manifest) if args.manifest else \
        root / DEFAULT_MANIFEST
    if args.manifest and not manifest_path.is_absolute():
        manifest_path = root / args.manifest

    include_tests = args.include_tests and not args.production_only
    meta, records = scan_repository(root, layout, include_tests,
                                    args.production_only)
    summary = summarize(records)
    scanned_tiers = {"production", "scene"}
    if not args.production_only:
        scanned_tiers.add("data")
        if include_tests:
            scanned_tiers.add("test")

    if args.update_manifest:
        # The manifest is the tool's ONLY write path; never let it land on
        # a production surface by mistyped --manifest.
        resolved_manifest = manifest_path.resolve()
        for guarded in ("game", "art", "design"):
            guarded_dir = (root / guarded).resolve()
            if resolved_manifest.is_relative_to(guarded_dir):
                raise AuditError(
                    f"refusing to write manifest inside {guarded_dir}; "
                    "the manifest belongs under tools/ or outside the "
                    "repository")
        manifest = {
            "manifest_version": MANIFEST_VERSION,
            "tool_version": TOOL_VERSION,
            "layout_path": layout.relative_to(root).as_posix()
            if layout.is_relative_to(root) else str(layout),
            "universe_counts": meta["universe"]["counts"],
            "records": records,
        }
        manifest_path.write_text(
            json.dumps(manifest, indent=1, sort_keys=False) + "\n",
            encoding="utf-8")
        payload = {"mode": "update", "manifest": str(manifest_path),
                   "summary": summary, "stats": meta["stats"]}
        emit(payload, args, records=records)
        return 0

    if not manifest_path.is_file():
        raise AuditError(
            f"manifest {manifest_path} missing; run --update-manifest once "
            "to establish the inventory")
    manifest = load_manifest(manifest_path)
    drift = diff_against_manifest(manifest, records, scanned_tiers,
                                  set(meta["universe"]["ids"]))

    fail = bool(drift["new_failing"] or drift["class_changes"] or
                drift["target_vanished"] or drift["save_unresolved"])
    stale = bool(drift["stale_preserved"])
    payload = {
        "mode": "check",
        "summary": summary,
        "stats": meta["stats"],
        "drift": {k: v for k, v in drift.items()},
        "result": "fail" if fail and stale else
                  "fail" if fail else "stale" if stale else "clean",
    }
    emit(payload, args, records=records)
    if fail and stale:
        return 5
    if fail:
        return 1
    if stale:
        return 4
    return 0


def emit(payload: dict, args, records=None) -> None:
    if args.as_json:
        if args.verbose and records is not None:
            payload = dict(payload)
            payload["records"] = records
        print(json.dumps(payload, indent=1, sort_keys=False))
        return
    out = io.StringIO()
    mode = payload["mode"]
    out.write(f"orison spatial dependency audit ({mode})\n")
    summary = payload["summary"]
    out.write(f"records: {summary['records']}  ")
    out.write("tiers: " + ", ".join(
        f"{k}={v}" for k, v in summary["by_tier"].items()) + "\n")
    out.write("authority: " + ", ".join(
        f"{k}={v}" for k, v in summary["by_authority"].items()) + "\n")
    out.write("spatial: " + ", ".join(
        f"{k}={v}" for k, v in summary["by_spatial"].items()) + "\n")
    out.write("disposition: " + ", ".join(
        f"{k}={v}" for k, v in summary["by_disposition"].items()) + "\n")
    stats = payload["stats"]
    out.write(f"vector3 literals: {stats['vector3_total']} total, "
              f"{stats['vector3_stats_only']} stats-only (local/"
              f"presentation)\n")
    if mode == "check":
        drift = payload["drift"]
        for label, entries in (
                ("NEW unclassified (FAIL)", drift["new_failing"]),
                ("authority-class changes (FAIL)", drift["class_changes"]),
                ("targets vanished (FAIL)", drift["target_vanished"]),
                ("save-contract unresolved (FAIL)",
                 drift["save_unresolved"]),
                ("stale preserved records (STALE)",
                 drift["stale_preserved"]),
                ("new incidental (report only)", drift["new_reported"]),
                ("cleanup opportunities", drift["cleanup_opportunities"])):
            out.write(f"{label}: {len(entries)}\n")
            limit = None if args.verbose else 10
            for entry in entries[:limit]:
                record = entry.get("live", entry) if "live" in entry \
                    else entry
                out.write(f"  - {record.get('kind')}:"
                          f"{record.get('file')}:"
                          f"{record.get('token')}"
                          f" [{record.get('tier')}]\n")
            if limit is not None and len(entries) > limit:
                out.write(f"  ... {len(entries) - limit} more "
                          f"(--verbose)\n")
        out.write(f"result: {payload['result']}\n")
    else:
        out.write(f"manifest written: {payload['manifest']}\n")
    sys.stdout.write(out.getvalue())


if __name__ == "__main__":
    sys.exit(main())
