class_name RealityAffectedProp
extends Node3D
## Procedural placeholder for an object a resident's manifestation can seize.
## The catalog owns narrative identity and placement; this class supplies a
## cheap recognizable silhouette plus a shared affected-state language.

const PALETTE := [
	Color(0.42, 0.24, 0.16), Color(0.20, 0.28, 0.25),
	Color(0.42, 0.38, 0.24), Color(0.27, 0.29, 0.33),
	Color(0.38, 0.20, 0.23), Color(0.18, 0.31, 0.38),
]

var prop_id := ""
var display_name := ""
var kind := ""
var case_id := ""

var _material: StandardMaterial3D
var _label: Label3D
var _home := Vector3.ZERO
var _phase := 0.0
var _intensity := 0.0
var _recurrence := 0
var _verbs: Array = []
var _base_color := Color.WHITE
var _echo_root: Node3D


func setup(id: String, title: String, prop_kind: String,
		owner_case := "") -> void:
	prop_id = id
	display_name = title
	kind = prop_kind
	case_id = owner_case


func _ready() -> void:
	name = "AffectedProp_" + prop_id
	add_to_group("reality_affected_props")
	_home = position
	_phase = float(abs(hash(prop_id)) % 1000) * 0.017
	_material = StandardMaterial3D.new()
	_material.albedo_color = PALETTE[abs(hash(prop_id)) % PALETTE.size()]
	_base_color = _material.albedo_color
	_material.roughness = 0.72
	_material.emission_enabled = true
	_material.emission = Color(0.22, 0.78, 0.65)
	_material.emission_energy_multiplier = 0.0
	_build_visual()
	_build_echo()
	_build_label()
	if case_id != "":
		RealityRules.rule_changed.connect(_on_rule_changed)
		_apply_rule(RealityRules.effect_for(case_id))


func _build_visual() -> void:
	match kind:
		"paper_stack", "notebook", "blueprints", "tags", "keycards", "word_tiles", "folded_cloth", "gloves", "clipboard":
			for index in range(3 if kind in ["paper_stack", "blueprints"] else 1):
				_box(Vector3(0.28, 0.012, 0.20),
						Vector3(index * 0.008, index * 0.014, -index * 0.006))
		"pencil", "ruler", "shears", "tuning_fork", "antenna", "tape_measure":
			var shaft := _cylinder(0.012, 0.32, Vector3(0, 0.03, 0))
			shaft.rotation_degrees.z = 90
			if kind in ["shears", "tuning_fork"]:
				var second := _cylinder(0.012, 0.24, Vector3(0, 0.05, 0.055))
				second.rotation_degrees.z = 90
		"bell":
			_cylinder(0.10, 0.08, Vector3(0, 0.04, 0))
			_sphere(Vector3(0.13, 0.09, 0.13), Vector3(0, 0.12, 0))
		"thermos", "mug", "plant_pot", "paint_cans", "spools", "tape_reel":
			_cylinder(0.075 if kind != "paint_cans" else 0.11,
					0.20 if kind == "thermos" else 0.12,
					Vector3(0, 0.10 if kind == "thermos" else 0.06, 0))
			if kind in ["spools", "tape_reel", "paint_cans"]:
				_cylinder(0.06, 0.10, Vector3(0.14, 0.05, 0.02))
		"plant":
			_cylinder(0.12, 0.20, Vector3(0, 0.10, 0))
			for index in range(5):
				var leaf := _sphere(Vector3(0.08, 0.22, 0.05),
						Vector3(sin(index * 1.26) * 0.10,
								0.28 + (index % 2) * 0.08,
								cos(index * 1.26) * 0.10))
				leaf.rotation_degrees.z = index * 24 - 48
		"radio", "recorder", "camera", "pager", "control_panel", "appliance", "sewing_machine":
			_box(Vector3(0.30, 0.20, 0.18), Vector3(0, 0.10, 0))
			_cylinder(0.045, 0.025, Vector3(-0.08, 0.12, 0.105)).rotation_degrees.x = 90
			_cylinder(0.035, 0.025, Vector3(0.08, 0.12, 0.105)).rotation_degrees.x = 90
			if kind == "camera":
				_cylinder(0.07, 0.10, Vector3(0, 0.10, 0.14)).rotation_degrees.x = 90
		"tool_case", "briefcase", "bag", "luggage", "artifact_box", "antique_box", "storage_crate":
			var size := Vector3(0.42, 0.26, 0.22)
			if kind == "storage_crate":
				size = Vector3(0.72, 0.48, 0.50)
			_box(size, Vector3(0, size.y * 0.5, 0))
			_box(Vector3(size.x * 0.35, 0.035, 0.035),
					Vector3(0, size.y + 0.05, 0))
		"helmet":
			_sphere(Vector3(0.25, 0.17, 0.22), Vector3(0, 0.13, 0))
		"wedges":
			for index in range(4):
				_box(Vector3(0.15, 0.05, 0.08),
						Vector3((index - 1.5) * 0.10, 0.025, index % 2 * 0.08))
		"cable_bundle":
			for index in range(3):
				_ring(0.12 + index * 0.025, Vector3(0, 0.03 + index * 0.012, 0))
		"microphone":
			_cylinder(0.025, 0.70, Vector3(0, 0.35, 0))
			_sphere(Vector3(0.09, 0.10, 0.09), Vector3(0, 0.75, 0))
		"easel":
			for x in [-0.18, 0.18]:
				var leg := _cylinder(0.018, 1.0, Vector3(x, 0.5, 0))
				leg.rotation_degrees.z = -10.0 * signf(x)
			_box(Vector3(0.48, 0.52, 0.025), Vector3(0, 0.62, 0))
		"palette":
			_sphere(Vector3(0.26, 0.025, 0.18), Vector3(0, 0.03, 0))
		"work_order_board":
			_box(Vector3(1.1, 0.72, 0.06), Vector3(0, 0.36, 0))
		"service_cart":
			_box(Vector3(0.78, 0.08, 0.42), Vector3(0, 0.46, 0))
			for x in [-0.31, 0.31]:
				for z in [-0.14, 0.14]:
					_cylinder(0.03, 0.80, Vector3(x, 0.40, z))
		"portal_tags":
			for index in range(5):
				_box(Vector3(0.18, 0.025, 0.10),
						Vector3((index - 2) * 0.13, 0.04 + index * 0.01, 0))
		_:
			_box(Vector3(0.26, 0.18, 0.20), Vector3(0, 0.09, 0))


func _build_label() -> void:
	_label = Label3D.new()
	_label.text = display_name
	_label.position.y = 0.48 if kind != "storage_crate" else 0.82
	_label.font_size = 26
	_label.pixel_size = 0.0018
	_label.modulate = Color(0.72, 0.9, 0.84, 0.0 if case_id != "" else 0.82)
	_label.outline_size = 8
	_label.outline_modulate = Color(0.01, 0.02, 0.02, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(_label)


func _build_echo() -> void:
	_echo_root = Node3D.new()
	_echo_root.name = "ImpossibleDuplicate"
	for child in get_children():
		if child is MeshInstance3D:
			var echo := MeshInstance3D.new()
			echo.mesh = child.mesh
			echo.transform = child.transform
			var echo_material := _material.duplicate()
			echo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			echo_material.albedo_color.a = 0.32
			echo.material_override = echo_material
			_echo_root.add_child(echo)
	_echo_root.visible = false
	add_child(_echo_root)


func _on_rule_changed(changed_case: String, effect: Dictionary) -> void:
	if changed_case == case_id:
		_apply_rule(effect)


func _apply_rule(effect: Dictionary) -> void:
	_recurrence = int(effect.get("recurrence", 0))
	_intensity = float(effect.get("intensity", 0.0))
	_verbs = effect.get("prop_verbs", [])
	if _label:
		_label.modulate.a = clampf(_intensity + 0.25, 0.0, 0.95)
	if _echo_root:
		_echo_root.visible = "duplicate" in _verbs and _intensity > 0.05


func _process(delta: float) -> void:
	if _material == null:
		return
	var time := Time.get_ticks_msec() / 1000.0 + _phase
	_material.emission_energy_multiplier = lerpf(
			_material.emission_energy_multiplier,
			_intensity * (1.2 + _recurrence * 0.45), delta * 5.0)
	if "wrong_color" in _verbs and _intensity > 0.0:
		var impossible_color := Color.from_hsv(
				fposmod(_base_color.h + time * 0.035, 1.0),
				minf(0.82, _base_color.s + 0.32), _base_color.v)
		_material.albedo_color = _base_color.lerp(
				impossible_color, _intensity)
	else:
		_material.albedo_color = _material.albedo_color.lerp(
				_base_color, minf(1.0, delta * 4.0))
	if _intensity > 0.0:
		var orbit_scale := 0.18 if "orbit" in _verbs else 0.012
		if "freeze" in _verbs:
			orbit_scale = 0.0
		elif "drift" in _verbs:
			orbit_scale = 0.07
		elif "stutter" in _verbs:
			orbit_scale *= 1.0 if fmod(time * 3.0, 1.0) < 0.18 else 0.0
		position = _home + Vector3(
				sin(time * 3.7) * orbit_scale,
				(0.015 + sin(time * 4.9) * 0.008) * _intensity,
				cos(time * 3.1) * orbit_scale) * _intensity
		var turn := 0.38 if "point" in _verbs else 0.035
		if "lag" in _verbs:
			turn *= 0.25
		rotation.y = sin(time * 2.3) * turn * (1 + _recurrence)
		var possessed_scale := Vector3.ONE
		if "grow" in _verbs:
			possessed_scale *= 1.0 + _intensity * (0.08 + 0.04 * sin(time))
		if "stretch" in _verbs:
			possessed_scale *= Vector3(1.0 + _intensity * 0.12,
					1.0 - _intensity * 0.05, 1.0)
		scale = scale.lerp(possessed_scale, minf(1.0, delta * 2.0))
		if "pulse" in _verbs:
			_material.emission_energy_multiplier *= 0.72 + 0.28 * sin(time * 5.0)
		if _echo_root and _echo_root.visible:
			_echo_root.position = Vector3(
					sin(time * 1.7) * 0.24, 0.04,
					cos(time * 1.3) * 0.18) * _intensity
			_echo_root.rotation.y = sin(time) * 0.18
	else:
		position = position.lerp(_home, minf(1.0, delta * 6.0))
		rotation.y = lerp_angle(rotation.y, 0.0, minf(1.0, delta * 6.0))
		scale = scale.lerp(Vector3.ONE, minf(1.0, delta * 6.0))


func _box(size: Vector3, offset: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = _material
	add_child(instance)
	return instance


func _cylinder(radius: float, height: float, offset: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = _material
	add_child(instance)
	return instance


func _sphere(size: Vector3, offset: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.scale = size
	instance.position = offset
	instance.material_override = _material
	add_child(instance)
	return instance


func _ring(radius: float, offset: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.012
	mesh.outer_radius = radius + 0.012
	mesh.rings = 16
	mesh.ring_segments = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.material_override = _material
	add_child(instance)
	return instance
