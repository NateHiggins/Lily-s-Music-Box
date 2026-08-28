class_name LampOpticalInstrument
extends Node3D
## Opt-in L1 review instrument. It owns presentation, never switch/game rules.

signal optical_observation(observation: Dictionary)

@export var seed := 0x28A11CE
@export_range(0, 2) var quality_tier := 2
@export var base_energy := 4.2
@export var range_m := 9.0

var state := LampOpticalState.new()
var light: SpotLight3D
var fog_volume: FogVolume
var filament: MeshInstance3D
var particles: GPUParticles3D
var _filament_material: StandardMaterial3D
var _fog_material: ShaderMaterial


func _ready() -> void:
	state.configure(seed, true)
	_build_filament()
	_build_housing()
	_build_primary_light()
	_build_volume()
	_build_particles()


func _physics_process(delta: float) -> void:
	state.advance(delta)
	_apply_output()
	if Engine.get_physics_frames() % 6 == 0:
		optical_observation.emit(state.observation(global_position,
				-global_transform.basis.z, 1.0))


func set_powered(on: bool) -> void:
	state.switched_on = on


func apply_mechanical_shock(strength: float) -> void:
	state.apply_mechanical_shock(strength)


func save_optical_state() -> Dictionary:
	return state.save_state()


func restore_optical_state(data: Dictionary) -> bool:
	var ok := state.restore_state(data)
	if ok:
		_apply_output()
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
	fog_volume.size = Vector3(range_m * 0.72, range_m * 0.72, range_m)
	fog_volume.position.z = -range_m * 0.5
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = load("res://shaders/lamp_beam_fog.gdshader")
	fog_volume.material = _fog_material
	add_child(fog_volume)


func _build_particles() -> void:
	if quality_tier <= 0:
		return
	particles = GPUParticles3D.new()
	particles.name = "BoundedAirborneMatter"
	particles.amount = 80 if quality_tier == 1 else 144
	particles.lifetime = 7.0
	particles.visibility_aabb = AABB(Vector3(-3.5, -3.5, -range_m),
			Vector3(7.0, 7.0, range_m))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(2.6, 2.6, range_m * 0.48)
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
	particles.position.z = -range_m * 0.5
	add_child(particles)


func _apply_output() -> void:
	if light == null:
		return
	var o := state.output()
	var energy := float(o.intensity)
	light.visible = energy > 0.001
	light.light_energy = base_energy * energy
	light.light_color = o.color
	light.spot_angle = o.cone_angle_deg
	# Damp short electrical events in the reprojection history.
	light.light_volumetric_fog_energy = (0.0 if state.instability > 0.42
			else 9.0 * float(o.volumetric_multiplier))
	_filament_material.emission = o.color
	_filament_material.emission_energy_multiplier = float(o.filament_emission)
	if _fog_material:
		_fog_material.set_shader_parameter("optical_time", state.simulation_time_s)
		_fog_material.set_shader_parameter("lamp_output",
				minf(1.0, float(o.volumetric_multiplier)))
	if particles:
		particles.emitting = energy > 0.035
