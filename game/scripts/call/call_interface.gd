class_name CallInterface
extends CanvasLayer
## The overnight support desk in apartment 4B, and the runner for every case
## in the Case Network. The case itself is data (`case_library.gd`); this
## class knows only how to play one.
##
## The desk offers three verbs — split a signal apart, hold a piece of it,
## push that piece into the building — and a case is what those verbs mean
## tonight. That fixed shape is deliberate: by the third call the player is
## fluent in the console and is spending their attention on the person on the
## line instead of on the buttons.
##
## The caller's audio rides the SAME conductor clock the building follows, so
## routing a captured loop genuinely moves the conductor's origin and the
## outcomes genuinely change building state — Case 01's Complete pushes
## infection high enough to manifest the door anomaly in 4B's wall, and Case
## 02 leaves a utility door in the third-floor corridor whichever way it ends.
##
## Interact with the desk chair to enter; Esc steps away (the call and its
## consequences continue without you).

signal call_ended(outcome: String)
## A case left something behind in the world (`desk_double`, `rhea_detector`).
signal case_flag_set(flag: String)

enum Stage { IDLE, CALL, ISOLATION, CAPTURE, TRANSMISSION, RESPONSE, OUTCOME }

const SILENCE_WINDOW := 16.0

var stage: Stage = Stage.IDLE
var outcome := ""
var fast := false          # test hook: compress waits

## Which case is on the line, and what every closed case resolved to.
var case_index := 0
var closed_outcomes: Array[String] = []
var flags: Dictionary = {}
## Set by building_root so `reveal` beats can find the prop they change.
var world: Node = null

var _case: Dictionary = {}
var _player: Node = null
var _run_id := 0
var _started := false
var _closed := false
var _isolated := false
var _captured := false
var _routed := false
var _silence_left := -1.0
var _ticks_heard := 0

var _panel: PanelContainer
var _header: Label
var _subtitle: Label
var _hint: Label
var _waveform: Control
var _isolate_btn: Button
var _capture_btn: Button
var _route_btn: Button
var _respond_box: HBoxContainer
var _prompt_label: Label
var _silence_label: Label
var _murmur: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _vocal: AudioStreamPlayer
var _pulses: Array = []
var _blink := 0.0
var _infection_tween: Tween


func _ready() -> void:
	layer = 9
	visible = false
	_panel = PanelContainer.new()
	_panel.position = Vector2(240, 340)
	_panel.custom_minimum_size = Vector2(800, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.07, 0.96)
	style.border_color = Color(0.16, 0.2, 0.25)
	style.set_border_width_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 13)
	_header.modulate = Color(0.5, 0.85, 0.8)
	vb.add_child(_header)
	_waveform = Control.new()
	_waveform.custom_minimum_size = Vector2(780, 96)
	_waveform.draw.connect(_draw_waveform)
	vb.add_child(_waveform)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	vb.add_child(tools)
	_isolate_btn = _btn(tools, "ISOLATE", _press_isolate)
	_isolate_btn.toggle_mode = true
	_capture_btn = _btn(tools, "CAPTURE", press_capture)
	_route_btn = _btn(tools, "ROUTE", press_route)
	_respond_box = HBoxContainer.new()
	_respond_box.add_theme_constant_override("separation", 10)
	_respond_box.visible = false
	vb.add_child(_respond_box)
	_prompt_label = Label.new()
	_prompt_label.modulate = Color(0.95, 0.65, 0.35)
	_respond_box.add_child(_prompt_label)
	_silence_label = Label.new()
	_silence_label.modulate = Color(0.5, 0.55, 0.6)
	_silence_label.add_theme_font_size_override("font_size", 11)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.modulate = Color(0.75, 0.8, 0.85)
	vb.add_child(_hint)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 13)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size = Vector2(780, 44)
	vb.add_child(_subtitle)
	var leave_btn := _btn(vb, "STEP AWAY FROM DESK (Esc)", leave, false)
	leave_btn.add_theme_font_size_override("font_size", 10)

	_murmur = _mk_audio("murmur_loop", -40.0, true)
	_breath = _mk_audio("breath", -12.0)
	_vocal = _mk_audio("vocal", -8.0)
	Conductor.motif_tick.connect(_on_motif_tick)
	_load_case()
	set_process(true)


func _btn(parent: Node, text: String, fn: Callable, disabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(fn)
	parent.add_child(b)
	return b


func _mk_audio(key: String, volume_db: float, autoplay := false) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = PropAudio.get_stream(key)
	p.volume_db = volume_db
	add_child(p)
	if autoplay:
		p.play()
	return p


# ------------------------------------------------------------ case loading

## Dress the console for whichever case is next on the line. Nothing here
## touches the world; a case only exists once the player sits down.
func _load_case() -> void:
	_case = CaseLibrary.case_at(case_index)
	if _case.is_empty():
		_header.text = "NIGHTLINE REMOTE SUPPORT — NO CALLS WAITING"
		_hint.text = "The line is quiet. It has not been quiet before."
		_isolate_btn.disabled = true
		_capture_btn.disabled = true
		_route_btn.disabled = true
		return
	_header.text = "NIGHTLINE REMOTE SUPPORT — CASE #%s · %s · \"%s\"" % [
			_case.id, _case.caller, _case.complaint]
	var tools: Dictionary = _case.tools
	_isolate_btn.text = tools.isolate
	_capture_btn.text = tools.capture
	_route_btn.text = tools.route
	_isolate_btn.disabled = true
	_isolate_btn.set_pressed_no_signal(false)
	_capture_btn.disabled = true
	_route_btn.disabled = true
	_prompt_label.text = _case.prompt
	_silence_label.text = _case.silence_note
	for child in _respond_box.get_children():
		if child is Button:
			child.queue_free()
			_respond_box.remove_child(child)
	if _silence_label.get_parent() == _respond_box:
		_respond_box.remove_child(_silence_label)
	for r in _case.responses:
		var id: String = r.id
		_btn(_respond_box, r.label, func(): press_respond(id), false)
	_respond_box.add_child(_silence_label)
	_respond_box.visible = false
	_hint.text = ""
	_subtitle.text = ""


## Called when a closed case is left behind: the next caller is already
## holding. There is always another one.
func _advance() -> void:
	closed_outcomes.append(outcome)
	case_index += 1
	stage = Stage.IDLE
	outcome = ""
	_started = false
	_closed = false
	_isolated = false
	_captured = false
	_routed = false
	_ticks_heard = 0
	_silence_left = -1.0
	_run_id += 1
	_load_case()


# ------------------------------------------------------------ entry/exit

func enter(player: Node) -> void:
	_player = player
	if _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	if not _started and not _case.is_empty():
		_started = true
		_run_id += 1
		_seq_open(_run_id)


func leave() -> void:
	visible = false
	if _player:
		_player.call_locked = false
		_player = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Stepping away from a finished call is what clears the desk. The next
	# caller is not waiting on the outcome, only on the chair.
	if _closed:
		_advance()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		leave()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ beat player

func _delay(sec: float, rid: int) -> bool:
	await get_tree().create_timer(sec * (0.1 if fast else 1.0), false).timeout
	return rid == _run_id


func _say(text: String, who: String, tint: Color, rid: int) -> bool:
	_subtitle.text = "[%s]  %s" % [who, text]
	_subtitle.modulate = tint
	create_tween().tween_property(_murmur, "volume_db", -16.0, 0.3)
	var ok: bool = await _delay(clampf(1.6 + 0.045 * text.length(), 2.0, 6.0), rid)
	if ok:
		create_tween().tween_property(_murmur, "volume_db", -40.0, 0.5)
	return ok


## Plays a beat list. Returns false the moment the run is superseded (the
## player answered, or left and came back to a different case), so a stale
## sequence can never write over a live one.
func _run_beats(beats: Array, rid: int) -> bool:
	for beat in beats:
		if rid != _run_id:
			return false
		if beat.has("delay"):
			if not await _delay(beat.delay, rid):
				return false
		elif beat.has("say"):
			if not await _say(beat.say, _case.caller,
					Color(1, 1, 1), rid):
				return false
		elif beat.has("resident"):
			# The resident is not on the phone. They are through the wall.
			if not await _say(beat.resident, _case.resident,
					Color(0.72, 0.9, 0.78), rid):
				return false
		elif beat.has("hint"):
			_hint.text = beat.hint
		elif beat.has("infection"):
			Conductor.infection = beat.infection
		elif beat.has("infection_to"):
			_infection_tween = create_tween()
			_infection_tween.tween_method(func(v): Conductor.infection = v,
					Conductor.infection, beat.infection_to[0],
					beat.infection_to[1] * (0.2 if fast else 1.0))
		elif beat.has("origin"):
			# The captured loop now plays from here, and the building hears
			# it through the acoustic graph with real per-node delays.
			Conductor.propagation_mode = "network"
			Conductor.origin_node = beat.origin
		elif beat.has("propagate"):
			var p: Array = beat.propagate
			AcousticGraphData.propagate(p[0], p[1], p[2], p[3])
		elif beat.has("mutate"):
			Conductor.mutate_motif()
		elif beat.has("vocal"):
			_vocal.pitch_scale = beat.vocal
			_vocal.play()
		elif beat.has("reveal"):
			_reveal(beat.reveal)
		elif beat.has("flag"):
			flags[beat.flag] = true
			case_flag_set.emit(beat.flag)
			print("[CALL] case flag set: %s" % beat.flag)
		elif beat.has("respond"):
			_open_response(beat.respond)
			return true
	return true


func _reveal(prop_name: String) -> void:
	var node: Node = null
	if world:
		node = world.get_node_or_null(NodePath(prop_name))
	if node == null:
		push_warning("case reveal: no prop named %s" % prop_name)
		return
	if node.has_method("reveal"):
		node.reveal()
	print("[CALL] case revealed %s" % prop_name)


# ------------------------------------------------------------ sequence

func _seq_open(rid: int) -> void:
	stage = Stage.CALL
	print("[CALL] case %s opened (%s)" % [_case.id, _case.caller])
	if not await _run_beats(_case.open, rid):
		return
	if rid != _run_id:
		return
	_isolate_btn.disabled = false


func _press_isolate() -> void:
	press_isolate(_isolate_btn.button_pressed)


func press_isolate(active: bool) -> void:
	_isolated = active
	_isolate_btn.set_pressed_no_signal(active)
	if active and stage == Stage.CALL:
		stage = Stage.ISOLATION
		_hint.text = _case.isolate_hint
		print("[CALL] isolation active")


func press_capture() -> void:
	if _captured or stage < Stage.ISOLATION:
		return
	_captured = true
	stage = Stage.CAPTURE
	_capture_btn.disabled = true
	_route_btn.disabled = false
	_hint.text = _case.capture_hint
	print("[CALL] pattern captured")


func press_route() -> void:
	if not _captured or _routed:
		return
	_routed = true
	stage = Stage.TRANSMISSION
	print("[CALL] routing")
	_seq_route(_run_id)


func _seq_route(rid: int) -> void:
	if not await _run_beats(_case.route, rid):
		return
	if not await _run_beats(_case.transmission, rid):
		return


func _open_response(hint: String) -> void:
	if stage != Stage.TRANSMISSION:
		return
	stage = Stage.RESPONSE
	_respond_box.visible = true
	_hint.text = hint
	_silence_left = SILENCE_WINDOW * (0.15 if fast else 1.0)
	print("[CALL] response window open")


func press_respond(kind: String) -> void:
	if stage != Stage.RESPONSE or outcome != "":
		return  # latch: one outcome per case
	if not _case.outcomes.has(kind):
		return
	outcome = kind
	stage = Stage.OUTCOME
	_respond_box.visible = false
	_silence_left = -1.0
	if _infection_tween and _infection_tween.is_valid():
		_infection_tween.kill()  # the outcome owns infection from here
	print("[CALL] outcome -> %s" % kind)
	_seq_outcome(kind, _run_id)


func _seq_outcome(kind: String, rid: int) -> void:
	if not await _run_beats(_case.outcomes[kind], rid):
		return
	if rid != _run_id:
		return
	_subtitle.text = ""
	_hint.text = "CASE #%s · CUSTOMER EDUCATED · ISSUE RESOLVED" % _case.id
	_closed = true
	call_ended.emit(outcome)
	print("[CALL] case %s closed (%s)" % [_case.id, outcome])


# ------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	_blink += delta
	for p in _pulses:
		p.age += delta
	_pulses = _pulses.filter(func(p): return p.age < 0.8)
	if visible:
		_waveform.queue_redraw()
	if _silence_left > 0.0:
		_silence_left -= delta
		if _silence_left <= 0.0:
			# Saying nothing is an answer, and every case scores it as one.
			press_respond(_case.timeout)


func _on_motif_tick(index: int, accent: float, _pitch: float) -> void:
	# phone side: the caller's channel carries the motif whenever we can hear it
	if visible and stage >= Stage.ISOLATION and stage < Stage.OUTCOME \
			and not _case.is_empty():
		_breath.volume_db = -14.0 + linear_to_db(clampf(accent, 0.2, 1.0)) \
				+ (4.0 if _isolated else -8.0)
		_breath.pitch_scale = randf_range(0.92, 1.05)
		_breath.play()
		_pulses.append({"i": index, "age": 0.0, "accent": accent})
		_ticks_heard += 1
		if _ticks_heard >= int(_case.ticks_to_capture) \
				and stage == Stage.ISOLATION and _capture_btn.disabled:
			_capture_btn.disabled = false
			_hint.text = _case.capture_ready_hint


func _draw_waveform() -> void:
	var size := _waveform.size
	_waveform.draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.045, 0.06))
	var midy := size.y * 0.55
	_waveform.draw_line(Vector2(4, midy), Vector2(size.x - 4, midy),
			Color(0.15, 0.22, 0.26), 1.0)
	if stage < Stage.CAPTURE:
		if stage == Stage.IDLE:
			return
	else:
		for i in Conductor.motif_events.size():
			var ev: Dictionary = Conductor.motif_events[i]
			var x: float = 6.0 + (ev.t / Conductor.MOTIF_LOOP) * (size.x - 12.0)
			var h: float = ev.accent * size.y * 0.36
			_waveform.draw_rect(Rect2(x - 2, midy - h, 4, h * 2),
					Color(0.34, 0.9, 0.83))
		# the implied event: dashed, blinking, unanswered
		var gx: float = 6.0 + (Conductor.MOTIF_GAP_T / Conductor.MOTIF_LOOP) \
				* (size.x - 12.0)
		var ga := 0.35 + 0.5 * (0.5 + 0.5 * sin(_blink * 3.0)) \
				* (1.0 if stage >= Stage.RESPONSE else 0.3)
		var gcol := Color(0.95, 0.65, 0.35, ga)
		var y := midy - size.y * 0.36
		while y < midy + size.y * 0.36:
			_waveform.draw_line(Vector2(gx, y), Vector2(gx, y + 4), gcol, 2.0)
			y += 8.0
	for p in _pulses:
		var ev2: Dictionary = Conductor.motif_events[clampi(p.i, 0,
				Conductor.motif_events.size() - 1)]
		var px: float = 6.0 + (ev2.t / Conductor.MOTIF_LOOP) * (size.x - 12.0)
		var a: float = (1.0 - p.age / 0.8) * 0.9
		_waveform.draw_circle(Vector2(px, midy), 3.0 + p.age * 12.0,
				Color(0.34, 0.9, 0.83, a * 0.5))
