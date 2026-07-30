class_name BuildingDebug
extends PanelContainer
## Collapsible debug panel (F1): floor teleports, conductor controls,
## infection, floor-visibility override, acoustic graph overlay, position
## and FPS readouts.

var root: Node3D
var _body: VBoxContainer
var _status: Label
var _overlay_on := false


func setup(building_root: Node3D) -> void:
	root = building_root


func _ready() -> void:
	position = Vector2(8, 8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	add_child(vb)
	var header := Button.new()
	header.text = "ORISON DEBUG ▸ (F1)"
	header.pressed.connect(func(): _body.visible = not _body.visible)
	vb.add_child(header)
	_body = VBoxContainer.new()
	## Start expanded so a missing/consumed F1 binding can never make the
	## controls undiscoverable. F1 collapses the body but leaves the header.
	_body.visible = true
	vb.add_child(_body)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_body.add_child(_status)

	var grid := GridContainer.new()
	grid.columns = 4
	_body.add_child(grid)
	for fid in ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]:
		var b := Button.new()
		b.text = fid
		b.add_theme_font_size_override("font_size", 10)
		b.pressed.connect(func(): root.teleport_player(fid))
		grid.add_child(b)

	_slider("BPM", 40, 140, Conductor.bpm, func(v): Conductor.bpm = v)
	_slider("Infection", 0.0, 1.0, Conductor.infection,
			func(v): Conductor.infection = v)

	var networked := CheckBox.new()
	networked.text = "Networked propagation (graph delays)"
	networked.button_pressed = Conductor.propagation_mode == "network"
	networked.toggled.connect(func(on):
		Conductor.propagation_mode = "network" if on else "global")
	_body.add_child(networked)
	var origin_row := HBoxContainer.new()
	var ol := Label.new()
	ol.text = "Origin"
	ol.add_theme_font_size_override("font_size", 10)
	origin_row.add_child(ol)
	for origin in ["B1_BOILER_01", "F04_B_RADIATOR_01", "ROOF_FLUE_TOP"]:
		var ob := Button.new()
		ob.text = origin.replace("_01", "").replace("_", " ").to_lower()
		ob.add_theme_font_size_override("font_size", 9)
		ob.pressed.connect(func(): Conductor.origin_node = origin)
		origin_row.add_child(ob)
	_body.add_child(origin_row)

	var all_floors := CheckBox.new()
	all_floors.text = "Show all floors"
	all_floors.toggled.connect(func(on): root.show_all_floors = on)
	_body.add_child(all_floors)
	var overlay := CheckBox.new()
	overlay.text = "Acoustic graph overlay"
	overlay.toggled.connect(func(on):
		_overlay_on = on
		AcousticGraphData.set_overlay_visible(on, root))
	_body.add_child(overlay)
	var mute := CheckBox.new()
	mute.text = "Mute"
	mute.toggled.connect(func(on): AudioServer.set_bus_mute(0, on))
	_body.add_child(mute)
	var seed := Button.new()
	seed.text = "Play intro (F2)"
	seed.add_theme_font_size_override("font_size", 10)
	seed.pressed.connect(func(): root.virus_director.toggle_intro())
	_body.add_child(seed)
	var hint := Label.new()
	hint.text = "WASD move · Shift run · C crouch · E interact\nL flashlight · V noclip · F2 intro · Esc release mouse"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.7, 0.7, 0.75)
	_body.add_child(hint)


func _slider(label_text: String, lo: float, hi: float, initial: float,
		on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 70
	l.add_theme_font_size_override("font_size", 10)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = initial
	s.custom_minimum_size.x = 150
	s.value_changed.connect(on_change)
	row.add_child(s)
	_body.add_child(row)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		_body.visible = not _body.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("intro") and root \
			and root.virus_director:
		root.virus_director.toggle_intro()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _body.visible or root == null or root.player == null:
		return
	var p: Vector3 = root.player.global_position
	var seed_status := ""
	if root.virus_director and root.virus_director.active:
		var f: Dictionary = root.virus_director.current_features
		seed_status = "\nintro %.1fs  low %.2f  mid %.2f  high %.2f" % [
				root.virus_director._elapsed, float(f.get("low", 0.0)),
				float(f.get("mid", 0.0)), float(f.get("high", 0.0))]
	_status.text = ("pos (%.1f, %.1f, %.1f)  fps %d\n" +
			"bpm %.0f  infection %.2f%s") \
			% [p.x, p.y, p.z, Engine.get_frames_per_second(),
			Conductor.bpm, Conductor.infection, seed_status]
