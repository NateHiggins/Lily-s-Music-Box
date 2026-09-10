extends Node3D
## Beam-local participating air, lit and shadowed by the existing real lamp.
## Electrical state and logical switch remain with PlayerController. This is
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
var _elapsed := 0.0
var _due := 0.0

func setup(owner_player: PlayerController, environment: Environment) -> void:
	player = owner_player
	player.set_beam_mask_enabled(false)
	if RenderingServer.get_current_rendering_method() != "forward_plus": return
	field = Field.new()
	field.initialize(0)
	observation = preload("res://scripts/lamp/carried_lamp_observation.gd").new()
	add_child(observation)
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
	process_priority = 100
	_update_volume(0)

func _process(delta: float) -> void:
	_update_volume(delta)

func _update_volume(delta: float) -> void:
	if volume == null or not is_instance_valid(player): return
	if not field.failed.is_empty():
		volume.visible = false
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
			_bound = true
		field.observe(observation)
	volume.global_transform = player.flashlight.global_transform * Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,0,-3.25))
	var useful := player.lamp_is_enabled() and player.flashlight.light_energy > .025
	volume.visible = useful and _bound
	player.flashlight.light_volumetric_fog_energy = 3.0 if useful else 0.0
	if _due <= 0 or not useful:
		_due = 1.0/15.0
		material.set_shader_parameter("optical_time",_elapsed)
		material.set_shader_parameter("lamp_output",1.0 if useful else 0.0)

func _exit_tree() -> void:
	if field != null:
		field.dispose()
		field = null
	if is_instance_valid(volume): volume.material = null
	material = null
