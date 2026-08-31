class_name DreamVoxelLightPresenter
extends Node
## Default-off production bridge between the accepted L1C instrument, the
## one world-owned DreamExposureField, and existing cellular presentation.
## It owns no ecology facts and has no reference to DreamEcologyDirector.

const LampScript := preload("res://scripts/lamp/lamp_optical_instrument.gd")
const ExposureScript := preload("res://scripts/dream/dream_exposure_field.gd")
const CellularStateScript := preload("res://scripts/dream/dream_cellular_state.gd")
const VoxelShader := preload("res://shaders/dream_moss_voxel_light.gdshader")

const UPDATE_HZ := 15.0
const UPDATE_INTERVAL := 1.0 / UPDATE_HZ
const TARGET_NODES := {
	"MossHeart": [1.0, .92],
	"PlasmodialFans": [0.0, .98],
	"VascularNetwork": [0.0, .98],
	"InformationReturnPulse": [2.0, 1.0],
	"MembraneProteinFamilies": [2.0, 1.0],
}

var field: DreamExposureField
var texture: ImageTexture3D
var lamp: LampOpticalInstrument
var shared_material: ShaderMaterial
var player: Node3D
var target_case := ""
var room_key := ""
var target_rect := Vector4.ZERO
var debug_mode := 2

var add_lamp_calls := 0
var upload_calls := 0
var uploads_performed := 0
var accumulated_update_s := 0.0
var voxel_cpu_total_us := 0
var voxel_cpu_peak_us := 0
var last_deposition: Dictionary = {}
var _bindings: Array[Dictionary] = []
var _renderers: Array = []
var _player_light_visible := false
var _player_light_cull_mask := 0
var _player_light_bound := false
var _running := false


func configure(player_node: Node3D, case_id: String, rect: Vector4,
		floor_y: float, renderers: Array) -> void:
	player = player_node
	target_case = case_id
	target_rect = rect
	room_key = "@orison_cellular_%s" % case_id
	field = ExposureScript.new()
	field.stamp_room(room_key, [rect.x, rect.y, rect.z, rect.w], 0.0,
		float(posmod(case_id.hash(), 10007)) / 10007.0)
	texture = field.make_texture()
	shared_material = ShaderMaterial.new()
	shared_material.shader = VoxelShader
	shared_material.set_shader_parameter("exposure_tex", texture)
	shared_material.set_shader_parameter("exposure_extent", ExposureScript.EXTENT_M)
	shared_material.set_shader_parameter("exposure_height", ExposureScript.HEIGHT_M)
	for renderer in renderers:
		_bind_renderer(renderer)
	_build_real_l1c()
	_sync_lamp_transform()
	_running = true
	set_process(true)
	set_physics_process(true)
	print("[DREAM-VOXEL-V1] active case=%s room=%s renderers=%d field=%dx%dx%d RG8 @ %.1f Hz"
			% [target_case, room_key, _renderers.size(), ExposureScript.GRID_XZ,
			ExposureScript.GRID_XZ, ExposureScript.GRID_Y, UPDATE_HZ])


func _build_real_l1c() -> void:
	lamp = LampScript.new()
	lamp.name = "ProductionL1COpticalInstrument"
	lamp.seed = 0xD1EA0C11
	lamp.quality_tier = 1
	add_child(lamp)
	if player != null and "flashlight" in player and player.flashlight != null:
		_player_light_visible = player.flashlight.visible
		_player_light_cull_mask = player.flashlight.light_cull_mask
		_player_light_bound = true
		# The opt-in profile replaces only the old presentation light.  Its
		# switch remains the device/game authority and is mirrored into L1C.
		player.flashlight.visible = false
		player.flashlight.light_cull_mask = 0


func _process(_delta: float) -> void:
	if not _running:
		return
	_sync_lamp_transform()
	_push_instance_state()


func _physics_process(delta: float) -> void:
	if not _running:
		return
	accumulated_update_s += delta
	if accumulated_update_s < UPDATE_INTERVAL:
		return
	# At most one write per physics frame.  The real accumulated interval is
	# passed through, so low frame rate changes neither dose nor cooling rate.
	var dt := accumulated_update_s
	accumulated_update_s = 0.0
	deposit_once(dt)


func deposit_once(dt: float = UPDATE_INTERVAL) -> void:
	if field == null or texture == null or lamp == null or lamp.light == null:
		return
	_sync_lamp_transform()
	var started := Time.get_ticks_usec()
	var physical_light := lamp.light
	var origin: Vector3 = physical_light.global_position
	var direction := -physical_light.global_transform.basis.z.normalized()
	var reach: float = physical_light.spot_range
	var cos_outer := cos(deg_to_rad(physical_light.spot_angle))
	var energy := clampf(physical_light.light_energy /
			maxf(lamp.base_energy, .0001), 0.0, 1.12)
	field.add_lamp(origin, direction, reach, cos_outer, energy, dt)
	add_lamp_calls += 1
	# This call is deliberately unconditional. DreamExposureField's dirty flag
	# alone decides whether the existing ImageTexture3D receives new bytes.
	upload_calls += 1
	if field.upload(texture):
		uploads_performed += 1
	var elapsed := Time.get_ticks_usec() - started
	voxel_cpu_total_us += elapsed
	voxel_cpu_peak_us = maxi(voxel_cpu_peak_us, elapsed)
	last_deposition = {
		"origin": origin, "direction": direction, "range_m": reach,
		"cone_angle_deg": physical_light.spot_angle, "cos_outer": cos_outer,
		"normalized_energy": energy, "dt_s": dt,
	}


func set_debug_mode(mode: int) -> void:
	debug_mode = clampi(mode, 0, 2)
	for row in _bindings:
		var node = row.get("node")
		if is_instance_valid(node):
			node.set_instance_shader_parameter("voxel_response_mode", debug_mode)


func _sync_lamp_transform() -> void:
	if lamp == null or player == null:
		return
	var source = player.get("flashlight")
	if source == null:
		return
	lamp.global_transform = source.global_transform
	if player.has_method("lamp_is_enabled"):
		lamp.set_powered(bool(player.call("lamp_is_enabled")))
	if _player_light_bound:
		# PlayerController may reassert visibility while its switch transient
		# advances; keep the replaced draw path suppressed only in this profile.
		source.visible = false
		source.light_cull_mask = 0


func _bind_renderer(renderer) -> void:
	if renderer == null or not is_instance_valid(renderer):
		return
	_renderers.append(renderer)
	for node_name in TARGET_NODES:
		var node := renderer.get_node_or_null(NodePath(node_name)) as GeometryInstance3D
		if node == null:
			continue
		_bindings.append({"node": node, "original": node.material_override,
			"renderer": renderer, "role": TARGET_NODES[node_name][0],
			"alpha": TARGET_NODES[node_name][1]})
		node.material_override = shared_material
		node.set_instance_shader_parameter("membrane_role", TARGET_NODES[node_name][0])
		node.set_instance_shader_parameter("tissue_alpha", TARGET_NODES[node_name][1])
		node.set_instance_shader_parameter("voxel_response_mode", debug_mode)
	_push_renderer_state(renderer)


func _push_instance_state() -> void:
	for renderer in _renderers:
		if is_instance_valid(renderer):
			_push_renderer_state(renderer)


func _push_renderer_state(renderer) -> void:
	var colony = renderer.get("colony")
	if colony == null:
		return
	var phenotype: Dictionary = renderer.get("_phenotype")
	var state = renderer.get("_state_packet")
	if state == null:
		state = CellularStateScript.new()
	var phenotype_vector := Vector4(float(phenotype.get("organization", .78)),
		float(phenotype.get("windows", .48)), float(phenotype.get("proteins", .88)),
		float(phenotype.get("refractive", .42)))
	for row in _bindings:
		if row.renderer != renderer:
			continue
		var node = row.node
		if not is_instance_valid(node):
			continue
		node.set_instance_shader_parameter("cellular_seed",
			float(int(colony.seed) % 8191) * .013)
		node.set_instance_shader_parameter("cellular_phenotype", phenotype_vector)
		node.set_instance_shader_parameter("cellular_state_a", state.to_vector_a())
		node.set_instance_shader_parameter("cellular_state_b", state.to_vector_b())
		node.set_instance_shader_parameter("cellular_state_c", state.to_vector_c())
		node.set_instance_shader_parameter("cellular_time", float(renderer.get("_clock")))


func field_snapshot() -> Dictionary:
	var active_durable := 0
	var active_irradiance := 0
	var active_union := 0
	var strongest := 0.0
	var strongest_channel := "none"
	var strongest_index := Vector3i.ZERO
	if field != null:
		var images := field.to_images()
		for iy in images.size():
			var image: Image = images[iy]
			for iz in ExposureScript.GRID_XZ:
				for ix in ExposureScript.GRID_XZ:
					var pixel := image.get_pixel(ix, iz)
					if pixel.r > 0.0: active_durable += 1
					if pixel.g > 0.0: active_irradiance += 1
					if pixel.r > 0.0 or pixel.g > 0.0: active_union += 1
					if pixel.r > strongest:
						strongest = pixel.r
						strongest_channel = "durable_r"
						strongest_index = Vector3i(ix, iy, iz)
					if pixel.g > strongest:
						strongest = pixel.g
						strongest_channel = "irradiance_g"
						strongest_index = Vector3i(ix, iy, iz)
	return {
		"texture_dimensions": [ExposureScript.GRID_XZ, ExposureScript.GRID_XZ,
			ExposureScript.GRID_Y], "texture_format": "RG8",
		"voxel_size_m": ExposureScript.VOXEL_M,
		"active_durable_voxels": active_durable,
		"active_irradiance_voxels": active_irradiance,
		"active_voxels_union": active_union, "strongest_voxel": strongest,
		"strongest_channel": strongest_channel, "strongest_grid_index": strongest_index,
		"stamped_room_count": field.stamped_rooms() if field != null else 0,
		"overflowed": field.overflowed() if field != null else false,
	}


func receipt() -> Dictionary:
	var mean_cpu := float(voxel_cpu_total_us) / maxf(1.0, float(add_lamp_calls)) / 1000.0
	return {
		"enabled": _running, "target_case": target_case,
		"authorities": {
			"LampOpticalInstrument": "electrical/thermal state and instantaneous physical presentation",
			"DreamExposureField": "shared 0.5 m RG8 durable/reversible voxel history",
			"DreamVoxelLightPresenter": "cellular optical interpretation and resource binding",
			"ecology": "independent sensing and decisions; no reference held here",
		},
		"method_chain": ["LampOpticalState", "LampOpticalInstrument._apply_output()",
			"LampOpticalInstrument.light SpotLight3D",
			"DreamVoxelLightPresenter.deposit_once()",
			"DreamExposureField.add_lamp()", "DreamExposureField.upload()",
			"dream_moss_voxel_light.gdshader exposure_at(world_position)"],
		"update_cadence_hz": UPDATE_HZ, "last_deposition": last_deposition,
		"add_lamp_call_count": add_lamp_calls, "upload_call_count": upload_calls,
		"upload_count": uploads_performed, "voxel_update_cpu_ms_mean": mean_cpu,
		"voxel_update_cpu_ms_peak": float(voxel_cpu_peak_us) / 1000.0,
		"shared_material_count": 1 if shared_material != null else 0,
		"shared_texture_count": 1 if texture != null else 0,
		"bound_organism_count": _renderers.size(), "bound_surface_count": _bindings.size(),
		"per_organism_field": false, "per_organism_texture": false,
		"per_organism_material": false, "gpu_readback_during_gameplay": false,
		"substitute_scalar_drives_voxel_response": false,
		"field": field_snapshot(),
	}


func shutdown() -> Dictionary:
	if not _running and field == null and texture == null:
		return {"already_released": true}
	_running = false
	set_process(false)
	set_physics_process(false)
	for row in _bindings:
		var node = row.get("node")
		if is_instance_valid(node):
			node.material_override = row.get("original")
			node.set_instance_shader_parameter("voxel_response_mode", 0)
	_bindings.clear()
	_renderers.clear()
	if shared_material != null:
		shared_material.set_shader_parameter("exposure_tex", null)
	if field != null and not room_key.is_empty():
		field.clear_room(room_key)
	if _player_light_bound and player != null and "flashlight" in player \
			and player.flashlight != null:
		player.flashlight.visible = _player_light_visible
		player.flashlight.light_cull_mask = _player_light_cull_mask
	_player_light_bound = false
	if lamp != null:
		lamp.set_physics_process(false)
		if lamp.light != null:
			lamp.light.visible = false
			lamp.light.light_energy = 0.0
			lamp.light.light_cull_mask = 0
		if lamp.fog_volume != null:
			lamp.fog_volume.material = null
		if lamp.particles != null:
			lamp.particles.emitting = false
			lamp.particles.process_material = null
		lamp.queue_free()
	var result := {"writer_stopped": true, "sampler_unbound": true,
		"room_ownership_cleared": field == null or field.stamped_rooms() == 0,
		"lamp_release_requested": lamp != null}
	lamp = null
	shared_material = null
	texture = null
	field = null
	player = null
	return result


func _exit_tree() -> void:
	shutdown()
