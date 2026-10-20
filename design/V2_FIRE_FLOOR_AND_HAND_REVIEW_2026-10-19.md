# Fire cabinet floor and current hand review

Evidence class: **INERT**. Work report, not completion or human acceptance.

The cabinet's pale floor was a 10 mm visual slab above its supporting steel.
It is now a Blender-authored 50 micrometre cosmetic enamel coating, with a
clear footprint around the retained square tin. The original floor node,
parents, structural collision and existing **Lining** finish remain owned by
the native installer. No material key or maintenance authority was added.

Native review checks closed positive volume, zero nonmanifold edges, 32
underside bearing rays within 100 micrometres, the tin clearance and exported
tangents. Loaded Godot UVs retain metre scale and valid derivatives. Default
compression failed the small edge charts; only this asset joins the existing
measured full-precision import list. Both assembled and separated native
views were inspected before publication.

A rejected 0.3 mm version with its own almost coincident collision shell
caused recovery to alternate between paint and steel. The final cosmetic
coating uses the single retained structural support. The passive probe keeps
all eight loose nozzles stationary against their real supports. This is a
diagnostic fixture, not proof of player access.

The nozzle invalidates cached support when its lever geometry changes.
An upward carry can also escape a false floor-margin contact only when every
convex vertex, including its margin, is above the highest plane of every box
on that static body. There is no negative-gap allowance. The sweep repeats
against other obstacles; descending motion, non-box stock and dynamic bodies
retain the ordinary collision path. Thread turns skip expensive narrow-phase
queries only when the conservative swept bounds have no world overlap.

## Verification and original failures

The review packet is **art/reviews/v2_fire_floor_hand_20261019**. Original
failures remain failures and are not repinned to current sources.

| Run | Result and scope |
| --- | --- |
| stage19_fire1 | Composed first station failed pickup and full-state restoration; stopped before the expensive unrelated surface sweep. |
| stage19_floor_uv1 | Loaded edge-chart scale failed under default compression, widest ratio 1.00508346. |
| stage19_closed3 / stage19_support1 | Rejected separate coating collider did not retain a stable supported pose. |
| stage19_support2 | Final single support and thin coating: all eight nozzles stationary, terminal pass in 16.65 s. |
| stage19_closed4 | Stable restoration passed; upward floor-margin trapping remained. |
| stage19_closed5 | 42 checks passed in 52.01 s through actual windowed mouse grab, motion, release, inspection, native guide entry, nut phase pickup, sealing, partial travel, restoration and full withdrawal. The nozzle also landed on its displaced original floor within 200 micrometres. |
| stage19_fire2 through stage19_fire4 | Basement nozzle, washer and full-state restoration checks passed; closed-leaf ray still failed. Native node and server transforms agreed, all 17 shapes remained enabled; a focused fixture's restored leaf was selectable. The composed query publication timing remains under investigation. |

The focused fixture runs at the basement station's actual world rotation and
location with the nozzle valve closed through real input. Its frame uses
neutral fixture illumination and is not an installed voxel-light comparison.
Original wrapper receipts are run corroboration, not runtime acceptance.

The shared surface harness now checks the changed fire family first, using
the existing composed player and hand helpers. It verifies current imported
fold/rack contacts and retired legacy prompts instead of old click-toggle
assumptions. A fail-fast or explicitly fire-only run writes only its scoped
fire contract; it cannot issue full surface acceptance. Passive parts receive
40 physics ticks before restoration snapshots.

The next combined run, **stage19_fire5**, passed the complete basement hand
programme and both restored-door rays after yielding a rendered frame before
the physics query. The next landing exposed five fresh-fold bearing-ray
failures, so the eight-station review still failed and remains unaccepted.

The native bearing probe now traces upward from inside the curved profiles,
comparing the carrier's upper surface with the crown's inner upper surface.
The rejected opposed-ray attempt measured the carrier underside. The corrected
geometry fixture, **stage19_rack_matrix2**, passed 320 checks in 25.66 s: 800
bearing rays across both stock poses and all eight world heights, plus 160
deliberately displaced-crown negative controls. The 100 micrometre contact
limit remains unchanged. This is loaded geometry verification, not a played
route or an eight-station hand contract. A new combined run is pending.

That combined run, **stage19_fire6**, still failed five centre bearing samples
in the basement's fresh pose: the arm ray returned no intersection while the
cloth ray remained finite. Other offsets passed. The small fixture therefore
does not close the composed failure. Triangle-ray numerical behavior and
exact world transforms require diagnosis before another expensive full run;
the centre samples and 100 micrometre contact requirement remain mandatory.

The current isolated staged-candidate board has 114 regressions against the
clean merge-base board, with only the two expired-evidence completeness smoke
checks failing among the tools tests. This is diagnostic static coverage, not
clean candidate acceptance. The lighting test's header now accurately names
its optical/collision diagnostic scope; no public-behavior proof is inferred
from its private policy calls, and no systemic baseline was expanded.

Partial checkpoint **6529faf5** was committed and pushed to draft PR **10**.
Its clean in-place verifier also reported 114 regressions, preserved all 17
protected paths and the V2 selector, and found no design-document lint errors.
It is not merge-ready. The later rack-matrix follow-up and combined review
remain work in progress beyond that checkpoint.

The broader surface, route and clean
candidate qualification remain open, as do human appearance approval,
complete 15.24 m hose storage/deployment/refolding, certification and the
known renderer shutdown warnings. The smaller, offset carried voxel-light
profile remains described in **design/V2_CARRIED_LIGHT_OFFSET_2026-10-19.md**.
