class_name DreamLightControlHarness
extends Node3D
## N3 disposable control pack. This is measurement geometry, not a production
## dream module and not a Tenant implementation. It exists only to establish
## the service-lamp pursuit binary behind real opaque collision.

const CORRIDOR_WIDTH_M := 3.20
const CORRIDOR_LENGTH_M := 42.0
const CORRIDOR_HEIGHT_M := 3.0
const WALL_M := 0.20
const TARGET_START_Z_M := 8.0
const TARGET_END_Z_M := 40.0
const TARGET_SPEED_MPS := 4.60
const BODY_START_Z_M := 1.0
const CAPTURE_RADIUS_M := 0.75
const MAX_RUN_S := 30.0

var tenant_body: CharacterBody3D
var shadow_proxy: MeshInstance3D
var target: Node3D
var work_lamp: SpotLight3D
var opaque_control_wall: StaticBody3D

var elapsed_s := 0.0
var acquisition_time_s := -1.0
var capture_time_s := -1.0
var light_enabled := true
var acquired := false
var captured := false
var target_moving := true
var last_known_position := Vector3.ZERO

var _lit_speed_mps := 6.35
var _dark_speed_mps := 3.35
var _hearing_period_s := 0.72
var _hearing_due_s := 0.0


func _ready() -> void:
	_build_control_pack()
	reset_run(1, true)


func reset_run(seed: int, lamp_on: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_lit_speed_mps = 6.35 + rng.randf_range(-0.12, 0.12)
	_dark_speed_mps = 3.35 + rng.randf_range(-0.08, 0.08)
	_hearing_period_s = 0.72 + rng.randf_range(-0.08, 0.08)
	_hearing_due_s = _hearing_period_s
	elapsed_s = 0.0
	acquisition_time_s = -1.0
	capture_time_s = -1.0
	acquired = false
	captured = false
	target_moving = true
	tenant_body.position = Vector3(0, 0, BODY_START_Z_M)
	target.position = Vector3(0, 0, TARGET_START_Z_M)
	last_known_position = target.position
	set_light_enabled(lamp_on)


func set_light_enabled(on: bool) -> void:
	light_enabled = on
	if work_lamp:
		work_lamp.visible = on


func advance_fixed(delta: float) -> void:
	if captured:
		return
	elapsed_s += delta
	var old_target := target.position
	var was_moving := target_moving
	target.position.z = minf(TARGET_END_Z_M,
			target.position.z + TARGET_SPEED_MPS * delta)
	target_moving = target.position.distance_to(old_target) > 0.00001
	if was_moving and not target_moving:
		# The final shoe plant at the real end wall is audible. Without this
		# terminal sample a runner could stop between hearing ticks and leave
		# the body chasing a stale point forever: an accidental hiding state.
		last_known_position = target.position

	var clear_light := light_enabled and has_clear_line_to_target()
	if clear_light:
		if not acquired:
			acquisition_time_s = elapsed_s
		acquired = true
		last_known_position = target.position
	else:
		_hearing_due_s -= delta
		if _hearing_due_s <= 0.0:
			# Footsteps update a coarse last-known point. Once the player reaches
			# the end wall there is no endless dark hiding state: the last audible
			# footfall remains a real place the body can finish reaching.
			if target_moving:
				last_known_position = target.position
			_hearing_due_s += _hearing_period_s

	var speed := _lit_speed_mps if clear_light and acquired else _dark_speed_mps
	var pursuit := last_known_position - tenant_body.position
	pursuit.y = 0.0
	if pursuit.length() > 0.0001:
		tenant_body.position += pursuit.normalized() * minf(
				speed * delta, pursuit.length())
	if tenant_body.position.distance_to(target.position) <= CAPTURE_RADIUS_M:
		captured = true
		capture_time_s = elapsed_s


func has_clear_line_to_target() -> bool:
	return has_clear_line(tenant_body.position + Vector3.UP * 1.05,
			target.position + Vector3.UP * 1.05)


func has_clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [tenant_body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func prepare_opaque_control(blocked: bool) -> void:
	captured = false
	acquired = false
	acquisition_time_s = -1.0
	tenant_body.position = Vector3(5.8, 0, 0)
	target.position = Vector3(9.2, 0, 0 if blocked else 4.6)
	last_known_position = tenant_body.position
	set_light_enabled(true)


func scan_light_once() -> bool:
	if light_enabled and has_clear_line_to_target():
		acquired = true
		acquisition_time_s = elapsed_s
		last_known_position = target.position
	return acquired


func set_shot_state(lamp_on: bool) -> void:
	tenant_body.position = Vector3(0, 0, 20.0)
	target.position = Vector3(0, 0, 31.0)
	last_known_position = target.position
	set_light_enabled(lamp_on)


func run_parameters() -> Dictionary:
	return {
		"lit_speed_mps": _lit_speed_mps,
		"dark_speed_mps": _dark_speed_mps,
		"hearing_period_s": _hearing_period_s,
	}


func _build_control_pack() -> void:
	var architecture := Node3D.new()
	architecture.name = "DisposableControlArchitecture"
	add_child(architecture)
	var wall_mat := _material(Color("272a31"), 0.94)
	var floor_mat := _material(Color("343139"), 0.90)
	_solid_box("Floor", Vector3(CORRIDOR_WIDTH_M, WALL_M,
			CORRIDOR_LENGTH_M), Vector3(0, -WALL_M * 0.5,
			CORRIDOR_LENGTH_M * 0.5), floor_mat, architecture)
	_solid_box("Ceiling", Vector3(CORRIDOR_WIDTH_M, WALL_M,
			CORRIDOR_LENGTH_M), Vector3(0, CORRIDOR_HEIGHT_M + WALL_M * 0.5,
			CORRIDOR_LENGTH_M * 0.5), wall_mat, architecture)
	for x in [-CORRIDOR_WIDTH_M * 0.5 - WALL_M * 0.5,
			CORRIDOR_WIDTH_M * 0.5 + WALL_M * 0.5]:
		_solid_box("CorridorWall", Vector3(WALL_M, CORRIDOR_HEIGHT_M,
				CORRIDOR_LENGTH_M), Vector3(x, CORRIDOR_HEIGHT_M * 0.5,
				CORRIDOR_LENGTH_M * 0.5), wall_mat, architecture)
	for z in [-WALL_M * 0.5, CORRIDOR_LENGTH_M + WALL_M * 0.5]:
		_solid_box("EndWall", Vector3(CORRIDOR_WIDTH_M + WALL_M * 2.0,
				CORRIDOR_HEIGHT_M, WALL_M), Vector3(0,
				CORRIDOR_HEIGHT_M * 0.5, z), wall_mat, architecture)

	# A separate sensor cell proves that acquisition respects real opaque
	# collision without compromising the straight timing corridor.
	opaque_control_wall = _solid_box("OpaqueAcquisitionControl",
			Vector3(0.35, 2.80, 3.0), Vector3(7.5, 1.40, 0), wall_mat,
			architecture)

	tenant_body = CharacterBody3D.new()
	tenant_body.name = "InvisibleNavigationBody"
	tenant_body.collision_layer = 2
	tenant_body.collision_mask = 1
	var body_shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.28
	capsule_shape.height = 1.70
	body_shape.shape = capsule_shape
	body_shape.position.y = 0.85
	tenant_body.add_child(body_shape)
	add_child(tenant_body)

	shadow_proxy = MeshInstance3D.new()
	shadow_proxy.name = "DiagnosticShadowsOnlyProxy"
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.28
	capsule_mesh.height = 1.70
	shadow_proxy.mesh = capsule_mesh
	shadow_proxy.position.y = 0.85
	shadow_proxy.cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow_proxy.material_override = _material(Color("09090b"), 1.0)
	tenant_body.add_child(shadow_proxy)

	target = Node3D.new()
	target.name = "MeasuredPlayerTarget"
	add_child(target)
	work_lamp = SpotLight3D.new()
	work_lamp.name = "ServiceLampControl"
	work_lamp.position = Vector3(0, 1.15, 0)
	work_lamp.light_color = Color(1.0, 0.80, 0.56)
	work_lamp.light_energy = 5.0
	work_lamp.spot_range = 34.0
	work_lamp.spot_angle = 34.0
	work_lamp.spot_angle_attenuation = 1.8
	work_lamp.shadow_enabled = true
	target.add_child(work_lamp)


func _solid_box(node_name: String, size: Vector3, at: Vector3,
		material: Material, parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	body.add_child(mesh_node)
	parent.add_child(body)
	return body


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
