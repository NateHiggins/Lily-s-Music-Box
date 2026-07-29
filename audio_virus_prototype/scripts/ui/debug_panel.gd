class_name DebugPanel
extends PanelContainer
## Collapsible developer panel (toggle with F1 or the header button).
## Reads GameState directly for display; talks to the scene only through
## signals so it stays decoupled from Main's internals.

signal replay_source(profile_id: String)
signal restart_requested
signal skip_to_stage(stage: int)
signal markers_toggled(enabled: bool)
signal tempo_changed(value: float)
signal drift_changed(value: float)
signal infection_changed(value: float)
signal master_volume_changed(db: float)
signal mute_toggled(muted: bool)

## Main sets this to a Callable returning Array[String] describing active renderers.
var renderer_status_provider: Callable = Callable()

var _body: VBoxContainer
var _state_label: Label
var _renderers_label: Label
var _peak_label: Label
var _refresh_accum := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(310, 0)
	var root := VBoxContainer.new()
	add_child(root)

	var header := Button.new()
	header.text = "DEBUG ▸ (F1)"
	header.pressed.connect(_toggle)
	root.add_child(header)

	_body = VBoxContainer.new()
	_body.visible = false
	root.add_child(_body)

	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 11)
	_body.add_child(_state_label)

	_renderers_label = Label.new()
	_renderers_label.add_theme_font_size_override("font_size", 11)
	_renderers_label.modulate = Color(0.7, 0.9, 0.85)
	_body.add_child(_renderers_label)

	_peak_label = Label.new()
	_peak_label.add_theme_font_size_override("font_size", 11)
	_body.add_child(_peak_label)

	_body.add_child(HSeparator.new())
	_add_label("REPLAY SOURCE")
	var replay_row := _grid(3)
	for src in ["caller_breathing", "radiator", "computer_notification", "electrical_hum", "human_humming"]:
		var b := Button.new()
		b.text = src.replace("_", " ").left(12)
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func(): replay_source.emit(src))
		replay_row.add_child(b)

	_add_label("SKIP TO STAGE")
	var skip_row := _grid(3)
	for stage in GameState.Stage.size() - 1:  # OUTCOME reached via response, not skip
		var b := Button.new()
		b.text = GameState.STAGE_NAMES[stage].left(9)
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func(): skip_to_stage.emit(stage))
		skip_row.add_child(b)

	_body.add_child(HSeparator.new())
	_add_slider("Tempo", 0.5, 1.6, 1.0, func(v): tempo_changed.emit(v))
	_add_slider("Drift ×", 0.0, 4.0, 1.0, func(v): drift_changed.emit(v))
	_add_slider("Infection", 0.0, 1.0, 0.0, func(v): infection_changed.emit(v))
	_add_slider("Master dB", -30.0, 0.0, 0.0, func(v): master_volume_changed.emit(v))

	var markers := CheckBox.new()
	markers.text = "Show motif event markers"
	markers.button_pressed = true
	markers.toggled.connect(func(on): markers_toggled.emit(on))
	_body.add_child(markers)

	var mute := CheckBox.new()
	mute.text = "Master mute"
	mute.toggled.connect(func(on): mute_toggled.emit(on))
	_body.add_child(mute)

	var restart := Button.new()
	restart.text = "RESTART SEQUENCE"
	restart.pressed.connect(func(): restart_requested.emit())
	_body.add_child(restart)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_toggle()


func _toggle() -> void:
	_body.visible = not _body.visible


func _add_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.modulate = Color(0.6, 0.6, 0.65)
	_body.add_child(l)


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	_body.add_child(g)
	return g


func _add_slider(label_text: String, lo: float, hi: float, initial: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 80
	l.add_theme_font_size_override("font_size", 10)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = initial
	s.custom_minimum_size.x = 170
	s.value_changed.connect(on_change)
	row.add_child(s)
	_body.add_child(row)


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum < 0.2 or not _body.visible:
		return
	_refresh_accum = 0.0
	_state_label.text = "\n".join([
		"stage: %s" % GameState.STAGE_NAMES[GameState.call_stage],
		"isolated: %s  captured: %s" % [GameState.is_noise_isolated, GameState.motif_captured],
		"route: %s" % GameState.current_route,
		"infection room %.2f / caller %.2f" % [GameState.room_infection_level, GameState.caller_infection_level],
		"radiator: %s  computer: %s" % [GameState.radiator_infected, GameState.computer_infected],
		"response: %s  mutations: %d" % [GameState.RESPONSE_NAMES[GameState.player_response], GameState.motif_mutation],
	])
	if renderer_status_provider.is_valid():
		_renderers_label.text = "\n".join(renderer_status_provider.call())
	var peak: float = AudioEnv.master_peak_db()
	if peak > -0.5:
		_peak_label.text = "peak %.1f dB  ⚠ NEAR CLIP" % peak
		_peak_label.modulate = Color(1.0, 0.4, 0.35)
	else:
		_peak_label.text = "peak %.1f dB" % peak
		_peak_label.modulate = Color(0.7, 0.75, 0.8)
