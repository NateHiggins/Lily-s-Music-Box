# Orison v2 runtime composition census — 2026-08-28

**Task:** DEV-COMP-1. **Lane:** runtime composition and tests only. No
spatial schema, blockout JSON, floor geometry, scene geometry or
checkpoint was created or modified. **Base commit:** `2cf7588`
("Classify the radiator interaction surface in the census"), the tip of
`origin/main`. The Open Shift integration **has** landed on main at this
base, and so has the harness truth fix — `tools/run_godot_serial.ps1`
caches the process handle, so every exit code below is real.

This census extends the M08D 1:1 authority-parity method
(`design/ORISON_V2_M08D_RUNTIME_PARITY_CHECKPOINT_2026-08-28.md`) from
the nine route authorities it covered to **every** authority the v1 root
composes. It is the M15 runtime-matrix work list and the spatial owner's
NEEDS_SPATIAL feed.

## Outcome in one paragraph

Ninety-nine distinct authorities were enumerated and classified against
the v2 root. **One was composed**: the observation ledger's presence
provider, the named parked debt from the Sept 3 handoff. The other two
candidates the assignment named — the waking-residue owner and the
sleep gates — were **verified NEEDS_SPATIAL and deliberately left
uncomposed**, because in both cases the code would have *run* while
being wrong, which is the exact counterfeit this program forbids. Two
pre-existing defects were found and one was fixed. The three gates
finish exactly as found, with one deliberate manifest update of three
records, all from files this task added or edited.

## Classification

| Class | Count | Meaning |
| --- | ---: | ---: |
| COMPOSABLE_NOW | 36 | needs no new geometry |
| — of which already composed in v2 | 16 | parity already held |
| — of which **composed by this task** | **1** | the presence provider |
| — of which deferred with cause | 19 | see "Deferred" below |
| NEEDS_SPATIAL | 58 | named missing space/anchor; feeds the spatial owner |
| DELIBERATELY_V1 | 5 | presentation welded to v1 geometry; not a gap |
| UNKNOWN | 0 | — |

Four rows were re-classified against their enumerating agent's first
answer after I read the source myself; each is argued below. The
enumeration was produced by parallel readers over
`building_root.gd:304-826`, its helper builders, and the four candidate
deep-dives; the full deduplicated table is appended.

## The three named candidates

### 1. Waking-residue owner — NEEDS_SPATIAL, not composed

The M10 runway report hypothesised that
`MinaCaptionManifestation`'s acoustic-node fallback "may suffice without
a v1 socket". **It does not, and the failure is silent.**

`_residue_display_position()`
(`game/scripts/cases/mina_caption_manifestation.gd:173-186`) looks up
layout socket `2A_FRIDGE_FACE` by iterating `layout["floors"]`. The v2
layout has no `floors` key at all — it carries `levels`
(`orison_v2_runtime_root.gd:43`) — so on v2 **the socket branch is
structurally dead and the fallback always fires**. The fallback mounts
the label at `AcousticGraphData.node_pos("F02_2A_FRIDGE_01")`, which
resolves to a real position — **in v1 coordinate space**. Composed
today, the residue, the four authored captions
(`:10-19`) and every remote propagation caption (`:129`) would render at
v1 coordinates inside v2 geometry. It would boot, log nothing, and be
wrong.

**Needs:** a semantic anchor node **F02_2A_FRIDGE_01** in
**F02_A_KITCHEN** so `OrisonV2AnchorAdapter.install_acoustic_overrides`
can retarget the node into v2 space. **REQUIRED**
(`orison_v2_anchor_adapter.gd:4-8`) does not list it, and no
appliance-class anchor exists in the blockout — the nearest F02_A
kitchen identities are the clearance zones **F02_A_KITCHEN_WORK_RUN**,
**F02_A_KITCHEN_AISLE**, **F02_A_CAPTION_WORK_ZONE**. Secondarily, the
socket path needs either a v2 equivalent of `2A_FRIDGE_FACE` or an
owner ruling that the acoustic-node display path is canonical.

### 2. Passenger-lift sleep gate — NEEDS_SPATIAL, not composed

Every *consumer-side* prerequisite is ready: `SleepPressureDirector`
duck-types the gate and treats null as a safe no-gate
(`game/scripts/dream/sleep_pressure_director.gd:151-162`), and
`CampaignShell.bind_waking_services` already threads it
(`campaign_shell.gd:55-60`). The v2 blockout even carries the shaft
(**PASSENGER_LIFT_SHAFT**), the F01–F04 landings, and levels that map
trivially onto stops.

I still classify it NEEDS_SPATIAL, against the deep-dive's
"composable with a ~20-line adapter", for three reasons that are
spatial decisions rather than composition ones:

1. `OrisonElevator.setup` requires `cabin` dimensions
   (`game/scripts/building/elevator.gd:65-68`) that **exist nowhere in
   the v2 schema**. Choosing them because "a 1.55 × 1.7 car fits a
   2.4 × 2.5 shaft" is authoring geometry.
2. The blockout marks **F01_PASSENGER_LIFT_RESERVATION** class
   **`unresolved`** — the schema itself records that the spatial owner
   has not decided this space.
3. `setup` positions through `GameBoot.b2g`, which negates y, while the
   v2 blockout world maps plan-y directly to +z
   (`orison_v2_blockout.gd:301`). Fed the v2 rect raw, the car and its
   sleep-block AABB land mirrored into the north half of the core while
   the authored landings sit on the south face. That is the same
   wrong-place failure as the street gate below, and it would gate a
   volume no player stands in.

**Needs:** resolve **F01_PASSENGER_LIFT_RESERVATION** — authored cabin
dimensions, a B1-landing decision (v2 has none; the basement is
stairs-only via **PRIMARY_B1_F01**), and either a y-negated shaft rect or
an explicit v2-native convention for the class.

### 3. Street/carriageway sleep gate — NEEDS_SPATIAL, not composed

`StreetTraffic.build()` takes no layout at all; its site is baked as
constants (`street_traffic.gd:24-58`): lanes at plan-y −17.0/−21.8,
kerb band 14.55–24.10, spawn ±52 m. The v2 blockout's entire southern
extent is **F01_STREET_APRON**, a 6.0 × 3.35 m threshold slab, and the
site ends at its south edge; **no carriageway, kerb, lane, pavement or
shelter record exists anywhere in the file.**

Composed verbatim, the same negated-y mismatch would place its
sleep-block AABB at Godot z +14.55…+24.10 — *north* of the building,
past the rear apron — leaving the real street front ungated. Null is
the honest state today, and it is safe: the null gate short-circuits to
"not blocked" rather than crashing.

**Needs:** a carriageway space south of **F01_STREET_APRON**, roughly
plan-y −15…−24 by x ±52, to satisfy the authored constants; or an
owner ruling that v2's street is a different shape, in which case
`StreetTraffic`'s constants are the thing to re-derive.

## What was composed

**The observation ledger's presence provider**
(`game/scripts/building/orison_v2_runtime_root.gd`, new
`_compose_observation_ledger()` and `resident_is_home()`).

The ledger gates in-flat sight on presence, and an unbound provider
means *assume home* (`npc_observation_ledger.gd:107-110`): every
resident counts as standing in their own flat at the instant of every
visible event. Lena could therefore earn a durable `in_home_sight`
belief — committed with provenance and deduplicated forever — at a
minute her own authored timetable had her out on a corridor round. The
ledger's stated contract is that nothing else may author NPC knowledge;
assume-home quietly authored it. **This is live in v1 as well as v2**:
v1 spawns real bodies and a `ScheduleDirector`, but has never wired
either to the ledger (repo-wide, the only `presence` references are the
ledger's own definition).

The fix binds the authority that already owns the fact, and owns it as
data: `ScheduleDirector.resolve()` is pure over
`res://data/resident_schedules.json` and needs no resident body, no
floor node and no layout geometry. Three properties make this honest
rather than decorative:

- **The dispatch half stays inert.** The director is composed with a
  null routines target, so `_process` returns immediately
  (`schedule_director.gd:99-101`). v2 has no resident bodies; a
  timetable that tried to move them would be composing an absence. Only
  the resolution half is used — the half that answers the question.
- **It reads the place token, not the mapped directive.**
  `directive_for()` resolves world *points* through v1 layout
  coordinates. The `place` token is the authored fact itself and needs
  no geometry, so the provider cannot inherit the v1-coordinate hazard
  that disqualified the residue owner.
- **One clock.** The ledger's `minute_provider` and the presence lambda
  both read the situation's own durable simulation minutes
  (`open_shift_radiator_ecosystem.now_minutes()`), so a belief can never
  be dated to a minute at which its witness was somewhere else. The
  ecosystem's own `minute_provider` argument is left exactly as it was,
  so the porter's proven timeline determinism is untouched.

It degrades to the ledger's own assume-home if the timetable data is
unavailable, rather than inventing an absence.

**Behaviour at canonical test time is unchanged**: at minute 180 (03:00,
`DAYNIGHT=0`) Lena's timetable has her in `unit:bedroom`, so the
provider answers exactly what assume-home answered. It diverges only
where the timetable genuinely puts her elsewhere.

### Proof

`game/tests/orison_v2_presence_ledger_test.gd` (+ `.tscn`), **17/17
PASS, exit 0** under explicit v2. It proves the gate is real rather than
bound-but-always-yes: at minute 180 Lena is home and a visible change is
learned by `in_home_sight`; the situation clock is then advanced 140
minutes into her authored corridor round, where she is **not** home and
an identical visible change is **not** learned. It also proves hearing
is not silenced by the sight gate (the riser still reaches 3B), that the
earned belief is stamped with the minute she was present, and that the
beliefs reconstruct identically after save/reload **under both roots** —
including that the rollback root does not resurrect the belief the gate
refused.

## Findings recorded, not fixed

**F1 — hearing ignores presence (owner: the ledger / Open Shift).**
Presence gates `witness_visible_state` only
(`npc_observation_ledger.gd:57-68`); `witness_audible_event` consults no
presence at all (`:38-52`). So the resident of the sounding flat earns
an `in_home_hearing` belief at a minute her timetable has her on the
corridor. Binding presence did not create this and must not paper over
it, so the test **pins** the current behaviour with a check labelled
KNOWN GAP: a deliberate change to hearing semantics will fail there and
be read. Whether hearing should be presence-gated (and whether "in-home
hearing" is even the right channel for an absent resident) is the
ledger owner's ruling.

**F2 — one-shot sight has no return-home path (owner: design).** A
truthful provider makes residents legitimately *miss* events fired while
they are out, and the ledger has no re-observation-on-return mechanic:
those beliefs are lost rather than deferred. Correct per the ledger's
contract, but it exposes that sight is modelled as instantaneous while
residue vocabulary like `resident_saw_return` assumes otherwise.

**F3 — the watch round cannot be worked in v2 (owner: spatial).** A
census keyed on `building_root.gd` text alone would wrongly call
`WatchStationNetwork` v2-only: v1 composes it *indirectly* through
`OrisonDetailPass` (`orison_detail_pass.gd:460-501`) **with two
stations**. v2 composes the network, receiver and key guard directly but
registers **zero** stations, so `station_count() == 0` and marks can
never accrue. Needs the two placements: F02 corridor west wall beside
2A's door, and the B1 coal-bunker north wall by the boiler.

**F4 — heat balance is inert at n=1 (owner: spatial).** With one
radiator the zero-sum solver's share term cancels
(`heat_balance.gd:97-103`): vent grade and the partial-supply penalty
have provably zero effect on delivered heat, which is the entire reason
the file exists. `configure()` also reads `layout["floors"]` and finds
nothing on v2. Composing it over v2's single radiator would run without
error and mean nothing. Honest minimum: ≥2 radiator records carrying
riser membership. Current v2 — props standing alone, no balance, no
tend — is the honest state.

**F5 — any `design/ORISON_V2_*.md` is automatically ledger evidence
(owner: completeness tool / all authors).** The completeness audit globs
every file matching that pattern as a checkpoint document
(`tools/audit_orison_v2_completeness.py:522`) and **promotes any space
whose exact id the document backticks**, provided the id still exists in
the v2 layout. This document matched the glob. Its first draft backticked
thirteen identifiers and silently moved FULL_BUILDING_STRUCTURAL from 78
to 77 and PRODUCTION_CUTOVER from 94 to 93 — a census that proves
nothing spatial was promoting a space by describing it. Caught by
diffing the ledger with and without this file present.

**Every identifier in this document is therefore written in bold, not
backticks, deliberately.** Do not "tidy" them into code spans: doing so
re-arms the promotion. The general trap is worth the tool owner's
attention — a report, a work order and a proof are all `ORISON_V2_*.md`,
and only one of them should be evidence. A `status: report` front-matter
opt-out, or restricting the glob to `*CHECKPOINT*`, would close it.

## Defect fixed

`game/tests/open_shift_save_matrix_test.gd:27` asserted the *committed*
selector default by calling `Selector.selected_id()` immediately after
`reset_for_tests()`, which re-reads **ORISON_BUILDING_ROOT** from the
environment. The suite therefore reported a **false 16/17 failure
whenever it ran under the explicit v2 selection its own matrix
exercises**. A/B proves it pre-existing and unrelated to this task: the
**pristine** tree fails 16/17 under `ORISON_BUILDING_ROOT=v2` and passes
17/17 without it. The check now asserts `Selector.DEFAULT_ID == "v1"` —
what its own label claims, and what
`orison_v2_m08f_runtime_test.gd:153` already asserts for the same
contract. Now 17/17 under both roots.

## Deferred COMPOSABLE_NOW (19), with cause

These need no geometry and would not crash, but composing them into a
gray-box collision blockout would produce authorities with no subjects
or presentation with no consumer — and, for two of them, the same
v1-coordinate hazard as the residue owner. Each is a legitimate M15
candidate once v2 has the surfaces they govern.

| Deferred | Why now is wrong |
| --- | --- |
| WorldEnvironment/Environment, sky dome, ExteriorMoon, DayNightDirector, viewport render-time instrumentation | No consumer: the blockout has no materials, windows or exterior sightline. Composing them changes how every existing v2 review capture renders — those captures are the spatial lane's checkpoint evidence, not mine to perturb. |
| LightRig | Ranks authored lights into a budget; v2 authors none, so it would govern nothing. |
| AmbientSoundscape, OrisonMusicDirector | The music director's roam destinations come from v1-authored acoustic node positions; only three acoustic anchors are overridden into v2 space today. Same wrong-coordinates class as the residue. |
| BoilerTend | Would tick the plant honestly, but its stated partner (HeatBalance) is inert at n=1 — see F4. Deferred with the balance rather than split from it. |
| DeskZone, ClockProp, TapProp, MonitorProp, DoorAnomaly + Room0, CaseDoorProp | Marker-driven props. Each needs a named blockout anchor for the adapter to mount; without one, choosing a position is authoring geometry. Reclassified NEEDS_SPATIAL-adjacent: they are composition-ready the moment their anchor exists. |
| TouchControls, ShotCapture, PropWarehouse + debug overlay | Dev/input tooling with no gameplay authority; PropWarehouse additionally needs **PROP_SCRIPTS**, a v1 `building_root` constant. |
| VantryPointNetwork (full 119 points) | v2 composes the single-point variant honestly; the other 118 are v1 ceiling positions. |

## Per-system authority parity (M08D extended)

`v1 : v2-before : v2-after`. Rows above the rule are M08D's original
census, carried forward and re-verified; rows below are new.

| Authority | v1 | v2 before | v2 after |
| --- | ---: | ---: | ---: |
| PlayerController | 1 | 1 | 1 |
| WorkOrders / ObjectiveTracker / MaintenanceInventory | 1 ea | 1 ea | 1 ea |
| ServiceSetCarrier | 1 | 1 | 1 |
| CallInterface / VirusSoundDirector | 1 ea | 1 ea | 1 ea |
| ChirpHunt / MinaCaseGameplay / VantryPointNetwork | 1 ea | 1 ea | 1 ea |
| CoreLoopDirector / SafetyNet | 1 ea | 1 ea | 1 ea |
| F01 mail/porter/telephone/dumbwaiter | 1 ea | 1 ea | 1 ea |
| FirstShiftDirector | 1 | 1 | 1 |
| ServiceRoundDirector | 1 | 1 | 1 |
| OpenShiftRadiatorEcosystem | 1 | 1 | 1 |
| **NpcObservationLedger** | 1 (ecosystem-minted, no presence) | 1 (ecosystem-minted, no presence) | **1 (root-composed, presence-bound)** |
| **Resident presence authority** | 1 dispatcher, never wired to the ledger | **0** | **1 (timetable, dispatch inert)** |
| WatchStationNetwork | 1 + **2 stations** | 1 + 0 stations | 1 + 0 stations |
| MaintenanceShopService | 1 | 0 | 0 |
| MinaCaptionManifestation | 1 | 0 | 0 |
| HeatBalance / BoilerTend | 1 ea | 0 | 0 |
| StreetTraffic / OrisonElevator (sleep gates) | 1 ea | 0 | 0 |

M08D's two "blocked by missing physical owners" rows (FirstShiftDirector
0, ServiceRoundDirector 0) have since closed; this census confirms both
at parity.

## NEEDS_SPATIAL feed — recommended order

The order is by what each unblocks, not by size.

1. **Maintenance shop counter** — a shop/storage space in B1 or F01
   carrying an anchor resolvable as
   `storm_shop_hardware_paint_counter_top` with `{rect, z0, h}`, or an
   adapter translating a v2 anchor of that identity into the furniture
   record shape. `shop_id` `hardware_paint` is the transaction gate;
   renaming it means editing `data/shop_inventory.json` too. **Unblocks
   golden-shift beat 4**, where every human run currently stops.
2. ****F02_2A_FRIDGE_01**** semantic anchor in **F02_A_KITCHEN** —
   unblocks the waking-residue owner and beat 11's residue.
3. **Two watch stations** (F02 corridor west wall beside 2A's door; B1
   coal-bunker north wall by the boiler) — unblocks the watch round.
4. **Resolve **F01_PASSENGER_LIFT_RESERVATION**** (cabin dims, B1 landing
   decision, y-convention) — unblocks the lift sleep gate at beat 9.
5. **Carriageway space south of **F01_STREET_APRON**** — unblocks the
   traffic sleep gate; alternatively re-derive `StreetTraffic`'s
   constants for a v2-shaped street.
6. **≥2 radiator records with riser membership** in a v2-schema feed,
   plus `graph_node_id` assignment at mount — makes heat balance mean
   something.

## Validation — every command, real exit codes

Godot runs were serialized through the fixed runner (one process, lane
checked); the two-root matrix exceeds the 60 s ceiling and was run
directly, as its own convention requires.

| Command | Result | Exit |
| --- | --- | ---: |
| `orison_v2_presence_ledger_test` (v2) — **new** | PASS 17/17 | 0 |
| `orison_v2_m08f_runtime_test` (v2 / v1) | PASS 29 / PASS 29 | 0 / 0 |
| `orison_v2_two_root_matrix_test` (v2, direct) | PASS 24, all four directions | 0 |
| `RealitySaveCompatTest` (v2 / v1) | PASS 14/14 / 14/14 | 0 / 0 |
| `DreamBoundaryTest` (v2 / v1) | PASS 38 / PASS 39 | 0 / 0 |
| `OpenShiftAuthorityTest` (v2 / v1) | PASS / PASS | 0 / 0 |
| `OpenShiftSaveMatrixTest` (v2 / v1, after fix) | PASS 17/17 / 17/17 | 0 / 0 |
| `OpenShiftSaveMatrixTest` — pristine tree, env v2 (A/B) | 16/17, pre-existing | 1 |
| `OpenShiftWork/Ignore/Abandon/Meddle/SituationTest` (v2) | PASS ×5 | 0 ×5 |
| `MaintenanceServiceRoundTest` (v2) | PASS | 0 |
| `python tools/audit_orison_v2_completeness.py` | unchanged vs baseline | 2 (expected) |
| `... --blockers-for golden-shift` | only `golden.eleven_beats` | 2 (expected) |
| `python tools/audit_orison_spatial_dependencies.py` (after manifest update) | clean, 0 new unclassified | 0 |
| `python tools/audit_systemic_situation_authority.py` | 0 new actionable, 0 baseline violations | 0 |
| `python tools/tests/test_orison_v2_completeness.py` | 64 OK | 0 |
| `python tools/tests/test_orison_spatial_dependencies.py` | 48 OK | 0 |
| `python tools/tests/test_systemic_situation_authority.py` | 34 OK | 0 |

**Completeness ledger, before → after:** `by_status` and
`blockers_by_scope` are **byte-identical**: FIRST_SLICE_TECHNICAL 0,
GOLDEN_SHIFT_V2 1, FULL_BUILDING_STRUCTURAL 78, **FULL_BUILDING_RUNTIME
45 → 45**, PRODUCTION_CUTOVER 94, V1_RETIREMENT 96. That is the correct
outcome, not a disappointment: the ledger's runtime rows are per-space
and per-system obligations, and binding a presence provider to an
existing authority satisfies none of them. Moving FULL_BUILDING_RUNTIME
requires the spatial feed above.

**Manifest delta (deliberate, this commit):** exactly **3 records added,
0 removed, 0 reclassified**, all from files this task authored or
edited — `3B` (unit_reference, RUNTIME_LOOKUP/PRESERVE_OR_ALIAS) in the
runtime root from the ledger's observer list, and **F02_B_RADIATOR_01**
plus `2B` (TEST_CONTRACT/UPDATE_TEST_FIXTURE) in the new test. Nothing
was silenced.

**Selector and layout:** `BuildingRootSelector.DEFAULT_ID` is untouched
at `"v1"`, asserted in-run by the M08F, two-root-matrix, save-matrix and
new presence suites. The production layout SHA-256 remained byte-stable
in every suite that checks it.

## Limitations

- The enumeration is a source census, not a runtime census: a system
  that composes another indirectly can be missed by file-scoped reading.
  F3 is exactly that failure caught once (`WatchStationNetwork` via
  `OrisonDetailPass`); there may be others, and the honest reading is
  that the 99 rows are a floor, not a ceiling.
- Sixteen COMPOSABLE_NOW rows describe authorities v2 already composes;
  they are parity confirmations, not available work.
- The presence provider is composed **in v2 only**. v1 still runs
  assume-home, so the two roots now differ in this one respect. That is
  the honest direction to diverge (v2 gains the truthful gate), but v1
  should follow, and until it does, a v1 run and a v2 run can record
  different beliefs for the same visible event at a minute the resident
  is out. Recommended as a small follow-up in the v1 lane.
- `resident_is_home` is only consulted for units carrying an observer;
  today that is Lena (2B) alone, since hearing is not presence-gated
  (F1). Omar's presence entry exists but is never read.
- Deferral rationales for the 19 rows are judgments about consumer
  absence, not proofs; each should be re-tested when v2 gains the
  surfaces named.

## Appendix — full classification table

Deduplicated from 110 enumerated rows to 99 distinct authorities. Where
this document's body re-classifies a row after direct source reading
(the residue owner, both sleep gates, heat balance, the marker-driven
props), **the body is authoritative**.

<!-- The table below is generated evidence; columns are clipped for
     width. Full untruncated evidence, including line numbers, is in the
     per-row `v1_evidence` fields cited throughout the body above. -->

### COMPOSABLE_NOW (36)

| Authority | v1 composition | Owns | v2 blocker / note |
| --- | --- | --- | --- |
| AmbientSoundscape (building ambient audio bed) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation-only ambient audio; no durable state | None hard — player-relative emitters plus optional group members (v2 has radiators via RadiatorProp mounts; resident_placeholders… |
| BoilerTend | building_root.gd:435-443; configure(get_node_or_null('B1_BOILER_01') as BoilerProp, heat_… | the slow plant clock: carries BoilerProp's physical facts into the radiator budget and hot taps; transie… | a BoilerProp named B1_BOILER_01 (v2 HAS this anchor + prop, orison_v2_runtime_root.gd:173-175), heat_balance, and TapProps (none … |
| BoilerTend + boiler/tap water loop | game/scripts/building/building_root.gd:435-443 (finds B1_BOILER_01, scans children for Ta… | The plant's 1 Hz tick clock (tick_plant), propagation of boiler output to HeatBalance and hot-water temp… | None beyond nodes that already exist: v2 mounts BoilerProp at B1_BOILER_01 (orison_v2_runtime_root.gd:173-175) but composes no Bo… |
| building_root group identity + renderer announcement | game/scripts/building/building_root.gd:311-312 (add_to_group("building_root"), _announce_… | group-addressable identity used by every system that reaches for the building; diagnostic renderer print… | none |
| CallInterface | building_root.gd:411-417; call_interface.world = self | case call/runner surface; reveal beats resolve props by marker-spawned node name through .world; no dire… | a world root whose children carry marker ids (v1: building_root; v2: _blockout + adapter-mounted props) |
| ChirpHunt (vantry-point chirp mini-loop) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Chirp-hunt behavioral state over vantry_points/work_orders/maintenance_inventory | VantryPointNetwork — v2 provides a single-point network (orison_v2_runtime_root.gd:199-214), so hunt breadth is reduced but valid |
| ClockProp wall clocks (marker kind 'wall_clock') | game/scripts/building/building_root.gd:86 (PROP_SCRIPTS), setup 1313-1316 (bind_order_spi… | Spring reserve / winding state, WO-CLOCK-001 work-order issue via WorkOrders spine, house-time-vs-truth … | Two clock spots (4B apartment wall, lobby wall) via WallArtLaw.legal_spot over room rects, or a plain authored anchor; v2 has F04… |
| CoreLoopDirector (waking-services campaign loop; shell-owne… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Campaign/waking loop authority (job offers, day progression) over WorkOrders durable state (RealityState… | Elevator and street_traffic service legs (deliberately null in v2); return positioning delegated to the v2 anchor resolver instea… |
| DayNightDirector | building_root.gd:894-899; setup(self, env, moon, dome.material_override) | sole absolute writer for the Environment and the exterior directional key; resolved presentation profile… | needs the env, moon, and (optionally null) sky-dome material from the three rows above; no layout/geometry |
| DeskZone (marker kind 'desk_zone', 4B support desk seat) | game/scripts/building/building_root.gd:1257-1265; wired to call_interface 1259; case orde… | Seated-player state and the only room-visible view of the case queue (interact prompt); gates when cases… | One Area3D at the 4B workstation desk position; v2 already has the F04_B workstation space (F04_B_MONITOR_01 anchor resolved by a… |
| DoorAnomalyProp F04_B_DOOR_ANOMALY + Room0 pocket space | game/scripts/building/building_root.gd:80 (PROP_SCRIPTS), Room0 bind 707-711; classes gam… | Seam emission intensity (breathes with room infection), portal to Room0; Room0 owns occupant, return pos… | One wall-seam anchor between the 4B workstation and radiator (F04_B space exists in v2 blockout); Room0 builds its own geometry f… |
| ExteriorMoon (DirectionalLight3D) | building_root.gd:883-893 | the single exterior directional key (color/energy/shadow tuning); DayNightDirector becomes its absolute … | none |
| FirstShiftDirector + F01 desk prop bindings (watchman detec… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | First-shift opening-ritual sequencing; gates on durable RealityState.data["intro_complete"] (first_shift… | Four F01 desk anchors — all present and mounted in v2 (F01_WATCHMAN_DETECTOR, F01_NIGHT_REGISTER, F01_SIGNAL_REGISTER, F01_TOUR_K… |
| HeatBalance (zero-sum steam budget) | building_root.gd:418-419; configure(layout) reads radiator markers (heat_balance.gd:22-34… | per-radiator share states and riser membership; the zero-sum heat model BoilerTend and RadiatorProps con… | data-shaped, not geometric: needs a radiator census (id/riser/unit dicts). v1 gets it from layout markers; v2 layout has none, bu… |
| HeatBalance — the 23-radiator zero-sum steam cycle | game/scripts/building/building_root.gd:418-419 (HEAT_BALANCE_SCRIPT.new().configure(layou… | Per-radiator states (supply/vent grade/pitch/target) keyed by marker id, riser membership, boiler output… | Data-only: radiator marker records (id, riser, unit, pos height) read from layout['floors'] markers; no geometry. v2 layout uses … |
| LightRig (light/shadow ranking budget governor) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation: per-frame ranking of which authored lights are enabled and which cast shadows; no RealityS… | None hard — governs whatever populates groups "light_fixtures"/"floor_lights"; sibling lookups are get_node_or_null and optional |
| MaintenanceInventory | building_root.gd:348-351 | durable RealityState.data.maintenance_items (maintenance_inventory.gd:18-19,78) | none |
| MinaCaseGameplay | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Mina case gameplay logic over the objective/work-order spine; no direct RealityState.data writes found (… | None — pure authority wiring (objective_tracker, work_orders) |
| MonitorProp domestic picture receivers (marker kind 'monito… | game/scripts/building/building_root.gd:77 (PROP_SCRIPTS); class game/scripts/props/monito… | Screen/tuning state, found-screen atlas presentation, acoustic graph membership; distinct class from Sig… | Per-unit monitor anchors; v2 already resolves F02_A_MONITOR_01 for acoustic overrides (orison_v2_runtime_root.gd:51-53) but mount… |
| Night sky half dome (_build_sky_dome, custom sky shader) | building_root.gd:881 (call), func :902+; panorama texture loaded :834-836 | camera-centered upper-hemisphere sky presentation: panorama blend, celestial body, procedural cloud deck… | none — camera-centered dome, never samples lower hemisphere; only matters where sky is visible (windows/roof); v2 blockout has no… |
| ObjectiveTracker | building_root.gd:336-339 (presentation_enabled=false) | diegetic work-order readout presentation; presents owner-authored headings; no RealityState.data writes | none |
| OpenShiftRadiatorEcosystem | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Open-shift radiator gameplay loop over work_orders + the SR radiator prop; no private RealityState.data … | ServiceRoundDirector.RADIATOR_ID resolved against _blockout (present in v2). The v1-only tail is apartment_encroachment.bind_serv… |
| OrisonMusicDirector (diegetic ghost-radio station + earned … | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Durable music library under RealityState.data["music_library"]; presentation of radio broadcasts and MP3… | Ghost-radio roam destinations come from v1-authored AcousticGraphData node positions; v2 adapter overrides only 3 acoustic anchor… |
| PlayerController | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Physical player body, camera, lamp, carried device slot | Only a spawn position; v2 already provides one in blockout space |
| PropWarehouse (debug prop catalog hall) + building_debug ov… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Debug-only physical display hall of every prop family; no durable state | None — builds its own hall 400 m east at a constant origin; needs only the PROP_SCRIPTS dictionary (a building_root const the v2 … |
| SafetyNet (out-of-world player recovery) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Last-real-standing-position memory and teleport-back authority; exempt_zones list | None — player-relative |
| ServiceRoundDirector (SR4 waking service round) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Service-round behavioral state translating call/mechanism events into WorkOrders calls; no parallel life… | RADIATOR_ID node (F02_B_RADIATOR_01 mounted in v2), boiler at B1_BOILER_01 — all satisfied by v2 anchors |
| ServiceSetCarrier (no-screen Vantry service radiophone in-h… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Carried-device presentation and its work-order voice surface; no RealityState.data subtree (orders live … | None — attaches to player and camera |
| ShotCapture (F-key screenshot/review tool) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Screenshot capture and optional debug-chrome toggle; no durable game state | None |
| TapProp water fixtures (marker kinds 'sink'/'shower') | game/scripts/building/building_root.gd:105-106 (PROP_SCRIPTS), config 1322-1328 (fixture/… | Hot/cold valve state, hot-water temperature from BoilerTend, complete fixture geometry (marker owns whol… | Bathroom/kitchen fixture anchors per unit; v2 has F02 A/B unit rooms — a single anchored fixture works today, full coverage needs… |
| TouchControls (touch look/move overlay) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation/input overlay only; no durable state | None — viewport geometry only; needs the PlayerController v2 already has |
| VantryPointNetwork (full 119-point build) | building_root.gd:359-362; build(layout, floor_nodes, work_orders) | the 119 ceiling ears: per-floor three-surface MultiMesh batches + one full owner FunctionalProp; current… | layout point set + per-floor parent nodes for batching; v1 ceiling positions |
| Viewport render-time instrumentation | building_root.gd:378 (RenderingServer.viewport_set_measure_render_time) | perf measurement flag; no state | none |
| VirusSoundDirector (infection/motif diegetic sound) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation of the building infection soundscape; no private RealityState.data subtree seen | Acoustic anchor bindings — already bridged in v2 via adapter.install_acoustic_overrides for F02_A_MAIN_VANTRY_POINT, F02_A_MONITO… |
| WorkOrders | building_root.gd:340-344; setup(objective_tracker), bind_job_library(MaintenanceJobLibrar… | durable RealityState.data.work_orders and RealityState.data.maintenance_jobs (work_orders.gd:36-39,55,26… | none |
| WorldEnvironment + Environment (ambient, depth fog, glow, S… | building_root.gd:315 -> _build_environment; env built :833-876, WorldEnvironment added :8… | global render environment presentation (moonlit ambient floor, fog curve, glow threshold, Forward+ SSAO/… | none — pure global settings |

### NEEDS_SPATIAL (58)

| Authority | v1 composition | Owns | v2 blocker / note |
| --- | --- | --- | --- |
| _spawn_npc_placeholders + ResidentRoutines + ScheduleDirect… | game/scripts/building/building_root.gd:466 (call), 2106-2167 (func: 18 NPC_RESIDENTS 129-… | 18 resident actors (position, animation clips, 'resident_placeholders' group), per-resident routine loop… | Unit living-room rects per floor (placement lerp 2141-2144), corridor ring RING_X 4.38 / RING_Z 8.30, lift hall Vector2(1.9,-5.6)… |
| _spawn_props marker-driven FunctionalProp spawn system | game/scripts/building/building_root.gd:425 (call), 1248-1441 (func); layout loaded 313-31… | ~471 FunctionalProps + registries functional_props_by_floor/doors_by_floor (building_root.gd:224,230) th… | Every marker record per floor: kind/id/pos/yaw_deg/w/h/unit/room/riser/variant/zone/mount_wall/mount_along plus floor z and room … |
| _spawn_reality_affected_props -> RealityAffectedProp catalog | game/scripts/building/building_root.gd:493 (call), 2170-2238 (func: res://data/reality_af… | Seizable-object silhouettes with shared affected-state language (echo, emission, verbs), 'reality_affect… | Case-unit room rects for u/v placement, table-surface heights, absolute shared-prop positions keyed to v1 floors; all missing in … |
| _spawn_reality_controllers -> ApartmentRealityController pe… | game/scripts/building/building_root.gd:489 (call), 2241-2287 (func: one per RealityCases … | Canonical apartment-manifestation state: node transform/visibility snapshots for deterministic restore (… | Per-case unit living-room rect -> world AABB (rect + floor z + 3.0 m); v2 blockout has no per-unit rooms for the 18 case units |
| ApartmentEncroachment | building_root.gd:501-503; build(layout, floor_nodes, domestic_witnesses) | nothing durable by design (header: 'owns no case state, no save key'); sets `intensity` on each case uni… | the case unit's wall-finish quads inside the floor glTF + domestic witnesses |
| ApartmentEncroachment + dream ecology (field/margin/critter… | game/scripts/building/building_root.gd:501-503 (build(layout, floor_nodes, domestic_witne… | Presentation only (no case state, no save key): per-case wall-finish encroachment intensity as a state o… | Baked per-storey wall-finish quads under SurfacePass (v2 blockout has no baked finish surfaces), case-unit rects to clip the cree… |
| ApartmentRealityController spawn (_spawn_reality_controller… | building_root.gd:489, func :2241-2287; setup(case_id, unit, bounds_min, bounds_max) per R… | per-case in-apartment distortion authority over registered nodes; bounds-gated; reads case state (case s… | unit living-room rects (bounds derived from rect + floor z + 3.0 m) |
| ArcadeRow | building_root.gd:407-410; install(layout, floor_nodes) | live screens, marquees and titles hung on the cabinet carcasses; presentation/minigame surface | asm_arcade_cab carcasses merged into the floor mesh + layout entries; Passage-resident — none of it exists in v2 |
| Art passes (character memory art, character wall art, hallw… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation-only wall/landing artworks instantiated from res://data/character_memory_art.json, characte… | v1 layout schema layout["floors"]->rooms->walls resolved through _legal_art_spot (building_root.gd:2329), layout["stairs"][0]["we… |
| AtmosphericDecalPass (wear + uncanny evidence) | building_root.gd:382-384; build(layout, floor_nodes) | deterministic surface decal placement, including the nested-rect wall law; rejected-mark reporting; pres… | v1 room rects (explicitly handles the nested bathroom-rect gotcha) and wall faces |
| Atrium atmosphere shaft (AtriumShaft additive prism) | building_root.gd:882 (call), func _build_atrium_atmosphere :1137-1162+ | one unshaded additive BoxMesh light-shaft presentation in the stair court's eye; no state | hardcoded to v1 atrium geometry: 2.92 m square eye, skylight underside at y 21.35, basement floor -2.6; needs the v2 atrium/stair… |
| BroadcastDirector (the station) | building_root.gd:400-403; build(layout, floor_nodes) | one shared video decode + programme state (per-clip shuffle, live cards, per-set power, poltergeist hand… | television set meshes baked in the floor glTF, located via layout — v2 has neither TVs nor those markers |
| CaseDoorProp (marker kind 'case_door') | game/scripts/building/building_root.gd:81 (PROP_SCRIPTS), spawned via 1287-1292; CallInte… | revealed flag (hidden until a case reveal beat), rattle presentation; a door in a corridor wall the plan… | A specific corridor wall spot on the case unit's storey (marker pos/yaw); v2 blockout lacks the case floors' corridor walls and a… |
| Character memory art (_spawn_character_memory_art) | building_root.gd:509 -> _spawn_character_art_catalog('res://data/character_memory_art.jso… | catalog-driven CharacterMemoryArt pieces (atlas quads) in character spaces; presentation | WallArtLaw legal spots over v1 room rects/walls |
| Character wall art (_spawn_character_wall_art) | building_root.gd:510 -> catalog 'res://data/character_wall_art.json' at :2296-2300 | character-specific wall artworks (collection 'character_wall_art'); presentation | same WallArtLaw / room-rect dependency |
| CommensalDirector (roaches/commensal life) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Commensal creature behavior/presentation; reads durable RealityState.data dreams_had and dream_seed (:53… | v1 layout floors + kitchen marker positions in Blender space, street hoarding node, meta.levels heights; also depends on switch_s… |
| domestic_witnesses.bind_director(sanity, player) (witness c… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Witness clock props and anomaly manifestations per unit (physical + presentation); witness observations … | Placement from v1 layout floors->rooms living-room resolution with b2g coordinates; missing in v2: unit living-room geometry/anch… |
| DomesticWitnessSystem | game/scripts/building/building_root.gd:494-498 (bind_vantry_network then build(layout, fl… | clocks/placements/anomalies registries, PossessedDomesticProp home_relays, routing of each sanity intrus… | Unit living rooms per profile, WallArtLaw.legal_spot walls and furniture surfaces (_nearest_surface) on each storey; consumer San… |
| DoorProp / LandmarkEntryDoor fleet (marker kind 'door') | game/scripts/building/building_root.gd:1266-1286 (spawn branch; F01_DOOR_06 landmark spec… | Leaf open/closed state, swing direction, door_kind/unit/finish_variant, per-floor visibility registry me… | Door markers (pos, yaw_deg, w, h, leaf, swing, subtype, unit, zone) at real wall openings in every storey; v2 blockout has no doo… |
| ExteriorDetailPass | building_root.gd:444-447; build(layout, floor_nodes['F01']), configure_street_lights(self) | exterior finish MultiMeshes, damage cards, curbside car, street lights; presentation + audited street-en… | F01 facade glTF + street/site geometry + layout exterior data — v2 has NO street |
| FoundArtPass | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | repurposed source art as framed pieces, loose print matter, rooftop billboard (shared 2x2 atlases); pres… | layout.get("floors") iteration (found_art_pass.gd:17), per-floor floor_nodes keys, authored b2g spec positions. Missing in v2: fl… |
| Front entry details (_build_front_entry_details: BuildingEn… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | facade/sidewalk dressing welded to v1 Blender coordinates (marquee origin at facade face, vault lights m… | Hard-coded b2g coordinates welded to floor_01.gltf facade assembly (F01_DOOR_06 at Blender y=-9.795, :2351-2374) and gen_layout v… |
| FurnitureInteractionPass (baked-furniture E mechanisms) | game/scripts/building/building_root.gd:429-432 (build(layout, floor_nodes)); class game/s… | BakedFurnitureInteraction owners: the moving/interactable mechanism state over furniture whose bodies st… | Layout furniture records (at/yaw/z0) AND the baked furniture meshes they overlay — the v2 blockout has neither the records nor an… |
| FurnitureInteractions (furniture_interaction_pass) | building_root.gd:429-432; build(layout, floor_nodes) | individually generated mechanisms (E-owner moving parts) overlaid on furniture whose static bodies are m… | furniture records in layout + the merged glTF bodies they overlay |
| Hallway art (_spawn_hallway_art) | building_root.gd:511, func :2303-2347; expected_count audit | hallway CharacterMemoryArt pieces with placement audit; presentation | _legal_art_spot over floor/room data (wall, along, height) |
| Harukiya directors (HarukiyaStateDirector bar hours + Haruk… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Bar OPEN/AFTER-HOURS/CLOSED state (presentation+behavior) and bar interactables (pictures, barrels, pool… | gen_layout-authored bar lights by node path and hard-coded Blender-space bar coordinates. Missing in v2: the Harukiya bar volume,… |
| HeightmapPass | building_root.gd:366-368; build(floor_nodes) | re-attached height maps on floor glTF materials (presentation only) | the floor glTF meshes and their shipped StandardMaterial3D — v2 has neither |
| MaintenanceHeadquarters | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Physical HQ props (pivot board, tokens, interaction area, visuals) in the F01 office; no RealityState.da… | All internals at authored b2g coordinates around x=-11.76..-13.40 inside the v1 F01 maintenance office; parented into floor_nodes… |
| MaintenanceShopService | building_root.gd:352-356; setup(maintenance_inventory, work_orders), build_counters(layou… | shop stock provenance (data/shop_inventory.json) and the maintenance acquisition transaction; counters d… | build_counters resolves each stock record's counter_anchor_id against layout furniture records (maintenance_shop_service.gd:107-1… |
| Marker prop pipeline (_spawn_props: DeskZone, doors, all Fu… | building_root.gd:425, func :1248-1441; binds clocks to work_orders (:1316), radiators to … | every marker-spawned interactive: DeskZone, DoorProp/LandmarkEntryDoor, lights, lamps, clocks, taps/show… | the entire v1 floors[].markers schema (kind/pos/yaw/unit/variant/...) plus WallArtLaw for clock spots — the single largest missin… |
| mina_manifestation.bind_wake(core_loop) (caption layer wake… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Binding only — connects the waking loop to MinaCaptionManifestation presentation | Blocked on MinaCaptionManifestation itself (see its row): authored b2g caption positions plus layout["floors"] schema absent in v2 |
| MinaCaptionManifestation | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | first-case caption scaffold proving stabilization vs recurrence as separate persistent states; captions … | Authored b2g caption positions and v1 layout["floors"] traversal. v2 layout has no "floors" key; missing: caption anchor position… |
| MoonFill | game/scripts/building/building_root.gd:484-488 (build(layout, player), _root backref for … | Presentation only: one OmniLight3D that follows the player and exists only in facade-window rooms; day-n… | Room rects tested against the v1 facade envelope (rect within wall thickness of ±13.65/±9.65), B1 excluded; v2 blockout has a dif… |
| NPC placeholders (_spawn_npc_placeholders: AnimatedResident… | building_root.gd:466, func :2106-2167; placed in unit living rooms from room rects | the 18 resident bodies (rigged glTF or sprite fallback) in the resident_placeholders group | unit living-room rects from v1 layout + resident glTF/sprite assets; v2 has NO NPC bodies by scope |
| OrganismIncidents (LF-3) | game/scripts/building/building_root.gd:506-508 (build(layout, apartment_encroachment, wor… | Survey, incident ledger in RealityState.data.organism_incidents (the one named RealityState subtree in t… | flats table (unit rect + floor per resident) from layout, living-field voxel positions from ApartmentEncroachment, and a Function… |
| OrisonDetailPass (lived-in clutter) | building_root.gd:379-381; build(layout, floor_nodes) | two MultiMeshes per floor of primitive clutter/infrastructure + one narrative-paper quad per apartment (… | v1 room rects and unit data from layout + floor parents; placement derives from room geometry |
| OrisonDoorGlow | building_root.gd:394-397; build(layout, window_glow) | corridor-side under-door light bars + leaf-outline hairlines, consistent with WindowGlow's awake set; pr… | v1 door markers (positions/widths) and WindowGlow; v2's 21 blockout doors use a different schema and WindowGlow is absent |
| OrisonRailingPolish | building_root.gd:385-387; build(layout) | decorative overlay on the exported stair balustrade (newel silhouettes, brass collars, rake inlay); pres… | v1 stairs data (rakes) + the exported balustrade meshes |
| OrisonWindowGlow | building_root.gd:388-391; build(layout); n_lit returned | emissive night interiors seen from the street; the awake-rooms set that DoorGlow queries; presentation s… | facade window geometry from layout + an exterior/street vantage to be seen from — v2 has no street and no facade |
| Passage geometry index (_index_passage_geometry) | building_root.gd:333, func :1447-1457+ | passage_interior_nodes list of F01 glTF '_retail_shop_' GeometryInstance3D batches, consumed by the pass… | F01 glTF with per-shop named batches (Blender batch identity); no equivalent in v2 blockout, which has no passage at all |
| Passage light pass (5 ungoverned shadowless lights) | building_root.gd:460, func :1991-2062; tuned via day_night_director.resolved_profile() (:… | crossing shaft, lunette key (the sanctioned always-lit abnormality), lantern drum + two well omnis; pres… | hardcoded Passage coordinates (x 14.0, z 51.6/64.61) and the lantern/lunette geometry they light |
| PassageFinish (passage_finish_pass) + PassageHoursDirector | building_root.gd:451-459; build(layout); geometry_nodes -> passage_shell_nodes, pushcarts… | the Passage's movable middle layer (handcarts with runtime physics, wear) and the hours authority (open/… | the ruled Passage shell + eleven shop interiors in the glTF; v2 has no Passage space |
| PassageLightTick (2 s timer polling day/night into passage … | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation: passage light color/energy tracking the day profile; no durable state | Requires the PassageLightPass node set built for the v1 arcade and day_night_director.resolved_profile(); guard at :2068 no-ops w… |
| PlanarMirrorRenderer (bathroom cabinet reflected view) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation: one shared reflected viewport bound to mirror-tagged surfaces; no durable state | Requires MeshInstance geometry in group "planar_mirror_surface" (v1 bathroom cabinet glass). Missing in v2: any mirror-tagged sur… |
| PortalRuleDisplay (portal rules wall display) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Presentation of the durable portal_rules list; reads RealityState.data["portal_rules"], does not own wri… | Root-authored position on the east wall of F04 west storage in v1 space. Missing in v2: an F04 storage wall anchor (no such ancho… |
| RealityAffectedProp catalog (_spawn_reality_affected_props) | building_root.gd:493, func :2170-2238; data/reality_affected_props.json; registers cluste… | the case-cluster and shared reality-affected props (id/name/kind per case); placement audit; prop distor… | unit living-room rects (u/v lerp placement) + shared absolute positions in v1 coordinates |
| ResidentRoutines | building_root.gd:469-473; build(layout, get_nodes_in_group('resident_placeholders')) | per-resident daily loops (home, pacing, errand, elsewhere); transient schedule state | layout rooms/routes + the placeholder bodies from the previous row |
| Room0 (hidden pocket room) + F04_B_DOOR_ANOMALY entry wiring | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Physical pocket space, its hum/seam presentation, occupant + return-position state; sustained by Conduct… | Room itself is geometry-free (fixed origin far above any shell). Entry requires the manifested door anomaly in unit 4B, placed fr… |
| Sanity stack: FourthWallLayer + Intrusions + SanityDirector… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Hidden pressure model, poltergeist address firing, meta fourth-wall effects (contractually touch nothing… | SanityDirector._unit_at requires group "apartment_reality_controllers" per-unit zone volumes (sanity_director.gd:232-237) — absen… |
| ScheduleDirector (resident archetype timetables on the day/… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Behavioral schedule state driving ResidentRoutines; no RealityState.data subtree seen | Hard dependency on ResidentRoutines (v1-only, composed before :509) plus v1 layout meta.levels and floors for visit targets. Miss… |
| Shop sign hours binding | building_root.gd:463-465; ShopSignProp.bind_hours_director(passage_finish.hours_director) | nothing — read-only presenters of hours state | ShopSignProps (marker pipeline) + passage_finish.hours_director |
| Stair landing art (_spawn_landing_art) | building_root.gd:512, func :1943-1972 | stair-landing pieces hung centred on the well; presentation | layout stairs[0].well north wall + landing z per piece — no stairs data in v2 layout |
| StreetTraffic | game/scripts/building/building_root.gd:481-483 (new/add/build), bind_player 622; CoreLoop… | 14-vehicle MultiMesh stream (11 KINDS incl. real-mesh piano truck), headlight-pool and lamp MultiMeshes,… | The authored STREET site: carriageway lanes y -17.0/-21.8, kerb band z 14.55..24.10, spawn /x/<=52, south shelter x -12.6..-8.2, … |
| SurfacePass (MX-4 layered orison_surface) | building_root.gd:376-377; apply(floor_nodes) | material substitution on masonry/wall-finish/floor surface classes: same maps under the layered shader (… | the named surface classes inside the floor glTF exports |
| SwitchSystem | game/scripts/building/building_root.gd:476-479; class game/scripts/building/switch_system… | Per-room circuit power verdict (authoritative; fixtures' powered flags), 202 interactable switch plates … | Furniture switch records (at/yaw/z0/serves_room) beside doorways, room polygons for the hand-span _room_served probe, and the mar… |
| WallArtLaw reservation registry (clear + the placement law) | building_root.gd:424 (WallArtLaw.clear_reservations(), ordered before props and witnesses… | static registry of claimed wall hooks; the one legality law all art/clock placers query | legal_spot() requires v1 floor/room rects, door/window aware wall runs, wainscot data — none present in v2 |
| WayfindingSignagePass | game/scripts/building/building_root.gd:490-492 (build(self)); class game/scripts/building… | Presentation: apartment number plates, floor directories, fire signs, spine plates, entry bell audio/but… | Live DoorProp nodes in the tree (v2 has none), wall faces beside each door, the LEVELS storey-z table (v1 storey heights), lobby … |
| Weather triple: WeatherFX + LiveWeatherService + PeriodReal… | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Rain/exposure presentation, window reflection glares, live open-meteo conditions feed (live_weather_serv… | WeatherFX: exposure/cover callables hard-code the v1 street/passage envelope (building_root.gd:2721-2748) and build_reflections i… |

### DELIBERATELY_V1 (5)

| Authority | v1 composition | Owns | v2 blocker / note |
| --- | --- | --- | --- |
| Floor glTF scene instantiation (FLOOR_SCENES -> floor_nodes) | building_root.gd:316-324 | the per-floor visual/collision meshes and the floor_nodes dictionary every pass parents into | the v1 floor glTF exports themselves — exactly what v2 does not ship |
| FloorCoveragePass (reference implementation, not applied) | building_root.gd:332 (instantiated only; comment :325-331 says MX-4 folded coverage into … | nothing at runtime — kept as reference implementation | n/a (never applied) |
| OrisonElevator + F01 landing interlock (+resident bindings) | C:/PleaseRemainOnTheLine/.claude/worktrees/v2-composition-census/game/scripts/building/bu… | Physical lift car/door state and ride authority; interlock safety contract with the F01 door | layout["elevator"] shaft data (absent from blockout layout), F01LandingInterlock prop (v1 lobby detail, not mounted in v2), Resid… |
| v1 layout data source (res://data/building_layout.json) | building_root.gd:313-314 (FileAccess.open + JSON.parse_string into `layout`) | the authoritative marker/room/floor dictionary every v1 pass consumes; schema: floors[].markers/rooms/re… | IS the spatial dependency: v1 marker schema (floors[], markers[], rooms[].rect, stairs[].well) that v2 does not have — v2 layout … |
| Zone gates: _index_passage_geometry / _index_late_f01_geome… | game/scripts/building/building_root.gd:333 (early passage index), 812-813 (late + street … | PASSAGE/STREET render-zone membership lists (passage_interior/shell/foreign/late/shared nodes, foreign l… | v1 glTF export identity: batch name tokens '_retail_shop_', '_retail_passage_shell_', '_retail_passage_proxy_', ENVELOPE_BATCHES … |
