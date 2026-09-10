extends Node3D
## Beam-local participating air, lit and shadowed by the existing real lamp.
## PlayerController owns the logical switch; the optical driver owns thermal state.
## This is
## engine froxel scattering with a shared instantaneous optical-field sample.
## Scene-mesh shadows remain engine-owned; ecological exposure is untouched.
const FOG_SHADER := preload("res://shaders/lamp_optical_air.gdshader")
const Field := preload("res://scripts/lamp/lamp_optical_voxel_field.gd")
var field: RefCounted
var observation: Node3D
var _bound := false
var _failed_reported := false
var player: PlayerController
var volume: FogVolume
var material: ShaderMaterial
var particles: GPUParticles3D
var particle_material: ShaderMaterial
var driver: Node
var _environment: Environment
var _environment_before := {}
var _elapsed := 0.0
var _due := 0.0

func setup(owner_player: PlayerController, environment: Environment) -> bool:
	player = owner_player
	player.set_beam_mask_enabled(false)
	# V2 has a real thermal output multiplier and no photographic exposure
	# mask. Keep a modest usable throw while room fixtures remain dominant.
	player.set_lamp_base_energy(1.5)
	# Finite filament aperture gives nearby blockers a contact shadow and
	# softens the shadow with distance, rather than a pinhole silhouette.
	player.flashlight.light_size = .018
	driver = preload("res://scripts/lamp/carried_lamp_optical_driver.gd").new()
	add_child(driver)
	if not driver.setup(player): return false
	if RenderingServer.get_current_rendering_method() != "forward_plus": return true
	field = Field.new()
	field.initialize(0)
	observation = preload("res://scripts/lamp/carried_lamp_observation.gd").new()
	add_child(observation)
	_environment = environment
	_environment_before = {"enabled":environment.volumetric_fog_enabled,
		"density":environment.volumetric_fog_density,"length":environment.volumetric_fog_length}
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = .0001
	environment.volumetric_fog_length = 12.0
	volume = FogVolume.new()
	volume.name = "CarriedLampAir"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_CONE
	# Unchanged L1C production bounds, density and shader detail tier.
	# Godot's cone axis is local Y, apex at +Y. Rotate that apex toward
	# lamp +Z so the cone extends forward along lamp -Z. World bounds stay
	# 3.9 x 3.9 x 6.5 m; the old unrotated cone was perpendicular to the beam.
	volume.size = Vector3(3.9,6.5,3.9)
	material = ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter("density_gain",.034)
	material.set_shader_parameter("detail_octaves",1.0)
	volume.material = material
	add_child(volume)
	_build_dust()
	process_priority = 100
	_update_volume(0)
	return true

func _process(delta: float) -> void:
	_update_volume(delta)

func _update_volume(delta: float) -> void:
	if volume == null or not is_instance_valid(player): return
	if not field.failed.is_empty():
		volume.visible = false
		particles.visible = false
		particles.emitting = false
		_update_environment(false)
		if not _failed_reported:
			_failed_reported = true
			push_error("V2 lamp optical field: " + field.failed)
		return
	_elapsed += delta
	_due -= delta
	observation.observe_player(player,delta)
	if field.ready:
		if not _bound:
			field.bind_material(material)
			field.bind_material(particle_material)
			_bound = true
		field.observe(observation)
	volume.global_transform = player.flashlight.global_transform * Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,0,-3.25))
	var useful: bool = player.lamp_is_enabled() and float(driver.output.intensity) >= .035
	volume.visible = useful and _bound
	_update_environment(volume.visible)
	particles.global_transform = player.flashlight.global_transform.translated_local(Vector3(0,0,-3.25))
	particles.visible = useful and _bound
	particles.emitting = useful and _bound
	player.flashlight.light_volumetric_fog_energy = 3.0 * float(driver.output.volumetric_multiplier) \
			if useful and driver.state.instability <= .42 else 0.0
	if _due <= 0 or not useful:
		_due = 1.0/15.0
		material.set_shader_parameter("optical_time",_elapsed)
		material.set_shader_parameter("lamp_output",minf(1.0,float(driver.output.volumetric_multiplier)) if useful else 0.0)

func _update_environment(useful: bool) -> void:
	# Waking V2 has no ambient volumetric fog before this owner mounts.
	# Release the full-screen froxel pass when our only volume is inactive.
	# An environment that already owned fog must retain that independent pass.
	if _environment != null:
		_environment.volumetric_fog_enabled = useful or bool(_environment_before.enabled)

func _build_dust() -> void:
	particles = GPUParticles3D.new()
	particles.name = "CarriedLampDust"
	particles.amount = 48
	particles.lifetime = 7.0
	particles.local_coords = false
	particles.emitting = false
	particles.visible = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Existing particles stay in world space as the emitter follows the lens.
	# The generous AABB retains those particles during ordinary hand motion;
	# the shared field rejects any mote outside the instantaneous beam.
	particles.visibility_aabb = AABB(Vector3(-5,-5,-6.5),Vector3(10,10,13))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(1.95,1.95,3.12)
	motion.direction = Vector3(.05,1,-.08)
	motion.spread = 18
	motion.initial_velocity_min = .015
	motion.initial_velocity_max = .055
	motion.gravity = Vector3(0,.012,0)
	motion.scale_min = .55
	motion.scale_max = 1.65
	particles.process_material = motion
	var mesh := QuadMesh.new()
	mesh.size = Vector2(.026,.026)
	particle_material = ShaderMaterial.new()
	particle_material.shader = preload("res://shaders/lamp_optical_dust.gdshader")
	mesh.material = particle_material
	particles.draw_pass_1 = mesh
	add_child(particles)

func _exit_tree() -> void:
	if _environment != null:
		_environment.volumetric_fog_enabled = bool(_environment_before.enabled)
		_environment.volumetric_fog_density = float(_environment_before.density)
		_environment.volumetric_fog_length = float(_environment_before.length)
		_environment = null
	if field != null:
		field.dispose()
		field = null
	if is_instance_valid(volume): volume.material = null
	if is_instance_valid(particles):
		particles.emitting = false
		particles.draw_pass_1 = null
		particles.process_material = null
	particle_material = null
	material = null
