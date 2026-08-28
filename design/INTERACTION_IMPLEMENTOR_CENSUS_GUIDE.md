# Interaction implementor census — usage and interpretation

`tools/audit_interaction_implementors.py` implements **T10** of
`design/INTERACTION_CONTRACT_2026-08-27.md`: a checked-in manifest of every
`interact_prompt` / `control_prompt` implementor
(`tools/interaction_implementor_manifest.json`) and a source-only audit
that fails when the interaction surface changes without classification.
T10 is what keeps the contract's census true past its date.

**This is a drift detector, not an engine interface.**  `has_method`
dispatch enforces spelling only; the game deliberately runs on a stable
implicit protocol (contract §A, §G rung 1), and this manifest changes
nothing about dispatch — it only refuses to let the census rot silently.
T2 (`audit_interaction_prompt_carriers.py`) owns prompt *text*; T10 owns
implementor *classification*.  They share no rules and neither replaces
the other.

## Running it

```
python tools/audit_interaction_implementors.py
    [--root game/scripts] [--manifest <json>] [--json] [--verbose]
    [--update-manifest]
```

Default: discover every prompt definition under `game/scripts`, trace its
action relationship, and compare against the manifest.  `--update-manifest`
is the only way the manifest changes; run it deliberately and review the
diff like any other source change.

## What the manifest classifies

Per implementor (identity = file + prompt family, deliberately
line-independent):

- **family**: `interact_prompt` or `control_prompt`;
- **role**: `production`, `debug-only` (the contract's two known files),
  or `adapter` (`PropControlArea`);
- **protocol**: `whole-object`, `named-control`, `composed/interact-area`;
- **action owner/method/source**: which node answers the verb and where
  the answer was found;
- **rationale** and an **extraction disposition** (`game-only`,
  `reusable-with-work`, `infrastructure/adapter`) — generated dispositions
  are defaults for the post-EA boundary review, not decisions.

## How action relationships are traced

Conservative source tracing, in order:

1. a same-file action method (`interact` / `interact_control` /
   `interact_area`) at **any indentation** — inner-class implementors
   (e.g. `reality/organism_incidents.gd`) pair within their file with an
   explicit note that scope pairing is assumed, not proven;
2. `extends ClassName` resolved through `class_name` declarations, walking
   the chain (this is how `projector_prop.gd` → `TVProp.interact`
   resolves — pinned by a production smoke test);
3. `extends "res://….gd"` resolved by path suffix;
4. same-file `interact` that immediately delegates to `get_parent()` is
   classified `parent/delegate`;
5. the adapter pattern: invoking the parent mechanism's `control_prompt`
   **and** `interact_control` (directly or via `call("…")`);
6. composed `interact_area` dispatch (`wayfinding_signage_pass.gd` —
   pinned).

Anything else is `ACTION_UNRESOLVED`.  A whole-object implementor may be
*deliberately* recorded as `action_owner: "unresolved"` in the manifest
(tolerated, visible); a `control_prompt` without a resolvable
`interact_control`, an adapter without its target, or a
previously-resolved relationship that stops resolving always fails.

## What fails (exit 1)

New unclassified implementor · manifest entry with no implementor (STALE —
deliberate removals are reconciled by an explicit `--update-manifest`
after review, never accepted silently) · prompt-family change · file move
without reconciliation (surfaces as STALE + UNCLASSIFIED) · any
role/protocol/action divergence between manifest and source (including a
production implementor silently marked debug) · missing required
relationships · manifest/source totals disagreeing.

Malformed manifests (missing keys, invalid enum values, duplicate
identities) exit 4; drift plus malformation exits 5; usage errors 3;
internal failure 70.

## Adding a new interaction implementor correctly

1. Write the prop following the contract (semantic prompt text — T2 —
   plus its action method).
2. Run this audit; it fails UNCLASSIFIED.
3. Run `--update-manifest`, review the generated entry (role, protocol,
   action tracing, rationale), adjust the rationale/extraction fields if
   the defaults are wrong, and commit the manifest change *with* the prop.
4. The reviewed manifest diff **is** the classification record.

## What remains runtime-only

Scene-tree composition (`.tscn`-authored nodes), whether a `ControlArea`
is positioned where a ray can reach it, prompt/action landing on the same
ancestor at runtime (contract T4), and everything K2 measures with humans.
A green census proves the surface is fully classified and its statically
traceable relationships hold — never reachability, usability, or prompt
content (T2's job).

## Current production census (2026-08-28)

85 implementors: 67 `interact_prompt` + 18 `control_prompt`; roles 82
production + 2 debug-only + 1 adapter; protocols 66 whole-object + 18
named-control + 1 composed; actions 82 same-file (one inner-class, one
parent-delegate, and the `f572896` radiator interaction surface - the
census's first live drift catch, classified the day it landed), 1 inherited (`projector_prop.gd` ← `tv_prop.gd`),
1 composed (`wayfinding_signage_pass.gd`), 1 adapter target
(`prop_control_area.gd`), 0 unresolved required relationships.  The audit
and manifest agree: exit 0.

## Tests

```
python tools/tests/test_interaction_implementors.py
```

31 tests: fixture classifications for every protocol/role/tracing path
(class-name and script-path inheritance, adapter, composition, parent
delegation, inner-file pairing, unresolved dynamic), drift scenarios (new,
removed, renamed, family flip, role reclassification, adapter target loss,
missing named-control action, disappearing inheritance, line-number
immunity, tolerated declared-unresolved), manifest validation (duplicates,
invalid enums, unreadable, missing), deterministic output, git/Godot-free
operation, and production smoke checks pinning the exact census counts and
the two contract-resolved cases.
