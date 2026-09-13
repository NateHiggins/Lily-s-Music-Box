# Arcade ceiling detail from owner references

The owner supplied `arcadeceiling1.png` and `arcadeceiling2.png` from Downloads
on September 13, 2026, asking that their details inspire the arcade ceiling.
Unmodified reference copies and hashes are retained under
`art/references/arcade_ceiling` and in `game/data/orison_v2/arcade_ceiling_source.json`.

The adaptation uses turquoise enameled open geometric panels, warm brass frames,
three stepped ochre edge mouldings and two compact fan crowns. It follows the
existing ten-facet glass barrel instead of reproducing the photographs' flat
ceiling. The panels fit between the original transverse ribs; the central
crossing lantern and clock remain open. The fan crowns attach to solid plaster
above the south lunette. Nothing projects a photograph onto the building.

`tools/build_v2_arcade_ceiling.py` generates a V2-specific passage glTF, keeping
all 31 original meshes, their materials and collision ownership intact. Existing
binary geometry and textures remain external referenced resources. The added
geometry has 100 open-work panels and 22,344 triangles in three material batches,
with existing enamel, brass and plaster texture sets. It adds no light nodes or
collision bodies; its dimensional relief can participate in ordinary mesh
shadow rendering. Lamp/voxel behavior and appearance remain unverified.

Initial loading and threaded residency use the same cell-path owner, ensuring
that the detailed ceiling is included when the passage is reconstructed. The
existing residency engine test now requires all three detail batches and their
architectural surface materials before and after reconstruction. This test was
syntax parsed, not executed.

`tools/check_v2_arcade_ceiling.py` passes source checks for roof-rib, lantern and
lunette clearance; solid gable support; deterministic regeneration; external
resource existence; buffer lengths; emitted triangle winding; and three script
syntax parses. Deliberately shifted details are rejected for rib and lantern
overlap. Exact artifact hashes are in `checks.json`.

`geometry_study.png` is a flat-colour drawing of eight actual generated panels.
It is a geometry preview, not a Godot screenshot or an approved lighting result.
Godot remains paused under the owner's standing instruction. Import/compilation,
night and daylight appearance, flashlight shadows, draw cost and residency
execution remain pending. V1 remains the default; no broader V2 completion is
claimed by this ceiling pass.
