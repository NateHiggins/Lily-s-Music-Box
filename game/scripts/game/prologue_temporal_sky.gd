extends Node
## A bounded presentation clip, never an intermediate campaign/weather writer.
signal finished(completed:bool)
const DURATION:=32.0
const State:=preload("res://scripts/game/prologue_state.gd")
const Living:=preload("res://scripts/building/living_sky.gd")
const Calendar:=preload("res://scripts/game/campaign_weather.gd")
const Weather:=preload("res://scripts/building/WeatherManager.gd")
const Astronomy:=preload("res://scripts/building/skywatch_astronomy.gd")
const Stinger:=preload("res://scripts/game/prologue_tardi_stinger.gd")

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
var failure:=""
var active:=false
var holding:=false
var cutaway:Node
var age:=0.0
var sampled_utc:=0.0
var publications:=0
var was_skipped:=false
var profile_samples:=false
var sample_costs:Array=[]
var finish_costs:Dictionary={}
var source_utc:=0.0
var destination_utc:=0.0
var _travel_destination:=0.0
var view_clock:=RenderClock.new()
var _campaign:Dictionary
var _completion:Callable
var _cutaway_completion:Callable
var _old_mode:int
var _old_camera:Camera3D
var _old_clock:CampaignClock
var _old_conditions:Dictionary
var _old_extreme:RefCounted
var _view_extreme:RefCounted
var _old_parameters:Dictionary={}
var _particles:Array[Dictionary]=[]
var _audio:Array[Dictionary]=[]
var _late_audio:Array[Node]=[]
var _canvas_layers:Array[CanvasLayer]=[]
var _watching_tree:SceneTree
var _start:Transform3D
var _window:Vector3
var _above:Vector3
var _outward:Vector3
var _publish_age:=-INF
var _published_utc:=INF
var _published_camera:=Vector3(INF,INF,INF)
var _view_departed:=false
var _carrier:Node
var _quiet:=false
var _veil:ColorRect
var _treatment:Node3D
var _aperture_borrowed:=false
var _crossing_distance:=.5
var _window_start:Transform3D

func _init() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_process(false);set_process_unhandled_input(false)

static func time_at(seconds:float,source:float,destination:float) -> float:
	var span:=absf(destination-source)
	if span<.00001:return destination
	if seconds<=2:return source
	if seconds>=30:return destination
	var u:=(seconds-2.0)/28.0
	# Integrate one speed envelope: log(speed) is a smooth parabola, rather
	# than stopping at every date knot. Subtract its tiny endpoint speed so
	# the two-second holds join at rest. Span controls the orders of magnitude.
	var k:=clampf(4.0*log(maxf(1.0,span/28.0)),12.0,96.0)
	var root:=sqrt(k)
	var base:=exp(-k*.25)
	var end_tail:=_erfc(root*.5)
	var width:=sqrt(PI/k)
	# Integrate from the nearer end to retain seconds at a century's end.
	var near_end:=minf(u,1.0-u)
	var area:=.5*width*(_erfc(root*(.5-near_end))-end_tail)-base*near_end
	var fraction:=clampf(area/(width*(_erfc(0)-end_tail)-base),0,.5)
	return lerpf(source,destination,fraction if u<=.5 else 1.0-fraction)

static func _erfc(x:float) -> float:
	# Complementary Gaussian integral; x>=0. Bounded, no per-frame quadrature.
	var t:=1.0/(1.0+.5*x)
	return t*exp(-x*x-1.26551223+t*(1.00002368+t*(.37409196+t*(.09678418+t*(-.18628806+t*(.27886807+t*(-1.13520398+t*(1.48851587+t*(-.82215223+t*.17087277)))))))))

func start(owner_world:Node3D,completion:Callable,cutaway_completion:Callable=Callable()) -> bool:
	if active or get_tree().paused or not is_instance_valid(owner_world) or not completion.is_valid():return _refuse("active, paused or missing owner/completion")
	var opening:=State.restore(RealityState.data.get("prologue",{}))
	if opening.is_empty() or opening.target.is_empty():return _refuse("missing validated destination")
	var resuming:bool=opening.phase=="title_reveal" and opening.effects.clock_applied
	if not resuming and (opening.phase!="temporal_synchronization" or opening.effects.clock_applied):return _refuse("opening phase or clock acknowledgement changed")
	if resuming and not cutaway_completion.is_valid():return _refuse("missing cutaway completion")
	world=owner_world;player=world.player;director=world.day_night_director
	var atmosphere:=world.get_node_or_null("WakingAtmosphere")
	if player==null or director==null or atmosphere==null:return _refuse("missing existing atmosphere or player")
	manager=atmosphere.weather_manager
	if manager==null or manager.extreme_weather==null or not _find_window():return _refuse("missing installed window or weather owner")
	var clock:=CampaignClock.new()
	if not clock.bind_state():return _refuse("campaign clock refused binding")
	source_utc=State.wrap_loop_utc(Calendar.clock_seconds(clock)+18000.0)
	destination_utc=float(State.annual_destination(opening.target).utc_unix_seconds)
	_travel_destination=State.showcase_end(source_utc,destination_utc)
	if not view_clock.seek_utc(destination_utc):return _refuse("detached clock refused destination")
	if not player.acquire_text_input(self):return _refuse("player input lease refused: protected=%s inspection=%s mouse_released=%s owner=%s"%[player.protected_input_active(),player.inspecting(),player.mouse_released,str(player.text_input_owner)])
	_campaign=RealityState.data;_completion=completion;_cutaway_completion=cutaway_completion;_old_mode=world.process_mode
	_old_camera=get_viewport().get_camera_3d();_start=_old_camera.global_transform
	_old_clock=director._campaign_clock;_old_conditions=director._live_conditions.duplicate(true)
	_old_extreme=director.extreme_weather
	_view_extreme=preload("res://scripts/building/queens_weather_extension.gd").new()
	for uniform:Dictionary in manager.sky.shader.get_shader_uniform_list():
		_old_parameters[str(uniform.name)]=manager.sky.get_shader_parameter(uniform.name)
	for node:Node in world.find_children("*","",true,false):
		if is_ancestor_of(node):continue # Our own veil/audio must remain owned by this cinematic.
		if node is GPUParticles3D:
			_particles.append({"node":node,"speed":node.speed_scale});node.speed_scale=0
		if node is CanvasLayer:_canvas_layers.append(node)
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			_audio.append({"node":node,"pitch":node.pitch_scale,"volume":node.volume_db})
			node.pitch_scale*=.25;node.volume_db-=8
	_watching_tree=get_tree();_watching_tree.node_added.connect(_track_added)
	_carrier=world.service_set_carrier
	world.process_mode=Node.PROCESS_MODE_DISABLED
	director._campaign_clock=view_clock
	director.extreme_weather=_view_extreme
	camera=Camera3D.new();camera.name="TemporalWindowCamera";add_child(camera)
	camera.fov=_old_camera.fov;camera.environment=_old_camera.environment;camera.cull_mask=_old_camera.cull_mask
	camera.near=_old_camera.near;camera.far=_old_camera.far;camera.keep_aspect=_old_camera.keep_aspect
	camera.global_transform=_start # Retain the real reading observer until departure.
	_quiet=bool(GameBoot.settings.get("reduce_flashing",false))
	var layer:=CanvasLayer.new();layer.layer=80;add_child(layer)
	_veil=ColorRect.new();layer.add_child(_veil);_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;_veil.color=Color(0,0,0,0)
	if resuming:
		holding=true
		if _start_cutaway():return true
		_cleanup();return false
	if not _treatment.begin_story_aperture(self):
		_cleanup();return _refuse("window presentation already owned")
	_aperture_borrowed=true
	var aperture:Transform3D=_treatment.story_aperture_frame(self)
	_window=aperture.origin;_outward=-aperture.basis.z.normalized()
	_above=_window+_outward*2.0+Vector3.UP*12.0
	_window_start=Transform3D(Basis.looking_at(_outward,Vector3.UP),_window-_outward*1.45)
	active=true;age=0;_publish_age=-INF
	if _carrier.rig.temporal_register==null or not _carrier.rig.temporal_register.begin(self,opening.target):
		_cleanup();return _refuse("temporal hardware is not safely powered and stowed")
	set_process(true);set_process_unhandled_input(true);seek(0)
	return true

## Capture only newly mounted presentation owners while the world is borrowed.
## Avoid rescanning the complete building at the historical handoff.
func _track_added(node:Node) -> void:
	if node is not AudioStreamPlayer and node is not AudioStreamPlayer3D and node is not CanvasLayer:return
	if not is_instance_valid(world) or not world.is_ancestor_of(node) or is_ancestor_of(node):return
	if node is CanvasLayer:_canvas_layers.append(node)
	else:_late_audio.append(node)

func _find_window() -> bool:
	# The bath's labelled east window faces retained interior stock. Cut to
	# the sleeping alcove's real west exterior opening; do not invent a view.
	for record:Dictionary in world.layout.windows:
		if str(record.space)!="F04_B_ALCOVE" or str(record.axis)!="z":continue
		var root:Node3D=world.adapter.root
		var opening:=root.get_node_or_null(str(record.id))
		if opening==null:return false
		_treatment=opening.get_node_or_null("WindowTreatment")
		if _treatment==null:return false
		var span:Vector2=root.window_reveal_span(record)
		# Start the rise only beyond the complete installed masonry reveal.
		_crossing_distance=maxf(.5,span.y-span.x+.30)
		_window=root.to_global(Vector3(float(record.center[0]),float(root.level_y[record.level])+float(record.sill)+float(record.height)*.82,float(record.center[1])))
		_outward=(root.global_basis*Vector3.RIGHT).normalized()
		_above=_window+_outward*2.0+Vector3.UP*12.0
		return true
	return false

func seek(seconds:float) -> void:
	if not active or not is_finite(seconds):return
	age=clampf(seconds,0,DURATION)
	sampled_utc=destination_utc if age>=30 else State.wrap_loop_utc(time_at(age,source_utc,_travel_destination))
	if not view_clock.seek_utc(sampled_utc):cancel();return
	if _carrier.rig.temporal_register != null:
		var register:Node=_carrier.rig.temporal_register
		register.sample_clock(self,sampled_utc)
		# The world is borrowed/disabled: use this existing cinematic clock for
		# the reveal instead of leaving an inert process callback behind it.
		register._set_opening(clampf(age/(register.OPEN_END-register.OPEN_START),0,1))
	var entering:=smoothstep(4.0,5.0,age)
	var crossing:=smoothstep(5.0,6.2,age)
	var rising:=smoothstep(6.2,8.0,age)
	# Stay parallel to the slats until outside the complete wall reveal.
	# A deliberate cut after the suspended bathroom hold avoids crossing
	# rooms, doors or closed walls on the way to the verified exterior.
	var start_view:=_start if age<4 else _window_start
	var at:=start_view.origin.lerp(_window-_outward*_crossing_distance,entering)
	at=at.lerp(_window+_outward*_crossing_distance,crossing).lerp(_above,rising)
	var aim:=Basis.looking_at((_outward+Vector3.UP*lerpf(.03,.55,rising)).normalized(),Vector3.UP)
	camera.global_transform=Transform3D(start_view.basis.slerp(aim,entering),at)
	camera.near=lerpf(_old_camera.near,.002,smoothstep(4,5,age)*(1-smoothstep(6.2,8.0,age)))
	if age>=4.0:
		if not _view_departed:
			if not _old_camera.is_current() and not camera.is_current():cancel();return
			camera.make_current();_view_departed=true
		if not _carrier.is_story_absent():_carrier.acquire_story_absence(self)
	elif camera.is_current():_old_camera.make_current();_view_departed=false
	# Normal presentation crosses the actual opening without a blackout.
	# Reduced-flash presentation still protects against rapid day/night cycles.
	_veil.color.a=(smoothstep(4,6,age)*(1-smoothstep(29,31,age))) if _quiet else 0.0
	# Bounded morphology/ephemeris work, independent of elapsed campaign days.
	if (sampled_utc!=_published_utc or camera.global_position!=_published_camera) and (age-_publish_age>=.05 or age<_publish_age or (age>=30 and _publish_age<30)):
		_publish_age=age;_published_utc=sampled_utc;_published_camera=camera.global_position;_publish()
	if age>=DURATION:_finish()

func _publish() -> void:
	var started:int=Time.get_ticks_usec() if profile_samples else 0
	var date:=view_clock.local_datetime()
	var authored:=Calendar.snapshot(date)
	var conditions:=Weather.Service.presentation(authored if not authored.is_empty() else Weather.seasonal_snapshot(date))
	# Every detached sample is in the authored year; no modern-year weather proxy.
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
	var expected:Camera3D=camera if _view_departed else _old_camera
	if get_viewport().get_camera_3d()!=expected:cancel();return
	if not is_same(_campaign,RealityState.data) or RealityState.save_write_blocked or player.protected_input_active() or player.text_input_owner!=self:cancel();return
	seek(age+delta)

func _unhandled_input(event:InputEvent) -> void:
	if not active or get_tree().paused or event.is_echo():return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled();was_skipped=true;seek(DURATION)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled();cancel()

func _finish() -> void:
	var began:int=Time.get_ticks_usec() if profile_samples else 0
	if _cutaway_completion.is_valid():
		active=false;holding=true;set_process(false);set_process_unhandled_input(false)
		var accepted:bool=_completion.call() if _completion.is_valid() else false
		if accepted and holding and _start_cutaway():
			if profile_samples:finish_costs["handoff_ms"]=(Time.get_ticks_usec()-began)/1000.0
			finished.emit(true);return
		finish_cutaway(false);return
	_cleanup()
	var cleaned:int=Time.get_ticks_usec() if profile_samples else 0
	var accepted:bool=_completion.call() if _completion.is_valid() else false
	var committed:int=Time.get_ticks_usec() if profile_samples else 0
	if accepted and is_instance_valid(manager):
		manager._calendar_check_left=0;manager._publish_left=0;manager._phenomena_left=0
		manager._process(0)
		director._apply(director._campaign_clock.minute_of_day())
	if profile_samples:
		finish_costs.merge({"cleanup_ms":(cleaned-began)/1000.0,"clock_callback_ms":(committed-cleaned)/1000.0,"weather_refresh_ms":(Time.get_ticks_usec()-committed)/1000.0},true)
	finished.emit(accepted)

func _start_cutaway() -> bool:
	if not _carrier.is_story_absent() and not _carrier.acquire_story_absence(self):return false
	cutaway=Stinger.new();add_child(cutaway)
	if not cutaway.start(self,_cutaway_completion):return false
	if was_skipped:finish_cutaway(bool(_cutaway_completion.call(true)))
	return true

func finish_cutaway(_accepted:bool) -> void:
	if not holding:return
	var began:int=Time.get_ticks_usec() if profile_samples else 0
	if is_instance_valid(cutaway):cutaway.release()
	_cleanup()
	_refresh_destination()
	if profile_samples:finish_costs["cutaway_release_ms"]=(Time.get_ticks_usec()-began)/1000.0

func _refresh_destination() -> void:
	var opening:=State.restore(RealityState.data.get("prologue",{}))
	if opening.is_empty() or not opening.effects.clock_applied:return
	if is_instance_valid(manager) and is_instance_valid(director):
		manager._calendar_check_left=0;manager._publish_left=0;manager._phenomena_left=0
		manager._process(0);director._apply(director._campaign_clock.minute_of_day())

func cancel() -> void:
	if not active and not holding:return
	_cleanup();_refresh_destination();finished.emit(false)

func _cleanup() -> void:
	var began:int=Time.get_ticks_usec() if profile_samples else 0
	if _aperture_borrowed and is_instance_valid(_treatment):_treatment.end_story_aperture(self)
	_aperture_borrowed=false
	if _watching_tree!=null and _watching_tree.node_added.is_connected(_track_added):_watching_tree.node_added.disconnect(_track_added)
	_watching_tree=null
	if is_instance_valid(cutaway):cutaway.release()
	_late_audio.clear();_canvas_layers.clear()
	active=false;holding=false;set_process(false);set_process_unhandled_input(false)
	if is_instance_valid(director):
		director._campaign_clock=_old_clock;director._live_conditions=_old_conditions;director.extreme_weather=_old_extreme
		director._apply(_old_clock.minute_of_day())
	var lighting:int=Time.get_ticks_usec() if profile_samples else 0
	if is_instance_valid(manager):
		for parameter:String in _old_parameters:manager.sky.set_shader_parameter(parameter,_old_parameters[parameter])
	_old_parameters.clear()
	_view_extreme=null
	var parameters:int=Time.get_ticks_usec() if profile_samples else 0
	if is_instance_valid(camera):
		if camera.is_current() and is_instance_valid(_old_camera) and _old_camera.is_inside_tree():_old_camera.make_current()
		camera.queue_free()
	if is_instance_valid(_veil):_veil.get_parent().queue_free()
	var view:int=Time.get_ticks_usec() if profile_samples else 0
	for record:Dictionary in _particles:
		if is_instance_valid(record.node):record.node.speed_scale=record.speed
	_particles.clear()
	for record:Dictionary in _audio:
		if is_instance_valid(record.node):record.node.pitch_scale=record.pitch;record.node.volume_db=record.volume
	_audio.clear()
	var effects:int=Time.get_ticks_usec() if profile_samples else 0
	if is_instance_valid(_carrier):_carrier.release_story_absence(self)
	if is_instance_valid(_carrier) and _carrier.rig.temporal_register != null:_carrier.rig.temporal_register.release(self,true)
	var carrier:int=Time.get_ticks_usec() if profile_samples else 0
	if is_instance_valid(player):player.release_text_input(self)
	var input:int=Time.get_ticks_usec() if profile_samples else 0
	if is_instance_valid(world) and world.process_mode==Node.PROCESS_MODE_DISABLED:world.process_mode=_old_mode
	if profile_samples:
		finish_costs.merge({"restore_lighting_ms":(lighting-began)/1000.0,"restore_parameters_ms":(parameters-lighting)/1000.0,"restore_view_ms":(view-parameters)/1000.0,"restore_effects_ms":(effects-view)/1000.0,"release_carrier_ms":(carrier-effects)/1000.0,"release_input_ms":(input-carrier)/1000.0,"resume_world_ms":(Time.get_ticks_usec()-input)/1000.0},true)

func _exit_tree() -> void:
	if active or holding:_cleanup()

func _refuse(reason:String) -> bool:
	failure=reason
	return false
