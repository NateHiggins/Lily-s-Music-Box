extends Control
## Scene controller for the Audio Virus prototype. Builds the set and UI in
## code (flat-color placeholders — audio is the priority), owns the staged
## call sequence, and translates GameState signals into sound and light.
##
## Restart safety: every async sequence captures run_id and re-checks it
## after each await, so restarting mid-audio simply orphans old coroutines.

const MOTIF := preload("res://resources/motifs/incomplete_knock.tres")
const P_BREATHING := preload("res://resources/profiles/caller_breathing.tres")
const P_RADIATOR := preload("res://resources/profiles/radiator.tres")
const P_NOTIF := preload("res://resources/profiles/computer_notification.tres")
const P_HUM := preload("res://resources/profiles/electrical_hum.tres")
const P_HUMMING := preload("res://resources/profiles/human_humming.tres")
const DISTORT_SHADER := preload("res://shaders/screen_distortion.gdshader")

const CALLER := "CALLER"
const SYSTEM := "SYSTEM"
const SILENCE_WINDOW := 16.0  # seconds of no response before silence resolves

var run_id := 0
var _fast_skip := false
var _rng := RandomNumberGenerator.new()

# Renderers (bodies)
var breath_r: MotifRenderer
var loop_r: MotifRenderer       # the captured loop played through the interface
var radiator_r: MotifRenderer
var notif_r: MotifRenderer
var hum_r: MotifRenderer
var humming_r: MotifRenderer    # the player's own voice, used for responses

# Ambient players
var _murmur: AudioStreamPlayer
var _static: AudioStreamPlayer
var _room_tone: AudioStreamPlayer
var _behind_knock: AudioStreamPlayer

# Environment
var lamp: DeskLamp
var radiator: RadiatorProp
var door: DoorOutline
var _distort_rect: ColorRect
var _flash_rect: ColorRect

# UI
var waveform: WaveformView
var _header: Label
var _case_label: Label
var _caller_dot: ColorRect
var _notif_light: ColorRect
var _subtitle: Label
var _hint: Label
var _integrity_fill: ColorRect
var _isolate_btn: Button
var _capture_btn: Button
var _route_btns: Dictionary = {}
var _respond_box: HBoxContainer
var _corporate: ColorRect
var _corporate_status: Label
var _monitor: PanelContainer
var _monitor_rest := Vector2.ZERO

# Sequence flags
var _transmission_started := false
var _headset_warned := false
var _isolated_events := 0
var _silence_countdown := -1.0
var _fade_started := false
var _header_base := "NIGHTLINE REMOTE SUPPORT — SHIFT 03:12"
var _glitch_cooldown := 0.0
var _user_muted := false


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_monitor_ui()
	_build_overlays()
	_build_audio()
	_build_debug()
	_connect_state()
	start_run()


# ---------------------------------------------------------------- build

func _build_environment() -> void:
	_add_rect(Rect2(0, 0, 1280, 720), Color(0.024, 0.028, 0.038))          # night
	_add_rect(Rect2(0, 0, 1280, 560), Color(0.04, 0.045, 0.06))            # wall
	_add_rect(Rect2(0, 560, 1280, 160), Color(0.055, 0.042, 0.05))         # floor
	_add_rect(Rect2(80, 552, 800, 14), Color(0.09, 0.07, 0.08))            # desk edge
	# window with distant city light
	_add_rect(Rect2(1160, 100, 104, 240), Color(0.07, 0.06, 0.14))
	_add_rect(Rect2(1206, 100, 6, 240), Color(0.03, 0.03, 0.05))
	for i in 8:
		_add_rect(Rect2(1170 + (i % 4) * 22, 150 + (i / 4) * 90, 6, 8), Color(0.45, 0.3, 0.6, 0.5))

	door = DoorOutline.new()
	door.position = Vector2(950, 470)
	add_child(door)

	radiator = RadiatorProp.new()
	radiator.position = Vector2(1080, 500)
	add_child(radiator)

	lamp = DeskLamp.new()
	lamp.position = Vector2(78, 528)
	add_child(lamp)

	# headset on the desk, purely set dressing
	_add_rect(Rect2(830, 528, 34, 20), Color(0.12, 0.12, 0.14))
	_add_rect(Rect2(834, 512, 6, 18), Color(0.12, 0.12, 0.14))


func _add_rect(rect: Rect2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _build_monitor_ui() -> void:
	_monitor = PanelContainer.new()
	_monitor.position = Vector2(150, 88)
	_monitor.size = Vector2(660, 466)
	_monitor_rest = _monitor.position
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.065, 0.08)
	style.border_color = Color(0.13, 0.16, 0.2)
	style.set_border_width_all(6)
	style.set_corner_radius_all(4)
	_monitor.add_theme_stylebox_override("panel", style)
	add_child(_monitor)

	var screen := Control.new()
	screen.custom_minimum_size = Vector2(632, 438)
	_monitor.add_child(screen)

	_header = _mk_label(screen, _header_base, Vector2(10, 4), 13, Color(0.5, 0.85, 0.8))
	_case_label = _mk_label(screen, "CASE #4471 · L. VOSS · \"SMART SPEAKER RESPONDS BEFORE I ASK\"",
			Vector2(10, 24), 11, Color(0.55, 0.6, 0.68))
	_mk_label(screen, "LINE", Vector2(560, 4), 10, Color(0.45, 0.5, 0.55))
	_caller_dot = ColorRect.new()
	_caller_dot.position = Vector2(596, 7)
	_caller_dot.size = Vector2(10, 10)
	_caller_dot.color = Color(0.3, 0.8, 0.4)
	screen.add_child(_caller_dot)
	_notif_light = ColorRect.new()
	_notif_light.position = Vector2(616, 7)
	_notif_light.size = Vector2(10, 10)
	_notif_light.color = Color(0.2, 0.24, 0.3)
	screen.add_child(_notif_light)

	waveform = WaveformView.new()
	waveform.position = Vector2(10, 48)
	waveform.size = Vector2(612, 112)
	screen.add_child(waveform)

	var tools := HBoxContainer.new()
	tools.position = Vector2(10, 172)
	tools.add_theme_constant_override("separation", 10)
	screen.add_child(tools)
	_isolate_btn = Button.new()
	_isolate_btn.text = "ISOLATE NOISE"
	_isolate_btn.toggle_mode = true
	_isolate_btn.disabled = true
	_isolate_btn.toggled.connect(_on_isolate_toggled)
	tools.add_child(_isolate_btn)
	_capture_btn = Button.new()
	_capture_btn.text = "CAPTURE LOOP"
	_capture_btn.disabled = true
	_capture_btn.pressed.connect(_on_capture_pressed)
	tools.add_child(_capture_btn)

	var routes := HBoxContainer.new()
	routes.position = Vector2(10, 214)
	routes.add_theme_constant_override("separation", 8)
	screen.add_child(routes)
	var route_label := Label.new()
	route_label.text = "ROUTE →"
	route_label.add_theme_font_size_override("font_size", 12)
	routes.add_child(route_label)
	for route in [GameState.ROUTE_SPEAKERS, GameState.ROUTE_HEADSET, GameState.ROUTE_ROOM]:
		var b := Button.new()
		b.text = {"speakers": "COMPUTER SPEAKERS", "headset": "HEADSET RETURN", "room": "ROOM OUTPUT"}[route]
		b.toggle_mode = true
		b.disabled = true
		b.add_theme_font_size_override("font_size", 11)
		b.toggled.connect(_on_route_toggled.bind(route))
		routes.add_child(b)
		_route_btns[route] = b

	_respond_box = HBoxContainer.new()
	_respond_box.position = Vector2(10, 254)
	_respond_box.add_theme_constant_override("separation", 10)
	_respond_box.visible = false
	screen.add_child(_respond_box)
	var wait_label := Label.new()
	wait_label.text = "THE PATTERN WAITS —"
	wait_label.add_theme_font_size_override("font_size", 12)
	wait_label.modulate = Color(0.95, 0.65, 0.35)
	_respond_box.add_child(wait_label)
	var complete_btn := Button.new()
	complete_btn.text = "COMPLETE IT"
	complete_btn.pressed.connect(func(): _do_outcome(GameState.Response.COMPLETE))
	_respond_box.add_child(complete_btn)
	var interrupt_btn := Button.new()
	interrupt_btn.text = "INTERRUPT"
	interrupt_btn.pressed.connect(func(): _do_outcome(GameState.Response.INTERRUPT))
	_respond_box.add_child(interrupt_btn)
	var silent_label := Label.new()
	silent_label.text = "(or say nothing)"
	silent_label.add_theme_font_size_override("font_size", 11)
	silent_label.modulate = Color(0.5, 0.55, 0.6)
	_respond_box.add_child(silent_label)

	_hint = _mk_label(screen, "", Vector2(10, 296), 12, Color(0.75, 0.8, 0.85))
	_hint.size = Vector2(612, 28)
	_subtitle = _mk_label(screen, "", Vector2(10, 330), 13, Color(0.85, 0.87, 0.9))
	_subtitle.size = Vector2(612, 66)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_mk_label(screen, "SIGNAL INTEGRITY", Vector2(10, 408), 10, Color(0.45, 0.5, 0.55))
	_add_child_rect(screen, Rect2(130, 412, 300, 8), Color(0.1, 0.12, 0.15))
	_integrity_fill = _add_child_rect(screen, Rect2(130, 412, 300, 8), Color(0.34, 0.9, 0.83))


func _mk_label(parent: Control, text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.modulate = color
	parent.add_child(l)
	return l


func _add_child_rect(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _build_overlays() -> void:
	var distort_layer := CanvasLayer.new()
	distort_layer.layer = 5
	add_child(distort_layer)
	_distort_rect = ColorRect.new()
	_distort_rect.size = Vector2(1280, 720)
	_distort_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = DISTORT_SHADER
	mat.set_shader_parameter("intensity", 0.0)
	_distort_rect.material = mat
	distort_layer.add_child(_distort_rect)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 6
	add_child(flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.size = Vector2(1280, 720)
	_flash_rect.color = Color(0, 0, 0, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_flash_rect)

	var corp_layer := CanvasLayer.new()
	corp_layer.layer = 8
	add_child(corp_layer)
	_corporate = ColorRect.new()
	_corporate.size = Vector2(1280, 720)
	_corporate.color = Color(0.01, 0.015, 0.02, 0.92)
	_corporate.visible = false
	corp_layer.add_child(_corporate)
	var vb := VBoxContainer.new()
	vb.position = Vector2(440, 240)
	vb.custom_minimum_size = Vector2(400, 0)
	vb.add_theme_constant_override("separation", 14)
	_corporate.add_child(vb)
	for entry in [["CASE #4471", 14, Color(0.45, 0.5, 0.55)],
			["CUSTOMER EDUCATED", 34, Color(0.5, 0.85, 0.8)],
			["ISSUE RESOLVED", 34, Color(0.5, 0.85, 0.8)]]:
		var l := Label.new()
		l.text = entry[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", entry[1])
		l.modulate = entry[2]
		vb.add_child(l)
	_corporate_status = Label.new()
	_corporate_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corporate_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corporate_status.add_theme_font_size_override("font_size", 12)
	_corporate_status.modulate = Color(0.4, 0.45, 0.5)
	vb.add_child(_corporate_status)
	var restart := Button.new()
	restart.text = "START NEXT SHIFT"
	restart.pressed.connect(start_run)
	vb.add_child(restart)


func _build_audio() -> void:
	_murmur = _mk_player("murmur_loop", AudioEnv.BUS_CALLER, -38.0)
	_static = _mk_player("phone_static_loop", AudioEnv.BUS_CALLER, -30.0)
	_room_tone = _mk_player("room_tone_loop", AudioEnv.BUS_ROOM, -26.0)
	_behind_knock = AudioStreamPlayer.new()
	_behind_knock.stream = AudioFactory.get_stream("knock")
	_behind_knock.bus = AudioEnv.BUS_ROOM
	_behind_knock.pitch_scale = 0.55
	_behind_knock.volume_db = -2.0
	add_child(_behind_knock)

	breath_r = _mk_renderer(P_BREATHING)
	radiator_r = _mk_renderer(P_RADIATOR)
	notif_r = _mk_renderer(P_NOTIF)
	hum_r = _mk_renderer(P_HUM)
	humming_r = _mk_renderer(P_HUMMING)
	# The captured loop is its own body: machine playback of a noisy capture.
	var loop_profile := P_BREATHING.duplicate() as TranslationProfile
	loop_profile.id = "captured_loop"
	loop_profile.timbre = "click"
	loop_profile.timing_drift = 0.0
	loop_profile.accent_accuracy = 0.9
	loop_profile.event_reliability = 1.0
	loop_profile.base_volume_db = -12.0
	loop_profile.bus = AudioEnv.BUS_UI
	loop_r = _mk_renderer(loop_profile)

	breath_r.event_played.connect(_on_breath_event)
	loop_r.event_played.connect(_on_loop_event)
	radiator_r.event_played.connect(_on_radiator_event)
	notif_r.event_played.connect(_on_notif_event)
	hum_r.event_played.connect(func(_i, a, _p): lamp.pulse(a * 0.15))


func _mk_player(timbre: String, bus: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = AudioFactory.get_stream(timbre)
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	return p


func _mk_renderer(profile: TranslationProfile) -> MotifRenderer:
	var r := MotifRenderer.new()
	r.profile = profile
	r.motif = MOTIF
	r.name = "Renderer_%s" % profile.id
	add_child(r)
	return r


func _build_debug() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := DebugPanel.new()
	panel.position = Vector2(1280 - 322, 8)
	layer.add_child(panel)
	panel.renderer_status_provider = _renderer_status
	panel.replay_source.connect(_debug_replay)
	panel.restart_requested.connect(start_run)
	panel.skip_to_stage.connect(_skip_to_stage)
	panel.markers_toggled.connect(_on_markers_toggled)
	panel.tempo_changed.connect(_on_debug_tempo)
	panel.drift_changed.connect(_on_debug_drift)
	panel.infection_changed.connect(GameState.set_room_infection)
	panel.master_volume_changed.connect(AudioEnv.set_master_volume_db)
	panel.mute_toggled.connect(_on_debug_mute)


func _on_markers_toggled(enabled: bool) -> void:
	waveform.show_markers = enabled


func _on_debug_tempo(value: float) -> void:
	for r in _renderers():
		r.tempo_scale = value


func _on_debug_drift(value: float) -> void:
	for r in _renderers():
		r.drift_multiplier = value


func _on_debug_mute(muted: bool) -> void:
	_user_muted = muted
	AudioEnv.set_master_mute(muted)


func _connect_state() -> void:
	GameState.infection_changed.connect(_on_infection_changed)


# ---------------------------------------------------------------- run control

func start_run() -> void:
	run_id += 1
	_fast_skip = false
	_transmission_started = false
	_headset_warned = false
	_isolated_events = 0
	_silence_countdown = -1.0
	_fade_started = false
	for r in _renderers():
		r.stop()
		r.include_missing_events = false
		r.tempo_scale = 1.0
		r.drift_multiplier = 1.0
		r.volume_offset_db = 0.0
		r.set_motif(MOTIF)
	GameState.reset()
	door.reset()
	lamp.set_base(0.55)
	waveform.set_motif(MOTIF)
	waveform.set_mode(WaveformView.Mode.IDLE)
	waveform.ghost_emphasis = 0.0
	_respond_box.visible = false
	_corporate.visible = false
	_subtitle.text = ""
	_hint.text = ""
	_header.text = _header_base
	_isolate_btn.set_pressed_no_signal(false)
	_isolate_btn.disabled = true
	_capture_btn.disabled = true
	for b in _route_btns.values():
		b.set_pressed_no_signal(false)
		b.disabled = true
		b.modulate = Color.WHITE
	_murmur.volume_db = -38.0
	if not _murmur.playing:
		_murmur.play()
	if not _static.playing:
		_static.play()
	if not _room_tone.playing:
		_room_tone.play()
	# The pattern is present from the first second — just buried.
	breath_r.infection_intensity = 0.15
	breath_r.volume_offset_db = -8.0
	breath_r.play(true)
	_seq_ordinary_call(run_id)


func _renderers() -> Array:
	var out: Array = []
	for r in [breath_r, loop_r, radiator_r, notif_r, hum_r, humming_r]:
		if r:
			out.append(r)
	return out


## Awaits (scaled when fast-skipping); returns false if the run restarted.
func _delay(sec: float, rid: int) -> bool:
	await get_tree().create_timer(sec * (0.12 if _fast_skip else 1.0), false).timeout
	return rid == run_id and is_inside_tree()


func _say(speaker: String, text: String, rid: int, whisper := false) -> bool:
	_subtitle.text = "[%s]  %s" % [speaker, text]
	if speaker == CALLER:
		_tween_volume(_murmur, -22.0 if whisper else -14.0, 0.3)
	var dur := clampf(1.6 + 0.045 * text.length(), 2.0, 6.5)
	var ok: bool = await _delay(dur, rid)
	if ok and speaker == CALLER:
		_tween_volume(_murmur, -38.0, 0.5)
	return ok


func _tween_volume(player: AudioStreamPlayer, db: float, dur: float) -> void:
	create_tween().tween_property(player, "volume_db", db, dur)


# ---------------------------------------------------------------- stages

func _seq_ordinary_call(rid: int) -> void:
	if not await _delay(2.0, rid): return
	if not await _say(CALLER, "Thanks for staying on this late. It's the speaker — it answers before I finish asking. Like it already knows the question.", rid): return
	if not await _delay(1.0, rid): return
	if not await _say(CALLER, "There's a little clicking behind it, too. That's just the pipes. Ignore that.", rid): return
	if not await _delay(2.0, rid): return
	_hint.text = "ANALYSIS: periodic transient on background channel. [ISOLATE NOISE] to inspect."
	_isolate_btn.disabled = false


func _on_isolate_toggled(active: bool) -> void:
	GameState.set_isolated(active)
	if active:
		# Fake source separation: duck the voice bed, lift the breath layer.
		_tween_volume(_murmur, -46.0, 0.8)
		_tween_volume(_static, -36.0, 0.8)
		breath_r.infection_intensity = 0.6
		create_tween().tween_property(breath_r, "volume_offset_db", 4.0, 0.8)
		waveform.set_mode(WaveformView.Mode.LIVE)
		if GameState.call_stage == GameState.Stage.ORDINARY_CALL:
			GameState.set_stage(GameState.Stage.ISOLATION)
			_hint.text = "Background channel isolated. Listen."
	else:
		_tween_volume(_murmur, -38.0, 0.6)
		_tween_volume(_static, -30.0, 0.6)
		breath_r.infection_intensity = 0.15
		create_tween().tween_property(breath_r, "volume_offset_db", -8.0, 0.6)
		if not GameState.motif_captured:
			waveform.set_mode(WaveformView.Mode.IDLE)


func _on_breath_event(index: int, accent: float, _pitch: float) -> void:
	if GameState.is_noise_isolated:
		waveform.notify_event(index, accent)
		_isolated_events += 1
		# After hearing the figure twice, the interface can hold it.
		if _isolated_events >= 7 and _capture_btn.disabled \
				and GameState.call_stage == GameState.Stage.ISOLATION:
			_capture_btn.disabled = false
			_hint.text = "Pattern registered: 4 events, 1 expected. [CAPTURE LOOP] to hold it."


func _on_capture_pressed() -> void:
	if GameState.motif_captured:
		# Re-press = clean restart of the loop, never a second instance.
		loop_r.stop()
		loop_r.play(true)
		return
	GameState.set_captured(true)
	GameState.set_stage(GameState.Stage.CAPTURE)
	waveform.set_mode(WaveformView.Mode.CAPTURED)
	loop_r.infection_intensity = 0.7
	loop_r.play(true)
	for b in _route_btns.values():
		b.disabled = false
	_hint.text = "Loop held. Four marks — and an empty slot. Choose an output route."
	_seq_after_capture(run_id)


func _seq_after_capture(rid: int) -> void:
	if not await _delay(4.0, rid): return
	if GameState.call_stage == GameState.Stage.CAPTURE:
		await _say(CALLER, "Are you… playing something back? It sounds different on your side. Smaller.", rid)


func _on_loop_event(index: int, accent: float, _pitch: float) -> void:
	waveform.notify_event(index, accent)


func _on_route_toggled(on: bool, route: String) -> void:
	if on:
		_on_route_selected(route)
	elif route == GameState.current_route:
		# Routes are sticky: clicking the active route off keeps it active.
		_route_btns[route].set_pressed_no_signal(true)


func _on_route_selected(route: String) -> void:
	for r in _route_btns:
		_route_btns[r].modulate = Color(0.45, 1.0, 0.92) if r == route else Color.WHITE
		if r != route:
			_route_btns[r].set_pressed_no_signal(false)
	GameState.set_route(route)
	match route:
		GameState.ROUTE_SPEAKERS:
			AudioEnv.reroute_source_bus(loop_r.output_bus(), AudioEnv.BUS_ROOM)
			loop_r.volume_offset_db = 0.0
		GameState.ROUTE_ROOM:
			AudioEnv.reroute_source_bus(loop_r.output_bus(), AudioEnv.BUS_ROOM)
			loop_r.volume_offset_db = 4.0
		GameState.ROUTE_HEADSET:
			AudioEnv.reroute_source_bus(loop_r.output_bus(), AudioEnv.BUS_CALLER)
			loop_r.volume_offset_db = -2.0
	if not loop_r.playing and GameState.motif_captured:
		loop_r.play(true)
	if route == GameState.ROUTE_HEADSET:
		GameState.set_caller_infection(maxf(GameState.caller_infection_level, 0.35))
		if not _headset_warned:
			_headset_warned = true
			_seq_headset_reaction(run_id)
		_hint.text = "Return channel reaches only the caller. The room heard nothing."
	elif not _transmission_started:
		_transmission_started = true
		_seq_transmission(run_id)


func _seq_headset_reaction(rid: int) -> void:
	if not await _delay(2.5, rid): return
	await _say(CALLER, "Why are you sending it back into my ear? It liked that. Don't do that.", rid)


func _seq_transmission(rid: int) -> void:
	GameState.set_stage(GameState.Stage.TRANSMISSION)
	_hint.text = "Playback active. Room response pending…"
	if not await _delay(3.5, rid): return
	# The wall answers: a rougher body picks the idea up.
	GameState.radiator_infected = true
	radiator_r.infection_intensity = 0.55
	radiator_r.play(true)
	_ramp_room_infection(0.55, 9.0)
	if not await _delay(2.5, rid): return
	hum_r.infection_intensity = 0.4
	hum_r.play(true)
	if not await _delay(1.5, rid): return
	GameState.computer_infected = true
	notif_r.infection_intensity = GameState.room_infection_level
	notif_r.play(true)
	if not await _delay(2.0, rid): return
	if not await _say(CALLER, "Wait. I can hear knocking. Not here — through the phone. It's in YOUR room, isn't it?", rid): return
	if not await _delay(2.5, rid): return
	create_tween().tween_property(waveform, "ghost_emphasis", 1.0, 2.0)
	_seq_response(rid)


func _ramp_room_infection(target: float, dur: float) -> void:
	create_tween().tween_method(GameState.set_room_infection, GameState.room_infection_level, target, dur)


func _seq_response(rid: int) -> void:
	if rid != run_id: return
	GameState.set_stage(GameState.Stage.RESPONSE)
	_respond_box.visible = true
	_hint.text = "Every source stops at the same empty slot. It is waiting."
	_silence_countdown = SILENCE_WINDOW


func _on_radiator_event(index: int, accent: float, _pitch: float) -> void:
	radiator.knock(accent)
	lamp.pulse(accent * 0.7)  # the lamp flickers with the accent pattern
	if GameState.motif_captured:
		waveform.notify_event(index, accent)


func _on_notif_event(_index: int, accent: float, _pitch: float) -> void:
	_notif_light.color = Color(0.34, 0.9, 0.83)
	var tw := create_tween()
	tw.tween_interval(0.1 + accent * 0.1)
	tw.tween_callback(func(): _notif_light.color = Color(0.2, 0.24, 0.3))


# ---------------------------------------------------------------- outcomes

func _do_outcome(response: int) -> void:
	# Latch lives in GameState: repeated presses / duplicate triggers no-op.
	if GameState.call_stage != GameState.Stage.RESPONSE and not GameState.outcome_triggered:
		return  # response before the pattern is established does nothing
	if not GameState.try_commit_outcome(response):
		return
	_silence_countdown = -1.0
	_respond_box.visible = false
	match response:
		GameState.Response.COMPLETE:
			_seq_outcome_complete(run_id)
		GameState.Response.INTERRUPT:
			_seq_outcome_interrupt(run_id)
		GameState.Response.SILENCE:
			_seq_outcome_silence(run_id)


func _seq_outcome_complete(rid: int) -> void:
	_hint.text = "You answered."
	humming_r.include_missing_events = true
	humming_r.play_single_event(4)          # the player hums the missing fifth
	waveform.notify_event(4, 1.0)
	if not await _delay(1.1, rid): return
	radiator_r.include_missing_events = true  # from now on the loop resolves
	radiator_r.play_single_event(4)           # the radiator confirms it
	if not await _delay(0.7, rid): return
	# Brief brown-out: the room acknowledges receipt.
	lamp.power_flicker()
	hum_r.stop()
	_tween_volume(_room_tone, -60.0, 0.2)
	var flash := create_tween()
	flash.tween_property(_flash_rect, "color:a", 0.85, 0.1)
	flash.tween_interval(0.7)
	flash.tween_property(_flash_rect, "color:a", 0.0, 0.6)
	if not await _delay(1.4, rid): return
	_tween_volume(_room_tone, -26.0, 1.0)
	hum_r.infection_intensity = 0.7
	hum_r.play(true)
	GameState.set_room_infection(0.85)  # stable, but higher than before
	door.reveal()
	if not await _delay(1.6, rid): return
	if not await _say(CALLER, "oh. the door was always there. i can see your room now.", rid, true): return
	GameState.set_caller_infection(0.8)
	if not await _delay(4.0, rid): return
	_show_corporate(rid)


func _seq_outcome_interrupt(rid: int) -> void:
	_hint.text = "You spoke over it."
	humming_r.play_single_event(1)  # wrong event, wrong moment
	waveform.notify_event(1, 1.0)
	GameState.motif_mutation += 1
	var mutated := MOTIF.mutated(_rng)
	print("[STATE] motif mutated -> %s" % mutated.id)
	# The idea survives, damaged: bodies fall out of agreement.
	radiator_r.drift_multiplier = 5.0
	radiator_r.tempo_scale = 1.06
	radiator_r.set_motif(mutated)
	hum_r.set_motif(mutated)
	notif_r.tempo_scale = 0.93
	if not notif_r.playing:
		notif_r.infection_intensity = 0.8
		notif_r.play(true)
	GameState.set_room_infection(minf(GameState.room_infection_level + 0.15, 1.0))
	GameState.set_caller_infection(0.7)
	if not await _delay(2.5, rid): return
	if not await _say(CALLER, "There's another voice in my speaker now. It's answering for me.", rid): return
	if not await _delay(5.0, rid): return
	_show_corporate(rid)


func _seq_outcome_silence(rid: int) -> void:
	_hint.text = ""
	# Everything has already faded (see _process); hold the empty room.
	for r in _renderers():
		r.stop()
	if not await _delay(3.0, rid): return
	# She performs the figure herself, close to the mic…
	breath_r.volume_offset_db = 2.0
	breath_r.infection_intensity = 0.9
	breath_r.play(false)
	# …and the fifth beat arrives from behind the player, not the radiator.
	if not await _delay(MOTIF.event_times[4], rid): return
	_behind_knock.play()
	lamp.pulse(1.0)
	radiator.knock(0.3)
	waveform.notify_event(4, 1.0)
	var mat := _distort_rect.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v): mat.set_shader_parameter("intensity", v),
			GameState.room_infection_level * 0.5, 0.8, 0.15)
	tw.tween_method(func(v): mat.set_shader_parameter("intensity", v),
			0.8, GameState.room_infection_level * 0.5, 0.8)
	GameState.set_caller_infection(1.0)
	if not await _delay(1.6, rid): return
	if not await _say(CALLER, "you left it unfinished. hold still — i finished it for you.", rid, true): return
	if not await _delay(4.0, rid): return
	_show_corporate(rid)


func _show_corporate(rid: int) -> void:
	if rid != run_id: return
	_header.text = "NIGHTLINE REMOTE SUPPORT — CASE CLOSED"
	_corporate_status.text = "outcome logged: %s · anomaly: none found" \
			% GameState.RESPONSE_NAMES[GameState.player_response].to_lower()
	_corporate.visible = true
	_corporate.modulate.a = 0.0
	create_tween().tween_property(_corporate, "modulate:a", 1.0, 1.2)


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	if loop_r and loop_r.playing:
		waveform.set_playhead(loop_r.loop_position())
	else:
		waveform.set_playhead(-1.0)

	if _silence_countdown > 0.0:
		_silence_countdown -= delta
		# Last stretch: the world audibly loses interest before the cutoff.
		if _silence_countdown <= 6.0 and not _fade_started:
			_fade_started = true
			for r in [loop_r, radiator_r, notif_r, hum_r, breath_r]:
				r.fade_out(5.0)
		if _silence_countdown <= 0.0:
			_do_outcome(GameState.Response.SILENCE)

	_update_corruption(delta)


## UI corruption scales with room infection: header glitches, monitor jitter.
func _update_corruption(delta: float) -> void:
	var inf := GameState.room_infection_level
	_glitch_cooldown -= delta
	if inf > 0.2 and _glitch_cooldown <= 0.0 and _rng.randf() < inf * 0.1:
		_glitch_cooldown = 0.4
		var chars := _header_base.split("")
		for i in int(inf * 5.0):
			chars[_rng.randi_range(0, chars.size() - 1)] = char(_rng.randi_range(0x2591, 0x2593))
		_header.text = "".join(chars)
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_callback(_restore_header)
		_monitor.position = _monitor_rest + Vector2(_rng.randf_range(-1.5, 1.5) * inf * 2.0, 0)
	elif _monitor.position != _monitor_rest and _glitch_cooldown <= 0.0:
		_monitor.position = _monitor_rest


func _restore_header() -> void:
	if not GameState.outcome_triggered:
		_header.text = _header_base


func _on_infection_changed(room: float, caller: float) -> void:
	var mat := _distort_rect.material as ShaderMaterial
	mat.set_shader_parameter("intensity", room * 0.5)
	_integrity_fill.size.x = 300.0 * (1.0 - room * 0.9)
	_caller_dot.color = Color(0.3, 0.8, 0.4).lerp(Color(0.95, 0.3, 0.3), caller)
	notif_r.infection_intensity = maxf(notif_r.infection_intensity, room)


# ---------------------------------------------------------------- debug hooks

func _renderer_status() -> Array:
	var lines: Array = []
	lines.append("motif: %s" % (breath_r.motif.id if breath_r.motif else "none"))
	for r in _renderers():
		if r.playing:
			lines.append("▶ %s (inf %.2f)" % [r.profile.id, r.infection_intensity])
	if lines.size() == 1:
		lines.append("no active renderers")
	return lines


func _debug_replay(profile_id: String) -> void:
	for r in _renderers():
		if r.profile.id == profile_id:
			var was_looping: bool = r.looping
			r.stop()
			r.play(was_looping)
			return


func _skip_to_stage(stage: int) -> void:
	start_run()
	_fast_skip = true
	if stage >= GameState.Stage.ISOLATION:
		_isolate_btn.disabled = false
		_isolate_btn.button_pressed = true  # emits toggled -> full isolate path
	if stage >= GameState.Stage.CAPTURE:
		_capture_btn.disabled = false
		_on_capture_pressed()
	if stage >= GameState.Stage.TRANSMISSION:
		_route_btns[GameState.ROUTE_SPEAKERS].button_pressed = true
	# RESPONSE follows automatically from the (fast-forwarded) transmission.
	if stage < GameState.Stage.TRANSMISSION:
		_fast_skip = false


# ---------------------------------------------------------------- focus / device

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Freeze the sequence and go quiet rather than playing to an empty chair.
			get_tree().paused = true
			AudioEnv.set_master_mute(true)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			get_tree().paused = false
			AudioEnv.set_master_mute(_user_muted)
