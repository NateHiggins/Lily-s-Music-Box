# Orison v2 full-rebuild completeness audit — 2026-08-28

**Task:** ADMIN-ARCH2 (amended: scope-aware readiness policy). **Method:**
deterministic read-only ledger (`tools/audit_orison_v2_completeness.py`)
over the canonical program, the v1 inventory, the committed v2 schema, the
migration contract, the spatial dependency manifest and the M03–M08E
evidence through M08F ("runtime composition", `2d1cb1d`, TECHNICAL
PASS), reconciled by ADMIN-ARCH3's chronological evidence rules.
**Verdict of the live run at `2d1cb1d`: exit 2 (BLOCKED) —
144 requirements, 7 v1 fallbacks — while `--blockers-for first-slice`
now exits 0:**

```
FIRST SLICE READY - PRODUCTION CUTOVER NOT IMPLIED.
```

Statuses: 47 ABSENT, 3 SHELL_ONLY, 38 PROGRAMMED, 21 SPATIALLY_PROVEN,
34 RUNTIME_PROVEN, 1 HUMAN_ACCEPTED. No percentage is computed,
deliberately. Regenerate exact figures with
`python tools/audit_orison_v2_completeness.py` rather than quoting this
snapshot.

**Blockers by readiness scope (live at `2d1cb1d`):**

| Readiness scope | Blockers |
| --- | ---: |
| FIRST_SLICE_TECHNICAL | **0** — M08E built, M08E-A accepted, M08F composed and proved |
| GOLDEN_SHIFT_V2 | 1 (the eleven authored beats) |
| FULL_BUILDING_STRUCTURAL | 79 |
| FULL_BUILDING_RUNTIME | 45 |
| **PRODUCTION_CUTOVER** | **95** |
| V1_RETIREMENT | 97 |

First-slice readiness is a mechanical recognition of M08F. It supports
explicit v2 development/test selection only; it is not permission to
flip the selector, and `BuildingRootSelector.DEFAULT_ID` remains `"v1"`
and untouched.

The first slice is real and proven. The building is not rebuilt. This
document states exactly the distance between those two facts — and the
policy consequence: **a proven first slice may be selected explicitly for
development and testing, but nothing short of a clean PRODUCTION_CUTOVER
scope authorizes flipping `BuildingRootSelector.DEFAULT_ID`.**

## 1. Exact current v2 coverage

**Floors (canonical 8):** F01 PROGRAMMED (arrival + service cluster +
M08E ritual station, minus staff restroom), F02 improved by M08E's 2B
spaces, F03 core-transfer only, F04 with the full 4B program; **B1 now
exists at PROGRAMMED grain** (M08E boiler route, 3 spaces — full B1
program still absent). **F05, F06, ROOF: ABSENT.**

**Units (canonical 22):** 2A and 4B PROGRAMMED with full domestic
programs; **2B PROGRAMMED since M08E** (runtime composition pending).
**The other 19 units are ABSENT**, including sixteen further
case-bearing units. Sealed units (2D/3C/5D/6D) need only thresholds —
also absent.

**v1 room representation:** of 127 v1 rooms, 15 match a v2 id exactly,
1 is aliased (`F01_OFFICE`→`F01_WATCH`), 3 subdivide into support spaces,
**108 have no v2 representation**. (This measures external content
ownership — fixture maps, art catalogs, acoustic rooms — not geometry
sanctity.)

**Semantic contracts:** all twelve `OrisonV2AnchorAdapter.REQUIRED`
identities resolve uniquely and are RUNTIME_PROVEN (doors `F01_DOOR_06`,
`F02_DOOR_02`, `F04_DOOR_03`; vantry point + monitors; `F04_B_BED` +
`F04_B_BEDSIDE_RETURN`; four lobby service anchors). Contract identities
**not** yet in v2: `B1_BOILER_01`, `F02_B_RADIATOR_01`, the four F01
ritual identities, `F02_A_MAIN` support aliases beyond the slice.

**Save/wake:** explicit v2 bedside return RUNTIME_PROVEN (two-root
matrix 24/24); the anonymous v1 `bed` fallback remains committed by
contract (TEMPORARY_V1_FALLBACK, retired only at cutover). Organism/case
save facts can reconstruct only for units with geometry — today that is
2A and 4B; every other case unit's facts reconstruct only under v1.

**Human acceptance:** exactly one durable receipt —
`ORISON_V2_M08A_HUMAN_ACCEPTANCE_2026-08-28.json`, verdict PASS, scope
"Route-readability acceptance only", every authorization flag false.
Nothing else is human-accepted. Capture receipts (F04 checkpoint, M08,
M08A packets) are capture integrity, not acceptance.

## 2. Shell-only and anchor-only findings

- `F02_LANDING`, `F04_LANDING`: deliberate open decision shells (fine).
- `F02_SERVICE_HALL`, `F04_SERVICE_HALL`: **no door or cased opening
  connects them** in the schema — service continuity above F01 is
  currently proven by traversal only, not by declared openings. Schema
  gap for the M08E/M11 owner.
- `F01_STREET_APRON`/`F01_REAR_APRON`: open review shells by design.
- No anchor-only findings in the current layout (every non-review anchor
  sits inside a programmed space) — the M08 hardening did its job.
- Stale checkpoint identifier: `B1_PUBLIC_LANDING_E` (named by the M08E
  checkpoint, absent from the current layout). The M08C/M08D mentions of
  the then-missing ritual/2B/B1 ids are curated as negative evidence —
  a mention of absence never becomes proof after the id appears.

## 3. Remaining v1 dependencies (7 flagged rows)

Five riser systems whose ROOF endpoints (and full B1 program) are not
built (reservations span full height, the plant still lives in v1) —
`absence`-kind fallbacks; the acoustic graph (550 nodes authored against
v1 geometry — adapter overrides only parity anchors) — `absence`; and
the anonymous bed fallback — `redundancy`-kind, the only fallback that
blocks nothing before V1_RETIREMENT. M08E removed the ritual/2B/B1
absence fallbacks by building their spatial owners; their runtime
composition (M08F) is what still blocks the first slice. Production boot
remains v1-default by design (`BuildingRootSelector.DEFAULT_ID = "v1"`)
— a cutover *requirement*, not a debt.

## 4. Missing service routes and program gaps

- **Electrical riser and fire-service records: no v2 vocabulary at all.**
- B1 program entirely absent: boiler, coal, electrical, laundry,
  maintenance shop, resident storage.
- ROOF program absent: bulkhead, tank/lift machinery.
- F01 staff restroom absent from the v2 program (present in the
  program authority) — owner should either schedule it or mark it
  deliberately deferred.
- Service halls above F01 lack declared lateral openings (§2).

## 5. First-slice blockers versus production-cutover blockers

**First-slice blockers: 0.** The M08D ten (rituals, 2B, B1 route,
boiler/radiator contracts, the lena service round) are closed by the
chronological evidence chain: M08E built the spatial owners
(SPATIALLY_PROVEN via its checkpoint), M08E-A's owner receipt accepted
the B1 floor / 2B unit / boiler-room spatial contract (curated
acceptance grant, spatial tier only), and M08F's composition table plus
its passing `runtime_authority_receipt.json` (15/15 PASS,
`production_runtime: true`, `selector: "v2"`) prove the six authorities
at RUNTIME_PROVEN. The M08C/M08D mentions of those ids as missing
remain visible in `evidence_conflicts` — a mention never became proof;
the proof came from the later checkpoints that actually built and
exercised the authorities. `--blockers-for first-slice` prints
"FIRST SLICE READY - PRODUCTION CUTOVER NOT IMPLIED." — and nothing
more.

**Production-cutover blockers (105 at `22df9f6`)** include every one of
those plus
every required whole-building obligation still absent or incomplete:
the four missing floors (B1/F05/F06/ROOF) and their circulation, the
twenty absent units and their domestic minimums, the sixteen further
case routes, the B1/ROOF program rows, electrical and fire risers, the
undeclared service-hall openings, acoustic re-derivation, F01
staff restroom, remaining contract identities below runtime tier,
whole-building performance stations and whole-building navigation
acceptance. Run `--blockers-for production-cutover` for the exact
enumerated list; the ledger's `blockers_by_scope` carries all six
totals. Non-blocking for production cutover is only what the program
marks deliberate (sealed interiors until a case opens them, final
decoration) — not missing geometry.

## 6. Readiness layers (do not conflate them)

| Readiness scope | Condition | Today (blockers) |
| --- | --- | --- |
| **FIRST_SLICE_TECHNICAL** | the M08D ten close (M08E spatial + M08E-A acceptance + M08F runtime composition), gates green under both roots. Supports an EXPLICIT v2 development/test selector only — never a default flip. | **READY (0)** |
| **GOLDEN_SHIFT_V2** | all eleven golden-shift beats run under explicit v2 selection with the four-row K3 evidence schema; first-shift and service-round runtime proof. Still not a production-default authorization. | BLOCKED (1) |
| **FULL_BUILDING_STRUCTURAL** | all 8 floors, circulation, all 22 units (sealed = thresholds), service rooms and vertical systems represented and spatially proven; electrical + fire vocabulary; no undeclared-entrance shells | BLOCKED (79) |
| **FULL_BUILDING_RUNTIME** | every required job, case, interaction, save, wake, resident, acoustic and service system resolves against v2; acoustic graph re-derived from v2 topology | BLOCKED (45) |
| **PRODUCTION_CUTOVER** | both full-building scopes pass; whole-building navigation/performance/human acceptance passes; one reversible selector flip is owner-authorized; v1 remains a tagged fallback | **BLOCKED (95)** |
| **V1_RETIREMENT** | no temporary v1 fallbacks anywhere; rollback window completed; explicit owner retirement authorization | BLOCKED (97) |

Final decoration/furnishing remains tracked (dimension 22) but is never a
structural gate.

**The exact production-cutover condition:**
`python tools/audit_orison_v2_completeness.py --blockers-for
production-cutover` exits 0, the whole-building navigation acceptance
receipt exists with a scope beyond route readability, and the owner signs
`authorization.production_cutover: true`. Only then may
`BuildingRootSelector.DEFAULT_ID` change — one line, one revert.

**The exact definition of "the Orison rebuild is complete":** the
unfiltered live run (`python tools/audit_orison_v2_completeness.py`)
exits 0 — no requirement blocks any readiness scope, which by
construction means: all canonical floors, units and program rows exist,
are entered, programmed and proven at their required tier; every
migration-contract identity resolves in v2; every job and case route is
unblocked; service systems reach both endpoints; whole-building
navigation carries a human-acceptance receipt whose scope exceeds route
readability; and no v1 fallback flag remains. **A first-slice or
golden-shift pass cannot make that run exit 0, cannot flip the default,
and must never be reported as "cutover ready".**

## 7. Minimum milestone sequence (evidence-ordered)

The ledger derives this queue from prerequisite structure; each item's
full scope/prereq/proof/forbidden-files contract is in the tool output.

1. **M08E — DONE** (spatial owners built and M08E-A owner-accepted).
2. **M08F — DONE** (runtime composition, TECHNICAL PASS;
   FIRST_SLICE_TECHNICAL clean — production cutover NOT implied).
3. **M10 (queue head)** — golden shift authored and human-run under EXPLICIT v2
   selection; v1 stays the production default throughout.
4. **M11** — structural floors: F03 full program, F05, F06, B1 complete,
   ROOF; electrical + fire risers; declared service-hall openings.
5. **M12** — apartments by case dependency (occupied units, transient
   4D), each with domestic minimums and room acceptance.
6. **M13** — sealed/vacant authoring (2D/3C/5D/6D thresholds, authored
   absence).
7. **M14** — service topology + acoustic graph re-derivation from v2,
   retiring adapter positional overrides.
8. **M15** — whole-building runtime consumer/save matrix under explicit
   v2 selection (every job, case, resident, wake and organism fact).
9. **M16** — whole-building performance stations and navigation
   acceptance (a receipt whose scope exceeds route readability).
10. **M09** — production cutover proposal: `DEFAULT_ID` flip only, owner
    authorization, tagged v1 fallback. May be drafted earlier as a
    dormant proposal template, but the flip requires
    `--blockers-for production-cutover` to exit 0 first.
11. **M17** — v1 fallback window: rollback period with v1 tagged and
    selectable; owner closes it explicitly.
12. **M18** — v1 retirement (fallback removal, frozen fixture, alias
    retirement) — only after the window, never on first-slice or
    golden-shift evidence.

## 8. Non-blocking debts worth naming

GPU gameplay timing (headless limitation, from pre-M09 audit); the
pre-existing dirty production layout in the main checkout (excluded from
staging by convention); shared-partition mass duplication in the
generator; F02 north court window owner decision; checkpoint evidence at
identifier granularity (unnamed support halls sit at PROGRAMMED even
where a census passed) — an honest under-claim.

## 9. Provenance and reproduction

Every ledger conclusion carries its source (v2 record, checkpoint file,
acceptance receipt, manifest record, program table citation) and the
report embeds SHA-256 of every input read. Reproduce with:

```bash
python tools/audit_orison_v2_completeness.py --markdown
```

and compare any two states with `--baseline`. Run after every milestone:

```bash
python tools/audit_orison_v2_completeness.py && python tools/audit_orison_spatial_dependencies.py && python tools/tests/test_orison_v2_completeness.py
```
