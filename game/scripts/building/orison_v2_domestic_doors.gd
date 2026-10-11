extends RefCounted
static var _knob_mesh: Mesh
static var _hinge_meshes: Dictionary = {}
## Reuse production leaves at the semantic opening's hinge, retaining its frame.
const SPECS := {
	"F01_INNER_DOOR": {"kind": "apartment_interior", "swing_out": true, "unit": ""},
	"F01_REAR_SERVICE_DOOR": {"kind": "service", "swing_out": true, "unit": ""},
	"F01_WATCH_MAIL_DOOR": {"kind": "service", "swing_out": false, "unit": ""},
	"F01_MAIL_PACKAGE_DOOR": {"kind": "service", "swing_out": false, "unit": ""},
	"F01_PACKAGE_COMMON_DOOR": {"kind": "apartment_interior", "swing_out": false, "unit": ""},
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
	if _knob_mesh==null:
		var source := (preload("res://assets/props/door_knob_set.glb") as PackedScene).instantiate()
		_knob_mesh=(source.find_child("KnobSet",true,false) as MeshInstance3D).mesh
		source.free()
	if _hinge_meshes.is_empty():
		var source := (preload("res://assets/props/door_butt_hinge.glb") as PackedScene).instantiate()
		for part in source.get_children():
			if part is MeshInstance3D: _hinge_meshes[str(part.name)]=part.mesh
		source.free()
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
		var door: OrisonV2FittedDoor = (preload("res://scripts/building/orison_v2_vestibule_door.gd").new()
				if identity=="F01_INNER_DOOR" else OrisonV2FittedDoor.new())
		if str(record.level)=="ROOF": door.open_stop_degrees=100.0
		if identity=="B1_SHOP_STAIR_DOOR": door.open_stop_degrees=85.0
		door.knob_mesh=_knob_mesh
		door.hinge_meshes=_hinge_meshes
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
		if door.door_kind == "apartment_entry" and not door.unit.is_empty():
			var hall_side := _hall_side(door, record, layout)
			_add_unit_numeral(door, hall_side)
			_add_chain_guard(door, hall_side)
			if str(specs[identity].get("leaf_notice", "")) == "corrected":
				_add_corrected_notice(door, hall_side)
	return true

## Which leaf face looks into the hall: +1 for the leaf's +z face, -1 for -z,
## from the centre of the connected space that is not the vestibule.
func _hall_side(door: OrisonV2FittedDoor, record: Dictionary, layout: Dictionary) -> float:
	var leaf := door.get_node_or_null("HingedLeaf") as Node3D
	if leaf == null: return 1.0
	var hall_side := 1.0
	for space_id: Variant in record.get("connects", []):
		if str(space_id).contains("_VESTIBULE") or str(space_id).contains("_RESTRICTED"): continue
		for space: Dictionary in layout.get("spaces", []):
			if str(space.get("id", "")) != str(space_id): continue
			var rect: Array = space.rect
			var centre := door.get_parent_node_3d().to_global(Vector3.ZERO)
			centre.x = (float(rect[0]) + float(rect[2])) * 0.5
			centre.z = (float(rect[1]) + float(rect[3])) * 0.5
			var root := door.get_parent_node_3d()
			while root.get_parent_node_3d() != null and not root.is_in_group("orison_v2_blockout"): root = root.get_parent_node_3d()
			var local := leaf.to_local(root.to_global(Vector3(centre.x, 1.6, centre.z)))
			hall_side = -1.0 if local.z < 0.0 else 1.0
	return hall_side

## Enamel unit-numeral plate on the hall face of every apartment entry leaf
## (dossier BW-022). The leaf swings with it; lettering is a single-sided Label3D.
func _add_unit_numeral(door: OrisonV2FittedDoor, hall_side: float) -> void:
	var leaf := door.get_node_or_null("HingedLeaf") as Node3D
	if leaf == null: return
	var plate := MeshInstance3D.new()
	plate.name = "UnitNumeralPlate"
	var box := BoxMesh.new()
	box.size = Vector3(0.13, 0.09, 0.004)
	box.material = MatLib.get_mat("porcelain_fixture", Color(0.95, 0.93, 0.86))
	plate.mesh = box
	# The slab sits at the hinge setback in the body frame (apply_hinge_setback ran in
	# _ready). DoorProp._build_domestic lays the upper panel bed 0.006 m thick at
	# 0.025 m off the slab centre, so the painted face under the plate is at 0.028;
	# the plate seats on that bed, inside the rails that stand at 0.040.
	var slab_z: float = float(door.get("_hinge_offset"))
	var face_z := slab_z + hall_side * 0.028
	plate.position = Vector3(door.width * 0.5, 1.6, face_z + hall_side * 0.0025)
	leaf.add_child(plate)
	var numeral := Label3D.new()
	numeral.name = "UnitNumeral"
	numeral.text = door.unit
	numeral.font_size = 88
	numeral.pixel_size = 0.0007
	numeral.modulate = Color(0.09, 0.12, 0.26)
	numeral.outline_size = 0
	numeral.double_sided = false
	numeral.position = Vector3(door.width * 0.5, 1.6, face_z + hall_side * 0.006)
	numeral.rotation.y = 0.0 if hall_side > 0.0 else PI
	leaf.add_child(numeral)

## Dossier slice 68 (F01_A_VESTIBULE-003): the building's notice pinned inside the entry leaf at 1.5 m, a
## correction slip pinned over its lower half and one red pencil line struck through it. Blank cards, no
## lettering. Off-centre on the upper panel bed, clear of the viewer and the knob; it swings with the leaf.
func _add_corrected_notice(door: OrisonV2FittedDoor, hall_side: float) -> void:
	var leaf := door.get_node_or_null("HingedLeaf") as Node3D
	if leaf == null: return
	var inside := -hall_side
	var bed: float = float(door.get("_hinge_offset")) + inside * 0.028
	var x := door.width * 0.5 - 0.17
	var notice := Node3D.new()
	notice.name = "CorrectedNotice"
	leaf.add_child(notice)
	for piece: Array in [
			["Notice", Vector3(0.21, 0.28, 0.0015), Vector3(x, 1.5, bed + inside * 0.00075), 0.0, MatLib.get_mat("paper", Color(0.93, 0.90, 0.82))],
			["Correction", Vector3(0.15, 0.055, 0.0015), Vector3(x + 0.01, 1.44, bed + inside * 0.00225), 0.04, MatLib.get_mat("paper", Color(0.98, 0.96, 0.89))],
			["PencilLine", Vector3(0.11, 0.0025, 0.0005), Vector3(x - 0.01, 1.56, bed + inside * 0.0018), -0.02, MatLib.get_mat("enamel", Color(0.62, 0.08, 0.06))]]:
		var mesh := BoxMesh.new()
		mesh.size = piece[1]
		mesh.material = piece[4]
		var part := MeshInstance3D.new()
		part.name = piece[0]
		part.mesh = mesh
		part.position = piece[2]
		part.rotation.z = float(piece[3])
		notice.add_child(part)
	for at: Vector3 in [Vector3(x - 0.09, 1.625, 0), Vector3(x + 0.09, 1.625, 0), Vector3(x + 0.07, 1.455, 0)]:
		var pin := MeshInstance3D.new()
		pin.name = "Pin"
		var head := CylinderMesh.new()
		head.top_radius = 0.005
		head.bottom_radius = 0.005
		head.height = 0.003
		head.radial_segments = 10
		head.material = MatLib.get_mat("brass_dull", Color(0.80, 0.70, 0.50))
		pin.mesh = head
		pin.rotation.x = PI * 0.5
		pin.position = Vector3(at.x, at.y, bed + inside * 0.004)
		notice.add_child(pin)

## Chain door guard on the apartment face of every entry leaf (dossier
## F0x_x_VESTIBULE-002): a brass slotted plate by the latch stile, the anchor
## plate beside it with its chain hanging unhooked. Passive, no owner.
func _add_chain_guard(door: OrisonV2FittedDoor, hall_side: float) -> void:
	var leaf := door.get_node_or_null("HingedLeaf") as Node3D
	if leaf == null: return
	var flat_side := -hall_side
	var slab_z: float = float(door.get("_hinge_offset"))
	var face_z := slab_z + flat_side * 0.028
	var brass := MatLib.get_mat("brass_dull", Color(0.80, 0.70, 0.50))
	var guard := Node3D.new()
	guard.name = "ChainGuard"
	leaf.add_child(guard)
	var slot := MeshInstance3D.new()
	slot.name = "SlottedPlate"
	var slot_mesh := BoxMesh.new()
	slot_mesh.size = Vector3(0.085, 0.026, 0.004)
	slot_mesh.material = brass
	slot.mesh = slot_mesh
	slot.position = Vector3(door.width - 0.16, 1.55, face_z + flat_side * 0.002)
	guard.add_child(slot)
	var anchor_plate := MeshInstance3D.new()
	anchor_plate.name = "AnchorPlate"
	var anchor_mesh := BoxMesh.new()
	anchor_mesh.size = Vector3(0.036, 0.04, 0.004)
	anchor_mesh.material = brass
	anchor_plate.mesh = anchor_mesh
	anchor_plate.position = Vector3(door.width - 0.06, 1.55, face_z + flat_side * 0.002)
	guard.add_child(anchor_plate)
	# The unhooked chain hangs from the anchor plate: four short links read as
	# a chain at arm's length without a chain mesh.
	for index in 4:
		var link := MeshInstance3D.new()
		link.name = "Link%d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.004
		mesh.bottom_radius = 0.004
		mesh.height = 0.034
		mesh.radial_segments = 8
		mesh.material = brass
		link.mesh = mesh
		link.position = Vector3(door.width - 0.06 - 0.004 * index, 1.53 - 0.03 * index - 0.017, face_z + flat_side * 0.009)
		link.rotation.z = 0.12
		guard.add_child(link)
