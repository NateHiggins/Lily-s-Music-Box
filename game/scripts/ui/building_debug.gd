class_name BuildingDebug
extends PanelContainer
## Debug panel (F1). Scrollable, sectioned, and deliberately curated: it
## carries controls for what is actually being worked on right now, not
## everything that has ever been worked on.
##
## It grew past the bottom of a 720p window some time ago, which made the
## most recently added controls — always appended at the end — the ones you
## could not reach. Hence the scroll, and hence the sections: with nine
## subsystems in here, a flat list is not navigable even when it fits.
##
## The wheel is handled explicitly rather than left to the ScrollContainer,
## because this game captures the mouse. With the pointer captured the
## container never sees a hover and the panel would only scroll after Esc,
## which is exactly when you are least likely to want to stop playing.
##
## What earned its place, and why:
##   SUBJECT   one resident picker shared by the sanity and reality sections
##   SANITY    the newest subsystem and the only one with no other way in
##   CASES     three call-network cases that need driving from any state
##   CONDUCTOR bpm/infection/origin drive every other system in the building
##   WORLD     distortion and chaos, which are how the safety net gets tested
##   DEVICE    light budgets and the phone HUD, both still unresolved
## What was cut is described at the bottom of this file.

var root: Node3D

var _shot_status: Label
var _body: ScrollContainer
var _column: VBoxContainer
var _status: Label
var _resident_pick: OptionButton
var _effect_pick: OptionButton
var _overlay_on := false
var _sections: Dictionary = {}
var _light_sliders: Dictionary = {}
var _updating_light_controls := false
var _selected_fixture: Node
var _light_identity: Label


func setup(building_root: Node3D) -> void:
	root = building_root


func _ready() -> void:
	position = Vector2(8, 8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shell := VBoxContainer.new()
	add_child(shell)
	var header := Button.new()
	header.text = "ORISON DEBUG ▸ (F1)"
	header.pressed.connect(func(): _body.visible = not _body.visible)
	shell.add_child(header)

	_body = ScrollContainer.new()
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Never taller than the window it is drawn in. Without this the panel
	# runs off the bottom of the screen and the newest controls are the
	# unreachable ones.
	# Width is fixed; height follows the content up to a ceiling, set every
	# frame in _process. Reserving the full height up front instead left a
	# slab of empty panel below the controls whenever sections were closed,
	# which is most of the time.
	_body.custom_minimum_size = Vector2(340, 0)
	## Start expanded so a missing or consumed F1 binding can never make the
	## controls undiscoverable. F1 collapses the body but leaves the header.
	_body.visible = true
	shell.add_child(_body)
	_column = VBoxContainer.new()
	_body.add_child(_column)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_column.add_child(_status)

	_build_subject()
	_build_sanity()
	_build_cast()
	_build_cases()
	_build_go()
	_build_conductor()
	_build_reality()
	_build_world()
	_build_device()
	_build_capture()
	_build_keys()
	root.light_rig.debug_fixture_selected.connect(_on_debug_fixture_selected)


# ------------------------------------------------------------- sections

## Collapsible so nine subsystems can coexist without a scroll marathon.
## Only the sections for live work open by default.
func _section(title: String, tint: Color, open := false) -> VBoxContainer:
	var toggle := Button.new()
	toggle.text = ("▾ " if open else "▸ ") + title
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.add_theme_font_size_override("font_size", 10)
	toggle.modulate = tint
	_column.add_child(toggle)
	var box := VBoxContainer.new()
	box.visible = open
	_column.add_child(box)
	toggle.pressed.connect(func():
		box.visible = not box.visible
		toggle.text = ("▾ " if box.visible else "▸ ") + title)
	_sections[title] = box
	return box


## One picker, shared. Both the sanity rungs and the reality-case lifecycle
## act on "whichever resident is selected", so asking twice would be two
## controls that can disagree.
func _build_subject() -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "SUBJECT"
	label.custom_minimum_size.x = 58
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	_resident_pick = OptionButton.new()
	_resident_pick.add_theme_font_size_override("font_size", 10)
	_resident_pick.custom_minimum_size.x = 250
	for case_id in PoltergeistLibrary.ids():
		var profile: Dictionary = PoltergeistLibrary.profile(case_id)
		_resident_pick.add_item("%s · %s" % [profile.resident, profile.unit])
		_resident_pick.set_item_metadata(
				_resident_pick.item_count - 1, case_id)
	row.add_child(_resident_pick)
	_column.add_child(row)


func _selected_case() -> String:
	if _resident_pick == null or _resident_pick.selected < 0:
		return "mina_caption_crisis"
	return str(_resident_pick.get_item_metadata(_resident_pick.selected))


## The newest subsystem, and the only one with no other way in. Everything
## the director normally decides for itself can be forced from here, because
## an invisible system that only fires on its own schedule is untestable by
## definition.
func _build_sanity() -> void:
	var box := _section("SANITY — invisible director", Color(0.95, 0.7, 0.55),
			true)
	var rungs := HBoxContainer.new()
	var rung_label := Label.new()
	rung_label.text = "Rung"
	rung_label.custom_minimum_size.x = 58
	rung_label.add_theme_font_size_override("font_size", 10)
	rungs.add_child(rung_label)
	for tier in [1, 2, 3, 4]:
		var t: int = tier
		_button(rungs, ["tell", "pattern", "reenact", "ADDRESS"][t - 1],
				func(): root.sanity.force(_selected_case(), t))
	box.add_child(rungs)
	var controls := HBoxContainer.new()
	_button(controls, "Restore props",
			func(): root.sanity.intrusions.restore_all())
	_button(controls, "Stand down", func(): root.sanity.stand_down())
	_button(controls, "Re-arm", func(): root.sanity.enabled = true)
	box.add_child(controls)
	var meta := HBoxContainer.new()
	_effect_pick = OptionButton.new()
	_effect_pick.add_theme_font_size_override("font_size", 9)
	_effect_pick.custom_minimum_size.x = 180
	for effect in FourthWallLayer.EFFECTS:
		_effect_pick.add_item(str(effect))
	meta.add_child(_effect_pick)
	_button(meta, "Break frame", func():
		root.fourth_wall.force_finish()
		root.fourth_wall.play(str(_effect_pick.get_item_text(
				maxi(0, _effect_pick.selected)))))
	box.add_child(meta)
	# The net is invisible by design, so this is the only way to see it work
	# without actually falling out of the world.
	var net := HBoxContainer.new()
	_button(net, "Drop me out of the world",
			func(): root.safety_net.drop_test())
	box.add_child(net)


## Evelyn's clips arrive from Meshy with UUID filenames and no way to tell
## which prompt produced which. Cycling them in front of her, at eye height
## under the building's own lighting, is the only reliable way to name them —
## and it is also the only way to find out whether a clip actually works
## where it has to work.
func _build_cast() -> void:
	var box := _section("CAST — Evelyn's clips", Color(0.85, 0.65, 0.85), true)
	var row := HBoxContainer.new()
	_button(row, "◀ prev", func(): _step_clip(-1))
	_button(row, "next ▶", func(): _step_clip(1))
	_button(row, "go to her", func():
		var fig := _evelyn()
		if fig:
			root.player.global_position = fig.global_position \
					+ Vector3(-1.35, 0.0, 1.30)
			root.player.velocity = Vector3.ZERO)
	box.add_child(row)
	# Inspection parade: every resident teleported into lobby ranks,
	# routines held, so the whole cast can be judged in one sweep.
	var parade := HBoxContainer.new()
	_button(parade, "line up in lobby", func(): _lineup_cast(true))
	_button(parade, "send them home", func(): _lineup_cast(false))
	box.add_child(parade)


func _lineup_cast(gather: bool) -> void:
	var routines = root.resident_routines
	if routines:
		routines.inspection_hold = gather
	var residents := get_tree().get_nodes_in_group("resident_placeholders")
	residents.sort_custom(func(a, b):
		return str(a.get("resident_id")) < str(b.get("resident_id")))
	for i in residents.size():
		var resident: Node3D = residents[i]
		if gather:
			if not resident.has_meta("pre_lineup_pos"):
				resident.set_meta("pre_lineup_pos", resident.global_position)
				resident.set_meta("pre_lineup_yaw", resident.rotation.y)
				resident.set_meta("pre_lineup_home", resident.get("_home"))
			var col := i % 9
			var line := i / 9
			resident.global_position = GameBoot.b2g([
					-4.4 + col * 1.1, -8.7 + line * 1.3, 0.0])
			resident.rotation.y = PI  # face the entrance, and the inspector
			# AnimatedResident lerps toward _home; the parade ground is
			# home until dismissal.
			resident.set("_home", resident.position)
		elif resident.has_meta("pre_lineup_pos"):
			resident.global_position = resident.get_meta("pre_lineup_pos")
			resident.rotation.y = resident.get_meta("pre_lineup_yaw")
			if resident.get_meta("pre_lineup_home") != null:
				resident.set("_home", resident.get_meta("pre_lineup_home"))
			resident.remove_meta("pre_lineup_pos")
			resident.remove_meta("pre_lineup_yaw")
			resident.remove_meta("pre_lineup_home")


## She stands in 1A now — the lobby test figure that used to carry these
## clips is retired, so the cast panel drives the real resident.
func _evelyn() -> Node3D:
	for resident in get_tree().get_nodes_in_group("resident_placeholders"):
		if "resident_id" in resident and str(resident.get(
				"resident_id")) == "evelyn_marsh":
			return resident
	return null


func _evelyn_anim() -> AnimationPlayer:
	var fig := _evelyn()
	if fig == null:
		return null
	var stack: Array = [fig]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer:
			return node
		stack.append_array(node.get_children())
	return null


func _step_clip(direction: int) -> void:
	var anim := _evelyn_anim()
	if anim == null:
		return
	var clips := anim.get_animation_list()
	if clips.is_empty():
		return
	var here := Array(clips).find(anim.current_animation)
	var next: String = clips[(here + direction + clips.size()) % clips.size()]
	anim.play(next)


## Three cases exist and any of them may need driving from any state — the
## queue is linear, so without a skip you have to play case one to look at
## case three.
func _build_cases() -> void:
	var box := _section("CASES — call network", Color(0.5, 0.85, 0.8), true)
	var flow := HBoxContainer.new()
	_button(flow, "Sit", func(): root.call_interface.enter(root.player))
	_button(flow, "Isolate", func(): root.call_interface.press_isolate(true))
	_button(flow, "Capture", func(): root.call_interface.press_capture())
	_button(flow, "Route", func(): root.call_interface.press_route())
	_button(flow, "Leave", func(): root.call_interface.leave())
	box.add_child(flow)
	# Responses are per-case, so they are built on demand rather than baked.
	var answers := HBoxContainer.new()
	var answer_label := Label.new()
	answer_label.text = "Answer"
	answer_label.custom_minimum_size.x = 58
	answer_label.add_theme_font_size_override("font_size", 10)
	answers.add_child(answer_label)
	_button(answers, "list ▸", func(): _rebuild_answers(answers))
	box.add_child(answers)
	var skip := HBoxContainer.new()
	_button(skip, "Fast (compress waits)", func():
		root.call_interface.fast = not root.call_interface.fast)
	_button(skip, "Skip case", func():
		root.call_interface.outcome = "skipped"
		root.call_interface._closed = true
		root.call_interface.leave())
	box.add_child(skip)


## The live case decides what the buttons are, so they are rebuilt from its
## own response list rather than hard-coded to Case 01's three.
func _rebuild_answers(row: HBoxContainer) -> void:
	for child in row.get_children():
		if child is Button and str(child.text) != "list ▸":
			child.queue_free()
	var case_def: Dictionary = root.call_interface._case
	if case_def.is_empty():
		return
	for response in case_def.responses:
		var id: String = response.id
		_button(row, id, func(): root.call_interface.press_respond(id))
	# The timeout answer never has a button in-game — saying nothing is how
	# you pick it — but it still needs exercising.
	var timeout: String = case_def.timeout
	_button(row, timeout + "*",
			func(): root.call_interface.press_respond(timeout))


func _build_go() -> void:
	var box := _section("GO — teleports", Color(0.75, 0.8, 0.85))
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for fid in ["B1", "F01", "F02", "F03", "F04", "F05", "F06", "ROOF"]:
		var floor_id: String = fid
		_button(grid, floor_id, func(): root.teleport_player(floor_id))
	var extra := HBoxContainer.new()
	_button(extra, "4B desk", func():
		root.player.global_position = GameBoot.b2g([-8.8, 5.6, 9.7])
		root.player.velocity = Vector3.ZERO)
	_button(extra, "F03 utility door", func():
		root.player.global_position = GameBoot.b2g([-4.4, 2.0, 6.5])
		root.player.velocity = Vector3.ZERO)
	# The warehouse is a teleport, so it belongs with the teleports. It
	# used to live under CAPTURE - a section about screenshots, collapsed
	# by default - which is nobody's first guess for "take me to the
	# warehouse", and the one route into a room with no door is not a
	# thing to hide.
	_button(extra, "Prop warehouse", func():
		if root == null or root.warehouse == null:
			push_warning("[DEBUG] warehouse exists in DEBUG launches only")
			return
		var to: Vector3 = root.warehouse.viewing_stand()
		if root.view_override:
			root.view_override.global_position = to
		if root.player:
			root.player.global_position = to
			root.player.velocity = Vector3.ZERO
		print("[DEBUG] warehouse: %d prop kinds" % root.warehouse._built))
	box.add_child(extra)


func _build_conductor() -> void:
	var box := _section("CONDUCTOR — clock, infection, origin",
			Color(0.85, 0.8, 0.6))
	_slider(box, "BPM", 40, 140, Conductor.bpm, func(v): Conductor.bpm = v)
	_slider(box, "Infection", 0.0, 1.0, Conductor.infection,
			func(v): Conductor.infection = v)
	var networked := CheckBox.new()
	networked.text = "Networked propagation (graph delays)"
	networked.add_theme_font_size_override("font_size", 10)
	networked.button_pressed = Conductor.propagation_mode == "network"
	networked.toggled.connect(func(on):
		Conductor.propagation_mode = "network" if on else "global")
	box.add_child(networked)
	var origin_row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Origin"
	label.custom_minimum_size.x = 58
	label.add_theme_font_size_override("font_size", 10)
	origin_row.add_child(label)
	for origin in ["B1_BOILER_01", "F04_B_RADIATOR_01", "ROOF_FLUE_TOP"]:
		var node_id: String = origin
		_button(origin_row, node_id.replace("_01", "")
				.replace("_", " ").to_lower(),
				func(): Conductor.origin_node = node_id)
	box.add_child(origin_row)
	var extras := HBoxContainer.new()
	_button(extras, "Play intro (F2)",
			func(): root.virus_director.toggle_intro())
	_button(extras, "Mutate motif", func(): Conductor.mutate_motif())
	box.add_child(extras)


## One lifecycle row for whichever resident is selected, replacing what used
## to be seven hard-coded Mina buttons plus three more residents' worth of
## on/fix/reset. Strictly more capable, a third of the controls.
func _build_reality() -> void:
	var box := _section("REALITY — resident case lifecycle",
			Color(0.78, 0.68, 0.94))
	var row := HBoxContainer.new()
	_button(row, "Open", func():
		RealityCases.activate_case(_selected_case()))
	_button(row, "Stabilize", func():
		RealityCases.stabilize_case(_selected_case()))
	_button(row, "Reopen", func():
		RealityCases.reopen_case(_selected_case()))
	_button(row, "Reset", func():
		RealityCases.debug_reset_case(_selected_case()))
	box.add_child(row)
	# Insight flags come from the case definition, so this works for all
	# eighteen instead of only for the two Mina had buttons for.
	var insight := HBoxContainer.new()
	var label := Label.new()
	label.text = "Insight"
	label.custom_minimum_size.x = 58
	label.add_theme_font_size_override("font_size", 10)
	insight.add_child(label)
	_button(insight, "flags ▸", func(): _rebuild_insights(insight))
	_button(insight, "Resolve", func():
		RealityCases.resolve_case(_selected_case()))
	box.add_child(insight)


func _rebuild_insights(row: HBoxContainer) -> void:
	for child in row.get_children():
		if child is Button and str(child.text) not in ["flags ▸", "Resolve"]:
			child.queue_free()
	var case_id := _selected_case()
	var definition: Dictionary = RealityCases.definition(case_id)
	for flag in definition.get("resolution_flags", []):
		var name: String = flag
		_button(row, name.substr(0, 12),
				func(): RealityCases.record_conversation(case_id, name))


func _build_world() -> void:
	var box := _section("WORLD — visibility, distortion, chaos",
			Color(0.62, 0.82, 0.92))
	var all_floors := CheckBox.new()
	all_floors.text = "Show all floors"
	all_floors.add_theme_font_size_override("font_size", 10)
	all_floors.toggled.connect(func(on): root.show_all_floors = on)
	box.add_child(all_floors)
	var overlay := CheckBox.new()
	overlay.text = "Acoustic graph overlay"
	overlay.add_theme_font_size_override("font_size", 10)
	overlay.toggled.connect(func(on):
		_overlay_on = on
		AcousticGraphData.set_overlay_visible(on, root))
	box.add_child(overlay)
	var mute := CheckBox.new()
	mute.text = "Mute"
	mute.add_theme_font_size_override("font_size", 10)
	mute.toggled.connect(func(on): AudioServer.set_bus_mute(0, on))
	box.add_child(mute)


## Both of these are open questions on hardware rather than settled numbers,
## which is the whole reason they are adjustable next to a frame counter.
func _build_device() -> void:
	var box := _section("LIGHTING — global grade and budgets",
			Color(0.7, 0.85, 0.7))
	# The grade set remembers its boot values so one button can walk every
	# slider home. Budgets stay out: those are device answers, not grades.
	var grade: Dictionary = {}
	var torch_default := 1.15
	if root.player and root.player.flashlight:
		torch_default = root.player.flashlight.light_energy
	grade[_slider(box, "Torch", 0.0, 3.0, torch_default,
			_set_torch_energy, 0.01)] = torch_default
	grade[_slider(box, "Fixture", 0.0, 1.5, root.light_rig.fixture_gain,
			func(v): root.light_rig.set_tuning("fixture_gain", v), 0.01)] = \
			root.light_rig.fixture_gain
	grade[_slider(box, "Ambient gain", 0.0, 2.0, root.light_rig.ambient_gain,
			func(v): root.light_rig.set_tuning("ambient_gain", v), 0.01)] = \
			root.light_rig.ambient_gain
	grade[_slider(box, "Sky-key gain", 0.0, 2.0, root.light_rig.sky_key_gain,
			func(v): root.light_rig.set_tuning("sky_key_gain", v), 0.01)] = \
			root.light_rig.sky_key_gain
	grade[_slider(box, "Glow", 0.0, 1.2, root.light_rig.glow_intensity,
			func(v): root.light_rig.set_tuning("glow_intensity", v), 0.01)] = \
			root.light_rig.glow_intensity
	grade[_slider(box, "Fog gain", 0.0, 2.0, root.light_rig.fog_gain,
			func(v): root.light_rig.set_tuning("fog_gain", v), 0.01)] = \
			root.light_rig.fog_gain
	grade[_slider(box, "Shadow", 0.0, 1.0, root.light_rig.shadow_opacity,
			func(v): root.light_rig.set_tuning("shadow_opacity", v), 0.01)] = \
			root.light_rig.shadow_opacity
	_button(box, "Set lighting to defaults", func():
		for slider in grade:
			slider.value = grade[slider])
	_slider(box, "Lights", 1, 24, root.light_rig._active_budget,
			func(v): root.light_rig.set_budgets(int(v),
					root.light_rig._shadow_budget), 1.0)
	_slider(box, "Shadows", 0, 16, root.light_rig._shadow_budget,
			func(v): root.light_rig.set_budgets(
					root.light_rig._active_budget, int(v)), 1.0)
	var divider := HSeparator.new()
	box.add_child(divider)
	var inspect := CheckBox.new()
	inspect.text = "Walk-up light tuning (look at fixture + E)"
	inspect.add_theme_font_size_override("font_size", 10)
	inspect.toggled.connect(func(on):
		root.light_rig.set_debug_inspection(on)
		if on:
			_sections["LIGHTING — global grade and budgets"].visible = true)
	box.add_child(inspect)
	var fixture_hint := Label.new()
	fixture_hint.text = "Select a fitting in the world; sliders edit that fitting only."
	fixture_hint.add_theme_font_size_override("font_size", 9)
	fixture_hint.modulate = Color(0.72, 0.78, 0.70)
	fixture_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(fixture_hint)
	_light_identity = Label.new()
	_light_identity.text = "No light selected"
	_light_identity.add_theme_font_size_override("font_size", 10)
	_light_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_light_identity.modulate = Color(0.72, 1.0, 0.84)
	box.add_child(_light_identity)
	_light_sliders["energy_multiplier"] = _slider(box, "Energy ×", 0.0, 2.0,
			1.0, func(v): _set_light_value("energy_multiplier", v), 0.01)
	_light_sliders["range"] = _slider(box, "Throw m", 1.5, 16.0,
			6.0, func(v): _set_light_value("range", v), 0.1)
	_light_sliders["attenuation"] = _slider(box, "Falloff", 0.8, 3.2,
			2.0, func(v): _set_light_value("attenuation", v), 0.05)
	_light_sliders["temperature"] = _slider(box, "Temp K", 1800, 6500,
			2700, func(v): _set_light_value("temperature", v), 50.0)
	_light_sliders["source_size"] = _slider(box, "Softness", 0.02, 0.50,
			0.12, func(v): _set_light_value("source_size", v), 0.01)
	_light_sliders["shadow_opacity"] = _slider(box, "Shadow", 0.0, 1.0,
			1.0, func(v): _set_light_value("shadow_opacity", v), 0.01)
	_light_sliders["flicker_depth"] = _slider(box, "Flicker", 0.0, 0.30,
			0.02, func(v): _set_light_value("flicker_depth", v), 0.005)
	_light_sliders["flicker_rate"] = _slider(box, "Flicker Hz", 0.10, 4.0,
			1.0, func(v): _set_light_value("flicker_rate", v), 0.05)
	_set_light_controls_enabled(false)
	var export_status := Label.new()
	export_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	export_status.add_theme_font_size_override("font_size", 9)
	_button(box, "Export settings + copy JSON", func():
		var path: String = root.light_rig.export_tuning()
		export_status.text = "Saved: %s\nJSON copied to clipboard" % path)
	box.add_child(export_status)
	var touch := CheckBox.new()
	touch.text = "Touch controls (phone HUD)"
	touch.add_theme_font_size_override("font_size", 10)
	touch.button_pressed = root.touch.enabled if root and root.touch else false
	touch.toggled.connect(func(on):
		if root and root.touch:
			root.touch.set_enabled(on)
			root.player.touch_input = on
			if on:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	box.add_child(touch)


func _set_light_value(parameter: String, value: float) -> void:
	if _updating_light_controls:
		return
	if _selected_fixture and is_instance_valid(_selected_fixture):
		root.light_rig.set_fixture_tuning(_selected_fixture, parameter, value)


func _refresh_light_controls() -> void:
	if _selected_fixture == null or not is_instance_valid(_selected_fixture):
		_set_light_controls_enabled(false)
		return
	var tuning: Dictionary = root.light_rig.fixture_tuning(_selected_fixture)
	_updating_light_controls = true
	for parameter in _light_sliders:
		(_light_sliders[parameter] as HSlider).value = float(tuning[parameter])
	_updating_light_controls = false
	_set_light_controls_enabled(true)


func _on_debug_fixture_selected(fixture: Node) -> void:
	_selected_fixture = fixture
	if fixture == null:
		_light_identity.text = "No light selected"
		_refresh_light_controls()
		return
	var card: Dictionary = root.light_rig.fixture_provenance(fixture)
	_light_identity.text = "%s\n%s\nQuirk: %s" % [
			str(card.get("display", "Selected light")),
			str(card.get("provenance", "Uncatalogued fixture")),
			str(card.get("quirk", "None recorded"))]
	_refresh_light_controls()


func _set_light_controls_enabled(enabled: bool) -> void:
	for slider in _light_sliders.values():
		(slider as HSlider).editable = enabled


## Where the player stands is the only camera that ever finds the real
## problems — a scripted stand frames what I already suspect. The work
## happens in ShotCapture, which lives on the building root so F still
## takes a shot in a launch mode that never built this panel.
func _build_capture() -> void:
	var box := _section("CAPTURE — shots for review", Color(0.85, 0.85, 0.6),
			true)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 9)
	status.modulate = Color(0.7, 0.75, 0.6)
	status.text = "F anywhere, or the button. Panel hides itself first.
" 			+ "Lands in art/renders/insitu with the pose in shots.md."
	_button(box, "Screenshot  (F)", func():
		if root and root.shots:
			root.shots.capture())
	box.add_child(status)
	_shot_status = status
	if root and root.shots:
		root.shots.captured.connect(func(stem, aim):
			status.text = "%s.png · %s" % [stem, aim])


func _build_keys() -> void:
	var box := _section("KEYS", Color(0.7, 0.7, 0.75))
	var hint := Label.new()
	hint.text = "WASD move · Shift run · C crouch · E interact\n" \
			+ "L / left shoulder: lamp · R / right shoulder: radio\n" \
			+ "F screenshot · V noclip · F2 intro · F3 distort · F4 chaos\n" \
			+ "Esc release mouse · wheel scrolls this panel"
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(0.7, 0.7, 0.75)
	box.add_child(hint)


# -------------------------------------------------------------- helpers

func _set_torch_energy(value: float) -> void:
	if root.player and root.player.flashlight:
		root.player.flashlight.light_energy = value


func _button(parent: Node, label_text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _slider(parent: Node, label_text: String, lo: float, hi: float,
		initial: float, on_change: Callable, step := 0.01) -> HSlider:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 58
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size.x = 135
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 48
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 9)
	var decimals := 0 if step >= 1.0 else (3 if step < 0.01 else 2)
	value_label.text = ("%%.%df" % decimals) % initial
	slider.value_changed.connect(func(value):
		value_label.text = ("%%.%df" % decimals) % value)
	row.add_child(value_label)
	parent.add_child(row)
	return slider


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		_body.visible = not _body.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("intro") and root and root.virus_director:
		root.virus_director.toggle_intro()
		get_viewport().set_input_as_handled()


## The wheel, handled here rather than left to the ScrollContainer, because
## the game captures the mouse: with no pointer to hover, the container never
## receives the event and the panel would only scroll after Esc.
func _unhandled_input(event: InputEvent) -> void:
	if not _body.visible or not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_body.scroll_vertical += 48
		get_viewport().set_input_as_handled()
	elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_body.scroll_vertical -= 48
		get_viewport().set_input_as_handled()


## The readout is the one place the hidden values are allowed to surface, and
## only here — nothing in the shipped HUD may read sanity pressure.
func _process(_delta: float) -> void:
	if not _body.visible or root == null or root.player == null:
		return
	# Grow to fit what is open, but never past the window. Recomputed rather
	# than cached because sections collapse and the viewport can resize.
	var ceiling: float = get_viewport().get_visible_rect().size.y - 96.0
	_body.custom_minimum_size.y = clampf(
			_column.get_combined_minimum_size().y, 0.0, maxf(160.0, ceiling))
	var p: Vector3 = root.player.global_position
	var lines: Array[String] = []
	lines.append("pos (%.1f, %.1f, %.1f)  fps %d" % [p.x, p.y, p.z,
			Engine.get_frames_per_second()])
	lines.append("bpm %.0f  infection %.2f  origin %s"
			% [Conductor.bpm, Conductor.infection, Conductor.origin_node])
	var ci = root.call_interface
	if ci:
		var case_def: Dictionary = ci._case
		lines.append("case %s  stage %d  outcome %s" % [
				case_def.get("id", "—"), int(ci.stage),
				ci.outcome if ci.outcome != "" else "—"])
	var director = root.sanity
	if director:
		var s: Dictionary = director.stats()
		lines.append("pressure %.2f  intrusions %d  last %s r%d" % [
				s.pressure, s.intrusions,
				s.last_case if s.last_case != "" else "—", s.last_tier])
		lines.append("held %d  still %.1fs  net recoveries %d" % [
				s.held, s.still_for,
				root.safety_net.recoveries if root.safety_net else 0])
		lines.append("gaze %s %.1fs  unseen %d  witnessed %d" % [
				s.gaze, s.gaze_hold, s.ignored, s.witnessed])
	var evelyn_anim := _evelyn_anim()
	if evelyn_anim:
		lines.append("evelyn clip %s (%d of %d)" % [
				evelyn_anim.current_animation,
				Array(evelyn_anim.get_animation_list()).find(
						evelyn_anim.current_animation) + 1,
				evelyn_anim.get_animation_list().size()])
	var case_id := _selected_case()
	var state: Dictionary = RealityState.case_state(case_id)
	lines.append("%s: %s · repairs %d · recur %d" % [
			PoltergeistLibrary.profile(case_id).get("unit", "?"),
			str(state.get("stage", "unseen")),
			int(state.get("repair_count", 0)),
			int(state.get("recurrence_count", 0))])
	_status.text = "\n".join(lines)


# ---------------------------------------------------------------- cut
#
# Removed rather than carried, with reasons, so nobody re-adds them by
# reflex:
#
# - Mina's seven-button lifecycle and the three "reality rule prototype"
#   rows. Sixteen buttons covering four of eighteen residents. The SUBJECT
#   picker plus one lifecycle row does all eighteen in four buttons, and the
#   insight flags now come from each case's own definition instead of being
#   hard-coded to Mina's two.
# - The separate Mina status line. The status block reports whichever
#   resident is selected, which is the one you are actually looking at.
#
# Nothing else was dropped: the conductor, teleports, distortion, budgets and
# phone HUD all still earn their place, they are just no longer competing for
# the same flat list.
