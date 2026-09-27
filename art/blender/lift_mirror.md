# V2 lift mirror

Evidence class: **INERT**

**art/blender/scripts/build_lift_mirror.py** produces the editable
**art/blender/lift_mirror.blend** and **game/assets/props/lift_mirror.glb**.
The oak surround is a continuous mitered profile with a real glass opening,
recessed groove and inner bead. Its back seats on the existing car wall.
The runtime pane sits inside the recess and moves with the production car.

The lift uses the existing PlanarMirrorRenderer and its one borrowed view.
Surface ownership is resolved through the mirror methods instead of assuming
a medicine-cabinet parent hierarchy. Cabinets retain the same selection,
projection, fallback and lifecycle. Mirror glass stays excluded from the
reflected camera, preventing recursive reflections. No new viewport is added
per lift or bathroom. V1 keeps its original cab presentation.

OrisonV2LiftMirrorTest samples analytic reflected pixel locations from three
eye positions and after a production lift ride, checks the single-view budget,
handoff to an installed bathroom mirror and inactive fallback, and captures
the actual cab. PlanarMirrorShot retains
the independent bathroom projection regression. Receipts and captures live
under **tmp/lift-mirror**; this is not runtime-contract ledger promotion.
