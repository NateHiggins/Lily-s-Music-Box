# V2 door-frame mitres

Evidence class: **INERT**. Source/native repairs and focused diagnostics.
No occupied-world runtime contract, human acceptance or all-V2 completion claim.

## Concise issue log

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Building door linings | View the deep head/jamb joint behind the front trim; medium | Front architraves already mitred, but production still builds three square-ended reveal boxes | Seven exact Blender stocks cover all111 openings; matching45-degree cap faces through the actual140/350mm depth | Native renders and corrected150-check imported review pass, zero script errors; occupied-world check pending |
| Closed shop back-door surrounds | Inspect the head above any of eleven represented shop back doors; medium | Source builder uses square jambs and an overlapping head | Shared three-member mitre recipe; retain clear opening, native stock, original knobs and non-interactive back-door authority | Final shared native family has628 closed stocks,23 assemblies and116 bearings; all46 imported partitions pass the focused review; installed interaction/save checks pending |
| Main entrance oak surround | Native facade contains overlapping full-height oak jambs/head; medium | Separate facade owner, not the semantic frame proxies | Native full-depth45-degree oak joints retain the taller head and stepped cap; hide the duplicate semantic lining at this owner | Native563-stock review/four renders and focused imported checks pass; installed door/access/save review pending |
| Passenger-lift landings | Profile uprights end square under a wider header; medium | Production landing-frame adapter | Native matching sixteen-corner grooved caps; retain rolled shoulders, clear aperture and140mm head; same moving-panel/interlock owners | Native render/tangents and focused imported cap/UV checks pass after measured import correction; three unscaled parts total188 triangles versus180; seven installed landing checks pending |
| Eleven exterior shop door frames | Source storefront jambs meet a deep rectangular head; medium | Source storefront construction records | Retire the exact33 fitted placeholder members; native45-degree caps and stepped feet retain the original clear apertures and shipping stock | Native review and all46 imported shared-family partitions pass; all35 retained native parts are byte-identical; installed ownership/access/save review pending |
| Bar and Bodega retained source frontage | Inspect separately authored/merged source trim; medium, audit incomplete | Three bar door surrounds remain in shared trim; Bodega header/transom needs source classification | Open; separate actual casings from continuous structural stock before repairing | No acceptance or all-door completion claim |

## Construction and cost

The plain lining uses36 triangles, the same as the three former boxes. It is
one static MultiMesh instance per opening, without per-frame work. The original
FrameLeft/FrameHead/FrameRight proxies retain their dimensions and mesh types
for existing schema and door-fitting consumers; production hides their visuals.
The repair does not change the semantic aperture or add collision owners.
This is a geometry-count observation, not a measured frame-time improvement.

**art/blender/scripts/frame_mitre_geometry.py** is the shared plain-stock
recipe. Independently closed members remain editable in the native file.
The loaded bench checks matching cap corners on both sides of the full depth,
clear width/height, metre UV charts, tangent derivatives and loaded PBR maps.
The occupied-world casing suite now requires lining coverage for every opening.

The original native shop review rejected the new coplanar head caps because
BVH overlap does not establish contact between exactly coincident faces.
The revised review independently measures opposing four-corner diagonal cap
faces, within the original20-micrometre native tolerance; no stock-name waiver
or larger contact tolerance was introduced. Both reviews are retained.

First imported lining review:151 checks, one UV failure. Its worst complete
frame edge excess was51.23micrometres against the existing50-micrometre bound.
The narrow import policy now disables mesh compression for this asset; the
original failure remains under **art/reviews/v2_door_mitres_20261024**.
The run also exposed compile errors in the separate NPC routine draft, so its
wrapper receipt cannot establish successful runtime qualification.

The corrected review finishes with150 checks, no failed checks and no script
errors. Its wrapper receipt and test-written stock JSON remain separate forms
of diagnostic evidence; neither grants occupied-world acceptance.

The fresh entrance source projection subdivides13 existing edge intervals
because the current layout has additional stations. The original strict plan
comparison failed and is retained. Independent owner/level/plane interval
unions remain identical. The facade changes from37,403 to37,687 triangles;
there is no frame-time claim for that increase. Native-only facade inspection
is explicitly selected when the historical temporary world-fabric survey is
absent. It does not fabricate a replacement survey or claim composed clearance.

The shared plain-stock recipe now supports taller heads while keeping the
actual jamb interface diagonal. Before the storefront frames were appended,
rebuilding the seven linings and eleven closed shop surrounds after that
extension produced byte-identical GLBs. Three source
regression tests pass, including all111 opening dimensions at both wall depths.

The Blender batch workflow now explicitly requires full-depth45-degree joints
in both the visible surround and the reveal lining. Continuous structural
lintels and transom rails remain separate construction members.

## Final focused import review and remaining coverage

The shared shop family now includes eleven exterior frames. It retires only
their exact33 placeholder members, adds11 native partitions, and retains all35
previous native part poses and vertex/normal/UV/tangent/index buffers byte for
byte. This is the separate **shop_original_native_buffers.json** comparison;
it does not establish installed shipping-owner preservation. The family has57
source records,23 assemblies,628 closed stocks and116 contact bearings. Its
final native review rendered all11 storefronts. Stepped feet meet the retained
floor and decorative border; the border's declared visual-only status does not
permit ignoring a physical floor obstruction.

The first storefront review failed its source envelope. The next review exposed
missing vertical step bearings. Both failures are retained; explicit step faces
repair those contacts without increasing the contact tolerance or waiving stock.
The new storefronts add264 triangles compared with the33 retired boxes. No
frame-time improvement is claimed.

The combined **loaded_v3** diagnostic found one remaining lift-header UV edge
stretch of0.618%, exceeding the unchanged0.5% limit. The lift receives the same
narrow no-mesh-compression policy already measured necessary for the lining.
After reimport, windowed **loaded_v4** completes253 checks in16.8 seconds with
zero failed checks and zero script errors. The original failed run, both import
receipts, raw stdout/stderr, test-written **stock.json** and loaded capture are
preserved under **art/reviews/v2_door_mitres_20261024/diagnostics/**.

This bench checks authored cap matches and imported UV/tangent/PBR/mipmap data
across the retained casing variants, seven deep-lining variants, the three lift
members, entrance facade and46 shared shop partitions. Its capture was reviewed.
It is an explicitly INERT diagnostic; the wrapper's successful process exit is
not an occupied-world runtime contract, door-operation proof or human acceptance.

Still open: three bar source door surrounds in shared retained trim; source
classification and any required Bodega repair; installed casing/lift/shop owner
and contact checks; played access, door and lift operation; and save/rebuild
regressions. These repairs do not make all V2 door frames complete.

REPORT - door-mitre-source-and-import-preparation - 2026-10-25

Branch / starting HEAD / local origin/main / merge-base:
**codex/v2-main-integration-20261024 / 819e20b7 / 862e54a2 / 55e60195**.
Worktree clean at end: no; disabled resident-world drafts, companion moisture
initialization correction and import churn remain separate. Named frame-family
paths only are included, with their reviewed spatial records and import policy.
Protected17/17: not recertified by this focused report. The protected floor GLBs
are unchanged; selector V2 and the explicit V1 rollback remain unchanged.
Ledger before → after: no promotion claimed; requirements_changed: none claimed.
The broader stale surface/runtime proof and candidate regressions remain open.

Gates: **loaded_v4.log.receipt.json** records a completed windowed process with
exit0 and zero script errors; test-written **stock.json** records253 checks and
no failures. The complete shared static preflight separately passes all three
**test_v2_door_frame_mitres** tests. Reader has zero NEW fields; the targeted
spatial audit is clean after classifying existing anchors while preserving prior
records. No complete clean candidate board or management certificate is claimed.
Numbers requested:111 lining openings, seven landings, eleven new storefront
frames; focused/native counts and explicit limits above. Changes outside the
expected boundary: the common casing adapter retains semantic proxies while
replacing their visuals, and the facade hides its duplicate common lining.
Mechanical, collision, access, panel/interlock and save owners are retained.
Open findings: listed above. Decision needed from owner: none.

BLOCKED merge qualification: occupied-world frame/access/save checks and remaining source surrounds are open.
