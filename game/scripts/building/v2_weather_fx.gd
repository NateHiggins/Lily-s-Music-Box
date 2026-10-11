extends WeatherFX
## Existing precipitation owner, with real V2 roof/ceiling cover queries.
var air: FogVolume
var air_material: ShaderMaterial
func _ready() -> void:
	super._ready()
	_leaves.material_override=MatLib.get_mat("plant")
	for node: Node in [_splash,_snow,_hail,_middle_rain,_road_mist]:
		node.set_meta("surface_role","weather_optics")
	if RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_rendering_device()!=null:
		air=FogVolume.new();air.name="SeasonalOutdoorAir";air.size=Vector3(8,6,8)
		air_material=ShaderMaterial.new();air_material.shader=preload("res://shaders/v2_weather_air.gdshader")
		air_material.set_shader_parameter("cloud_noise",preload("res://scripts/building/weather_noise.gd").load_volume())
		air.material=air_material;add_child(air)

func _process(delta: float) -> void:
	super._process(delta)
	if air==null or not is_instance_valid(_player): return
	air.global_position=_player.global_position+Vector3.UP*2.0
	air.visible=exposed(_player.global_position)
	var seasons: Vector4 = _live_conditions.get("season_weights",Vector4.ZERO)
	var humidity: float = _live_conditions.get("relative_humidity",.5)
	var density := (seasons.y*.003+seasons.z*.0015)*humidity
	air_material.set_shader_parameter("density_gain",density if air.visible else 0.0)

func covered(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point+Vector3.UP*200.0,1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func exposed(point: Vector3) -> bool:
	# Outdoor roof and street are defined by the actual unobstructed sky above
	# the observer. Covered spaces remain dry; no floor-height shortcut.
	return not covered(point)
