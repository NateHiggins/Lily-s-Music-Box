#!/usr/bin/env python3
"""ADMIN-ETHOS1: hidden quest logic and counterfeit world consequences.

Deterministic, read-only source audit of production GDScript and data for
architectural violations of the virtual-environment ethos: situations, not
assigned objectives; work optional; neglect produces continued world
state; NPCs interpret events through their own authorities; physical
mechanisms own physical consequences; inventory owns custody; saves keep
concrete facts; coordinators may schedule and observe but must not
fabricate what everyone knows; no hidden morality score, no
tutorial/objective leakage, no host wall-clock world mutation.

This is a HEURISTIC textual scan, not GDScript semantic analysis.  Every
finding carries a confidence (EXACT / STRONG / HEURISTIC / UNKNOWN) and a
suggested verification; the audit never claims semantic certainty from
text alone, and it never modifies production files.

Audit domains and finding classes:

  npc-knowledge   DIRECT_NPC_KNOWLEDGE_WRITE - a coordinator/director
                  directly assigns what an NPC knows/observed/believes,
                  with no observer event or delegated owner in evidence.
  physical        FOREIGN_PHYSICAL_MUTATION - a coordinator directly
                  mutates valve/door/heat/power/mechanism/inventory/NPC
                  transform/case/work-order state instead of calling the
                  owning domain API (a method call into the owner is
                  reported as delegation, not a violation).
  custody         DUPLICATE_CUSTODY - situation/quest records that
                  appear to own item/part/tool/key custody as strings,
                  cross-referenced against the inventory authority.
  timer           TIMER_IMPERSONATES_ACTOR - elapsed time directly
                  producing NPC arrival/knowledge, repair, inventory
                  transfer, relationship change or mechanism mutation in
                  the same scope; scheduling/dispatching through an actor
                  authority is fine.
  proximity       AUTONOMY_DEPENDS_ON_PROXIMITY - "autonomous"
                  progression gated on player presence/distance/room, or
                  accumulated only in scene-local _process that stops
                  when the scene unloads.
  host-clock      HOST_CLOCK_MUTATES_WORLD - durable world facts derived
                  from unix/system time or OS ticks (profiling, perf
                  measurement and cosmetic clocks are classified, not
                  flagged).
  objective-ui    OBJECTIVE_UI_LEAK - objective/mission/quest/tutorial
                  presentation in player-facing production UI (debug,
                  tests, diegetic work papers and ordinary dialogue are
                  out of scope).
  dead-end        COMPLIANCE_DEAD_END - state machines whose only exit
                  requires player compliance, with no timeout,
                  compensator or continued-world alternative in evidence
                  (conservative candidate, never a semantic verdict).
  judgment        ABSTRACT_JUDGMENT_FACT - generic good/bad, compliant,
                  success/failure, morality facts written into durable or
                  player-facing state (test verdicts and technical result
                  enums are classified, not flagged).
  test-proof      TEST_AUTHORITY_SHORTCUT - tests that claim player
                  behavior proof while invoking internal consequence
                  methods directly, with no public interaction exercised.
  (any)           DYNAMIC_UNRESOLVED - dynamic call/emit touching a
                  monitored concept that cannot be resolved statically.

Finding identity is line-independent: sha1 of (domain, class, file,
scope, normalized expression).  Line numbers are reported for reading,
never compared.

Baseline policy (tools/systemic_situation_authority_baseline.json):
new actionable production findings FAIL; a baselined finding whose class
or confidence changes FAILS (a baseline entry never suppresses a
different class, a higher-confidence mutation, or a production finding
via a test-tier entry); vanished baseline entries are cleanup
opportunities; malformed or duplicate baselines FAIL.  Output is
deterministic and byte-identical across runs.

Usage:
  python tools/audit_systemic_situation_authority.py
      [--root .] [--json] [--verbose] [--production-only]
      [--domain npc-knowledge|physical|custody|timer|proximity|
                host-clock|objective-ui|dead-end|judgment|test-proof]
      [--baseline <path>] [--write-baseline <safe tools path>]
      [--compare <old-report.json>]

Exit codes (stable, tested):
  0   clean against baseline (REVIEW-only findings allowed)
  1   new actionable production finding (or baseline-policy violation)
  3   usage error / refused output destination
  4   malformed baseline or input
  5   both actionable findings and malformed/conflicting state
  70  internal failure
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

TOOL_VERSION = 1
DEFAULT_BASELINE = "tools/systemic_situation_authority_baseline.json"

DOMAINS = ["npc-knowledge", "physical", "custody", "timer", "proximity",
           "host-clock", "objective-ui", "dead-end", "judgment",
           "test-proof"]
CLASSES = {
    "DIRECT_NPC_KNOWLEDGE_WRITE", "FOREIGN_PHYSICAL_MUTATION",
    "DUPLICATE_CUSTODY", "TIMER_IMPERSONATES_ACTOR",
    "AUTONOMY_DEPENDS_ON_PROXIMITY", "HOST_CLOCK_MUTATES_WORLD",
    "OBJECTIVE_UI_LEAK", "COMPLIANCE_DEAD_END", "ABSTRACT_JUDGMENT_FACT",
    "TEST_AUTHORITY_SHORTCUT", "DYNAMIC_UNRESOLVED"}
CONFIDENCES = ["UNKNOWN", "HEURISTIC", "STRONG", "EXACT"]
DISPOSITIONS = {"FIX", "DELEGATE_TO_OWNER", "ADD_PUBLIC_PROOF",
                "DOCUMENT", "BASELINE_DEBT", "REVIEW"}
# Actionable dispositions fail when new; REVIEW/DOCUMENT report only.
ACTIONABLE = {"FIX", "DELEGATE_TO_OWNER", "ADD_PUBLIC_PROOF",
              "BASELINE_DEBT"}


class AuditError(Exception):
    """Usage / refused output (exit 3)."""


class MalformedError(Exception):
    """Malformed baseline or input (exit 4)."""


# ---------------------------------------------------------------------------
# Writer classification (who is talking) and rightful owners.
# ---------------------------------------------------------------------------

COORDINATOR_RE = re.compile(
    r"_director\.gd$|_ecosystem\.gd$|_situation\.gd$|coordinator|"
    r"core_loop|first_shift|service_round|campaign_shell")
PERCEPTION_RE = re.compile(r"acoustic|audio_policy|ambient_soundscape")
CONVERSATION_RE = re.compile(r"dialogue|call_interface|conversation")


def writer_class(rel: str) -> str:
    name = rel.rsplit("/", 1)[-1]
    if rel.startswith("game/tests/") or "/tests/" in rel:
        return "test"
    if COORDINATOR_RE.search(name) or "/campaign/" in rel:
        return "coordinator"
    if "maintenance_inventory" in name:
        return "inventory_authority"
    if "work_orders" in name or "reality_case_manager" in name:
        return "job_case_authority"
    if "reality_game_state" in name:
        return "save_owner"
    if PERCEPTION_RE.search(rel):
        return "perception_authority"
    if CONVERSATION_RE.search(rel):
        return "conversation_authority"
    if "/characters/" in rel:
        return "npc_authority"
    if "/props/" in rel or "/device/" in rel:
        return "mechanism_authority"
    if "/ui/" in rel or "/phoneos/" in rel:
        return "presentation"
    if "/building/" in rel or "/reality/" in rel or "/game/" in rel:
        return "world_system"
    return "unknown"


# Rightful owners of RealityState.data subtrees (from the save/reload
# transaction model and the spatial dependency audit).
DATA_SUBTREE_OWNERS = {
    "work_orders": "game/scripts/game/work_orders.gd",
    "maintenance_jobs": "game/scripts/game/work_orders.gd",
    "maintenance_items": "game/scripts/game/maintenance_inventory.gd",
    "cases": "game/scripts/game/reality_case_manager.gd",
    "core_loop": "game/scripts/campaign/core_loop_director.gd",
    "first_shift": "game/scripts/game/first_shift_director.gd",
    "dream": "game/scripts/dream/dream_director.gd",
    "sleep_pressure":
        "game/scripts/campaign/sleep_pressure_director.gd",
    "waking_residues": "game/scripts/game/reality_game_state.gd",
    "organism_incidents": "game/scripts/reality/organism_incidents.gd",
    "building_personality":
        "game/scripts/reality/building_personality_director.gd",
    "night_register": "game/scripts/props/night_register_prop.gd",
    "open_shift_situations":
        "game/scripts/game/open_shift_situation.gd",
}

INVENTORY_AUTHORITY_RE = re.compile(
    r"MaintenanceInventory|maintenance_inventory|\binventory\.(acquire|"
    r"consume|has_item|grant|spend)")

# ---------------------------------------------------------------------------
# Domain pattern vocabulary
# ---------------------------------------------------------------------------

KNOWLEDGE_CONCEPT_RE = re.compile(
    r"npc_knowledge|\bknows\b|\bobserved\b|\bwitnessed\b|\bheard\b|"
    r"\bsaw\b|\bbelieves\b|\bsuspects\b|relationship_consequence|"
    r"\btrust\b")
KNOWLEDGE_WRITE_RE = re.compile(
    r'record_fact\(\s*"(npc_knowledge|relationship_consequence)"|'
    r'\.npc_knowledge\s*=|"npc_knowledge"\s*[:,]|'
    r'\.(knows|believes|suspects)\s*=|\btrust\s*[+\-]?=')

PHYSICAL_CALL_RE = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*)\.(apply_[a-z_]+|set_[a-z_]+|"
    r"open|close|repair|complete)\s*\(")
PHYSICAL_ASSIGN_RE = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*)\.(valve[a-z_]*|door_state|heat[a-z_]*|"
    r"power[a-z_]*|pressure|open|locked|repaired|fault[a-z_]*|"
    r"global_position|position)\s*=(?!=)")
PHYSICAL_CONCEPT_RE = re.compile(
    r"valve|door|heat|power|boiler|radiator|mechan|inventory|"
    r"work_order|case", re.IGNORECASE)
NPC_TARGET_RE = re.compile(
    r"npc|resident|actor|porter|player|character", re.IGNORECASE)
CONSTRUCTION_SCOPE_RE = re.compile(
    r"^_?(build|spawn|make|add|create|install|mount|compose)")
REALITY_DATA_WRITE_RE = re.compile(
    r"RealityState\.data\.([a-z_]+)"
    r"(?:\.[A-Za-z0-9_\.]+|\[[^\]]+\])?\s*"
    r"(?:=(?!=)|\.(?:merge|append|erase|clear)\()")

CUSTODY_RE = re.compile(
    r"part_custody|player_has|has_item|took_part|tool_custody|"
    r"key_custody|material_consumed|source_depleted|custody")

ELAPSED_RE = re.compile(
    r"elapsed|_MINUTES\b|bucket|>=\s*[A-Z_]*(MINUTES|SECONDS|TIMEOUT)|"
    r"create_timer|Timer\b")
CONSEQUENCE_RE = re.compile(
    r"begin_compensation|\.resolve\(|apply_[a-z_]*condition|"
    r'record_fact\(\s*"npc_knowledge"|record_fact\(\s*'
    r'"relationship_consequence"|\.arrive|\.acquire\(|\.consume\(|'
    r"\.repair\(|complete_")
SCHEDULE_ONLY_RE = re.compile(
    r"emit\(|emit_signal|call_deferred|schedule|queue_event|dispatch")

PROXIMITY_RE = re.compile(
    r"distance_to\(\s*player|player\.global_position|overlaps_body|"
    r"body_entered|current_room|is_visible|on_screen|near_player|"
    r"player_in")
# A file "claims autonomy" only when it says so - autonomous events,
# simulation advancement, situation progression - never merely because
# it has a _process loop (audio/presentation proximity cueing is
# legitimate and out of scope).
AUTONOMY_CLAIM_RE = re.compile(
    r"autonom|advance_simulation|situation|neglect|continued_world")

HOST_CLOCK_RE = re.compile(
    r"Time\.get_unix_time[a-z_]*\(|Time\.get_ticks_msec\(|"
    r"Time\.get_ticks_usec\(|Time\.get_datetime[a-z_]*\(|"
    r"OS\.get_ticks")
PROFILING_CONTEXT_RE = re.compile(
    r"perf|profil|budget_ms|_ms\b|elapsed_ms|print|debug|stopwatch|"
    r"startup|timing", re.IGNORECASE)
DURABLE_CONTEXT_RE = re.compile(
    r"RealityState|save|commit\(|issued_at|acquired_at|consumed_at|"
    r"record_fact|data\.")

OBJECTIVE_RE = re.compile(
    r"objective|mission|\bquest\b|complete task|current goal|tutorial|"
    r"\brequired\b|go to |return to ", re.IGNORECASE)
OBJECTIVE_STRING_RE = re.compile(
    r'"[^"]*(?:Objective|OBJECTIVE|Mission|Quest|Tutorial|Go to|'
    r'Return to|Task complete|Current goal)[^"]*"')

JUDGMENT_RE = re.compile(
    r'"(good|bad|compliant|noncompliant|morality|rebellion|'
    r'correct_choice|wrong_choice)"|\bmorality\b|correct_choice|'
    r"wrong_choice")
JUDGMENT_DURABLE_RE = re.compile(
    r"RealityState|record_fact|\.data\.|save|commit\(")

TEST_CLAIM_RE = re.compile(
    r"meddle|abandon|interaction|player|behav|proof|work",
    re.IGNORECASE)
TEST_SHORTCUT_CALL_RE = re.compile(
    r"\.(abandon_after|meddle_[a-z_]+|apply_[a-z_]*condition|"
    r'record_fact|resolve|begin_compensation|_[a-z_]*consequence)\s*\(')
TEST_PUBLIC_RE = re.compile(
    r"\.interact\(|get_interaction|_input\(|press|simulate_|"
    r"InputEvent|action_press|prompt")

DYNAMIC_RE = re.compile(
    r'\.call\(\s*"?([a-z_]+)"?|emit_signal\(\s*"([a-z_]+)"|'
    r'call_deferred\(\s*"([a-z_]+)"')

FUNC_RE = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)")


# ---------------------------------------------------------------------------
# Finding model
# ---------------------------------------------------------------------------

def normalize(expr: str) -> str:
    return re.sub(r"\s+", " ", expr.strip())[:200]


def finding_id(domain, cls, file, scope, expr) -> str:
    basis = "|".join((domain, cls, file, scope, normalize(expr)))
    return hashlib.sha1(basis.encode("utf-8")).hexdigest()[:16]


def make_finding(domain, cls, file, scope, line_no, expr, writer, owner,
                 confidence, risk, verify, disposition, tier) -> dict:
    return {
        "id": finding_id(domain, cls, file, scope, expr),
        "domain": domain,
        "class": cls,
        "file": file,
        "scope": scope,
        "line": line_no,
        "evidence": normalize(expr),
        "writer": writer,
        "rightful_owner": owner,
        "confidence": confidence,
        "risk": risk,
        "verify": verify,
        "disposition": disposition,
        "tier": tier,
    }


# ---------------------------------------------------------------------------
# Scanner
# ---------------------------------------------------------------------------

class FileContext:
    def __init__(self, rel: str, text: str):
        self.rel = rel
        self.text = text
        self.lines = text.split("\n")
        self.writer = writer_class(rel)
        self.tier = "test" if self.writer == "test" else "production"
        self.uses_inventory_authority = bool(
            INVENTORY_AUTHORITY_RE.search(text))
        # function spans: list of (name, start, end)
        self.functions = []
        current = None
        for i, raw in enumerate(self.lines):
            m = FUNC_RE.match(raw.strip())
            if m and (raw.startswith("func") or
                      raw.startswith("static func") or
                      raw.startswith("\tfunc") is False):
                if current:
                    self.functions.append(
                        (current[0], current[1], i - 1))
                current = (m.group(1), i)
        if current:
            self.functions.append((current[0], current[1],
                                   len(self.lines) - 1))

    def scope_at(self, index: int) -> str:
        for name, start, end in self.functions:
            if start <= index <= end:
                return name
        return "<module>"

    def function_body(self, name: str) -> str:
        for fname, start, end in self.functions:
            if fname == name:
                return "\n".join(self.lines[start:end + 1])
        return ""

    def code_line(self, index: int) -> str:
        raw = self.lines[index]
        stripped = raw.lstrip()
        if stripped.startswith("#"):
            return ""
        return raw.split("#", 1)[0] if "#" in raw else raw


def scan_file(ctx: FileContext, findings: list):
    seen_scopes_timer = set()
    for i in range(len(ctx.lines)):
        line = ctx.code_line(i)
        if not line.strip():
            continue
        scope = ctx.scope_at(i)
        line_no = i + 1

        _scan_npc_knowledge(ctx, findings, line, scope, line_no)
        _scan_physical(ctx, findings, line, scope, line_no)
        _scan_custody(ctx, findings, line, scope, line_no)
        _scan_host_clock(ctx, findings, line, scope, line_no)
        _scan_objective(ctx, findings, line, scope, line_no)
        _scan_judgment(ctx, findings, line, scope, line_no)
        _scan_proximity(ctx, findings, line, scope, line_no)
        _scan_dynamic(ctx, findings, line, scope, line_no)

        if scope not in seen_scopes_timer and \
                ELAPSED_RE.search(line):
            seen_scopes_timer.add(scope)
            _scan_timer_scope(ctx, findings, scope)

    if ctx.tier == "test":
        _scan_test_proof(ctx, findings)
    else:
        _scan_dead_ends(ctx, findings)
        _scan_scene_local_autonomy(ctx, findings)


def _scan_npc_knowledge(ctx, findings, line, scope, line_no):
    if not KNOWLEDGE_WRITE_RE.search(line):
        return
    writer = ctx.writer
    if writer in ("npc_authority", "perception_authority",
                  "conversation_authority"):
        # An NPC/perception/conversation authority recording its own
        # observation is the intended shape; report nothing.
        return
    if writer == "test":
        findings.append(make_finding(
            "npc-knowledge", "DIRECT_NPC_KNOWLEDGE_WRITE", ctx.rel,
            scope, line_no, line, writer, "npc/perception authority",
            "HEURISTIC", "test writes NPC knowledge directly",
            "confirm the test is setup-only, not behavior proof",
            "REVIEW", ctx.tier))
        return
    confidence = "STRONG" if writer == "coordinator" else "HEURISTIC"
    findings.append(make_finding(
        "npc-knowledge", "DIRECT_NPC_KNOWLEDGE_WRITE", ctx.rel, scope,
        line_no, line, writer,
        "npc/perception/conversation authority",
        confidence,
        "the world's narrator fabricates what an NPC knows; no "
        "observer event owns the belief",
        "trace the write to a perception/conversation event owned by "
        "the NPC authority, or delegate the write to that owner",
        "DELEGATE_TO_OWNER" if writer == "coordinator" else "REVIEW",
        ctx.tier))


def _scan_physical(ctx, findings, line, scope, line_no):
    if ctx.writer not in ("coordinator", "world_system", "unknown"):
        return
    assign = PHYSICAL_ASSIGN_RE.search(line)
    if assign and PHYSICAL_CONCEPT_RE.search(line):
        target = assign.group(1)
        prop = assign.group(2)
        if target in ("self",):
            return
        # Builders positioning what they are constructing own that
        # geometry; transform writes only matter for coordinators
        # moving NPC-like targets.
        if prop in ("position", "global_position"):
            if ctx.writer != "coordinator" or not \
                    NPC_TARGET_RE.search(line):
                return
        elif ctx.writer == "world_system" and \
                CONSTRUCTION_SCOPE_RE.match(scope):
            return
        findings.append(make_finding(
            "physical", "FOREIGN_PHYSICAL_MUTATION", ctx.rel, scope,
            line_no, line, ctx.writer, f"{target} (owning domain)",
            "STRONG" if ctx.writer == "coordinator" else "HEURISTIC",
            "a coordinator writes another domain's physical state "
            "directly; the mechanism no longer owns its consequence",
            "replace the direct write with the owning domain's API "
            "call, or document why this file is the owner",
            "DELEGATE_TO_OWNER", ctx.tier))
        return
    m = REALITY_DATA_WRITE_RE.search(line)
    if m:
        subtree = m.group(1)
        owner = DATA_SUBTREE_OWNERS.get(subtree)
        if owner and not ctx.rel.endswith(owner.rsplit("/", 1)[-1]) \
                and ctx.rel != owner:
            findings.append(make_finding(
                "physical", "FOREIGN_PHYSICAL_MUTATION", ctx.rel,
                scope, line_no, line, ctx.writer, owner,
                "STRONG",
                f"direct write into RealityState.data.{subtree}, "
                f"which is owned by {owner}",
                "route the mutation through the owner's API so the "
                "fact has one author",
                "DELEGATE_TO_OWNER", ctx.tier))


def _scan_custody(ctx, findings, line, scope, line_no):
    if not CUSTODY_RE.search(line):
        return
    if ctx.writer == "inventory_authority":
        return
    is_write = "=" in line.split("#")[0] or "record_fact" in line
    if not is_write:
        return
    if ctx.writer == "test":
        return
    confidence = "STRONG" if not ctx.uses_inventory_authority else \
        "HEURISTIC"
    findings.append(make_finding(
        "custody", "DUPLICATE_CUSTODY", ctx.rel, scope, line_no, line,
        ctx.writer, "game/scripts/game/maintenance_inventory.gd",
        confidence,
        "custody exists only as a situation string; the inventory "
        "authority never granted or consumed the item"
        if not ctx.uses_inventory_authority else
        "custody string duplicated beside inventory authority use",
        "prove the item through the inventory authority (acquire/"
        "consume) and derive the situation fact from it",
        "DELEGATE_TO_OWNER" if not ctx.uses_inventory_authority
        else "REVIEW",
        ctx.tier))


def _scan_timer_scope(ctx, findings, scope):
    body = ctx.function_body(scope)
    if not body or not ELAPSED_RE.search(body):
        return
    consequences = CONSEQUENCE_RE.findall(body)
    if not consequences:
        return
    # Scheduling-only scopes dispatch/emit and apply nothing final.
    consequence_lines = [ln for ln in body.split("\n")
                         if CONSEQUENCE_RE.search(ln)]
    if all(SCHEDULE_ONLY_RE.search(ln) for ln in consequence_lines):
        return
    start = next((s for n, s, _e in ctx.functions if n == scope), 0)
    findings.append(make_finding(
        "timer", "TIMER_IMPERSONATES_ACTOR", ctx.rel, scope, start + 1,
        f"elapsed gate + {normalize(consequence_lines[0])}",
        ctx.writer, "the actor authority (porter/NPC/mechanism owner)",
        "STRONG" if ctx.writer == "coordinator" else "HEURISTIC",
        "elapsed time itself performs the actor's action (arrival, "
        "repair, knowledge, mechanism change) instead of dispatching "
        "an actor who does it",
        "let the timer schedule an actor event; the actor authority "
        "applies the consequence and leaves its own evidence",
        "DELEGATE_TO_OWNER" if ctx.writer == "coordinator"
        else "REVIEW",
        ctx.tier))


def _scan_proximity(ctx, findings, line, scope, line_no):
    if ctx.tier == "test":
        return  # tests position players by design; not autonomy claims
    if not PROXIMITY_RE.search(line):
        return
    if not AUTONOMY_CLAIM_RE.search(ctx.text):
        return
    findings.append(make_finding(
        "proximity", "AUTONOMY_DEPENDS_ON_PROXIMITY", ctx.rel, scope,
        line_no, line, ctx.writer, "a persistence-owning scheduler",
        "HEURISTIC",
        "a system that claims autonomy gates progression on player "
        "presence; the world may stop when the player leaves",
        "confirm progression continues when the player is absent and "
        "the scene is unloaded (save-time catch-up or global tick)",
        "REVIEW", ctx.tier))


def _scan_scene_local_autonomy(ctx, findings):
    """A coordinator that claims autonomy but only advances inside its
    own _process writes durable facts that stop accruing the moment the
    scene unloads - autonomy that quietly depends on being loaded."""
    if ctx.writer != "coordinator":
        return
    if not AUTONOMY_CLAIM_RE.search(ctx.text):
        return
    process_body = ctx.function_body("_process")
    if not process_body:
        return
    if not (DURABLE_CONTEXT_RE.search(process_body) or
            re.search(r"advance_|situation\.", process_body)):
        return
    start = next((s for n, s, _e in ctx.functions
                  if n == "_process"), 0)
    findings.append(make_finding(
        "proximity", "AUTONOMY_DEPENDS_ON_PROXIMITY", ctx.rel,
        "_process", start + 1,
        "autonomy-claiming coordinator advances durable state only "
        "inside scene-local _process",
        ctx.writer, "a persistence-owning scheduler or save-time "
        "catch-up",
        "HEURISTIC",
        "progression stops when the scene is unloaded or the node is "
        "absent; 'autonomous' consequences exist only near a running "
        "scene",
        "prove the situation advances across scene unload/save/load "
        "(catch-up on reconstruction or a global scheduler)",
        "REVIEW", ctx.tier))


def _scan_host_clock(ctx, findings, line, scope, line_no):
    if not HOST_CLOCK_RE.search(line):
        return
    body = ctx.function_body(scope)
    profiling = PROFILING_CONTEXT_RE.search(line) or \
        PROFILING_CONTEXT_RE.search(scope)
    if profiling and not DURABLE_CONTEXT_RE.search(line):
        return  # profiling / perf measurement / debug timing
    if not DURABLE_CONTEXT_RE.search(line):
        # The clock value itself must feed a durable sink on this line;
        # body-level context alone stays cosmetic/local.
        return
    findings.append(make_finding(
        "host-clock", "HOST_CLOCK_MUTATES_WORLD", ctx.rel, scope,
        line_no, line, ctx.writer, "simulation clock authority",
        "STRONG" if "RealityState" in (body or "") or
        "commit(" in (body or "") else "HEURISTIC",
        "durable world state derives from the host wall clock; "
        "save/load and real-world time changes mutate the world",
        "derive the fact from the simulation clock, or document an "
        "explicit contract authorizing wall-clock use here",
        "REVIEW" if ctx.tier == "test" else "DOCUMENT",
        ctx.tier))


def _scan_objective(ctx, findings, line, scope, line_no):
    if ctx.tier == "test":
        return
    m = OBJECTIVE_STRING_RE.search(line)
    is_tracker = "objective_tracker" in ctx.rel
    if not m and not (is_tracker and OBJECTIVE_RE.search(line)):
        return
    if "/arcade/" in ctx.rel:
        return  # diegetic game-within-a-game copy
    if ctx.writer not in ("presentation",) and not is_tracker:
        return
    findings.append(make_finding(
        "objective-ui", "OBJECTIVE_UI_LEAK", ctx.rel, scope, line_no,
        line if m else "objective tracker surface",
        ctx.writer, "diegetic presentation (work papers, prompts)",
        "STRONG" if is_tracker else "HEURISTIC",
        "objective-shaped presentation survives in player-facing UI; "
        "the environment reads as an assigned quest",
        "replace with diegetic artifacts (work paper, prompt, radio) "
        "or scope the surface to debug builds",
        "BASELINE_DEBT", ctx.tier))


def _scan_judgment(ctx, findings, line, scope, line_no):
    if not JUDGMENT_RE.search(line):
        return
    if ctx.tier == "test":
        return  # test verdicts are not moral facts
    if not (JUDGMENT_DURABLE_RE.search(line) or
            JUDGMENT_DURABLE_RE.search(ctx.function_body(scope) or "")):
        return  # technical result enum / local use
    findings.append(make_finding(
        "judgment", "ABSTRACT_JUDGMENT_FACT", ctx.rel, scope, line_no,
        line, ctx.writer, "concrete world facts",
        "HEURISTIC",
        "a generic moral/compliance verdict replaces concrete facts "
        "in durable or player-facing state",
        "store what physically happened (valve open, part missing, "
        "who saw it) and derive any judgment at read time",
        "FIX", ctx.tier))


def _scan_dynamic(ctx, findings, line, scope, line_no):
    m = DYNAMIC_RE.search(line)
    if not m:
        return
    target = next((g for g in m.groups() if g), "")
    if not target:
        return
    monitored = re.search(
        r"record_fact|apply_|resolve|begin_compensation|knowledge|"
        r"custody|repair|consume|acquire", target)
    if not (KNOWLEDGE_CONCEPT_RE.search(target) or
            CUSTODY_RE.search(target) or monitored):
        return
    findings.append(make_finding(
        "npc-knowledge" if KNOWLEDGE_CONCEPT_RE.search(target)
        else "custody" if CUSTODY_RE.search(target) else "timer",
        "DYNAMIC_UNRESOLVED", ctx.rel, scope, line_no, line,
        ctx.writer, "unknown (dynamic dispatch)",
        "UNKNOWN",
        "a dynamic call touches a monitored concept; static analysis "
        "cannot resolve the writer",
        "resolve the dynamic target by hand and reclassify",
        "REVIEW", ctx.tier))


def _scan_test_proof(ctx, findings):
    claims = bool(TEST_CLAIM_RE.search(ctx.rel)) or bool(
        TEST_CLAIM_RE.search(ctx.text[:400]))
    if not claims:
        return
    shortcut_lines = []
    for i in range(len(ctx.lines)):
        line = ctx.code_line(i)
        if TEST_SHORTCUT_CALL_RE.search(line):
            shortcut_lines.append((i, line))
    if not shortcut_lines:
        return
    if TEST_PUBLIC_RE.search(ctx.text):
        return  # exercises a public interaction somewhere; give benefit
    i, line = shortcut_lines[0]
    findings.append(make_finding(
        "test-proof", "TEST_AUTHORITY_SHORTCUT", ctx.rel,
        ctx.scope_at(i), i + 1,
        f"{len(shortcut_lines)} direct consequence call(s), first: "
        f"{normalize(line)}",
        "test", "public interaction surface (interact/prompt/input)",
        "HEURISTIC",
        "the test claims player-behavior proof but drives internal "
        "consequence methods directly; range/stance/prompt "
        "prerequisites are never exercised",
        "add a public-interaction path (input or interact()) before "
        "asserting the consequence, or rename the claim",
        "ADD_PUBLIC_PROOF", "test"))


def _scan_dead_ends(ctx, findings):
    if ctx.writer not in ("coordinator", "world_system"):
        return
    if not re.search(r"\bmatch\s+", ctx.text):
        return
    has_stage_machine = re.search(
        r'match\s+[a-z_]*(stage|state|beat|phase)', ctx.text)
    if not has_stage_machine:
        return
    has_escape = re.search(
        r"elapsed|timeout|compensat|fallback|abandon|expire|decay|"
        r"alternate|porter|neglect", ctx.text)
    if has_escape:
        return
    gates_progress = re.search(
        r'==\s*"(closed|complete|repaired|done)"', ctx.text)
    if not gates_progress:
        return
    m = re.search(r'match\s+[a-z_]*(?:stage|state|beat|phase)[^\n]*',
                  ctx.text)
    index = ctx.text[:m.start()].count("\n")
    findings.append(make_finding(
        "dead-end", "COMPLIANCE_DEAD_END", ctx.rel,
        ctx.scope_at(index), index + 1, m.group(0),
        ctx.writer, "a continued-world alternative",
        "HEURISTIC",
        "a stage machine appears to wait forever for player "
        "compliance: no timeout, compensator or alternate resolution "
        "is in evidence, and progression gates on completion",
        "confirm by hand whether the world continues without the "
        "player's compliance; add a compensator or neglect path if "
        "not",
        "REVIEW", ctx.tier))


# ---------------------------------------------------------------------------
# Repository scan
# ---------------------------------------------------------------------------

def scan_repository(root: Path, production_only: bool,
                    domains: list[str] | None) -> list[dict]:
    findings: list[dict] = []
    bases = ["game/scripts"]
    if not production_only:
        bases.append("game/tests")
    for base in bases:
        base_path = root / base
        if not base_path.is_dir():
            continue
        for path in sorted(base_path.rglob("*.gd")):
            rel = path.relative_to(root).as_posix()
            try:
                text = path.read_text(encoding="utf-8",
                                      errors="replace")
            except OSError:
                continue
            ctx = FileContext(rel, text)
            scan_file(ctx, findings)
    if domains:
        findings = [f for f in findings if f["domain"] in domains]
    # Deterministic order + stable dedupe by identity.
    unique: dict[str, dict] = {}
    for finding in findings:
        unique.setdefault(finding["id"], finding)
    return sorted(unique.values(),
                  key=lambda f: (f["file"], f["domain"], f["class"],
                                 f["scope"], f["evidence"]))


# ---------------------------------------------------------------------------
# Baseline
# ---------------------------------------------------------------------------

def load_baseline(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise MalformedError(f"cannot read baseline {path}: {exc}")
    except json.JSONDecodeError as exc:
        raise MalformedError(f"malformed baseline {path}: {exc}")
    if not isinstance(data, dict) or not isinstance(
            data.get("entries"), list):
        raise MalformedError(
            f"malformed baseline {path}: missing entries list")
    seen = set()
    for entry in data["entries"]:
        if not isinstance(entry, dict) or "id" not in entry:
            raise MalformedError(
                f"malformed baseline {path}: entry without id")
        if entry["id"] in seen:
            raise MalformedError(
                f"duplicate baseline entry {entry['id']}")
        seen.add(entry["id"])
        if entry.get("class") not in CLASSES:
            raise MalformedError(
                f"malformed baseline {path}: bad class on "
                f"{entry['id']}")
        if entry.get("confidence") not in CONFIDENCES:
            raise MalformedError(
                f"malformed baseline {path}: bad confidence on "
                f"{entry['id']}")
    return data


def diff_baseline(baseline: dict, findings: list[dict]) -> dict:
    base_by_id = {e["id"]: e for e in baseline.get("entries", [])}
    new_actionable, new_review, covered = [], [], []
    policy_violations = []
    for finding in findings:
        entry = base_by_id.get(finding["id"])
        if entry is None:
            if finding["tier"] == "production" and \
                    finding["disposition"] in ACTIONABLE:
                new_actionable.append(finding)
            else:
                new_review.append(finding)
            continue
        # A baseline entry never suppresses a different class, a
        # higher-confidence mutation, or a production finding via a
        # test-tier entry.
        if entry.get("class") != finding["class"]:
            policy_violations.append(
                {"finding": finding, "entry": entry,
                 "why": "class changed"})
        elif CONFIDENCES.index(finding["confidence"]) > \
                CONFIDENCES.index(entry.get("confidence", "UNKNOWN")):
            policy_violations.append(
                {"finding": finding, "entry": entry,
                 "why": "confidence increased"})
        elif entry.get("tier") == "test" and \
                finding["tier"] == "production":
            policy_violations.append(
                {"finding": finding, "entry": entry,
                 "why": "test-tier entry cannot baseline a "
                        "production finding"})
        else:
            covered.append(finding)
    vanished = [e for eid, e in sorted(base_by_id.items())
                if eid not in {f["id"] for f in findings}]
    return {"new_actionable": new_actionable, "new_review": new_review,
            "covered": covered, "vanished": vanished,
            "policy_violations": policy_violations}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Systemic situation-authority audit "
                    "(ADMIN-ETHOS1; read-only).")
    parser.add_argument("--root", default=".")
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--production-only", action="store_true")
    parser.add_argument("--domain", action="append", choices=DOMAINS)
    parser.add_argument("--baseline")
    parser.add_argument("--write-baseline",
                        help="write a reviewed baseline (refused inside "
                             "game/, art/ or design/)")
    parser.add_argument("--compare",
                        help="previous --json report to diff against")
    return parser


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
    except MalformedError as exc:
        print(f"MALFORMED: {exc}", file=sys.stderr)
        return 4
    except Exception as exc:  # pragma: no cover - defensive
        print(f"INTERNAL: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 70


def summarize(findings: list[dict]) -> dict:
    def tally(key):
        out: dict[str, int] = {}
        for finding in findings:
            out[finding[key]] = out.get(finding[key], 0) + 1
        return dict(sorted(out.items()))
    return {
        "findings": len(findings),
        "by_class": tally("class"),
        "by_confidence": tally("confidence"),
        "by_domain": tally("domain"),
        "by_tier": tally("tier"),
        "by_disposition": tally("disposition"),
    }


def run(args) -> int:
    root = Path(args.root).resolve()
    if not root.is_dir():
        raise AuditError(f"root {root} is not a directory")
    findings = scan_repository(root, args.production_only, args.domain)
    summary = summarize(findings)

    if args.write_baseline:
        target = Path(args.write_baseline)
        if not target.is_absolute():
            target = root / target
        resolved = target.resolve()
        for guarded in ("game", "art", "design"):
            if resolved.is_relative_to((root / guarded).resolve()):
                raise AuditError(
                    f"refusing to write baseline inside "
                    f"{root / guarded}; use a tools/ path")
        baseline = {
            "baseline_version": 1,
            "tool_version": TOOL_VERSION,
            "entries": [
                {"id": f["id"], "domain": f["domain"],
                 "class": f["class"], "file": f["file"],
                 "scope": f["scope"], "evidence": f["evidence"],
                 "confidence": f["confidence"], "tier": f["tier"],
                 "disposition": f["disposition"]}
                for f in findings],
        }
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            json.dumps(baseline, indent=1, sort_keys=False) + "\n",
            encoding="utf-8")
        print(f"baseline written: {target} "
              f"({len(baseline['entries'])} entries)")
        return 0

    if args.baseline:
        # An explicit baseline resolves against the invoker's working
        # directory, so a main-branch baseline can gate a --root scan
        # of another checkout.
        baseline_path = Path(args.baseline)
        if not baseline_path.is_absolute():
            baseline_path = Path.cwd() / baseline_path
    else:
        baseline_path = root / DEFAULT_BASELINE
    drift = None
    malformed = False
    if baseline_path.is_file():
        try:
            baseline = load_baseline(baseline_path)
            drift = diff_baseline(baseline, findings)
        except MalformedError:
            actionable_now = [f for f in findings
                              if f["tier"] == "production" and
                              f["disposition"] in ACTIONABLE]
            if actionable_now:
                print("MALFORMED baseline plus actionable findings",
                      file=sys.stderr)
                return 5
            raise
    else:
        drift = diff_baseline({"entries": []}, findings)

    payload = {
        "tool_version": TOOL_VERSION,
        "summary": summary,
        "findings": findings if args.verbose or args.as_json else
        [f for f in findings if f["disposition"] in ACTIONABLE or
         args.verbose],
        "drift": {k: v for k, v in drift.items()},
    }

    comparison = None
    if args.compare:
        old_path = Path(args.compare)
        if not old_path.is_absolute():
            old_path = root / args.compare
        try:
            old = json.loads(old_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise MalformedError(f"cannot read compare report: {exc}")
        old_ids = {f["id"] for f in old.get("findings", [])}
        new_ids = {f["id"] for f in findings}
        comparison = {
            "added": sorted(new_ids - old_ids),
            "removed": sorted(old_ids - new_ids),
        }
        payload["comparison"] = comparison

    if args.as_json:
        print(json.dumps(payload, indent=1, sort_keys=False))
    else:
        print("systemic situation-authority audit")
        for key, value in summary.items():
            if isinstance(value, dict):
                value = ", ".join(f"{k}={v}" for k, v in value.items())
            print(f"  {key}: {value}")
        for label, rows in (
                ("NEW actionable (FAIL)", drift["new_actionable"]),
                ("baseline policy violations (FAIL)",
                 drift["policy_violations"]),
                ("new review-only", drift["new_review"]),
                ("vanished baseline entries (cleanup)",
                 drift["vanished"])):
            print(f"{label}: {len(rows)}")
            limit = None if args.verbose else 8
            for row in rows[:limit]:
                finding = row.get("finding", row)
                print(f"  - {finding.get('class')} "
                      f"{finding.get('file')}:{finding.get('scope')} "
                      f"[{finding.get('confidence')}]")
            if limit is not None and len(rows) > limit:
                print(f"  ... {len(rows) - limit} more (--verbose)")
        if comparison:
            print(f"compare: +{len(comparison['added'])} "
                  f"-{len(comparison['removed'])}")

    if drift["new_actionable"] or drift["policy_violations"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
