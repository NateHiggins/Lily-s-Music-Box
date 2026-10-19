# REPORT - V2-CITY-CONTEXT - 2026-10-19

Evidence class: **INERT**. Publication report; no additional acceptance grant.

Branch / HEAD / origin/main / merge-base: **main** / verified candidate
**30f603c3bdd75ab5557cba15c2db4c9b35be1555** / **fa6e8f9762763a0ff369c74ed42aa704b44365e2** /
**fa6e8f9762763a0ff369c74ed42aa704b44365e2**.
This publication child changes documentation and preserves the unmodified final
verification output. No runtime, rendering, asset or helper inputs change.

Worktree clean at end: verification checkout yes; canonical shared checkout no.
Inherited/generated UID, import, receipt, enamel/M08F and unrelated capture
changes remain unowned. Only named owned paths are staged.

Protected 17/17: unchanged versus merge-base. Selector: **v2**;
explicit V1 rollback preserved. Historical raw hash differences are not new work.

Ledger before -> after (blockers):

| Gate | Before | After |
|---|---:|---:|
| FIRST_SLICE_TECHNICAL | 0 | 0 |
| GOLDEN_SHIFT_V2 | 1 | 1 |
| FULL_BUILDING_STRUCTURAL | 27 | 27 |
| FULL_BUILDING_RUNTIME | 25 | 25 |
| PRODUCTION_CUTOVER | 44 | 44 |
| V1_RETIREMENT | 46 | 46 |

Requirements changed: []. City scenery and the source-derived
context camera grant no new played-region, programme or human appearance proof.

All 92 gates, including 80 tools-test suites, complete.
The clean verifier exits 0 with zero regressions, 0 improvements,
zero accepted regressions and zero design lint errors. The ledger intentionally
remains incomplete. Exact results, original exits and all diagnostics are in
**art/reviews/v2_city_polish_20261018/verified/verification.json** and
**verification.md**. Verification uses **--no-godot**: the original canonical
engine runs below bind the identical source pair. The clean checkout ran no
engine and makes no fresh import/cache claim.

All six original Godot jobs complete with zero failures and zero script errors:

| Original run | Actual checks | Seconds |
|---|---:|---:|
| final_surface4 | 39527 | 636.77 |
| final_circulation1 | 90 | 318.08 |
| final_service1 | 360 | 374.73 |
| final_home1 | 909 | 441.54 |
| final_upper1 | 989 | 1127.82 |
| final_landing1 | 41 | 343.44 |

The service run executes 360 checks; 359 are serialized because its final flush
check runs after writing the JSON. Original stdout and matching wrapper retain
that check. Contracts are copied unchanged, never repinned. The independent
**original_qualification_summary.json** validates current fingerprints, original
contract identity and every wrapper/raw-log hash. Canonical packets are under
**art/renders/orison_v2/**; prior packets and failed diagnostics are preserved
under **art/reviews/v2_city_polish_20261018/**.

The primary 25 buildings now have varied sash, curtains and roller shades:
3,682 windows, 3,975 independently inspected closed curtain stocks and 1,205
retained roof-bearing samples. The additive horizon has 124 disjoint footprints:
48 rowhouses, 57 walkups, 18 factories and one commercial accent. Its 12,331
recessed panes, sash frames, cornices and chimney caps are native closed stocks.
This is authored western Queens scenery informed by period sources, not a
surveyed reconstruction. Sources, dates and inspection limits are documented in
**design/V2_QUEENS_1928_CITY_REFERENCE_2026-10-18.md**. No reference photographs
are baked, projected or committed as game assets.

Four disjoint native grade slabs extend to 420 metres outside the retained
ground envelope. The old ground asset is byte-identical. Thirty-six actual
first-hit samples retain the 0.1 mm tolerance and include all building colliders.
The context camera is explicitly source-derived, not a retained player vista.
Native source checks precede the combined composed review; the final loaded
context bench passes 12,500 checks. Dry V2 fog reaches 70..400 metres, humidity
40..300; fog/heavy rain retain 13..58. V1 retains its writer and distances. The
actual-writer visibility bench passes 138 checks.

All nineteen current scoped surface images and seven current standing service
images were inspected. Four native primary-elevation and four final native
horizon previews were also inspected. These reviews concern fit, continuity and
correspondence; they do not grant whole-game photorealism or human acceptance.
The composed inventory is 26,475 draws, 17,441 meshes, 6,135 material instances
and 497 textures, with zero unresolved UV/custom-PBR/loaded-mipmap surfaces.
Existing catalogue maps are reused; no new texture images or material keys.

Runtime inputs: **8b1ba493e78e83c64f5a19e9298ff28acadaa47f8ce88be6a41d9766e5508b0c**.
Surface inputs: **246782ff7adee6f7a7ef51ed359fe887d1afd3b71e617e086ae8ef69714b5709**.
Both match canonical and clean-checkout source **1d41eac1**.

Changed gate files requiring explicit review:

- **M tools/orison_spatial_dependency_manifest.json**
- **A tools/tests/test_city_ground_apron.py**
- **A tools/tests/test_city_horizon.py**
- **M tools/tests/test_v2_surface_requirements.py**

Review: surface provenance adds ten owning native plans/assets/reports and
negative tests that mutate each input. The ground tests independently check
ring area, old-ground reservation and invalid envelopes/depth. Horizon tests
check closed edges, signed volume, entire party-wall segments, actual roof
height and duplicate/invalid footprints. The spatial manifest appends one
inspected camera record with all prior rows unchanged. Three mesh assets use
metric precision to avoid demonstrated UV distortion; texture compression and
mipmap requirements are unchanged. No baseline waiver is accepted.

A composed blind review exposed a timer/tween scheduling race at low FPS.
The isolated real-save-owner diagnostic reproduces the old timer firing while
the same tween is still running; it later finishes normally. Tests now observe
that original tween's finished signal with a bounded frame wait and reject
cancelled/replaced tweens. Production blind/save code is unchanged. Failed
originals remain archived. This is stronger completion testing, not new hand
input or mechanism acceptance.

Changes outside expected city art: the shared director gains a no-op profile
hook for V2's sole fog writer; V1 behavior is retained. The blind review timing
repair resolves an independently reproduced qualification failure. New source
expiry inputs and negative gates bind the actual authored stock.

Open findings: seven leaked Texture RIDs reported at surface shutdown; carried
light hotspots, repeated glazing/timber/shades, coarse artwork, schematic cloud
art and plain outward faces on retained far buildings. Remaining structural and
runtime blockers above, V2 acoustic rederivation, eleven authored Golden Shift
beats, full programme/system proof, human appearance acceptance and explicit V1
retirement remain open. Ignored regional prototypes grant no acceptance.

Decision needed from owner: none for this scoped checkpoint. Human acceptance
and eventual explicit V1 retirement remain separate.

MERGE-CANDIDATE 30f603c3bdd75ab5557cba15c2db4c9b35be1555
