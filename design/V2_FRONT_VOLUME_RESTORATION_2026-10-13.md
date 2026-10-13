# V2 central front volume restoration — 2026-10-13

Evidence class: **INERT**. Implementation and visual-review report. This is
not a room-acceptance checkpoint or a claim that V2 is complete.

## Diagnosis and correction

The owner identified the central frontage as missing architecture, rather
than an intentional courtyard. The original layout has a continuous rectangular
slab. V2 retained a roof across this area but omitted substantial occupied
volume below it. The preceding localized fire-repair staging did not repair
that omission. This restoration supersedes its proposal to develop the recess
as an exterior court.

The V2 source now contains 20 additional spaces, 24 passage openings and
27 new windows. Five upper floors receive street-facing common galleries,
connections to the existing east halls, and returns into the service spine.
Ground-floor bays flank the retained recessed entrance, with a connected
workroom and service return. The shallow recess behind the staff restroom
is storage, not a claimed standing passage. Existing apartment ownership,
entry-door identity, fire risers and world connections remain intact.

The two original lobby window identities move forward from the former recessed
wall to the new frontage. Their dimensions and operation remain intact. No
other existing space, opening, window or door record is changed. The authoring
recipe checks this limited scope before applying the changes.

## Architectural finish

A continuous brick front, floor-line courses, three articulated piers and a
stepped cornice give the middle section a coherent mass. Separate stone heads,
sills and keystones frame the added windows; timber benches furnish the upper
galleries. Existing public wall paneling, floors, window frames and adjustable
window treatments extend into the restored rooms through the regular builders.
The fire-repair staging remains on the adjacent wing.

Native restoration details comprise 219 closed stocks, three material
partitions and 23,652 triangles. All use registered custom brick, concrete and
wood PBR, authored metric UVs, and matching fixed collisions. Exterior masonry,
ceiling top closures and foundations were regenerated from the revised layout.
The entrance stonework was regenerated too, removing obsolete window surrounds
that otherwise blocked the new lobby passages. The original canopy and its
lamps move down 720 mm: the highest native canopy stock is at 2.95 m, leaving
50 mm below the restored slab soffit. Door mechanics and the entrance threshold
retain their existing owners.

## Verification

Final receipts and rendered review are recorded in
**art/renders/orison_v2/front_restoration_20261013/**.
The final surface run completes 26,656 checks with zero failures, covering
24,464 draws, 16,514 meshes, 5,990 materials and 465 textures. Its restored
front walkthrough passes all 42 movement checks. All 98 habitable windows
receive their expected treatments. The entrance passes 759 fit and interaction
checks, including its full door sweep. The first
combined run correctly rejected obstructed lobby passages and a premature
first-frame walking check; those results are retained as diagnostics. Its
technical surface inventory itself found zero noncompliant surfaces. A later
run exposed the canopy backplate crossing the door sweep; the plate was
shortened above the retained door head. The longer review also exposed a
mid-capture campaign-clock reset in the existing four-season screenshot loop.
The visual qualification now explicitly freezes the supported campaign-time
driver while taking seasonal pictures, and checks that the shop simulation
remains healthy. Separate apartment and save/reconstruction runs retain the
live clock. Intermediate diagnostic runs do not provide final acceptance.

The source reader audit reports zero new unread fields. The spatial manifest
adds only the 27 generated lookups of newly authored, existing window IDs.
No blanket fixture hash rebinding or spatial acceptance promotion is used.

The live-clock apartment contract passes 268 checks and reaches all 19
previously verified rooms. One attempt failed the final 2B entry closing
gesture; the unchanged retry passed. Its failed runtime contract and log are
preserved under **apartment_retry_diagnostic/**, and the intermittent cause
is not claimed resolved by this architectural change.

## Management report

REPORT - V2-FRONT-VOLUME-RESTORATION - 2026-10-13

Branch / validation parent / origin/main / merge-base: main / 7283b99b /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Publication targets **codex/v2-direct-manipulation-checkpoint**. No integration
into origin/main is claimed. The shared checkout retains inherited dirty files;
only named owned paths are included in this checkpoint.

The final live-clock first-slice contract passes 113 checks, including actual
save-file reconstruction. The surface suite reports no script errors or shop
simulation error; seven texture RIDs are still warned about at engine shutdown,
as in the preceding surface runs. This is not claimed fixed by the frontage.

The remaining nine-apartment access diagnostic, broad V2 completion, historical
baseline defects and human aesthetic acceptance remain separate obligations.

Final gate board: 55 rows, zero regressions against
**art/renders/orison_v2/fire_repairs_20261013/gate_board.json**. All 45 tools
tests pass. All ten static gates were refreshed after final verification;
unchanged tools-test rows are retained from this batch's full run, with live
completeness and spatial tests refreshed. Reader NEW remains zero.

Protected paths: 17/17 unchanged against the merge-base; selector remains V2
with the explicit V1 rollback. Ledger blockers before and after are unchanged:
first slice / golden shift / structural / runtime / cutover / retirement =
**0 / 1 / 102 / 34 / 119 / 121**. The completeness gate remains INCOMPLETE.
A clean-worktree candidate verification and an origin/main merge are not claimed.

Changes outside the architectural assets are the visual harness's explicit
fixed-clock seasonal review, renewal of the existing canonical contracts,
append-only window dependency registration, and the batch workflow's fit-review
notes. Decision needed from the owner: none for this scoped checkpoint.
Whole-building completion remains unachieved; the intermittent 2B closing
observation and previous 4A/5B access diagnostics remain recorded separately.
