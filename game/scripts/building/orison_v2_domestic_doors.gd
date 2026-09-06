extends RefCounted
## Reuse production leaves at the semantic opening's hinge, retaining its frame.
const SPECS := {
	"F03_DOOR_03": {"kind": "apartment_entry", "swing_out": true},
	"F03_B_SERVICE_DOOR": {"kind": "service", "swing_out": true},
	"F03_B_ALCOVE_DOOR": {"kind": "apartment_interior", "swing_out": false},
	"F03_B_BATH_DOOR": {"kind": "apartment_interior", "swing_out": false},
}

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary) -> bool:
	var records: Dictionary = {}
	for record: Dictionary in layout.doors:
		if not SPECS.has(str(record.id)): continue
		var anchor := adapter.resolve(str(record.id)) as Node3D
		if records.has(record.id) or anchor == null or anchor.get_node_or_null("Hinge") == null:
			return false
		if record.hinge != "left" or float(record.width) <= 0.1 or float(record.height) <= 1.5:
			return false
		records[record.id] = record
	if records.size() != SPECS.size(): return false
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
		door.door_kind = str(SPECS[identity].kind)
		door.swing_out = bool(SPECS[identity].swing_out)
		door.unit = "3B"
		door.position.x = -door.width * 0.5
		door.set_meta("semantic_id", identity)
		anchor.add_child(door)
	return true
