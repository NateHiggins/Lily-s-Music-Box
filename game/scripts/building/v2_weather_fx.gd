extends WeatherFX
## Existing precipitation owner, with real V2 roof/ceiling cover queries.
var air: FogVolume
var air_material: ShaderMaterial
var _dust_demand := false
var gpu_emitters: Array[GPUParticles3D]=[]
var _exposure_due:=0.0
var _outdoor:=false
var weather_environment: Environment
var outdoor_air_frame:=Transform3D.IDENTITY
var precipitation_contact: GPUParticlesCollisionHeightField3D
var contact_updates:=0

func _build_precipitation() -> void:
	if RenderingServer.get_current_rendering_method()!="forward_plus" or OS.get_environment("WEATHER_SKY_BASELINE")=="1" or not _player is PlayerController:
		super._build_precipitation();return
	_leaves=_make_leaves();_leaves.emitting=false;add_child(_leaves)
	gpu_emitters=preload("res://scripts/building/queens_weather_extension.gd").gpu_precipitation(_player.camera,
		preload("res://shaders/queens_precipitation_motion.gdshader"),preload("res://shaders/queens_precipitation_draw.gdshader"))
	precipitation_contact=GPUParticlesCollisionHeightField3D.new()
	precipitation_contact.name="WeatherContactField"
	precipitation_contact.size=Vector3(64,48,64)
	precipitation_contact.resolution=GPUParticlesCollisionHeightField3D.RESOLUTION_256
	precipitation_contact.heightfield_mask=1 # world; exclude device, avatar and weather
	precipitation_contact.cull_mask=1<<18
	precipitation_contact.follow_camera_enabled=false
	precipitation_contact.update_mode=GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(precipitation_contact)
func _ready() -> void:
	super._ready()
	_leaves.material_override=MatLib.get_mat("plant")
	for node: Node in [_splash,_snow,_hail,_middle_rain,_road_mist]:
		if node!=null:node.set_meta("surface_role","weather_optics")
	if RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_rendering_device()!=null:
		air=FogVolume.new();air.name="SeasonalOutdoorAir";air.size=Vector3(120,28,9.144)
		air_material=ShaderMaterial.new();air_material.shader=preload("res://shaders/queens_weather_air.gdshader")
		air_material.set_shader_parameter("low_fog_noise",load("res://assets/environment/weather/cirrus.png"))
		air_material.set_shader_parameter("fog_band_height_m",18.0)
		air.material=air_material;add_child(air)
		var section:=preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
		air.global_transform=Transform3D(outdoor_air_frame.basis,outdoor_air_frame*Vector3(0,14.0,19.322-float(section.source_threshold_z)))
		air_material.set_shader_parameter("datum_y_m",outdoor_air_frame.origin.y)
		air_material.set_shader_parameter("cloud_noise",preload("res://scripts/building/weather_noise.gd").load_volume())
		if gpu_emitters.is_empty():
			air.size=Vector3(8,6,8)
			air_material.shader=preload("res://shaders/v2_weather_air.gdshader")
			air_material.set_shader_parameter("cloud_noise",preload("res://scripts/building/weather_noise.gd").load_volume())

func _process(delta: float) -> void:
	if gpu_emitters.is_empty():
		super._process(delta)
		if air!=null and is_instance_valid(_player):
			air.global_position=_player.global_position+Vector3.UP*2.0
			air.visible=exposed(_player.global_position)
			var seasons: Vector4=_live_conditions.get("season_weights",Vector4.ZERO)
			air_material.set_shader_parameter("density_gain",(seasons.y*.003+seasons.z*.0015)*float(_live_conditions.get("relative_humidity",.5)) if air.visible else 0.0)
		_apply_dust()
		return
	_t+=delta;_update_lightning(delta)
	var wind_gain := _advance_wind()
	if air==null or not is_instance_valid(_player): return
	_exposure_due-=delta
	if _exposure_due<=0.0:
		_exposure_due=.1
		_outdoor=exposed(_player.global_position)
	var camera:=get_viewport().get_camera_3d()
	var at: Vector3=camera.global_position if camera!=null else _player.global_position
	if extreme_weather!=null:
		extreme_weather.update_emitters(gpu_emitters,at,_outdoor and OS.get_environment("WEATHER_RAIN")!="0",wind_gain,camera)
		# A 64 m field retains 20 m of visible precipitation while its centre
		# moves only after leaving the inner 8 m band. No per-frame redraw.
		if precipitation_contact!=null and _outdoor and extreme_weather.weights.length_squared()>.0001:
			var offset: Vector3=at-precipitation_contact.global_position
			if contact_updates==0 or absf(offset.x)>8.0 or absf(offset.z)>8.0 or absf(offset.y)>8.0:
				precipitation_contact.global_position=Vector3(snappedf(at.x,8.0),snappedf(at.y,8.0),snappedf(at.z,8.0))
				contact_updates+=1
	_leaves.emitting=_outdoor and bool(_live_conditions.get("thunderstorm",false))
	_leaves.global_position=_player.global_position+Vector3.UP*LEAF_HEIGHT
	_leaves.gravity=Vector3(wind.x*.85,-1.5,wind.z*.85)
	# The authored road corridor ends before either building face. Unlike a
	# camera-centred cube it cannot fill an occupied interior through its walls.
	air.visible=OS.get_environment("WEATHER_MIST")!="0"
	if weather_environment!=null:weather_environment.set_meta("outdoor_weather_active",air.visible and extreme_weather!=null and (float(extreme_weather.cyclone)>.01 or float(extreme_weather.weights.z)>.60 or float(extreme_weather.threat)>.10))

	_apply_dust()

func _apply_dust() -> void:
	if air == null or not is_instance_valid(_player): return
	var dust := clampf(float(_live_conditions.get("dust",0.0)),0.0,1.0)
	var bearing := deg_to_rad(float(_live_conditions.get("wind_direction_degrees",0.0)))
	var downwind := Vector2(-sin(bearing),cos(bearing))
	# Keep the authored street bounds. The front passes the observer at60%,
	# without expanding a camera-centred volume through occupied rooms.
	var observer := Vector2(_player.global_position.x,_player.global_position.z)
	air_material.set_shader_parameter("dust_direction",downwind)
	air_material.set_shader_parameter("dust_front",downwind.dot(observer)+(dust-.6)*90.0)
	air_material.set_shader_parameter("dust_gain",dust*.05 if air.visible else 0.0)
	if (dust>.05) != _dust_demand:
		_dust_demand = dust>.05
		get_tree().call_group("v2_volumetric_fog","set_weather_demand",_dust_demand)
	if weather_environment!=null and _dust_demand:
		weather_environment.set_meta("outdoor_weather_active",true)

func apply_profile(profile: Dictionary) -> void:
	super.apply_profile(profile)
	var color: Color=profile.get("rain",Color(.55,.62,.70))
	for emitter: GPUParticles3D in gpu_emitters:
		(emitter.draw_pass_1.material as ShaderMaterial).set_shader_parameter("precipitation_light",Vector3(color.r,color.g,color.b))
	if air_material!=null:
		var fog: Color=profile.get("fog",Color(.32,.24,.16))
		air_material.set_shader_parameter("coal_color",Vector3(fog.r,fog.g,fog.b))

func covered(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.25,point+Vector3.UP*200.0,1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func exposed(point: Vector3) -> bool:
	# Outdoor roof and street are defined by the actual unobstructed sky above
	# the observer. Covered spaces remain dry; no floor-height shortcut.
	return not covered(point)
