# Orison v2 rebuild — Sept 3 handoff pack

Audience: the returning spatial-construction owner (codex/ChatGPT).
Prepared 2026-08-28 by program management. Authoritative state:
`origin/main` at `66355da` ("Remove counterfeit consequences from Open
Shift").

## What landed while you were away

- **Open Shift is on main**, ethos-corrected: `NpcObservationLedger` is
  the only NPC-knowledge writer (beliefs earned via acoustic
  audibility / in-home sight / direct inspection, with provenance);
  `PorterActor` performs compensation as a real actor (intent → board
  round → transit → access check → inspection → shutoff through the
  mechanism; turned away if 2B is unreachable); packing custody is one
  `MaintenanceInventory` record (`radiator_packing_2b`). Your radiator
  model, its seven surfaces and all four dispositions are preserved;
  your `codex/ethos-open-shift` branch is untouched for your own
  reconciliation. See `design/ETHOS_OPEN_SHIFT_2_AUTHORITY_CHECKPOINT_
  2026-08-28.md` and the audit delta beside it.
- **A third gate now exists**: `tools/audit_systemic_situation_
  authority.py` (+49-entry baseline). It fails on coordinator-authored
  NPC knowledge, timers impersonating actors, shadow custody,
  objective UI, wall-clock world mutation, moral scores. Guide:
  `design/SYSTEMIC_SITUATION_AUTHORITY_AUDIT_GUIDE.md`.
- **M10 runway is verified** (`design/ORISON_V2_M10_RUNWAY_REPORT_
  2026-08-28.md`): every automatable precondition of the eleven-beat
  golden shift passes under explicit v2; the human run is the sole
  golden-shift blocker — except it will honestly stop at **beat 4**,
  which is yours (below).

## Live scope counts (frozen at 66355da; regenerate, don't quote)

FIRST_SLICE_TECHNICAL 0 · GOLDEN_SHIFT_V2 1 (the eleven beats) ·
FULL_BUILDING_STRUCTURAL 79 · FULL_BUILDING_RUNTIME 45 ·
**PRODUCTION_CUTOVER 95** · V1_RETIREMENT 97.
`python tools/audit_orison_v2_completeness.py --blockers-for
full-building-structural` enumerates your exact spatial list.

## Your spatial work order (M11/M12, in recommended order)

1. **Part-source space first (unblocks the golden shift's beat 4).**
   v2 composes no shop: the K2 "fetch it" beat has no part source.
   The program's answer is the maintenance shop/storage room (B1 or
   F01 split allowed — see the program's service table). A modest,
   entered, programmed space with a counter anchor lets runtime
   composition (our lane) mount the existing shop service. Until it
   exists, every human golden-shift run stops at beat 4.
2. **Declared service-hall openings** — **F02_SERVICE_HALL** and
   **F04_SERVICE_HALL** have no door/opening records (traversal proved,
   schema silent). The completeness ledger holds floors F02/F04 at
   SHELL_ONLY grain over this.
3. **Structural floors**: F03 full program, F05, F06, B1 full program
   (coal, electrical, laundry, resident storage — boiler route exists),
   ROOF (bulkhead, tank/machinery). Plus **electrical and fire-service
   riser vocabulary** — no v2 records of either class exist.
4. **Apartments by case dependency (M12)**: every occupied unit needs
   its six domestic minimums satisfied by each space's own
   `purpose`/`class` fields (entry, living, cooking, sanitary, sleep,
   storage — the ledger matches purpose text, never id tokens).
   Sealed units 2D/3C/5D/6D need only public thresholds.
5. F01 staff restroom is absent from the v2 program — schedule it or
   mark it deliberately deferred.
6. **Cheapest blocker on the board:** unit.2B.entry blocks STRUCTURAL
   only because no admitted checkpoint ever names **F02_B_VESTIBULE**.
   The vestibule is built, walked and owner-accepted; the ledger just
   has no proof naming it. Backtick that id in a checkpoint and the
   blocker clears. Sweep your other accepted-but-unnamed spaces the
   same way — **F01_WATCH** is the other known one. Neither needs a
   single line of geometry.

## The blocker count goes UP when you build correctly — expect it

A floor-landing rehearsal (see ORISON_V2_FLOOR_LANDING_REHEARSAL_
CHECKPOINT_2026-08-29.md) measured the real economics on a synthetic
F05 with two apartments: STRUCTURAL went **80 → 92** on building the
floor, then **92 → 74** once a properly-named checkpoint backticked
the ids. The rise is not a regression — apartments cannot owe domestic
minimums until they exist, so twelve new obligations appear the moment
the units do. Build, then checkpoint, then read the number. Judging a
floor by the count before its checkpoint lands will always look like
going backwards.

## Purpose strings are matched by words, not ids — use the vocabulary

Domestic minimums are satisfied by each space's own `purpose` text.
The matcher looks for meaning-words, never id tokens, so name the
activity plainly: **privacy/distribution** (entry), **living / rest /
meeting / conversation**, **cooking**, **sanitary** (or class `wet`),
**sleep**, **storage**. Decorated phrasing is fine — the live 2B
vestibule reads "2B privacy, coat storage and distribution" — but be
aware that predicate is being hardened right now precisely because
that comma once produced a false blocker on a built, accepted room.
If a room you built reports its function ABSENT, check the purpose
wording before assuming the geometry is wrong, and tell management: a
false blocker is a tooling defect, never something to work around by
renaming a room.

## Identities you must preserve

`OrisonV2AnchorAdapter.REQUIRED` (game/scripts/building/
orison_v2_anchor_adapter.gd) and the full table in
`design/ORISON_REBUILD_MIGRATION_CONTRACT_2026-08-28.md` remain
binding, plus the M08E ritual/2B/B1 identities and — new —
**F02_B_RADIATOR_01**'s acoustic node (the observation ledger derives
who hears the riser from `AcousticGraphData.audibility`; the heating
riser reaches **3B**, and `omar_bell` is now the canonical hearing
neighbor). `BuildingRootSelector.DEFAULT_ID` stays `"v1"`; M09 remains
unauthorized until the PRODUCTION_CUTOVER scope is clean and the owner
signs.

## Gates — run after every commit, leave clean or document honestly

```
python tools/audit_orison_v2_completeness.py
python tools/audit_orison_spatial_dependencies.py
python tools/audit_systemic_situation_authority.py
python tools/tests/test_orison_v2_completeness.py
python tools/tests/test_orison_spatial_dependencies.py
python tools/tests/test_systemic_situation_authority.py
```

**Document naming decides what can prove anything — read this before
writing any design doc.** The completeness tool once read every
`design/ORISON_V2_*.md` as evidence and promoted any space whose id it
found backticked, so reports satisfied the requirements they merely
described (this pack did it to circ.F02.service_route; the M08E
dimensioned schedule did it to f01.watch_station and
service.heat_stack). Intake is now an explicit allowlist on the
**filename**: CHECKPOINT, GRAYBOX, ACCEPTANCE, RECEIPT, VERTICAL_CORE,
SCHEMA_GENERATOR. Consequences for you, both directions:

- A report, census, schedule, audit or handoff is inert. Backtick
  freely; it proves nothing.
- **A checkpoint that does not carry a marker in its name proves
  nothing either.** If you name your M11 floor proof
  `..._M11_FLOORS_REPORT.md`, the ledger will not credit the work.
  Name proofs `..._CHECKPOINT.md` / `..._ACCEPTANCE.md`.
- **Backtick the exact space and anchor ids you actually proved** in
  those checkpoints — that is the only thing that promotes them.
  f01.watch_station currently blocks STRUCTURAL precisely because the
  real M08E spatial-owners checkpoint never names F01_WATCH, even
  though the station was built and accepted.
- Before committing any new design file, check what it would do:
  `python tools/audit_orison_v2_completeness.py --evidence-impact <path>`
  (exit 0 inert, 1 promoting).

**Runner truth notice:** before 2026-08-28, `tools/run_godot_serial.ps1`
never propagated a real exit code (a PowerShell 5.1 `Start-Process`
quirk returned null → 0 for every suite, always). It is fixed and now
throws on a null exit — but treat any HISTORICAL "exit 0" claim made
through the runner as vacuous; printed PASS/FAIL lines were the real
signal. Trust exit codes only from the fixed runner or direct Godot
invocations.

Spatial deltas update `tools/orison_spatial_dependency_manifest.json`
deliberately in the same commit (never to silence drift); the ethos
baseline accepts no new suppressions without written justification.
The completeness canon tables (unit programs, floor programs, service
systems) live at the top of `tools/audit_orison_v2_completeness.py` —
if you change the program, change the canon in the same commit.

## Coordination

Claude dev agents own runtime composition, tests, gates and debt; they
will not touch schema/blockouts/floor geometry/checkpoints. Known
non-blocking debts parked with owners: DreamBoundaryTest harness
(in flight), clock_prop "Hold E" (K2), pseudo-room fixture/provenance
reconciliation, M08F serial-runner exit-leak, observation-ledger
presence provider, v2 sleep-gate composition, v2 waking-residue owner,
golden-loop harness v1 hardcode. The Godot lane stays serialized —
one process, wait politely. Program manager reviews all landings;
Nate owns merges to main and every human acceptance.
