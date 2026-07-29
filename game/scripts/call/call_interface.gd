class_name CallInterface
extends CanvasLayer
## Case 01 ("The Early Answer") played from inside apartment 4B. A compact
## port of the 2D prototype's support-call loop, wired into the building:
## the caller's breathing rides the SAME conductor clock the building
## follows, routing the captured loop moves the conductor's origin to the
## 4B desk, and the outcomes change real building state — Complete pushes
## infection high enough that the door anomaly manifests in the wall.
## Interact with the desk chair to enter; Esc to step away (the call and
## its consequences continue without you).

signal call_ended(outcome: String)

enum Stage { IDLE, CALL, ISOLATION, CAPTURE, TRANSMISSION, RESPONSE, OUTCOME }

const SILENCE_WINDOW := 16.0
const CALLER := "M. CHEN"

var stage: Stage = Stage.IDLE
var outcome := ""
var fast := false          # test hook: compress waits

var _player: Node = null
var _run_id := 0
var _started := false
var _isolated := false
var _captured := false
var _routed := false
var _silence_left := -1.0
var _breath_heard := 0

var _panel: PanelContainer
var _subtitle: Label
var _hint: Label
var _waveform: Control
var _isolate_btn: Button
var _capture_btn: Button
var _route_btn: Button
var _respond_box: HBoxContainer
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
	var header := Label.new()
	header.text = "NIGHTLINE REMOTE SUPPORT — CASE #4471 · %s · \"SPEAKER ANSWERS BEFORE I ASK\"" % CALLER
	header.add_theme_font_size_override("font_size", 13)
	header.modulate = Color(0.5, 0.85, 0.8)
	vb.add_child(header)
	_waveform = Control.new()
	_waveform.custom_minimum_size = Vector2(780, 96)
	_waveform.draw.connect(_draw_waveform)
	vb.add_child(_waveform)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	vb.add_child(tools)
	_isolate_btn = _btn(tools, "ISOLATE NOISE", _press_isolate)
	_isolate_btn.toggle_mode = true
	_capture_btn = _btn(tools, "CAPTURE LOOP", press_capture)
	_route_btn = _btn(tools, "ROUTE → DESK SPEAKERS", press_route)
	_respond_box = HBoxContainer.new()
	_respond_box.add_theme_constant_override("separation", 10)
	_respond_box.visible = false
	vb.add_child(_respond_box)
	var wait := Label.new()
	wait.text = "THE PATTERN WAITS —"
	wait.modulate = Color(0.95, 0.65, 0.35)
	_respond_box.add_child(wait)
	_btn(_respond_box, "COMPLETE IT", func(): press_respond("complete"), false)
	_btn(_respond_box, "INTERRUPT", func(): press_respond("interrupt"), false)
	var silent := Label.new()
	silent.text = "(or say nothing)"
	silent.modulate = Color(0.5, 0.55, 0.6)
	silent.add_theme_font_size_override("font_size", 11)
	_respond_box.add_child(silent)
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


# ------------------------------------------------------------ entry/exit

func enter(player: Node) -> void:
	_player = player
	if _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	if not _started:
		_started = true
		_run_id += 1
		_seq_call(_run_id)


func leave() -> void:
	visible = false
	if _player:
		_player.call_locked = false
		_player = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		leave()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ sequence

func _delay(sec: float, rid: int) -> bool:
	await get_tree().create_timer(sec * (0.1 if fast else 1.0), false).timeout
	return rid == _run_id


func _say(text: String, rid: int) -> bool:
	_subtitle.text = "[%s]  %s" % [CALLER, text]
	create_tween().tween_property(_murmur, "volume_db", -16.0, 0.3)
	var ok: bool = await _delay(clampf(1.6 + 0.045 * text.length(), 2.0, 6.0), rid)
	if ok:
		create_tween().tween_property(_murmur, "volume_db", -40.0, 0.5)
	return ok


func _seq_call(rid: int) -> void:
	stage = Stage.CALL
	print("[CALL] case 4471 opened")
	if not await _delay(1.5, rid): return
	if not await _say("Thanks for staying on this late. It's the speaker — it answers before I finish asking.", rid): return
	if not await _delay(0.8, rid): return
	if not await _say("There's a clicking behind it too. That's just the pipes. Ignore that.", rid): return
	if not await _delay(1.5, rid): return
	_hint.text = "ANALYSIS: periodic transient on background channel — the same period as this building."
	_isolate_btn.disabled = false


func _press_isolate() -> void:
	press_isolate(_isolate_btn.button_pressed)


func press_isolate(active: bool) -> void:
	_isolated = active
	_isolate_btn.set_pressed_no_signal(active)
	if active and stage == Stage.CALL:
		stage = Stage.ISOLATION
		_hint.text = "Background channel isolated. Listen to her breathing."
		print("[CALL] isolation active")


func press_capture() -> void:
	if _captured or stage < Stage.ISOLATION:
		return
	_captured = true
	stage = Stage.CAPTURE
	_capture_btn.disabled = true
	_route_btn.disabled = false
	_hint.text = "Loop held: four marks, one empty slot. Route it to hear it in the room."
	print("[CALL] motif captured")


func press_route() -> void:
	if not _captured or _routed:
		return
	_routed = true
	stage = Stage.TRANSMISSION
	# The captured loop now plays from the desk: the conductor's origin
	# moves to 4B and the building hears it through the electrical network.
	Conductor.propagation_mode = "network"
	Conductor.origin_node = "F04_B_MONITOR_01"
	_infection_tween = create_tween()
	_infection_tween.tween_method(func(v): Conductor.infection = v,
			Conductor.infection, 0.6, 2.0 if fast else 10.0)
	_hint.text = "Routing through desk speakers. Room response pending…"
	print("[CALL] routed to desk speakers, origin -> F04_B_MONITOR_01")
	_seq_transmission(_run_id)


func _seq_transmission(rid: int) -> void:
	if not await _delay(6.0, rid): return
	if not await _say("Wait. I can hear knocking. Not here — through the phone. It's in YOUR room, isn't it?", rid): return
	if not await _delay(3.0, rid): return
	if stage != Stage.TRANSMISSION or rid != _run_id:
		return
	stage = Stage.RESPONSE
	_respond_box.visible = true
	_hint.text = "Every source stops at the same empty slot. It is waiting."
	_silence_left = SILENCE_WINDOW * (0.15 if fast else 1.0)
	print("[CALL] response window open")


func press_respond(kind: String) -> void:
	if stage != Stage.RESPONSE or outcome != "":
		return  # latch: one outcome per case
	outcome = kind
	stage = Stage.OUTCOME
	_respond_box.visible = false
	_silence_left = -1.0
	if _infection_tween and _infection_tween.is_valid():
		_infection_tween.kill()  # the outcome owns infection from here
	print("[CALL] outcome -> %s" % kind)
	match kind:
		"complete":
			_seq_complete(_run_id)
		"interrupt":
			_seq_interrupt(_run_id)
		"silence":
			_seq_silence(_run_id)


func _seq_complete(rid: int) -> void:
	_hint.text = "You answered."
	_vocal.play()  # the player hums the missing fifth
	if not await _delay(0.9, rid): return
	# the radiator answers, and the answer spreads from IT
	AcousticGraphData.propagate("F04_B_RADIATOR_01", 4, 1.0, 0.0)
	Conductor.infection = 0.85  # stable, elevated: the seam can exist now
	if not await _delay(1.6, rid): return
	if not await _say("oh. the door was always there. i can see your room now.", rid): return
	_finish(rid)


func _seq_interrupt(rid: int) -> void:
	_hint.text = "You spoke over it."
	_vocal.pitch_scale = 1.3
	_vocal.play()
	Conductor.mutate_motif()
	Conductor.infection = 0.65
	if not await _delay(2.0, rid): return
	if not await _say("There's another voice in my speaker now. It's answering for me.", rid): return
	_finish(rid)


func _seq_silence(rid: int) -> void:
	_hint.text = ""
	create_tween().tween_method(func(v): Conductor.infection = v,
			Conductor.infection, 0.25, 3.0)
	if not await _delay(3.5, rid): return
	# she finishes it herself; the fifth beat arrives from the radiator
	# behind the player, low and wrong
	AcousticGraphData.propagate("F04_B_RADIATOR_01", 4, 1.0, -12.0)
	Conductor.infection = 0.5
	if not await _delay(1.4, rid): return
	if not await _say("you left it unfinished. hold still — i finished it for you.", rid): return
	_finish(rid)


func _finish(rid: int) -> void:
	if rid != _run_id: return
	_subtitle.text = ""
	_hint.text = "CASE #4471 · CUSTOMER EDUCATED · ISSUE RESOLVED"
	call_ended.emit(outcome)
	print("[CALL] case closed (%s)" % outcome)


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
			press_respond("silence")


func _on_motif_tick(index: int, accent: float, _pitch: float) -> void:
	# phone side: her breathing carries the motif whenever we can hear it
	if visible and stage >= Stage.ISOLATION and stage < Stage.OUTCOME:
		_breath.volume_db = -14.0 + linear_to_db(clampf(accent, 0.2, 1.0)) \
				+ (4.0 if _isolated else -8.0)
		_breath.pitch_scale = randf_range(0.92, 1.05)
		_breath.play()
		_pulses.append({"i": index, "age": 0.0, "accent": accent})
		_breath_heard += 1
		if _breath_heard >= 6 and stage == Stage.ISOLATION and _capture_btn.disabled:
			_capture_btn.disabled = false
			_hint.text = "Pattern registered: 4 events, 1 expected. [CAPTURE LOOP] to hold it."


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
		# the implied fifth event: dashed, blinking, unanswered
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
