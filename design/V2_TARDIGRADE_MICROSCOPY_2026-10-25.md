# REPORT - Tardigrade microscopic optics and private companion - 2026-10-25

Evidence class: **INERT**

This report records implementation and scoped verification, not ledger promotion
or owner visual acceptance. Wrapper receipts and captures are not runtime proof.

## Delivered behavior and appearance

The exterior now transmits the actual scene behind the animal. Finite optical
depth softens the organs at grazing boundaries; integrated cloudy cytoplasm,
spectral absorption, wet reflection and lamp-dependent internal attenuation
provide depth beyond alpha blending. Front, side and backlight reference captures
show transmission through trunk and legs, differentiated tissue and changing
mineral/wet highlights. The neutral grid is a diagnostic background, not a light.

Three coordinated transparent passes carry organs/mineral, membrane/cytoplasm
and vacuole walls. Nine catalogue-backed custom PBR maps have loaded mip chains;
UV tile size is 0.04 m. Inspection geometry has 19,960 triangles and normal LOD
4,996. Imported UV area error is at most 0.000113962, with no invalid charts.
Blender anatomy includes folded gut, nucleus/germinal mass, paired vacuoles,
contractile sacs, granules, mineral branches at three depths, cilia/menisci,
paired brain lobes, four ventral ganglia and eight somatic muscle strands.

The existing instantaneous lamp field owns every optical input. Lamp-off,
blocked and outside-cone fragments disappear, including on a visible room
background; mineral reflection has no emission. Local density advection, gut
constriction, muscle strain and small organ lag remain in organism coordinates.
The existing pose atlas and planted-foot authority remain intact. Mutable pose
arrays are copied into the material synchronization cache so contractions update
on the GPU instead of comparing against an aliased copy of themselves. Body
turns accompany stepping; idle/startled attention cannot twist the trunk over
eight planted feet.

The companion is composed in the production V2 building and existing apartment
encroachment path. It reads live WorkOrders and repair anchors, including the
relocating Vantry owner. It leads briefly, checks back, waits for the player,
explores when idle, retreats from residents and contracts/reopens after a close
startle. Completed jobs stop attracting it. It neither advances jobs nor writes
save/case state, emits NPC stimuli, or adds collision/perception targets.
Player-camera gating and a reserved visibility layer keep it private to the PC;
its layer is excluded from the lamp shadow camera. The production test verifies
that its three materials bind the existing waking field, not a second field.

## Research basis

- [Nirody et al., 2021](https://pmc.ncbi.nlm.nih.gov/articles/PMC8536314/)
  measured coordinated stepping in Hypsibius exemplaris. Rear legs differ from
  the first three pairs and serve grasping; the existing planted-foot gait is
  preserved while exploration pauses and escape turns vary behavior.
- [Mayer et al., 2013](https://doi.org/10.1186/1471-2148-13-230)
  describe four ventral trunk ganglia, motivating the separate neural masses.
- [Janelt et al., 2024](https://onlinelibrary.wiley.com/doi/full/10.1111/joa.13994)
  describe a compact brain and ganglionated nervous system in encysted
  Thulinius ruffoi. A brief game startle is not claimed to be cryptobiosis.
- [Eibye-Jacobsen, 1996](https://academic.oup.com/zoolinnean/article-abstract/116/1-2/123/2684335)
  identify the pharynx as myoepithelium, informing distinct feeding-tissue motion.

Curiosity, shyness, private perception, mineral strands and repair guidance are
fiction, not claims about real tardigrade cognition or physiology.

## Verification and artifacts

All local evidence is under C:/ov/tardigrade-optics. Native inspection and normal
checks are anatomy9.json and anatomy9-lod1.json (PASS); native9 neutral/cutaway
renders were reviewed before the final source assets were copied and imported.

Final microscopy: final-seated/runtime_contract.json, schema 2, **87/87 PASS**,
with final-seated.log.receipt.json completed and no script/shader errors.
This proves loaded maps/UVs, off/blocker/cone rejection, private observer gating,
live target selection, read-only behavior, real surface movement, contraction
and GPU pose synchronization, material unregistering, all twelve field RID
releases and retired resource weak-reference clearance. It does not prove
whole-building navigation or save reconstruction.

New captures: [front](C:/ov/tardigrade-optics/final-seated/21_stage_front.png),
[side](C:/ov/tardigrade-optics/final-seated/22_stage_side.png),
[backlight](C:/ov/tardigrade-optics/final-seated/23_stage_backlight.png).
Black-stage equivalents are 01_front.png, 02_side.png and 03_back.png.
[Animation](C:/ov/tardigrade-optics/behavior.mp4) contains 64 frames at 8 fps;
simulation uses eight substeps per captured frame. Contracted/reopened frames
24 and 56 were visually reviewed after the planted-body turn fix.

Performance: 120 samples after 30 warm-up frames per control. GPU figures are
viewport timings, not isolated hardware shader counters. The historical
opaque_only control name means the organ pass alone (now also translucent).

| Control | Wall ms median / p95 / max | GPU ms median / p95 / max | Controller us median / p95 / max | Draws |
|---|---|---|---|---|
| bound | 19.561/25.983/27.100 | 3.417/4.136/7.156 | 181.000/199.000/286.000 | 3 |
| unbound | 19.925/26.075/27.986 | 1.382/2.154/4.644 | 185.000/218.000/315.000 | 3 |
| opaque_only | 20.165/25.672/27.342 | 0.942/4.569/6.003 | 186.000/207.000/253.000 | 1 |

Bound-minus-unbound GPU median: 2.035 ms;
outer-pass delta: 2.475 ms.
Field disposal releases 21,234,400 reported VRAM bytes.
Bound scene video memory: 1,705,354,848 bytes, including shared
all-species pose resources. Unbound retains the same field/resources; its VRAM
delta is zero. Three new materials share nine PBR maps and twelve optical
texture bindings. Production tier 1 uses main 48x48x64 and near 96x96x128.
Both cascades report zero field readbacks. Injection/construction/submission
distributions are preserved in final-seated/measurements.json. Sequential
desktop timings include scheduling noise and are not per-shader isolation.

The composed-world test world2/runtime_contract.json is schema-2 runtime proof
for production V2 composition and read-only targeting: 9/9 checks PASS.
Its wrapper is world2.log.receipt.json, with no script/shader errors.
The existing rendered creature regression passed 486/486 checks in
regression-next.log.receipt.json. It precedes the final micro-material/cache
adjustments; the final microscopy suite exercises those changes directly.

The transport uses an authored trunk envelope, finite samples and ellipsoid
vacuole lens displacement, not general ray-traced fluid. Transparent surfaces
use conventional blending. Guidance is local directional movement with surface
and obstacle casts, not a demonstrated whole-building path planner. No save
reconstruction or full traversal acceptance is claimed.

## Management record

Branch / HEAD / origin/main / task merge-base: main /
7a548239e3fddba395341e05fcb3be6ec583ae3e /
20b7fee5f2122dd44065623e0d13b47794a56fc8 /
7a548239e3fddba395341e05fcb3be6ec583ae3e.
Worktree clean: no; changes are uncommitted. A shared Git index lock is present;
no lock was removed and no unrelated changes were staged. Import line-ending
churn has no substantive diff. No candidate verifier was run.

Protected paths: 17/17 match task HEAD, recorded in protected-working-tree.json.
Selector V2 default and explicit V1 rollback remain unchanged.
Ledger baseline blockers: FIRST_SLICE_TECHNICAL 7, FULL_BUILDING_RUNTIME 42,
FULL_BUILDING_STRUCTURAL 110, GOLDEN_SHIFT_V2 8, PRODUCTION_CUTOVER 134,
V1_RETIREMENT 136. The delivery-board comparison leaves these six counts unchanged and reports
one newly failing test, test_v2_flue_native_evidence. It raised KeyError when
another task changed its discovered native input set between reads. Both a
standalone rerun (flue-retry.txt) and flue-retry-board/board.json PASS after the
input set settled. The original full board remains honestly marked REGRESSED;
it is not overwritten by the targeted rerun. Its totals are 104 PASS, five FAIL
and one INCOMPLETE. The remaining four failures and incomplete ledger match the
baseline. Reader: zero NEW, 1,108 known unread and 200 resolved. Catalogue
persistence PASS. No requirement states changed. The baseline was captured
in the active checkout, not a clean merge-base, and is not canonical candidate
verification. Known baseline failures are not a green-main claim.

Changes outside the creature boundary: production composition hooks; receiver
shader registration; bridge retirement cleanup; lamp shadow-layer exclusion;
nine retained mip import recipes; catalogue regeneration persistence; three
scoped spatial dependency records. Existing manifest records are unchanged.

Open limitations: bounded optical approximations and local guidance described
above; uncommitted integration. Owner decision needed: none.

Implementation-stage status above is historical. The owner subsequently authorized
integration with the lunch work; see V2_TARDIGRADE_LUNCH_2026-10-25.md and
C:/ov/tardi-lunch/merge for candidate verification. A rebuild against the final
shared builder preserves byte-identical runtime GLBs and manifests for both LODs.
