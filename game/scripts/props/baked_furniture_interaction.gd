class_name BakedFurnitureInteraction
extends StaticBody3D
## A lightweight mechanism owner placed over one individually-authored object
## that remains visually baked into its floor glTF.
##
## The generated furniture record owns identity and transform.  This node owns
## only the part that can move, its collision, sound and current condition; it
## never claims the merged floor mesh as mutable state.

const BRASS := Color(0.58, 0.46, 0.25)
const MUSIC_CATALOG_PATH := "res://data/music_catalog.json"
const JUKEBOX_TRACKS := [
	"wishes_in_the_glass",
	"stripes_of_velvet",
	"that_was_selection",
]
## The layout id, not nearby case state, owns the neutral description.  This is
## deliberately a closed table: adding a paper assembly without deciding whose
## working copy it is must fail the I4 proof instead of printing guessed text.
const PAPER_OWNER_COPY := {
	"1A_story_lesson_notes": {"subject": "LESSON NOTES", "authority": "RESIDENT WORKING COPY"},
	"1A_story_classboard": {"subject": "CLASS NOTICES", "authority": "RESIDENT TEACHING BOARD"},
	"1D_story_rota": {"subject": "SHIFT ROTA", "authority": "RESIDENT WORKING COPY"},
	"retail_bod_papers": {"subject": "COUNTER SHEETS", "authority": "BODEGA WORKING COPY"},
	"retail_bar_lit_paper": {"subject": "LOOSE BAR SHEETS", "authority": "HARUKIYA WORKING COPY"},
	"2A_pinboard": {"subject": "WORKING CARDS", "authority": "RESIDENT WORKING BOARD"},
	"2A_papers": {"subject": "WORKING SHEETS", "authority": "RESIDENT COPY WITHHELD"},
	"2B_story_patterns": {"subject": "PATTERN SHEETS", "authority": "RESIDENT WORKING COPY"},
	"2B_story_pattern_board": {"subject": "PATTERN BOARD", "authority": "RESIDENT WORKING BOARD"},
	"3D_lyrics": {"subject": "LYRIC SHEETS", "authority": "RESIDENT WORKING COPY"},
	"4A_story_briefs": {"subject": "BRIEF SHEETS", "authority": "RESIDENT WORKING COPY"},
	"4A_story_deadlines": {"subject": "DEADLINE CARDS", "authority": "RESIDENT WORKING BOARD"},
	"4C_story_drawings": {"subject": "DRAWING SHEETS", "authority": "HOUSEHOLD WORKING COPY"},
	"4C_story_familyboard": {"subject": "HOUSEHOLD CARDS", "authority": "HOUSEHOLD WORKING BOARD"},
	"5A_pins1": {"subject": "TENANT NOTICES", "authority": "RESIDENT WORKING BOARD"},
	"5A_pins2": {"subject": "TENANT NOTES", "authority": "RESIDENT WORKING BOARD"},
	"5A_papers1": {"subject": "TENANT SHEETS", "authority": "RESIDENT WORKING COPY"},
	"5A_papers2": {"subject": "REVISION SHEETS", "authority": "RESIDENT WORKING COPY"},
	"5C_story_studies": {"subject": "COLOUR STUDIES", "authority": "RESIDENT WORKING COPY"},
	"5C_story_colorboard": {"subject": "COLOUR CARDS", "authority": "RESIDENT WORKING BOARD"},
	"6A_detail_capture_papers": {"subject": "CONTACT SHEETS", "authority": "RESIDENT WORKING COPY"},
	"6B_story_draft": {"subject": "DRAFT SHEETS", "authority": "RESIDENT WORKING COPY"},
}

var furniture_kind := ""
var record_id := ""
var owner_unit := ""
var _record_width := 1.3
var _record_height := 0.6
var _record_count := 0
var _case_wood := "wood_dark"
var _refilling := false
var _lever: Node3D
var _water: AudioStreamPlayer3D
var _flush_tween: Tween
var _busy_tween: Tween
var _powered := false
var _radio_knob: Node3D
var _radio_bed: AudioStreamPlayer3D
var _control_click: AudioStreamPlayer3D
var _control_tween: Tween
var _wardrobe_left_leaf: Node3D
var _wardrobe_right_leaf: Node3D
var _wardrobe_rattle: AudioStreamPlayer3D
var _wardrobe_tween: Tween
var _wardrobe_open := false
var _jukebox_selection := 0
var _jukebox_title := "NO SELECTION"
var _jukebox_coin_state := "EMPTY"
var _jukebox_catalog: Dictionary = {}
var _jukebox_player: AudioStreamPlayer3D
var _jukebox_selector: Node3D
var _jukebox_coin_return: Node3D
var _jukebox_sign_material: StandardMaterial3D
var _jukebox_selector_tween: Tween
var _jukebox_coin_tween: Tween
var _paper_profile: Dictionary = {}
var _paper_touch: Node3D
var _paper_touch_home := Vector3.ZERO
var _paper_tap: AudioStreamPlayer3D
var _paper_tween: Tween


func setup(spec: Dictionary) -> void:
	furniture_kind = str(spec.get("asm", ""))
	record_id = str(spec.get("id", furniture_kind))
	owner_unit = record_id.get_slice("_", 0)
	_record_width = float(spec.get("W", 1.3))
	_record_height = float(spec.get("H", 0.6))
	_record_count = int(spec.get("cards", 12)) if furniture_kind == "pinboard" \
			else int(spec.get("n", 6))
	_case_wood = str(spec.get("case_wood", "wood_dark"))
	if furniture_kind == "papers" or furniture_kind == "pinboard":
		_paper_profile = (PAPER_OWNER_COPY.get(record_id, {}) as Dictionary).duplicate()
		if _paper_profile.is_empty():
			push_error("Paper interaction lacks authored owner copy: %s" % record_id)
	name = "Service_%s" % record_id
	add_to_group("baked_furniture_interactions")
	set_meta("furniture_record_id", record_id)
	set_meta("furniture_kind", furniture_kind)


func _ready() -> void:
	match furniture_kind:
		"toilet": _build_toilet_control()
		"radio": _build_radio_control()
		"wardrobe": _build_wardrobe_control()
		"jukebox": _build_jukebox_control()
		"papers", "pinboard": _build_paper_control()
		_: push_error("No baked furniture interaction for %s" % furniture_kind)


func _build_paper_control() -> void:
	if _paper_profile.is_empty():
		return
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	if furniture_kind == "papers":
		var stack_top := maxf(0.005, float(maxi(0, _record_count - 1)) * 0.0075 + 0.005)
		shape.size = Vector3(0.38, maxf(0.10, stack_top + 0.05), 0.42)
		collision.position = Vector3(0.0, shape.size.y * 0.5, 0.0)
	else:
		shape.size = Vector3(_record_width + 0.08, _record_height + 0.08, 0.10)
		collision.position = Vector3(0.0, _record_height * 0.5, -0.018)
	collision.shape = shape
	add_child(collision)

	# The stack/board remains part of the floor buffer.  A single paper corner
	# or tack head supplies visible hand acknowledgement without child targets
	# over every sheet.
	_paper_touch = Node3D.new()
	_paper_touch.name = "PaperCorner" if furniture_kind == "papers" else "BoardTack"
	add_child(_paper_touch)
	var mesh_node := MeshInstance3D.new()
	if furniture_kind == "papers":
		var paper_mesh := BoxMesh.new()
		paper_mesh.size = Vector3(0.11, 0.004, 0.14)
		mesh_node.mesh = paper_mesh
		_paper_touch.position = Vector3(0.045,
				maxf(0.007, float(maxi(0, _record_count - 1)) * 0.0075 + 0.008),
				-0.065)
		mesh_node.material_override = MatLib.get_mat("paper",
				Color(0.80, 0.76, 0.64), 0.82)
	else:
		var tack_mesh := CylinderMesh.new()
		tack_mesh.top_radius = 0.011
		tack_mesh.bottom_radius = 0.011
		tack_mesh.height = 0.012
		tack_mesh.radial_segments = 10
		mesh_node.mesh = tack_mesh
		mesh_node.rotation_degrees.x = 90.0
		_paper_touch.position = Vector3(-_record_width * 0.30,
				_record_height * 0.72, -0.038)
		mesh_node.material_override = MatLib.get_mat("brass_dull",
				Color(0.58, 0.46, 0.25), 0.46)
	_paper_touch.add_child(mesh_node)
	_paper_touch_home = _paper_touch.position

	_paper_tap = AudioStreamPlayer3D.new()
	_paper_tap.name = "PaperHandlingTick"
	_paper_tap.stream = PropAudio.get_stream("tick")
	_paper_tap.volume_db = -24.0
	_paper_tap.unit_size = 1.0
	_paper_tap.max_distance = 5.0
	add_child(_paper_tap)


func _build_toilet_control() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.54, 0.84, 0.76)
	collision.shape = shape
	collision.position = Vector3(0, 0.42, -0.02)
	add_child(collision)

	# The porcelain is in the floor buffer.  This small side lever is the only
	# overlay geometry and sits clear of the close-coupled tank's right cheek.
	_lever = Node3D.new()
	_lever.name = "CisternHandle"
	_lever.position = Vector3(0.18, 0.64, 0.12)
	add_child(_lever)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 0.022, 0.026)
	mesh_node.mesh = mesh
	mesh_node.position.x = -0.035
	var material := StandardMaterial3D.new()
	material.albedo_color = BRASS
	material.metallic = 0.72
	material.roughness = 0.34
	mesh_node.material_override = material
	_lever.add_child(mesh_node)

	_water = AudioStreamPlayer3D.new()
	_water.name = "CisternWater"
	_water.stream = PropAudio.get_stream("sink_water")
	_water.volume_db = -14.0
	_water.unit_size = 1.4
	_water.max_distance = 8.0
	add_child(_water)


func _build_radio_control() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.48, 0.34, 0.34)
	collision.shape = shape
	collision.position = Vector3(0, 0.14, -0.02)
	add_child(collision)

	# One knob sits a few millimetres proud of the baked right-hand control.
	# The cabinet, dial strip and grille remain in the floor buffer.
	_radio_knob = Node3D.new()
	_radio_knob.name = "PowerTuningKnob"
	_radio_knob.position = Vector3(0.14, 0.062, -0.139)
	add_child(_radio_knob)
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.017
	mesh.bottom_radius = 0.017
	mesh.height = 0.026
	mesh.radial_segments = 10
	mesh_node.mesh = mesh
	mesh_node.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.065, 0.052)
	material.roughness = 0.43
	mesh_node.material_override = material
	_radio_knob.add_child(mesh_node)

	_control_click = AudioStreamPlayer3D.new()
	_control_click.name = "RadioSwitchClick"
	_control_click.stream = PropAudio.get_stream("tick")
	_control_click.volume_db = -20.0
	_control_click.unit_size = 1.2
	_control_click.max_distance = 6.0
	add_child(_control_click)
	_radio_bed = AudioStreamPlayer3D.new()
	_radio_bed.name = "ValveProgramme"
	_radio_bed.stream = PropAudio.get_stream("murmur_loop")
	_radio_bed.volume_db = -28.0
	_radio_bed.unit_size = 1.4
	_radio_bed.max_distance = 7.0
	add_child(_radio_bed)


func _build_wardrobe_control() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_record_width + 0.12, 2.02, 0.74)
	collision.shape = shape
	collision.position = Vector3(0, 0.98, 0)
	add_child(collision)

	_wardrobe_left_leaf = _build_wardrobe_leaf(-1.0)
	_wardrobe_right_leaf = _build_wardrobe_leaf(1.0)

	_wardrobe_rattle = AudioStreamPlayer3D.new()
	_wardrobe_rattle.name = "PrivateLeafRattle"
	_wardrobe_rattle.stream = PropAudio.get_stream("creak")
	_wardrobe_rattle.volume_db = -19.0
	_wardrobe_rattle.unit_size = 1.4
	_wardrobe_rattle.max_distance = 7.0
	add_child(_wardrobe_rattle)


func _build_wardrobe_leaf(side: float) -> Node3D:
	var leaf_width := _record_width * 0.5 - 0.047
	var hinge_x := side * (_record_width * 0.5 - 0.035)
	var pivot := Node3D.new()
	pivot.name = "LeftLeaf" if side < 0.0 else "RightLeaf"
	pivot.position = Vector3(hinge_x, 0.10, -0.305)
	add_child(pivot)
	var centre_x := leaf_width * 0.5 * -side
	var leaf := MeshInstance3D.new()
	leaf.name = "FramedLeaf"
	var leaf_box := BoxMesh.new()
	leaf_box.size = Vector3(leaf_width, 1.72, 0.025)
	leaf.mesh = leaf_box
	leaf.position = Vector3(centre_x, 0.86, 0.0)
	leaf.material_override = MatLib.get_mat(_case_wood, Color(0.82, 0.76, 0.68),
			0.82)
	pivot.add_child(leaf)
	var panel := MeshInstance3D.new()
	panel.name = "RaisedPanel"
	var panel_box := BoxMesh.new()
	panel_box.size = Vector3(leaf_width - 0.10, 1.46, 0.014)
	panel.mesh = panel_box
	panel.position = Vector3(centre_x, 0.85, -0.019)
	# A floor-board texture on this tall face produced a hard horizontal phase
	# break. Raised panels are the same suite timber, merely darker and tighter.
	panel.material_override = MatLib.get_mat(_case_wood,
			Color(0.62, 0.56, 0.48), 0.62)
	pivot.add_child(panel)
	var knob := MeshInstance3D.new()
	knob.name = "BrassKnob"
	var knob_mesh := CylinderMesh.new()
	knob_mesh.top_radius = 0.012
	knob_mesh.bottom_radius = 0.016
	knob_mesh.height = 0.05
	knob_mesh.radial_segments = 8
	knob.mesh = knob_mesh
	knob.rotation_degrees.x = 90.0
	knob.position = Vector3((0.075 - hinge_x) if side > 0.0 \
			else (-0.075 - hinge_x), 0.845, -0.04)
	knob.material_override = MatLib.get_mat("brass_dull",
			Color(0.72, 0.61, 0.38), 0.42)
	pivot.add_child(knob)
	return pivot


func _build_jukebox_control() -> void:
	# The cabinet and its original ranks of Bakelite buttons remain in the floor
	# buffer. These two small proud controls give the selection bank and coin
	# return distinct ray ownership without redrawing the hero furniture.
	_make_jukebox_area("selector", Vector3(0.0, 0.79, 0.36),
			Vector3(0.76, 0.18, 0.13))
	_make_jukebox_area("coin_return", Vector3(0.31, 0.58, 0.36),
			Vector3(0.17, 0.14, 0.13))

	_jukebox_selector = Node3D.new()
	_jukebox_selector.name = "SelectionButton"
	_jukebox_selector.position = Vector3(-0.315, 0.80, 0.337)
	add_child(_jukebox_selector)
	var selector_mesh := MeshInstance3D.new()
	var selector_box := BoxMesh.new()
	selector_box.size = Vector3(0.06, 0.045, 0.035)
	selector_mesh.mesh = selector_box
	var selector_material := StandardMaterial3D.new()
	selector_material.albedo_color = Color(0.24, 0.055, 0.038)
	selector_material.roughness = 0.4
	selector_mesh.material_override = selector_material
	_jukebox_selector.add_child(selector_mesh)

	_jukebox_coin_return = Node3D.new()
	_jukebox_coin_return.name = "CoinReturn"
	_jukebox_coin_return.position = Vector3(0.31, 0.58, 0.337)
	add_child(_jukebox_coin_return)
	var return_mesh := MeshInstance3D.new()
	var return_box := BoxMesh.new()
	return_box.size = Vector3(0.10, 0.04, 0.04)
	return_mesh.mesh = return_box
	var return_material := StandardMaterial3D.new()
	return_material.albedo_color = Color(0.07, 0.06, 0.05)
	return_material.metallic = 0.45
	return_material.roughness = 0.34
	return_mesh.material_override = return_material
	_jukebox_coin_return.add_child(return_mesh)

	var sign := MeshInstance3D.new()
	sign.name = "LiveSelectionGlass"
	sign.position = Vector3(0.0, 1.16, 0.337)
	var sign_box := BoxMesh.new()
	sign_box.size = Vector3(0.80, 0.18, 0.014)
	sign.mesh = sign_box
	_jukebox_sign_material = StandardMaterial3D.new()
	_jukebox_sign_material.albedo_color = Color(0.20, 0.13, 0.08)
	_jukebox_sign_material.emission_enabled = false
	_jukebox_sign_material.emission = Color(1.0, 0.43, 0.12)
	_jukebox_sign_material.emission_energy_multiplier = 1.7
	sign.material_override = _jukebox_sign_material
	add_child(sign)

	_control_click = AudioStreamPlayer3D.new()
	_control_click.name = "SelectorMechanism"
	_control_click.stream = PropAudio.get_stream("tick")
	_control_click.volume_db = -13.0
	_control_click.unit_size = 1.5
	_control_click.max_distance = 8.0
	add_child(_control_click)
	_jukebox_player = AudioStreamPlayer3D.new()
	_jukebox_player.name = "LocalRecordPickup"
	_jukebox_player.volume_db = -13.0
	_jukebox_player.unit_size = 3.0
	_jukebox_player.max_distance = 20.0
	_jukebox_player.attenuation_model = \
			AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_jukebox_player)
	_jukebox_player.finished.connect(_on_jukebox_finished)
	_load_jukebox_catalog()
	_refresh_jukebox_title()


func _make_jukebox_area(control_id: String, at: Vector3,
		size: Vector3) -> PropControlArea:
	var area := PropControlArea.new()
	area.name = "%sReach" % control_id.to_pascal_case()
	area.configure(control_id)
	area.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	return area


func _load_jukebox_catalog() -> void:
	var file := FileAccess.open(MUSIC_CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_warning("Jukebox music catalog missing")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_jukebox_catalog = parsed.get("tracks", {})


func _refresh_jukebox_title() -> void:
	var track_id: String = JUKEBOX_TRACKS[_jukebox_selection]
	var track: Dictionary = _jukebox_catalog.get(track_id, {})
	_jukebox_title = str(track.get("title", track_id)).to_upper()


func interact_prompt() -> String:
	if furniture_kind == "toilet":
		return "[E] Test refilling cistern handle" if _refilling \
				else "[E] Flush water closet"
	if furniture_kind == "radio":
		return "[E] Switch valve radio off" if _powered \
				else "[E] Switch valve radio on"
	if furniture_kind == "wardrobe":
		return "[E] Close private wardrobe" if _wardrobe_open \
				else "[E] Open private wardrobe"
	if furniture_kind == "jukebox":
		return control_prompt("selector")
	if furniture_kind == "papers":
		return "[E] Inspect working papers"
	if furniture_kind == "pinboard":
		return "[E] Inspect pin board"
	return ""


func interact(_player: Node = null) -> Dictionary:
	if furniture_kind == "radio":
		return _interact_radio()
	if furniture_kind == "wardrobe":
		return _interact_wardrobe()
	if furniture_kind == "jukebox":
		return interact_control("selector", _player)
	if furniture_kind == "papers" or furniture_kind == "pinboard":
		return _inspect_paperwork()
	if furniture_kind != "toilet": return {}
	if _refilling:
		# The handle still gives under an impatient second hand, but the stored
		# water and refill clock are not restarted.
		if _busy_tween and _busy_tween.is_valid():
			_busy_tween.kill()
		_lever.position.x = 0.18
		_busy_tween = create_tween()
		_busy_tween.tween_property(_lever, "position:x", 0.168, 0.05)
		_busy_tween.tween_property(_lever, "position:x", 0.18, 0.10)
		return service_wire_card()

	_refilling = true
	_water.pitch_scale = randf_range(0.96, 1.03)
	_water.play()
	if _flush_tween and _flush_tween.is_valid():
		_flush_tween.kill()
	_flush_tween = create_tween()
	_flush_tween.tween_property(_lever, "rotation:z", deg_to_rad(-34.0), 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flush_tween.tween_property(_lever, "rotation:z", 0.0, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flush_tween.tween_interval(2.1)
	_flush_tween.tween_callback(_finish_refill)
	return service_wire_card()


func _inspect_paperwork() -> Dictionary:
	if _paper_profile.is_empty() or _paper_touch == null:
		return {}
	_paper_tap.pitch_scale = randf_range(0.96, 1.04)
	_paper_tap.play()
	if _paper_tween and _paper_tween.is_valid():
		_paper_tween.kill()
	_paper_touch.position = _paper_touch_home
	_paper_touch.rotation = Vector3.ZERO
	_paper_tween = create_tween()
	if furniture_kind == "papers":
		_paper_tween.set_parallel(true)
		_paper_tween.tween_property(_paper_touch, "position:y",
				_paper_touch_home.y + 0.014, 0.08) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_paper_tween.tween_property(_paper_touch, "rotation:x",
				deg_to_rad(-7.0), 0.08) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_paper_tween.chain().tween_property(_paper_touch, "position:y",
				_paper_touch_home.y, 0.16) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_paper_tween.parallel().tween_property(_paper_touch, "rotation:x",
				0.0, 0.16) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_paper_tween.tween_property(_paper_touch, "position:z",
				_paper_touch_home.z + 0.010, 0.06) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_paper_tween.tween_property(_paper_touch, "position:z",
				_paper_touch_home.z, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return service_wire_card()


func _interact_radio() -> Dictionary:
	_powered = not _powered
	_control_click.pitch_scale = 1.05 if _powered else 0.94
	_control_click.play()
	if _powered:
		_radio_bed.play()
	else:
		_radio_bed.stop()
	if _control_tween and _control_tween.is_valid():
		_control_tween.kill()
	_control_tween = create_tween()
	_control_tween.tween_property(_radio_knob, "rotation:z",
			deg_to_rad(42.0 if _powered else 0.0), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return service_wire_card()


func _interact_wardrobe() -> Dictionary:
	_wardrobe_open = not _wardrobe_open
	_wardrobe_rattle.pitch_scale = randf_range(0.94, 1.04)
	_wardrobe_rattle.play()
	if _wardrobe_tween and _wardrobe_tween.is_valid():
		_wardrobe_tween.kill()
	_wardrobe_tween = create_tween()
	_wardrobe_tween.set_parallel(true)
	_wardrobe_tween.tween_property(_wardrobe_left_leaf, "rotation:y",
			deg_to_rad(92.0) if _wardrobe_open else 0.0, 0.46) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_wardrobe_tween.tween_property(_wardrobe_right_leaf, "rotation:y",
			deg_to_rad(-92.0) if _wardrobe_open else 0.0, 0.46) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return service_wire_card()


func control_prompt(control_id: String) -> String:
	if furniture_kind != "jukebox":
		return ""
	if control_id == "selector":
		return "[E] Press next jukebox selection" if _jukebox_player.playing \
				else "[E] Press jukebox selection"
	if control_id == "coin_return":
		return "[E] Pull jukebox coin return" if _jukebox_coin_state == "HELD" \
				else "[E] Test empty jukebox coin return"
	return ""


func interact_control(control_id: String, _player: Node = null) -> Dictionary:
	if furniture_kind != "jukebox":
		return {}
	if control_id == "selector":
		return _press_jukebox_selection()
	if control_id == "coin_return":
		return _pull_jukebox_coin_return()
	return {}


func _press_jukebox_selection() -> Dictionary:
	if _jukebox_player.playing:
		_jukebox_selection = (_jukebox_selection + 1) % JUKEBOX_TRACKS.size()
		_refresh_jukebox_title()
	var track_id: String = JUKEBOX_TRACKS[_jukebox_selection]
	var track: Dictionary = _jukebox_catalog.get(track_id, {})
	var stream := load(str(track.get("path", ""))) as AudioStream
	if stream == null:
		push_warning("Jukebox selection missing: %s" % track_id)
		return service_wire_card()
	_jukebox_player.stream = stream
	_jukebox_player.play()
	_jukebox_coin_state = "HELD"
	_jukebox_sign_material.emission_enabled = true
	_control_click.pitch_scale = 1.08
	_control_click.play()
	if _jukebox_selector_tween and _jukebox_selector_tween.is_valid():
		_jukebox_selector_tween.kill()
	_jukebox_selector.position.z = 0.337
	_jukebox_selector_tween = create_tween()
	_jukebox_selector_tween.tween_property(
			_jukebox_selector, "position:z", 0.319, 0.06)
	_jukebox_selector_tween.tween_property(
			_jukebox_selector, "position:z", 0.337, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return service_wire_card()


func _pull_jukebox_coin_return() -> Dictionary:
	var had_coin := _jukebox_coin_state == "HELD"
	if had_coin:
		_jukebox_player.stop()
		_jukebox_coin_state = "RETURNED"
		_jukebox_sign_material.emission_enabled = false
	_control_click.pitch_scale = 0.88 if had_coin else 0.76
	_control_click.play()
	if _jukebox_coin_tween and _jukebox_coin_tween.is_valid():
		_jukebox_coin_tween.kill()
	_jukebox_coin_return.position.z = 0.337
	_jukebox_coin_tween = create_tween()
	_jukebox_coin_tween.tween_property(
			_jukebox_coin_return, "position:z", 0.30, 0.08)
	_jukebox_coin_tween.tween_property(
			_jukebox_coin_return, "position:z", 0.337, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return service_wire_card()


func _on_jukebox_finished() -> void:
	_jukebox_coin_state = "SPENT"
	if _jukebox_sign_material:
		_jukebox_sign_material.emission_enabled = false


func service_wire_card() -> Dictionary:
	if furniture_kind == "papers":
		if _paper_profile.is_empty():
			return {}
		return PropServiceWire.card("papers", {
			"paper_state": "%d SHEETS / %s" % [
					_record_count, str(_paper_profile.get("subject", ""))],
			"owner_condition": str(_paper_profile.get("authority", "")),
		})
	if furniture_kind == "pinboard":
		if _paper_profile.is_empty():
			return {}
		var notice_count := "EMPTY" if _record_count == 0 \
				else "%d PINNED" % _record_count
		return PropServiceWire.card("pinboard", {
			"notice_state": "%s / %s" % [notice_count,
					str(_paper_profile.get("subject", ""))],
			"owner_condition": str(_paper_profile.get("authority", "")),
		})
	if furniture_kind == "radio":
		return PropServiceWire.card("radio", {
			"power_state": "ON" if _powered else "OFF",
			"tuning_state": "MID-BAND",
			"programme_state": "DISTANT SPEECH" if _powered else "SILENT",
		})
	if furniture_kind == "wardrobe":
		return PropServiceWire.card("wardrobe", {
			"leaf_state": "OPEN" if _wardrobe_open else "CLOSED",
			"owner_state": "%s RESIDENT / PRIVATE" % owner_unit,
		})
	if furniture_kind == "jukebox":
		return PropServiceWire.card("jukebox", {
			"coin_state": _jukebox_coin_state,
			"selection_state": _jukebox_title,
			"motor_state": "TURNING / LOCAL PICKUP" \
					if _jukebox_player.playing else "STOPPED",
		})
	if furniture_kind != "toilet": return {}
	return PropServiceWire.card("toilet", {
		"cistern_state": "REFILLING" if _refilling else "FULL",
		"flush_state": "RUNNING" if _refilling else "READY",
	})


func _finish_refill() -> void:
	_refilling = false
