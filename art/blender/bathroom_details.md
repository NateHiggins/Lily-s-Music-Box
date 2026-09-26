# Bathroom fixture refinement

Evidence class: **INERT**

Rebuild with `blender -b -P art/blender/scripts/build_bathroom_details.py`.
The script writes editable **bath_shower.blend** and **bath_towel.blend**, their
game GLBs, plus **bath_water_closet.blend** and **bath_paper_holder.blend**.
Towel and paper references and bounds remain in the existing bath-details data.
The consumer checks imported dressing vertices against those bounds. Toilet
model references are authored in domestic_furniture_source.json; run
`python tools/build_v2_authoring_projection.py` after rebuilding to update the
runtime projection. Household identities and supports remain unchanged.

The shower retains its existing receptor footprint, separate hot/cold controls,
curtain ownership and water simulation. Blender supplies a coved enamel tray,
drain grille, joined riser and curved arm, bell-shaped rose with jet details,
wall brackets, rounded curtain rail and bracing. CurtainDrawn and CurtainGathered
are alternative authored cloth poses, not simulated cloth; their groups remain
separate from the casting and moving valve crosses. Rings surround the rail,
hooks connect to the cloth, and the lower hem sits inside the receptor.

The towel has thickness, a rounded fold over its rail, and a shorter return
behind the front drop. Two brackets bear on the lavatory apron; there is no
strap crossing the pedestal. It uses the existing linen and nickel finishes.

The companion lavatory rebuild now includes glazed valve bosses, exposed
spindles and a chain eye on the bridge fitting. The runtime chain endpoint
matches that eye in both stopper states.

The water closet has a hollow wash-down bowl, porcelain foot and low cistern,
wooden seat and raised lid, supply shutoff and a separate CisternHandle pivot.
The existing owner still controls flush sound, lever travel, refill time and
repeat-use refusal. The paper spindle mounts on the cistern side opposite the
lever, behind and outside the seat opening; its loose end clears the knee space.
The seat and lid are fixed poses; this pass does not add a toileting simulation.

PlanarMirrorRenderer retains one borrowed viewport. Its asymmetric frustum is
aligned to the moving glass and clipped at that plane. The shader derives full
glass coordinates from local vertex positions instead of using a BoxMesh's
six-face UV atlas. PlanarMirrorShot checks reflected coloured objects at their
analytically predicted positions from both sides; BathLavatoryTest captures the
installed mirror, fixtures and plumbing. Neither suite promotes spatial evidence.

The full apartment batch also ran during this work: 20,315 checks, three
failures representing two unrelated cardinality assertions (heating runs twice).
It expects 41 wall extensions and 12 installed radiators; the unchanged main
data already contains 53 and 18. These assertions remain intact. The focused
bath suite invokes that batch's complete bath-detail validation, including
shared meshes, material bindings, missing/invalid supports and rejection of
incorrect Blender paths and bounds. The 4B walking route separately checks
actual input rays, door crossings and water controls.
