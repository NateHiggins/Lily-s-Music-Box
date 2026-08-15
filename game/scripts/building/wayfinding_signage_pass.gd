class_name WayfindingSignagePass
extends Node3D
## Period brass wayfinding with modern life-safety information nested inside.
## Unit assignments come from case definitions and doors from live geometry;
## the sign system therefore cannot drift away from the playable layout.

const BRASS_TEXTURE := preload("res://assets/building/textures/signage/aged_brass_quadrants_v1.png")
## Engraved legends, baked into the metal by build_signage_plates.py.
## Unit numbers used to be Label3D floating in front of a brass
## rectangle, which is why they read as a debug overlay: no engraving,
## no depth, and a baseline answering to Godot rather than the plate.
const PLATE_ATLAS := preload("res://assets/building/textures/signage/engraved_plates.png")
const PLATE_COLS := 6
const PLATE_ROWS := 6
var _plate_index: Dictionary = {}


## One plate off the atlas, as its own small textured quad.
func _plate(parent: Node3D, legend: String, at: Vector3,
		size: Vector2) -> MeshInstance3D:
	if _plate_index.is_empty():
		var f := FileAccess.open("res://data/signage_plates.json",
				FileAccess.READ)
		if f:
			var doc: Dictionary = JSON.parse_string(f.get_as_text())
			_plate_index = doc.get("index", {})
	if not _plate_index.has(legend):
		return null
	var cell: Array = _plate_index[legend]
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PLATE_ATLAS
	mat.uv1_scale = Vector3(1.0 / PLATE_COLS, 1.0 / PLATE_ROWS, 1.0)
	mat.uv1_offset = Vector3(float(cell[0]) / PLATE_COLS,
			float(cell[1]) / PLATE_ROWS, 0.0)
	mat.roughness = 0.38
	mat.metallic = 0.65
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
const LEVELS := {"B1":-2.8, "F01":0.0, "F02":3.2, "F03":6.4,
	"F04":9.6, "F05":12.8, "F06":16.0, "ROOF":19.2}

var _brass: StandardMaterial3D
var _dark_brass: StandardMaterial3D
var _enamel: StandardMaterial3D
var _luminous: StandardMaterial3D
var _bell: AudioStreamPlayer3D
var _bell_button: MeshInstance3D
var _bell_button_rest := Vector3.ZERO
var _bell_tween: Tween
var _last_bell_state := "READY"
var apartment_numbers := 0
var floor_directories := 0
var fire_signs := 0
var _numbered_doors := {}


func build(world: Node3D) -> Dictionary:
	name = "WayfindingSignage"
	_build_materials()
	_build_apartment_numbers(world)
	_build_floor_directories()
	_build_fire_directions()
	_build_front_directory()
	print("[WAYFINDING] %d brass unit numbers, %d directories, %d fire signs"
			% [apartment_numbers, floor_directories, fire_signs])
	return {"numbers":apartment_numbers, "directories":floor_directories,
			"fire_signs":fire_signs}


func _build_materials() -> void:
	_brass = _metal(Color(0.72, 0.49, 0.18), 0.76, 0.35)
	_brass.albedo_texture = _quadrant(Rect2(0, 0, 628, 628))
	_dark_brass = _metal(Color(0.30, 0.21, 0.11), 0.68, 0.52)
	_dark_brass.albedo_texture = _quadrant(Rect2(628, 628, 628, 628))
	_enamel = _metal(Color(0.055, 0.075, 0.068), 0.08, 0.46)
	_luminous = _metal(Color(0.76, 0.88, 0.58), 0.0, 0.7)
	_luminous.emission_enabled = true
	_luminous.emission = Color(0.22, 0.44, 0.14)
	_luminous.emission_energy_multiplier = 0.22


func _quadrant(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = BRASS_TEXTURE
	atlas.region = region
	return atlas


func _build_apartment_numbers(world: Node3D) -> void:
	var used := {}
	for case_id in RealityCases.definitions:
		var definition := RealityCases.definition(case_id)
		var unit: String = definition.get("unit", "")
		if unit.is_empty() or used.has(unit):
			continue
		used[unit] = true
		var controller: ApartmentRealityController = world.reality_controllers.get(case_id)
		if controller == null:
			continue
		var door := _nearest_apartment_door(controller)
		if door == null:
			continue
		_add_unit_plaque(door, unit)
		_numbered_doors[door] = unit
		door.set_meta("apartment_unit", unit)
		apartment_numbers += 1


func _nearest_apartment_door(controller: ApartmentRealityController) -> DoorProp:
	var center := (controller.room_min + controller.room_max) * 0.5
	var nearest: DoorProp
	var best := 999.0
	for candidate in get_tree().get_nodes_in_group("apartment_doors"):
		if not candidate is DoorProp:
			continue
		var door := candidate as DoorProp
		if _numbered_doors.has(door):
			continue
		if absf(door.global_position.y - center.y) > 1.6:
			continue
		var distance := door.global_position.distance_to(center)
		if distance < best:
			best = distance
			nearest = door
	return nearest


func _add_unit_plaque(door: DoorProp, unit: String) -> void:
	var root := Node3D.new()
	root.name = "BrassApartmentNumber_" + unit
	root.position = Vector3(door.width + 0.13, 1.48, 0.0)
	door.add_child(root)
	_box(root, Vector3(0.19, 0.13, 0.018), Vector3.ZERO, _dark_brass)
	_add_screws(root, 0.075, 0.045)
	# The number IS the plate now, not a caption in front of one.
	if _plate(root, unit, Vector3(0, 0, 0.0102),
			Vector2(0.155, 0.105)) == null:
		_label(root, unit, Vector3(0, 0, 0.013), 46, 0.00125,
				Color(0.94, 0.74, 0.30), true)
	# Smoke-level responder marking: intentionally newer and less elegant.
	var low := Node3D.new()
	low.position = Vector3(door.width + 0.065, 0.19, 0.0)
	door.add_child(low)
	_box(low, Vector3(0.09, 0.065, 0.008), Vector3.ZERO, _luminous)
	_label(low, unit, Vector3(0, 0, 0.008), 25, 0.0010,
			Color(0.05, 0.09, 0.035), true)
	# Four screw heads and a backplate used to remain five separate shadow
	# submissions on every entry door. The typed face keeps its own atlas
	# material; the fixed brass behind it is one surface.
	StaticMeshBatcher.merge(root)


func _build_floor_directories() -> void:
	var residents := _resident_rows()
	for floor_index in range(1, 7):
		var fid := "F%02d" % floor_index
		var rows: Array = residents.get(str(floor_index), [])
		var panel := Node3D.new()
		panel.name = "FloorDirectory_" + fid
		panel.position = GameBoot.b2g([-4.94, 5.56, LEVELS[fid] + 1.42])
		panel.rotation.y = PI
		add_child(panel)
		_directory_panel(panel, "FLOOR %d" % floor_index, rows, false)
		floor_directories += 1
	# Cellar directory belongs to workers and firefighters, not tenants.
	var cellar := Node3D.new()
	cellar.name = "FloorDirectory_B1"
	cellar.position = GameBoot.b2g([-4.94, 5.56, LEVELS.B1 + 1.42])
	cellar.rotation.y = PI
	add_child(cellar)
	_directory_panel(cellar, "CELLAR", [["BOILER", "EAST"],
			["LAUNDRY", "WEST"], ["MAINT.", "LOBBY"]], false)
	floor_directories += 1


func _resident_rows() -> Dictionary:
	var rows := {}
	for case_id in RealityCases.definitions:
		var d := RealityCases.definition(case_id)
		var unit: String = d.get("unit", "")
		if unit.is_empty():
			continue
		var floor := unit.left(1)
		if not rows.has(floor): rows[floor] = []
		rows[floor].append([unit, str(d.get("resident", "OCCUPIED")).to_upper()])
	for floor in rows:
		rows[floor].sort_custom(func(a, b): return a[0] < b[0])
	return rows


func _directory_panel(root: Node3D, title: String, rows: Array,
		with_buttons: bool) -> void:
	var height := 0.23 + rows.size() * 0.072
	_box(root, Vector3(0.66, height, 0.035), Vector3.ZERO, _dark_brass)
	_box(root, Vector3(0.57, height - 0.10, 0.012), Vector3(0, -0.015, 0.026), _enamel)
	_label(root, title, Vector3(0, height * 0.5 - 0.052, 0.038), 24,
			0.00115, Color(0.91, 0.73, 0.37))
	var top := height * 0.5 - 0.125
	for index in rows.size():
		var row: Array = rows[index]
		var y := top - index * 0.072
		_box(root, Vector3(0.49, 0.052, 0.008), Vector3(-0.018, y, 0.038),
				_metal(Color(0.74, 0.70, 0.58), 0.0, 0.82))
		_label(root, "%s   %s" % [row[0], row[1]], Vector3(-0.23, y, 0.044),
				15, 0.00088, Color(0.10, 0.085, 0.06), false,
				HORIZONTAL_ALIGNMENT_LEFT)
		if with_buttons:
			var button := _cylinder(root, 0.015, 0.018,
					Vector3(0.275, y, 0.052), _brass)
			# One assembly-level interaction owns the call circuit. Keep one
			# actual button separate as its physical response instead of adding
			# eighteen duplicate gameplay targets to the directory.
			if index == rows.size() / 2:
				_bell_button = button
				_bell_button_rest = button.position
	_add_screws(root, 0.295, height * 0.5 - 0.025)


func _build_fire_directions() -> void:
	for fid in LEVELS:
		var level: float = LEVELS[fid]
		var sign := Node3D.new()
		sign.name = "FireDirection_" + fid
		sign.position = GameBoot.b2g([4.98, 2.92, level + 1.45])
		sign.rotation.y = -PI * 0.5
		add_child(sign)
		_box(sign, Vector3(0.62, 0.34, 0.022), Vector3.ZERO, _dark_brass)
		_box(sign, Vector3(0.55, 0.27, 0.010), Vector3(0, 0, 0.017), _enamel)
		var floor_text := "ROOF LANDING" if fid == "ROOF" else \
				("CELLAR" if fid == "B1" else "FLOOR %d" % int(fid.right(2)))
		_label(sign, floor_text, Vector3(0, 0.105, 0.031), 18, 0.0010,
				Color(0.90, 0.74, 0.40))
		_label(sign, "←  FIRE EXIT — STAIRS", Vector3(0, 0.025, 0.031), 21,
				0.0010, Color(0.86, 0.93, 0.72))
		_label(sign, "STREET LEVEL ↓", Vector3(0, -0.055, 0.031), 17,
				0.0010, Color(0.86, 0.93, 0.72))
		_label(sign, "DO NOT USE ELEVATOR", Vector3(0, -0.115, 0.031), 13,
				0.0009, Color(0.76, 0.30, 0.24))
		fire_signs += 1


func _build_front_directory() -> void:
	var rows: Array = []
	var resident_rows := _resident_rows()
	for floor in resident_rows:
		rows.append_array(resident_rows[floor])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	var panel := Node3D.new()
	panel.name = "FrontResidentDirectoryAndBuzzer"
	panel.position = GameBoot.b2g([-1.13, -9.91, 1.38])
	add_child(panel)
	panel.scale = Vector3(0.82, 0.82, 0.82)
	_directory_panel(panel, "RESIDENTS — RING ONCE", rows, true)
	var area := Area3D.new()
	area.name = "DirectoryDoorbellArea"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.68, 1.60, 0.10)
	shape_node.shape = shape
	area.add_child(shape_node)
	panel.add_child(area)
	_bell = AudioStreamPlayer3D.new()
	_bell.stream = PropAudio.get_stream("bell")
	_bell.volume_db = -16.0
	_bell.max_distance = 18.0
	panel.add_child(_bell)


func interact_area(area: Area3D) -> Dictionary:
	if area.name != "DirectoryDoorbellArea" or _bell == null:
		return {}
	_press_directory_button()
	if not _bell.playing:
		_bell.pitch_scale = 0.88
		_bell.play()
		_last_bell_state = "SOUNDED"
	else:
		_last_bell_state = "STILL RINGING"
	return service_wire_card()


func interact_prompt() -> String:
	return "[E]  Ring directory buzzer"


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("buzzer", {
		"button_state": "RETURNING" if _bell_tween \
				and _bell_tween.is_running() else "READY",
		"bell_state": _last_bell_state,
	})


func _press_directory_button() -> void:
	if _bell_button == null:
		return
	if _bell_tween and _bell_tween.is_valid():
		_bell_tween.kill()
	_bell_button.position = _bell_button_rest
	_bell_tween = create_tween()
	_bell_tween.tween_property(_bell_button, "position:z",
			_bell_button_rest.z - 0.009, 0.055)
	_bell_tween.tween_property(_bell_button, "position:z",
			_bell_button_rest.z, 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = at
	node.rotation_degrees.x = 90
	node.material_override = material
	parent.add_child(node)
	return node


func _add_screws(root: Node3D, x: float, y: float) -> void:
	for corner in [Vector2(-x, -y), Vector2(x, -y), Vector2(-x, y), Vector2(x, y)]:
		_cylinder(root, 0.009, 0.009, Vector3(corner.x, corner.y, 0.032), _brass)


func _label(parent: Node3D, text: String, at: Vector3, font_size: int,
		pixel_size: float, color: Color, double_sided := false,
		alignment := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 1
	label.outline_modulate = Color(0.025, 0.02, 0.012, 0.8)
	label.horizontal_alignment = alignment
	label.double_sided = double_sided
	parent.add_child(label)
	return label
