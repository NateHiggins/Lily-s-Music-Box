# Cast radiator section joints

Evidence class: **INERT**. Scoped geometry and verification report, not acceptance.

REPORT - V2-RADIATOR-JOINTS - 2026-10-17

Branch / tested HEAD / origin/main / merge-base: canonical **main** /
**29226611b5be9332747fff29f4011e0b0ba1ea0b** /
**e0b0dd293325a49c207785888112262a4990e474** / same.
Publication: **codex/v2-direct-manipulation-checkpoint**; no main integration.
Worktree clean at end: **no**, inherited receipt/capture and M08F edits remain.
Only named owned paths are staged. Protected 17/17: unchanged by this batch.
Selector: V2 with explicit V1 rollback. Clean merge-base candidate verification
is not performed. Ledger promotion is not requested by this inert report.

## Finding and change

The current cast-iron maps already carry real fine relief. The section joints,
however, have no visible rim break: radial samples of the final old solid keep
the full 34 mm boss radius to within 10 micrometres of its end. A configured
global bevel had clamped away at these Boolean intersections. Replacing the
texture or increasing normal strength would not create that missing joint.

The casting producer now builds explicit **0.8 mm quarter-round profiles** on
the joining bosses before Boolean assembly. The **92 mm section pitch**,
**54 mm bore**, **46 mm end planes**, remaining flat sealing annuli, casting
bounds and mounting datums are retained. At the sampled outer circumference,
each section now recedes **0.279–0.374 mm** from the joint plane. Adjacent
sections retain the inner sealing face while their outer junction reads as
a real recessed seam. This is authored fabrication geometry, not a certified
commercial radiator or pressure simulation. Native and exported machined-face
normals now share the same explicit plane anchors.

Nineteen other exported stocks retain exact attributes, indices, morphs and
material names. All node frames are identical. Shoes, valve, retainer, packing,
vent and wall supports keep their existing authorities. The casting receives
fresh physical charts and tangent derivatives. The one shared casting now has
**13,224 triangles**; the full mechanism export has **136,370**, versus **125,312**
before. All installed sections share that mesh. The existing morph-rich import
has LOD generation disabled; this change makes no new LOD or performance claim.
Separating static stock for future LOD work remains an optimization opportunity.
No textures, optical material policy, heating facts or save codec are changed.

## Verification and retained failures

The native rim/seat/port review passes **580 checks**, including an old-stock
negative control that reproduces the absent recess. The retained fit review
passes **1,486 checks**, covering floor/shoe seats, service retainer travel and
46 surveyed wall ties. Final exported tangent validation passes. The actual
player hand bench passes, with **448 loaded surface checks**, **20 kinematic
cases**, real grab/motion/release, inspection and in-memory reconstruction.
Its stderr is empty; it is not disk reconstruction or a runtime contract.

The first native review detects a **0.475 degree** cap-normal discrepancy:
export preparation anchored the machined face, but the saved source still
held the older corner normals. Applying the same native anchoring and rebuilding
resolves it. That failed output stays separate. The original front-side render
concealed the joining sleeves; the corrected port-side A/B images show the
new seam in diffuse and grazing light. Texture grain remains quiet and physical;
there is no painted dark line. Native A/B frames do not qualify room lighting.

The composed surface suite now checks loaded end-plane/bore/rim radii, all
23 shared-mesh installations, current PBR/mips and five installed views. Its
light fixture uses the existing carried-light layer to stay out of room probe
captures. The earlier control-finish fixture receives that same isolation.
The helpers restore room circuit, lamp, player/camera pose, FOV and processing.
Circuit restoration is a diagnostic fixture, not switch-input proof.

Qualification also binds the native mechanism file, cast-map generator and
metadata, the actual export hook and the loaded review helper. Two reviewed
test dependencies name the existing 2B radiator and room; unrelated spatial debt
is retained. The final composed run passes **28,217 checks**, with zero surface failures:
**25,669 draws**, **16,619 meshes**, **6,089 materials**, **474 textures**.
Loaded boss face radii are **33.200 mm** with **27.000 mm** bore radii on all
four end faces. All 23 installations share that current stock. The five installed
views show the real seams and cast relief under room/carried/diffuse/grazing
light. Grey iron still reads brown under the warm production lights; the
prominent shoe/wedge finish and broader body shape remain appearance work.
The seven-Texture-RID shutdown warning is unchanged. Save reconstruction is
explicitly NOT_EXECUTED in this schema-2 surface contract.

The first publication attempt qualifies the source but encounters Windows
**OSError 22** while copying the inventory. The complete earlier inventory is
verified against its preserved contract before recovery. Atomic replacements
repair publication without another Godot run. The new publisher requires a
qualified source, verifies its preserved inventory/log/image bindings, stages
each file, installs the contract last and qualifies the result. Six isolation
tests cover old-file preservation, transient/permanent sharing failures,
rejection of stale source, image path escape and corrupt prior inventory.
No runtime evidence is generated or repinned by the publisher.

The final **75-row** board reports **zero regressions** against the preceding
checkpoint board: **948 tests**, **64 suites**, 62 passing and the same two
live spatial/first-slice smoke failures. The spatial gate still has **28 new
failing**, **43 new reported** and **one stale preserved** record. Reader,
surface qualification, imports, recipe projections, systemic, period, carrier
and rulings checks pass. The comparison uses the preceding dirty-tree board
(recorded at **0ae108b7**, its owned state subsequently committed as **29226611**),
not a clean merge-base candidate verification.

Ledger before -> after: ABSENT 9, HUMAN_ACCEPTED 1, PROGRAMMED 118,
RUNTIME_PROVEN 27, SHELL_ONLY 3, SPATIALLY_PROVEN 82 -> unchanged.
Requirements changed: **none**. All six completion scopes remain incomplete.

## Evidence and outstanding work

Packet: **art/reviews/v2_radiator_joints_20261017**. Wrapper receipts are
**suite_run**. Only the composed test writes a schema-2 runtime contract;
INERT comparisons and reviewed images never promote gameplay requirements.
Previous qualifying surface files are preserved before publishing a new packet.

The radiator's complete appearance, warm room lighting, other cast transitions,
resident-specific finish variation, played repair/job/custody and disk proof,
broad spatial debt, weather/exteriors and V1 retirement remain unfinished.
This checkpoint does not complete V2 or assert human appearance acceptance.

Decision needed from owner: **none**.

BLOCKED full V2 completion and integration acceptance remain open
