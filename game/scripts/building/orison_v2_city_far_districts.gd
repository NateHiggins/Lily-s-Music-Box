extends Node3D
## Passive distant districts beyond the composed city: midtown Manhattan, Welfare
## Island, north and south Long Island City, Sunnyside Yard, Newtown Creek and
## Greenpoint (art/blender/scripts/build_city_far_districts.py). Ground and water
## extend the installed bridge sheet and apron to the camera's far plane. No
## collision, access, resident, weather, clock or save authority is added; window
## lamps only read the campaign clock, as the background window optics do.
const ASSET := preload("res://assets/props/city_far_districts.glb")
const FacadeShader := preload("res://shaders/v2_far_city_facade.gdshader")
## glTF material name -> catalogue key. "far_" names are facades with window lamps.
const FACADES := {
	"far_brick": "brick",
	"far_grey": "city_grey_brick",
	"far_stone": "limestone",
	"far_terracotta": "terracotta",
}
const PLAIN := ["roof_bitumen", "asphalt", "soil", "water_clear", "iron_neutral", "brick", "soot",
	"tank_staves", "galvanized_roof", "city_slate", "copper_aged", "limestone", "car_paint"]

var facade_materials: Array[ShaderMaterial] = []
var motion: Node3D
var _clock := CampaignClock.new()
var _elapsed := 0.0
var _minute := -INF


static func mount(parent: Node3D) -> Node3D:
	var districts := preload("res://scripts/building/orison_v2_city_far_districts.gd").new()
	districts.name = "FarDistricts"
	parent.add_child(districts)
	return districts


func _ready() -> void:
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	var made: Dictionary = {}
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		assert(draw.mesh.get_surface_count() == 1)
		# Node names are "<district>__<catalogue key>" from the generator; the
		# placeholder glTF materials carry no usable name of their own.
		var key := str(draw.name).get_slice("__", 1)
		if not made.has(key):
			made[key] = _material(key)
		draw.material_override = made[key]
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		draw.set_meta("v2_city_far_district", true)
	motion = preload("res://scripts/building/orison_v2_city_far_motion.gd").new()
	motion.name = "FarMotion"
	add_child(motion)
	_refresh(true)


func _material(key: String) -> Material:
	if FACADES.has(key):
		var stock: StandardMaterial3D = MatLib.get_mat(str(FACADES[key]))
		var facade := ShaderMaterial.new()
		facade.shader = FacadeShader
		facade.set_shader_parameter("albedo_tex", stock.albedo_texture)
		facade.set_shader_parameter("rough_tex", stock.roughness_texture)
		facade.set_shader_parameter("normal_tex", stock.normal_texture)
		facade.set_shader_parameter("physical_uv_scale", Vector2(stock.uv1_scale.x, stock.uv1_scale.y))
		facade_materials.append(facade)
		return facade
	assert(key in PLAIN, "unmapped far-district material " + key)
	var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	# UV0 is already metric; keep the catalogue's tile scale and turn triplanar off.
	material.uv1_triplanar = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if key == "water_clear":
		# The bridge's opaque turbid-river policy; no kilometre-wide refraction pass.
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color = Color(0.22, 0.27, 0.29)
	return material


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	_refresh(false)


func _refresh(force: bool) -> bool:
	if facade_materials.is_empty() or not _clock.bind_state():
		return false
	var minute := floorf(_clock.calendar_minutes())
	if minute == _minute and not force:
		_copy_fog()  # weather can thicken or clear the haze between minutes
		return true
	_minute = minute
	return project_clock(_clock)


## Also used by a prologue or capture that borrows the world clock.
func project_clock(clock: CampaignClock) -> bool:
	var day := clock.day_info()
	if not bool(day.get("valid", false)):
		return false
	var minute_of_day := clock.minute_of_day()
	var hour := minute_of_day / 60.0
	# Blue hour either side of night lifts the far walls a little so they keep their shape.
	var dusk := smoothstep(15.5, 17.5, hour) * (1.0 - smoothstep(20.0, 22.0, hour)) \
		+ smoothstep(4.5, 6.0, hour) * (1.0 - smoothstep(7.0, 8.5, hour))
	for material in facade_materials:
		material.set_shader_parameter("minute_of_day", minute_of_day)
		material.set_shader_parameter("weekend", str(day.day) in ["sat", "sun"])
		material.set_shader_parameter("dusk_fill", dusk)
	if is_instance_valid(motion):
		motion.call("set_darkness_from_minute", minute_of_day)
	_copy_fog()
	return true


func _copy_fog() -> void:
	var environment: Environment = null
	if is_inside_tree() and get_viewport() != null and get_viewport().world_3d != null:
		environment = get_viewport().world_3d.environment
	if environment == null:
		return
	var density := environment.fog_density if environment.fog_enabled else 0.0
	for material in facade_materials:
		material.set_shader_parameter("fog_density", density)
		material.set_shader_parameter("fog_begin", environment.fog_depth_begin)
		material.set_shader_parameter("fog_end", environment.fog_depth_end)
		material.set_shader_parameter("fog_curve", environment.fog_depth_curve)
		material.set_shader_parameter("fog_colour", environment.fog_light_color * environment.fog_light_energy)
