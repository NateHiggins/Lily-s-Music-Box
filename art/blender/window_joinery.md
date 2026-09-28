# V2 complete window joinery

Evidence class: **INERT**

**art/blender/scripts/build_window_joinery.py** generates the editable
**art/blender/window_joinery.blend** and **game/assets/props/window_joinery.glb**.
All 72 V2 window openings gain complete rebated jambs and heads, two framed
sash fields, a meeting rail and projecting sill noses. The existing opening
width, height, sill, axis and installed wall thickness place the shared mesh.
The wood retains the existing jamb material and fits the masonry reveal.
The current space-outline builder uses partition-wall depth even for these
exterior openings; the joinery follows that owner rather than the unused
outer-wall dimension. A shaft/court window also intersects the west wet chase:
the chase now retains solid visual and collision sections around its declared
aperture, instead of sealing the window behind a full-height box. Its deeper
reveal fits the combined wall/chase depth. No service anchors or pipe routes
move. Changing general building wall thickness is outside this batch.

The original glazing mesh and material remain visible and authoritative;
only the two primitive jamb visuals are hidden. No window operation, collision
barrier, opening dimension or save state is added. The chase aperture correction
also applies to standalone blockout; Blender framing is production-only and V1
is unchanged. This batch supplies framing, not operable sashes.

OrisonV2WindowJoineryTest checks 72 installed meshes, both sash apertures,
head/meeting/bottom rails, 144 unobstructed aperture rays and 288 actual wall-face
probes, with rendered views
for both plan axes and exterior directions. The existing blockout, upper-floor
and title suites cover composition. Captures use inspection fill. Logs and
suite-run receipts live under **tmp/window-joinery**. No runtime-contract or
completeness-ledger promotion is claimed.
