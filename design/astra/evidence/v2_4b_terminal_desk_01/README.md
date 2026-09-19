# 4B terminal support replacement: source pass

Replaced playable V2's `TerminalHomeContext` schematic blocks with a wooden
`4B_terminal_desk` through the existing furniture pipeline. The new assembly
has an oak top, dark wood legs and aprons, and 108 triangles. Its 0.58 x 1.25 m
footprint preserves the existing support footprint, and its top meets the
instrument anchor at 0.75 m above the floor. This is newly authored V2 support
geometry, not a recovered historical furniture asset.

The signal terminal, semantic identity, facing logic, CallInterface and
DeskZone remain unchanged. Playable V2 disables only the schematic workspace
geometry; standalone review defaults retain it. Existing development lighting
is unchanged, so this pass does not claim replacement of that lighting.

Source checks pass for repeatable generation, preservation of existing
furniture, clockwise winding, instrument base containment, matching top height,
0.56 m desk-edge/operator-stance separation and GDScript syntax. The earned
boundary harness checks that the reconstructed physical desk replaces the
placeholder group. These assertions have not run in Godot.

Rebuild with `python design/astra/work/v2_4b_terminal_desk_01/build.py`.
`assembly.json` records the explicit frame blocks and anchor.

**No Godot launched, per owner instruction.** The new desk is solid where the
schematic blocks were non-colliding. Player approach, terminal targeting,
seated/standing behavior, lifetime, wake reconstruction and actual material
presentation need engine validation. The furniture loader uses coarse box
collision; open leg geometry does not establish accessible knee space. No
terminal functionality, final visual acceptance or V2 completion is claimed.
