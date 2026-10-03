# V2 sliding lift door leaves

Evidence class: **INERT**

Rebuild with `blender -b -P art/blender/scripts/build_lift_panels.py`.
The editable **art/blender/lift_panels.blend** keeps separate fabrication
parts; **game/assets/props/lift_panels.glb** exports two handed steel leaves
and a shared kick plate. Rounded edges, shallow pressed fields, two-sided
glazing bezels and grooved kick plates replace the primitive visuals.

Each leaf has a real Boolean-cut vision aperture. The old glass rectangles
were laid over an unbroken steel box. The existing glass material now fills
the opening with a 6 mm pane and does not cast an opaque shadow. The aperture
is visual; its narrow glazing remains part of the closed physical barrier.

The production elevator exposes direct references to each moving body's
three existing visuals. V2 replaces their meshes and preserves materials,
travel, stop ownership, interlocks, interaction and all collision shapes.
The original 500 mm colliders still overlap at closure. The visible leaves
are 478 mm wide around the existing 480 mm center separation, producing a
2 mm meeting seam instead of 20 mm of overlapping coplanar steel. Bezels
stay within the previous visual depth envelope. No material keys, textures,
saved fields or additional runtime mesh nodes are introduced.

OrisonV2LiftPanelsTest checks all fourteen leaves, seventy rays against
actual imported triangles through the vision openings, solid-steel controls,
fourteen physics barrier hits, glazing bounds and the closed meeting seam.
Windowed captures show open/closed production landings and a glazing detail
under neutral fill. The existing elevator route suite checks ordinary input,
seven passenger stops, hall exits, shaft-barrier contact and hall recall.
Logs and suite-run receipts are under **tmp/lift-panels**; this reference
does not promote the runtime completeness ledger.
