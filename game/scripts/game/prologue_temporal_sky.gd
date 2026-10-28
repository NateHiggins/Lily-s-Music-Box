extends Node
## A bounded presentation clip, never an intermediate campaign/weather writer.
signal finished(completed:bool)
const DURATION:=32.0
const State:=preload("res://scripts/game/prologue_state.gd")
const Living:=preload("res://scripts/building/living_sky.gd")
const Calendar:=preload("res://scripts/game/campaign_weather.gd")
const Weather:=preload("res://scripts/building/WeatherManager.gd")
const Astronomy:=preload("res://scripts/building/skywatch_astronomy.gd")

class RenderClock extends CampaignClock:
	## Detached read-only projection. No binding, creation, migration or save.
	func bind_state() -> bool:return not _state.is_empty()
	func configure_date(_year:int,_month:int,_day:int,_minute:=0) -> bool:return false
	func configure_start(_day:String,_doy:=1,_minute:=0) -> bool:return false
	func advance_to(_minute:float) -> bool:return false
	func advance_seconds(_seconds:float) -> void:pass
	func apply_prologue_destination() -> bool:return false
	func seek_utc(seconds:float) -> bool:
		if not is_finite(seconds) or seconds-18000<State.MIN_UNIX or seconds-18000>State.MAX_UNIX:return false
		var date:=Time.get_datetime_dict_from_unix_time(int(floor(seconds))-18000)
		_state=_civil_record({"year":date.year,"month":date.month,"day_of_month":date.day},int(date.hour)*60+int(date.minute))
		_state.elapsed_minutes=(float(date.second)+fposmod(seconds,1.0))/60.0
		return true

var world:Node3D
var director:Node
var manager:Node
var camera:Camera3D
var player:PlayerController
var active:=false
var age:=0.0
var sampled_utc:=0.0
var publications:=0
var was_skipped:=false
var profile_samples:=false
var sample_costs:Array=[]
var finish_costs:Dictionary={}
var source_utc:=0.0
var destination_utc:=0.0
var view_clock:=RenderClock.new()
var _campaign:Dictionary
var _completion:Callable
var _old_mode:int
var _old_camera:Camera3D
var _old_clock:CampaignClock
var _old_conditions:Dictionary
var _old_extreme:RefCounted
var _view_extreme:RefCounted
var _representatives:Dictionary={}
var _old_parameters:Dictionary={}
var _particles:Array[Dictionary]=[]
var _audio:Array[Dictionary]=[]
var _start:Transform3D
var _window:Vector3
var _above:Vector3
var _outward:Vector3
var _publish_age:=-INF
var _published_utc:=INF
var _published_camera:=Vector3(INF,INF,INF)
var _carrier:Node
var _quiet:=false
var _veil:ColorRect

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process(false);set_process_unhandled_input(false)

static func time_at(seconds:float,source:float,destination:float) -> float:
	var span:=absf(destination-source)
	if span<.00001:return destination
	var knots:Array=[[0.0,0.0],[2.0,0.0],[5.0,minf(172800/span,.01)],
		[9.0,minf(5184000/span,.08)],[15.0,.55],
		[20.0,maxf(.70,1-minf(31536000/span,.30))],
		[24.0,maxf(.90,1-minf(604800/span,.10))],
		[27.0,maxf(.98,1-minf(21600/span,.02))],
		[29.0,maxf(.999,1-minf(120/span,.001))],[30.0,1.0],[DURATION,1.0]]
	for index in range(knots.size()-1):
		var a:Array=knots[index];var b:Array=knots[index+1]
		if seconds<=b[0]:return lerpf(source,destination,lerpf(a[1],b[1],smoothstep(a[0],b[0],maxf(0,seconds))))
	return destination

func start(owner_world:Node3D,completion:Callable) -> bool:
	if active or get_tree().paused or not is_instance_valid(owner_world) or not completion.is_valid():return false
	var opening:=State.restore(RealityState.data.get("prologue",{}))
	if opening.is_empty() or opening.phase!="temporal_synchronization" or opening.target.is_empty() or opening.effects.clock_applied:return false
	world=owner_world;player=world.player;director=world.day_night_director
	var atmosphere:=world.get_node_or_null("WakingAtmosphere")
	if player==null or director==null or atmosphere==null:return false
	manager=atmosphere.weather_manager
	if manager==null or manager.extreme_weather==null or not _find_window():return false
	var clock:=CampaignClock.new()
	if not clock.bind_state():return false
	source_utc=Calendar.clock_seconds(clock)+18000.0
	destination_utc=float(opening.target.utc_unix_seconds)
	if not view_clock.seek_utc(destination_utc) or not player.acquire_text_input(self):return false
	_campaign=RealityState.data;_completion=completion;_old_mode=world.process_mode
	_old_camera=get_viewport().get_camera_3d();_start=_old_camera.global_transform
	_old_clock=director._campaign_clock;_old_conditions=director._live_conditions.duplicate(true)
	_old_extreme=director.extreme_weather
	_view_extreme=preload("res://scripts/building/queens_weather_extension.gd").new()
	for date:String in Calendar._dates:_representatives[date.substr(5)]=date
	for uniform:Dictionary in manager.sky.shader.get_shader_uniform_list():
		_old_parameters[str(uniform.name)]=manager.sky.get_shader_parameter(uniform.name)
	for node:Node in world.find_children("*","GPUParticles3D",true,false):
		_particles.append({"node":node,"speed":node.speed_scale});node.speed_scale=0
	for node:Node in world.find_children("*","",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			_audio.append({"node":node,"pitch":node.pitch_scale,"volume":node.volume_db})
			node.pitch_scale*=.25;node.volume_db-=8
	_carrier=world.service_set_carrier
	world.process_mode=Node.PROCESS_MODE_DISABLED
	director._campaign_clock=view_clock
	director.extreme_weather=_view_extreme
	camera=Camera3D.new();camera.name="TemporalWindowCamera";add_child(camera)
	camera.fov=_old_camera.fov;camera.environment=_old_camera.environment;camera.cull_mask=_old_camera.cull_mask
	camera.near=_old_camera.near;camera.far=_old_camera.far;camera.keep_aspect=_old_camera.keep_aspect
	camera.global_transform=_start;camera.make_current()
	_quiet=bool(GameBoot.settings.get("reduce_flashing",false))
	var layer:=CanvasLayer.new();layer.layer=80;add_child(layer)
	_veil=ColorRect.new();layer.add_child(_veil);_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;_veil.color=Color(0,0,0,0)
	active=true;age=0;_publish_age=-INF
	set_process(true);set_process_unhandled_input(true);seek(0)
	return true

func _find_window() -> bool:
	# The installed sanitary-room opening supplies the camera datums.
	for record:Dictionary in world.layout.windows:
		if str(record.space)!="F04_B_BATH":continue
		var root:Node3D=world.adapter.root
		_window=root.to_global(Vector3(float(record.center[0]),float(root.level_y[record.level])+float(record.sill)+float(record.height)*.82,float(record.center[1])))
		_outward=(root.global_basis*Vector3.RIGHT).normalized()
		_above=_window+_outward*2.0+Vector3.UP*12.0
		return true
	return false

func seek(seconds:float) -> void:
	if not active or not is_finite(seconds):return
	age=clampf(seconds,0,DURATION)
	sampled_utc=time_at(age,source_utc,destination_utc)
	if not view_clock.seek_utc(sampled_utc):cancel();return
	var entering:=smoothstep(1.5,5.0,age)
	var rising:=smoothstep(4.5,6.5,age)
	var at:=_start.origin.lerp(_window-_outward*.45,entering).lerp(_above,rising)
	var aim:=Basis.looking_at((_outward+Vector3.UP*lerpf(.03,.55,rising)).normalized(),Vector3.UP)
	camera.global_transform=Transform3D(_start.basis.slerp(aim,entering),at)
	if age>=1.5 and not _carrier.is_story_absent():_carrier.acquire_story_absence(self)
	# The dark aperture hides the passage through closed glazing/linen. No
	# physical curtain, window, collision or saved household state is changed.
	_veil.color.a=(smoothstep(2,4,age)*(1-smoothstep(29,31,age))) if _quiet else smoothstep(3.7,4.5,age)*(1-smoothstep(5.6,6.8,age))
	# Bounded morphology/ephemeris work, independent of elapsed campaign days.
	if (sampled_utc!=_published_utc or camera.global_position!=_published_camera) and (age-_publish_age>=.05 or age<_publish_age or (age>=30 and _publish_age<30)):
		_publish_age=age;_published_utc=sampled_utc;_published_camera=camera.global_position;_publish()
	if age>=DURATION:_finish()

func _publish() -> void:
	var started:int=Time.get_ticks_usec() if profile_samples else 0
	var date:=view_clock.local_datetime()
	var authored:=Calendar.snapshot(date)
	var conditions:=Weather.Service.presentation(authored if not authored.is_empty() else Weather.seasonal_snapshot(date))
	# Representative seasonal weather is visual art, never historical reporting.
	var month_day:="%02d-%02d"%[date.month,date.day]
	if age<29 and _representatives.has(month_day):
		var representative:=Time.get_datetime_dict_from_datetime_string(str(_representatives[month_day])+"T%02d:%02d:%02d"%[date.hour,date.minute,date.second],false)
		var borrowed:=Weather.Service.presentation(Calendar.snapshot(representative))
		conditions=Weather.interpolate(borrowed,conditions,smoothstep(24,29,age))
	conditions.season_weights=Weather.season_weights(int(date.month),int(date.day))
	var shape:=Living.sample(date,conditions,manager._seed_value())
	Living.publish(manager.sky,shape)
	var transport:=Calendar.cloud_transport_at(sampled_utc-18000)
	_view_extreme.receive_conditions(conditions,Calendar.date_key(date),manager._seed_value())
	_view_extreme.project_sky(sampled_utc-18000,transport)
	var parameters:Dictionary=_view_extreme.sky_parameters(camera.global_position)
	for parameter:String in parameters:manager.sky.set_shader_parameter(parameter,parameters[parameter])
	# These are presentation inputs. Never call manager._publish or emit its
	# conditions_changed signal for any of the intermediate dates.
	var weather:WeatherFX=director._weather;var exterior:ExteriorDetailPass=director._exterior
	director._weather=null;director._exterior=null;director._live_conditions=conditions
	director._apply(view_clock.minute_of_day())
	director._weather=weather;director._exterior=exterior
	Astronomy.publish_star_frame(manager.sky,camera,view_clock)
	manager.sky.set_shader_parameter("season_weights",conditions.season_weights)
	manager.sky.set_shader_parameter("humidity",float(conditions.relative_humidity))
	manager.sky.set_shader_parameter("storm_strength",float(conditions.precipitation_intensity))
	publications+=1
	if profile_samples and sample_costs.size()<4096:sample_costs.append([age,sampled_utc,(Time.get_ticks_usec()-started)/1000.0])

func _process(delta:float) -> void:
	if not active or get_tree().paused:return
	if not is_same(_campaign,RealityState.data) or RealityState.save_write_blocked:cancel();return
	seek(age+delta)

func _unhandled_input(event:InputEvent) -> void:
	if not active or get_tree().paused or event.is_echo():return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled();was_skipped=true;seek(DURATION)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled();cancel()

func _finish() -> void:
	var began:int=Time.get_ticks_usec() if profile_samples else 0
	_cleanup()
	var cleaned:int=Time.get_ticks_usec() if profile_samples else 0
	var accepted:bool=_completion.call() if _completion.is_valid() else false
	var committed:int=Time.get_ticks_usec() if profile_samples else 0
	if accepted and is_instance_valid(manager):
		manager._calendar_check_left=0;manager._publish_left=0;manager._phenomena_left=0
		manager._process(0)
		director._apply(director._campaign_clock.minute_of_day())
	if profile_samples:
		finish_costs={"cleanup_ms":(cleaned-began)/1000.0,"clock_callback_ms":(committed-cleaned)/1000.0,"weather_refresh_ms":(Time.get_ticks_usec()-committed)/1000.0}
	finished.emit(accepted)

func cancel() -> void:
	if not active:return
	_cleanup();finished.emit(false)

func _cleanup() -> void:
	active=false;set_process(false);set_process_unhandled_input(false)
	if is_instance_valid(director):
		director._campaign_clock=_old_clock;director._live_conditions=_old_conditions;director.extreme_weather=_old_extreme
		director._apply(_old_clock.minute_of_day())
	if is_instance_valid(manager):
		for parameter:String in _old_parameters:manager.sky.set_shader_parameter(parameter,_old_parameters[parameter])
	_old_parameters.clear()
	_view_extreme=null
	if is_instance_valid(camera):
		if camera.is_current() and is_instance_valid(_old_camera) and _old_camera.is_inside_tree():_old_camera.make_current()
		camera.queue_free()
	if is_instance_valid(_veil):_veil.get_parent().queue_free()
	for record:Dictionary in _particles:
		if is_instance_valid(record.node):record.node.speed_scale=record.speed
	_particles.clear()
	for record:Dictionary in _audio:
		if is_instance_valid(record.node):record.node.pitch_scale=record.pitch;record.node.volume_db=record.volume
	_audio.clear()
	if is_instance_valid(_carrier):_carrier.release_story_absence(self)
	if is_instance_valid(player):player.release_text_input(self)
	if is_instance_valid(world) and world.process_mode==Node.PROCESS_MODE_DISABLED:world.process_mode=_old_mode

func _exit_tree() -> void:
	if active:_cleanup()
