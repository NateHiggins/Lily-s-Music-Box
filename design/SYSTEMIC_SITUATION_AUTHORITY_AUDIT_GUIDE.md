# Systemic situation-authority audit — usage guide

**Task:** ADMIN-ETHOS1. **Tool:**
`tools/audit_systemic_situation_authority.py` (read-only, standard
library, deterministic). **Baseline:**
`tools/systemic_situation_authority_baseline.json` (reviewed main-branch
debt). **Tests:** `tools/tests/test_systemic_situation_authority.py`
(34, fixture-backed).

The audit exists to protect one ethos boundary: **a narratively shaped
virtual environment must not smuggle objective-driven quest logic back in
under other names.** Situations, not assigned objectives; work optional;
neglect produces continued world state; NPCs interpret events through
their own authorities; mechanisms own physical consequences; inventory
owns custody; saves keep concrete facts; coordinators schedule and
observe but never fabricate what everyone knows; no hidden morality
score; no tutorial/objective leakage; no host wall-clock world mutation.

## Running it

```bash
python tools/audit_systemic_situation_authority.py            # gate vs baseline
python tools/audit_systemic_situation_authority.py --json     # machine output
python tools/audit_systemic_situation_authority.py --verbose
python tools/audit_systemic_situation_authority.py --production-only
python tools/audit_systemic_situation_authority.py --domain npc-knowledge
python tools/audit_systemic_situation_authority.py --baseline tools/systemic_situation_authority_baseline.json --root <other-checkout>
python tools/audit_systemic_situation_authority.py --write-baseline tools/systemic_situation_authority_baseline.json
python tools/audit_systemic_situation_authority.py --compare old_report.json
```

Domains: `npc-knowledge physical custody timer proximity host-clock
objective-ui dead-end judgment test-proof`. An explicit `--baseline`
resolves against the invoking directory, so main's baseline can gate a
`--root` scan of a feature-branch checkout. `--write-baseline` refuses
`game/`, `art/` and `design/` destinations.

**Exit codes:** 0 clean vs baseline (REVIEW-only findings allowed) ·
1 new actionable production finding or baseline-policy violation ·
3 usage/refused output · 4 malformed baseline/input · 5 actionable +
malformed combined · 70 internal.

## Finding classes

`DIRECT_NPC_KNOWLEDGE_WRITE` · `FOREIGN_PHYSICAL_MUTATION` (with the
rightful `RealityState.data` subtree owner named) · `DUPLICATE_CUSTODY` ·
`TIMER_IMPERSONATES_ACTOR` · `AUTONOMY_DEPENDS_ON_PROXIMITY` ·
`HOST_CLOCK_MUTATES_WORLD` · `OBJECTIVE_UI_LEAK` ·
`COMPLIANCE_DEAD_END` · `ABSTRACT_JUDGMENT_FACT` ·
`TEST_AUTHORITY_SHORTCUT` · `DYNAMIC_UNRESOLVED`.

Every finding carries a line-independent identity (domain, class, file,
scope, normalized expression), the apparent writer and rightful owner, a
confidence (`EXACT/STRONG/HEURISTIC/UNKNOWN`), the player/world risk, a
suggested verification, and a disposition (`FIX / DELEGATE_TO_OWNER /
ADD_PUBLIC_PROOF / DOCUMENT / BASELINE_DEBT / REVIEW`). Only
production-tier findings with actionable dispositions fail the gate;
REVIEW and test-tier findings report without failing (test shortcuts are
listed so a landing review can weigh them).

## What the heuristics deliberately do NOT flag

- An NPC/perception/conversation authority recording its **own**
  observation.
- A coordinator **calling the owning domain's API**
  (`radiator.apply_condition(...)`) — delegation is the intended shape.
- A timer that **schedules** (emits/dispatches) an actor event.
- Profiling/perf/debug timing and cosmetic clocks.
- Objective vocabulary in dialogue, docs, tests, or the arcade's
  game-within-a-game; diegetic work papers.
- Test verdict enums and technical success/failure results.
- Ordinary unit tests of small methods — `TEST_AUTHORITY_SHORTCUT` fires
  only when the test's name/claim says player-behavior proof and no
  public interaction surface is exercised.

## Baseline policy

New actionable production findings fail. A baselined finding whose class
changes, whose confidence rises, or whose production tier is covered
only by a test-tier entry fails. Vanished entries are cleanup
opportunities. Malformed/duplicate baselines fail (exit 4; 5 when
actionable findings coexist). Output is byte-identical across runs.

The current baseline (49 entries: 32 production, 17 test) records
main-branch debt only — notably the `objective_tracker` HUD surface, the
building-personality trust writes, one abstract judgment string, the
unix-time save stamps in work orders/inventory (DOCUMENT), dream-realm
proximity heuristics and 13 dynamic-dispatch unknowns. **The Open Shift
feature branch's known problems are deliberately NOT baselined** — the
gate is supposed to catch them at landing time.

## Use in the Open Shift landing gate

Run main's baseline against the candidate checkout:

```bash
python tools/audit_systemic_situation_authority.py --root <open-shift-checkout> --baseline tools/systemic_situation_authority_baseline.json
```

Validated against `origin/codex/ethos-open-shift` (`e5cbc3d`), this
exits 1 with 14 new findings, all in the Open Shift files: 8× STRONG
coordinator-authored `npc_knowledge`/`relationship_consequence` writes,
1× STRONG timer-bucket → porter compensation/shutoff
(`TIMER_IMPERSONATES_ACTOR`), 1× STRONG string-only packing custody, 1×
scene-local `_process` autonomy risk, and 3× direct-method meddling
proofs (`TEST_AUTHORITY_SHORTCUT`). Landing requires either fixing them
(delegate knowledge to observers, dispatch a porter actor, prove custody
through the inventory authority, add public-interaction proof) or an
explicit reviewed baseline update — never a silent pass.

Recommended integration command after every ethos-relevant change:

```bash
python tools/audit_systemic_situation_authority.py && python tools/tests/test_systemic_situation_authority.py
```

## False-positive risks and limitations

- Textual heuristics, not GDScript semantics: dynamic dispatch, helper
  indirection and cross-file delegation are reported as
  `DYNAMIC_UNRESOLVED`/`HEURISTIC`, never as certainty.
- Writer classification is path/name-based; a mis-homed file inherits
  the wrong writer class (fix by moving the file or extending the map).
- `COMPLIANCE_DEAD_END` is the weakest heuristic (token presence of
  escape vocabulary); treat every hit as a reading assignment.
- `AUTONOMY_DEPENDS_ON_PROXIMITY` cannot see save-time catch-up logic;
  a flagged system may be correct — verify across unload/save/load.
- The `RealityState.data` subtree owner map is curated; new subtrees
  need a row in `DATA_SUBTREE_OWNERS` in the same commit.
- Concept vocabularies (knowledge/custody/physical) are English token
  lists; renamed concepts evade them until the vocabulary is extended.
