#!/usr/bin/env python3
"""ADMIN-ARCH2 completeness ledger: when is the Orison rebuild actually done?

Read-only, deterministic comparison of the canonical building/resident/
program obligations against the current Orison v2 schema, the production v1
inventory, the migration-contract identities, the spatial dependency
manifest and the committed v2 milestone evidence.  It answers, with
provenance, which required floors, units, rooms, service systems, semantic
owners and proofs exist in v2, which are shells or bare anchors, which are
proven or human-accepted, which still lean on v1 fallbacks, which absences
block cutover, and what the safest remaining milestone order is.

The tool NEVER collapses completeness into one percentage.  Every
requirement carries one attained status from an explicit ladder plus
independent flags:

  ABSENT          no v2 record exists for the obligation
  SHELL_ONLY      geometry exists but is an open shell / has no entrance /
                  carries no functional program
  ANCHOR_ONLY     a semantic anchor exists with no containing programmed
                  space (an anchor in empty space is not an owner)
  PROGRAMMED      space exists with class, purpose and a real entrance
  SPATIALLY_PROVEN  covered by a committed automated geometry/route/
                  clearance checkpoint (gray-box, vertical core, schema)
  RUNTIME_PROVEN  exercised by committed runtime-parity / composition
                  evidence (M08 family)
  HUMAN_ACCEPTED  covered by a durable human-acceptance receipt (owner
                  verdict JSON) - a screenshot receipt is NOT acceptance
  Flags (orthogonal, never statuses of their own):
  TEMPORARY_V1_FALLBACK  the consumer is still served by a v1 mechanism
  BLOCKED         a prerequisite absence prevents progress
  NOT_REQUIRED    deliberately absent per the program authority

Readiness is SCOPED.  A requirement is never simply "complete for
cutover"; it carries `complete_for_scopes` and `blocking_scopes` over six
explicit readiness scopes, in dependency order:

  FIRST_SLICE_TECHNICAL   accepted street->F01->2A->4B route, the M08E
                          ritual/2B/B1 owners, runtime composition and the
                          two-root proof.  Supports an explicit v2
                          development/test selector only - it NEVER
                          implies a production default flip.
  GOLDEN_SHIFT_V2         the complete authored golden shift (eleven
                          beats) under explicit v2 selection, plus
                          first-shift/service-round runtime proof.  Still
                          not a production-default authorization.
  FULL_BUILDING_STRUCTURAL  every canonical floor, circulation record,
                          unit, sealed/vacant threshold, service room and
                          vertical system represented and spatially
                          proven.
  FULL_BUILDING_RUNTIME   every required job, case, interaction, save,
                          wake, acoustic and service system resolves
                          against v2.
  PRODUCTION_CUTOVER      both full-building scopes plus whole-building
                          navigation/performance/human acceptance; one
                          reversible selector flip authorized; v1 remains
                          a tagged fallback.
  V1_RETIREMENT           no temporary v1 fallbacks anywhere, rollback
                          window completed, explicit owner retirement
                          authorization.

A v1 fallback of kind "absence" (the consumer cannot resolve v2 at all)
blocks every scope that requires the item; a fallback of kind
"redundancy" (the v2 path is proven and the v1 path is retained by
contract, e.g. the anonymous bed) blocks only V1_RETIREMENT.

The ten M08D dependencies are FIRST-SLICE blockers (equivalently:
golden-shift spatial blockers).  Production-cutover blockers include
every absent or incomplete whole-building obligation - a proven first
slice with twenty missing units is NOT production-cutover ready, and no
first-slice result may flip `BuildingRootSelector.DEFAULT_ID`.

Matching rules (honest by construction):

  - Exact evidence first: v2 record ids/fields (class, purpose, connects,
    open_shell), migration-contract table identities, adapter REQUIRED
    list, dependency-manifest dispositions, checkpoint documents'
    backticked identifiers, capture receipts, the human-acceptance JSON.
  - Function matching inside a unit uses the v2 record's own `purpose` and
    `class` fields, never the id token alone.
  - Heuristic conclusions (id-grammar unit membership, v1->v2 alias
    guesses) are labeled `heuristic`.  The label qualifies the MAPPING -
    which v2 spaces were taken to belong to the unit - not the status:
    once a space is mapped, it climbs the ladder on the same evidence as
    any other, so a heuristic unit reaches SPATIALLY_PROVEN when a
    checkpoint backticks its spaces (unit.2B does today).  The label is
    surfaced in `heuristic_conclusions` and in the `unresolved` list so a
    reviewer can see which conclusions rest on a guessed mapping; only
    UNIT_PREFIX_EXACT removes the guess.
  - A checkpoint id that no longer exists in the current v2 layout is
    reported as stale evidence, not silently trusted.
  - Human acceptance applies only to its recorded scope (M08A is
    route-readability only) - it never marks rooms as accepted.

Writes nothing unless --out is given.  --out refuses game/, art/ and
design/ destinations (the single documented safe design path is
design/orison_v2_completeness_reports).  Existing report files are not
overwritten without --force; writes are atomic (temp file + replace).
No Godot, no Git, no generators; standard library only.

Usage:
  python tools/audit_orison_v2_completeness.py [--root .]
      [--v1-layout PATH] [--v2-layout PATH] [--design-dir PATH]
      [--dependency-manifest PATH] [--acceptance PATH]
      [--floor F02 ...] [--unit 2A ...] [--space ID]
      [--blockers-for SCOPE] [--blockers-only]
      [--baseline PATH] [--json] [--markdown] [--out DIR] [--force]

`--blockers-for` takes first-slice, golden-shift,
full-building-structural, full-building-runtime, full-building,
production-cutover or retirement.  `--blockers-only` is a
backward-compatible alias for `--blockers-for production-cutover` -
deliberately the WIDE meaning, never the first slice.

Exit codes (stable, tested):
  0   clean: nothing in scope blocks any queried readiness scope (the
      unfiltered run exits 0 only when the whole rebuild is complete
      through PRODUCTION_CUTOVER and V1_RETIREMENT)
  1   incomplete: only V1_RETIREMENT-scope work remains in scope
  2   blocked: a production-cutover-or-earlier blocker is in scope (or,
      with --blockers-for, a blocker for that scope)
  3   malformed input, refused output destination or usage error
  70  internal failure

A clean `--blockers-for first-slice` run prints
"FIRST SLICE READY - PRODUCTION CUTOVER NOT IMPLIED." and still exits 0
only for that narrow question; the unfiltered command stays nonzero
until the whole rebuild is complete.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

TOOL_VERSION = 1

DEFAULT_V1 = ("art/data/building_layout.json",
              "game/data/building_layout.json")
DEFAULT_V2 = "game/data/orison_v2_blockout.json"
DEFAULT_DESIGN = "design"
DEFAULT_MANIFEST = "tools/orison_spatial_dependency_manifest.json"
ADAPTER_PATH = "game/scripts/building/orison_v2_anchor_adapter.gd"
RECEIPT_GLOB = "art/renders/orison_v2"
SAFE_DESIGN_OUT = "design/orison_v2_completeness_reports"

STATUS_ORDER = ["ABSENT", "ANCHOR_ONLY", "SHELL_ONLY", "PROGRAMMED",
                "SPATIALLY_PROVEN", "RUNTIME_PROVEN", "HUMAN_ACCEPTED"]
RANK = {s: i for i, s in enumerate(STATUS_ORDER)}

SCOPES = ["FIRST_SLICE_TECHNICAL", "GOLDEN_SHIFT_V2",
          "FULL_BUILDING_STRUCTURAL", "FULL_BUILDING_RUNTIME",
          "PRODUCTION_CUTOVER", "V1_RETIREMENT"]
SCOPE_FLAGS = {
    "first-slice": ["FIRST_SLICE_TECHNICAL"],
    "golden-shift": ["FIRST_SLICE_TECHNICAL", "GOLDEN_SHIFT_V2"],
    "full-building-structural": ["FULL_BUILDING_STRUCTURAL"],
    "full-building-runtime": ["FULL_BUILDING_RUNTIME"],
    "full-building": ["FULL_BUILDING_STRUCTURAL",
                      "FULL_BUILDING_RUNTIME"],
    "production-cutover": ["PRODUCTION_CUTOVER"],
    "retirement": ["V1_RETIREMENT"],
}
FIRST_SLICE_BANNER = ("FIRST SLICE READY - PRODUCTION CUTOVER NOT "
                      "IMPLIED.")

# Requirement ids (and id prefixes) that belong to the first-slice
# technical gate: the accepted route's proofs plus the ten M08D spatial
# dependencies ("first-slice blockers" / "golden-shift spatial
# blockers" - never "the cutover blockers").
FIRST_SLICE_PREFIXES = ("ritual.", "interaction.", "job.")
FIRST_SLICE_IDS = {
    "unit.2B", "floor.B1", "b1.boiler_room",
    "contract.B1_BOILER_01", "contract.F02_B_RADIATOR_01",
    "case.mina_caption_crisis", "save.bedside_return",
    "human.route_readability", "evidence.receipts",
    "selector.reversible_two_root", "site.street_threshold",
}
STRUCTURAL_FAMILIES = {"floor", "circ", "unit", "f01", "b1", "roof",
                       "site", "service"}
RUNTIME_FAMILIES = {"job", "case", "interaction", "save", "contract",
                    "acoustic", "service", "ritual", "unit", "f01"}


def in_first_slice(req_id: str) -> bool:
    return req_id in FIRST_SLICE_IDS or \
        req_id.startswith(FIRST_SLICE_PREFIXES)


def scope_memberships(record: dict) -> dict:
    """scope -> required status tier for this requirement (members only).

    PRODUCTION_CUTOVER and V1_RETIREMENT contain every requirement (except
    the retirement authorization, which belongs to retirement alone):
    production-cutover blockers include every required whole-building
    obligation, by construction.
    """
    rid = record["id"]
    family = rid.split(".", 1)[0]
    required = record["required_proof"]
    tiers: dict[str, str] = {}
    if rid == "retirement.authorization":
        return {"V1_RETIREMENT": required}
    if in_first_slice(rid):
        tiers["FIRST_SLICE_TECHNICAL"] = required
    if in_first_slice(rid) or rid == "golden.eleven_beats":
        tiers["GOLDEN_SHIFT_V2"] = required
    if family in STRUCTURAL_FAMILIES:
        tiers["FULL_BUILDING_STRUCTURAL"] = STATUS_ORDER[
            min(RANK[required], RANK["SPATIALLY_PROVEN"])]
    if family in RUNTIME_FAMILIES and rid.count(".") == 1:
        tiers["FULL_BUILDING_RUNTIME"] = required
    tiers["PRODUCTION_CUTOVER"] = required
    tiers["V1_RETIREMENT"] = required
    return tiers


def assign_scopes(record: dict) -> None:
    tiers = scope_memberships(record)
    blocking, complete = [], []
    for scope in SCOPES:
        tier = tiers.get(scope)
        if tier is None:
            continue
        if record["status"] == "NOT_REQUIRED":
            complete.append(scope)
            continue
        ok = (RANK.get(record["status"], -1) >= RANK.get(tier, 99)
              and not record["blocked_by"])
        if record["temporary_v1_fallback"]:
            if scope == "V1_RETIREMENT":
                ok = False
            elif record.get("fallback_kind", "absence") == "absence":
                ok = False
        (complete if ok else blocking).append(scope)
    record["blocking_scopes"] = blocking
    record["complete_for_scopes"] = complete


class AuditError(Exception):
    """Usage / malformed-input error (exit 3)."""


# ---------------------------------------------------------------------------
# Canonical obligations.
#
# Encoded from the accepted program authority and companion documents; each
# entry names its provenance so no conclusion is free-floating.  The tool
# deliberately does not parse the program prose: this table IS the reviewed
# machine encoding of it, and updating the program means updating this
# table in the same commit.
# ---------------------------------------------------------------------------
PROGRAM_DOC = "design/ORISON_ARCHITECTURAL_PROGRAM_2026-08-28.md"
REBUILD_DOC = "design/ORISON_ARCHITECTURAL_REBUILD_CHECKPOINT_2026-08-28.md"
CONTRACT_DOC = "design/ORISON_REBUILD_MIGRATION_CONTRACT_2026-08-28.md"
M08D_DOC = "design/ORISON_V2_M08D_RUNTIME_PARITY_CHECKPOINT_2026-08-28.md"

CANON_FLOORS = ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]
RESIDENTIAL_FLOORS = ["F02", "F03", "F04", "F05", "F06"]

# Sealed units per production story facts (window_glow.gd SEALED_UNITS and
# the absence of apartment_life_profiles entries).
SEALED_UNITS = {"2D", "3C", "5D", "6D"}

# Unit functional minimums (program: apartment program table).  Each
# function is satisfied by a v2 space whose OWN purpose/class matches the
# predicate - never by id token alone.
#
# `word_groups` is a list of alternatives; a space satisfies the function
# when EVERY word of ANY ONE group appears in its purpose (see
# match_purpose_words).  This replaced contiguous-phrase containment,
# which made the entry minimum depend on English word order and
# punctuation: F02_B_VESTIBULE's real purpose, "2B privacy, coat storage
# and distribution", failed the phrase "privacy and distribution" over a
# comma, so unit.2B.entry was reported ABSENT on a built, traversed and
# owner-accepted vestibule.  The apartment program asks for a vestibule
# that gives privacy AND distributes; it does not prescribe a sentence.
UNIT_FUNCTIONS = {
    "entry": {"word_groups": [["privacy", "distribution"],
                              ["weather", "lock"]],
              "basis": f"{PROGRAM_DOC} - apartment vestibule row"},
    "living": {"word_groups": [["living"], ["rest"], ["meeting"],
                               ["conversation"]],
               "basis": f"{PROGRAM_DOC} - living/dining row"},
    "cooking": {"word_groups": [["cooking"]],
                "basis": f"{PROGRAM_DOC} - kitchen row"},
    "sanitary": {"class_any": ["wet"], "word_groups": [["sanitary"]],
                 "basis": f"{PROGRAM_DOC} - bathroom row"},
    "sleep": {"word_groups": [["sleep"]],
              "basis": f"{PROGRAM_DOC} - bedroom/alcove rows"},
    "storage": {"word_groups": [["storage"]],
                "basis": f"{PROGRAM_DOC} - closet row (bedroom-integrated "
                         "clothes storage also satisfies it)"},
}

# Program spaces required beyond apartments, by floor.  `match` predicates
# run against v2 space purpose/class on that floor.
F01_PROGRAM = [
    ("street_vestibule", ["weather lock"], "street entrance and vestibule"),
    ("lobby", ["arrival", "orientation"], "lobby"),
    ("watch_station", ["watch"], "superintendent/watch station"),
    ("mail_telephone", ["mail", "house-line"], "telephone/message custody"),
    ("parcel_package", ["parcel"], "parcel/package storage"),
    ("common_room", ["meeting", "reading"], "common room"),
    ("staff_restroom", ["sanitary"], "staff restroom"),
]
B1_PROGRAM = [
    ("boiler_room", ["heat", "boiler", "firing"], "boiler room"),
    ("coal_room", ["fuel", "coal"], "coal room"),
    ("electrical_room", ["switch", "fuse", "electrical"], "electrical room"),
    ("laundry", ["wash", "laundry"], "laundry"),
    ("maintenance_shop", ["repair", "bench", "tool"],
     "maintenance shop/storage"),
    ("resident_storage", ["trunk", "resident storage", "cage"],
     "resident storage"),
]
ROOF_PROGRAM = [
    ("roof_bulkhead", ["bulkhead", "roof access"], "roof service bulkhead"),
    ("tank_machinery", ["tank", "machinery", "lift machine"],
     "tank/lift machinery"),
]

# Per-residential-floor circulation obligations, matched by space class and
# purpose on that floor.
FLOOR_CIRCULATION = [
    ("public_landing", ["decision", "landing"], "corridors and landings"),
    ("public_core", ["passenger lift", "primary stair"], "primary stair + "
     "passenger lift landing"),
    ("service_core", ["service lift", "service stair"],
     "service stair/lift"),
    ("service_route", ["maintenance", "service", "delivery"],
     "maintenance circulation"),
]

# Service continuity systems (program service rows + rebuild checkpoint
# riser matrix).  `riser_classes`/`riser_ids` match v2 riser records;
# absence of any matching riser is ABSENT.
SERVICE_SYSTEMS = [
    ("wet_stack", ["WEST_WET_STACK"], "wet"),
    ("heat_stack", ["HEAT_STACK"], "service"),
    ("telephone_riser", ["TELEPHONE_MESSAGE_RISER"], "service"),
    ("passenger_lift", ["PASSENGER_LIFT_SHAFT"], "core"),
    ("service_lift", ["SERVICE_LIFT_SHAFT"], "core"),
    ("electrical_riser", [], "electrical"),
    ("fire_service", [], "fire"),
]

# First-slice cutover blockers named by the M08D runtime-parity checkpoint
# ("build and accept the existing F01 ritual desk identities plus 2B and
# B1 service route before requesting selector cutover").
RITUAL_IDENTITIES = ["F01_WATCHMAN_DETECTOR", "F01_NIGHT_REGISTER",
                     "F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD"]

# The twelve identities whose unique runtime resolution M08A/M08D proved
# (design/ORISON_V2_M08D_RUNTIME_PARITY_CHECKPOINT_2026-08-28.md).
M08D_PROVEN_PARITY_IDS = [
    "F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
    "F02_A_MAIN_VANTRY_POINT", "F02_A_MONITOR_01", "F04_B_MONITOR_01",
    "F04_B_BED", "F04_B_BEDSIDE_RETURN", "LobbyMailBank",
    "LobbyPorterBoard", "F01_HOUSE_TELEPHONE_BOARD",
    "LobbyServiceDumbwaiter"]

# --- Chronological evidence policy -----------------------------------
# Milestone documents carry an epoch derived from their name (longest
# marker wins).  A checkpoint stating an identifier is ABSENT is negative
# evidence AS OF ITS EPOCH: it suppresses backtick mentions from the same
# or earlier epochs (reported as conflicts, never silently resolved) and
# is superseded by genuinely later evidence.  A historical mention alone
# never becomes positive proof: backtick mentions in ANY checkpoint cap
# at SPATIALLY_PROVEN.  RUNTIME_PROVEN comes only from (a) the curated
# M08D twelve-anchor census, or (b) a runtime-composition checkpoint's
# structured claims (identifier + production authority + save/durable
# owner + teardown owner in its composition table) validated by that
# packet's passing runtime_authority_receipt.json.
DOC_EPOCH_MARKERS = [
    ("SCHEMA_GENERATOR", 0), ("VERTICAL_CORE", 1), ("GRAYBOX", 2),
    ("M08E_A", 8), ("M08F", 9), ("M08E", 7), ("M08D", 6), ("M08C", 5),
    ("M08A", 4), ("M09", 10), ("M08", 3),
]

# --- Evidence intake policy -------------------------------------------
# WHAT IS ALLOWED TO PROVE SOMETHING.
#
# This used to be `design/ORISON_V2_*.md` minus an ad-hoc "COMPLETENESS"
# exclusion, which meant a document satisfied the requirements it merely
# DESCRIBED: a report, a census, a handoff or an audit that backticked a
# space id promoted that space.  Two documents did exactly that, one of
# them shipped.  Prose about the building is not the building.
#
# Intake is therefore an explicit allowlist of what a document CLAIMS TO
# BE, read from its name: a checkpoint (a milestone's own record of what
# was built and proved) or an acceptance receipt (a human verdict).
# Everything else that matches the family glob is reported as
# `not evidence` rather than dropped silently — see --verbose and the
# `evidence_intake` block of --json.  Adding a marker here grants real
# promoting power, so add one only for a document class that is itself
# proof.
EVIDENCE_NAME_MARKERS = (
    "CHECKPOINT",        # every milestone/gray-box/vertical-core record
    "GRAYBOX",           # a gray-box record not named ...CHECKPOINT...
    "ACCEPTANCE",        # acceptance hardening and human acceptance
    "RECEIPT",           # human acceptance receipts carried as prose
    "VERTICAL_CORE",     # the vertical-core milestone record
    "SCHEMA_GENERATOR",  # the generator milestone record
)
# Reported as the reason in `not evidence` lines, longest match first so
# the most specific description of a document wins.
NON_EVIDENCE_KINDS = [
    ("COMPLETENESS_LEDGER_GUIDE", "this tool's own usage guide"),
    ("COMPLETENESS_AUDIT", "this tool's own companion report"),
    ("READINESS_AUDIT", "audit prose, not a milestone record"),
    ("CONSUMER_CENSUS", "census prose, not a milestone record"),
    ("COMPOSITION_CENSUS", "census prose, not a milestone record"),
    ("CENSUS", "census prose, not a milestone record"),
    ("HANDOFF", "work order for a future milestone"),
    ("DIMENSIONED_SCHEDULE", "construction basis authored ahead of the "
                             "schema; a plan, not a proof"),
    ("RUNWAY_REPORT", "report prose, not a milestone record"),
    ("REPORT", "report prose, not a milestone record"),
    ("AUDIT", "audit prose, not a milestone record"),
    ("GUIDE", "documentation, not a milestone record"),
]


def evidence_marker(name: str) -> str | None:
    """The allowlist marker that admits this document as evidence, or
    None.  Name-only: an excluded document is never even read, so it
    cannot influence a conclusion by accident."""
    for marker in EVIDENCE_NAME_MARKERS:
        if marker in name:
            return marker
    return None


def non_evidence_reason(name: str) -> str:
    for marker, reason in NON_EVIDENCE_KINDS:
        if marker in name:
            return reason
    return "not a checkpoint or acceptance receipt"


def doc_epoch(name: str) -> int:
    for marker, epoch in DOC_EPOCH_MARKERS:
        if marker in name:
            return epoch
    return 2


NEGATIVE_EVIDENCE = {
    "M08C": set(RITUAL_IDENTITIES) | {"B1_BOILER_01",
                                      "F02_B_RADIATOR_01"},
    "M08D": set(RITUAL_IDENTITIES) | {"B1_BOILER_01",
                                      "F02_B_RADIATOR_01"},
}

ACCEPTANCE_DOC_RE = re.compile(r"HUMAN_ACCEPTANCE|ACCEPTANCE_RECEIPT")
RUNTIME_COMPOSITION_DOC_RE = re.compile(r"RUNTIME_COMPOSITION")
AT_ID_RE = re.compile(r"at `([A-Za-z0-9_]+)`")
PACKET_DIR_RE = re.compile(r"art/renders/orison_v2/([A-Za-z0-9_]+)/")

# Human-acceptance receipts state their accepted subjects in prose the
# tool cannot parse; this curated mapping is the reviewed machine
# encoding of each receipt's scope (rule: later human acceptance may
# satisfy the relevant SPATIAL-acceptance requirement — it can raise an
# existing PROGRAMMED requirement to SPATIALLY_PROVEN, and never
# conjures absent geometry or runtime proof).
ACCEPTANCE_GRANTS = {
    "M08E_A_HUMAN_ACCEPTANCE_RECEIPT": {
        "requirements": ["floor.B1", "unit.2B", "b1.boiler_room"],
        "grants": "SPATIALLY_PROVEN",
        "rationale": "Owner accepted the F01 ritual station, apartment "
                     "2B radiator service stance and B1 boiler route as "
                     "a gray-box spatial contract (authorizes M08F "
                     "only; not M09/cutover/retirement).",
    },
}
CUTOVER_UNITS = {"2B"}
CUTOVER_FLOORS = {"B1"}
CUTOVER_SERVICE_IDS = ["B1_BOILER_01", "F02_B_RADIATOR_01",
                       "LobbyPorterBoard"]

# Exact unit->v2 prefix map confirmed by the gray-box checkpoints; any
# other unit resolved by grammar is labeled heuristic.
UNIT_PREFIX_EXACT = {
    "2A": ("F02_A_", "design/ORISON_V2_F02_2A_GRAYBOX_CHECKPOINT_"
                     "2026-08-28.md"),
    "4B": ("F04_B_", "design/ORISON_V2_F04_4B_GRAYBOX_CHECKPOINT_"
                     "2026-08-28.md"),
}

# v1 room -> v2 space aliases (renames/subdivisions) grounded in the
# rebuild checkpoint's room schedule; used for coverage bookkeeping only,
# never for status promotion.
V1_TO_V2_ALIASES = {
    "F01_OFFICE": ["F01_WATCH"],
    "F01_HALL": ["F01_SERVICE_HALL", "F01_CORE_TO_SERVICE"],
    "F01_PACKAGE": ["F01_PACKAGE"],
    "F01_COMMON_B": ["F01_COMMON_B"],
    "F02_CORRIDOR": ["F02_LANDING", "F02_WEST_HALL"],
    "F04_CORRIDOR": ["F04_LANDING", "F04_WEST_HALL"],
}

# Acoustic/service pseudo-rooms: graph vocabulary, not building rooms.
PSEUDO_ROOM_RE = re.compile(
    r"_NAVIGATION$|_ATRIUM_FRUIT_|^PASSAGE|^SITE_|_VANTRY_TRUNK$|"
    r"_V_[A-D]_RISER$")

BACKTICK_RE = re.compile(r"`([A-Za-z0-9_./-]+)`")
GD_STRING_RE = re.compile(r'"([A-Za-z0-9_]+)"')


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path, what: str) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise AuditError(f"cannot read {what} {path}: {exc}")
    except json.JSONDecodeError as exc:
        raise AuditError(f"malformed {what} {path}: {exc}")


# ---------------------------------------------------------------------------
# Input assembly
# ---------------------------------------------------------------------------

class Inputs:
    def __init__(self, root: Path, args):
        self.root = root
        self.provenance: dict[str, str] = {}
        self.admitted_evidence: list[dict] = []

        v1_path = Path(args.v1_layout) if args.v1_layout else None
        if v1_path is None:
            for candidate in DEFAULT_V1:
                if (root / candidate).is_file():
                    v1_path = root / candidate
                    break
            if v1_path is None:
                raise AuditError("no v1 building_layout.json found; pass "
                                 "--v1-layout")
        elif not v1_path.is_absolute():
            v1_path = root / v1_path
        self.v1 = load_json(v1_path, "v1 layout")
        self._record(v1_path)

        v2_path = Path(args.v2_layout) if args.v2_layout else root / \
            DEFAULT_V2
        if not v2_path.is_absolute():
            v2_path = root / v2_path
        self.v2 = load_json(v2_path, "v2 layout") if v2_path.is_file() \
            else {}
        if v2_path.is_file():
            self._record(v2_path)
        if self.v2 and not isinstance(self.v2.get("spaces"), list):
            raise AuditError(f"malformed v2 layout {v2_path}: no spaces "
                             "list")

        design_dir = Path(args.design_dir) if args.design_dir else \
            root / DEFAULT_DESIGN
        if not design_dir.is_absolute():
            design_dir = root / design_dir
        self.design_dir = design_dir

        manifest_path = Path(args.dependency_manifest) if \
            args.dependency_manifest else root / DEFAULT_MANIFEST
        if not manifest_path.is_absolute():
            manifest_path = root / manifest_path
        self.manifest = load_json(manifest_path, "dependency manifest") \
            if manifest_path.is_file() else {"records": []}
        if manifest_path.is_file():
            self._record(manifest_path)

        self.acceptances = []
        if args.acceptance:
            acc = Path(args.acceptance)
            if not acc.is_absolute():
                acc = root / acc
            self.acceptances = [acc]
        elif design_dir.is_dir():
            self.acceptances = sorted(
                design_dir.glob("ORISON_V2_*HUMAN_ACCEPTANCE*.json"))
        self.acceptance_records = []
        for acc in self.acceptances:
            record = load_json(acc, "acceptance receipt")
            record["_file"] = acc.relative_to(root).as_posix() \
                if acc.is_relative_to(root) else str(acc)
            self.acceptance_records.append(record)
            self._record(acc)

        self.checkpoints = []
        self.non_evidence: list[dict] = []
        exclude = getattr(args, "_exclude_doc", None)
        if design_dir.is_dir():
            for doc in sorted(design_dir.glob("ORISON_V2_*.md")):
                rel = doc.relative_to(root).as_posix() \
                    if doc.is_relative_to(root) else str(doc)
                if exclude is not None and doc.resolve() == exclude:
                    continue
                marker = evidence_marker(doc.name)
                if marker is None:
                    # Named, never read: an excluded document cannot
                    # influence a conclusion even by accident.
                    self.non_evidence.append(
                        {"file": rel,
                         "reason": non_evidence_reason(doc.name)})
                    continue
                text = doc.read_text(encoding="utf-8", errors="replace")
                self.checkpoints.append((rel, text))
                self.admitted_evidence.append(
                    {"file": rel, "marker": marker,
                     "epoch": doc_epoch(doc.name)})
                self._record(doc)

        contract = design_dir / Path(CONTRACT_DOC).name
        self.contract_ids: list[str] = []
        if contract.is_file():
            self._record(contract)
            for line in contract.read_text(encoding="utf-8").splitlines():
                if line.startswith("| `"):
                    tokens = BACKTICK_RE.findall(line.split("|")[1])
                    self.contract_ids.extend(
                        t for t in tokens
                        if re.fullmatch(r"[A-Za-z0-9_-]+", t))
        self.contract_ids = sorted(set(self.contract_ids))

        adapter = root / ADAPTER_PATH
        self.adapter_required: list[str] = []
        if adapter.is_file():
            self._record(adapter)
            text = adapter.read_text(encoding="utf-8")
            m = re.search(r"REQUIRED[^=]*=\s*\[(.*?)\]", text, re.DOTALL)
            if m:
                self.adapter_required = GD_STRING_RE.findall(m.group(1))

        self.receipts = []
        self.runtime_receipts = []
        receipts_dir = root / RECEIPT_GLOB
        if receipts_dir.is_dir():
            for receipt in sorted(
                    receipts_dir.glob("*/scene_capture_receipt.json")):
                data = load_json(receipt, "capture receipt")
                data["_file"] = receipt.relative_to(root).as_posix()
                self.receipts.append(data)
                self._record(receipt)
            for receipt in sorted(receipts_dir.glob(
                    "*/runtime_authority_receipt.json")):
                data = load_json(receipt, "runtime authority receipt")
                records = data.get("records", [])
                valid = (data.get("production_runtime") is True and
                         str(data.get("selector")) == "v2" and
                         bool(records) and
                         all(str(r.get("capture", "")).upper() == "PASS"
                             for r in records))
                if valid:
                    data["_file"] = receipt.relative_to(root).as_posix()
                    data["_dir"] = receipt.parent.name
                    self.runtime_receipts.append(data)
                self._record(receipt)

    def _record(self, path: Path) -> None:
        rel = path.relative_to(self.root).as_posix() \
            if path.is_relative_to(self.root) else str(path)
        self.provenance[rel] = sha256_file(path)


# ---------------------------------------------------------------------------
# v2 model
# ---------------------------------------------------------------------------

class V2Model:
    def __init__(self, v2: dict):
        self.raw = v2
        self.spaces = {s["id"]: s for s in v2.get("spaces", [])}
        self.doors = {d["id"]: d for d in v2.get("doors", [])}
        self.openings = {o["id"]: o for o in v2.get("openings", [])}
        self.anchors = {a["id"]: a for a in v2.get("anchors", [])}
        self.risers = {r["id"]: r for r in v2.get("risers", [])}
        self.stairs = {s["id"]: s for s in v2.get("stairs", [])}
        self.lift_landings = {x["id"]: x
                              for x in v2.get("lift_landings", [])}
        self.levels = {lv["id"]: lv for lv in v2.get("levels", [])}
        self.connected: dict[str, set] = {}
        for record in list(self.doors.values()) + \
                list(self.openings.values()):
            pair = record.get("connects", [])
            for space in pair:
                self.connected.setdefault(space, set()).update(
                    p for p in pair if p != space)
        self.all_ids = set(self.spaces) | set(self.doors) | \
            set(self.openings) | set(self.anchors) | set(self.risers) | \
            set(self.stairs) | set(self.lift_landings) | set(self.levels)
        self.vertical_levels: set = set()
        for stair in self.stairs.values():
            self.vertical_levels.update(
                {stair.get("from"), stair.get("to")} - {None})
        for landing in self.lift_landings.values():
            if landing.get("level"):
                self.vertical_levels.add(landing["level"])

    def spaces_on(self, level: str) -> list[dict]:
        return [s for s in self.spaces.values()
                if s.get("level") == level]

    def space_status(self, space: dict) -> tuple[str, str]:
        """Base geometric status of one space with a reason."""
        sid = space["id"]
        if space.get("open_shell"):
            return "SHELL_ONLY", "declared open_shell in the v2 schema"
        if not str(space.get("purpose", "")).strip():
            return "SHELL_ONLY", "no purpose recorded"
        if sid not in self.connected:
            if str(space.get("class")) == "core" and \
                    space.get("level") in self.vertical_levels:
                return "PROGRAMMED", ("vertical entrance via stair/lift "
                                      "records on this level")
            return "SHELL_ONLY", "no door or cased opening connects it"
        return "PROGRAMMED", "class + purpose + entrance present"

    def anchor_space(self, anchor: dict):
        """Containing programmed space, by level + position point test."""
        pos = anchor.get("position")
        level = anchor.get("level")
        if not pos or level is None:
            return None
        x, z = float(pos[0]), float(pos[2])
        for space in self.spaces_on(level):
            rect = space.get("rect")
            if rect and rect[0] <= x <= rect[2] and rect[1] <= z <= rect[3]:
                return space
        return None


# ---------------------------------------------------------------------------
# Evidence index (checkpoints, receipts, acceptance, manifest)
# ---------------------------------------------------------------------------

def parse_composition_claims(text: str) -> list[dict]:
    """Structured claims from a runtime-composition checkpoint table.

    A claim requires, in one table row: the composed identifier
    (``at `ID```), a backticked production authority class, a non-empty
    durable/save-owner cell and a non-empty teardown-owner cell.  A bare
    mention of an id anywhere else in the document is NOT a claim.
    """
    claims = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        if len(cells) < 5:
            continue
        row_text = " ".join(cells)
        id_match = AT_ID_RE.search(row_text)
        if not id_match:
            continue
        identifier = id_match.group(1)
        classes = [t for t in BACKTICK_RE.findall(row_text)
                   if t != identifier]
        owner_cell = cells[3]
        teardown_cell = cells[4]
        if classes and owner_cell and teardown_cell and \
                owner_cell != "---":
            claims.append({"id": identifier,
                           "authority": classes[0],
                           "owner": owner_cell[:80],
                           "teardown": teardown_cell[:80]})
    return claims


class Evidence:
    def __init__(self, inputs: Inputs, model: V2Model):
        self.by_token: dict[str, list[dict]] = {}
        self.stale: list[dict] = []
        self.docs: list[dict] = []
        self.conflicts: list[dict] = []
        self.acceptance_docs: list[dict] = []
        neg_epoch: dict[str, int] = {}
        for pattern, negatives in NEGATIVE_EVIDENCE.items():
            for token in negatives:
                for rel, _text in inputs.checkpoints:
                    if pattern in Path(rel).name:
                        neg_epoch[token] = max(
                            neg_epoch.get(token, -1),
                            doc_epoch(Path(rel).name))

        for rel, text in inputs.checkpoints:
            name = Path(rel).name
            epoch = doc_epoch(name)
            acceptance = bool(ACCEPTANCE_DOC_RE.search(name))
            composition = bool(RUNTIME_COMPOSITION_DOC_RE.search(name))
            status_line = next(
                (ln.strip() for ln in text.splitlines()
                 if ln.strip().lower().startswith("status:")), "")
            tokens = sorted({t for t in BACKTICK_RE.findall(text)
                             if re.fullmatch(r"[A-Z0-9][A-Za-z0-9_]+", t)})
            self.docs.append({"file": rel, "epoch": epoch,
                              "kind": "acceptance" if acceptance else
                              "runtime_composition" if composition else
                              "checkpoint",
                              "status_line": status_line,
                              "tokens": len(tokens)})
            if acceptance:
                # Human-acceptance documents accept, they do not
                # enumerate proof; verdict handled via ACCEPTANCE_GRANTS.
                self.acceptance_docs.append({
                    "file": rel, "name": name, "epoch": epoch,
                    "verdict_pass": bool(re.search(
                        r"Verdict:.*PASS", text, re.IGNORECASE))})
                continue
            for token in tokens:
                if token not in model.all_ids and \
                        token not in RITUAL_IDENTITIES:
                    if re.match(r"^(B1|F0\d|ROOF)_", token) or \
                            token.startswith("Lobby"):
                        self.stale.append(
                            {"token": token, "source": rel,
                             "note": "checkpointed identifier absent "
                                     "from current v2 layout"})
                    continue
                suppressed_until = neg_epoch.get(token, -1)
                if epoch <= suppressed_until:
                    # Same-era or earlier mention alongside a statement
                    # of absence: visible conflict, never proof.
                    self.conflicts.append({
                        "token": token, "source": rel, "epoch": epoch,
                        "negative_epoch": suppressed_until,
                        "note": "mention suppressed by same-era or "
                                "later statement of absence"})
                    continue
                # A backtick mention - in ANY checkpoint, of any era -
                # caps at spatial proof.  Runtime proof needs the census
                # or a structured composition claim below.
                self.by_token.setdefault(token, []).append(
                    {"tier": "SPATIALLY_PROVEN", "source": rel,
                     "epoch": epoch, "channel": "mention"})

            if composition:
                packet_names = set(PACKET_DIR_RE.findall(text))
                receipt_ok = any(
                    r["_dir"] in packet_names
                    for r in inputs.runtime_receipts)
                for claim in parse_composition_claims(text):
                    token = claim["id"]
                    if token not in model.all_ids:
                        continue
                    if not receipt_ok:
                        self.conflicts.append({
                            "token": token, "source": rel,
                            "epoch": epoch, "negative_epoch": -1,
                            "note": "composition claim without a "
                                    "passing runtime authority "
                                    "receipt"})
                        continue
                    self.by_token.setdefault(token, []).append(
                        {"tier": "RUNTIME_PROVEN", "source": rel,
                         "epoch": epoch, "channel": "claim",
                         "authority": claim["authority"],
                         "owner": claim["owner"]})

        # Deduplicate stale/conflict rows.
        def dedupe(rows, keys):
            seen, unique = set(), []
            for row in rows:
                key = tuple(row[k] for k in keys)
                if key not in seen:
                    seen.add(key)
                    unique.append(row)
            return sorted(unique, key=lambda r: tuple(
                str(r[k]) for k in keys))
        self.stale = dedupe(self.stale, ("token", "source"))
        self.conflicts = dedupe(self.conflicts, ("token", "source"))

        # M08A/M08D proved exactly twelve parity identities resolving
        # uniquely under the selected root; that census is exact runtime
        # evidence for THOSE ids when they exist in the current layout.
        # Ids added to the adapter REQUIRED list later earn runtime
        # proof only from their own runtime-composition claims - a
        # longer REQUIRED list is not retroactive proof.
        if any(d["kind"] != "acceptance" and d["epoch"] >= 3
               for d in self.docs):
            for token in M08D_PROVEN_PARITY_IDS:
                if token in inputs.adapter_required and \
                        token in model.all_ids:
                    self.by_token.setdefault(token, []).append(
                        {"tier": "RUNTIME_PROVEN",
                         "source": "M08D twelve-anchor census + adapter "
                                   "REQUIRED",
                         "epoch": 6, "channel": "census"})

        self.receipts = inputs.receipts
        self.acceptances = inputs.acceptance_records
        self.route_accepted = any(
            str(a.get("verdict", "")).upper() == "PASS"
            for a in self.acceptances)

        # v1 fallbacks and preserved contracts from the dependency
        # manifest.
        self.v1_fallbacks: list[dict] = []
        self.manifest_preserved: set = set()
        for record in inputs.manifest.get("records", []):
            rationale = str(record.get("rationale", ""))
            if "V1-ONLY" in rationale or "v1 fallback" in rationale.lower():
                self.v1_fallbacks.append({
                    "token": record.get("token"),
                    "file": record.get("file"),
                    "rationale": rationale[:160]})
            if record.get("disposition") == "MUST_PRESERVE_ID" and \
                    record.get("tier") in ("production", "data"):
                self.manifest_preserved.add(record.get("token"))

    def tier_for(self, token: str):
        """Best committed proof tier for one identifier (exact only)."""
        best = None
        sources = []
        for entry in self.by_token.get(token, []):
            sources.append(entry["source"])
            if best is None or RANK[entry["tier"]] > RANK[best]:
                best = entry["tier"]
        return best, sorted(set(sources))


# ---------------------------------------------------------------------------
# Requirement evaluation
# ---------------------------------------------------------------------------

def match_purpose(space: dict, keywords: list[str],
                  classes: list[str] | None = None) -> bool:
    """Contiguous-phrase containment, for the floor/service program tables.

    The domestic minimums deliberately do NOT use this - see
    match_purpose_words.  These tables keep phrase containment because
    their keywords are single words or fixed compound names ("passenger
    lift", "primary stair") where word order carries the meaning, and
    because changing them is a separate enumeration.
    """
    purpose = str(space.get("purpose", "")).lower()
    if classes and str(space.get("class", "")).lower() in classes:
        return True
    return any(k in purpose for k in keywords)


PURPOSE_WORD_RE = re.compile(r"[a-z0-9]+")


def purpose_words(space: dict) -> list[str]:
    return PURPOSE_WORD_RE.findall(str(space.get("purpose", "")).lower())


def match_purpose_words(space: dict, groups: list[list[str]],
                        classes: list[str] | None = None) -> bool:
    """Word-set predicate for the apartment domestic minimums.

    A space satisfies the function when every word of at least one group
    appears in its purpose, in any order, regardless of the punctuation
    and connectives between them.  Each word matches a purpose word that
    STARTS with it, so authored English inflections still count:
    "player sleeping context" satisfies sleep, exactly as it did under
    phrase containment.

    Prefix rather than whole-word equality is deliberate and was measured
    - requiring equality would have regressed F04_B_ALCOVE,
    F04_B_ALCOVE_APPROACH and F04_B_PRIVATE_HALL, all of which say
    "sleeping".  Matching is still on the space's own purpose/class only,
    never on its id.
    """
    if classes and str(space.get("class", "")).lower() in classes:
        return True
    words = purpose_words(space)
    return any(
        all(any(word.startswith(term) for word in words) for term in group)
        for group in groups)


class Ledger:
    def __init__(self, inputs: Inputs):
        self.inputs = inputs
        self.model = V2Model(inputs.v2)
        self.evidence = Evidence(inputs, self.model)
        self.requirements: list[dict] = []
        self.anchor_only: list[dict] = []
        self._build()

    # -- helpers ----------------------------------------------------------
    def add(self, dimension: str, req_id: str, scope: dict, status: str,
            required: str, provenance: list, notes: str = "",
            heuristic: bool = False, v1_fallback: bool = False,
            blocked_by: list | None = None, cutover_blocking: bool = False,
            not_required: bool = False, fallback_kind: str = "absence"):
        # `cutover_blocking` is retained for call-site readability only;
        # actual blocking is scope-derived in assign_scopes().
        del cutover_blocking
        self.requirements.append({
            "id": req_id,
            "dimension": dimension,
            "scope": scope,
            "status": "NOT_REQUIRED" if not_required else status,
            "required_proof": required,
            "temporary_v1_fallback": v1_fallback,
            "fallback_kind": fallback_kind if v1_fallback else None,
            "blocked_by": blocked_by or [],
            "heuristic": heuristic,
            "provenance": provenance,
            "notes": notes,
        })

    def space_attained(self, space_id: str) -> tuple[str, list, str]:
        """Status ladder for one v2 space id, with provenance."""
        space = self.model.spaces.get(space_id)
        if space is None:
            return "ABSENT", [], "no v2 space record"
        base, why = self.model.space_status(space)
        prov = [f"v2:{space_id} ({why})"]
        tier, sources = self.evidence.tier_for(space_id)
        if base == "PROGRAMMED" and tier:
            prov += [f"checkpoint:{s}" for s in sources]
            return tier, prov, why
        return base, prov, why

    def unit_spaces(self, unit: str) -> tuple[list, bool, str]:
        exact = UNIT_PREFIX_EXACT.get(unit)
        if exact:
            prefix, source = exact
            heuristic = False
        else:
            floor_no, letter = unit[0], unit[1]
            prefix = f"F0{floor_no}_{letter}_"
            source = "unit-id grammar (heuristic)"
            heuristic = True
        spaces = [s for sid, s in sorted(self.model.spaces.items())
                  if sid.startswith(prefix)]
        return spaces, heuristic, source

    # -- construction -----------------------------------------------------
    def _build(self):
        self._dim_site_street()
        self._dim_f01()
        self._dim_circulation()
        self._dim_floors_and_units()
        self._dim_b1_roof()
        self._dim_services()
        self._dim_contracts()
        self._dim_jobs_cases()
        self._dim_acoustic()
        self._dim_save_wake()
        self._dim_interaction()
        self._dim_readability_evidence()
        self._dim_selector()
        self._dim_furnishing()
        self._dim_golden_and_retirement()
        self._find_anchor_only()
        self._apply_acceptance_grants()
        for record in self.requirements:
            assign_scopes(record)

    def _apply_acceptance_grants(self):
        """Rule 3: later human acceptance satisfies the relevant
        SPATIAL-acceptance requirement.  It raises an existing
        PROGRAMMED requirement to the granted spatial tier - it never
        conjures absent geometry, and never grants runtime proof."""
        by_id = {r["id"]: r for r in self.requirements}
        for name_pattern, grant in ACCEPTANCE_GRANTS.items():
            docs = [d for d in self.evidence.acceptance_docs
                    if name_pattern in d["name"] and d["verdict_pass"]]
            if not docs:
                continue
            target = grant["grants"]
            for rid in grant["requirements"]:
                record = by_id.get(rid)
                if record is None:
                    continue
                current = RANK.get(record["status"], -1)
                if current < RANK["PROGRAMMED"] or \
                        current >= RANK[target]:
                    continue
                record["status"] = target
                record["provenance"] = record["provenance"] + [
                    f"acceptance:{d['file']} ({grant['rationale']})"
                    for d in docs]

    def _dim_golden_and_retirement(self):
        golden = [a for a in self.evidence.acceptances
                  if "golden" in (str(a.get("receipt_type", "")) +
                                  str(a.get("scope", ""))).lower()
                  and str(a.get("verdict", "")).upper() == "PASS"]
        self.add("15/19 golden shift", "golden.eleven_beats",
                 {"scope": "eleven golden-shift beats under explicit v2 "
                           "selection"},
                 "HUMAN_ACCEPTED" if golden else "ABSENT",
                 "HUMAN_ACCEPTED",
                 [f"acceptance:{a['_file']}" for a in golden] or
                 ["derived: no golden-shift acceptance receipt exists"],
                 notes="Requires the authored eleven-beat run under the "
                       "explicit v2 selector with the four-row K3 "
                       "evidence schema; never a default-flip "
                       "authorization.")
        retired = [a for a in self.evidence.acceptances
                   if isinstance(a.get("authorization"), dict) and
                   a["authorization"].get("v1_retirement") is True]
        self.add("21 reversible selector and v1 fallback",
                 "retirement.authorization",
                 {"scope": "owner retirement authorization"},
                 "HUMAN_ACCEPTED" if retired else "ABSENT",
                 "HUMAN_ACCEPTED",
                 [f"acceptance:{a['_file']}" for a in retired] or
                 ["derived: no acceptance receipt carries "
                  "authorization.v1_retirement=true"],
                 notes="v1 retires only after the rollback window and an "
                       "explicit owner authorization receipt.")

    def _dim_site_street(self):
        status, prov, _ = self.space_attained("F01_STREET_APRON")
        door = "F01_DOOR_06" in self.model.doors
        if door:
            prov = prov + ["v2:F01_DOOR_06 (street threshold door)"]
        tier, sources = self.evidence.tier_for("F01_DOOR_06")
        if door and tier and RANK[tier] > RANK.get(status, 0):
            status = tier
            prov += [f"checkpoint:{s}" for s in sources]
        self.add("01 site and street", "site.street_threshold",
                 {"kind": "site"}, status if door else "ABSENT",
                 "RUNTIME_PROVEN", prov,
                 notes="Street apron is an open review shell by design; "
                       "the threshold contract is the door identity.",
                 cutover_blocking=not door)

    def _dim_f01(self):
        for key, keywords, label in F01_PROGRAM:
            hits = [s for s in self.model.spaces_on("F01")
                    if match_purpose(s, keywords)]
            if not hits:
                self.add("02 public arrival and F01 program",
                         f"f01.{key}", {"floor": "F01"}, "ABSENT",
                         "RUNTIME_PROVEN",
                         [f"program:{PROGRAM_DOC} ({label})"],
                         notes=f"No F01 space matches the {label} program.",
                         cutover_blocking=key == "watch_station")
                continue
            best = max(hits, key=lambda s: RANK[
                self.space_attained(s["id"])[0]])
            status, prov, _ = self.space_attained(best["id"])
            self.add("02 public arrival and F01 program", f"f01.{key}",
                     {"floor": "F01", "space": best["id"]}, status,
                     "RUNTIME_PROVEN",
                     prov + [f"program:{PROGRAM_DOC} ({label})"])
        # F01 ritual/administrative owners named by M08D.
        for identity in RITUAL_IDENTITIES:
            present = identity in self.model.all_ids
            tier, sources = self.evidence.tier_for(identity)
            self.add("10 F01 administrative/watch functions",
                     f"ritual.{identity}", {"identity": identity},
                     tier if (present and tier) else
                     ("PROGRAMMED" if present else "ABSENT"),
                     "RUNTIME_PROVEN",
                     ([f"v2:{identity}"] if present else []) +
                     [f"checkpoint:{s}" for s in sources] +
                     [f"blocker:{M08D_DOC} (build and accept the F01 "
                      "ritual desk identities before cutover)"],
                     cutover_blocking=True,
                     v1_fallback=not present,
                     notes="" if present else
                     "Served today only by the v1 detail pass.")

    def _dim_circulation(self):
        for floor in RESIDENTIAL_FLOORS + ["F01"]:
            present = floor in self.model.levels
            for key, keywords, label in FLOOR_CIRCULATION:
                if not present:
                    self.add("03/04 circulation", f"circ.{floor}.{key}",
                             {"floor": floor}, "ABSENT", "SPATIALLY_PROVEN",
                             [f"program:{PROGRAM_DOC} ({label})"],
                             blocked_by=[f"floor {floor} absent from v2"])
                    continue
                hits = [s for s in self.model.spaces_on(floor)
                        if match_purpose(s, keywords)]
                if not hits:
                    self.add("03/04 circulation", f"circ.{floor}.{key}",
                             {"floor": floor}, "ABSENT",
                             "SPATIALLY_PROVEN",
                             [f"program:{PROGRAM_DOC} ({label})"])
                    continue
                best = max(hits, key=lambda s: RANK[
                    self.space_attained(s["id"])[0]])
                status, prov, _ = self.space_attained(best["id"])
                self.add("03/04 circulation", f"circ.{floor}.{key}",
                         {"floor": floor, "space": best["id"]}, status,
                         "SPATIALLY_PROVEN",
                         prov + [f"program:{PROGRAM_DOC} ({label})"])

    def _dim_floors_and_units(self):
        residents = self.inputs.v1.get("meta", {}).get("residents", {})
        units = sorted(residents)
        for floor in CANON_FLOORS:
            present = floor in self.model.levels
            level_spaces = self.model.spaces_on(floor) if present else []
            if not present:
                status = "ABSENT"
                prov = ["v2:levels (floor missing)"]
            elif not level_spaces:
                status = "SHELL_ONLY"
                prov = ["v2:levels (level exists, no spaces)"]
            elif all(self.model.space_status(s)[0] == "SHELL_ONLY"
                     for s in level_spaces):
                status = "SHELL_ONLY"
                prov = [f"v2:{floor} (all spaces are shells)"]
            else:
                # Deliberate open shells (aprons, landing voids) do not
                # drag the floor down; undeclared-entrance shells do.
                considered = [s for s in level_spaces
                              if not s.get("open_shell")]
                statuses = [self.space_attained(s["id"])[0]
                            for s in considered]
                status = min(statuses, key=lambda s: RANK[s])
                weakest = sorted(
                    s["id"] for s in considered
                    if self.space_attained(s["id"])[0] == status)
                prov = [f"v2:{floor} ({len(level_spaces)} spaces; "
                        f"weakest {status}: {', '.join(weakest[:4])})"]
            self.add("05 canonical floors", f"floor.{floor}",
                     {"floor": floor}, status, "SPATIALLY_PROVEN", prov,
                     cutover_blocking=floor in CUTOVER_FLOORS,
                     notes="Core-transfer-only level" if floor == "F03" and
                     present and len(level_spaces) <= 2 else "")

        for unit in units:
            floor = f"F0{unit[0]}"
            sealed = unit in SEALED_UNITS
            spaces, heuristic, source = self.unit_spaces(unit)
            if not spaces:
                blocked = [] if floor in self.model.levels else \
                    [f"floor {floor} absent from v2"]
                self.add("06 canonical units", f"unit.{unit}",
                         {"unit": unit, "floor": floor},
                         "ABSENT",
                         "PROGRAMMED" if sealed else "SPATIALLY_PROVEN",
                         [f"v1:meta.residents ({unit})",
                          f"map:{source}"],
                         heuristic=heuristic, blocked_by=blocked,
                         cutover_blocking=unit in CUTOVER_UNITS,
                         notes=("Sealed unit: only the public threshold "
                                "is required until a case opens it."
                                if sealed else ""))
                continue
            worst = min((self.space_attained(s["id"])[0] for s in spaces),
                        key=lambda s: RANK[s])
            best = max((self.space_attained(s["id"])[0] for s in spaces),
                       key=lambda s: RANK[s])
            self.add("06 canonical units", f"unit.{unit}",
                     {"unit": unit, "floor": floor,
                      "spaces": [s["id"] for s in spaces]},
                     worst,
                     "PROGRAMMED" if sealed else "SPATIALLY_PROVEN",
                     [f"map:{source}",
                      f"v2:{len(spaces)} spaces (weakest {worst}, "
                      f"best {best})"],
                     heuristic=heuristic,
                     cutover_blocking=unit in CUTOVER_UNITS)
            if sealed:
                continue
            # Function minimums, matched on purpose/class only.
            for func, spec in sorted(UNIT_FUNCTIONS.items()):
                hits = [s for s in spaces if match_purpose_words(
                    s, spec.get("word_groups", []),
                    spec.get("class_any"))]
                if hits:
                    hit = max(hits, key=lambda s: RANK[
                        self.space_attained(s["id"])[0]])
                    status, prov, _ = self.space_attained(hit["id"])
                    self.add("07 domestic minimums",
                             f"unit.{unit}.{func}",
                             {"unit": unit, "space": hit["id"]},
                             status, "SPATIALLY_PROVEN",
                             prov + [spec["basis"]], heuristic=heuristic)
                else:
                    self.add("07 domestic minimums",
                             f"unit.{unit}.{func}",
                             {"unit": unit}, "ABSENT", "SPATIALLY_PROVEN",
                             [spec["basis"]], heuristic=heuristic,
                             notes=f"No {func} purpose among this unit's "
                                   "v2 spaces.")

    def _dim_b1_roof(self):
        for floor, program in (("B1", B1_PROGRAM), ("ROOF", ROOF_PROGRAM)):
            present = floor in self.model.levels
            for key, keywords, label in program:
                hits = [s for s in self.model.spaces_on(floor)
                        if match_purpose(s, keywords)] if present else []
                if hits:
                    best = max(hits, key=lambda s: RANK[
                        self.space_attained(s["id"])[0]])
                    status, prov, _ = self.space_attained(best["id"])
                    self.add("11 maintenance/service spaces",
                             f"{floor.lower()}.{key}",
                             {"floor": floor, "space": best["id"]},
                             status, "SPATIALLY_PROVEN",
                             prov + [f"program:{PROGRAM_DOC} ({label})"])
                else:
                    self.add("11 maintenance/service spaces",
                             f"{floor.lower()}.{key}", {"floor": floor},
                             "ABSENT", "SPATIALLY_PROVEN",
                             [f"program:{PROGRAM_DOC} ({label})"],
                             blocked_by=[] if present else
                             [f"floor {floor} absent from v2"],
                             cutover_blocking=(floor == "B1" and key ==
                                               "boiler_room"))

    def _dim_services(self):
        built_levels = sorted(self.model.levels)
        for key, riser_ids, riser_class in SERVICE_SYSTEMS:
            risers = [self.model.risers[r] for r in riser_ids
                      if r in self.model.risers]
            if not riser_ids:
                # Systems with no named riser yet (electrical, fire)
                # match by class only.
                risers = [r for r in self.model.risers.values()
                          if r.get("class") == riser_class]
            if not risers:
                self.add("12 service continuity", f"service.{key}",
                         {"system": key}, "ABSENT", "RUNTIME_PROVEN",
                         [f"program:{PROGRAM_DOC} (service rows)",
                          f"schedule:{REBUILD_DOC} (riser matrix)"],
                         notes="No v2 riser/stack record for this system.")
                continue
            spans = all(float(r.get("from_y", 0)) <= -3.2 and
                        float(r.get("to_y", 0)) >= 19.2 for r in risers)
            served = "B1" in built_levels and "ROOF" in built_levels
            status = "PROGRAMMED" if spans else "SHELL_ONLY"
            tier, sources = self.evidence.tier_for(risers[0]["id"])
            if tier and spans:
                status = tier
            self.add("12 service continuity", f"service.{key}",
                     {"system": key,
                      "risers": [r["id"] for r in risers]},
                     status, "RUNTIME_PROVEN",
                     [f"v2:{r['id']} ({r.get('from_y')}..{r.get('to_y')})"
                      for r in risers] +
                     [f"checkpoint:{s}" for s in sources],
                     v1_fallback=not served,
                     notes="" if served else
                     "Full-height reservation, but B1/ROOF endpoints are "
                     "not built - the plant it serves still lives in v1.")

    def _dim_contracts(self):
        for token in self.inputs.contract_ids:
            if not re.match(r"^[A-Z0-9]", token):
                continue  # job/case ids handled in their own dimension
            if re.fullmatch(r"B1|F0\d|ROOF|[1-6][A-D]", token) or \
                    token.startswith("WO-"):
                continue  # floors/units/save aliases have own dimensions
            in_v2 = token in self.model.all_ids
            tier, sources = self.evidence.tier_for(token)
            in_adapter = token in self.inputs.adapter_required
            status = tier if (in_v2 and tier) else (
                "PROGRAMMED" if in_v2 else "ABSENT")
            self.add("13/14 semantic contracts", f"contract.{token}",
                     {"identity": token},
                     status, "RUNTIME_PROVEN",
                     [f"contract:{CONTRACT_DOC}"] +
                     ([f"v2:{token}"] if in_v2 else []) +
                     ([f"adapter:{ADAPTER_PATH} REQUIRED"] if in_adapter
                      else []) +
                     [f"checkpoint:{s}" for s in sources],
                     v1_fallback=not in_v2,
                     cutover_blocking=token in CUTOVER_SERVICE_IDS or
                     token in RITUAL_IDENTITIES,
                     notes="" if in_v2 else
                     "Preserved identity not yet present in v2; consumers "
                     "resolve it only in the v1 root.")

    def _dim_jobs_cases(self):
        jobs = load_scoped_jobs(self.inputs)
        for job_id, unit, anchors in jobs:
            missing = [a for a in anchors if a not in self.model.all_ids]
            unit_spaces, heuristic, _ = self.unit_spaces(unit)
            blocked = []
            if not unit_spaces and unit not in ("",):
                blocked.append(f"unit {unit} absent from v2")
            blocked += [f"anchor {a} absent from v2" for a in missing]
            tier = "RUNTIME_PROVEN" if not blocked and all(
                self.evidence.tier_for(a)[0] == "RUNTIME_PROVEN"
                for a in anchors) else (
                "PROGRAMMED" if not blocked else "ABSENT")
            self.add("15 jobs and case routes", f"job.{job_id}",
                     {"job": job_id, "unit": unit, "anchors": anchors},
                     tier, "RUNTIME_PROVEN",
                     ["data:game/data/maintenance_jobs.json"],
                     blocked_by=blocked, heuristic=heuristic,
                     cutover_blocking=bool(blocked) and
                     unit in CUTOVER_UNITS | {"2A"},
                     v1_fallback=bool(blocked))
        cases = load_scoped_cases(self.inputs)
        for case_id, unit, origin in cases:
            unit_spaces, heuristic, _ = self.unit_spaces(unit)
            origin_ok = origin is None or origin in self.model.all_ids
            blocked = []
            if not unit_spaces:
                blocked.append(f"unit {unit} absent from v2")
            if not origin_ok:
                blocked.append(f"origin node {origin} absent from v2")
            tier, _src = (self.evidence.tier_for(origin)
                          if origin else (None, []))
            status = tier if (not blocked and tier) else (
                "PROGRAMMED" if not blocked else "ABSENT")
            self.add("15 jobs and case routes", f"case.{case_id}",
                     {"case": case_id, "unit": unit, "origin": origin},
                     status, "RUNTIME_PROVEN",
                     ["data:game/data/reality_cases.json"],
                     blocked_by=blocked, heuristic=heuristic,
                     v1_fallback=bool(blocked))

    def _dim_acoustic(self):
        overridden = [t for t in self.inputs.adapter_required
                      if t in self.model.all_ids]
        self.add("16 acoustic topology", "acoustic.v2_rederivation",
                 {"system": "acoustic_graph"},
                 "PROGRAMMED" if overridden else "ABSENT",
                 "RUNTIME_PROVEN",
                 ["data:game/data/acoustic_graph.json (v1-positioned)",
                  f"adapter:{ADAPTER_PATH} (scoped positional overrides "
                  "restore v1 records on teardown)"],
                 v1_fallback=True,
                 notes="Only parity-anchor positions are overridden in "
                       "scope; the 550-node graph remains authored "
                       "against v1 geometry.")

    def _dim_save_wake(self):
        bed = "F04_B_BED" in self.model.all_ids
        stance = "F04_B_BEDSIDE_RETURN" in self.model.all_ids
        tier, sources = self.evidence.tier_for("F04_B_BED")
        fallback_active = any("bed" == f["token"]
                              for f in self.evidence.v1_fallbacks)
        self.add("17 save/wake reconstruction", "save.bedside_return",
                 {"anchors": ["F04_B_BED", "F04_B_BEDSIDE_RETURN"]},
                 tier if (bed and stance and tier) else (
                     "PROGRAMMED" if bed and stance else "ABSENT"),
                 "RUNTIME_PROVEN",
                 [f"checkpoint:{s}" for s in sources] +
                 [f"contract:{CONTRACT_DOC} (explicit anchor + temporary "
                  "fallback)"],
                 v1_fallback=fallback_active,
                 fallback_kind="redundancy",
                 notes="Anonymous v1 'bed' fallback remains committed by "
                       "contract; the v2 path is proven, so this blocks "
                       "only V1_RETIREMENT.")
        # Organism/case save facts need unit geometry to reconstruct.
        absent_case_units = sorted({
            unit for _cid, unit, _o in load_scoped_cases(self.inputs)
            if not self.unit_spaces(unit)[0]})
        self.add("17 save/wake reconstruction", "save.unit_rect_facts",
                 {"absent_units": absent_case_units},
                 "PROGRAMMED" if not absent_case_units else "ABSENT",
                 "RUNTIME_PROVEN",
                 ["manifest:organism_ledger_spatial_payload",
                  "map:case units require v2 flat geometry for "
                  "reconstruction"],
                 v1_fallback=bool(absent_case_units),
                 notes=f"{len(absent_case_units)} case units have no v2 "
                       "geometry; their organism/encroachment facts can "
                       "only reconstruct in the v1 root.")

    def _dim_interaction(self):
        for token in sorted(self.inputs.adapter_required):
            tier, sources = self.evidence.tier_for(token)
            in_v2 = token in self.model.all_ids
            self.add("18 interaction ownership", f"interaction.{token}",
                     {"identity": token},
                     tier if (in_v2 and tier) else (
                         "PROGRAMMED" if in_v2 else "ABSENT"),
                     "RUNTIME_PROVEN",
                     [f"adapter:{ADAPTER_PATH} REQUIRED"] +
                     [f"checkpoint:{s}" for s in sources],
                     v1_fallback=not in_v2)

    def _dim_readability_evidence(self):
        acc = self.evidence.acceptances
        self.add("19 human route readability", "human.route_readability",
                 {"scope": [a.get("scope") for a in acc]},
                 "HUMAN_ACCEPTED" if self.evidence.route_accepted
                 else "ABSENT",
                 "HUMAN_ACCEPTED",
                 [f"acceptance:{a['_file']} (verdict "
                  f"{a.get('verdict')}, commit {a.get('reviewed_commit')})"
                  for a in acc],
                 notes="Scope is route readability only; it accepts no "
                       "room program, milestone or cutover." if acc else
                 "No durable human-acceptance receipt found.")
        passing = [r for r in self.evidence.receipts
                   if str(r.get("status", "")).upper() == "PASS"]
        self.add("20 performance/evidence coverage", "evidence.receipts",
                 {"receipts": [r["_file"] for r in passing]},
                 "RUNTIME_PROVEN" if passing else "ABSENT",
                 "RUNTIME_PROVEN",
                 [f"receipt:{r['_file']} ({r.get('actual_frames')}/"
                  f"{r.get('expected_frames')} frames)" for r in passing],
                 notes="Receipts prove capture integrity for the first "
                       "slice only; whole-building stations do not exist "
                       "yet.")
        floors_done = all(
            RANK.get(r["status"], -1) >= RANK["SPATIALLY_PROVEN"]
            and not r["blocked_by"]
            for r in self.requirements
            if r["id"].startswith("floor."))
        whole_building_acc = any(
            "route" not in str(a.get("scope", "route")).lower()
            for a in acc)
        self.add("20 performance/evidence coverage",
                 "evidence.whole_building_stations",
                 {"scope": "all canonical floors"},
                 "ABSENT" if not floors_done else "PROGRAMMED",
                 "RUNTIME_PROVEN",
                 ["derived: requires every canonical floor built before "
                  "stations can exist"],
                 notes="Whole-building performance/capture stations "
                       "cannot exist while floors are missing.")
        self.add("19 human route readability",
                 "human.whole_building_navigation",
                 {"scope": "all floors, all routes"},
                 "HUMAN_ACCEPTED" if whole_building_acc else "ABSENT",
                 "HUMAN_ACCEPTED",
                 ["derived: needs an acceptance receipt whose scope "
                  "exceeds route readability"],
                 notes="M08A acceptance is explicitly route-scoped; "
                       "whole-building navigation acceptance is a "
                       "separate future receipt.")

    def _dim_selector(self):
        selector = (self.inputs.root /
                    "game/scripts/building/building_root_selector.gd")
        present = selector.is_file()
        self.add("21 reversible selector and v1 fallback",
                 "selector.reversible_two_root", {"kind": "composition"},
                 "RUNTIME_PROVEN" if present else "ABSENT",
                 "RUNTIME_PROVEN",
                 (["source:game/scripts/building/building_root_selector"
                   ".gd (v1 default, session-pinned)"] if present else []) +
                 [f"checkpoint:{M08D_DOC}"],
                 notes="The v1 fallback window is a cutover REQUIREMENT, "
                       "not a debt: it stays until retirement gates pass.")

    def _dim_furnishing(self):
        programmed = [s for s in self.model.spaces.values()
                      if self.model.space_status(s)[0] == "PROGRAMMED"]
        self.add("22 final-furnishing readiness", "furnishing.envelopes",
                 {"programmed_spaces": len(programmed)},
                 "PROGRAMMED" if programmed else "ABSENT",
                 "PROGRAMMED",
                 ["v2:fixed-use envelopes prove allocation, not furniture "
                  "fit (F04 checkpoint's own caveat)"],
                 notes="Structural completeness never requires final "
                       "decoration; this dimension only tracks that "
                       "use envelopes exist before props.")

    def v1_room_coverage(self) -> dict:
        """How much of the v1 room inventory has a v2 representation.

        Bookkeeping only: an id match or curated alias never promotes a
        requirement's status.  Pseudo-rooms referenced by acoustic/service
        data (navigation zones, fruit clusters, riser vocabulary) are
        excluded rather than reported as missing rooms.
        """
        matched, aliased, subdivided, unrepresented = [], [], [], []
        for floor in self.inputs.v1.get("floors", []):
            for room in floor.get("rooms", []):
                rid = str(room.get("id", ""))
                if not rid or PSEUDO_ROOM_RE.search(rid):
                    continue
                if rid in self.model.spaces:
                    matched.append(rid)
                    continue
                alias_targets = [t for t in V1_TO_V2_ALIASES.get(rid, [])
                                 if t in self.model.spaces]
                if len(alias_targets) > 1:
                    subdivided.append({"v1": rid, "v2": alias_targets})
                elif alias_targets:
                    aliased.append({"v1": rid, "v2": alias_targets[0]})
                else:
                    unrepresented.append(rid)
        acoustic = self.inputs.root / "game/data/acoustic_graph.json"
        pseudo_refs = []
        if acoustic.is_file():
            try:
                graph = json.loads(acoustic.read_text(encoding="utf-8"))
                rooms = {str(n.get("room", ""))
                         for n in graph.get("nodes", [])}
                pseudo_refs = sorted(r for r in rooms
                                     if r and PSEUDO_ROOM_RE.search(r))
            except (OSError, json.JSONDecodeError):
                pseudo_refs = []
        return {
            "matched": sorted(matched),
            "aliased": sorted(aliased, key=lambda a: a["v1"]),
            "subdivided": sorted(subdivided, key=lambda a: a["v1"]),
            "unrepresented": sorted(unrepresented),
            "pseudo_rooms_excluded": pseudo_refs,
        }

    def _find_anchor_only(self):
        for aid, anchor in sorted(self.model.anchors.items()):
            if anchor.get("kind") == "review":
                continue
            containing = self.model.anchor_space(anchor)
            if containing is None:
                self.anchor_only.append({
                    "anchor": aid, "level": anchor.get("level"),
                    "note": "anchor with no containing programmed space"})


def load_scoped_jobs(inputs: Inputs):
    path = inputs.root / "game/data/maintenance_jobs.json"
    if not path.is_file():
        return []
    data = load_json(path, "maintenance jobs")
    jobs = []

    def walk(node, current_id=None):
        if isinstance(node, dict):
            job_id = node.get("id") or current_id
            if "anchor_ids" in node or "repair_target_id" in node:
                anchors = list(node.get("anchor_ids", []))
                for key in ("repair_target_id", "inspect_anchor_id"):
                    value = node.get(key)
                    if value and value not in anchors:
                        anchors.append(value)
                jobs.append((str(job_id), str(node.get("unit", "")),
                             anchors))
            for k, v in node.items():
                walk(v, k if isinstance(v, dict) else job_id)
        elif isinstance(node, list):
            for entry in node:
                walk(entry, current_id)

    walk(data)
    unique = {}
    for job_id, unit, anchors in jobs:
        unique[(job_id, unit)] = anchors
    return sorted((j, u, a) for (j, u), a in unique.items())


def load_scoped_cases(inputs: Inputs):
    path = inputs.root / "game/data/reality_cases.json"
    if not path.is_file():
        return []
    data = load_json(path, "reality cases")
    cases = []

    def walk(node):
        if isinstance(node, dict):
            if "unit" in node and ("id" in node or "case_id" in node):
                cid = node.get("id") or node.get("case_id")
                cases.append((str(cid), str(node["unit"]),
                              node.get("origin_node")))
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for entry in node:
                walk(entry)

    walk(data)
    return sorted(set(cases))


# ---------------------------------------------------------------------------
# Milestone queue
# ---------------------------------------------------------------------------

def build_queue(ledger: Ledger) -> list[dict]:
    reqs = ledger.requirements

    def outstanding(*prefixes, scope=None):
        out = []
        for record in reqs:
            if not record["id"].startswith(tuple(prefixes)):
                continue
            blocking = record["blocking_scopes"]
            if scope is None:
                if blocking:
                    out.append(record["id"])
            elif scope in blocking:
                out.append(record["id"])
        return sorted(set(out))

    production_blockers = sorted(
        r["id"] for r in reqs
        if "PRODUCTION_CUTOVER" in r["blocking_scopes"])
    retirement_blockers = sorted(
        r["id"] for r in reqs
        if "V1_RETIREMENT" in r["blocking_scopes"])

    # Dependency-ordered milestone templates.  The production DEFAULT_ID
    # flip (M09) sits AFTER whole-building structural, runtime and human
    # acceptance work; it may be drafted earlier as a dormant proposal
    # template, but DEFAULT_ID must not change until the
    # PRODUCTION_CUTOVER scope passes and the owner authorizes it.
    queue_templates = [
        {
            "id": "M08E-f01-rituals-2b-b1",
            "scope": "Build and spatially prove the F01 ritual desk "
                     "spaces/identities, apartment 2B, and the B1 service "
                     "route (boiler endpoint) in the v2 schema.",
            "prerequisite": "M08D runtime-parity checkpoint (done)",
            "outstanding": (outstanding("ritual.", "unit.2B", "floor.B1",
                                        "b1.boiler_room",
                                        scope="FIRST_SLICE_TECHNICAL")),
            "blocked_consumers": ["FirstShiftDirector",
                                  "ServiceRoundDirector", "NightRegister",
                                  "WatchStationNetwork",
                                  "lena_radiator_round_2b"],
            "required_ids": RITUAL_IDENTITIES + CUTOVER_SERVICE_IDS +
            ["2B unit spaces"],
            "automated_proof": "extended OrisonV2BlockoutTest census + "
                               "clearance stations; drift-clean spatial "
                               "dependency audit",
            "human_evidence": "graybox route-readability frames for the "
                              "new spaces; owner acceptance JSON",
            "files_change": ["game/data/orison_v2_blockout.json",
                             "game/scripts/building/orison_v2_*.gd",
                             "game/tests/orison_v2_*",
                             "design/ORISON_V2_M08E_*"],
            "files_forbidden": ["game/data/building_layout.json",
                                "art/data/*", "game/scenes/building/"
                                "orison_root.tscn",
                                "game/scripts/game/reality_game_state.gd",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "All four ritual identities, unit 2B and the B1 "
                    "boiler endpoint resolve uniquely in v2 with "
                    "SPATIALLY_PROVEN status.",
        },
        {
            "id": "M08F-runtime-composition-of-m08e",
            "scope": "Compose and runtime-prove the M08E spaces: first "
                     "shift ritual, service round and night register "
                     "under the v2 runtime root; authority census 1:1.",
            "prerequisite": "M08E-f01-rituals-2b-b1",
            "outstanding": outstanding(
                "job.lena_radiator_round_2b", "contract.B1_BOILER_01",
                "contract.F02_B_RADIATOR_01",
                scope="FIRST_SLICE_TECHNICAL"),
            "blocked_consumers": ["golden shift beats 1-3",
                                  "service round proof"],
            "required_ids": CUTOVER_SERVICE_IDS + RITUAL_IDENTITIES,
            "automated_proof": "two-root matrix extension covering first "
                               "shift + service round; save round trip",
            "human_evidence": "none new (runtime milestone)",
            "files_change": ["game/scripts/building/orison_v2_runtime_"
                             "root.gd", "game/tests/orison_v2_*"],
            "files_forbidden": ["game/scripts/game/work_orders.gd",
                                "game/data/maintenance_jobs.json",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "M08D authority census reports 1:1 for "
                    "FirstShiftDirector and ServiceRoundDirector under "
                    "explicit v2 selection.  FIRST_SLICE_TECHNICAL "
                    "clean - production cutover NOT implied.",
        },
        {
            "id": "M10-golden-shift-v2",
            "scope": "Author and human-run the eleven golden-shift beats "
                     "under EXPLICIT v2 selection (K3 matrix); v1 stays "
                     "the production default throughout.",
            "prerequisite": "M08F-runtime-composition-of-m08e",
            "outstanding": outstanding("golden.", "job.", "case.mina",
                                       scope="GOLDEN_SHIFT_V2"),
            "blocked_consumers": ["K3 save/reload human matrix"],
            "required_ids": ["golden-shift boundaries (byte-identical)"],
            "automated_proof": "golden_loop equivalent targeting the v2 "
                               "selector",
            "human_evidence": "eleven-beat human run card + golden-shift "
                              "acceptance receipt",
            "files_change": ["game/tests/*", "design/"],
            "files_forbidden": ["save owners",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "GOLDEN_SHIFT_V2 scope clean - still not a "
                    "production-default authorization.",
        },
        {
            "id": "M11-structural-floors",
            "scope": "Build remaining canonical floors structurally: "
                     "F03 full program, F05, F06, B1 full program, ROOF; "
                     "electrical + fire risers; declared service-hall "
                     "openings.",
            "prerequisite": "M08F-runtime-composition-of-m08e",
            "outstanding": outstanding(
                "floor.", "circ.", "b1.", "roof.", "f01.",
                "service.electrical_riser", "service.fire_service",
                scope="FULL_BUILDING_STRUCTURAL"),
            "blocked_consumers": ["resident schedules above F04",
                                  "building personality floors",
                                  "maintenance activities"],
            "required_ids": ["floor levels F05/F06/B1/ROOF",
                             "per-floor circulation records"],
            "automated_proof": "completeness ledger floor dimension all "
                               ">= SPATIALLY_PROVEN",
            "human_evidence": "per-floor graybox acceptance",
            "files_change": ["game/data/orison_v2_blockout.json",
                             "generator"],
            "files_forbidden": ["v1 layout/scenes",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "All eight canonical floors PROGRAMMED and "
                    "SPATIALLY_PROVEN with circulation and riser "
                    "endpoints.",
        },
        {
            "id": "M12-apartments-by-case-dependency",
            "scope": "Build occupied apartments in case-dependency "
                     "order (units with active case routes first), "
                     "then transient 4D.",
            "prerequisite": "M11-structural-floors",
            "outstanding": outstanding(
                "unit.", scope="FULL_BUILDING_STRUCTURAL"),
            "blocked_consumers": ["17 reality cases",
                                  "resident routines/haunts",
                                  "organism incident reconstruction"],
            "required_ids": ["per-unit space sets with domestic "
                             "minimums"],
            "automated_proof": "domestic-minimum dimension complete per "
                               "unit",
            "human_evidence": "per-unit room acceptance (room sentence "
                              "profiles)",
            "files_change": ["game/data/orison_v2_blockout.json"],
            "files_forbidden": ["game/data/reality_cases.json",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "Every occupied unit >= SPATIALLY_PROVEN with all "
                    "six domestic functions present.",
        },
        {
            "id": "M13-sealed-vacant-authoring",
            "scope": "Author sealed (2D/3C/5D/6D) thresholds and vacant "
                     "conditions as deliberate absence.",
            "prerequisite": "M12-apartments-by-case-dependency",
            "outstanding": [f"unit.{u}" for u in sorted(SEALED_UNITS)
                            if any(r["id"] == f"unit.{u}" and
                                   r["blocking_scopes"]
                                   for r in reqs)],
            "blocked_consumers": ["window_glow sealed set",
                                  "mail/dead letters"],
            "required_ids": ["sealed unit thresholds on public route"],
            "automated_proof": "sealed threshold census",
            "human_evidence": "owner confirmation absence reads as "
                              "authored",
            "files_change": ["game/data/orison_v2_blockout.json"],
            "files_forbidden": ["BuildingRootSelector.DEFAULT_ID"],
            "exit": "Each sealed unit has a public threshold and an "
                    "authored closed state; no accidental navigable gap.",
        },
        {
            "id": "M14-service-topology-and-acoustics",
            "scope": "Regenerate acoustic graph and service networks "
                     "from v2 topology, retaining externally consumed "
                     "node ids; retire adapter positional overrides.",
            "prerequisite": "M11-structural-floors",
            "outstanding": outstanding("acoustic.", "service.",
                                       scope="FULL_BUILDING_RUNTIME"),
            "blocked_consumers": ["audio propagation", "cases",
                                  "VirusSoundDirector"],
            "required_ids": ["externally consumed acoustic node ids"],
            "automated_proof": "acoustic graph integrity + case "
                               "sound-origin tests under v2",
            "human_evidence": "listening pass",
            "files_change": ["game/data/acoustic_graph.json (regenerated "
                             "from v2)", "generator"],
            "files_forbidden": ["game/scripts/audio owners",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "Graph positions derive from v2; adapter positional "
                    "overrides retired.",
        },
        {
            "id": "M15-whole-building-runtime-matrix",
            "scope": "Whole-building runtime consumer and save matrix: "
                     "every job, case, interaction, resident, wake and "
                     "organism fact resolves and reconstructs under "
                     "explicit v2 selection.",
            "prerequisite": "M12-apartments-by-case-dependency + "
                            "M14-service-topology-and-acoustics",
            "outstanding": outstanding(
                "job.", "case.", "interaction.", "save.", "contract.",
                scope="FULL_BUILDING_RUNTIME"),
            "blocked_consumers": ["all reality cases",
                                  "organism ledger reconstruction",
                                  "resident schedules"],
            "required_ids": ["every migration-contract identity"],
            "automated_proof": "full-root consumer census + two-root "
                               "save matrix over every historical "
                               "fixture",
            "human_evidence": "none (runtime milestone)",
            "files_change": ["game/tests"],
            "files_forbidden": ["save owners",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "FULL_BUILDING_RUNTIME scope clean.",
        },
        {
            "id": "M16-whole-building-performance-navigation",
            "scope": "Whole-building performance stations, human "
                     "navigation acceptance, resident schedule proof.",
            "prerequisite": "M15-whole-building-runtime-matrix",
            "outstanding": outstanding("evidence.", "human.",
                                       scope="PRODUCTION_CUTOVER"),
            "blocked_consumers": ["release evidence matrix"],
            "required_ids": ["per-floor capture stations"],
            "automated_proof": "route/performance matrix at documented "
                               "budgets",
            "human_evidence": "whole-building navigation acceptance "
                              "JSON (scope beyond route readability)",
            "files_change": ["game/tests", "art/renders/orison_v2"],
            "files_forbidden": ["v1 evidence",
                                "BuildingRootSelector.DEFAULT_ID"],
            "exit": "Whole-building route budget met and owner-accepted.",
        },
        {
            "id": "M09-production-cutover-proposal",
            "scope": "Evidence-backed production default switch: flip "
                     "BuildingRootSelector.DEFAULT_ID with a tagged v1 "
                     "fallback and rollback instructions.  May exist "
                     "earlier only as a dormant proposal template.",
            "prerequisite": "M16-whole-building-performance-navigation "
                            "(PRODUCTION_CUTOVER scope must be clean)",
            "outstanding": production_blockers,
            "blocked_consumers": ["default boot path"],
            "required_ids": ["BuildingRootSelector.DEFAULT_ID"],
            "automated_proof": "completeness ledger --blockers-for "
                               "production-cutover exits 0; full gate "
                               "suite green under both roots",
            "human_evidence": "owner authorization JSON with "
                              "authorization.production_cutover=true",
            "files_change": ["game/scripts/building/building_root_"
                             "selector.gd (DEFAULT_ID only)",
                             "design/ORISON_V2_M09_CUTOVER_PROPOSAL_*"],
            "files_forbidden": ["everything on the pre-M09 forbidden "
                                "list (saves, jobs, cases, v1 scene/"
                                "layout, evidence)"],
            "exit": "Owner-signed production-cutover authorization; "
                    "DEFAULT_ID flips with a one-line revert as "
                    "rollback.",
        },
        {
            "id": "M17-v1-fallback-window",
            "scope": "Post-cutover rollback window: v1 stays selectable "
                     "and tagged; regressions revert the one-line "
                     "DEFAULT_ID change.",
            "prerequisite": "M09-production-cutover-proposal",
            "outstanding": ["rollback window observation period"],
            "blocked_consumers": [],
            "required_ids": ["tagged v1 fallback commit"],
            "automated_proof": "both roots stay green for the window",
            "human_evidence": "owner closes the window explicitly",
            "files_change": [],
            "files_forbidden": ["v1 generation, scenes and evidence"],
            "exit": "Window closed by the owner with no rollback.",
        },
        {
            "id": "M18-v1-retirement",
            "scope": "Retire the v1 fallback: remove the anonymous-bed "
                     "fallback, freeze v1 generation as a migration "
                     "fixture, retire adapter aliases id-by-id.",
            "prerequisite": "M17-v1-fallback-window",
            "outstanding": retirement_blockers,
            "blocked_consumers": [],
            "required_ids": ["every adapter alias with consumer census"],
            "automated_proof": "spatial dependency audit accepts the "
                               "deliberate stale-preserved deltas; "
                               "v2-only matrix replaces the two-root "
                               "matrix",
            "human_evidence": "owner retirement authorization "
                              "(authorization.v1_retirement=true)",
            "files_change": ["selector", "adapter", "manifest"],
            "files_forbidden": ["save owners"],
            "exit": "No TEMPORARY_V1_FALLBACK flag remains anywhere in "
                    "this ledger; v1 tagged as frozen fixture.",
        },
    ]
    queue = []
    for template in queue_templates:
        item = dict(template)
        item["outstanding"] = sorted(set(template["outstanding"]))
        if not item["outstanding"] and item["id"] not in (
                "M09-production-cutover-proposal",
                "M17-v1-fallback-window", "M18-v1-retirement"):
            continue
        queue.append(item)
    return queue


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def blockers_for(requirements: list[dict], scope: str) -> list[dict]:
    return [r for r in requirements if scope in r["blocking_scopes"]]


def summarize(ledger: Ledger, scope_reqs: list[dict]) -> dict:
    def tally(key):
        out: dict[str, int] = {}
        for record in scope_reqs:
            out[record[key]] = out.get(record[key], 0) + 1
        return dict(sorted(out.items()))
    fallbacks = [r for r in scope_reqs if r["temporary_v1_fallback"]]
    return {
        "requirements": len(scope_reqs),
        "by_status": tally("status"),
        "blockers_by_scope": {
            scope: len(blockers_for(scope_reqs, scope))
            for scope in SCOPES},
        "v1_fallbacks": len(fallbacks),
        "heuristic_conclusions": sum(
            1 for r in scope_reqs if r["heuristic"]),
        "anchor_only_findings": len(ledger.anchor_only),
        "stale_checkpoint_ids": len(ledger.evidence.stale),
    }


FINDING_LIST_LIMIT = 20


def render_findings(payload: dict, emit) -> None:
    """Name the two side-channel findings a builder has to act on.

    Both were counted in the summary and carried in --json but never
    named in the human-readable or markdown output, so a floor owner
    reading the default gate saw `anchor_only_findings: 1` with no way
    to learn WHICH anchor without switching to --json.  An unnamed
    finding is an unactionable one.
    """
    orphans = payload.get("anchor_only") or []
    if orphans:
        emit(f"anchors with no containing programmed space "
             f"({len(orphans)}):")
        for entry in orphans[:FINDING_LIST_LIMIT]:
            emit(f"  ! {entry['anchor']} [{entry.get('level')}] "
                 f"- {entry['note']}")
        if len(orphans) > FINDING_LIST_LIMIT:
            emit(f"  ... {len(orphans) - FINDING_LIST_LIMIT} more (--json)")
    stale = payload.get("stale_checkpoint_ids") or []
    if stale:
        emit(f"stale checkpoint identifiers ({len(stale)}):")
        for entry in stale[:FINDING_LIST_LIMIT]:
            emit(f"  ! {entry['token']} - {entry['note']} "
                 f"({entry['source']})")
        if len(stale) > FINDING_LIST_LIMIT:
            emit(f"  ... {len(stale) - FINDING_LIST_LIMIT} more (--json)")


def render_markdown(payload: dict) -> str:
    out = ["# Orison v2 completeness ledger", ""]
    summary = payload["summary"]
    out.append("| Metric | Value |")
    out.append("| --- | --- |")
    for key, value in summary.items():
        if isinstance(value, dict):
            value = ", ".join(f"{k}={v}" for k, v in value.items())
        out.append(f"| {key} | {value} |")
    out += ["", "## Blockers by readiness scope", ""]
    for scope in SCOPES:
        ids = payload["blockers_by_scope"].get(scope, [])
        out.append(f"- **{scope}**: {len(ids)}")
        for rid in ids[:40]:
            out.append(f"  - {rid}")
        if len(ids) > 40:
            out.append(f"  - ... {len(ids) - 40} more")
    if payload.get("banner"):
        out += ["", f"**{payload['banner']}**"]
    out += ["", "## v1 fallbacks", ""]
    for record in payload["v1_fallbacks"]:
        out.append(f"- {record['id']} [{record['status']}] "
                   f"({record.get('fallback_kind')})")
    findings: list[str] = []
    render_findings(payload, findings.append)
    if findings:
        out += ["", "## Findings", ""]
        for line in findings:
            out.append(f"- {line.strip()}" if line.startswith("  ")
                       else f"\n**{line}**\n")
    out += ["", "## Requirements", ""]
    out.append("| id | dimension | status | required | blocking scopes | "
               "fallback | heuristic |")
    out.append("| --- | --- | --- | --- | --- | --- | --- |")
    for record in payload["requirements"]:
        out.append(
            f"| {record['id']} | {record['dimension']} | "
            f"{record['status']} | {record['required_proof']} | "
            f"{', '.join(record['blocking_scopes']) or '-'} | "
            f"{'yes' if record['temporary_v1_fallback'] else ''} | "
            f"{'yes' if record['heuristic'] else ''} |")
    out += ["", "## Recommended queue", ""]
    for item in payload["queue"]:
        out.append(f"### {item['id']}")
        out.append(f"- scope: {item['scope']}")
        out.append(f"- prerequisite: {item['prerequisite']}")
        out.append(f"- outstanding: {len(item['outstanding'])} "
                   "requirements")
        out.append(f"- exit: {item['exit']}")
        out.append("")
    out += ["## Provenance", ""]
    for path, digest in sorted(payload["provenance"].items()):
        out.append(f"- `{path}` sha256 `{digest[:16]}...`")
    out.append("")
    return "\n".join(out)


def guarded_out_dir(root: Path, out_dir: Path) -> Path:
    resolved = out_dir.resolve()
    safe = (root / SAFE_DESIGN_OUT).resolve()
    for guarded in ("game", "art"):
        if resolved.is_relative_to((root / guarded).resolve()):
            raise AuditError(
                f"refusing to write reports under {root / guarded}; "
                "choose a directory outside production trees")
    design_root = (root / "design").resolve()
    if resolved.is_relative_to(design_root) and resolved != safe:
        raise AuditError(
            "refusing to write inside design/; the only documented safe "
            f"design destination is {SAFE_DESIGN_OUT}")
    return resolved


def atomic_write(path: Path, content: str, force: bool) -> None:
    if path.exists() and not force:
        raise AuditError(f"refusing to overwrite {path} without --force")
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent),
                               prefix=path.name + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


# ---------------------------------------------------------------------------
# Compare mode
# ---------------------------------------------------------------------------

def compare(baseline: dict, current: list[dict]) -> dict:
    base_reqs = {r["id"]: r for r in baseline.get("requirements", [])}
    cur_reqs = {r["id"]: r for r in current}
    improved, regressed, added, removed = [], [], [], []
    for rid, record in sorted(cur_reqs.items()):
        old = base_reqs.get(rid)
        if old is None:
            added.append(rid)
            continue
        old_rank = RANK.get(old.get("status"), -1)
        new_rank = RANK.get(record["status"], -1)
        if new_rank > old_rank:
            improved.append({"id": rid, "from": old.get("status"),
                             "to": record["status"]})
        elif new_rank < old_rank:
            regressed.append({"id": rid, "from": old.get("status"),
                              "to": record["status"]})
    for rid in sorted(base_reqs):
        if rid not in cur_reqs:
            removed.append(rid)
    return {"improved": improved, "regressed": regressed,
            "added": added, "removed": removed}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Orison v2 rebuild completeness ledger "
                    "(ADMIN-ARCH2; read-only).")
    parser.add_argument("--root", default=".")
    parser.add_argument("--v1-layout")
    parser.add_argument("--v2-layout")
    parser.add_argument("--design-dir")
    parser.add_argument("--dependency-manifest")
    parser.add_argument("--acceptance")
    parser.add_argument("--floor", action="append", default=[])
    parser.add_argument("--unit", action="append", default=[])
    parser.add_argument("--space")
    parser.add_argument("--blockers-for", choices=sorted(SCOPE_FLAGS),
                        help="show only requirements blocking the given "
                             "readiness scope; exit reflects that scope")
    parser.add_argument("--blockers-only", action="store_true",
                        help="alias for --blockers-for production-cutover "
                             "(deliberately the WIDE meaning)")
    parser.add_argument("--baseline",
                        help="prior ledger JSON, or a prior v2 layout "
                             "JSON, to diff against")
    parser.add_argument("--verbose", action="store_true",
                        help="also list every design/ORISON_V2_*.md that "
                             "was admitted as evidence and every one "
                             "refused, with the reason")
    parser.add_argument("--evidence-impact", metavar="PATH",
                        help="report whether this design document changes "
                             "any requirement's status. Works for a "
                             "candidate file that is not committed yet "
                             "and for one already in the design "
                             "directory; exits 0 when it changes nothing, "
                             "1 when it does.")
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--markdown", action="store_true")
    parser.add_argument("--out", help="directory for ledger reports "
                                      "(refuses game/, art/, design/ "
                                      "except the documented safe path)")
    parser.add_argument("--force", action="store_true")
    return parser


def scope_filter(args, requirements: list[dict]) -> list[dict]:
    scoped = requirements
    if args.floor:
        floors = set(args.floor)
        scoped = [r for r in scoped
                  if r["scope"].get("floor") in floors or
                  any(str(v) in floors
                      for v in r["scope"].values()
                      if isinstance(v, str))]
    if args.unit:
        units = set(args.unit)
        scoped = [r for r in scoped
                  if r["scope"].get("unit") in units]
    if args.space:
        scoped = [r for r in scoped
                  if r["scope"].get("space") == args.space or
                  args.space in (r["scope"].get("spaces") or []) or
                  args.space in (r["scope"].get("anchors") or [])]
    return scoped


def query_scopes(args) -> list[str]:
    """Readiness scopes the caller asked about, or [] for the default
    whole-ledger view.  --blockers-only means production-cutover."""
    if args.blockers_for:
        return SCOPE_FLAGS[args.blockers_for]
    if args.blockers_only:
        return SCOPE_FLAGS["production-cutover"]
    return []


def _status_map(requirements: list[dict]) -> dict[str, tuple]:
    return {r["id"]: (r["status"], tuple(r["blocking_scopes"]))
            for r in requirements}


def evidence_impact(args) -> int:
    """Answer, for one design document: does the ledger say anything
    different because this file exists?

    The check both ways round.  For a candidate that is not committed
    yet it is 'would adding this change a status'; for a file already in
    the design directory it is 'is this file changing a status right
    now'.  Both are the same comparison — the ledger without the
    document against the ledger with it — so one flag answers the
    question a reviewer actually has.
    """
    root = Path(args.root).resolve()
    if not root.is_dir():
        raise AuditError(f"root {root} is not a directory")
    target = Path(args.evidence_impact)
    if not target.is_absolute():
        target = root / target
    if not target.is_file():
        raise AuditError(f"evidence-impact target {target} is not a file")
    resolved = target.resolve()

    marker = evidence_marker(target.name)
    admissible = marker is not None and target.name.startswith("ORISON_V2_") \
        and target.suffix == ".md"

    without = argparse.Namespace(**vars(args))
    without._exclude_doc = resolved
    base_ledger = Ledger(Inputs(root, without))

    design_dir = Inputs(root, without).design_dir
    in_design_dir = resolved.parent == design_dir.resolve()
    staged: Path | None = None
    try:
        if not in_design_dir:
            # Evaluate a candidate in place: copy it beside the real
            # evidence under its own name, measure, then remove it.
            staged = design_dir / target.name
            if staged.exists():
                raise AuditError(
                    f"cannot stage {target.name}: a file of that name "
                    f"already exists in {design_dir}")
            staged.write_bytes(target.read_bytes())
        with_args = argparse.Namespace(**vars(args))
        with_args._exclude_doc = None
        with_ledger = Ledger(Inputs(root, with_args))
    finally:
        if staged is not None and staged.exists():
            staged.unlink()

    before = _status_map(base_ledger.requirements)
    after = _status_map(with_ledger.requirements)
    changed = []
    for rid in sorted(set(before) | set(after)):
        if before.get(rid) != after.get(rid):
            b = before.get(rid, ("<absent>", ()))
            a = after.get(rid, ("<absent>", ()))
            changed.append({
                "id": rid,
                "status_before": b[0], "status_after": a[0],
                "blocking_before": list(b[1]), "blocking_after": list(a[1]),
            })

    rel = resolved.relative_to(root).as_posix() \
        if resolved.is_relative_to(root) else str(resolved)
    payload = {
        "tool_version": TOOL_VERSION,
        "document": rel,
        "admitted_as_evidence": admissible,
        "evidence_marker": marker,
        "reason": None if admissible else non_evidence_reason(target.name),
        "requirements_changed": changed,
    }
    if args.as_json:
        print(json.dumps(payload, indent=1, sort_keys=False))
    else:
        print(f"evidence impact: {rel}")
        if admissible:
            print(f"  admitted as evidence (marker {marker}, "
                  f"epoch {doc_epoch(target.name)})")
        else:
            print(f"  NOT evidence ({payload['reason']})")
        if not changed:
            print("  changes no requirement status. Prose is inert.")
        else:
            print(f"  CHANGES {len(changed)} requirement(s):")
            for entry in changed:
                print("    %s: %s -> %s" % (entry["id"],
                                            entry["status_before"],
                                            entry["status_after"]))
    return 1 if changed else 0


def main(argv=None) -> int:
    try:
        args = build_parser().parse_args(argv)
    except SystemExit as exc:
        return 0 if exc.code == 0 else 3
    try:
        return run(args)
    except AuditError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3
    except Exception as exc:  # pragma: no cover - defensive
        print(f"INTERNAL: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 70


def run(args) -> int:
    if getattr(args, "evidence_impact", None):
        return evidence_impact(args)
    root = Path(args.root).resolve()
    if not root.is_dir():
        raise AuditError(f"root {root} is not a directory")
    inputs = Inputs(root, args)
    ledger = Ledger(inputs)
    scoped = scope_filter(args, ledger.requirements)
    asked = query_scopes(args)
    if asked:
        scoped = [r for r in scoped
                  if any(s in r["blocking_scopes"] for s in asked)]
    summary = summarize(ledger, scope_filter(args, ledger.requirements))
    queue = build_queue(ledger)

    payload = {
        "tool_version": TOOL_VERSION,
        "summary": summary,
        "queried_scopes": asked,
        "requirements": scoped,
        "blockers_by_scope": {
            scope: [r["id"] for r in blockers_for(
                scope_filter(args, ledger.requirements), scope)]
            for scope in SCOPES},
        "v1_fallbacks": [r for r in scoped
                         if r["temporary_v1_fallback"]],
        "anchor_only": ledger.anchor_only,
        "v1_room_coverage": ledger.v1_room_coverage(),
        "stale_checkpoint_ids": ledger.evidence.stale,
        "evidence_conflicts": ledger.evidence.conflicts,
        "unresolved": [r for r in scoped
                       if r["heuristic"] and r["blocking_scopes"]],
        "queue": queue,
        "evidence_intake": {
            "admitted": inputs.admitted_evidence,
            "not_evidence": inputs.non_evidence,
        },
        "provenance": inputs.provenance,
    }

    if args.baseline:
        baseline_path = Path(args.baseline)
        if not baseline_path.is_absolute():
            baseline_path = root / baseline_path
        base = load_json(baseline_path, "baseline")
        if "requirements" in base:
            payload["comparison"] = compare(base, ledger.requirements)
        elif "spaces" in base:
            class _A:  # re-evaluate against the baseline v2 layout
                pass
            alt = _A()
            for name in ("v1_layout", "v2_layout", "design_dir",
                         "dependency_manifest", "acceptance"):
                setattr(alt, name, getattr(args, name))
            alt.v2_layout = str(baseline_path)
            base_inputs = Inputs(root, alt)
            base_ledger = Ledger(base_inputs)
            payload["comparison"] = compare(
                {"requirements": base_ledger.requirements},
                ledger.requirements)
        else:
            raise AuditError(
                f"baseline {baseline_path} is neither a ledger report "
                "nor a v2 layout")

    if args.out:
        out_dir = guarded_out_dir(root, Path(args.out)
                                  if Path(args.out).is_absolute()
                                  else root / args.out)
        atomic_write(out_dir / "ORISON_V2_COMPLETENESS_LEDGER.json",
                     json.dumps(payload, indent=1, sort_keys=False) + "\n",
                     args.force)
        atomic_write(out_dir / "ORISON_V2_COMPLETENESS_LEDGER.md",
                     render_markdown(payload), args.force)

    banner = ""
    if asked and not scoped:
        if args.blockers_for == "first-slice":
            banner = FIRST_SLICE_BANNER
        elif args.blockers_for == "golden-shift":
            banner = ("GOLDEN SHIFT READY - PRODUCTION CUTOVER NOT "
                      "IMPLIED.")
        else:
            banner = f"{' / '.join(asked)}: no blockers in scope."
    if banner:
        payload["banner"] = banner

    if args.as_json:
        print(json.dumps(payload, indent=1, sort_keys=False))
    elif args.markdown:
        print(render_markdown(payload))
    else:
        print("orison v2 completeness ledger")
        for key, value in summary.items():
            if isinstance(value, dict):
                value = ", ".join(f"{k}={v}" for k, v in value.items())
            print(f"  {key}: {value}")
        if asked:
            print(f"blockers for {' / '.join(asked)}:")
            for record in scoped:
                print(f"  - {record['id']} [{record['status']}]")
        else:
            print("production-cutover blockers (first-slice blockers "
                  "marked *):")
            for record in blockers_for(
                    scope_filter(args, ledger.requirements),
                    "PRODUCTION_CUTOVER"):
                mark = "*" if "FIRST_SLICE_TECHNICAL" in \
                    record["blocking_scopes"] else " "
                print(f"  {mark} {record['id']} [{record['status']}]")
        if banner:
            print(banner)
        render_findings(payload, print)
        if args.verbose:
            print("evidence admitted (%d):"
                  % len(inputs.admitted_evidence))
            for entry in inputs.admitted_evidence:
                print("  + %s [%s, epoch %d]"
                      % (entry["file"], entry["marker"], entry["epoch"]))
            print("not evidence (%d):" % len(inputs.non_evidence))
            for entry in inputs.non_evidence:
                print("  - %s (%s)" % (entry["file"], entry["reason"]))
        print("queue:")
        for item in queue:
            print(f"  {item['id']}: {len(item['outstanding'])} "
                  "outstanding")

    if asked:
        return 2 if scoped else 0
    base = scope_filter(args, ledger.requirements)
    pre_retirement = [s for s in SCOPES if s != "V1_RETIREMENT"]
    if any(any(s in r["blocking_scopes"] for s in pre_retirement)
           for r in base):
        return 2
    if any("V1_RETIREMENT" in r["blocking_scopes"] for r in base):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
