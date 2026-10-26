extends "res://scripts/building/roof_weather_preview.gd"
## Occupied roof + native movement input. Isolated preview diagnostic, no
## save/reload acceptance or claim that the full weather brief is finished.
var checks: Array[Dictionary]=[]
var captures: Array[String]=[]
var directory := ""
var original_clock: Dictionary
var frame_samples: Array=[]
var previous_usec := 0

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
	check(preview_clock.position_minutes>before+60 and player.global_position.distance_to(origin)>.2,"native W walks on the real roof and advances weather")
	before=preview_clock.position_minutes
	await hold(KEY_S,.4)
	check(preview_clock.position_minutes<before-60,"native S reverses preview time")
	await key(KEY_SHIFT,true);before=preview_clock.position_minutes
	await hold(KEY_W,.3);await key(KEY_SHIFT,false)
	check(preview_clock.position_minutes>before+800,"native running accelerates time across days")
	await key(KEY_C,true);await key(KEY_C,false)
	before=preview_clock.position_minutes
	await hold(KEY_W,.4)
	check(player.crouched and preview_clock.position_minutes>before and preview_clock.position_minutes<before+6,"crouched movement allows fine minute-scale scrubbing")
	await key(KEY_P,true);await key(KEY_P,false);before=preview_clock.position_minutes
	await hold(KEY_W,.2)
	check(frozen and preview_clock.position_minutes==before,"native P holds weather while roof movement remains available")
	await key(KEY_TAB,true);await key(KEY_TAB,false)
	check(pointer and not player.is_physics_processing() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"native Tab releases pointer and stops walking for calendar sliders")
	year_slider.value=364;hour_slider.value=1439
	check(int(preview_clock.position_minutes)==365*1440-1,"calendar sliders select the final authored minute")
	await key(KEY_PAGEUP,true);await key(KEY_PAGEUP,false)
	check(int(preview_clock.position_minutes)==1439,"next-day control wraps from final day to first day")
	await key(KEY_TAB,true);await key(KEY_TAB,false)
	check(not pointer and player.is_physics_processing(),"native Tab restores roof control without entering a game interface")
	await key(KEY_C,true);await key(KEY_C,false)
	for sample: Array in [[0,720,"opening_day"],[44,1260,"christmas_snow"],[269,900,"summer_hail"],[120,1080,"spring_evening"]]:
		preview_clock.seek(float(sample[0])*1440+float(sample[1]));refresh_weather()
		for frame in 40:await RenderingServer.frame_post_draw
		var expected: Dictionary=manager.Service.presentation(CampaignWeather.snapshot(preview_clock.local_datetime()))
		check(int(manager.target.weather_code)==int(expected.weather_code),"roof renders date-owned conditions: "+str(sample[2]))
		var name:=str(sample[2])+".png"
		check(get_viewport().get_texture().get_image().save_png(directory.path_join(name))==OK,"rendered roof capture: "+name)
		captures.append(name)
	check(RealityState.data.campaign_clock==original_clock,"forward/reverse/year wrap never changes campaign date")
	await get_tree().create_timer(8.0).timeout
	# Record other transient runtime writes honestly; only the clock and disk
	# boundary are claimed here, not total authority neutrality of all actors.
	var observations_changed:=JSON.stringify(RealityState.data)!=original_authorities
	var failures:=checks.filter(func(row: Dictionary):return not row.passed)
	FileAccess.open(directory.path_join("roof_preview_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"actual roof, native forward/reverse/run/pause/pointer input, calendar wrapping and rendered weather; no campaign save reconstruction or full V2 acceptance","checks":checks,"failures":failures,"captures":captures,"other_runtime_data_changed":observations_changed,"frame_columns":["state","wall_ms","preview_update_ms","render_cpu_ms","render_gpu_ms"],"frames":frame_samples},"\t"))
	print("ROOF WEATHER PREVIEW TEST: %d checks, %d failures"%[checks.size(),failures.size()])
	ready_for_input=false
	world.shutdown_for_tests();world.queue_free();await get_tree().process_frame;await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
