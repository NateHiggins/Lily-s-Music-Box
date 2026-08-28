class_name LampOpticalInstrument
extends Node3D
## Opt-in L1 review instrument. It owns presentation, never switch/game rules.

const LampState = preload("res://scripts/lamp/lamp_optical_state.gd")

signal optical_observation(observation: Dictionary)

@export var seed := 0x28A11CE
@export_range(0, 2) var quality_tier := 1
@export var base_energy := 4.2
@export var range_m := 9.0
@export_range(0.0, 1.0) var ether_spectral_component := 0.0

var state = LampState.new()
var light: SpotLight3D
var fog_volume: FogVolume
var filament: MeshInstance3D
var particles: GPUParticles3D
var _filament_material: StandardMaterial3D
var _fog_material: ShaderMaterial
var _output_cache := {}
var _last_energy := -1.0
var _last_color := Color.TRANSPARENT
var _last_cone := -1.0
var _fog_update_clock := 0.0

const USEFUL_INTENSITY := 0.035
const FOG_UPDATE_INTERVAL := 1.0 / 15.0


func _ready() -> void:
	state.configure(seed, true)
	_build_filament()
	_build_housing()
	_build_primary_light()
	_build_volume()
	_build_particles()


func _physics_process(delta: float) -> void:
	state.advance(delta)
	_apply_output(delta)
	if Engine.get_physics_frames() % 6 == 0:
		optical_observation.emit(observation_payload())


## Read-only stimulus packet. Consumers remain responsible for interpretation;
## this node never writes ecology state or selects organism behavior.
func observation_payload(occlusion_confidence := 1.0) -> Dictionary:
	var result:Dictionary = state.observation(global_position,
			-global_transform.basis.z, occlusion_confidence)
	var output:Dictionary = state.output()
	result["spectral_balance"] = result.spectral_bands
	result["color_temperature_k"] = output.color_temperature_k
	result["flicker_phase"] = fposmod(state.simulation_time_s * 9.0, 1.0)
	result["flicker_amplitude"] = state.instability
	result["beam_direction"] = result.direction
	result["local_thermal_contribution"] = result.heat_contribution
	result["ether_spectral_component"] = ether_spectral_component
	return result


func set_powered(on: bool) -> void:
	state.switched_on = on


func apply_mechanical_shock(strength: float) -> void:
	state.apply_mechanical_shock(strength)


func save_optical_state() -> Dictionary:
	return state.save_state()


func restore_optical_state(data: Dictionary) -> bool:
	var ok:bool = state.restore_state(data)
	if ok:
		_apply_output(FOG_UPDATE_INTERVAL)
	return ok


func _build_filament() -> void:
	filament = MeshInstance3D.new()
	filament.name = "LivingFilament"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.012
	mesh.outer_radius = 0.020
	mesh.rings = 20
	mesh.ring_segments = 8
	filament.mesh = mesh
	filament.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_filament_material = StandardMaterial3D.new()
	_filament_material.albedo_color = Color("241008")
	_filament_material.emission_enabled = true
	filament.material_override = _filament_material
	add_child(filament)


func _build_primary_light() -> void:
	light = SpotLight3D.new()
	light.name = "HeroShadowLamp"
	light.shadow_enabled = true
	light.spot_range = range_m
	light.spot_angle = 37.0
	light.spot_attenuation = 1.35
	light.spot_angle_attenuation = 1.55
	light.light_energy = base_energy
	light.light_volumetric_fog_energy = 9.0
	light.shadow_blur = 1.5
	light.light_projector = null
	add_child(light)


func _build_housing() -> void:
	var shell := MeshInstance3D.new()
	shell.name = "PeriodReflectorHousing"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.34
	cone.height = 0.32
	shell.mesh = cone
	shell.position.z = 0.10
	shell.rotation_degrees.x = 90.0
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("4a3521")
	metal.metallic = 0.72
	metal.roughness = 0.24
	shell.material_override = metal
	add_child(shell)
	var lens := MeshInstance3D.new()
	lens.name = "ScratchedLens"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.155
	disc.bottom_radius = 0.155
	disc.height = 0.012
	lens.mesh = disc
	lens.position.z = -0.075
	lens.rotation_degrees.x = 90.0
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.52, 0.34, 0.18, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.19
	lens.material_override = glass
	add_child(lens)


func _build_volume() -> void:
	if quality_tier <= 0:
		return
	fog_volume = FogVolume.new()
	fog_volume.name = "OccludedBeamVolume"
	fog_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_CONE
	var useful_range := minf(range_m, 6.5) if quality_tier == 1 else range_m
	var useful_width := useful_range * (0.60 if quality_tier == 1 else 0.72)
	fog_volume.size = Vector3(useful_width, useful_width, useful_range)
	fog_volume.position.z = -useful_range * 0.5
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = load("res://shaders/lamp_beam_fog.gdshader")
	_fog_material.set_shader_parameter("density_gain", 0.034 if quality_tier == 1 else 0.055)
	_fog_material.set_shader_parameter("detail_octaves", 1.0 if quality_tier == 1 else 2.0)
	fog_volume.material = _fog_material
	add_child(fog_volume)


func _build_particles() -> void:
	if quality_tier <= 0:
		return
	particles = GPUParticles3D.new()
	particles.name = "BoundedAirborneMatter"
	particles.amount = 48 if quality_tier == 1 else 120
	particles.lifetime = 7.0
	var particle_range := minf(range_m, 6.5) if quality_tier == 1 else range_m
	var particle_width := 2.4 if quality_tier == 1 else 3.2
	particles.visibility_aabb = AABB(Vector3(-particle_width, -particle_width, -particle_range),
			Vector3(particle_width * 2.0, particle_width * 2.0, particle_range))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(particle_width, particle_width, particle_range * 0.48)
	process.direction = Vector3(0.05, 1.0, -0.08)
	process.spread = 18.0
	process.initial_velocity_min = 0.015
	process.initial_velocity_max = 0.055
	process.gravity = Vector3(0.0, 0.012, 0.0)
	process.scale_min = 0.55
	process.scale_max = 1.65
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.026, 0.026)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = Color(0.92, 0.82, 0.64, 0.58)
	mat.metallic = 0.18
	mat.roughness = 0.30
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.position.z = -particle_range * 0.5
	add_child(particles)


func _apply_output(delta := FOG_UPDATE_INTERVAL) -> void:
	if light == null:
		return
	state.write_output(_output_cache)
	var energy := float(_output_cache.intensity)
	var useful := energy >= USEFUL_INTENSITY
	if absf(energy - _last_energy) > 0.001:
		light.visible = energy > 0.001
		light.light_energy = base_energy * energy
		_last_energy = energy
	if _output_cache.color != _last_color:
		light.light_color = _output_cache.color
		_filament_material.emission = _output_cache.color
		_last_color = _output_cache.color
	if absf(float(_output_cache.cone_angle_deg) - _last_cone) > 0.01:
		light.spot_angle = _output_cache.cone_angle_deg
		_last_cone = _output_cache.cone_angle_deg
	# Damp short electrical events in the reprojection history.
	light.light_volumetric_fog_energy = (0.0 if not useful or state.instability > 0.42
			else (3.0 if quality_tier == 1 else 7.0) * float(_output_cache.volumetric_multiplier))
	_filament_material.emission_energy_multiplier = float(_output_cache.filament_emission)
	if _fog_material:
		fog_volume.visible = useful
		_fog_update_clock += delta
		if _fog_update_clock >= FOG_UPDATE_INTERVAL or not useful:
			_fog_update_clock = 0.0
			_fog_material.set_shader_parameter("optical_time", state.simulation_time_s)
			_fog_material.set_shader_parameter("lamp_output",
					minf(1.0, float(_output_cache.volumetric_multiplier)) if useful else 0.0)
	if particles:
		particles.visible = useful
		particles.emitting = useful
