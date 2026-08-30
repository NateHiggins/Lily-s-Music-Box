# Orison genetic memory — what this project learned the hard way

**Status:** reference, not proof. Named so the completeness ledger refuses it as
evidence; space identifiers are **bold**, never backticked, so nothing here
promotes a requirement it merely describes.
**Scope:** 1,099 commits, 2026-07-29 to 2026-08-29 — thirty-two days, ~34
commits a day, built almost entirely by AI agents directed by one owner.
**Sibling:** `design/ENGINE_RELEASE_PIPELINE_LESSONS_2026-08-27.md` holds the
release-pipeline lessons in this same form. This document extends that form to
the rest of the record; it does not replace or fork it.
**Companion:** `design/ORISON_VERIFICATION_MIDDLEWARE_ASSESSMENT_2026-08-29.md`
asks whether any of this is a product.

---

## How to read this

Every entry passed four tests. It was **learned**, not assumed — it cost time,
rework, a reversal or a defect. It is **transferable** — it applies to the next
system, not just to one file. It is **actionable** — you could work differently
tomorrow. It is **evidenced** — a commit, a `file:line`, a finding class or a
document. Roughly sixty candidates failed one of the four and were set aside;
the notable rejections are in Appendix A.

Where the project already had a compressed form, it is used verbatim. The
compression is not decoration: the house grammar is **"X is not Y"** — *a build
is not a release*, *the backlog is not the build*, *the apartment is not the
fault*, *the seal is not the charge*, *a centreline is not a face* — and that
grammar names the **conflation** that caused the defect, which is the part that
generalises. Slogans propagate between agents and sessions where paragraphs do
not. That is why they are here.

**Three lessons are load-bearing above all others.** If you read nothing else:

1. **§1.1 — A write is not a use.** The project's most repeated failure is not
   dead code; it is live artifacts nothing consumes, and reference-counting
   cannot see them.
2. **§2.1 — Prove the red before you believe the green.** Every instrument here
   has been found lying at least once, and each time everything measured
   downstream had to be demoted.
3. **§3.1 — A ruling made without reading the standing corpus is a new conflict,
   not a decision.** Rigour deepens a review; it does not widen its corpus.

---

## Part 1 — The master failure: artifacts with no consumer

This is the project's single most repeated defect. The seed brief called it
"authored data with no reader." That is too narrow. It applies to **data, tools,
documents and save fields alike**, and its cause is structural, not careless.

### 1.0 Why it recurs — and it is not carelessness

The asymmetry is the whole explanation, and it is worth stating before the
specimens:

> **A wrong owner produces a wrong output. A missing consumer produces no
> output.**

A wrong owner is visible, embarrassing and gate-able — the porter arrives at the
wrong flat, the coordinator names 2C when the riser reaches 3B. A missing
consumer produces *nothing*. It reads as *"not built yet"* rather than
*"broken"*, it never fails a test, it never fails a gate, and **it is
indistinguishable from scope.** That is why two floats survived four save
versions with zero readers: there is no failing state for a number nobody asks
for.

The tooling shows the same blind spot. All nine finding classes in
`audit_systemic_situation_authority.py` are **wrong-owner or wrong-clock**
classes. There is no `NO_READER` class in any of the eleven audits. The one
sweep that *did* find the class was a hand-written report run once on
2026-08-10 and never turned into a tool — and 19 days later three of its nine
findings are still open (§1.6).

Measured across 47 data files against 8.96 MB of source: **185 of 1,405
schema-shaped keys — 13.2% — have zero textual reader anywhere in the tree.**
That count is conservative in one direction (any string match counts as a read)
and inflated in another (id-keyed maps), so treat it as an order of magnitude,
not a figure. The hand-verified cases below are exact.

*Evidence:* `design/AUDIT_UNUSED_SYSTEMS_REPORT.md` (7 of 9 findings are
no-consumer; **0** are no-advance); `tools/audit_systemic_situation_authority.py`
class list; scratch measurement over `game/data/`.

### 1.1 A write is not a use

> **A variable that only reads itself is not read.**

`building_stability` and `reality_coherence` ship in `SAVE_VERSION 4` at
`game/scripts/game/reality_game_state.gd:37-38`. A tree-wide grep returns
exactly six lines: two declarations and four writes at
`reality_case_manager.gd:79-80,142-143`. Both writes are self-referential
clamped increments — `x = clampf(float(x) + 0.025, 0.0, 1.0)`. A reference count
says "used"; a reader census says "dead". They have accumulated in every save
file since **2026-07-30** (`dc86c8c`) — a commit about putting neon on the
building.

The same commit added `discovered_documents`. That field appears **exactly once
in the entire repository**: its own declaration at `reality_game_state.gd:40`.
Not in a test, not in a document, not in a comment. Thirty days, 950 commits.

**The rule.** When auditing for unread state, discard any read that appears on
the right-hand side of an assignment to the same name. Apply it to every
counter, score, meter and accumulator first. Never persist a value into a
versioned format until you can name the code that reads it back.

*Evidence:* `reality_game_state.gd:37-40`; `reality_case_manager.gd:79-80,142-143`;
`dc86c8c` (2026-07-30); `design/ORISON_DREAM_TAPESTRY_RULING_2026-08-29.md`
("a tree-wide grep returns zero readers").

### 1.2 A self-consistent artifact passes every test it has

> **Internal validation cannot detect a missing reader.**

`16e4901` added `game/data/resident_schedules.json` — 592 insertions, one file,
zero code. Its commit body lists a real validation suite: full seven-day
coverage per resident, no same-rank overlaps, interlocks hold, night census
correct. Every one of those checks is *internal to the file*. Measured today it
carries **415 `outfit` values, 25 `with` co-presence pairings and 9 `route`
polylines**. `schedule_director.gd:186-251` reads `role`, `days`, `monthly`,
`chance`, `start_min`, `end_min`, `place` and `activity` — nothing else.
`grep -rn outfit --include='*.gd' game/scripts/` returns nothing at all.

The schema even documents the deferral: `outfit` is "reserved for #46 model
swaps, runtime may ignore until then." A sentence inside the data is not a
tracking mechanism.

**The rule.** For any commit that adds authored data, the acceptance criterion
is a **named consumer symbol** — `file:line` of the code that opens it and the
field it reads — not a consistency proof. If wiring is deliberately deferred,
the deferral is a build-visible marker with an owner and an expiry, never a
comment in the payload.

*Evidence:* `16e4901`; `game/data/resident_schedules.json` (415/25/9, counted);
`game/scripts/characters/schedule_director.gd:186-251`.

### 1.3 The orphan is usually redundant with a derivation nobody noticed

This is the sharpest form of the lesson and the one that explains *why* the
orphans have no readers. The 25 authored co-presence pairings were never wired
because a **better** answer already existed: the resident timetables
independently produce roughly **4,120 co-present pair-minutes a week**, derived,
from data production already reads.
`design/ORISON_DREAM_TAPESTRY_RULING_2026-08-29.md` records the consequence
plainly — *"Not one authored pairing key touches any of it."*

So authored-data-with-no-reader and two-authorities-for-one-fact are the same
failure seen from two sides. Someone asserted a fact the system could already
derive; the derivation won by default because it was the one plugged in.

**The rule.** Before authoring a table of facts, ask whether they are derivable
from data that already has a consumer. If they are, author the **query**, not
the table — and if you author the table anyway, you have created a second
authority whose disagreement with the first is a silent bug.

*Evidence:* `design/ORISON_DREAM_TAPESTRY_RULING_2026-08-29.md`;
`game/data/resident_schedules.json`.

### 1.4 Deleting the orphan cures the symptom and keeps the disease

> **Do not keep two editable maps.**

`clock_dials.json` had no consumer because `domestic_witness_clock.gd:41`
hardcodes `DIAL_INDEX` — the same atlas map, in code. The audit called this
correctly: *"Editing the JSON cannot change a clock, so it is a false authority
beside the actual hard-coded map."* The fix that landed (`a80577d`) deleted the
JSON. `DIAL_INDEX` is still there.

`lobby_notices.json` is the same shape and is still live: an eight-cell atlas
index (rent, heat, super, halls, exterm, roof, elev, lost — **and no text in it
at all**), written by `art/tools/build_lobby_notices.py`, while
`lobby_bulletin_board.gd:23-38` hardcodes `COLS := 4`, `ROWS := 2` and the cells.
`mailbank_cards.json` is identical and also uncaught.

**The rule.** When an audit finds unread data, first ask whether a second copy
of the same knowledge is hardcoded in the consumer. If so the fix is to make the
consumer read the generated copy. Deleting the unread file removes your only
evidence that the duplication exists.

*Evidence:* `design/AUDIT_UNUSED_SYSTEMS_REPORT.md` P2; `a80577d`;
`game/scripts/props/domestic_witness_clock.gd:41`;
`game/scripts/props/lobby_bulletin_board.gd:23-38`; `game/data/lobby_notices.json`.

### 1.5 The verification layer is subject to the failure it was built to catch

> **A verifier with no installer and no caller is a document, not a gate.**

The seven **room checkpoint** tools — 6,750 lines of tool, 2,697 of tests, 1,069
across seven guide documents, **10,516 lines total** — were built in a **6h35m
window** on 2026-08-27/28 (`c23c875` 17:30 → `e74f929` 00:05). Every guide
shipped in the same commit as its tool.

Nothing outside the family has ever referenced any of them. No hook is
installed; `core.hooksPath` is unset; there is no CI. `room_gate_hook.py` is
named by exactly three files: itself, its own guide, its own test. Its commit
body says so: *"Nothing installs itself: `--print-hook` plus a manual recipe in
the guide are the whole installation story."*

They also had no input. 37 checkpoint documents exist; only **6**
`.decisions.json` files were ever produced, all inside one five-hour window. Of
the **25** checkpoint documents authored *after* the toolchain landed, **25 have
no verdict table** — a 100% non-adoption rate. And the family knows nothing of
**v2**: it was superseded within about a day by
`audit_orison_v2_completeness.py` (`b8bf0fe`, 2026-08-28) and has not been
touched in the 57 commits since.

This is not an argument against those tools' internals — they compose properly
(`room_layout_workbench.is_room_door` is called by three siblings; that is a
stack, not a pile). It is an argument about delivery.

**The rule.** A tool is not delivered until (a) one command installs it, (b) one
command proves it fires on deliberately-bad input, and (c) the document format
it consumes has been hand-authored for two consecutive real milestones *without
the tool existing*. If the third instance does not appear unprompted, the format
has no author and the tool will have no input.

*Evidence:* `c23c875`, `10cd164`, `a6ccdd5`, `8a3d2e9`, `ee73c47`, `9551c5a`,
`e74f929`; `design/ROOM_GATE_HOOK_GUIDE.md`; counts measured at HEAD.

### 1.6 An audit finding blocked on a decision is a queue with no drain

> **Orphans that need a ruling outlive orphans that need a deletion.**

`design/AUDIT_UNUSED_SYSTEMS_REPORT.md` (2026-08-10) filed nine dead-data
findings with a recommended repair order. Nineteen days later, the ones with a
**mechanical** fix are done — `clock_dials.json` deleted, `corridor_light_prop.gd`
removed, the monitor / `signal_terminal_prop.gd` split carried out,
`resident_decor_profiles.json` moved to `design/` exactly as recommended. The
ones needing an **owner ruling** are all still live: `creature_index.json` plus
**6.0 MB** of creature assets with zero consumers, and `B1_ROOM0_DOOR`, still
authored at `art/data/gen_layout.py:2839` with no runtime reader.

The audit itself flagged why: *"This is a fiction choice, so do not silently
choose deletion."* Correct — and with no drain, correct became permanent.

The project learned this and encoded it. The later audits carry explicit
disposition enums with `DELEGATE_TO_OWNER`
(`audit_systemic_situation_authority.py:113`) and `OWNER_DECISION`
(`audit_orison_spatial_dependencies.py`). Findings are typed by *who can close
them*.

**The rule.** Split audit output into two lists with different machinery:
*remove now* (mergeable immediately) and *needs a ruling* (named owner, dated).
Anything in the second list that passes its date without a ruling gets a default
action written into the finding **at authoring time** — usually
quarantine-in-place with a machine-readable label — so indecision has a
terminating branch.

*Evidence:* `design/AUDIT_UNUSED_SYSTEMS_REPORT.md`; `game/data/creature_index.json`
(zero consumers at HEAD); `art/data/gen_layout.py:2839`;
`tools/audit_systemic_situation_authority.py:113`.

### 1.7 Catch the class, not the instance

> **No finding is closed by a fix to the instance. It is closed by a
> build-failing invariant whose allow-list is empty and named.**

The evidence is the contrast. Where the project shipped an **existence gate**,
the class stopped recurring: `art/data/gen_layout.py:10366-10379` now refuses the
whole build when a spawned marker enters the acoustic graph without a carrier —
*"every spawned marker that enters this graph must have a carrier, with no
anonymous allow-list"* — and that class has not returned. Where the project
patched the **instance**, the class recurred: `clock_dials` was fixed while
`lobby_notices` and `mailbank_cards`, structurally identical, went uncaught;
`resident_decor_profiles.json` was relocated while `creature_index.json` and
`move_repertoire.json` stayed orphaned.

**The rule for this repository specifically.** The invariant is one line: *every
file in the runtime data directory must be opened by at least one production
source file, and every exception is listed by name.* It does not exist yet. It
is the highest-value gate this project could add, and Part 7 says why.

*Evidence:* `art/data/gen_layout.py:10366-10379`;
`design/AUDIT_UNUSED_SYSTEMS_REPORT.md` (which recommended precisely this shape);
`design/ORISON_DREAM_TAPESTRY_RULING_2026-08-29.md` ("add a generic rule to the
authority audit so the class is caught rather than the instance").

### 1.8 Location is a claim the filesystem cannot keep

> **Shipping it under `game/data` implies a reader.**

`move_repertoire.json` carries a `_comment` describing its own consumer:
*"ResidentMovesLibrary.apply() merges all of a family's sources…"*.
`resident_moves_library.gd:14-19` hardcodes three library paths and never
references the file. The comment is a **false wiring claim**, which costs more
than no documentation, because it survives grep and reads as evidence.

The sharper specimen is `apartment_life_profiles.json`, whose own `comment`
field reads: *"Dressing kits, room conversions, routines and audits all read
THIS — never another chain of if-unit-equals."* Measured: `daily_loops`,
`surface_sets`, `entry_set`, `bath_set`, `sleep_schedule`, `cleanliness` and
`hero_object` each have **zero** GDScript readers. Only `unit`, `resident_ids`
and `rooms` are consumed. **The file asserts its own consumption, in prose,
inside the data, and the assertion is false in seven of ten fields.**

**The rule.** Treat the runtime data directory as an assertion that every file
in it has a production reader, and enforce it. Inert briefs go in `design/`.
Never let a data file describe its own consumer in a comment — an artifact that
asserts its own consumption is the cheapest thing in the world to produce, and
it survives grep.

*Evidence:* `game/data/move_repertoire.json`;
`game/scripts/characters/resident_moves_library.gd:14-19`; `0e31059`;
`game/data/apartment_life_profiles.json` (`comment` field vs. measured readers).

### 1.9 Deadness is per-field, not per-system

`building_personality_director.gd:63-82` accumulates six durable quantities in
one `_process`, one owner, one commit. `bond` (4 references) and `resentment`
(8) are alive and read repeatedly. `favorite_floor` is read twice.
`flashlight_seconds` once. **`careful_seconds` and `flight_seconds` have two
references each — the declaration and the write. Zero reads.**

Half the outputs of one tick land and half do not. Any audit that asks *"is this
system used?"* answers yes and moves on.

**The rule.** Census at **field** granularity, never at file or class
granularity. "Is this system wired up?" is the wrong question; "which of its
outputs has a reader?" is the right one.

*Evidence:* `game/scripts/reality/building_personality_director.gd:19-20,63-82,111,138`;
`game/scripts/reality/sanity_director.gd:458`.

### 1.10 Ownership is enforced by the API surface, not by review

The one place this project genuinely fixed the class, it did not write a
convention — it made the wrong call **impossible**. Before `66355da`,
`open_shift_radiator_ecosystem.gd` ran a `_last_bucket` tick every frame that
wrote `record_fact("npc_knowledge", {"2c_neighbor": "heard_hammer", "porter":
"found_unresolved_fault"})` and emitted `porter_dispatched`. **A clock decided
what three people knew and dispatched a man who did not exist.** It had also
been wrong on the merits for months: the acoustic graph says the riser reaches
**3B**, not the asserted 2C.

The fix is four lines at `open_shift_situation.gd:69-72`:

```gdscript
func record_fact(fact: String, value: Variant) -> bool:
    if fact not in ["abandonment_boundary",
            "recoverable_next_state", "elapsed_simulation_minutes"]:
        return false
```

Beliefs now belong to `NpcObservationLedger`, custody to
`MaintenanceInventory`, and the coordinator is **structurally incapable** of
writing either. Not a rule an agent must remember — a return value.

**The rule.** When you find a component writing facts it does not own, do not
document the boundary and do not add a review check. Give the owner a whitelist
and make the foreign write **return false**. A convention every author happens
to honour is not an interface (§6 of the middleware assessment); an API that
refuses is.

*Evidence:* `66355da`; `game/scripts/game/open_shift_situation.gd:66-76`;
`git show 66355da -- game/scripts/game/open_shift_radiator_ecosystem.gd`.

### 1.11 Missing population is not missing simulation

The fourth failure class, and the only one that looks like success from every
direction:

`heat_balance.gd` has an owner, an `advance()`, a consumer, and passing tests.
It is also **provably inert on v2**: with one radiator, the zero-sum solver's
share term cancels at `heat_balance.gd:97-103`, so vent grade and the
partial-supply penalty *"have provably zero effect on delivered heat, which is
the entire reason the file exists."* Composing it over v2's single radiator
*"would run without error and mean nothing."*

Nothing detects this. It is not dead code, not an orphan field, not a wrong
owner, and not a missing tick. It is a correct system with **n = 1**.

**The rule.** For any system whose output is a *share*, a *ranking*, a
*competition* or a *balance*, state the minimum population at which its
behaviour becomes observable, and assert it. Below that population the system is
not "working with less data" — it is algebraically inert, and it will pass every
test you own.

*Evidence:* `design/ORISON_V2_COMPOSITION_CENSUS_2026-08-28.md` finding F4;
`game/scripts/props/heat_balance.gd:97-103`.

---

## Part 2 — Unearned green: the instrument and the gate

### 2.1 Prove the red before you believe the green

> **Test the transport, not just the test. An unavailable result must refuse,
> never pass.**

`tools/run_godot_serial.ps1` reported **exit 0 for every failing suite** because
Windows PowerShell 5.1 never populates `.ExitCode` on a `Start-Process -PassThru`
process unless `.Handle` is read before the wait — so `exit $null` reported
success. It ran that way from `d8ac27c` (2026-08-24) to `b813b1a` (2026-08-28):
**334 commits**. It was proved by pushing a known-failing suite through it
(`DreamBoundaryTest` FAIL 1 → runner 0; direct Godot → 1). The fix is not a
default, it is a refusal: `throw "Godot's exit code was unavailable; refusing to
report success."`

The consequence was recorded honestly rather than quietly:
`design/ORISON_V2_SEPT3_REBUILD_HANDOFF_2026-08-28.md` §7 — *"Historical exit
codes are worthless."* An entire prior evidence base was demoted rather than
trusted.

**The rule.** Before you trust any runner, wrapper, CI step or reporting pipe,
push a deliberately failing job through it end to end and confirm nonzero **at
the reader** — the shell that branches on it — not at the producer. Never read
`$?` after a pipe. Never let a process object's exit code reach an `exit`
statement unchecked.

*Evidence:* `tools/run_godot_serial.ps1:75-89`; `d070076`; `b813b1a`;
`git rev-list --count d8ac27c..b813b1a` = 334.

### 2.2 Your apparatus is older than the thing it certifies — date it

Between the runner's introduction and its repair, **29 non-test tools were
added**, including `audit_orison_v2_completeness.py`,
`audit_systemic_situation_authority.py`, `room_reconstruction_gate.py` and
`run_godot_capture.ps1`. The tool count in `tools/` went from 16 to 45 in that
window. Every gate authored while the runner lied inherited an unverified
transport.

**The rule.** When you fix an instrument, immediately list what was certified
while it was broken (`git diff --diff-filter=A <intro>..<fix>`), and re-run every
gate authored in that window against a known-bad input. Make *"when was this gate
last proven able to fail?"* a required field on every gate you own.

*Evidence:* `git diff --name-status --diff-filter=A d8ac27c b813b1a -- tools/`
(29 files); `git ls-tree` counts 16 → 45.

### 2.3 The instrument is the first suspect

The project keeps its own tally, in commit bodies. `33c9221` — *"it is the fourth
time this session that the INSTRUMENT was the broken thing rather than the
subject"*. `1faeb26` — *"the fifth time this project has found the instrument
broken rather than the subject"*. `40cbe01` — *"the instrument was the broken
thing for the sixth time"*. The session memory records it as **"GENERAL RULE, the
third instance."** No other lesson in this corpus is counted out loud like this.

The specimens are worth knowing by shape:

- **A shader that fails to compile does not disappear** — it falls back to a
  plain lit material, which looks exactly like a lighting problem. *"The render
  harness reported '4 frames saved' throughout. It was telling the truth about
  the files and lying about the subject."* (`33c9221`)
- **A perf probe reported zeroes headless, and zeroes read as a pass.** Every
  performance table recorded before 2026-08-22 came from a broken probe and is
  *"indicative, not exact"* (`design/DT4_PERFORMANCE_REAUDIT.md` §0, "THE PROBE
  WAS LYING").
- **A verification render with culling disabled.** `screenshot_run.gd:289` set
  `show_all_floors = true`, so every streaming-pass verification render had the
  thing under test switched off. *"A verification method that cannot fail is not
  a verification method."* (`7e0866c`)
- **`cmd | head; echo $?` reports head's status** — which nearly produced a filed
  defect against the completeness ledger that did not exist.

**The rule.** Give every measurement harness a pre-flight liveness check whose
passing is impossible for a dead instrument to fake, and run it before any
reading is trusted. The codified form ships at
`game/tests/dream_environment_shot.gd:91`: `_audit_shader_compiled()` walks every
`GeometryInstance3D` and calls `get_shader_uniform_list()`, which comes back
empty on a failed shader — *a fact a render cannot hide* — before the frames are
judged. It now appears in five harnesses.

*Evidence:* `33c9221`, `1faeb26`, `40cbe01`, `7e0866c`, `3e21e3d`, `ebcdfcc`;
`design/DT4_PERFORMANCE_REAUDIT.md`.

### 2.4 A guard derived from the implementation cannot fail

> **A boolean cannot see 64 mm.**

`walk_test` asserted `tap._handle_wall_mounted == [true, true]` — a boolean —
against a defect that is a **distance**. `3b04597` corrected the flag and left
the coordinate; the test stayed green. The replacement measures the seat gap on
all 43 wall-valve fixtures and *"requires the two families to agree with each
other, naming no number of its own"*, verified in both directions: spread
0.0640 m before, 0.0000 m after.

Same family, same week. A flake fix bounded the pursuer's drift by
`elapsed_s * top_speed`, which is exactly its own displacement bound, so the
check could not fail. A coverage check counted loop iterations rather than
distinct observed positions. A blinds validator measured only the axis its own
author had just repaired, and so missed the cross-axis fault introduced in the
same change.

**The rule.** For every guard, ask two questions before trusting a pass. *If I
delete the fix, does this fail?* — verify in both directions, not just forward.
*Where does my expected value come from?* — if it is the same constant, table or
module the code reads, the guard is decoration. Re-derive it from the opposite
side of the interface, or require two independent implementations to agree.
Assert in the defect's own units.

*Evidence:* `942ef43`, `8226945`, `e66f48c`, `bbdcddc`, `4c6c039`.

### 2.5 A generator that partially fails still prints its success census

`orison_v2_blockout.gd` had two silent failure modes. A leaf whose `connects`
named a missing space **built as a frame against the solid wall it should have
pierced**. A stair whose `from` named a missing level threw inside
`_build_u_stair` — which aborts only that one call — *"so the build continued,
printed its success census, joined the selector group and exited 0 with the
stair simply absent."*

`568a6c2` fixed it with refusals only: full referential integrity across
door/opening `connects`, window space, lift landing shaft, stair `from`/`to`,
route-edge `from`/`to`/`via` and service endpoints; validation runs before any
`_build_*`; on failure it prints the count and builds nothing. 27 guard checks,
each asserting exactly **one** failure that names the record, the field and the
target. The same shape had appeared earlier in the Blender export path (*"half
old / half new geometry with exit 0"*), fixed with a greppable `BUILD FAILED:`
sentinel plus `sys.exit(1)`.

**The rule.** In any loop that builds many things, resolve and validate every
cross-reference **before constructing anything**, and make the failure path
refuse the whole build. Make the success message assert `built == requested`.
Per-item error isolation turns a broken build into a successful one.

*Evidence:* `game/scripts/building/orison_v2_blockout.gd:18-29,99-105,153-162`;
`568a6c2`; `90222e2`.

### 2.6 Vacuity is the resting state of every scoped gate

> **A pass with no scope attached is a lie with good manners.**

`design/ROOM_RECONSTRUCTION_GATE_GUIDE.md:115` — *"An empty `--changed-since`
selection gates nothing and reports LANDABLE vacuously."*
`tools/measure_shot_sheet.py:131-142` had to add
`"floor_ratio_note": "undefined_zero_floor"` because a control floor of exactly
zero makes a ratio gate `value < 0 × 3` that can never be true.
`art/renders/first_minute_k2f/README.md:223` states the same trap by hand,
*"because the tool cannot state it."*

**The rule.** Make every gate default-red and require the caller to name a scope
to obtain green. Emit the scope and the **denominator** inside the success string
itself — *"0 blockers across 47 selected rooms"*, never bare `PASS` — so the
message cannot be quoted out of context. For any relative threshold, assert the
denominator is nonzero.

*Evidence:* `design/ROOM_RECONSTRUCTION_GATE_GUIDE.md:115`;
`tools/measure_shot_sheet.py:131-142`;
`tools/audit_orison_v2_completeness.py:126,170`
(`FIRST SLICE READY - PRODUCTION CUTOVER NOT IMPLIED.`).

### 2.7 Assert the gap; never skip the check

> **A known gap is an assertion that the gap still exists.**

The pattern that ships here is `game/tests/dream_boundary_test.gd:266-275` — a
loud `EXPECTED GAP TODO(v2-sleep-gates)` that still asserts `selected == "v2"`
and states that *"the gate checks are deferred, not passed"*, so it fails both
when the gap closes and when it is run in a configuration where the excuse does
not apply. `d070076` states the discipline: *"absence stays loud, never skipped;
the moment either owner exists the full gate checks become required again."*

The anti-pattern still ships too: `sleep_pressure_director.gd:151-162`
short-circuits its block check when the gate owner is null. Permission-on-absence
in a safety path.

**The rule.** Never express a known gap as a skipped or conditionally-absent
test. Express it as an assertion that the gap is still present, conditioned on
the exact flag that excuses it.

*Evidence:* `game/tests/dream_boundary_test.gd:266-275`; `d070076`;
`game/scripts/dream/sleep_pressure_director.gd:151-162`.

### 2.8 One signal must never stand for two facts

The serial runner's exit `73` meant *lane busy*, *timeout kill* **and** *no Godot
binary* — three conditions demanding three different responses, one of which
(retry) is actively wrong for the other two. Split on branch
`claude/runner-exit-truth`: **73 = lane busy** (wait and retry), **124 = timeout
kill** (raise the ceiling or find the hang; retrying is pointless), **78 = cannot
run**. The ceiling came from measurement, not taste: all fourteen committed
suites were timed, slowest **80.5 s**, so the old round-number 60 s cap had been
killing two suites structurally. Both paths were then proved deliberately.

`tools/audit_interaction_prompt_carriers.py:539-546` shows the general form —
`code |= 1` / `code |= 4`, so co-occurring conditions compose instead of
colliding.

**The rule.** For every distinct nonzero code, write the one sentence describing
what the reader should do about it. If two failure modes produce the same
sentence but demand different actions, the code is overloaded. Use bitwise
composition when conditions can co-occur. Set timeouts from a measured
distribution of real run times, never a round number.

*Evidence:* `f04be59` (branch `claude/runner-exit-truth`, not yet merged);
`tools/audit_interaction_prompt_carriers.py:539-546,67-73`.

### 2.9 Three signals survive; one signal gets swallowed

> **Count the artifacts, not the exit code.**

`tools/run_godot_capture.ps1:131` is the shape worth copying:
`$pass = $engineExit -eq 0 -and $pngs.Count -eq $ExpectedFrames -and $zeroByte -eq 0`
— a conjunction of exit code, artifact count against a number declared *before*
the run, and a non-degeneracy check. `game/tests/shot_harness.gd` refuses to
overwrite a non-empty directory, fails on an empty viewport image, and fails on
`frame count != expected`. `game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`: *"never
retry in a loop, and never point a new run at a non-empty directory"* — both let
a green come from a previous run.

The counter-example is in the same directory:
`game/tests/dream_ecology_e3a_shot.gd:69` prints `PASS` then calls
`get_tree().quit(0)` unconditionally, verifying nothing. **Five of 360 test files
share that shape.**

*Evidence:* `tools/run_godot_capture.ps1:131`; `game/tests/shot_harness.gd`;
`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`; `game/tests/dream_ecology_e3a_shot.gd:69`.

---

## Part 3 — Evidence and authority

### 3.1 A ruling made without reading the standing corpus is a new conflict

> **The refusal was void when it was written.**

On 2026-08-29 at 18:55, `a53f0a4` landed a 364-line ruling produced by an
adversarial review with **five independent readers** (authority, physical scale,
redundancy, omission, steelman), run — in its own words — *"against measured
geometry, shipped code and the binding rulings."* Among six rejections it
rejected *"every datum after 1928-12-31."*

The **very next commit**, `1209df3`, 69 minutes later, struck that line. Three
separate owner-ruled licences for post-1928 presence already existed in
`design/ORISON_BIBLE.md`, one of them ruled **2026-08-09 at the owner's own
direction** (§VIII.5.g: a 1919 machine receiving a 1987 programme *"is not a
contradiction… it is Tuesday"*).

It gets worse, and this is the part that matters. `1209df3` also corrected
`a53f0a4`'s **arithmetic**: the ruling claimed re-datuming would unlock 191 light
fixtures; the generator that produced them is
`rng.randint(1928, 1989)` (`tools/author_light_provenance.py:126`), so re-datuming
makes **187 of 191 more forbidden, not less**.

Five independent reviewers, five assigned adversarial stances, and both errors
would have been caught by a single grep of one binding document and a single
read of one generator. The review's corpus had covered geometry, code and
rulings — and not the bible, and not the generator producing the data being
ruled on. **Process rigour deepens a review; it does not widen its corpus.**

**The rule.** Before landing any prohibition, grep the tree for instances of the
thing you are about to forbid and open the document that authorised them. If
sanctioned instances exist, ship a **licence** — declared exception, named
authority, machine-verified reference to a real ruling — with a small absolute
core, not a blanket ban. The remedy `1209df3` adopted is the general form:
*"`licensed_by` is an enum of existing ruling ids, verified against a real
document heading. Otherwise the field is a rubber stamp and forging a licence is
cheaper than obeying one."*

*Evidence:* `a53f0a4` (2026-08-29 18:55:39); `1209df3` (20:05:15);
`design/ORISON_BIBLE.md` §VIII.5.g; `tools/author_light_provenance.py:126`.

### 3.2 Prose about the building is not the building

> **A work order is not a receipt.**

The completeness ledger's evidence intake was `design/ORISON_V2_*.md` minus an
ad-hoc `if "COMPLETENESS" in doc.name: continue`. Any file matching the family
glob that **backticked a space id** promoted that space. So a report, a census,
a handoff or an audit satisfied the requirements it merely *described*.

The specimen is perfect. `c20bc2d` — *"Stop the handoff pack from promoting the
gap it describes."* The Sept-3 handoff backticked **F02_SERVICE_HALL** *in the
sentence asking the spatial owner to give it door records*. That work order was
the only evidence marking the route spatially proven, so
**circ.F02.service_route** blocked nothing. **The bug report satisfied the
requirement it reported.**

`d344fd9` made intake a positive allowlist decided **from the filename before
the file is opened** — `CHECKPOINT`, `GRAYBOX`, `ACCEPTANCE`, `RECEIPT`,
`VERTICAL_CORE`, `SCHEMA_GENERATOR` — *"so a refused document is never read and
cannot influence a conclusion by accident."* Refusals are printed with reasons
and kept out of the provenance hash, because they are not inputs. It also
shipped `--evidence-impact PATH`, which diffs the ledger with and without a
candidate document and names every requirement whose status would move: exit 0
inert, 1 promoting. Two already-shipped documents turned out to be contaminating,
and the ledger got stricter by exactly their contribution — SPATIALLY_PROVEN
21→18, STRUCTURAL 78→80.

The authoring convention changed permanently. Every ruling since opens *"Work
order, not proof — named so the completeness ledger refuses it. Identifiers are
**bold**, never backticked."* This document does the same.

**The rule.** Never let a text-mining evidence tool read a directory by glob.
Make intake an explicit allowlist of document classes that are themselves proof,
decide membership from the filename, list every refusal with a reason, and ship a
`--impact <path>` mode. If a new report can move a ledger, the ledger is
measuring the report, not the system.

*Evidence:* `c20bc2d`; `d344fd9`; `tools/audit_orison_v2_completeness.py:388-411`;
`design/ORISON_V2_COMPLETENESS_LEDGER_GUIDE.md`.

### 3.3 Narrowing intake trades false positives for false negatives

The correction to the correction, 16 minutes later. `3aa3764` — *"the evidence
allowlist cuts both ways: reports are now inert, but a checkpoint without a
marker in its filename proves nothing either."* The live example:
**f01.watch_station** is **built and owner-accepted**, and still blocks
STRUCTURAL, because the spatial-owners checkpoint never names **F01_WATCH**.

There is no evidence rule without an error mode. You choose which error you
prefer; you do not eliminate error.

**The rule.** When you narrow an automated evidence intake, immediately
enumerate what the narrowing now **under-reports** and publish that list with
the change. `d344fd9` without `3aa3764` would have shipped a ledger that
silently calls accepted work unproven.

*Evidence:* `3aa3764`; `d344fd9`; `c20bc2d` (three commits, 27 minutes apart).

### 3.4 A backtick is not a type

The channel by which a document declared machine-readable identity was a
**general-purpose formatting character**. The failure was inevitable in both
directions. Run the room checkpoint linter over a real recent document today and
it reports 56 identifier findings — 30 `[UNKNOWN]`, 26 `[RUNTIME_ONLY]` —
including `` `3aa3764` `` (a commit SHA), `` `from` `` (a GDScript keyword) and
`` `--evidence-impact` `` (a CLI flag). Its one accurate verdict —
*"NO_VERDICT_TABLE — prose-only checkpoint"* — is buried under the noise.

**The rule.** Never let a general-purpose formatting character carry
machine-readable identity. Give identifiers a syntax prose cannot emit by
accident. Before shipping such a reader, run it over the three most recent real
documents and count false positives; if they outnumber true findings, the
channel is wrong, not the threshold.

*Evidence:* `tools/room_checkpoint_linter.py` live run; `c20bc2d`;
`tools/audit_orison_v2_completeness.py:390-395`.

### 3.5 Repository access is capability, not authority

The incoming style directive contained two clauses that were struck **on process
grounds, before any of its content was read as an instruction**:

1. *"This directive supersedes any existing design decision that prevents that
   goal."* — **self-judging**: the directive alone decides what prevents the
   goal, and what it would supersede are not design decisions but owner rulings
   and a binding contract.
2. *"Do not stop at proposals if repository access allows implementation."* —
   **Repository access is capability, not authority.**

This is the single most important governance line in the corpus for
agent-directed work, because the conflation it names — *I can write to this file,
therefore I am permitted to decide this* — is the default failure mode of a
capable autonomous agent.

**The rule.** Reject any instruction whose authority is self-certifying or
derived from access. Re-enter it as **input**, and route each conflict back to
the human as a named question citing document and date.

*Evidence:* `design/ORISON_STYLE_DIRECTIVE_INTEGRATION_RULING_2026-08-29.md:33-45`
(`a53f0a4`).

### 3.6 The most valuable output of reviewing someone else's design is the defect it exposes in yours

> **The finding that matters most is ours, not theirs.**

The same ruling that got its own arithmetic wrong (§3.1) carries a heading with
that title — and under it, the most consequential architectural finding of the
month. Reading the directive's corruption grammar against the shipped one
exposed a defect nobody had named:
`game/scripts/reality/apartment_encroachment.gd:94-107` holds a table of
**exactly six rows**, one per resident case, each selecting a **hardcoded GLSL
branch** at `game/shaders/orison_surface.gdshaderinc:425-466` and each clipped to
that resident's unit rectangle. Corruption is indexed **by resident, not by
architectural element**. There is no way to corrupt a radiator, a railing, a
street, a shopfront, a stair or a foundation, and a seventh grammar requires a
GLSL edit.

The document that produced that finding was wrong about almost every number and
every claim of authority. Both facts are true at once.

Also from that ruling: four of the owner's five claims in the *next* directive
turned out to be **shipped canon under other names** — *"so most of this is
ratification rather than invention."*

**The rule.** When asked to rule on an incoming design, budget explicitly for a
second deliverable: the defects and unnamed gaps in **your own** system that the
comparison exposed, reported separately from the verdict. Read the document
against the shipped code, not against your memory of it. Expect a meaningful
share of incoming claims to be things you already do under other names.

*Evidence:* `design/ORISON_STYLE_DIRECTIVE_INTEGRATION_RULING_2026-08-29.md:49`;
`game/scripts/reality/apartment_encroachment.gd:94-107`;
`game/shaders/orison_surface.gdshaderinc:425-466`; `1209df3`.

### 3.7 Audits find wrong things; they do not find missing kinds of things

> **No gate can fail a space that has no authored way to be wrong.**

The corollary of §3.6, and the most uncomfortable line in this document. Eleven
audits run clean over the Sept-3 route. Every space on that route — bodega,
street, apron, vestibule, lobby, shed, throat, hall, **B1** — has **no authored
way to be corrupted**, and no gate notices, because a gate can only compare what
exists against what is declared. Absent categories are invisible to it.

**The rule.** Gates cover *deviation*. Coverage of *category* is a separate,
human question, and it must be asked deliberately: for each system, enumerate the
population it can act on, and check that the population is the one you meant.

*Evidence:* as §3.6; eleven audits clean at HEAD.

### 3.8 A truncated listing is a sample; only a full listing is a census

The single best specimen of AI-specific failure in the record. `42ec857`
reported that `reality_cases.json` shipped eight case ids and that Peter, Cal
and Mae had no case entry, offering it as evidence of a possible quiet cast
change. `e81592d` retracted it: *"Every part of it was false."*

The mechanism: *"A diagnostic printed `list(keys)[:8]` of an eighteen-key
dictionary and the truncation was written up as though it were the complete
record. The first eight keys happened to exclude Peter, Cal and Mae and to
include Sacha, Evelyn and Teresa, which produced a **symmetrical, plausible and
entirely invented contradiction**. Nothing in the repository ever disagreed with
anything else."*

It survived review and reached the owner **as a recommended action**. The
plausibility was manufactured by the truncation, not found in the data — which
is exactly why it survived. A well-formed wrong answer is more dangerous than a
malformed one.

The retraction's own form is a second lesson: *"retracted here in place, dated,
rather than quietly rewritten, because it reached the owner as a recommended
action"*, with a correction notice above the original text so no reader meets the
old finding first, and with the four **real** findings from the same audit
explicitly preserved and none of them decided.

**The rule.** Never report a contradiction, a census or an absence from a listing
you did not print in full — print the total beside the sample, every time. When
you retract, grep for every citation and explicitly reopen each decision the
finding closed; a retraction that only edits the original is half done.

*Evidence:* `e81592d`; `42ec857`; `design/CAST_CASE_AUTHORITY_AUDIT_2026-08-26.md`;
`game/data/reality_cases.json` (18 records, one enabled, first eight keys
reproduce the false pattern exactly).

### 3.9 Numbers in prose are consumed as specifications, and a wrong suspect outlives the bug

`678b763` corrected a light-cap claim *"repeated in six places that has not been
true for some time"*, and recorded the reason it happened: *"I had answered from
a stale memory before checking the file."* Its distinction is the durable part —
**prose claiming a constraint holds today** is wrong and must be fixed, while
**tables recording "measured at 16/16"** are accurate records of test conditions
and must be left exactly as they are. Same numbers, different kind of statement.

`63b91b1` is the companion: *"I had named `1f8faa0` as prime suspect in two
committed records. It was innocent."* Both records now say so plainly *"rather
than quietly dropping the accusation."*

**The rule.** A number in a document is a spec whether you meant it or not.
Separate live constraints from historical measurements explicitly. When you
retract a diagnosis, correct the accusation in place — a wrong suspect left in a
README is how the next investigator wastes a day.

*Evidence:* `678b763`; `fc64066`; `63b91b1`.

---

## Part 4 — Measurement

### 4.1 Replicate before attributing; measure the noise floor first

The specimens are unusually clean:

- **The 5.03 ms that never existed.** A diagnostic attributed 5.03 ms to prop
  ticks. Direct profiling: 425 ticking props across 27 classes cost **0.42 ms
  per frame in total**. The old figure came from single sequential snapshots in
  a long toggle chain — and its *own* proc column had agreed with the truth all
  along. *"I trusted the frame column over the proc column, twice."* (`14abdd8`)
- **Both movements were noise.** Street elevation base 29.61 / 29.00 / 30.67,
  head 32.28 / 29.07 / 30.04 — *"+0.70 inside overlapping spreads."* And:
  *"`harukiya_rebuild` already said this … and this lane rediscovered it the
  expensive way."* (`8790902`)
- **The control was the finding.** Two identical baseline *renders* differ on
  86.1% of lobby pixels, because residents move. *"Without this control I would
  have reported the lobby as the biggest visual casualty of both policies; it is
  the biggest liar."* (`8f752cc`)
- **Free in the instrument you happen to be holding is not free.** Doubling the
  shadow atlas costs nothing in milliseconds and **1024 MB against a 256 MB
  budget**. *"Frame time misses VRAM."* (`5feaef8`)

**The rule.** Run the null experiment first — same build, same input, twice —
publish the noise floor next to every claimed delta, and refuse to attribute any
movement smaller than a stated multiple of it. Report the metric with the
tightest noise floor rather than the most meaningful one, and say which is the
estimate. Price a component by measuring it directly, never by differencing an
aggregate that contains it. Name which resource each dial spends.

*Evidence:* `14abdd8`, `8790902`, `8f752cc`, `5feaef8`, `c3f3714`, `aca55f5`.

### 4.2 A finding at one member is a fact about that member

> **Measured on one member, asserted about the family.**

*"Silencing prop ticks is worth 47% at the roof and nothing at the atrium, so
P2's 'user prop scripts are not the cost' was measured at one station and
over-applied."* (`20b704d`) Then the same claim was corrected a second time from
the other direction: *"They are the cost wherever there is little to draw."*
(`8f752cc`)

The same shape in a different domain: an acoustic constraint *"'No room is that
deep' described D03 (4.10 × 3.50) and silently generalised; D05 is 6.50 × 2.08
and D01 is 19.30 × 2.08."* And in rigging: every hero rig to date happened to be
the same 2026-08-02 generation as the reference, so a defect that rides on
position tracks was structurally invisible until a rig from another generation
arrived.

**The rule.** When you write a general claim into a document, a comment or a
constant's justification, write beside it **which members you measured**. When a
shared library normalises against a reference, add a heterogeneous member to the
test set deliberately rather than waiting for one to arrive.

*Evidence:* `20b704d`, `8f752cc`, `4c6c039`, `344dbb2`, `efaf55e`.

### 4.3 An insensitive number is a diagnosis, not a tuning problem

> **When the knob barely moves the number, the knob is not the constraint.**

Four rounds of tuning moved a contact distance 0.905 → 0.760 → 0.626 → 0.602 m
and stopped. Instrumenting the mechanism found the cause immediately: the cast
originated **from the tip**, so every result sat beyond full extension. The same
reasoning was then used in reverse to *exclude* a suspect — *"pinning the fauna's
own gait uniform moved it only 0.0281 to 0.0270, which is how we know the gait
was not the term that mattered."*

**The rule.** Before the third round of tuning a parameter, compute the response
ratio. If a >2× change in the control produced a <10% change in the output, stop
and instrument the mechanism. Record the rejected settings **and their numbers**
in the commit, so the next person does not repeat the sweep.

*Evidence:* `41e5cc7`; `c22b987`; `374eab0`.

### 4.4 A dark render is not evidence; authored is not reachable

Two failures that look different and are the same: something was built, and
nobody looked at the thing itself.

*"Five games had shipped with passing rule tests and NOT ONE of their interfaces
had ever been on screen."* All four were broken — one by
`Control.PRESET_RIGHT_WIDE`, which anchors both edges to 1.0, producing *"a
container zero pixels wide whose children are laid out past the edge of the
screen — invisible, silent, and indistinguishable from a panel that forgot to
add them."* (`dde09be`)

*"The haunting was fine; nobody could reach it."* The ordinary state of the game
— one live case, no call, a player walking a corridor — is **0.23 pressure**
against gates at 0.12 / 0.34 / 0.62 / 0.86. **Sixty-five of a hundred and twenty
authored acts, 54%, behind a wall.** *"The complaint is arithmetic, not taste."*
(`f057e57`)

And *"THE LUNETTE HAS BEEN INVISIBLE SINCE V1 BUILT IT"* — the soot backing
authored eight centimetres north of the gable face, invisible at night, found by
arithmetic. *"A dark render is not evidence."* (`fc64066`)

**The rule.** For every system with a perceptual surface, ship a capture station
that drives it into a **non-blank, non-default** state, and review the captures;
treat a dark or default-state capture as NO RESULT, not NO DEFECT. For every
gated system, compute the ordinary-case value of the gating variable and compare
it to the thresholds **before** redesigning anything — "nothing happens" usually
means the gate is set wrong, and rewriting is the expensive way to find that out.

*Evidence:* `dde09be`, `f057e57`, `fc64066`, `386f6e7`, `5d6812b`, `bc6d630`.

### 4.5 A stale build tests green, because it is a valid build of the wrong data

Sixteen parked cars were removed from the records and stayed in every frame the
engine drew, because `game/assets/building/*.gltf` had last been built eight
commits earlier. *"They came out of the records, not the build."* The corrective
rebuild produced all five JSONs **byte-identical** to what was already committed
— *"which is itself the finding"* — and dropped F01 from 332,051 to 316,044
vertices, every deleted box accounted for to the vertex (24 per box, no
remainder).

The consequence was propagated honestly: *"interior visual and perf numbers taken
before today are stale too, not just street ones."*

**The rule.** Stamp the source revision (or a content hash of the inputs) into
every generated artifact and assert it at test startup. Make regeneration a
non-optional pipeline step rather than a documented one. Label every recorded
number with the build it was taken on.

*Evidence:* `cbf0769`, `782776c`, `5771c93`, `4f019c7`.

### 4.6 A centreline is not a face

The most-repeated *geometric* defect in the project, and the reason it is here is
its recurrence pattern. `942ef43` names the class outright: *"This is the fourth
instance today of one anti-pattern … a position derived from something convenient
rather than from the surface the object must actually touch. Blinds measured from
a wall centreline, art from a room rect, windows deleted instead of moved, and
now a tap from a deck."* Towel rails were *"for the third time."* A living rect
containing its own bathroom had *"been found and fixed TWICE before as a one-unit
special case and never generalised, which is why seven units still had it."*

The cure that finally worked was not a better fix; it was **publishing the
resolver**: `WallArtLaw.nested_room_blocks()`, *"deliberately public and unaware
of who calls it"* — and the parallel session adopted it.

**The rule.** Name the datum in the same expression as the offset
(`valve_z = panel_front_z + SEAT_DZ`, never `valve_z = 0.105`). If a routine is
not given the surface it must touch, do not let it guess — move the pass after
that surface exists and pass it in. When you fix one instance, publish the
resolver as a shared function rather than patching the unit, and hand it to
parallel owners explicitly.

*Evidence:* `8226945`, `e66f48c`, `bbdcddc`, `942ef43`, `d985231`, `8b84214`.

### 4.7 Construct the situation; do not wait for the simulation to wander into it

> **The tests had to stop measuring the weather.**

`_use_the_margin` acts on whichever of eighty appendages is nearest, so an
assertion about it was sampling the world, not the behaviour. The fix reduces
the margin to one appendage for the duration of the check — *"and the animal is
never teleported to the appendage. The appendage is moved to the animal."* A
4.8 s window against a 2.4–6.4 s blink interval *"reported a working eye as
furniture, which is worse than no assertion."*

**The rule.** For any non-deterministic or environment-dependent assertion,
either constrain the environment to a single candidate for the duration of the
check, or make the window exceed the longest period of anything inside it.
Assert semantic properties, not literal presentation. Where a contract needs a
rare event, freeze the population or build the case.

*Evidence:* `f6f3669`; `374029b`; `41e5cc7`; `6bed0c0`;
`tools/audit_systemic_situation_authority.py` class `TEST_AUTHORITY_SHORTCUT`.

---

## Part 5 — Building gates that do not rot

The four flagship audits were written within 48 hours of each other and form a
visible maturity ladder. Read in date order they are a tutorial.

### 5.1 A baseline is a ratchet, not an amnesty

`audit_systemic_situation_authority.py:66-71`: *new actionable production
findings FAIL; a baselined finding whose class or confidence changes FAILS (a
baseline entry never suppresses a different class, a higher-confidence mutation,
or a production finding via a test-tier entry); vanished baseline entries are
cleanup opportunities.* Each of its 49 entries carries class + confidence + tier
+ disposition. `audit_interaction_prompt_carriers.py:61-63`: *"A cleanly removed
legacy occurrence is reported as a baseline cleanup opportunity and does NOT
fail."* Live today it reports `baseline_cleanup_opportunities: 1` — the debt has
shrunk by one and nothing was allowed back in.

**The rule.** Write the direction into the tool's docstring and exit codes
*before* writing the baseline: new = fail, changed classification = fail,
removed = clean note. Designate at least one finding class the baseline can
**never** cover. Refuse to write a regenerated baseline into the directory being
gated. Then check that the largest possible improvement — deleting the whole
baseline — still exits clean.

### 5.2 Identify findings by meaning, not by line number

> **Lines are for reading, not for comparing.**

*"Finding identity is line-independent: sha1 of (domain, class, file, scope,
normalized expression). Line numbers are reported for reading, never compared."*
The payoff is measurable: `568a6c2` moved twelve records' `lines` fields by seven
lines and **no classification moved**, against a 3,626-record manifest that
line-keying would have turned into noise.

### 5.3 A heuristic scanner earns trust by counting what it did not report

> **Report everything, count what you excluded, fail on almost nothing.**

Of 3,418 `Vector3` literals, **3,131 are counted in stats and deliberately kept
out of the manifest** — a 92% suppression rate with a written false-positive
policy and the suppressed pool still reported. Of 57 systemic findings today, 45
carry disposition `REVIEW` and **zero** are new actionable. Confidence
(`EXACT/STRONG/HEURISTIC/UNKNOWN`) is crossed with disposition
(`FIX/DELEGATE_TO_OWNER/ADD_PUBLIC_PROOF/DOCUMENT/BASELINE_DEBT/REVIEW`), and
only four dispositions are actionable.

**The distinguishing feature of these audits is not what they find. It is what
they refuse to report, and the fact that they count it.**

### 5.4 A finding class with no path to red is decoration

**The rule.** For every rule your gate can emit, write down the concrete input
that makes the process exit nonzero, and **commit that input as a fixture**. If
you cannot name one, it is a log line. Where the detector also assigns the
severity that decides whether it fails, that is a conflict of interest — put
severity in a separate reviewed policy table.

The project did this properly once and it is the model: `51a0619` shipped with
*"Open Shift's known problems deliberately NOT baselined — the gate catches all
four families on `origin/codex/ethos-open-shift` with STRONG confidence"*, and
the guide records the sick-tree run: *"this exits 1 with 14 new findings."* The
calibration commit is still reachable, so the claim is re-runnable.

> **Point the new detector at a tree you know is ill before you trust green on
> your own.**

### 5.5 Ban the shape, not the vocabulary

The counter-example, and it is live at HEAD. `ABSTRACT_JUDGMENT_FACT` exists to
catch a hidden morality score. Its detector is a regex over judgment *words*
(`good|bad|compliant|morality|correct_choice…`). Run it against
`reality_case_manager.gd:79-80,142-143` — the two global progress meters from
§1.1 — and `JUDGMENT_RE` is **False** on every line, because they are named
`building_stability` and `reality_coherence`. The audit exits clean at the same
commit where the rule it enforces is being violated.

> **The better the name, the better the hiding place.**

**The rule.** State a rule's **structural signature** before its vocabulary.
Here it is one sentence: *any numeric field in the persisted schema whose only
writes are monotonic and clamped, or that has zero readers.* Naming-based
detectors inherit the blind spot of whoever named the thing, and will run green
over the exact violation they were commissioned to find. Pair every vocabulary
heuristic with one structural check that does not read names.

The same file shows the technique done right elsewhere:
`AUTONOMY_DEPENDS_ON_PROXIMITY`, `TIMER_IMPERSONATES_ACTOR` and
`HOST_CLOCK_MUTATES_WORLD` are all shape-defined, and together account for 27 of
the 49 baseline entries.

**Measured, 2026-08-30 — and the number is worse than the argument.** Pointed at
a hand-labelled fantasy-RPG coordinator containing **eighteen** violations —
eight concepts each written twice, once in this project's idiom and once the way
another team would actually write it — the audit caught **three**.

| phrasing | labelled | caught |
| --- | ---: | ---: |
| this project's idiom | 8 | 3 |
| another team's idiom | 8 | **0** |
| objective-UI leaks | 2 | 0 |

`knows` fires; `knows_about_theft` does not. `valve_open` fires; `is_raised`
does not. `trust +=` fires; `reputation +=` does not. And a `Control` node
containing the literal string `"CURRENT OBJECTIVE: recover the brass key"` is
invisible, because the finding is suppressed unless the *filename* matches a
naming convention.

**The failure mode is not a false positive and not a crash. It is `exit 0` on
code the detector did not understand** — which is §2.1 and §2.6 arriving inside
the gate shelf itself.

**The rule, sharpened.** A vocabulary detector's recall is **unmeasured until you
run it on code you did not write**, and a clean report from one is a statement
about your naming habits, not about the code. Before trusting any detector:
hand-label a sample from an unfamiliar codebase, run it, and write the recall
number in the tool's own guide beside its exit codes. If you cannot produce that
number, the tool is a reminder for people who already know the rule — which is
useful, and is not a gate.

### 5.6 A prohibition about the player-facing surface does not bind the storage layer

> **The moment a total exists, someone renders it.**

`design/VIRTUAL_ENVIRONMENT_ETHOS.md` §7 forbids a morality meter in terms of
what the save *labels* the player. `c40d817` restated it as *"No percentage, no
meter, no completion figure, in the HUD or the ORDER device or a menu"* — again,
the view layer. Both were written **while two monotonic global floats were
already shipping in the save schema**, 17 days after they were introduced and 30
days before anyone noticed. `game/docs/reality_maintenance_implementation.md:15`
even documents them as working *"progression"*: a doc-based audit finds a
feature, a tool-based audit finds nothing.

`1209df3` finally stated it structurally: *"derived, never stored… **No aggregate
at any scope.** The loader must structurally refuse a floor-level or
building-level roll-up, because the moment a total exists someone renders it."*

**The rule.** Restate every UI-level prohibition as a **storage-level and
API-level invariant** before you rely on it. Grep the persistence schema, not the
view layer, when you audit compliance.

### 5.7 Encode "undecided" as a checked value — but enumerate the decided ones too

`tools/audit_period_dates.py` requires
`"UNRULED" in semantics["temporal_status"]` and pins four sibling fields
(`classification`, `authored`, `canonical_authority: null`,
`player_surface: debug_overlay_only`). Tested empirically: rewording the status
alone → exit 1; simulating a full owner ruling → **exit 1 with four failures**.
**The gate fails the moment the owner makes the decision.** That is real, it is
in the release path (`package_friends_build.ps1:17`), and it is the seed brief's
hypothesis 4 confirmed at line level.

But the intent is right and the fix is small. The purpose is that a quarantine
must stay *declared* rather than silently promoted to canon — the failure is that
the **only admissible value is the undecided one**.

**The rule.** Store an explicit status field for every body of generated,
scraped or provisional content, and assert its value in CI — but assert it
against an **enumerated set including the resolved states**
(`UNRULED | RULED_CANON | RULED_FLAVOUR`), with the downstream constraints keyed
to whichever is set. Require that changing the status touches the generator and
the check together, so promotion shows up as a reviewable diff rather than a
one-line data edit. **A gate should enforce that a decision is declared, not that
it is unmade.**

The graded form already exists in this repository, one day younger:
`audit_orison_spatial_dependencies.py` fails on a vanished `MUST_PRESERVE_ID` /
`PRESERVE_OR_ALIAS` / `SAVE_CONTRACT` record and treats every other disappearance
as a non-failing cleanup opportunity. Copy that, not the period gate.

### 5.8 Put the contract in the generator, not the output

`bf2e650` added the period gate reading a classification block that lived only in
the **runtime mirror** of a generated file. The next legitimate regeneration
would have silently erased it. `64dc248` moved the classification into
`tools/author_light_provenance.py` itself and added a byte-equality check between
the two mirrors.

**The rule.** Before trusting any automated check, identify the **writer** of
every file it reads. If a generator owns it, move the checked invariant into the
generator's source. A gate that reads only generated output has an expiry date
set by the next build.

### 5.9 An honest evidence metric moves against you first

> **Build, then checkpoint, then read the number. Expect it to rise.**

`09b43e8` measured the real economics of the ledger: building a two-apartment
floor moves STRUCTURAL blockers **80 → 92**, and only once its checkpoint names
the identifiers does it fall **92 → 74**. Doing the work makes the number worse
before it makes it better, because the work and the receipt are separate states.
This was published **to the person about to do the work, before they did it**.

The companion rule from the same commit is the governance one: **a false blocker
is a tooling defect, not something to work around by renaming a room.** The
proof that the project means it is `568a6c2`: **F02_B_VESTIBULE**'s real purpose,
*"2B privacy, coat storage and distribution"*, failed a contiguous-phrase match
for *"privacy and distribution"* **over a comma**, and **unit.2B.entry** was
reported ABSENT on a built, traversed and owner-accepted vestibule. The fix
replaced phrase containment with word-groups — and was validated by enumerating
**all 144 requirements** to show exactly one status moved and nothing else
changed.

**The rule.** When you tighten an evidence rule, publish the expected direction
and magnitude of the movement before landing it, and keep "the work is not done"
and "the receipt is not written" as distinct states. When a gate fails something
you can demonstrate exists, fix the gate — and prove the fix by enumerating the
whole requirement set.

### 5.10 Rehearse the landing on a synthetic subject

`90222e2` built a synthetic sixth floor in **scratch copies** of the v2 layout
and ran the whole acceptance chain against it — no real geometry, nothing under
`res://` mutated. It found two real defects in the machinery (§2.5) and produced
the economics in §5.9, *while it was still free to change them*.

**The rule.** Before a large piece of work lands, rehearse your own acceptance
machinery against a synthetic instance of it. You will learn what your gates
credit and refuse while changing them still costs nothing.

### 5.11 Readiness is scoped

> **A slice proves the slice — print that on the green.**

*"The ledger exists to make one confusion impossible: 'the accepted route works'
is not 'the complete building has been rebuilt.'"* Six ordered scopes; every
requirement declares which it blocks; **the tool never collapses completeness
into one percentage**; the narrow query prints
`FIRST SLICE READY - PRODUCTION CUTOVER NOT IMPLIED.`; and
`--blockers-only` is deliberately an alias for the **wide** meaning, never the
first slice. Today: FIRST_SLICE 0, GOLDEN_SHIFT 1, STRUCTURAL 80, RUNTIME 45,
CUTOVER 95, RETIREMENT 97 — six numbers, no average.

This is the same shape as the release pipeline's *exportable / packageable /
distributable / released* ladder: **no green state implies the one below it.**

*Evidence for Part 5:* `tools/audit_systemic_situation_authority.py:62-71,109-120,271-276`;
`tools/audit_orison_spatial_dependencies.py:22-35`;
`tools/audit_orison_v2_completeness.py:13-14,117-121,126,170`;
`tools/audit_interaction_prompt_carriers.py:61-73`;
`tools/audit_period_dates.py:80-89`; `51a0619`, `64dc248`, `bf2e650`, `09b43e8`,
`568a6c2`, `90222e2`, `c40d817`, `1209df3`.

---

## Part 6 — Working with agents

These are the least likely to have been written down elsewhere and the most
transferable, because they are about the *process*, not the game.

### 6.1 A worktree isolates files, not the machine

Nineteen worktrees exist. A worktree separates checkouts; it does not separate
the GPU, the import cache, the stash stack, or a shared index.
`tools/run_godot_serial.ps1` holds a machine-wide named mutex
(`Global\OrisonGodotSingleInstance`) and then censuses `Get-Process Godot*`,
because *"a separate worktree does not create a separate engine lane."* An idle
**Project Manager window with no project open** once held the lane for six hours.

**The rule.** Before parallelising agents by worktree, enumerate what is still
machine-global — build caches, GPU, ports, stashes, the index of any shared
checkout — and put an explicit fail-closed mutex in front of each, entered by a
named runner every agent must use.

### 6.2 "Untracked" is a statement about your index, not about the remote

A worktree sat at a base that `origin/main` then ran **636 commits** past. Godot's
`--import` minted 51 `.uid` files that showed as untracked, so they looked like a
gap worth committing. All 51 already existed upstream, and **47 held different
values** — Godot mints a fresh random `uid://` only when the file is absent, so
the import invented 47 new identities for scripts that already had canonical
ones. Merging that would have overwritten committed resource identities with
values referenced by nothing. Caught only by diffing against `origin/main`
before pushing.

Note that every *other* rule in this repository guards against sweeping up a
**peer's** working tree. This is the orthogonal failure: nothing was swept, the
pathspec was exact and audited, and it was still wrong.

**The rule.** Before committing any file that is merely *new*, check the remote,
not just the index — and compare **content** where the path already exists.
Generated-identity files (`.uid`, `.import`) are the sharp case: same path,
different value, silent corruption. At the start of any session in a long-lived
worktree, run `git rev-list --left-right --count origin/main...HEAD`; if it is
hundreds behind, retire the branch rather than rebase it.

### 6.3 Never `git add -A`

Banned outright, not discouraged, and it is a scar with at least five separate
incidents behind it: two swept scratch directories in the first two days
(`3a2718d`, `6cc60bc`), a 170 MB engine binary the remote then refused, a commit
that carried out another session's **staged** files under the wrong message
(`7268d6b`), and a concurrent commit cycle that deleted 40 minutes of untracked
bakes under `game/assets/characters/`.

The refinement that matters: staging by name is **not sufficient** when the index
is shared. Run `git diff --cached --name-only` immediately before every commit
and verify every line is yours.

### 6.4 The human gate sits where the required evidence is the absence of prior knowledge

The project automates aggressively and then stops at a precise line, and the line
is principled: a human is required exactly where the evidence needed is a **first
encounter** or a subjective read that no reader of the source can produce.
`design/GOLDEN_SHIFT_HUMAN_RUN_CARD_2026-08-27.md` states it: *"Automated suites
may support K3. They cannot replace it. **A green test is not one of the eleven
checks.** … If you had to realise something, it did not pass."*

Each verdict is a durable file scoped to exactly one claim and pinned to a
reviewed commit SHA, with an explicit statement of what it does **not**
authorise: *"This accepts spatial readability only… It authorizes M08F only."*
The M08A acceptance JSON's entire authorization block is `false`. And the ledger
enforces it: *"a scene-capture receipt is never acceptance."*

**The rule.** Put the human gate where the evidence is a first encounter or a
subjective read, automate everything up to that line, and say so in the artifact.
Record each human verdict as a durable, commit-pinned file scoped to one claim
and explicit about what it does not grant.

### 6.5 Record the failed approach beside the rule

> **A rule that does not carry its scar will be re-litigated by the next agent.**

`HANDOFF.md` has a section titled *"Defects resolved along the way — Kept because
each one cost real time and the diagnosis generalizes."* `sanity_director.gd:47-60`
carries a `REGATED` comment with the measured baseline in source, so the next
tuner sees the numbers rather than the conclusion. `efaf55e`'s docstring *"carries
the map of wrong turns, each measured before being abandoned."*

This matters more with agents than with people, because the commit graph is not
read and institutional memory does not exist between sessions. An unexplained
rule reads as an arbitrary constraint, and an agent optimising locally will
route around it.

### 6.6 Rule the shared frame before the second author, not after they disagree

`d12fe3d` — 148 lines, **zero code** — ruled the world axis. The inventory had
found that *"the two worlds are mirror images about the building: v1's street at
+z, v2's review apron at −z. Nobody noticed because v2's exterior stops at a
6.0 × 3.35 m apron with nothing outside it to disagree."* Settled *"before any
exterior coordinate gets authored twice."*

The counter-example is live: **five** independent implementations of "what minute
is it". `fposmod(x, 1440.0)` appears verbatim in three separate files
(`open_shift_situation.gd:131`, `open_shift_radiator_ecosystem.gd:72`,
`npc_observation_ledger.gd:135`), each with a **different fallback** — the
situation's own durable counter, `-1.0`, and `CANONICAL_MINUTE` — plus a fifth
strategy that parent-walks the scene tree for a duck-typed `_minute_now`. The
systemic audit sees this (9 `HOST_CLOCK_MUTATES_WORLD` entries) and its
disposition is `DOCUMENT`, not `FIX`.

**The rule.** The first time a second component needs an existing shared frame —
axis, origin, unit, epoch, id namespace — stop and have the owner rule it **in
writing** before that component authors a single value. Cost of ruling early: one
document. Cost of ruling late: every value already written in the losing frame.
And when you inject a value provider into more than two consumers, inject an
**object that owns the interpretation** (units, wrap, fallback, failure), not a
raw callable each consumer must interpret.

### 6.7 Audit the file the program opens

`art/data/building_layout.json` and `game/data/building_layout.json` are byte-
identical today (2,624,829 bytes each). **Every auditor defaults to the `art/`
copy** — `audit_orison_spatial_dependencies.py:101`,
`room_checkpoint_reconciler.py:68`, `room_evidence_verifier.py:708`,
`audit_orison_v2_completeness.py:144`. The shipped program opens the `game/` copy
(`building_root.gd:313`). 126 commits have touched both; **5 have touched only
one**, and two of those are genuine single-file divergences.

**The rule.** For any duplicated source of truth, add a byte-equality assertion
to the test suite in the same commit that creates the duplicate, and make every
audit default to **the path the shipped program actually opens**.

### 6.8 The verification layer arrives the week you decide to ship

Every audit tool in this repository was added between **2026-08-26 and
2026-08-28** — a 72-hour burst, in a project that by then was four weeks old. The
burst begins on the same day as `b43cbe1` *"Prioritize a fundable early-access
build"* and `71eec55` *"Charter Early Access distribution and marketing."*

Before that date, plausible work was survivable. The cost of an unearned green
signal changed the moment the audience became external.

**The rule.** Do not treat verification machinery as something that accretes
naturally. It arrives when the cost of being wrong changes, and if you can name
that date in advance, you can build it earlier and cheaply instead of in a
panic — 22,848 lines of tooling in three days is what "later" costs.

*Evidence for Part 6:* `HANDOFF.md:770,1161-1206`; `d8ac27c`;
`tools/run_godot_serial.ps1`; `7268d6b`; `d12fe3d`;
`design/GOLDEN_SHIFT_HUMAN_RUN_CARD_2026-08-27.md`;
`design/ORISON_V2_M08A_HUMAN_ACCEPTANCE_2026-08-28.json`; `b43cbe1`, `71eec55`;
tool introduction dates measured with `git log --diff-filter=A`.

---

## Part 7 — Most load-bearing for the v2 map rebuild

This is why the document was commissioned now. The rebuild has **144
requirements**, of which **46 are ABSENT** (unbuilt, therefore cheap to shape),
42 PROGRAMMED, 34 RUNTIME_PROVEN, 18 SPATIALLY_PROVEN and exactly **1
HUMAN_ACCEPTED**. Twenty-seven conclusions are flagged `heuristic`. The lessons
below are ranked by what they will actually cost if ignored during this specific
piece of work.

**1. Ship the reader-existence gate before you author the new world (§1.1, §1.7).**
The v2 rebuild will author an enormous volume of new spatial data. Every failure
in Part 1 was authored *faster than it was wired*, and the project has never had
a gate for it. The invariant is one line and it is the single highest-value
addition available: *every file in `game/data/` is opened by at least one
production source file; every exception is named.* Add the structural companion
from §5.5 at the same time — *no persisted numeric field whose only writes are
monotonic, and none with zero readers* — because it catches the two dead progress
floats that a vocabulary regex provably cannot see. Build this **before** M11, not
after.

**2. Give spaces an authored way to be wrong (§3.7, §3.6).** Corruption is
indexed by resident in six hardcoded GLSL branches. Every space on the new route
— street, apron, arcade, shopfronts, **B1**, service circulation — will be
outside all six, and therefore structurally incapable of being corrupt, and **no
gate will notice**, because gates find deviation, not absent categories. If the
element-indexed lineage table is not part of the rebuild, the new map ships
inert. This is the one item on this list that is a *design* dependency, not a
process one.

**3. Rule every shared frame before the second author (§6.6).** The axis has been
ruled (`d12fe3d`) — good, and cheaply, because nothing outside the apron existed
to disagree. The rebuild introduces at least four more shared frames the way the
axis was introduced: the street/neighbourhood origin, the shop identifier
namespace, the simulation-tier epoch, and the anomaly/space binding. Each costs
one document now and every authored value later. **Five clocks already disagree**;
do not add a sixth frame to the list.

**4. Expect the blocker count to rise (§5.9).** Building a two-apartment floor
moves STRUCTURAL 80 → 92 before its checkpoint moves it to 74. Anyone reading the
ledger during the rebuild without knowing this will conclude the work is going
backwards. Publish the expected movement to the spatial owner **before** each
milestone, and hold the line that a false blocker is a tooling defect rather than
something to work around by renaming a room.

**5. Rehearse each floor's landing on a synthetic instance (§5.10).** `90222e2`
found two real defects in the acceptance machinery against a synthetic floor, in
scratch copies, for free. Do this once per new *kind* of thing the rebuild adds —
the first shop, the first street segment, the first exterior route — not once per
instance.

**6. Name every new document so the ledger refuses it (§3.2, §3.3).** The rebuild
will generate briefs, censuses, handoffs and work orders at a high rate. Two
shipped documents already promoted spaces by describing them, and the correction
then made accepted work look unproven. Run
`--evidence-impact` on every new design file before committing it, and write
identifiers **bold**. The convention is now standard on every ruling; keep it.

**7. Prove the red on any new gate (§2.1, §5.4).** The rebuild will add gates.
Every one of them must ship with a named input that makes it fail, committed as a
fixture, and — if at all possible — a run against a branch known to violate it.
The one gate that did this (`51a0619`) is the only one whose green anybody should
currently trust without re-derivation.

**8. Look at it (§4.4).** Fifty-four percent of authored haunting acts were
unreachable. Five game panels shipped with passing tests and had never been on
screen. A lunette was invisible from the day it was built. The rebuild's risk is
identical in kind and larger in scale: *nothing is applied building-wide before
ONE example has been rendered and looked at.*

**9. Derive placement from the surface (§4.6).** The single most-repeated
geometric defect, at least six instances across two weeks, and the new map
multiplies the surfaces. Publish the resolvers as shared public functions from
the first floor, not the third.

**10. Keep the human gate where it is (§6.4).** Exactly one requirement is
HUMAN_ACCEPTED today. That number should grow slowly and deliberately, scoped and
commit-pinned. The temptation during a large rebuild is to let a capture receipt
stand in for acceptance; the ledger already refuses it, and it should keep
refusing.

---

## Appendix A — candidates rejected, and hypotheses refuted

**Rejected as facts about Orison, not genetic memory.** The Blender/Godot
version paths and regen commands (a fact about this machine). The one-material-
per-buffer export gotcha (real and expensive, but a Godot 4.7 fact, not a
transferable principle). The specific door-swing arithmetic in the layout
workbench. The 40.70 m street measurements — the *lesson* there is §4.2, not the
numbers. The `ORISON_BIBLE` content rulings, which are canon, not method. Roughly
sixty candidates in total; the discriminator was usually test 2, transferability.

**Seed hypotheses — outcomes.**

- **H1, authored data with no reader.** *Confirmed with corrections, and
  significantly sharpened.* Every number in the brief verified exactly: 415
  outfit values, 25 co-presence pairings, 9 route polylines, the 17-household
  decorating brief, the house-English module with zero production callers, the
  8-cell notice atlas with no text, 191 quarantined light-provenance records.
  **Two corrections.** The save file carries **three** dead fields, not two —
  `discovered_documents` has zero references anywhere in the repository — and all
  three came from the same 2026-07-30 commit about neon. And the failure is
  **not specific to data**: the 10,516-line room checkpoint stack is the same
  defect applied to tools (§1.5). The root cause is not laziness; it is that
  authoring is a complete-looking act with an internal success criterion, while
  wiring is not (§1.2), and that the orphan is often redundant with a derivation
  that already won (§1.3).

- **H2, "the missing piece is an owner and an `advance()`."** *Confirmed for the
  lane it was written about, refuted as a general law, and it names the wrong
  dominant class.* Four corrections, each load-bearing.
  **(i) The 313-system catalogue is not in the repository — and has since been
  retracted.** Two citations existed, no source. **`22542ac` (2026-08-30,
  `claude/mgmt-sept3-handoff`) retracts the figure and corrects both citing
  documents in place**; cite the retraction, not the claim. Its own account of
  the mechanism is worth keeping: *"The number came from an unfiled workflow run
  and was then cited by a later ruling as settled."* The sourced figure is 99
  (`design/ORISON_V2_COMPOSITION_CENSUS_2026-08-28.md`: "Deduplicated from 110
  enumerated rows to 99 distinct authorities", re-counted mechanically as
  COMPOSABLE_NOW 36 / NEEDS_SPATIAL 58 / DELIBERATELY_V1 5).
  **The mechanism is itself the lesson, and it is §3.9 with a receipt:** an
  unfiled measurement became a document's assertion, and a later ruling then
  cited that assertion as settled law. Nothing lied; each step was a reasonable
  reading of the step before. **A number's provenance decays one citation at a
  time, and the decay is invisible because every intermediate document is
  honest.**
  **(ii) In that catalogue the dominant blocker is neither owner nor
  `advance()` — it is SPACE.** 58 of 99 (59%) are `NEEDS_SPATIAL`: a named
  missing anchor, room or carriageway. The slogan is true of the simulation
  programme and **false of the v2 rebuild running in parallel on the same
  date** — which is §4.2 again, a finding at one member asserted about the
  family.
  **(iii) It names the wrong dominant class.** In the only readable
  incompleteness audit, **7 of 9 findings are no-consumer and 0 are
  no-advance** — and no-consumer is roughly seven times more common. "No owner"
  and "no `advance()`" diagnose systems that *run wrong*; "no consumer"
  diagnoses systems that *never run at all* (§1.0).
  **(iv) The `advance()` half is backwards.** Every flagship example is a case
  where the tick already existed **in the wrong hands**. `PorterActor.advance_to()`
  did not add a clock; it moved one (§1.10). The transferable statement is not
  *"add an `advance()`"* but **"the advance must live inside the thing that
  bears the consequence, and that thing must be able to refuse."** The audit
  encodes exactly this in its exclusion list: *a timer that schedules an actor
  is fine; a timer that acts for him is not.*
  And there is a fifth class the slogan cannot express at all: a system with an
  owner, an `advance()`, a consumer and passing tests that is inert because
  n = 1 (§1.11).

- **H3, exit 0 lies.** *Confirmed, and the runner is the least of it.* The serial
  runner lied for 334 commits (§2.1). The geometry builder claim is verbatim true
  (§2.5). Beyond the brief: a headless perf probe reporting zeroes that read as a
  pass, a verification render with culling disabled, `cmd | head; echo $?`, five
  test files that print `PASS` and `quit(0)` unconditionally, and vacuous scoped
  gates (§2.6). The general test that emerged is §5.4: *for every finding class,
  name the input that makes it fail.*

- **H4, gates that punish progress.** *Confirmed at line level, and it is real —
  but the framing is slightly off.* `audit_period_dates.py` does fail the moment
  the owner rules (tested empirically: exit 1, four failures). But the intent —
  keep a quarantine declared rather than silently promoted — is correct, and the
  defect is narrow: the only admissible value is the undecided one. The **better
  form already exists in this repository**, written one day later
  (§5.7). A second instance of the family is `09b43e8`, where correct building
  raises the blocker count — and there the project's response was to *publish the
  expected movement*, which is the right answer (§5.9).

- **H5, tool proliferation.** *Confirmed, but the diagnosis in the brief is
  wrong and the truth is worse.* The seven room tools are **not** redundant and
  **not** ignorant of each other — they compose through a shared workbench and
  cite each other deliberately. The failure is not duplication; it is that
  **10,516 lines shipped in 6h35m with no installer, no caller, no CI, and a
  format that was never adopted** (0 of 25 post-toolchain checkpoints carry a
  verdict table). A closed system of seven tools and seven guides that reference
  only each other. That is §1.5, and it makes tool proliferation a special case
  of the master failure rather than a separate one.

- **H6, two authorities for one fact.** *Confirmed, three instances.* The
  coordinate frames (ruled in time, `d12fe3d`, at a cost of one document). The
  clocks (**five** implementations, disposition `DOCUMENT`, unresolved). The
  documents that promote geometry they describe (§3.2). Plus one the brief did
  not name: **every audit reads `art/data/building_layout.json` while the game
  reads `game/data/building_layout.json`** (§6.7).

- **H7, the global-meter reflex.** *Partially refuted as stated.* I found **one**
  built-and-shipped global meter pair, not a repeated reflex — but it is worse
  than a reflex, because it is *still shipping*, and it exposes the deeper
  finding in §5.6: the rule was written about the **player-facing surface** and
  therefore never bound the **storage layer**, and the audit built to enforce it
  uses a **vocabulary regex** that provably cannot see it (§5.5). The related
  claim, that the two floats have zero readers, is confirmed exactly.

**One thing I could not check.** `f04be59` (the three-way exit-code split,
§2.8) is on `claude/runner-exit-truth` and is **not merged**. The lesson is
sound and the commit is real; the fix is not in `main`.

**One correction made while writing this.** An early draft recorded H2 as
untested because the agent assigned to it died mid-run. It was re-run and is now
answered above. Noting it because the alternative — leaving a hypothesis
described as unverified when it had in fact been refuted in three of four parts
— is exactly the shape of §3.9: a claim that stops being true and stays in the
prose because nobody re-checked it against the tip.
