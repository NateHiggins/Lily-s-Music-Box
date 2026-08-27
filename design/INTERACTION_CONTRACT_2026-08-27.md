# Interaction contract — 2026-08-27

**Base:** `c9846f1db627c8543bd9fbcd7cefebcbdb5a2c82` (pushed `origin/main`,
"ADMIN-INT1: record the interaction convention"). **Godot 4.7**
(`project.godot:22`).

**Origin advanced twice during this task.** Work began at `1f1bc80`; `bc6f167`
integrated ADMIN-ENG1 and `c9846f1` added Codex's own
`INTERACTION_CONVENTION_RECORD_2026-08-27.md` for this same assignment. **No
production file changed**, so every traced claim below was re-verified at
`c9846f1` and stands. **§M reconciles the two documents**, which disagree on two
counts and appear to disagree on the ruling.

**Godot was not run.** No import, capture, export, renderer or Blender. No code,
test, scene, data, `TASKS.md` or existing design document was modified. One new
file.

**No base class, registry, interface, component system, signal bus or refactor
is proposed here.** This describes the contract the game already obeys.

> **ADMIN-ENG1 said this surface had "no contract at all." That was wrong, and
> §A corrects it.** The correction is the main result of this audit: what looked
> like 66 unrelated duck-typed methods is three protocols, one adapter, and a
> discovery path that is more disciplined than its call sites suggest.

---

## A. Headline ruling

**A stable implicit protocol.** Not merely a convention; not yet
interface-ready.

**Why not "merely a convention":**

- Discovery and invocation both walk the collider's parent chain, in the same
  direction, in one place each (`player_controller.gd:326–333`, `:_try_interact`).
- **Empty prompt means unavailable** is implemented once, at the discovery site,
  not repeated per prop.
- Carrier formatting is centralised in one static function with a documented
  legacy-migration path (`format_interaction_prompt`, `:340–357`).
- The third protocol has an **adapter class**, `PropControlArea`, whose entire
  job is to present protocol 3 as protocol 1.
- **18 of 18** `control_prompt` definers construct a control area. That is not a
  convention people drift from; it is a rule with no exceptions in the tree.
- **Zero** production implementors present a prompt whose action does not exist
  once `extends` chains are resolved (§C.4).
- `FunctionalProp._build_primary_interaction()` **refuses to build an affordance
  unless both halves of the protocol are present** (`functional_prop.gd:57–58`) —
  a guard, written down, in the base class most props share.

**Why not "interface-ready":**

- There are **three** verb protocols, not one, and nothing names them.
- Two prompts are **hardcoded English inside the player controller**, bypassing
  object ownership entirely (`:316–324`).
- `interact` returns `Variant`; the schema is enforced downstream by
  `TelegramHud.card_from_interaction`, not at the call site.
- **`call_locked` is a public boolean** written directly by unrelated systems,
  with no acquire/release discipline (§E D3).
- No test fails when a new implementor is added unclassified.

### What would falsify this ruling

| If this were true | Ruling moves to |
| --- | --- |
| A production implementor presents a prompt for an action reachable by no code path | **merely a convention** |
| Two protocol-3 props disagree on `control_id` semantics, or a control area exists with no responder | **merely a convention** |
| The parent-chain walks can land the prompt on one node and the action on a different node in a shipped scene | **merely a convention** |
| A named schema for `interact`'s return existed and were enforced at the call site, and `call_locked` had an owner | **interface-ready** |

**INFERENCE:** row 3 is the one I could not fully discharge — see §K.

---

## B. The actual call chain

Every step, with the owner permitted to decide that fact.

| # | Step | Code | Who may decide |
| --- | --- | --- | --- |
| 1 | **Physical input** | `Input.is_action_just_pressed("interact")`, polled in `_process` (`:369`) | `GameBoot` owns the InputMap; **E, and joypad A** |
| 2 | **Modal gate** | fires only `if not call_locked or is_instance_valid(seated_interaction)` | Whoever set `call_locked` — **currently anyone** |
| 3 | **Ray** | camera origin → `basis * Vector3(0,0,-2.1)`; `collide_with_areas = true`; excludes self | The player. **Reach is 2.1 m and it is a literal in two places** |
| 4 | **Special cases** | if the collider is an `Area3D` with meta `call_level` or `cabin_panel`, the prompt is a **hardcoded string in the controller** (`:316–324`) | **The controller — a deviation (§E D2)** |
| 5 | **Prompt discovery** | walk `node = node.get_parent()` until `has_method("interact_prompt")` | **The nearest ancestor that answers.** The object owns its words |
| 6 | **Carrier formatting** | `format_interaction_prompt` strips a leading `[E]`/`[A]`/`[TAP]` and prepends the device's own | **The controller owns the carrier. The prop owns the action text** |
| 7 | **Availability** | `_prompt_panel.visible = _prompt.text != ""` | **The prop, by returning `""`** |
| 8 | **Invocation** | second, independent walk: `interact_area(area)` if the collider is an `Area3D` and the node answers it; else `interact(self)` | **The nearest ancestor that answers — possibly a different node than step 5** |
| 9 | **Result** | `Variant` → `_present_interaction_telegram(owner, result)` | The prop returns; the presenter interprets |
| 10 | **Result schema** | `TelegramHud.card_from_interaction`: a `Dictionary` with a non-empty `body`, else the owner's `service_wire_card()`, else `{}` | **TelegramHud.** Two accepted shapes, one fallback |
| 11 | **Presentation suppression** | returns early if `call_locked` — "a field note can never cover dialogue or a call surface" | The controller |
| 12 | **World signal** | `world_modified.emit(position, name)` fires **after every invocation**, whatever the result | The controller |
| 13 | **Audible answer** | the prop requests a semantic cue; `AudioPolicy` arbitrates | **The prop owns the fact; policy owns intelligibility** |
| 14 | **Persistence** | `RealityState` / `WorkOrders` | **Not the prop, and not the presenter** |

**Two facts about this chain worth stating plainly.** Step 5 and step 8 are
**separate walks with different predicates**, so the node that supplies the
words is not guaranteed to be the node that performs the act. And step 12 fires
unconditionally — **`world_modified` means "someone was interacted with", not
"something changed".**

---

## C. Implementor census

### C.1 Counts, by reproducible command

```
grep -rlF 'func interact_prompt(' game/scripts --include=*.gd | wc -l   → 66
grep -rlF 'func interact('        game/scripts --include=*.gd | wc -l   → 72
grep -rlF 'func interact_area('   game/scripts --include=*.gd | wc -l   → 6
grep -rlF 'func control_prompt('  game/scripts --include=*.gd | wc -l   → 18
grep -rlE '(PropControlArea|ControlArea)\.new\(\)' … | wc -l            → 18
```

**The 66 prompt definers break down as 63 + 2 + 1:**

| Class | Count | Which |
| --- | --- | --- |
| **Production** | **63** | Everything not listed below |
| **Debug-only** | **2** | `characters/npc_placeholder.gd`; `building/light_debug_handle.gd` (reachable only through the env-gated light-inspection path) |
| **Prototype / unplaced** | **1** | counted within the two above — see note |
| **Dead** | **0 found** | |

**Note, so the arithmetic is honest:** `light_debug_handle.gd` is both the
prototype and one of the two debug-only entries; **63 + 2 = 65, and the
sixty-sixth is `props/prop_control_area.gd`, the adapter**, which is production
infrastructure rather than an interactable object.

**Two further files reference `developer_overlays_enabled` but are production**:
`cases/case_interactable.gd` and `characters/animated_resident.gd` gate only a
nameplate or a generic title, not the interaction.

**Not in the 66 at all** — they define `interact` without a prompt and are not
player-controller driven: `arcade/swc_door.gd`, `arcade/swc_pickup.gd`.

### C.2 The three protocols

| # | Protocol | Shape | Definers | Used for |
| --- | --- | --- | --- | --- |
| **1** | Whole-object verb | `interact_prompt() -> String` + `interact(player) -> Variant` | 66 / 72 | Doors, lamps, switches, most props |
| **2** | Area-identified verb | `interact_area(area) -> Dictionary` | 6 | One object, several distinguishable areas |
| **3** | Named control | `control_prompt(id) -> String` + `interact_control(id, player) -> Variant`, adapted by `PropControlArea` | **18, with 18 area constructors** | Multi-control mechanisms |

**`PropControlArea` is the contract made explicit.** It is an `Area3D` that
implements protocol 1 by delegating to its parent's protocol 3, and its own
docstring states the rule: *"The area owns no appliance state. It names the
physical control the ray reached, asks the parent mechanism for the current
prompt, and returns the parent's authoritative interaction result."*

### C.3 Production families

Grouped; **the complete path list is in the appendix (§L), unabridged.**

| Family | n | Target | Verbs | Mutates | Modal | Audible | Persistence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Multi-control mechanisms** (boiler, fuse panel, dumbwaiter, mail chute, ballcock, interlock, watch station/register, night register, tour key, extinguisher, fire line, door closer, otis, washer, airer, watchman detector, baked furniture) | 18 | own `ControlArea` per control | 3 | yes — via own director | some | yes | via owner |
| **Doors and access** (`door_prop`, `case_door_prop`, `door_anomaly_prop`, `door_check_closer_prop`) | 4 | StaticBody/Area | 1 | yes | no | yes | — |
| **Switches and fixtures** (lamp, switch plate, radiator, tap, stove, kettle, toaster, fridge, boxfan, exhaust fan, flue) | ~11 | body | 1 | local device state | no | yes | — |
| **Panels and terminals** (songbook terminal, arcade cabinet, monitor, projector→`TVProp`, tv, point ball, darts, dead letters, fortune) | ~9 | body | 1 | opens UI | **yes** | some | some |
| **Reading surfaces** (signage, bulletin, ad board, marquee, entry sign, bodega/harukiya/shop signs, bookshelf, mail bank/box) | ~12 | body/Area | 1 or 2 | **none — inspection only** | no | recent cues | none |
| **Zones** (`bench_zone`, `bar_seat_zone`, `desk_zone`, `inspectable_zone`, `mail_box_zone`) | 5 | Area3D | 1 | seat/inspect | seated path | some | — |
| **People** (`animated_resident`) | 1 | body | 1 | conversation | **yes** | yes | case state |
| **Case objects** | 1 | body | 1 | case | no | — | case |

### C.4 Asymmetry check — and a correction to my own first pass

**Prompt without action: ZERO**, once `extends` chains are resolved.

My first pass flagged two files. Both were wrong and I checked before reporting:
`projector_prop.gd` **extends `TVProp`** and inherits its `interact`;
`wayfinding_signage_pass.gd` implements **`interact_area`**, which my initial
`func interact(` pattern did not match.

**Action without prompt: 9 files, and none is a defect.** Six extend
`FunctionalProp` and use protocol 3 — each builds its own `ControlArea`, which
carries the prompt. Two are arcade-internal. One is `building/elevator.gd`,
whose prompts are the controller's hardcoded strings (§E D2).

**This is the audit's central lesson.** Three separate times, a count that looked
like a defect dissolved under tracing. **The raw `has_method` census is not
evidence of disorder.**

---

## D. Minimum behavioral contract

Plain language first; pseudocode is descriptive, **not a proposed API**.

1. **Empty prompt means unavailable.** Returning `""` hides the affordance and
   is the only supported way to say "not now".
2. **Prompts carry semantic action text, never a device truth.** No prop writes
   `[E]`, `[A]` or a button glyph. The carrier is the controller's.
3. **Physical reach exists and is measurable.** Today it is **2.1 m** from the
   camera along its forward basis.
4. **Interaction is idempotent or explicitly refusal-bearing.** A second press
   must either repeat harmlessly or return a refusal that the player can
   perceive.
5. **Presentation owns no durable story state.** The telegram presenter "cannot
   make a prop respond, open a job or acquire an item" — its own words.
6. **A modal owner acquires and releases input exactly once**, and restores the
   prior state rather than assuming it was free.
7. **Abort restores transient mechanism state and does not retract published
   external facts.** A cancelled repair returns the mechanism to its snapshot; it
   does not un-issue a work order already published.
8. **Success and refusal are truthful**, visually or through a semantic cue.
   Silence is only correct when nothing happened.
9. **Save mutations pass through the declared persistence owner** — `RealityState`
   or `WorkOrders`, never the prop or the presenter.
10. **A returned value is either consumed under a named schema or is
    inspection-only.** Today the schema is a `Dictionary` with a non-empty
    `body`, or a `service_wire_card()`, or `{}`.

```
on press:
    if modal_locked and not seated:            return
    hit ← ray(camera, 2.1 m, areas = true)
    if none:                                   return
    target ← nearest ancestor answering a verb
    result ← target.verb(context)
    present(result under schema | inspection-only)
    world_modified.emit(...)                   # "touched", not "changed"

invariant: prompt_of(x) == "" ⟺ x is unavailable now
invariant: prompt text contains no device carrier
invariant: persistence(x) routed via RealityState | WorkOrders
```

---

## E. Deviation register

**Recommendations only. Nothing was performed. Every row was traced to source.**

| ID | Severity | Deviation | Evidence | Smallest safe repair |
| --- | --- | --- | --- | --- |
| ~~D1~~ | **RESOLVED** | **Raw device text in the repair panel — fixed at this base and recorded so nobody re-reports it.** `control_hint(input_family)` now returns *"D-pad left/right to work it · A to commit · B to leave"* on a pad. Fixed by `3fa6fb4`, "Show the repair controls in the active input family" | `ui/maintenance_activity_panel.gd:197,212–215` | **None. Already done** |
| **D2** | **P2** | **Two prompts are owned by the controller, not the object.** `"Call elevator"` and `"Select next floor"` are hardcoded literals keyed off `Area3D` meta, bypassing `interact_prompt` entirely | `player_controller.gd:316–324`; `building/elevator.gd` defines `interact` and no prompt | Give the elevator areas an `interact_prompt`, delete the special case. **Behaviour-neutral** |
| **D3** | **P2** | **Modal ownership has no acquire/release.** `call_locked` is a public boolean assigned directly by at least four unrelated systems. One already saves and restores it manually — a defensive workaround for exactly this hazard | `call/call_interface.gd:294,309`; `audio/music_director.gd:353`; `audio/virus_sound_director.gd:104–127` (`_previous_call_locked`) | Document the ownership rule now; consider a counter only if a real double-release is observed |
| **D4** | **P2** | **`world_modified` fires on every invocation, including refusals**, so a listener cannot distinguish "touched" from "changed" | `player_controller.gd:_try_interact` — emitted after both `interact_area` and `interact`, unconditionally | Document the signal's true meaning. **Do not change the emission before K2** |
| **D5** | **P3** | **Reach is a literal repeated twice.** `Vector3(0,0,-2.1)` appears in both `_update_prompt` and `_try_interact`; they cannot drift apart silently but nothing prevents it | `player_controller.gd:308, _try_interact` | One named constant |
| **D6** | **P3** | **Two independent parent-chain walks.** Prompt and action may resolve to different ancestors | `:326–333` vs `_try_interact` | A test, not a change (§H T4) |
| **D7** | **P3** | **Return schema is enforced downstream only.** `interact` is `Variant`; a prop returning a malformed Dictionary fails silently to present | `ui/telegram_hud.gd:76–84` | Document the two accepted shapes |

**Deliberately not listed as defects:** the `has_method` dispatch itself; the
three protocols; `PropControlArea`'s existence. **None is a defect, and the
scope guard against replacing `has_method` for inelegance is correct.**

**No P0, and after `3fa6fb4` no P1 either.** Nothing traced here makes a
production interaction unreachable, and nothing here blocks a controller K2 run.

**INFERENCE — worth stating because I got it wrong once already:** my
ADMIN-ENG1 handoff named the repair panel's keyboard-only hint as the finding
most likely to stop the first pad run. **That was true at `4d1028b` and is false
at `1f1bc80`.** Re-checking every claim against the current tip is the only
reason this document does not carry a stale P1 as its headline recommendation.

---

## F. Second-project contract

The three primitive-room objects from ADMIN-ENG1, conforming **without importing
any Orison autoload, data file, id or story state**.

| Object | Protocol | Prompt | Action | Proves |
| --- | --- | --- | --- | --- |
| **A lamp** — immediate toggle | 1 | `"Turn on the lamp"` / `"Turn off the lamp"`; `""` if unpowered | `interact(player)` toggles, returns `{}` | Availability, idempotence, carrier neutrality |
| **A stiff valve** — refusal-bearing | 1 | `"Open the valve"`; `""` never — it stays visible while refusing | returns `{"body": "The valve will not turn."}` | Refusal is perceptible and truthful |
| **A two-step bench** — modal activity | 3 via `ControlArea` | `control_prompt("bench")` | `interact_control` opens a modal that acquires input once, runs two steps, supports abort with restoration | Modal lock/release, abort restoration, snapshot |

**Must remain adapter-owned in the reference project:**

- the **input map** and which physical button is the verb;
- the **carrier strings** (`[E]`/`[A]`/`[TAP]`) and the device-family notion;
- **reach**, and whether the ray collides with areas;
- the **result presenter** — the reference project needs *a* consumer of the
  return schema, not Orison's telegram;
- **persistence** — a trivial owner, not `RealityState`.

**INFERENCE:** the adapter list is the honest measure of what is Orison-specific
about interaction. It is short, and none of it is the protocol itself — which is
the strongest evidence for §A's ruling.

---

## G. Formalization decision ladder

**No rung is chosen here.** Godot 4.7 is the target (`project.godot:22`).

> **Language note, deliberately narrow:** **no `interface` keyword is used
> anywhere in this repository** — verified by search. I make **no claim** about
> what GDScript 4.7 does or does not offer at the language level; that must be
> checked against the engine's own documentation before any rung 3 or 4
> decision.

| Rung | What it is | Migration risk | Testability | Composition cost | Godot limits | Evidence to justify moving up |
| --- | --- | --- | --- | --- | --- | --- |
| **1. Documented duck-typed protocol** *(today, once this file lands)* | The rules written down; dispatch unchanged | **None** | Census tests possible now | Free — a node may answer several protocols | `has_method` is a runtime check; typos are silent | — |
| **2. Shared helper / component** | A helper node or static utility props opt into, as `PropControlArea` already is for protocol 3 | **Low** — additive | Helper is testable in isolation | Low; composition preserved | Helper nodes cost a node each | **A second implementor duplicates non-trivial logic.** Protocol 3 already met this bar and produced the adapter |
| **3. Abstract base class** | A common ancestor declaring the verbs | **Medium-high** — GDScript is single-inheritance, and `FunctionalProp`, `TVProp` and others already occupy that slot | Strong | **Costly** — competes with existing hierarchies | Single inheritance is the binding constraint | Every implementor already shares one ancestor **and** the duck-typed dispatch has caused a real, observed bug |
| **4. Registered capability layer** | Explicit registration with a capability query | **High** | Strongest | Registration is a permanent chore | Registry lifetime must survive scene reloads | **A second project consumes the protocol** and needs discovery Orison does not |

**RECOMMENDED TODAY: rung 1.** Write it down; change nothing. **INFERENCE:**
rung 3 is the one to be most wary of — `FunctionalProp` and `TVProp` already own
the inheritance slot, so an abstract interaction base would force a hierarchy
fight for a problem no observed bug has yet demonstrated.

---

## H. Test contract

**Designed, not created. No test was written.**

| ID | Test | Asserts | Kind |
| --- | --- | --- | --- |
| **T1** | Discovery and reach | A prop at 2.0 m prompts; the same prop at 2.2 m does not | FOCUSED |
| **T2** | Carrier neutrality | **No production `interact_prompt` or `control_prompt` return contains `[A]`, `[TAP]`, a glyph, or a key name.** Legacy `[E]` tolerated only where already present | STATIC — cheapest, highest value |
| **T3** | Input-family switching | The same prop yields `[E]`, `[A]` and `[TAP]` as the family changes, **with identical action text** | FOCUSED |
| **T4** | Single invocation and walk agreement | One press → exactly one `interact`; **and the node answering `interact_prompt` is the node answering `interact`** (covers D6) | FOCUSED |
| **T5** | Modal lock and release | Every modal owner leaves `call_locked` as it found it, including when aborted | FOCUSED |
| **T6** | Abort restoration | A cancelled activity restores the mechanism snapshot and **does not retract an already-published work order** | FOCUSED |
| **T7** | Semantic accept/refuse | A refusal produces a perceptible cue or card; success does not present a card claiming a change that did not occur | LIVE |
| **T8** | Persistence ownership | **No file under `game/scripts/props/` writes the save payload directly** | STATIC |
| **T9** | Duplicate safety | Two presses in one frame produce one effect | FOCUSED |
| **T10** | **Census completeness** | Enumerates every production implementor and **fails when one is unclassified** against a checked-in manifest | STATIC |

**T10 is the one that keeps this document true.** Without it, this file is
accurate on 2026-08-27 and decays from the next prop onward. **T2, T8 and T10
need no Godot** — they are source scans.

---

## I. Ten follow-ups, in dependency order

| # | Task | Kind | When |
| --- | --- | --- | --- |
| 1 | Land this contract as the reference | Documentation | Now |
| 2 | **T2 carrier scan** — a source-only check | Test infrastructure | Now, **no Godot** |
| 3 | **T10 census manifest + drift test** | Test infrastructure | Now, **no Godot** |
| 4 | **T8 persistence-ownership scan** | Test infrastructure | Now, **no Godot** |
| 5 | Document `world_modified`'s true meaning (D4) and the return schema (D7) | Documentation | Now |
| 6 | Fix D2 — move the two elevator prompts onto their areas | Production repair | After K2 |
| 7 | T4, T5, T9 | Test infrastructure | After K2 |
| 8 | Document the `call_locked` ownership rule (D3) | Documentation | After K2 |
| 9 | Reference-project conformance (§F) | Post-EA extraction | Post-Early-Access |
| 10 | Re-run the §C.1 counts and this register against the then-current tip | Documentation | Before citing this file again |

**Seven need no Godot. Five are documentation. None is a production repair
before the first human run** — because the only candidate was already fixed.

### First task safe for Codex now

**Follow-up 2 — the T2 carrier scan.** A source-only check that no production
`interact_prompt` or `control_prompt` return contains `[A]`, `[TAP]`, a glyph or
a key name. It touches no production file, needs no Godot, cannot affect K2, and
it is the standing guard for the exact class of bug `3fa6fb4` just fixed by
hand.

**Second: follow-up 3, the census manifest and drift test.** It is what stops
this document going stale, and §C.1's commands are already the implementation.

**Deliberately not recommended: any production change.** After `3fa6fb4` there
is no P0 or P1 in this register, so **nothing here justifies touching production
code before K2.**

### Stop rules

- **No sweeping interaction rewrite.** Not before K2 identifies a user-facing
  failure — except a narrowly proved accessibility or duplicate-invocation bug.
  **No such bug remains open in this register.**
- **Do not replace `has_method` because it looks inelegant.** It works, it is
  centralised, and no observed bug is attributable to it.
- **Do not introduce a base class or registry** on the strength of this document.
  §G rung 1 is the recommendation.
- **Do not change `world_modified`'s emission before K2.** Listeners exist;
  document the meaning first.
- **Early Access remains the controlling milestone.** Follow-up 10 is post-EA.

### Owner decisions

| # | Decision |
| --- | --- |
| **O1** | Whether any production interaction change is permitted before K2 at all. **This register no longer asks for one**, so the honest default is no |
| **O2** | Whether the census manifest (T10) is worth its permanent upkeep |

---

## J. Sources

Traced at `1f1bc80`: `game/scripts/player/player_controller.gd:295–375`,
`use_primary_interaction`, `_try_interact`, `_present_interaction_telegram` ·
`game/scripts/props/prop_control_area.gd` (complete file) ·
`game/scripts/props/functional_prop.gd:56–100` ·
`game/scripts/props/watchman_clock_prop.gd:416–445` ·
`game/scripts/ui/telegram_hud.gd:76–84` ·
`game/scripts/ui/maintenance_activity_panel.gd:197` ·
`game/scripts/call/call_interface.gd:294,309` ·
`game/scripts/audio/music_director.gd:353` ·
`game/scripts/audio/virus_sound_director.gd:104–127` ·
`game/project.godot:22` · the five counting commands in §C.1 ·
`game/tests/` interaction-related scenes.

---

## K. Limitations

- **Reachability was established from source, not from a running game.** I did
  not verify that every `ControlArea` is positioned where a ray can hit it, or
  that its shape is non-degenerate. **§A's falsifier row 3 is the specific thing
  I could not discharge**: proving that prompt and action always resolve to the
  same node requires either a scene-graph walk or T4.
- **`.tscn` scenes were not audited.** A scene-authored node could answer a verb
  without appearing in any script grep.
- **Family groupings in §C.3 are approximate**; the appendix is authoritative.
- **I make no claim about GDScript 4.7 language features** (§G note).
- **Three of my own first-pass findings were wrong** and were corrected by
  tracing before reporting: two false "prompt without action" hits, and a
  "PropControlArea missing" result caused by grepping a literal class name when
  call sites use an alias. **The raw counts mislead; that is recorded as the
  audit's main methodological result.**
- **No P0 was found. That is a finding, not an absence of effort** — and it
  means this document does not block the first human run.

---

## M. Reconciliation with Codex's convention record

`design/INTERACTION_CONVENTION_RECORD_2026-08-27.md` (`c9846f1`) covers the same
ground independently. **Where we differ, here is the arithmetic and the
reasoning, so a reader does not have to guess which to trust.**

### M.1 Counts — a real discrepancy, resolved

| Definition | Codex | This document | At `c9846f1`, by `grep -rlF … \| wc -l` |
| --- | ---: | ---: | ---: |
| `interact_prompt` | 65 | **66** | **66** |
| `interact` | 71 | **72** | **72** |
| `interact_area` | 6 | 6 | 6 |
| `control_prompt` | 18 | 18 | 18 |
| `interact_control` | 18 | 18 | 18 |

**We agree on three of five.** The two that differ are off by exactly one, and
**INFERENCE:** the likely cause is that Codex excluded `props/prop_control_area.gd`
— the adapter — as infrastructure rather than an interactable. That is a
reasonable classification and it makes the raw count one low as stated. §C.1's
figures are the literal command output; §C.2's note explains why the adapter is
in the list.

### M.2 The rulings are compatible, and answer different questions

Codex rules: *"a shared spelling is a convention, not an interface"* — the
player **verifies nothing**, and `has_method` proves only that a name exists.
**That is correct and this document does not dispute a word of it.**

This document rules **"a stable implicit protocol"** on a different axis: not
whether the engine enforces the contract (it does not), but whether the
implementors **actually obey one** (they do — 18/18 protocol-3 consistency, zero
prompt-without-action once `extends` resolves, one guard in the shared base
class).

**Both are true.** *Nothing is enforced, and almost nothing deviates.* Where the
two would genuinely conflict is a decision to build an interface: Codex's ruling
supplies the reason one might be wanted, mine supplies the reason it is not yet
urgent. **Both land on the same recommendation — §G rung 1, change nothing —
and both cite the extraction boundary's phase-1 stop rule.**

### M.3 One ambiguity this document closes

Codex records that `projector_prop.gd` *"advertises a prompt without either
player action name in that file"* and that such cases *"may be intentional
compositions or defects; method discovery cannot distinguish them."*

**Following the `extends` chain distinguishes them.** `projector_prop.gd`
extends `TVProp` and inherits its `interact`; `wayfinding_signage_pass.gd`
implements `interact_area`. **Resolved through inheritance, the
prompt-without-action set is empty** (§C.4) — which is the single strongest piece
of evidence behind §A's ruling, and it is not visible to a same-file census.

---

## L. Appendix — every production implementor path

All 66 `interact_prompt` definers, unabridged, exactly as produced by
`grep -rlF 'func interact_prompt(' game/scripts --include=*.gd | sort`.
**Debug-only and non-player-driven entries are marked.**

```
building/light_debug_handle.gd                  [env-gated light inspection]
building/maintenance_headquarters.gd
building/room0.gd
building/switch_plate.gd
building/wayfinding_signage_pass.gd             [protocol 2]
call/desk_zone.gd
cases/case_interactable.gd                      [DEBUG-ONLY, partly]
characters/animated_resident.gd
characters/npc_placeholder.gd                   [DEBUG-ONLY]
game/maintenance_shop_counter.gd
props/arcade_cabinet_prop.gd
props/baked_furniture_interaction.gd            [protocol 3 constructor]
props/bar_seat_zone.gd
props/bench_zone.gd
props/bodega_signage_prop.gd
props/boiler_prop.gd                            [protocol 3]
props/bookshelf_prop.gd
props/boxfan_prop.gd
props/building_entry_sign.gd
props/case_door_prop.gd
props/clock_prop.gd
props/darts_prop.gd
props/dead_letters_prop.gd
props/domestic_radio_prop.gd
props/domestic_witness_clock.gd
props/door_anomaly_prop.gd
props/door_check_closer_prop.gd                 [protocol 3]
props/door_prop.gd
props/entrance_marquee_dress.gd
props/exhaust_fan_prop.gd
props/fire_line_cabinet_prop.gd                 [protocol 3]
props/flue_breast_prop.gd
props/fortune_answer_prop.gd
props/fridge_prop.gd
props/harukiya_signage_prop.gd
props/house_switchboard_prop.gd
props/inspectable_zone.gd
props/kettle_prop.gd
props/lamp_prop.gd
props/lobby_bulletin_board.gd
props/lobby_orison_ad_board.gd
props/mail_bank_prop.gd
props/mail_box_zone.gd
props/medicine_cabinet_prop.gd
props/monitor_prop.gd
props/neon_sign_prop.gd
props/night_register_prop.gd                    [protocol 3]
props/otis_prop.gd                              [protocol 3]
props/passage_pushcart.gd
props/point_ball_prop.gd
props/possessed_domestic_prop.gd
props/projector_prop.gd                         [extends TVProp]
props/prop_control_area.gd                      [THE ADAPTER]
props/radiator_prop.gd
props/shop_sign_prop.gd
props/soda_acid_extinguisher_prop.gd            [protocol 3]
props/songbook_terminal_prop.gd
props/stove_prop.gd
props/tap_prop.gd
props/toaster_prop.gd
props/tour_key_guard_prop.gd                    [protocol 3]
props/tv_prop.gd
props/vantry_point_prop.gd
props/watch_register_prop.gd                    [protocol 3]
props/watch_station_prop.gd                     [protocol 3]
reality/organism_incidents.gd
```

**Protocol-3 responders without their own `interact_prompt`** — each builds a
`ControlArea` that carries one:

```
props/dumbwaiter_prop.gd          props/mail_chute_prop.gd
props/elevator_interlock_prop.gd  props/roof_tank_ballcock_prop.gd
props/fuse_panel_prop.gd          props/watchman_clock_prop.gd
props/laundry_airer_prop.gd       props/washer_prop.gd
```

**Not player-controller driven:** `arcade/swc_door.gd`, `arcade/swc_pickup.gd`.
**Controller-owned prompts:** `building/elevator.gd` (§E D2).
