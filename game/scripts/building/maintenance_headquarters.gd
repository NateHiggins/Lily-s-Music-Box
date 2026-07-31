class_name MaintenanceHeadquarters
extends Node3D
## Persistent home base in the first-floor office.  The room deliberately
## derives its display state from resolved cases, so it never needs a second
## progression save or a parallel definition of what "finished" means.

const PLAQUE_TEXTURE := \
		"res://assets/building/textures/maintenance_hq/reality_maintenance_brass_plaque.png"
const GEAR := [
	{"name": "Inspection light", "threshold": 0, "kind": "light"},
	{"name": "Ontological tape", "threshold": 1, "kind": "tape"},
	{"name": "Resonance fork", "threshold": 3, "kind": "fork"},
	{"name": "Seam stapler", "threshold": 5, "kind": "stapler"},
	{"name": "Survey prism", "threshold": 8, "kind": "prism"},
	{"name": "Orison master key", "threshold": 12, "kind": "key"},
]

var _trophies: Dictionary = {}
var _gear_visuals: Array[Node3D] = []
var _status: Label3D
var _resolved_count := 0


func _ready() -> void:
	name = "RealityMaintenanceHeadquarters"
	add_to_group("maintenance_headquarters")
	_build_plaque()
	_build_workbench()
	_build_gear_wall()
	_build_case_wall()
	RealityCases.case_changed.connect(_on_case_changed)
	RealityState.state_changed.connect(_refresh)
	_refresh()
	print("[BUILDING] maintenance headquarters ready: %d trophy slots, %d gear tiers"
			% [_trophies.size(), GEAR.size()])


func resolved_trophy_count() -> int:
	return _resolved_count


func unlocked_gear_count() -> int:
	var count := 0
	for spec in GEAR:
		if _resolved_count >= int(spec.threshold):
			count += 1
	return count


func trophy_slot_count() -> int:
	return _trophies.size()


func interact_prompt() -> String:
	return "[E]  Review case wall — %d/%d resolved, %d/%d tools issued" % [
		_resolved_count, _trophies.size(), unlocked_gear_count(), GEAR.size()]


func interact(_player: Node) -> void:
	# The wall is intentionally readable without a modal UI. Interaction
	# briefly brightens its inventory label so the room acknowledges use.
	if _status == null:
		return
	_status.modulate = Color(0.92, 0.83, 0.52)
	var tween := create_tween()
	tween.tween_property(_status, "modulate",
			Color(0.72, 0.77, 0.70), 0.65)


func _build_plaque() -> void:
	# South wall of F01_OFFICE, facing into the room.  This is the title
	# concept used as an actual place marker rather than a detached poster.
	var pivot := Node3D.new()
	pivot.position = GameBoot.b2g([-11.76, 2.785, 1.72])
	pivot.rotation.y = PI
	add_child(pivot)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.72, 0.86)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(PLAQUE_TEXTURE)
	material.roughness = 0.56
	material.cull_mode = BaseMaterial3D.CULL_BACK
	var visual := MeshInstance3D.new()
	visual.mesh = quad
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(visual)
	# A shallow brass backing keeps the generated face grounded in the wall.
	_add_box([-11.76, 2.80, 1.72], [1.82, 0.035, 0.96],
			MatLib.get_mat("brass", Color(0.46, 0.38, 0.22)))
	var target := StaticBody3D.new()
	target.position = pivot.position
	target.rotation = pivot.rotation
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.82, 0.96, 0.08)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	target.add_child(collision)
	add_child(target)


func _build_workbench() -> void:
	var wood := MatLib.get_mat("wood_dark", Color(0.55, 0.45, 0.34))
	var metal := MatLib.get_mat("metal", Color(0.38, 0.40, 0.39))
	_add_box([-11.78, 4.98, 0.78], [2.55, 0.68, 0.11], wood)
	for x in [-12.88, -10.68]:
		_add_box([x, 4.98, 0.38], [0.10, 0.58, 0.76], metal)
	# Pegboard and two shelves establish the room at a glance.
	_add_box([-11.78, 5.285, 1.63], [2.62, 0.055, 1.36],
			MatLib.get_mat("trim", Color(0.30, 0.34, 0.29)))
	for z in [1.08, 2.18]:
		_add_box([-11.78, 5.22, z], [2.70, 0.28, 0.055], metal)


func _build_gear_wall() -> void:
	for index in GEAR.size():
		var spec: Dictionary = GEAR[index]
		var col := index % 3
		var row := index / 3
		var x := -12.54 + col * 0.76
		var z := 1.38 + row * 0.78
		var holder := Node3D.new()
		holder.name = "Gear_" + str(spec.name).to_snake_case()
		add_child(holder)
		_gear_visuals.append(holder)
		var color := Color(0.45, 0.56, 0.53).lightened(index * 0.025)
		match spec.kind:
			"light":
				_add_gear_cylinder(holder, [x, 5.13, z],
						Vector3(0.075, 0.28, 0.075), color)
			"tape":
				_add_gear_cylinder(holder, [x, 5.13, z],
						Vector3(0.13, 0.08, 0.13), color)
			"fork":
				_add_gear_box(holder, [x, 5.13, z],
						Vector3(0.07, 0.42, 0.07), color)
				_add_gear_box(holder, [x - 0.09, 5.13, z + 0.20],
						Vector3(0.07, 0.24, 0.07), color)
				_add_gear_box(holder, [x + 0.09, 5.13, z + 0.20],
						Vector3(0.07, 0.24, 0.07), color)
			"key":
				_add_gear_cylinder(holder, [x, 5.13, z + 0.12],
						Vector3(0.12, 0.05, 0.12), color)
				_add_gear_box(holder, [x, 5.13, z - 0.12],
						Vector3(0.055, 0.36, 0.055), color)
			_:
				_add_gear_box(holder, [x, 5.13, z],
						Vector3(0.25, 0.20, 0.30), color)


func _build_case_wall() -> void:
	# Eighteen compact brass sockets: one per authored resident case.  Empty
	# sockets remain visible, while a resolved case installs its colored token.
	var ids := RealityCases.definitions.keys()
	ids.sort()
	for index in ids.size():
		var case_id: String = ids[index]
		var col := index % 6
		var row := index / 6
		var x := -13.49
		var y := 3.02 + col * 0.40
		var z := 0.70 + row * 0.50
		_add_box([x, y, z], [0.045, 0.30, 0.32],
				MatLib.get_mat("brass", Color(0.25, 0.23, 0.18)))
		var token := MeshInstance3D.new()
		token.name = "Trophy_" + case_id
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.095
		mesh.bottom_radius = 0.095
		mesh.height = 0.035
		mesh.radial_segments = 12
		token.mesh = mesh
		token.position = GameBoot.b2g([x + 0.04, y, z])
		token.rotation.z = PI * 0.5
		var hue := fmod(float(index) * 0.137, 1.0)
		token.material_override = MatLib.get_mat(
				"porcelain", Color.from_hsv(hue, 0.38, 0.78))
		token.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(token)
		_trophies[case_id] = token
	_status = _label("CASE RESIDUE  00/%02d" % ids.size(),
			GameBoot.b2g([-13.40, 4.12, 2.37]), PI * 0.5, 22)


func _refresh() -> void:
	_resolved_count = 0
	for case_id in _trophies:
		var state := RealityState.case_state(case_id)
		var solved := bool(state.get("resolved", false))
		(_trophies[case_id] as Node3D).visible = solved
		if solved:
			_resolved_count += 1
	for index in _gear_visuals.size():
		_gear_visuals[index].visible = \
				_resolved_count >= int(GEAR[index].threshold)
	if _status:
		_status.text = "CASE RESIDUE  %02d/%02d   TOOLS  %02d/%02d" % [
			_resolved_count, _trophies.size(),
			unlocked_gear_count(), GEAR.size()]


func _on_case_changed(_case_id: String, _state: Dictionary) -> void:
	_refresh()


func _add_box(position_b: Array, size_b: Array,
		material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_b[0], size_b[2], size_b[1])
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = GameBoot.b2g(position_b)
	visual.material_override = material
	add_child(visual)
	return visual


func _add_gear_box(parent: Node3D, position_b: Array, size: Vector3,
		color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, size.z, size.y)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = GameBoot.b2g(position_b)
	visual.material_override = MatLib.get_mat("metal", color)
	parent.add_child(visual)


func _add_gear_cylinder(parent: Node3D, position_b: Array, size: Vector3,
		color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = size.x
	mesh.bottom_radius = size.x
	mesh.height = size.y
	mesh.radial_segments = 10
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = GameBoot.b2g(position_b)
	visual.material_override = MatLib.get_mat("metal", color)
	parent.add_child(visual)


func _label(text: String, at: Vector3, yaw: float, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.rotation.y = yaw
	label.font_size = font_size
	label.pixel_size = 0.0022
	label.modulate = Color(0.72, 0.77, 0.70)
	label.outline_size = 8
	label.outline_modulate = Color(0.015, 0.02, 0.018, 0.95)
	add_child(label)
	return label
