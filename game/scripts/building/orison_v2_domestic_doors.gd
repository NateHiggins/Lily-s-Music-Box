extends RefCounted
## Reuse production leaves at the semantic opening's hinge, retaining its frame.
const SPECS := {
	"ROOF_PUBLIC_DOOR": {"kind": "service", "swing_out": false, "unit": ""},
	"ROOF_SERVICE_DOOR": {"kind": "service", "swing_out": false, "unit": ""},
	"F03_DOOR_02": {"kind": "apartment_entry", "swing_out": false, "unit": "3A"},
	"F03_A_HALL_DOOR": {"kind": "apartment_interior", "swing_out": true, "unit": "3A"},
	"F03_A_BATH_DOOR": {"kind": "apartment_interior", "swing_out": true, "unit": "3A"},
	"F03_A_BED_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "3A"},
	"F04_DOOR_02": {"kind": "apartment_entry", "swing_out": true, "unit": "4A"},
	"F04_A_KITCHEN_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "4A"},
	"F04_A_BED_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "4A"},
	"F04_A_BATH_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "4A"},
	"F02_DOOR_02": {"kind": "apartment_entry", "swing_out": false, "unit": "2A"},
	"F02_A_HALL_DOOR": {"kind": "apartment_interior", "swing_out": true, "unit": "2A"},
	"F02_A_BATH_DOOR": {"kind": "apartment_interior", "swing_out": true, "unit": "2A"},
	"F02_A_BED_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "2A"},
	"F02_B_ENTRY_DOOR": {"kind": "apartment_entry", "swing_out": true, "unit": "2B"},
	"F02_B_KITCHEN_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "2B"},
	"F02_B_BED_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "2B"},
	"F02_B_BATH_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "2B"},
	"B1_LAUNDRY_DOOR": {"kind": "service", "swing_out": false, "unit": ""},
	"F04_DOOR_03": {"kind": "apartment_entry", "swing_out": false, "unit": "4B"},
	"F04_B_CLOSET_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "4B"},
	"F04_B_HALL_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "4B"},
	"F04_B_BATH_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": "4B"},
	"F03_DOOR_03": {"kind": "apartment_entry", "swing_out": true},
	"F03_B_SERVICE_DOOR": {"kind": "service", "swing_out": true},
	"F03_B_ALCOVE_DOOR": {"kind": "apartment_interior", "swing_out": false},
	"F03_B_BATH_DOOR": {"kind": "apartment_interior", "swing_out": false},
}

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	return mount_specs(adapter, layout, SPECS)

func mount_specs(adapter: OrisonV2AnchorAdapter, layout: Dictionary, specs: Dictionary) -> bool:
	var records: Dictionary = {}
	for record: Dictionary in layout.doors:
		if not specs.has(str(record.id)): continue
		var anchor := adapter.resolve(str(record.id)) as Node3D
		if records.has(record.id) or anchor == null or anchor.get_node_or_null("Hinge") == null:
			return false
		if record.hinge not in ["left", "right"] or float(record.width) <= 0.1 or float(record.height) <= 1.5:
			return false
		records[record.id] = record
	if records.size() != specs.size(): return false
	for identity: String in records:
		var record: Dictionary = records[identity]
		var anchor := adapter.resolve(identity) as Node3D
		var placeholder := anchor.get_node("Hinge")
		anchor.remove_child(placeholder)
		placeholder.free()
		var door := DoorProp.new()
		door.name = identity + "_Leaf"
		door.width = float(record.width)
		door.height = float(record.height)
		door.door_kind = str(specs[identity].kind)
		var right_hinge: bool = str(record.hinge) == "right"
		# DoorProp extends along local +X. A half-turn places a right-hung
		# leaf across the same opening without negative physics scale.
		# Reverse its local swing so the opening's authored side is retained.
		door.swing_out = not bool(specs[identity].swing_out) if right_hinge else bool(specs[identity].swing_out)
		door.unit = str(specs[identity].get("unit","3B"))
		door.leaf_state = str(specs[identity].get("leaf_state", "closed"))
		door.position.x = door.width * 0.5 if right_hinge else -door.width * 0.5
		door.position.z = float(specs[identity].get("mount_offset", 0.0))
		door.rotation.y = PI if right_hinge else 0.0
		door.set_meta("semantic_id", identity)
		anchor.add_child(door)
	return true
