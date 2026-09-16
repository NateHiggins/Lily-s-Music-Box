# Orison v2 interim management evaluation — 2026-09-16

Evidence class: **EVALUATION RECORD — INERT — PROMOTES NOTHING**

Written by interim management two days after the M11 merge. Identifiers are
bold, never backticked. Verified inert with `--evidence-impact` before commit.

## 1. The governance fact that reorders everything

On **2026-09-04** the owner issued a new mandate appointing **Astra** the
executive production authority for the whole game, with instructions to turn
the repository into the canonical finished incarnation. That mandate is
recorded by hash in **design/astra/AUTHORITY_HIERARCHY.md**, which ranks the
latest owner ruling first and the completeness canon fifth.

Interim management was dispatched on **2026-09-13** and merged the M11 chain
on **2026-09-14** under an explicit owner authorization. Both are true at
once, and the result is two lines each with a claim to be canonical:

| Line | Tip | Base | Carries |
|---|---|---|---|
| **main** | **6b5dc29** | — | the accepted M11 boundary, M11D, and the real owner-first floor_01 cut |
| **codex/astra-canonical-20260904** | **3d615be** | **a9e455b** (M11B) | 100 commits: F03 circulation, F05/F06 programs, upper-apartment furnishing, lighting, equipment, plus its own independent floor_01 cut |

The astra mandate's own ordered dependency (AUTH-04) is: accepted M11
boundary, real F01 owner-first cut, exterior route, F03 vertical proof, then
structural breadth and case-dependent apartments. **main** now holds the
first two; **astra** has built parts of the fourth and fifth on a base that
predates both. The mandate calls the M11C2 work "quarantined candidate work"
— correct on 2026-09-04, when that branch was dirty and every table read
PENDING. It was closed, corrected for checkout-invariant hashing, verified in
a fresh worktree and merged on 2026-09-14. That judgment is now stale.

**Ruling: one canonical line, and it is main.** Not because main is better
work, but because it is the line the owner authorized a merge into, it
carries the accepted boundary the astra mandate itself puts first, and its
floor_01 cut is the one with a closed checkpoint, a hash-bound registry, a
retained byte-identical rollback and a human packet awaiting review. Astra
remains the executive production authority over *content*; the integration
target is main. Astra reconciles onto **6b5dc29** rather than main adopting
a second cut.

## 2. What astra found that management had wrong

Astra's commit **fc359a6** (2026-09-04, "Require executed source-bound
runtime evidence instead of capture captions") hardened the completeness
audit to **TOOL_VERSION 2**. Management reproduced its effect by an isolation
test: astra's tool, run against **main's unmodified tree**, with the receipt
file byte-identical on both lines.

| Scope | main's tool | astra's tool, same tree |
|---|---:|---:|
| FIRST_SLICE_TECHNICAL | 0 | **7** |
| GOLDEN_SHIFT_V2 | 1 | **8** |
| FULL_BUILDING_STRUCTURAL | 84 | 84 |
| FULL_BUILDING_RUNTIME | 45 | **52** |
| PRODUCTION_CUTOVER | 100 | **107** |
| V1_RETIREMENT | 102 | **109** |

The cause is one file: **m08f_runtime_composition_01/runtime_authority_receipt.json**
is **schema_version 1**, carrying only `production_runtime`, `records` and
`selector`. It has no execution result, no executing source, no input
binding. It proves that frames were captured. It was being read as proof that
a runtime contract executed. On that basis six identifiers — the four F01
ritual stations, **B1_BOILER_01** and **F02_B_RADIATOR_01** — plus
**job.lena_radiator_round_2b** were RUNTIME_PROVEN, and FIRST_SLICE_TECHNICAL
was reported clear.

**The first slice was never technically clear.** It was declared clear on
2026-08-28 and every dry run, bounded landing and dispatch since has quoted
the zero, this management record included. The honest count is 7.

Astra's instrument is sound and only tightens: it requires
`evidence_kind: "runtime_contract"`, a completed execution with integer exit
code 0 and no timeout, a real `game/tests/*.gd` source whose SHA-256 still
matches the tree, and a `runtime_inputs_sha256` digest over every runtime
script, scene, resource and data file so that adding or removing an input
invalidates the proof. It ships roughly forty red/green fixture pairs — one
demonstrated red per rejection reason — and its suite is 105 tests against
main's 99. This is the failure class the genetic memory names: one signal
standing for two facts, and a green nobody had proved could go red.

**Adopted here.** This commit takes the tool and its test verbatim from
fc359a6 and corrects the ledger guide, which still described the old rule and
so would have left the program and its canon disagreeing. Nothing else on the
branch changes. No baseline, exception or suppression is added, and no
requirement is promoted. Measured on main's tree after adoption: completeness
exit 2 at **7 / 8 / 84 / 52 / 107 / 109**, its suite 105/105, all 22 tool
suites green, spatial 0, systemic 0, period 0, reader 1 unchanged.

**Nobody has re-earned the seven rows.** No schema-2 runtime contract receipt
exists anywhere in the repository, on either line. fc359a6 also modified
**game/tests/orison_v2_m08f_runtime_shot.gd**, which is where such a receipt
would come from; that harness is deliberately not adopted here, because
management cannot run the Godot lane to prove it and will not land an
unexercised harness.

## 3. State of the astra lane

Real progress, and it is the largest v2 geometry advance to date: 24
requirement rows advanced, including **floor.F05** and **floor.F06** ABSENT
to PROGRAMMED, all four **circ.F05.\*** and **circ.F06.\*** rows,
**circ.F03.service_route**, and units **3A**, **3B**, **4A** upward. 54 new
requirement rows appeared — the new units' domestic minimums — which is the
documented C1 behaviour of the count rising before it falls, not a
regression.

Nine rows read as regressed against main. Two, **unit.2B.entry** and
**f01.watch_station**, are only the absence of the M11D document from
astra's base and resolve on reconciliation. The other seven are the
first-slice truth above, which astra is right about.

Four things block the lane from merging, all real and none of them fatal:

1. **Twenty-six file conflicts against main**, including all seventeen cell
   GLTFs, **building_root.gd**, **floor01_cell_registry.gd** and
   **.gitattributes**. Astra authored its own floor_01 cut independently and
   has no **floor01_geometry_configuration.gd**, so it also has no rollback
   mode. Under the ruling in section 1 this is resolved by adopting main's
   cut, not by merging two.
2. **Spatial dependency audit fails: 1,347 new unclassified records, 324
   classification changes, exit 5** (a preserved record left source). The
   unclassified are genuine new authored ids — **bath_details.json** rows
   such as the per-unit water-closet identifiers — never absorbed by
   `--update-manifest`. The floor playbook requires that in the same commit
   as the geometry; 100 commits of geometry landed without it.
3. **Five new legacy "[E]" prompt carriers** in the new props
   (**orison_v2_prep_cabinet.gd**, **orison_v2_radio_prop.gd**,
   **orison_v2_water_valve.gd**). The same T2 violation management had fixed
   once during the M11C2 close. The 186-entry baseline is frozen; new props
   must use the ruled carrier-free form.
4. **Reader gate 1,448 blocking, up from 1,302.** Roughly 146 new unread
   authored fields — new furniture, equipment and detail data with no
   production consumer. The dominant defect class, arriving with the
   furniture.

Astra's own tool suites fail in its tree for reasons 2 and 3, not because its
instruments are wrong. Its worktree also holds 340 uncommitted paths, most of
them an untracked evidence tree, with in-flight upper-equipment work last
touched **2026-09-15 09:22**.

## 4. Where v2 actually stands

Structural is the honest measure of the building, and it is unmoved by the
receipt question: **84 blockers**, 47 ABSENT, 35 PROGRAMMED, 2 SHELL_ONLY,
distributed as units 32, circulation 21, floors 7, services 7, regions 6, B1
5, F01 4, roof 2. Astra's unmerged work moves 24 of those to PROGRAMMED and
adds 54 new minimums beneath them; landing it will raise the visible count
before a checkpoint lowers it.

Ground floor is cut into seventeen independently addressable cells with a
rollback monolith. The first exterior cell, the bodega bucket and the F02/F04
service openings are human-accepted. Nothing outside the building exists as
scored scope except **region.street** and **region.shops** at PROGRAMMED; the
construction seam, arcade portal, throat and hall are all ABSENT.

Known red and owned: GoldenLoopTest two objective checks, waiting on the
beat-4 part-source decision. ServiceWireResponseTest reads a property removed
on 2026-08-27 and hangs to a timeout. The stale **B1_PUBLIC_LANDING_E**
identifier needs the identity universe taught to read the layout's platforms
array. All three were dispatched as M11E-HYGIENE and none has started.

## 5. Dispatch queue

Serial, each reporting before the next starts, in the astra mandate's own
dependency order.

| # | Task | Owner | Deliverable |
|---|---|---|---|
| 1 | **V2-LEDGER-TRUTH** (this branch) | management, done | hardened tool adopted, guide corrected, board honest at 7/8/84/52/107/109 |
| 2 | **ASTRA-RECONCILE-1** | astra | rebase onto **6b5dc29**, adopt main's cut, absorb manifest drift, fix the five carriers, triage the 146 unread fields |
| 3 | **V2-FIRST-SLICE-REEARN** | astra or developer | one real schema-2 runtime contract receipt; 7 first-slice blockers to 0 honestly |
| 4 | **M11E-HYGIENE** | developer | platforms array in the identity universe; ServiceWireResponseTest repaired |
| 5 | **M12A-STREET-THRESHOLD** | developer | apron, vestibule, lobby on +z; the expansion template |
| 6 | **M12B-F03-SERVICE-HALL** | developer | F03 lateral service hall as data; riser choke resolved or re-scoped |

Task 2 before task 3 because a receipt binds `runtime_inputs_sha256` over
every runtime input: earn it before reconciliation and the rebase invalidates
it. That is the instrument working as designed.

## 6. Decisions for the owner

1. **Confirm the one-canonical-line ruling** in section 1: astra reconciles
   onto main. If the owner instead wants astra's line to become main, say so
   and management will sequence the reverse, which costs the closed M11C2
   checkpoint, the rollback mode and the hash-bound registry.
2. **Merge this branch** to make the board honest. Recommended: yes. It
   moves the numbers against us and is the only way they stop being wrong.
3. **Beat-4 part source**, bodega or hardware_paint. Still the only thing
   between GoldenLoopTest and green.
4. **Human review of the M11C2 seam packet**, still pending on main.
5. Whether **light_provenance** prose reaches a player-visible surface.

## 7. Correction to the management record

The 2026-09-13 dispatch and every report since quoted FIRST_SLICE_TECHNICAL
as 0 and GOLDEN_SHIFT_V2 as 1. Both were wrong, in the flattering direction,
and management did not check the receipt behind them. The error predates this
management and was not created by it, but it was repeated by it four times.
Astra caught it. The corrected figures are in section 2.
