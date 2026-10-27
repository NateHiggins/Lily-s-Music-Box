# REPORT - Tardi's Euplotes lunch - 2026-10-25

Evidence class: **INERT**

## Implementation

The owner requested prey from the existing zoo, comic pursuit and lunch taking
priority over repair hints. Euplotes (existing species 7) retains its flattened
cortex, curved macronucleus, micronucleus, two vacuoles, fourteen cirral bundles
and existing four-state gait. Both native LODs were regenerated with metric
0.04 m UV charts and tissue-role attributes for the shared microscopy shaders.
Three existing custom PBR stocks are reused; no unregistered material keys or
reference pixels are introduced. A cool cortex/organ response distinguishes
Euplotes under the same instantaneous lamp field as Tardi. The optical envelope
uses Euplotes' flattened proportions. Existing species identity and atlas pose
ownership remain intact.

This is an authored local resource-transfer pantomime between Dream organelles,
consistent with the owner's requested apparent predator/prey relationship.
No global generic predator AI, colony resource debit, save flag, NPC stimulus or
new collision target is introduced. The PC-only companion presentation applies
to both participants; resident fear interrupts lunch as well as repair hints.

A hungry Tardi spots a surface-seated Euplotes, stalks, chases, winds up and
lunges. Euplotes pauses, reverses sideways and escapes early attempts, then
exhausts its burst stamina. Misses produce a recovery beat. Feeding requires
mouth proximity and a clear physics ray; there is no timer-only remote kill.
The pharyngeal/gut pulse accompanies non-gory prey deflation. The prey is removed
once, followed by grooming and a 45-second satiated interval. A failed pursuit
is bounded to 32 seconds and defers another attempt for 24 seconds. Repair
selection remains live throughout and resumes after lunch. Surface casts and
obstacle rejection remain the movement authority; this is local steering,
not whole-building pathfinding.

## Source basis and fiction

[Bioelectric control of locomotor gaits in the walking ciliate
Euplotes, 2024](https://doi.org/10.1016/j.cub.2023.12.051) describes coordinated
backward/turning maneuvers involving distinct front and rear cirri.
[A unicellular walker controlled by a microtubule-based finite-state machine, 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9474717/) studies
fourteen cirri and finite-state-like gait coordination. These support the
side-step motif and retention of the existing anatomical gait. Comic timing,
finite escape stamina, giant scale, Tardi selecting Euplotes, and repair
priorities are fiction; no species-specific natural diet is asserted.

## Verification

Native anatomy and cutaway review artifacts: C:/ov/tardi-lunch/anatomy.json,
anatomy-lod1.json and native-review. Both structural checks PASS. Inspection:
7,032 triangles; normal: 2,640. Native renders were inspected before runtime
exports were installed. Final rendered review: review3/runtime_contract.json is test-written schema-2
runtime proof with **103/103 checks PASS**, scoped to the isolated production
batch/shared lamp receiver and real collision surface. Its wrapper is
review3.log.receipt.json. The observed sequence contains two missed lunges,
then one contact meal, grooming and return to the current repair target.
Resident fear, wall rejection and unchanged durable repair state pass.
Maximum measured leg-root reach during the hunt is 0.424147 m, within the
body-scale bound; lunge speed and gait phase advance together. Captures of the
miss, feeding onset and mid-feeding deflation were visually reviewed.
Euplotes imported UV area has zero invalid triangles and maximum relative scale
error 0.0000799375. Both species share nine loaded mipmapped PBR textures and
three materials. Existing off/cone/blocker/private-camera and field retirement
checks also pass; the runtime scope is not whole-building navigation or save
reconstruction acceptance.

[Rendered lunch sequence](C:/ov/tardi-lunch/tardi-lunch.mp4), 86 frames at 8 fps.
[Euplotes close-up](C:/ov/tardi-lunch/review3/24_euplotes_microscopy.png).
The review1 first-catch timing and review2 stride mismatch were rejected;
review3 contains the corrected committed-direction lunge and synchronized gait.



Final single-Tardi control measurements (all-species atlas loaded): bound wall
frame median/p95/max 19.991/24.530/33.499 ms;
viewport GPU 2.114/5.006/10.151 ms;
controller update 186/234/326 us.
These are 120 samples after 30 warm-up frames, not isolated two-creature shader
counters. Full bound/unbound/pass controls are in review3/measurements.json.
The same three passes batch the pair; no per-prey material set is allocated.
Field retirement releases 21,234,400 reported VRAM bytes;
all twelve field RIDs and captured material/mesh weak references clear.

The full windowed zoo regression passes **486/486 checks**; see
regression.log.receipt.json. This includes all species pose/atlas parity,
triangle partitions, rebind behavior and resource retirement.

Production V2 integration also passes **9/9 checks**, with schema-2 receipt
world/runtime_contract.json and wrapper world.log.receipt.json. This verifies
startup, private companion composition, binding to the existing waking field,
no NPC collision target and read-only live repair targeting. The complete hunt
is demonstrated in the isolated collision fixture, not claimed as a played
whole-building traversal. No engine/script/shader errors were reported in the
three final runtime runs.

## Management record

Changes are in the shared canonical checkout and remain uncommitted. The
initial static board is C:/ov/tardi-lunch/baseline/board.json; it is an active
checkout baseline, not clean-merge-base candidate verification. The earlier
Tardi implementation remains part of the same working tree. Branch/HEAD:
main/7a548239e3fddba395341e05fcb3be6ec583ae3e; origin/main:
20b7fee5f2122dd44065623e0d13b47794a56fc8; task merge-base equals HEAD.
No candidate verifier was run for this task. All 17 protected paths match task HEAD (protected.json). Selector logic,
durable job authority and saved ecology schema are unchanged. Installed native,
GLB, manifest, builder and model hashes match both build receipts
(source-integrity.json). No owner decision is needed.

The full candidate-board retains a REGRESSED verdict: unrelated concurrent
tentacle-gang import recipes are untracked, its start function changes a spatial
record, and the completeness test encountered 12 transient errors. The saved
board is not overwritten. The standalone completeness retry has no errors and
two failures, both already in the three-failure baseline. Focused-final confirms
zero NEW reader fields, unchanged six ledger blocker counts (7, 42, 110, 8, 134,
136), no requirement promotions and no new lunch spatial findings after two
scoped test records were registered. Its remaining new spatial record is
maintenance_tentacle_gang.gd/start (cf17de909a2eafa6). Partial-board missing-gate
notices are not whole-board verification. Unrelated import records were not
staged or changed to hide the global gate failures.

BLOCKED integration only: shared uncommitted checkout; no merge candidate prepared
