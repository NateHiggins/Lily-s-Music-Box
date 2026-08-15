class_name ServiceSetProp
extends Node3D
## The carried Vantry Model No. 4 service radiophone.  This is a physical
## instrument, not a phone with its screen removed: speaker, carbon mouthpiece,
## aerial, PTT, lamp and three single-purpose incandescent jewels are the whole
## grammar.

const DEVICE_LAYER := 2
const BODY := Vector3(0.085, 0.225, 0.058)
## The inspection beam leaves the attached lamp down local -Z.
const LAMP_AT := Vector3(0.054, 0.070, -0.119)

const PHENOLIC := Color("211711")
const PHENOLIC_EDGE := Color("35251a")
const BLACKENED := Color("24211d")
const BRASS := Color("79623a")
const BRASS_WORN := Color("a58b58")
const CERAMIC := Color("d3c7a7")
const GLASS_DARK := Color("160f0a")
const AMBER := Color("ff9d24")
const GREEN := Color("65d07d")
const RED := Color("e35a42")
const LAMP_WARM := Color("ffd08a")

var radio_powered := true
var lamp_enabled := true
var order_open := false

var _work_orders: WorkOrders
var _aerial: Node3D
var _lamp_lever: Node3D
var _order_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _lamp_indicator_material: StandardMaterial3D
var _lamp_glass_material: StandardMaterial3D


func _ready() -> void:
	_build_model()
	_isolate_meshes(self)
	_apply_state(false)


func bind_work_orders(orders: WorkOrders) -> void:
	_work_orders = orders
	if _work_orders == null:
		return
	if not _work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		_work_orders.job_stage_changed.connect(_on_job_stage_changed)
	if not _work_orders.order_issued.is_connected(_on_simple_order_changed):
		_work_orders.order_issued.connect(_on_simple_order_changed)
	if not _work_orders.order_activated.is_connected(_on_simple_order_changed):
		_work_orders.order_activated.connect(_on_simple_order_changed)
	if not _work_orders.order_closed.is_connected(_on_simple_order_changed):
		_work_orders.order_closed.connect(_on_simple_order_changed)
	if not RealityState.state_changed.is_connected(_refresh_order):
		RealityState.state_changed.connect(_refresh_order)
	_refresh_order()


func set_radio_powered(on: bool, animate := true) -> void:
	if radio_powered == on and _aerial != null:
		_apply_state(animate)
		return
	radio_powered = on
	_apply_state(animate)


func toggle_radio_power() -> void:
	set_radio_powered(not radio_powered)


func set_lamp_enabled(on: bool, animate := true) -> void:
	if lamp_enabled == on and _lamp_lever != null:
		_apply_state(animate)
		return
	lamp_enabled = on
	_apply_state(animate)


func _on_job_stage_changed(_job_id: String, _from_stage: String,
		_to_stage: String, _state: Dictionary) -> void:
	_refresh_order()


func _on_simple_order_changed(_order_id: String, _order: Dictionary) -> void:
	_refresh_order()


func _refresh_order() -> void:
	order_open = _work_orders != null and _work_orders.has_open_work()
	_apply_state(false)


func _apply_state(animate: bool) -> void:
	_set_jewel(_order_material, AMBER, order_open and radio_powered, 1.25)
	_set_jewel(_net_material, GREEN, radio_powered, 0.82)
	_set_jewel(_lamp_indicator_material, RED, lamp_enabled, 0.82)
	_set_jewel(_lamp_glass_material, LAMP_WARM, lamp_enabled, 2.1)
	if _aerial:
		var aerial_y := 1.0 if radio_powered else 0.14
		if animate and is_inside_tree():
			create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(
					Tween.EASE_OUT).tween_property(_aerial, "scale:y",
					aerial_y, 0.28)
		else:
			_aerial.scale.y = aerial_y
	if _lamp_lever:
		var angle := deg_to_rad(-24.0 if lamp_enabled else 24.0)
		if animate and is_inside_tree():
			create_tween().set_trans(Tween.TRANS_BACK).tween_property(
					_lamp_lever, "rotation:z", angle, 0.16)
		else:
			_lamp_lever.rotation.z = angle


func _set_jewel(material: StandardMaterial3D, color: Color, on: bool,
		energy: float) -> void:
	if material == null:
		return
	material.albedo_color = color if on else GLASS_DARK
	material.emission_enabled = on
	material.emission = color
	material.emission_energy_multiplier = energy if on else 0.0


func _build_model() -> void:
	# The isolated pass already supplies wear through light and silhouette. The
	# building material atlas is calibrated for metre-scale appliances and
	# crushed this 85 mm case to featureless black, so the carried prop uses
	# honest small-object colors here instead of sampling a wall-sized texel.
	var phenolic := _mat(Color("613b28"), 0.54)
	var edge := _mat(Color("7a5035"), 0.48)
	var black := _mat(Color("39332d"), 0.50, 0.18)
	var brass := _mat(Color("927440"), 0.44, 0.54)
	var worn_brass := _mat(Color("c3a66a"), 0.38, 0.62)
	var ceramic := _mat(CERAMIC, 0.76)
	var grille := _mat(Color("100d0b"), 0.84)
	var paper := _mat(Color("b8a77f"), 0.88)

	# Compression-moulded case, raised end caps and the screwed rear hatch.
	_box(BODY, Vector3.ZERO, phenolic)
	_box(Vector3(0.090, 0.014, 0.063), Vector3(0, 0.105, 0), edge)
	_box(Vector3(0.090, 0.014, 0.063), Vector3(0, -0.105, 0), edge)
	_box(Vector3(0.070, 0.137, 0.003), Vector3(0, -0.012, 0.0305), black)
	for x in [-0.031, 0.031]:
		for y in [-0.073, 0.049]:
			_cyl(0.0031, 0.0025, Vector3(x, y, 0.033), worn_brass,
					Vector3.RIGHT)

	# FRONT, away from the hand: receiver, carbon mouthpiece and ORDER.
	var front_z := -BODY.z * 0.5 - 0.002
	_cyl(0.031, 0.004, Vector3(0, 0.058, front_z), grille,
			Vector3.RIGHT)
	for radius in [0.030, 0.022, 0.014]:
		_torus(radius, 0.0015, Vector3(0, 0.058, front_z - 0.003), brass,
				Vector3.RIGHT)
	for row in range(-2, 3):
		for col in range(-2, 3):
			if Vector2(row, col).length() <= 2.35:
				_cyl(0.0015, 0.003, Vector3(col * 0.009, 0.058 + row * 0.009,
						front_z - 0.004), black, Vector3.RIGHT)
	_cyl(0.014, 0.004, Vector3(0, -0.058, front_z), grille,
			Vector3.RIGHT)
	for a in range(8):
		var theta := TAU * float(a) / 8.0
		_cyl(0.0012, 0.003, Vector3(cos(theta) * 0.008,
				-0.058 + sin(theta) * 0.008, front_z - 0.003), black,
				Vector3.RIGHT)
	_order_material = _jewel_material()
	_sphere(0.0062, Vector3(0, -0.010, front_z - 0.002), _order_material)
	_label("ORDER", Vector3(0, -0.024, front_z - 0.003), 0.00042,
			Color("cfb77a"), true)

	# Rebuild and maker plates; large enough to read only in a proof close-up.
	_box(Vector3(0.060, 0.027, 0.002), Vector3(0, -0.091,
			front_z - 0.001), brass)
	_label("VANTRY & CO.\nMODEL No. 4", Vector3(0, -0.089,
			front_z - 0.003), 0.00027, Color("21170d"), true)

	# BACK, facing the carrier: a later linesman's modification. NET tells the
	# worker that the aerial really closed the radio circuit; LAMP confirms the
	# forward-facing bulb they cannot see from behind.
	var back_z := BODY.z * 0.5 + 0.003
	_net_material = _jewel_material()
	_lamp_indicator_material = _jewel_material()
	for spec in [
		["NET", -0.019, GREEN, _net_material],
		["LAMP", 0.019, RED, _lamp_indicator_material],
	]:
		_sphere(0.0053, Vector3(float(spec[1]), 0.051, back_z), spec[3])
		_label(str(spec[0]), Vector3(float(spec[1]), 0.036, back_z + 0.002),
				0.00034, Color("c7b47f"), false)
	_label("1924 REBUILD", Vector3(0, -0.071, back_z + 0.002), 0.00028,
			Color("c7b47f"), false)
	# Pasted circuit card beneath the service cover's lower window.
	_box(Vector3(0.050, 0.034, 0.0015), Vector3(0, -0.039, back_z), paper)
	for y in [-0.048, -0.040, -0.032]:
		_box(Vector3(0.039, 0.0008, 0.001), Vector3(0, y, back_z + 0.002),
				brass)

	# Attached tungsten work lamp. The broad barrel, glass and bracket make
	# LAMP_AT visually true rather than a spotlight emitted by empty air.
	_box(Vector3(0.018, 0.035, 0.016), Vector3(0.036, 0.076, -0.023), brass)
	var barrel := _cyl(0.022, 0.082, Vector3(0.054, 0.070, -0.073), black,
			Vector3.RIGHT)
	barrel.rotation.x = PI * 0.5
	var reflector := _cyl(0.025, 0.018, Vector3(0.054, 0.070, -0.109),
			worn_brass, Vector3.RIGHT)
	reflector.rotation.x = PI * 0.5
	_lamp_glass_material = _jewel_material()
	var lens := _cyl(0.021, 0.004, LAMP_AT, _lamp_glass_material,
			Vector3.RIGHT)
	lens.rotation.x = PI * 0.5

	# Pull aerial, ceramic feed-through and nested brass tubes. The pivot is at
	# the case shoulder so collapsing scale visibly pushes it home.
	_cyl(0.010, 0.012, Vector3(-0.026, 0.116, 0.010), ceramic, Vector3.UP)
	_aerial = Node3D.new()
	_aerial.name = "PowerAerial"
	_aerial.position = Vector3(-0.026, 0.118, 0.010)
	add_child(_aerial)
	for i in 4:
		var length := 0.096
		var radius := 0.0034 - float(i) * 0.00055
		_cyl(radius, length, Vector3(0, length * (float(i) + 0.5), 0),
				worn_brass, Vector3.UP, _aerial)
	_sphere(0.006, Vector3(0, 0.402, 0), black, _aerial)

	# Tactile controls. PTT is broad and protected; the lamp switch has only
	# the owner-ruled OFF/ON detent. A fluted volume wheel sits on the crown.
	_box(Vector3(0.006, 0.064, 0.026), Vector3(-0.046, 0.008, 0.002), black)
	_label("PTT", Vector3(-0.050, 0.008, 0.017), 0.00030,
			Color("b29b6d"), false, Vector3(0, -90, 0))
	_lamp_lever = Node3D.new()
	_lamp_lever.name = "LampLever"
	_lamp_lever.position = Vector3(0.048, -0.055, 0.003)
	add_child(_lamp_lever)
	_box(Vector3(0.004, 0.030, 0.005), Vector3(0, 0.012, 0), worn_brass,
			_lamp_lever)
	_cyl(0.005, 0.008, Vector3.ZERO, black, Vector3.UP, _lamp_lever)
	_cyl(0.014, 0.010, Vector3(0.022, 0.112, 0.005), black, Vector3.UP)
	for notch in range(10):
		var a := TAU * float(notch) / 10.0
		_box(Vector3(0.002, 0.011, 0.003), Vector3(0.022 + cos(a) * 0.013,
				0.112, 0.005 + sin(a) * 0.013), worn_brass)

	# A repaired cotton-and-leather carrying strap: two short visible runs are
	# enough in first person; it never pretends to be tactical webbing.
	_box(Vector3(0.010, 0.170, 0.009), Vector3(-0.054, -0.010, 0.017),
			MatLib.get_mat("rubber_aged", Color("6d5845"), 0.32))
	_box(Vector3(0.020, 0.052, 0.012), Vector3(-0.055, 0.006, 0.017),
			_mat(Color("4a2f1d"), 0.88))


func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _jewel_material() -> StandardMaterial3D:
	var material := _mat(GLASS_DARK, 0.20)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.96
	return material


func _box(size: Vector3, at: Vector3, material: Material,
		parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _cyl(radius: float, height: float, at: Vector3, material: Material,
		_axis: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _sphere(radius: float, at: Vector3, material: Material,
		parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _torus(radius: float, tube: float, at: Vector3, material: Material,
		_axis: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 20
	mesh.ring_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation.x = PI * 0.5
	node.material_override = material
	add_child(node)
	return node


func _label(value: String, at: Vector3, pixel: float, color: Color,
		front_face: bool, rotation_degrees := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = 32
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.no_depth_test = false
	label.position = at
	label.rotation_degrees = rotation_degrees + (Vector3(0, 180, 0)
			if front_face else Vector3.ZERO)
	add_child(label)
	return label


func _isolate_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(node as GeometryInstance3D).layers = 1 << (DEVICE_LAYER - 1)
	for child in node.get_children():
		_isolate_meshes(child)
