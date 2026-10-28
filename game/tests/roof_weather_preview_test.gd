extends "res://scripts/building/roof_weather_preview.gd"
## Occupied roof + engine-dispatched movement input. Isolated preview diagnostic, no
## save/reload acceptance or claim that the full weather brief is finished.
var checks: Array[Dictionary]=[]
var captures: Array[String]=[]
var directory := ""
var original_clock: Dictionary
var frame_samples: Array=[]
var previous_usec := 0
var _original_data: Dictionary
var _original_values := ""
var _original_status: Dictionary
var _original_notice: Dictionary
var _original_last_save: Dictionary
var _original_persistence := false
var _original_blocked := false
var _original_version := 0
var _original_mode: GameBoot.LaunchMode
var _original_settings: Dictionary
var _original_environment: Dictionary

func _ready() -> void:
	profile_refresh=OS.get_environment("WEATHER_PREVIEW_PROFILE")=="1"
	_original_data=RealityState.data
	_original_values=JSON.stringify(_original_data,"",true,true)
	_original_status=RealityState.load_status();_original_notice=RealityState.player_notice()
	_original_last_save=RealityState.last_save_result()
	_original_persistence=RealityState.persistence_enabled
	_original_blocked=RealityState.save_write_blocked;_original_version=RealityState.incompatible_save_version
	_original_mode=GameBoot.launch_mode;_original_settings=GameBoot.settings.duplicate(true)
	for key: String in PREVIEW_ENV:
		_original_environment[key]={"exists":OS.has_environment(key),"value":OS.get_environment(key)}
	super._ready()

func _process(delta: float) -> void:
	var before_usec:=Time.get_ticks_usec()
	super._process(delta)
	if ready_for_input and previous_usec>0:
		frame_samples.append([status,(before_usec-previous_usec)/1000.0,(Time.get_ticks_usec()-before_usec)/1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
			RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
	previous_usec=before_usec

func check(ok: bool,message: String) -> void:
	checks.append({"name":message,"passed":ok})
	print("[ROOF PREVIEW %s] %s"%["PASS" if ok else "FAIL",message])
	if not ok:push_error(message)

func _preview_ready() -> void: _exercise.call_deferred()

func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func hold(code: Key,seconds: float) -> void:
	await key(code,true)
	await get_tree().create_timer(seconds).timeout
	await key(code,false)

func _exercise() -> void:
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	original_clock=RealityState.data.campaign_clock.duplicate(true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var original_authorities:=JSON.stringify(RealityState.data)
	check(manager.source=="campaign-calendar" and manager.extreme_weather!=null,"roof uses the installed Queens weather owner")
	check(manager.clock==preview_clock and director._campaign_clock==preview_clock and world.campaign_clock!=preview_clock,"sky and astronomy share detached clock; campaign clock stays separate")
	check(not RealityState.persistence_enabled,"preview disables disk writes before composing the world")
	check(pointer and not player.is_physics_processing() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"preview opens with a free pointer and stationary player")
	var held_date:=preview_clock.position_minutes
	var held_player:=player.global_transform
	await key(KEY_F8,true);await key(KEY_F8,false)
	check(is_instance_valid(world.shots.inspection_camera) and player.text_input_owner==world.shots,"F8 borrows inspection input in the detached roof preview")
	if is_instance_valid(world.shots.inspection_camera):
		var eye:=world.shots.inspection_camera.global_position
		await hold(KEY_W,.15)
		check(world.shots.inspection_camera.global_position.distance_to(eye)>.15,"inspection movement is actual input in the roof preview")
		check(preview_clock.position_minutes==held_date and player.global_transform.is_equal_approx(held_player),"flying leaves the preview date and parked operator unchanged")
		await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
		check(ready_for_input and not is_instance_valid(world.shots.inspection_camera) and pointer
				and not player.is_physics_processing() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Escape returns to the original roof pointer mode without closing it")
	var still_position:=player.global_position
	var still_time:=preview_clock.position_minutes
	await hold(KEY_W,.2)
	check(player.global_position==still_position and preview_clock.position_minutes==still_time,"pointer mode ignores movement keys without advancing time")
	await key(KEY_TAB,true);await key(KEY_TAB,false)
	check(not pointer and player.is_physics_processing() and not mouse_look and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Tab enables keyboard exploration without capturing the pointer")
	var facing:=player.rotation.y
	await hold(KEY_RIGHT,.2)
	check(absf(player.rotation.y-facing)>.1 and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"arrow keys turn the view without mouse capture")
	await hold(KEY_LEFT,.2)
	var c:=PreviewClock.new()
	check(c.seek(-1) and is_equal_approx(c.position_minutes,365*1440-1),"backward wrap reaches last minute of authored year")
	check(c.seek(365*1440+12) and is_equal_approx(c.position_minutes,12),"forward wrap reaches first day of authored year")
	check(c.seek(-365*1440*3.0+31) and is_equal_approx(c.position_minutes,31),"multiple reverse year crossings stay bounded")
	var before:=c.position_minutes
	check(not c.seek(NAN) and not c.seek(INF) and c.position_minutes==before,"non-finite seeks are refused without changing date")
	check(not c.configure_date(1930,1,1) and not c.advance_to(25),"preview refuses campaign mutation methods")
	check(scrub_rate(.5,true,false)==2880 and scrub_rate(-1,false,true)==-5,"analog direction and crouch fine-control rates are bounded")
	var all_dates:=true
	for day in 365:
		c.seek(float(day)*1440+720)
		all_dates=all_dates and not CampaignWeather.snapshot(c.local_datetime()).is_empty()
	check(all_dates,"all 365 preview dates resolve inside the authored calendar")
	await get_tree().physics_frame
	var ray:=PhysicsRayQueryParameters3D.create(player.camera.global_position,player.camera.global_position+Vector3.UP*12,1,[player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"preview starts beneath open sky rather than tank hardware")
	ray.to=player.camera.global_position-player.camera.global_basis.z*20
	check(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"initial view faces the open roof edge in the authored building frame")
	preview_clock.seek(120*1440+720);refresh_weather()
	before=preview_clock.position_minutes
	var origin:=player.global_position
	await hold(KEY_W,.4)
	check(preview_clock.position_minutes>before+60 and player.global_position.distance_to(origin)>.2,"engine-dispatched W walks on the real roof and advances weather")
	before=preview_clock.position_minutes
	await hold(KEY_S,.4)
	check(preview_clock.position_minutes<before-60,"engine-dispatched S reverses preview time")
	await key(KEY_SHIFT,true);before=preview_clock.position_minutes
	await hold(KEY_W,.3);await key(KEY_SHIFT,false)
	check(preview_clock.position_minutes>before+800,"engine-dispatched running accelerates time across days")
	await key(KEY_C,true);await key(KEY_C,false)
	before=preview_clock.position_minutes
	await hold(KEY_W,.4)
	check(player.crouched and preview_clock.position_minutes>before and preview_clock.position_minutes<before+6,"crouched movement allows fine minute-scale scrubbing")
	await key(KEY_P,true);await key(KEY_P,false);before=preview_clock.position_minutes
	await hold(KEY_W,.2)
	check(frozen and preview_clock.position_minutes==before,"engine-dispatched P holds weather while roof movement remains available")
	await key(KEY_TAB,true);await key(KEY_TAB,false)
	check(pointer and not player.is_physics_processing() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Tab stops walking for calendar sliders and leaves the pointer free")
	year_slider.value=364;hour_slider.value=1439
	check(int(preview_clock.position_minutes)==365*1440-1,"calendar sliders select the final authored minute")
	await key(KEY_PAGEUP,true);await key(KEY_PAGEUP,false)
	check(int(preview_clock.position_minutes)==1439,"next-day control wraps from final day to first day")
	await key(KEY_TAB,true);await key(KEY_TAB,false)
	check(not pointer and player.is_physics_processing() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Tab restores keyboard roof control without capturing the pointer")
	await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
	check(pointer and not player.is_physics_processing() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Escape always returns to pointer mode")
	await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
	check(pointer and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"repeated Escape cannot acquire capture")
	await key(KEY_TAB,true);await key(KEY_TAB,false)
	await key(KEY_C,true);await key(KEY_C,false)
	for sample: Array in [[0,720,"opening_day"],[44,1260,"christmas_snow"],[269,900,"summer_hail"],[120,1080,"spring_evening"]]:
		preview_clock.seek(float(sample[0])*1440+float(sample[1]));refresh_weather()
		for frame in 40:await RenderingServer.frame_post_draw
		var expected: Dictionary=manager.Service.presentation(CampaignWeather.snapshot(preview_clock.local_datetime()))
		check(int(manager.target.weather_code)==int(expected.weather_code),"roof renders date-owned conditions: "+str(sample[2]))
		var name:=str(sample[2])+".png"
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(name))==OK,"rendered roof capture: "+name)
		captures.append(name)
	if profile_refresh:await _profile_year()
	check(RealityState.data.campaign_clock==original_clock,"forward/reverse/year wrap never changes campaign date")
	await get_tree().create_timer(8.0).timeout
	# Record other transient runtime writes honestly; only the clock and disk
	# boundary are claimed here, not total authority neutrality of all actors.
	var observations_changed:=JSON.stringify(RealityState.data)!=original_authorities
	await retire_preview()
	check(is_same(RealityState.data,_original_data) and JSON.stringify(RealityState.data,"",true,true)==_original_values,"closing restores the original campaign reference and every value")
	check(RealityState.load_status()==_original_status and RealityState.player_notice()==_original_notice and RealityState.last_save_result()==_original_last_save,"closing restores load status, notices and last save result")
	check(RealityState.persistence_enabled==_original_persistence and RealityState.save_write_blocked==_original_blocked and RealityState.incompatible_save_version==_original_version,"closing restores persistence and protected-save latches")
	check(GameBoot.launch_mode==_original_mode and GameBoot.settings==_original_settings,"closing restores launch mode and original settings")
	var environment_restored:=true
	for name: String in _original_environment:
		var saved: Dictionary=_original_environment[name]
		environment_restored=environment_restored and OS.has_environment(name)==saved.exists and OS.get_environment(name)==saved.value
	check(environment_restored,"closing restores environment values and absent keys")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"pointer remains free after world retirement")
	var failures:=checks.filter(func(row: Dictionary):return not row.passed)
	FileAccess.open(directory.path_join("roof_preview_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"actual roof, engine-dispatched keyboard forward/reverse/run/pause/pointer input, calendar wrapping, rendered weather and original campaign restoration; no OS-native input, explicit mouse-look capture, campaign save reconstruction or full V2 acceptance","checks":checks,"failures":failures,"captures":captures,"other_runtime_data_changed":observations_changed,"frame_columns":["state","wall_ms","preview_update_ms","render_cpu_ms","render_gpu_ms"],"frames":frame_samples,"refresh_samples":refresh_samples,"profile_notes":"Optional fixed 365-noon forward/reverse route. CPU wall phases exclude pipeline-counter reads and sample append; counters may reflect prior renderer work. Frame data includes startup, input, PNG capture and instrumentation; not a matched whole-game performance claim."},"\t"))
	print("ROOF WEATHER PREVIEW TEST: %d checks, %d failures"%[checks.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _profile_year() -> void:
	set_exploration(false)
	var dates_match:=true
	for route: String in ["annual_forward","annual_reverse"]:
		profile_tag=route
		for index in 365:
			var day:=index if route=="annual_forward" else 364-index
			preview_clock.seek(float(day)*1440.0+720.0);refresh_weather()
			var expected: Dictionary=manager.Service.presentation(CampaignWeather.snapshot(preview_clock.local_datetime()))
			dates_match=dates_match and int(manager.target.weather_code)==int(expected.weather_code)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
	profile_tag="interaction"
	check(dates_match,"all 365 rendered noon targets follow the calendar in both directions")
