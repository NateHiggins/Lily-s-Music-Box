# 4B closet source integration

Mounted a 1 m equipment shelf inside the closet, using the existing
`asm_shelf` design and `3B_tools0` dimensions/settings with a distinct 4B
identity and anchor. Its 236 triangles retain oak shelves, metal supports and
the source's fixed equipment-container geometry. No inventory items or
container-opening interactions are implied or added.

The closet opening now uses DoorProp through DomesticDoors, retaining its
semantic frame, left hinge and 0.76 m opening. Its production leaf opens into
the hall. A flush-dome ceiling fixture uses its own existing SwitchSystem
circuit, with a switch outside the closet beside the opening.

Source checks pass for shelf containment, 0.45 m shelf-edge/stance separation,
estimated 100-degree leaf-sweep separation, repeatable extraction, unchanged
prior furniture/circuits, and GDScript syntax. Clearance calculations estimate
source geometry; they are not engine sweep tests. Initial fixture settings
use the existing flush-dome family and require visual tuning.

The earned wake harness checks shelf reconstruction, exactly the production
leaf replacing the old Hinge subtree, and direct switch toggle/restore. These
new checks have not run.

**No Godot launched, per owner instruction.** Pending engine work includes
entering the narrow closet with normal player input, door and switch targeting,
door swing/hardware clearance, shelf collision, material/light presentation,
and reconstruction/lifetime tests. Static shelf contents do not establish
interactive storage, and no saved door/switch state or room completion is
claimed.

The extraction script and source-hash receipt are in
`design/astra/work/v2_4b_closet_01`; its lighting data is recorded separately
in `lighting.json`.
