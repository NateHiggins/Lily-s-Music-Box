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
	var case_title := Label.new()
	case_title.text = "MINA CASE — recurrence scaffold"
	case_title.add_theme_font_size_override("font_size", 10)
	case_title.modulate = Color(0.65, 0.9, 0.82)
	_body.add_child(case_title)
	var case_row := GridContainer.new()
	case_row.columns = 3
	_body.add_child(case_row)
	_case_button(case_row, "Open", func():
		RealityCases.activate_case("mina_caption_crisis"))
	_case_button(case_row, "Stabilize", func():
		RealityCases.stabilize_case("mina_caption_crisis"))
	_case_button(case_row, "Reopen", func():
		RealityCases.reopen_case("mina_caption_crisis"))
	_case_button(case_row, "Insight 1", func():
		RealityCases.record_conversation("mina_caption_crisis",
				"assumptions_are_not_facts"))
	_case_button(case_row, "Insight 2", func():
		RealityCases.record_conversation("mina_caption_crisis",
				"silence_can_be_blank"))
	_case_button(case_row, "Integrate", func():
		RealityCases.resolve_case("mina_caption_crisis"))
	_case_button(case_row, "Reset case", func():
		RealityCases.debug_reset_case("mina_caption_crisis"))
	var rule_title := Label.new()
	rule_title.text = "REALITY RULE PROTOTYPES"
	rule_title.add_theme_font_size_override("font_size", 10)
	rule_title.modulate = Color(0.78, 0.68, 0.94)
	_body.add_child(rule_title)
	for prototype in [
		["Mina labels", "mina_caption_crisis"],
		["Peter topology", "peter_form_corridor"],
		["Cam gravity", "cam_tilted_room"],
	]:
		var row := HBoxContainer.new()
		_body.add_child(row)
		var title := Label.new()
		title.text = prototype[0]
		title.custom_minimum_size.x = 82
		title.add_theme_font_size_override("font_size", 9)
		row.add_child(title)
		var prototype_case: String = prototype[1]
		_case_button(row, "On", func():
			RealityCases.activate_case(prototype_case))
		_case_button(row, "Fix", func():
			RealityCases.stabilize_case(prototype_case))
		_case_button(row, "Reset", func():
			RealityCases.debug_reset_case(prototype_case))
	var distortion_title := Label.new()
	distortion_title.text = "MAP DISTORTION LAB — F3 cycles"
	distortion_title.add_theme_font_size_override("font_size", 10)
	distortion_title.modulate = Color(0.62, 0.82, 0.92)
	_body.add_child(distortion_title)
	var distortion_grid := GridContainer.new()
	distortion_grid.columns = 4
	_body.add_child(distortion_grid)
	for distortion in MapDistortionLab.MODES:
		var distortion_mode: String = distortion
		_case_button(distortion_grid,
				distortion_mode.replace("_", " ").capitalize(),
				func(): root.map_distortion_lab.set_mode(distortion_mode))
	# Tunable on the device that has to run it. The mobile light budget was
	# originally set from reasoning about tile-based GPUs with no phone to
	# check against, and it came out too dark. These two sliders sit next to
	# the frame counter so the ceiling can be found by pushing them until
	# the fps gives, instead of by argument.
	_slider("Light budget", 1, 24, root.light_rig._active_budget,
			func(v): root.light_rig.set_budgets(int(v),
					root.light_rig._shadow_budget), 1.0)
	_slider("Shadow budget", 0, 16, root.light_rig._shadow_budget,
			func(v): root.light_rig.set_budgets(
					root.light_rig._active_budget, int(v)), 1.0)
	# Lets the phone HUD be driven and judged on a desktop, where a mouse
	# drag stands in for a thumb — otherwise the only way to see whether the
	# controls are reachable is to build an APK first.
	var touch := CheckBox.new()
	touch.text = "Touch controls (phone HUD)"
	touch.button_pressed = root.touch.enabled if root and root.touch else false
	touch.toggled.connect(func(on):
		if root and root.touch:
			root.touch.set_enabled(on)
			root.player.touch_input = on
			if on:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	_body.add_child(touch)
	var hint := Label.new()
	hint.text = "WASD move · Shift run · C crouch · E interact\nL flashlight · V noclip · F2 intro · F3 distort map · Esc release mouse"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.7, 0.7, 0.75)
	_body.add_child(hint)


func _slider(label_text: String, lo: float, hi: float, initial: float,
		on_change: Callable, step := 0.01) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 70
	l.add_theme_font_size_override("font_size", 10)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = initial
	s.custom_minimum_size.x = 150
	s.value_changed.connect(on_change)
	row.add_child(s)
	_body.add_child(row)


func _case_button(parent: Node, label_text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(action)
	parent.add_child(button)


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
	var mina: Dictionary = RealityState.case_state("mina_caption_crisis")
	var case_status := "\nMina %s · repairs %d · recurrences %d" % [
			str(mina.get("stage", "unseen")), int(mina.get("repair_count", 0)),
			int(mina.get("recurrence_count", 0))]
	_status.text = ("pos (%.1f, %.1f, %.1f)  fps %d\n" +
			"bpm %.0f  infection %.2f%s%s") \
			% [p.x, p.y, p.z, Engine.get_frames_per_second(),
			Conductor.bpm, Conductor.infection, seed_status, case_status]
