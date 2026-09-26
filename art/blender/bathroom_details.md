# Bathroom fixture refinement

Evidence class: **INERT**

Rebuild with `blender -b -P art/blender/scripts/build_bathroom_details.py`.
The script writes editable **bath_shower.blend** and **bath_towel.blend**, their
game GLBs, and the towel model reference and measured bounds in the existing
bath-details data. It preserves every household support and all other dressing.
The consumer checks the imported towel vertices against those bounds.

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

PlanarMirrorRenderer retains one borrowed viewport. Its asymmetric frustum is
aligned to the moving glass and clipped at that plane. The shader derives full
glass coordinates from local vertex positions instead of using a BoxMesh's
six-face UV atlas. PlanarMirrorShot checks reflected coloured objects at their
analytically predicted positions from both sides; BathLavatoryTest captures the
installed mirror, fixtures and plumbing. Neither suite promotes spatial evidence.
