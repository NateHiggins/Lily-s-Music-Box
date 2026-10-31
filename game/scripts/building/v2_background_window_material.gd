extends RefCounted
## Private optical material factory. Never mutates catalogue stock or native meshes.
## Caller supplies normalized pane UV2 (top-left origin); UV0 remains metric PBR.
## Apply only to opaque, noninteractive background panes, not real inhabited rooms.
const InteriorShader = preload("res://shaders/v2_background_window_interior.gdshader")

static func create(identity: String, kind: int, size_metres: Vector2) -> ShaderMaterial:
	assert(kind >= 0 and kind <= 3 and size_metres.x > 0.0 and size_metres.y > 0.0)
	var glass: StandardMaterial3D = MatLib.get_mat("mirror_aged")
	var wall: StandardMaterial3D = MatLib.get_mat("limewash_plaster")
	var wood: StandardMaterial3D = MatLib.get_mat("wood_dark")
	var material := ShaderMaterial.new()
	material.shader = InteriorShader
	material.set_shader_parameter("glass_albedo", glass.albedo_texture)
	material.set_shader_parameter("glass_roughness", glass.roughness_texture)
	material.set_shader_parameter("glass_normal", glass.normal_texture)
	material.set_shader_parameter("wall_albedo", wall.albedo_texture)
	material.set_shader_parameter("wood_albedo", wood.albedo_texture)
	material.set_shader_parameter("physical_uv_scale", Vector2(glass.uv1_scale.x, glass.uv1_scale.y))
	material.set_shader_parameter("building_seed", float(identity.hash() & 0xffff))
	material.set_shader_parameter("room_kind", kind)
	material.set_shader_parameter("pane_size", size_metres)
	return material

static func sync_clock(material: ShaderMaterial, clock: CampaignClock) -> bool:
	var day := clock.day_info()
	if not bool(day.get("valid", false)):
		return false # Keep last valid presentation; never invent a date.
	material.set_shader_parameter("minute_of_day", clock.minute_of_day())
	material.set_shader_parameter("weekend", str(day.day) in ["sat", "sun"])
	return true
