class_name QueensWeatherExtension
extends RefCounted
## Called by the existing V2 WeatherManager; no independent network, clock or light owner.
var weights := Vector4.ZERO # rain, sleet, snow, hail
var wetness := 0.0
var threat := 0.0
var cyclone := 0.0
var vortex := 0.0
var wind_mps := Vector3.ZERO
var formation := 0
var formation_strength := 0.0
var phase := 0.0
var cyclone_phase := 0.0
var fog_offset := Vector2.ZERO
var _cloud_drift := Vector4.ZERO
var _asperitas_drift := Vector4.ZERO
var _cirrus_drift := Vector4.ZERO
var _dust_drift := Vector2.ZERO
var _target_weights := Vector4.ZERO
var _target_threat := 0.0
var _target_cyclone := 0.0
var _target_vortex := 0.0
var _target_wind := Vector3.ZERO
var _target_formation := 0
var _day := ""
var _daily_choice := 0
var _publish_left := 0.0
var _ramp: GradientTexture1D

func receive_conditions(conditions: Dictionary,campaign_day: String,seed_value: int=1928,events: Dictionary={}) -> void:
	# Use the existing normalized, interpolated observation. No synthetic rain
	# is invented merely because an API condition mentions precipitation.
	var rain:=clampf(number(conditions,"rain_intensity",0.0),0.0,1.0)
	var snow:=clampf(number(conditions,"snow_intensity",0.0),0.0,1.0)
	var provider_id:=int(number(conditions,"provider_weather_id",-1.0))
	var sleet:=provider_id in [611,612,613,615,616]
	var hail:=maxf(strength(events.get("hail",0.0)),rain if bool(conditions.get("hailing",false)) else 0.0)
	_target_weights=Vector4(0.0 if sleet else rain,maxf(rain,snow) if sleet else 0.0,0.0 if sleet else snow,hail)
	_target_vortex=maxf(1.0 if provider_id==781 else 0.0,strength(events.get("tornado",0.0)))
	_set_cyclone_target(strength(events.get("cyclone",0.0)))
	_target_threat=maxf(maxf(hail,_target_vortex),maxf(.85 if bool(conditions.get("thunderstorm",false)) else 0.0,strength(events.get("severe_storm_threat",0.0))))
	var bearing:=deg_to_rad(number(conditions,"wind_direction_degrees",0.0))
	var speed:=clampf(number(conditions,"wind_speed_kmh",0.0)/3.6,0.0,90.0)
	_target_wind=Vector3(-sin(bearing),0.0,cos(bearing))*speed
	if campaign_day!=_day:
		_day=campaign_day;_daily_choice=_daily_formation(campaign_day,seed_value)
	var fair:=number(conditions,"pressure_hpa",1013.0)>=1020.0 and speed<7.0 \
		and _target_weights.length_squared()<.001 and _target_threat<.05 and _target_cyclone<.05
	_target_formation=_daily_choice if fair else 0
	if events.has("formation"):
		_target_formation=clampi(int(events.formation),0,4) if _target_threat<.05 and _target_cyclone<.05 else 0
	var forced:=OS.get_environment("WEATHER_FORMATION")
	if forced in ["asperitas","fluctus","lenticular","nacreous"] and _target_threat<.05 and _target_cyclone<.05:
		_target_formation=["asperitas","fluctus","lenticular","nacreous"].find(forced)+1

func _init() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,0.2,0.4,0.6,0.8,1.0])
	gradient.colors = PackedColorArray([
		Color(1.0,0.76,0.87),Color(0.77,0.82,1.0),Color(0.75,1.0,0.87),
		Color(1.0,0.94,0.76),Color(0.90,0.77,1.0),Color(1.0,0.76,0.87)])
	_ramp = GradientTexture1D.new()
	_ramp.gradient = gradient
	_ramp.width = 128
	_ramp.use_hdr = true

static func number(data: Dictionary,key: String,fallback: float) -> float:
	var value: Variant = data.get(key,fallback)
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback

static func strength(value: Variant) -> float:
	if value is bool: return 1.0 if value else 0.0
	return clampf(float(value),0.0,1.0) if (value is int or value is float) and is_finite(float(value)) else 0.0

static func _daily_formation(day: String,seed_value: int) -> int:
	# Cosmetic recipe v1: stable day/seed selection; never reroll every frame.
	var seed_hash := posmod(seed_value,2147483647)
	var identity := day+":queens-clouds-v1"
	for index in identity.length():
		seed_hash = posmod(seed_hash*33+identity.unicode_at(index),2147483647)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash
	return rng.randi_range(1,4) if rng.randf()<0.025 else 0

func receive_api(raw: Dictionary,campaign_day: String,seed_value: int=1928,phenomena: Dictionary={}) -> bool:
	# raw must be the existing opt-in provider response in metric units.
	# phenomena contains VALIDATED active alert/art-director strengths, not text guesses.
	var entries: Variant=raw.get("weather",[])
	if entries is not Array or entries.is_empty() or entries[0] is not Dictionary: return false
	var identity := int(number(entries[0],"id",-1.0))
	if identity<0:return false
	var main: Variant=raw.get("main",{})
	var wind: Variant=raw.get("wind",{})
	var clouds: Variant=raw.get("clouds",{})
	if main is not Dictionary or wind is not Dictionary or clouds is not Dictionary:return false
	var rain_data: Variant=raw.get("rain",{})
	var snow_data: Variant=raw.get("snow",{})
	if rain_data is not Dictionary or snow_data is not Dictionary:return false
	var rain_rate := maxf(0.0,number(rain_data,"1h",0.0))
	var snow_rate := maxf(0.0,number(snow_data,"1h",0.0))
	var precip := Vector4.ZERO
	if identity in [611,612,613,615,616]:
		precip.y = clampf(maxf(rain_rate,snow_rate)/4.0,0.25,1.0)
	elif identity in [600,601,602,620,621,622]:
		var nominal := 1.0 if identity in [602,622] else (0.60 if identity in [601,621] else 0.25)
		precip.z = clampf(maxf(nominal,snow_rate/4.0),0.0,1.0)
	elif (identity>=200 and identity<400) or (identity>=500 and identity<600):
		# 511 is freezing RAIN, not sleet. Keep liquid streaks; icing is a separate owner.
		var nominal := 0.90 if identity in [202,212,232,502,503,504,522] else 0.25
		precip.x = clampf(maxf(nominal,rain_rate/10.0),0.0,1.0)
	var hail := strength(phenomena.get("hail",0.0))
	if hail>0.0:
		precip.w = hail
		precip.x = maxf(precip.x,hail*0.45)
	_target_weights=precip
	_target_vortex=maxf(1.0 if identity==781 else 0.0,strength(phenomena.get("tornado",0.0)))
	_set_cyclone_target(strength(phenomena.get("cyclone",0.0))) # hurricane OR nor'easter event
	var thunder := 0.90 if identity in [202,212,232] else (0.55 if identity>=200 and identity<300 else 0.0)
	_target_threat=maxf(maxf(thunder,hail),maxf(_target_vortex,strength(phenomena.get("severe_storm_threat",0.0))))
	var bearing := deg_to_rad(number(wind,"deg",0.0))
	var speed := clampf(number(wind,"speed",0.0),0.0,90.0)
	# Provider bearing is FROM north clockwise. Godot north is -Z in this adapter.
	_target_wind=Vector3(-sin(bearing),0.0,cos(bearing))*speed
	if campaign_day!=_day:
		_day=campaign_day
		_daily_choice=_daily_formation(campaign_day,seed_value)
	var pressure := number(main,"sea_level",number(main,"pressure",1013.0))
	var fair := pressure>=1020.0 and speed<7.0 and precip.length_squared()<0.001 \
		and _target_threat<0.05 and _target_cyclone<0.05
	_target_formation=_daily_choice if fair else 0
	return true

func advance(delta: float,calendar_owned := false) -> bool:
	var dt := maxf(delta,0.0)
	if calendar_owned:
		_publish_left-=dt
		if _publish_left>0.0:return false
		_publish_left=.1
		return true
	var blend := 1.0-exp(-dt/12.0)
	weights=weights.lerp(_target_weights,blend)
	threat=lerpf(threat,_target_threat,blend)
	cyclone=lerpf(cyclone,_target_cyclone,blend)
	vortex=lerpf(vortex,_target_vortex,blend)
	wind_mps=wind_mps.lerp(_target_wind,blend)
	var soaking := clampf(weights.x+weights.y+weights.w*0.65,0.0,1.0)
	wetness=move_toward(wetness,1.0 if soaking>0.02 else 0.0,dt*(0.035*soaking if soaking>0.02 else 0.0012))
	var goal := 1.0 if formation==_target_formation and formation>0 else 0.0
	formation_strength=move_toward(formation_strength,goal,dt/40.0)
	if formation_strength<0.0001:formation=_target_formation
	phase+=dt*0.08
	if maxf(cyclone,_target_cyclone)>.001:cyclone_phase+=dt*.08
	else:cyclone_phase=0.0
	fog_offset=Vector2(fposmod(fog_offset.x+wind_mps.x*dt*0.002,1.0),fposmod(fog_offset.y+wind_mps.z*dt*0.002,1.0))
	_publish_left-=dt
	if _publish_left>0.0:return false
	_publish_left=0.1
	return true # Owner publishes at <=10 Hz, not every render frame.

## Reconstruct bounded wetting history from the existing saved clock/calendar.
## No hidden instance-time history or additional save domain.
func sample_calendar(date: Dictionary,transport_km: Vector2,precise_seconds := INF) -> void:
	weights=_target_weights;threat=_target_threat;cyclone=_target_cyclone
	vortex=_target_vortex;wind_mps=_target_wind;formation=_target_formation
	var seconds:=int(Time.get_unix_time_from_datetime_dict(date))
	var lightning:=preload("res://scripts/building/deterministic_lightning_manager.gd")
	var intensity_clock: float=precise_seconds if is_finite(precise_seconds) else float(seconds)
	weights*=lightning.precipitation_gain(intensity_clock)
	for i in 4:weights[i]=clampf(weights[i],0.0,1.0)
	var day_seconds:=float(posmod(seconds,86400))
	formation_strength=(smoothstep(0,1800,day_seconds)*(1.0-smoothstep(84600,86400,day_seconds))) if formation>0 else 0.0
	phase=float(seconds-Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00"))*.0005
	fog_offset=Vector2(fposmod(transport_km.x*2.0,1.0),fposmod(transport_km.y*2.0,1.0))
	var calendar:=preload("res://scripts/game/campaign_weather.gd")
	cyclone_phase=calendar.cyclone_age_at(float(seconds))*.0005
	var service:=preload("res://scripts/building/live_weather_service.gd")
	var boundary:=int(floor(float(seconds)/900.0))*900
	wetness=0.0
	for step in range(-24,1):
		var stamp:=boundary+step*900
		var dt:=900.0 if step<0 else float(seconds-boundary)
		var condition: Dictionary=service.presentation(calendar.snapshot(Time.get_datetime_dict_from_unix_time(stamp)))
		var liquid:=clampf(float(condition.get("rain_intensity",0))*lightning.precipitation_gain(float(stamp)),0,1)
		var goal:=1.0 if liquid>.02 else 0.0
		wetness=lerpf(goal,wetness,exp(-dt/(120.0/maxf(liquid,.05) if goal>0 else 2400.0)))

func _set_cyclone_target(value: float) -> void:
	_target_cyclone=value

## Fractional render motion is separate from the slower wetting-history rebuild.
func move_calendar_fields(stamp: float,transport: PackedFloat64Array) -> void:
	if not is_finite(stamp) or transport.size()!=2 or not is_finite(transport[0]) or not is_finite(transport[1]):return
	phase=(stamp-float(Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00")))*.0005
	cyclone_phase=preload("res://scripts/game/campaign_weather.gd").cyclone_age_at(stamp)*.0005
	fog_offset=Vector2(fposmod(transport[0]*2.0,1.0),fposmod(transport[1]*2.0,1.0))
	var day_seconds:=fposmod(stamp,86400.0)
	formation_strength=(smoothstep(0,1800,day_seconds)*(1.0-smoothstep(84600,86400,day_seconds))) if formation>0 else 0.0

func set_transport(transport: PackedFloat64Array,cloud_scale: float) -> void:
	if transport.size()!=2 or not is_finite(transport[0]) or not is_finite(transport[1]) or not is_finite(cloud_scale):return
	var x:=-transport[0];var z:=-transport[1]
	_cloud_drift=Vector4(fposmod(x*cloud_scale,1),fposmod(z*cloud_scale,1),fposmod(x*cloud_scale*4.3,1),fposmod(z*cloud_scale*4.3,1))
	_asperitas_drift=Vector4(fposmod(x*.8,1),fposmod(z*.8,1),fposmod(x*1.8,TAU),fposmod(z*2.3-x*.8,TAU))
	_cirrus_drift=Vector4(fposmod(x*.14,1),fposmod(z*.14,1),fposmod(x*.14*.7,1),fposmod(z*.14*1.3,1))
	_dust_drift=Vector2(fposmod(x*.6,1),fposmod(z*.6,1))

func publish(sky: ShaderMaterial,camera_position_m: Vector3,air: ShaderMaterial=null) -> void:
	RenderingServer.global_shader_parameter_set("wetness",wetness)
	var whiteout := smoothstep(0.60,1.0,weights.z)
	var parameters := {"severe_storm_threat":threat,"vortex_intensity":vortex,"wx_cyclone":cyclone,"wx_hail":weights.w,
		"wx_whiteout":whiteout,"wx_formation":formation,"wx_formation_strength":formation_strength,
		"wx_phase":fposmod(phase,TAU*2.0),"wx_cyclone_phase":cyclone_phase,
		"wx_texture_phase":fposmod(phase*.0001,1.0),"wx_fluctus_phase":fposmod(phase*.25,1.0),
		"wx_cloud_drift":_cloud_drift,"wx_asperitas_drift":_asperitas_drift,"wx_cirrus_drift":_cirrus_drift,
		"wx_camera_km":camera_position_m*0.001,"wx_iridescence_ramp":_ramp}
	for key: String in parameters:sky.set_shader_parameter(key,parameters[key])
	if air!=null:
		air.set_shader_parameter("cyclone_strength",cyclone)
		air.set_shader_parameter("whiteout_strength",whiteout)
		air.set_shader_parameter("fog_offset",fog_offset)
		air.set_shader_parameter("dust_offset",_dust_drift)

func lighting(base_sun: Color,base_energy: float,base_ambient: Color,base_ambient_energy: float,to_sun: Vector3,base_saturation: float=1.0) -> Dictionary:
	# Apply these returned values at the END of the existing DayNightDirector profile.
	# Do not run another Node that fights its DirectionalLight3D every frame.
	var green := threat*smoothstep(0.005,0.045,to_sun.y)*(1.0-smoothstep(0.20,0.42,to_sun.y))
	return {"sun_color":base_sun.lerp(Color(0.48,0.82,0.20),green),
		"sun_energy":base_energy*lerpf(1.0,0.02,cyclone)*lerpf(1.0,0.45,threat),
		"ambient_color":base_ambient.lerp(Color(0.19,0.24,0.31),cyclone*0.88),
		"ambient_energy":base_ambient_energy*(1.0-0.12*wetness)*lerpf(1.0,0.72,cyclone),
		"saturation":lerpf(base_saturation,base_saturation*0.25,cyclone)}

static func gpu_precipitation(parent_camera: Camera3D,motion: Shader,draw_shader: Shader) -> Array[GPUParticles3D]:
	# Call ONCE during preparation. Splash emission comes from actual rain contact.
	var result: Array[GPUParticles3D]=[]
	var counts := [1800,600,1200,220]
	var sizes := [Vector2(0.018,0.60),Vector2(0.020,0.16),Vector2(0.065,0.065),Vector2(0.028,0.028)]
	for kind in 4:
		var process := ShaderMaterial.new();process.shader=motion
		process.set_shader_parameter("kind",kind)
		var visual := ShaderMaterial.new();visual.shader=draw_shader
		visual.set_shader_parameter("kind",kind)
		var quad: Mesh
		if kind==3:
			var ice:=SphereMesh.new();ice.radius=.014;ice.height=.028;ice.radial_segments=8;ice.rings=4
			quad=ice
		else:
			var sprite:=QuadMesh.new();sprite.size=sizes[kind];quad=sprite
		quad.material=visual
		var emitter := GPUParticles3D.new()
		emitter.name=["GPUWeatherRain","GPUWeatherSleet","GPUWeatherSnow","GPUWeatherHail"][kind]
		emitter.amount=counts[kind];emitter.amount_ratio=0.0
		emitter.lifetime=9.0 if kind==2 else 2.0
		emitter.local_coords=false;emitter.fixed_fps=60
		emitter.use_fixed_seed=true;emitter.seed=1928+kind
		emitter.layers=1<<18;emitter.collision_base_size=.014
		emitter.visibility_aabb=AABB(Vector3(-25,-20,-25),Vector3(50,40,50))
		emitter.process_material=process;emitter.draw_pass_1=quad
		emitter.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		emitter.set_meta("surface_role","weather_optics")
		emitter.emitting=false
		parent_camera.add_child(emitter);emitter.top_level=true
		result.append(emitter)
	var splash:=GPUParticles3D.new();splash.name="GPUWeatherSplash"
	splash.amount=256;splash.lifetime=.35;splash.local_coords=false;splash.fixed_fps=60
	splash.layers=1<<18;splash.emitting=false;splash.use_fixed_seed=true;splash.seed=1932
	splash.visibility_aabb=AABB(Vector3(-25,-20,-25),Vector3(50,40,50))
	splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash.set_meta("surface_role","weather_optics")
	var splash_process:=ShaderMaterial.new();splash_process.shader=motion;splash_process.set_shader_parameter("kind",4)
	var splash_draw:=ShaderMaterial.new();splash_draw.shader=draw_shader;splash_draw.set_shader_parameter("kind",4)
	var splash_mesh:=QuadMesh.new();splash_mesh.size=Vector2(.045,.07);splash_mesh.material=splash_draw
	splash.process_material=splash_process;splash.draw_pass_1=splash_mesh
	parent_camera.add_child(splash);splash.top_level=true;result.append(splash)
	result[0].sub_emitter=result[0].get_path_to(splash)
	return result

func update_emitters(emitters: Array[GPUParticles3D],camera_position_m: Vector3,outdoors: bool,wind_gain := 1.0,view_camera: Camera3D=null) -> void:
	# Called by existing WeatherFX. Reuse its roof/ceiling exposure authority.
	var forward: Vector3=-view_camera.global_basis.z if view_camera!=null else Vector3.FORWARD
	var right: Vector3=view_camera.global_basis.x if view_camera!=null else Vector3.RIGHT
	var half_fov:=tan(deg_to_rad(view_camera.fov if view_camera!=null else 72.0)*.5)
	var aspect:=float(view_camera.get_viewport().get_visible_rect().size.x)/maxf(1.0,float(view_camera.get_viewport().get_visible_rect().size.y)) if view_camera!=null else 1.78
	var pixel_angle:=half_fov*2.0/float(view_camera.get_viewport().get_visible_rect().size.y) if view_camera!=null else .001
	if emitters.size()>4:
		emitters[4].global_position=camera_position_m
		emitters[4].visible=outdoors
	for kind in mini(emitters.size(),4):
		var emitter := emitters[kind]
		emitter.global_transform=Transform3D(Basis.IDENTITY,camera_position_m+Vector3.UP*3.0-wind_mps*wind_gain*0.12)
		emitter.amount_ratio=sqrt(clampf(weights[kind],0.0,1.0))
		emitter.emitting=outdoors and weights[kind]>0.005
		emitter.visible=outdoors
		var process:=emitter.process_material as ShaderMaterial
		process.set_shader_parameter("wind_mps",wind_mps*wind_gain)
		process.set_shader_parameter("intensity",weights[kind])
		process.set_shader_parameter("camera_forward",forward);process.set_shader_parameter("camera_right",right)
		process.set_shader_parameter("camera_y",camera_position_m.y)
		process.set_shader_parameter("horizontal_tangent",half_fov*aspect)
		if view_camera!=null:process.set_shader_parameter("view_projection",view_camera.get_camera_projection()*Projection(view_camera.get_camera_transform().affine_inverse()))
		var visual:=emitter.draw_pass_1.material as ShaderMaterial
		visual.set_shader_parameter("wind_mps",wind_mps*wind_gain)
		visual.set_shader_parameter("intensity",weights[kind]);visual.set_shader_parameter("pixel_angle",pixel_angle)
