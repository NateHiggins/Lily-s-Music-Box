# V2 toilet form, attached fittings and gesture travel

Evidence class: **INERT**. Native and actual-input diagnostics, not acceptance,
not a schema-2 runtime contract, and no completeness promotion.

## Issue log

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Toilet seat and lid | Open seat; floating barrels and overly broad rear aperture; medium | Owner form references and retained native views | Fuller front, flatter rear, smaller aperture; common pivot, porcelain bearing plinths, rosettes, posts, pins, independent knuckles, leaf straps and screws | Native closed solids, measured mounting contacts, rendered close-up and actual hinge stops |
| Bowl and cistern underside | Look down bowl or under tank; absent bore and undersized connection; medium | Original casting and owner references | Continuous open wash-down throat, mating hollow cast-iron trap continuing below floor, larger hollow flush connection, defined cistern plinth, outlet boss, union, gasket and inlet fitting | Native and imported aperture rays, coincident trap mouth, underside renders |
| Flush paddle and cistern | Push external lever; poor finger shape and unsupported internal stock; medium | Owner report and native mechanism review | Smaller rose and rounded finger paddle, spindle bush, internal lever and length-constrained discharge chain; floor nuts/flanges, guide feet, overflow wall strap, ballcock pivot cheeks and pin, float nipple and lift eye | Actual handle input moves anchor and lift rod; chain-length and independent internal-control assertions; inspection and save roundtrip |
| Bounded toilet controls | Move seat/lid/handle/float/rod; unnecessary environment probes; medium | Owner direction to use environment sweeps only when gameplay useful | Functional angular/linear stops and seat/lid ordering; removable cover retains real world obstruction checks | Actual stop/reticle checks, physically carried cover and blocked feedback |
| Shower curtain | Same gesture gives short, viewpoint-dependent travel; medium | Old 288-pixel gestures open 0.234/0.412/0.518/0.676 m across two distances and FOVs | Opt-in 280-pixel full-range gesture with stable initial screen axis; same U rail, cloth, owner and saved intermediate travel | Four actual-input cases each open 1.78 m with 288 pixels and reverse to closed with the same gesture |
| Loose-plug diagnostic | Frozen player cannot update its new FPS hand; fixture defect | Original broader interaction failure retained | Enable real player physics against a standing floor during pickup; test actual input and chain-limited carrying | Broader interaction diagnostic passes 116 checks |

The native file keeps 76 separately editable closed stocks. Export batches
rigid stock by parent and registered material, retaining the semantic part
roots, separate internal bent linkage and eight animated chain links. The
imported asset has 26 mesh groups and 36,898 triangles, versus the original
19,992 triangles. The added bore, trap and mounting detail increase geometry;
this is a measured resource tradeoff, not a claimed frame-time improvement.

Every exported triangle has metric UV charts and validated tangent derivatives.
Godot's compressed mesh UVs failed the metric check; only this GLB's mesh
compression is disabled. Surface textures retain the V2 compression policy,
custom albedo/roughness/OpenGL normals, complete loaded mips and anisotropic
filtering. Material instances are shared within the fixture by registered key.
The existing exporter UV-V/bitangent-sign correction is applied through its
native export hook. Generated glTF is never hand-edited. Photographs inform
form only; none is projected, baked or committed.

The chain follows the same authoritative handle/rod positions that run the
flush. Its fixed length determines the handle-driven rod lift. The existing
flush, floating discharge, water level and refill owners remain responsible
for function. Chain links update only when their endpoints change, with no
extra targeting scan, physics simulation or environment collision. Save field
names and validators remain unchanged; decorative links reconstruct from
saved mechanism positions. Primary still grabs, mouse movement operates, next
primary releases; Space enters the fixed inspection view with its free cursor.

The gesture option is currently applied to the curtain. Other owners retain
their existing mapping unless they explicitly opt in; this does not establish
uniform travel for every mechanism in V2.

## Verification and retained failures

Diagnostic packet: **art/reviews/v2_toilet_form_20261022**. The final packet
manifest identifies exact compressed logs, stderr, wrapper receipts, native
reviews, source snapshots and selected views. Wrapper **suite_run** receipts
report process completion only; these benches do not issue runtime acceptance.

Original failures remain: degenerate native chart, exported tangent sign,
compressed imported UV metric, outdated handle gesture, the plug fixture and
a malformed new lift eye. The first hardware trap's smooth normal basis also
failed before import. Corrections were made in native source and import policy;
original failure logs and available rejected asset captures are retained.
The first full-world route stops at 0.6395 m of curtain travel: its old driver
changed gesture direction with each new world-rail tangent. The retained failed
fixture and completed failure receipt precede a driver update that uses the
controller's fixed gesture axis for opted-in controls. No owner writer or
collision bypass is introduced; the corrected route repeats real input.
A subsequent complete 32-waypoint run passes all changed bathroom controls but
fails its old final **collision_mask == 1** assertion. The fixture now checks
**1 | native_contact_layers**, matching the unchanged production player mask.
The next run reaches the closet but loses its grip at 72 degrees from the old
standing position; add a closer ordinary walking waypoint and log actual reach
on failure. Neither migration disables collision, teleports the walking player,
writes owner state or relaxes the requested physical stop. All failure receipts
and pre-migration fixture sources remain available.
A malformed import invocation launched the main scene and timed out at 180 s;
it is explicitly a diagnostic error with no verdict, followed by a correctly
argumentized import. No timed-out or partial run is promoted as a suite pass.

Final native review passes 76 closed stocks, metric charts, three open-aperture
rays and eight mounting/mating contacts. The final raw GLB passes all exported
UV tangent derivatives; imported Godot review and actual hand controls pass
192 checks with empty stderr. The dark trap uses registered **iron_blackened**
stock after render review rejected the pale **cast_iron** finish.
The 116-check broader manipulation diagnostic passes, including all four
curtain distance/FOV cases and physically updated loose-plug pickup.

## Continuation report

REPORT - V2 toilet form and gesture travel - 2026-10-22.
Branch **codex/v2-acoustic-topology**, preceding HEAD **a3e7b1bd**;
origin/main and merge-base **21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**.
Canonical shared checkout. Four preceding hose WIP paths, their pre-existing
helper and the separate hose profiling diagnostic remain outside this
checkpoint; unrelated files are preserved. Named paths only are staged.

Protected working paths match HEAD 17/17; selector remains V2 with explicit V1
rollback. The complete shared-tree board records 107 PASS, two FAIL and one
INCOMPLETE, with NO REGRESSIONS against the preceding continuation board.
Ledger blockers remain 7 / 42 / 110 / 8 / 134 / 136; no requirement changes.
Existing failures are expired surface qualification (two defects) and two
completeness assertions. The board is a dirty shared-tree census, not a
clean-main candidate baseline. A final six-gate source/import/spatial/reader
refresh passes after the dark finish; spatial report-only references remain
six and the reader reports zero NEW unread fields. The V2 import policy checks
all 1,376 referenced textures with no repairs needed.

The complete 32-waypoint **world_4b_dark_final** diagnostic reaches and operates
the repaired toilet and curtain, returns to the hall and verifies the closed
entry barrier; its final legacy mask assertion fails as described above. This
is not a passing route qualification. The subsequent **world_4b_mask_final**
fails at the closet grip. The closer-stance **world_4b_reach_final** is stopped
at the owner's new direction to remove door obstruction handling and adopt
fixed gesture travel, player accommodation and slow automatic closing. Its
explicit cancellation record grants no suite verdict, regardless of wrapper
process completion. Keep all three original outcomes. Future door verification
must exercise that new contract, not repeat the superseded collision route. No performance improvement or full-building acceptance is
claimed from this art and interaction repair. There is no paired playable
before/after frame distribution for this toilet revision. Screenshot-heavy
route timing is not a clean performance profile.

Remaining: the owner's new easy-door contract (fixed gesture, player backing,
no obstruction sweep, slow automatic closing); the newly requested shower spray
cone, hot-water-driven local steam,
mirror fog, restrained mirror/window edge wear and side-correct wet-glass
condensation/rivulets; hose carrying/aiming performance, release/contact behavior, supply
and controllable spray, coupling-aware saves, broader V2 inspection coverage,
renewed qualifications and human acceptance. Decision needed from owner: none.

BLOCKED - full V2 completion and merge qualification remain incomplete;
continue authorized repairs.
