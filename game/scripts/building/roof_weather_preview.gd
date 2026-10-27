extends Node
## Isolated inspection scene. Never install this clock in the campaign runtime.
## Real roof/collision/weather composition; no campaign-time travel or save writes.
class PreviewClock extends CampaignClock:
	const YEAR_MINUTES := 365.0*1440.0
	var position_minutes := 12.0*60.0
	var epoch_minutes: float
	func _init() -> void: epoch_minutes=float(CampaignClock._ordinal(1928,11,10))*1440.0
	func bind_state() -> bool: return true
	func absolute_minutes() -> float: return epoch_minutes+position_minutes
	func elapsed_minutes() -> float: return position_minutes
	func minute_of_day() -> float: return fposmod(position_minutes,1440.0)
	func local_datetime() -> Dictionary: return CampaignClock._datetime_from_minutes(absolute_minutes())
	func utc_datetime() -> Dictionary: return CampaignClock._datetime_from_minutes(absolute_minutes()+300.0)
	func seek(value: float) -> bool:
		if not is_finite(value): return false
		position_minutes=fposmod(value,YEAR_MINUTES)
		return true
	func advance_seconds(_seconds: float) -> void: pass
	func advance_to(_minute: float) -> bool: return false
	func configure_date(_year: int,_month: int,_day: int,_minute := 0) -> bool: return false

const Selector := preload("res://scripts/building/building_root_selector.gd")
const ROOF_STANCE := Vector3(3.0,19.25,-9.0)
const PREVIEW_ENV := ["WEATHER_SIMULATE","WEATHER_FORMATION","WEATHER_PHENOMENON","WEATHER_SKY_BASELINE","DAYNIGHT_FORCE","CAMPAIGN_TIME_FREEZE","DAYNIGHT"]
signal preview_retired
var world: OrisonV2RuntimeRoot
var player: PlayerController
var preview_clock := PreviewClock.new()
var manager: Node
var director: DayNightDirector
var ready_for_input := false
var frozen := false
var pointer := true
var mouse_look := false
var tick_left := 0.0
var label: Label
var year_slider: HSlider
var hour_slider: HSlider
var overlay: CanvasLayer
var status := "STILL"
var loading: CanvasLayer
var _published_position := INF
var _saved_environment: Dictionary={}
var _saved_launch_mode: GameBoot.LaunchMode
var _saved_network: Variant
var _had_network := false
var _owns_context := false
var _owns_capture := false
var _closing := false
var _retiring := false
var _retired := false
## Opt-in diagnostic timings; ordinary inspection does not collect samples.
var profile_refresh := false
var profile_tag := "interaction"
var refresh_samples: Array[Dictionary]=[]

func _ready() -> void:
	loading=CanvasLayer.new();loading.layer=100;add_child(loading)
	var message:=Label.new();message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;message.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	message.text="Preparing the rooftop weather preview…\nBuilding the occupied V2 world can take a couple of minutes.\nYour campaign will not be saved. Esc cancels."
	loading.add_child(message)
	_build.call_deferred()

func _build() -> void:
	if _closing:return
	_saved_launch_mode=GameBoot.launch_mode
	_had_network=GameBoot.settings.has("weather_network_enabled")
	_saved_network=GameBoot.settings.get("weather_network_enabled")
	for key: String in PREVIEW_ENV:
		_saved_environment[key]={"exists":OS.has_environment(key),"value":OS.get_environment(key)}
	_owns_context=RealityState.begin_preview_campaign(self)
	if not _owns_context:
		push_error("Roof weather preview: campaign context is already owned")
		get_tree().quit(1);return
	# A standalone inspector starts a detached fresh world. A user's obsolete
	# or incompatible household save must neither block it nor be repaired here.
	CampaignClock.new().configure_date(1928,11,10,720)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	GameBoot.settings.weather_network_enabled=false
	for key: String in ["WEATHER_SIMULATE","WEATHER_FORMATION","WEATHER_PHENOMENON","WEATHER_SKY_BASELINE","DAYNIGHT_FORCE"]: OS.set_environment(key,"")
	OS.set_environment("CAMPAIGN_TIME_FREEZE","1")
	OS.set_environment("DAYNIGHT","1")
	world=load(Selector.scene_path()).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms<=0.0: await get_tree().process_frame
	if _closing:return
	if world.startup_failed: push_error("Roof weather preview: V2 startup refused");close_preview(1);return
	world.resident_agenda.set_process(false)
	player=world.player
	player.set_process(false);player.set_process_input(false);player.set_process_unhandled_input(false)
	player.global_position=world.adapter.root.to_global(ROOF_STANCE)
	player.velocity=Vector3.ZERO;player.set_lamp_enabled(false)
	player.global_basis=world.adapter.root.global_basis.orthonormalized()
	player.rotate_y(.1);player.camera.rotation=Vector3(.34,0,0);player.camera.fov=78.0;player.camera.make_current()
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	world.service_set_carrier.set_capture_hidden(true)
	world.service_set_carrier.process_mode=Node.PROCESS_MODE_DISABLED
	manager=world.get_node("WakingAtmosphere").weather_manager
	manager.set_process(false);manager.clock=preview_clock
	manager.source="campaign-calendar"
	manager.forced_phenomena.clear();manager._extreme_events.clear()
	director=world.day_night_director
	director.set_process(false);director._campaign_clock=preview_clock
	_build_overlay()
	loading.queue_free()
	set_exploration(false)
	ready_for_input=true
	refresh_weather()
	_preview_ready()

func _preview_ready() -> void: pass

static func scrub_rate(forward: float,running: bool,crouching: bool) -> float:
	return clampf(forward,-1,1)*(5.0 if crouching else (5760.0 if running else 360.0))

func refresh_weather() -> void:
	if preview_clock.position_minutes==_published_position:
		update_label()
		return
	_published_position=preview_clock.position_minutes
	var started:=Time.get_ticks_usec() if profile_refresh else 0
	manager._calendar_check_left=0.0;manager._phenomena_left=0.0;manager._publish_left=0.0
	manager._process(.1)
	var weather_done:=Time.get_ticks_usec() if profile_refresh else 0
	if manager.extreme_weather!=null:
		manager.extreme_weather.publish(manager.sky,player.camera.global_position,manager.effects.air_material)
	var extreme_done:=Time.get_ticks_usec() if profile_refresh else 0
	manager._push_spectacle()
	var spectacle_done:=Time.get_ticks_usec() if profile_refresh else 0
	director._apply(preview_clock.minute_of_day())
	var astronomy_done:=Time.get_ticks_usec() if profile_refresh else 0
	update_label()
	if profile_refresh and refresh_samples.size()<4096:
		var finished:=Time.get_ticks_usec()
		refresh_samples.append({"tag":profile_tag,"position_minutes":_published_position,
			"manager_ms":(weather_done-started)/1000.0,"extreme_ms":(extreme_done-weather_done)/1000.0,
			"spectacle_ms":(spectacle_done-extreme_done)/1000.0,"astronomy_ms":(astronomy_done-spectacle_done)/1000.0,
			"label_ms":(finished-astronomy_done)/1000.0,"total_ms":(finished-started)/1000.0,
			"draw_compilations":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
			"surface_compilations":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE)})

func _process(delta: float) -> void:
	if not ready_for_input or not is_instance_valid(player):return
	var direction:=0.0 if pointer or frozen else Input.get_axis("move_back","move_forward")
	var rate:=scrub_rate(direction,Input.is_action_pressed("run"),player.crouched)
	if rate!=0.0:preview_clock.seek(preview_clock.position_minutes+rate*delta)
	status="PAUSED" if frozen else ("REVERSE" if rate<0 else ("FORWARD" if rate>0 else "STILL"))
	if not pointer:
		var look:=Input.get_vector("look_left","look_right","look_up","look_down")
		if Input.is_physical_key_pressed(KEY_LEFT):look.x-=1.0
		if Input.is_physical_key_pressed(KEY_RIGHT):look.x+=1.0
		if Input.is_physical_key_pressed(KEY_UP):look.y-=1.0
		if Input.is_physical_key_pressed(KEY_DOWN):look.y+=1.0
		look=look.limit_length(1.0)
		rotate_view(look*delta*2.0)
	# Native roof bodies protect the player. Recover to the real deck if they
	# jump a parapet or enter the stair opening; the preview has no downstairs.
	var local: Vector3=world.adapter.root.to_local(player.global_position)
	if local.y<18.95 or absf(local.x)>15.0 or absf(local.z)>10.5:
		player.global_position=world.adapter.root.to_global(ROOF_STANCE);player.velocity=Vector3.ZERO
	tick_left-=delta
	if tick_left<=0.0:
		tick_left=.1
		refresh_weather()

func rotate_view(motion: Vector2) -> void:
	player.rotate_y(-motion.x)
	player.camera.rotation.x=clampf(player.camera.rotation.x-motion.y,deg_to_rad(-75),deg_to_rad(85))

## Keyboard/controller exploration does not need Windows pointer confinement.
## Only the explicit mouse-look button acquires it; Tab never does.
func set_exploration(enabled: bool,capture_mouse := false) -> void:
	pointer=not enabled;mouse_look=enabled and capture_mouse
	if _owns_capture and not mouse_look:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		_owns_capture=false
	if mouse_look:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;_owns_capture=true
	if is_instance_valid(player):
		player.set_physics_process(enabled)
		if not enabled:player.velocity=Vector3.ZERO
	if enabled:get_viewport().gui_release_focus()

func _input(event: InputEvent) -> void:
	if not ready_for_input:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:close_preview()
		return
	if event is InputEventMouseMotion and mouse_look and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		rotate_view(event.relative*.002);get_viewport().set_input_as_handled()
	if not pointer and event.is_action_pressed("crouch") and not event.is_echo():player._set_crouched(not player.crouched)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:set_exploration(pointer);get_viewport().set_input_as_handled()
			KEY_ESCAPE:set_exploration(false);get_viewport().set_input_as_handled()
			KEY_P:frozen=not frozen
			KEY_H:overlay.visible=not overlay.visible
			KEY_PAGEUP:preview_clock.seek(preview_clock.position_minutes+1440.0);refresh_weather()
			KEY_PAGEDOWN:preview_clock.seek(preview_clock.position_minutes-1440.0);refresh_weather()
		if event.physical_keycode in [KEY_P,KEY_H,KEY_PAGEUP,KEY_PAGEDOWN]:get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and ready_for_input:set_exploration(false)

func _build_overlay() -> void:
	overlay=CanvasLayer.new();add_child(overlay)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);margin.offset_top=-204;overlay.add_child(margin)
	for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,14)
	var panel:=PanelContainer.new();margin.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	label=Label.new();box.add_child(label)
	year_slider=HSlider.new();year_slider.min_value=0;year_slider.max_value=364;year_slider.step=1;box.add_child(year_slider)
	hour_slider=HSlider.new();hour_slider.min_value=0;hour_slider.max_value=1439;hour_slider.step=1;box.add_child(hour_slider)
	year_slider.value_changed.connect(func(day: float):preview_clock.seek(day*1440+preview_clock.minute_of_day());refresh_weather())
	hour_slider.value_changed.connect(func(minute: float):preview_clock.seek(floor(preview_clock.position_minutes/1440)*1440+minute);refresh_weather())
	var actions:=HBoxContainer.new();box.add_child(actions)
	var keys:=Button.new();keys.text="Explore with keys / controller";actions.add_child(keys);keys.pressed.connect(func():set_exploration(true))
	var mouse:=Button.new();mouse.text="Look with mouse";actions.add_child(mouse);mouse.pressed.connect(func():set_exploration(true,true))
	var quit:=Button.new();quit.text="Close preview";actions.add_child(quit);quit.pressed.connect(close_preview)

func update_label() -> void:
	year_slider.set_value_no_signal(floor(preview_clock.position_minutes/1440))
	hour_slider.set_value_no_signal(preview_clock.minute_of_day())
	label.text="ROOF WEATHER PREVIEW · %s · day %d/365 · %s\n%s · %s\nW/S time ±6h/s · Shift ±4d/s · crouch ±5min/s · arrows / right stick look\nP hold time · Tab keys/cursor · Esc cursor · PgUp/PgDn day · H hide"%[preview_clock.datetime_string(),int(preview_clock.position_minutes/1440)+1,status,str(manager.atmosphere_state.get("regime","")),str(manager.atmosphere_state.get("scenario_label",""))]

func close_preview(exit_code := 0) -> void:
	await retire_preview()
	get_tree().quit(exit_code)

func retire_preview() -> void:
	_closing=true;ready_for_input=false
	set_exploration(false)
	if _retired:return
	if _retiring:
		await preview_retired;return
	_retiring=true
	# A cancellation must not dismantle an owner halfway through construction.
	while is_instance_valid(world) and not world.startup_failed and world.startup_ms<=0.0:
		await get_tree().process_frame
	if is_instance_valid(world):world.shutdown_for_tests();world.free();world=null
	await get_tree().physics_frame;await get_tree().physics_frame
	_restore_context()
	_retired=true
	preview_retired.emit()

func _restore_context() -> void:
	if not _owns_context:return
	GameBoot.launch_mode=_saved_launch_mode
	if _had_network:GameBoot.settings.weather_network_enabled=_saved_network
	else:GameBoot.settings.erase("weather_network_enabled")
	for key: String in _saved_environment:
		if _saved_environment[key].exists:OS.set_environment(key,str(_saved_environment[key].value))
		else:OS.unset_environment(key)
	RealityState.end_preview_campaign(self)
	_owns_context=false

func _exit_tree() -> void:
	ready_for_input=false
	# Children exit first. Normal close uses retire_preview's settlement barrier;
	# this fallback still restores ownership when a host removes the whole scene.
	if _owns_capture and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_owns_capture=false
	_restore_context()
