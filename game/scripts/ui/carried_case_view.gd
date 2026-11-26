extends CanvasLayer
## The dispensary valise held in front of the player, drawn over the live world in
## its own small 3D world (art/blender/carried_case.md). The front folds down on two
## jointed stays into a shelf, and the goods ride on it. Primary click grabs a stack,
## mouse motion carries it, the next
## click sets it down on the stitched squares (RUL-013); right click turns it. The
## world keeps running when opened in play. Building Services can also lend it
## the pointer while paused. Everything built here is freed on close,
## so a closed case costs nothing. Lettering is Label3D.
##
## Papers stand in the linen pocket in the body, above the card (PaperPocket): the
## cursor finds a paper's top edge, a click takes it, upward motion draws it out,
## and drawn far enough it is held up to read. The next click (or ESC on a
## newspaper) lets it go, and it slides back into the pocket.

const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const PlayerOriginals := preload("res://scripts/songbook/player_original_custody.gd")
const TraceVisual := preload("res://scripts/songbook/found_trace_visual.gd")
const TEXTURES := "res://assets/building/textures/"
const MATERIAL_SETS := "res://data/runtime_material_sets.json"
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")
const OPEN_DEGREES := 104.0
const OPEN_SECONDS := 0.45
const CLOSE_SECONDS := 0.3
const LIFT := 0.045
const FLOOR := 0.0
## How far past the shelf's front edge, in cells, a stack counts as taken out.
const OUT_OF_CASE := 0.4
## The stays' pins, in the case's own frame, from the native mechanism check.
const STAY_ROOT := Vector3(0, 0.208, -0.280)
const STAY_SHELF_OPEN := Vector3(0, 0.004, 0.060)
const STAY_LINK := 0.2
const STAY_UPPER_X := 0.286
const STAY_LOWER_X := 0.283
const CARD_CENTRE := Vector3(0, 0.04862055, -0.25761035)
const CARD_NORMAL := Vector3(0, 0.24192190, 0.97029573)
const CARD_LEAN := -0.24434609 # 14 degrees, the body's presentation lean.
const CARD_PIXEL := 0.00036
const CARD_WIDTH := 0.155
const CARD_LINES := 6
## The pocket, in the case's own frame: the centre of its top edge, a centimetre in front of the linen, and the
## body's leaned up direction. Above the pocket the body's top frame hides anything, so the papers stand in front of
## the linen with their tops just under its top edge, leaning on it, where they can be seen and taken.
const POCKET_TOP := Vector3(0, 0.2749, -0.2802)
const POCKET_UP := Vector3(0, 0.97029573, -0.24192190)
## Three containers on the body (Lily, 2026-11-06): the evidence folder on the left holds loose letters; on the
## right the newspaper pocket, with the shorter comics pocket in front of it, so both rows of covers show. Offsets
## are along the body's up direction from POCKET_TOP (negative is down) and toward the reader (depth).
const CONTAINERS := {
	"letter": {"x": -0.135, "width": 0.15, "top": -0.012, "panel": -0.055, "depth": 0.002, "front": 0.010, "w": 0.085, "h": 0.11, "skin": "paper"},
	"news": {"x": 0.085, "width": 0.24, "top": -0.006, "panel": -0.062, "depth": 0.002, "front": 0.012, "w": 0.11, "h": 0.13, "skin": "leather_worn"},
	"comic": {"x": 0.085, "width": 0.22, "top": -0.046, "panel": -0.088, "depth": 0.016, "front": 0.022, "w": 0.075, "h": 0.10, "skin": "leather_worn"},
}
const POCKET_BOTTOM := -0.145
const POCKET_WIDTH := 0.42
const SHEET_HEIGHT := 0.13
## Drawn out, a paper tips forward toward the reader as it rises, instead of up behind the frame.
const SHEET_TIP := 0.6
## The band at a paper's top edge that the hand takes.
const GRIP_BAND := 0.03
const SHEET_STEP := 0.085
## Pixels of upward pointer travel that draw a paper all the way out, and how far
## out it must come to be read.
const DRAW_PIXELS := 220.0
const DRAW_OPENS := 0.85
const DRAW_SETTLE_SECONDS := 0.2
const CURSOR_SPEED := 0.9
const CURSOR_STEP := 0.035
const CURSOR_DEADZONE := 0.22

signal closed

var player: PlayerController
var economy: Node
var fire_stock: Node
var household_state: Node
var item_use: ItemUse
var inventory_holder := PersonInventory.PLAYER
var opened := false
var settled := false
var held_item := ""
var _viewport: SubViewport
var _holder: SubViewportContainer
var _camera: Camera3D
var _forms: Dictionary = {}     # form -> Array of template MeshInstance3D
var _stacks: Dictionary = {}    # item -> Node3D
var _lid: Node3D
var _goods: Node3D
var _hinge := Vector3.ZERO
var _stays: Dictionary = {}     # assembly -> pivot Node3D
var _angle := 0.0
var _tag: Label3D
var _card: Label3D
var _materials: Dictionary = {}
var _song_titles: Dictionary = {}
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _pointer := Vector2.ZERO
var _held_turned := false
var _floor_size := Vector2.ZERO
var _return_washer := false
var _take_in_hand := ""
var _return_vent_insert := ""
## A kitchen tool pushed out of the case: put back at its station, or into the hand.
var _return_kitchen_tool := ""
var _use_after_close := ""
var held_paper := -1
var _papers: Array[Dictionary] = []
var _sheets: Array[Node3D] = []
var _draw := 0.0
var _draw_from_y := 0.0
var _reading: Node = null
var _returning := false
var _pause_access := false
var _pad_motion := Vector2.ZERO
var _pad_cursor: Label
var _pad_legend: Label


func _ready() -> void:
	layer = 40
	set_process(false)


func can_open_from_pause() -> bool:
	return not opened and _available() and not player._grab.active()


func open_from_pause() -> bool:
	if not get_tree().paused or not can_open_from_pause():
		return false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_access = true
	open_case()
	if not opened:
		_pause_access = false
		process_mode = Node.PROCESS_MODE_INHERIT
	return opened


func _unhandled_input(event: InputEvent) -> void:
	if opened or not event.is_action_pressed("carried_case") or not _available():
		return
	open_case()
	get_viewport().set_input_as_handled()


func _available() -> bool:
	return player != null and not player.call_locked and not player.mouse_released \
			and not player.inspecting() \
			and (not player._grab.active() or (is_instance_valid(fire_stock) and fire_stock.can_pack_washer(player)) \
				or (is_instance_valid(household_state) and (household_state.can_pack_book(player) \
					or not household_state.vent_insert_fit(player).is_empty()))) \
			and not is_instance_valid(player.seated_interaction)


func _input(event: InputEvent) -> void:
	if not opened:
		return
	if not settled:
		if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey \
				or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(_reading):
		return  # the paper held up to read takes the input until it goes back
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		_pad_motion[event.axis - JOY_AXIS_LEFT_X] = event.axis_value
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and _pad_button(event):
		get_viewport().set_input_as_handled()
		return
	if held_paper >= 0 and not _returning and _paper_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_hide_pad_cursor()
		_point(event.position)
	elif event is InputEventMouseButton and event.pressed:
		_hide_pad_cursor()
		_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_activate_pointer()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_turn()
	elif event.is_action_pressed("carried_case") or event.is_action_pressed("ui_cancel") \
			or event.is_action_pressed("pause_services"):
		close_case()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_turn()
	else:
		return
	get_viewport().set_input_as_handled()


func _pad_button(event: InputEventJoypadButton) -> bool:
	if event.is_action_pressed("interact"):
		_show_pad_cursor(_pointer)
		if held_paper >= 0:
			if not _returning:
				_let_paper_go()
		else:
			_activate_pointer()
		return true
	if event.is_action_pressed("case_turn"):
		_turn()
		return true
	var step := Vector2(
		float(event.is_action_pressed("ui_right")) - float(event.is_action_pressed("ui_left")),
		float(event.is_action_pressed("ui_down")) - float(event.is_action_pressed("ui_up")))
	if step.is_zero_approx():
		return false
	_move_pad_cursor(step * get_viewport().get_visible_rect().size.y * CURSOR_STEP)
	return true


func _process(delta: float) -> void:
	if not settled or is_instance_valid(_reading) or _pad_motion.length() <= CURSOR_DEADZONE:
		return
	var amount := inverse_lerp(CURSOR_DEADZONE, 1.0, minf(1.0, _pad_motion.length()))
	_move_pad_cursor(_pad_motion.normalized() * amount * delta
			* get_viewport().get_visible_rect().size.y * CURSOR_SPEED)


func _hide_pad_cursor() -> void:
	_pad_motion = Vector2.ZERO
	_pad_cursor.hide()
	_pad_legend.hide()


func _show_pad_cursor(at: Vector2) -> void:
	_pad_cursor.position = at - _pad_cursor.size * 0.5
	_pad_cursor.show()
	_pad_legend.show()


func _move_pad_cursor(relative: Vector2) -> void:
	var at := (_pointer + relative).clamp(Vector2(8, 8),
			get_viewport().get_visible_rect().size - Vector2(8, 8))
	_show_pad_cursor(at)
	if held_paper >= 0:
		_pointer = at
		if not _returning:
			# Pull relative to the hand's progress so the viewport edge cannot stop the sheet.
			_draw_paper(_draw_from_y - _draw * DRAW_PIXELS + relative.y)
	else:
		_point(at)


func _activate_pointer() -> void:
	var paper := _paper_at(_pointer) if held_item == "" and held_paper < 0 else -1
	if paper >= 0:
		_take_paper(paper, _pointer.y)
	else:
		_click()


func open_case(holder: String=PersonInventory.PLAYER) -> void:
	if opened:return
	if holder.is_empty() or not PersonInventory.book().get("holders",{}).has(holder) or (holder!=PersonInventory.PLAYER and player._grab.active()):return
	inventory_holder=holder
	if not _build():
		return
	if player._grab.active():
		var item := ""
		if is_instance_valid(household_state) and household_state.can_pack_book(player):
			var copy: Node3D = player.held_stock_body()
			if household_state.pack_book(player):
				item = CarriedCase.library_item(str(copy.shelf.name), copy.stock_id)
		elif is_instance_valid(fire_stock) and fire_stock.pack_washer(player):
			item = CarriedCase.MAINTENANCE_WASHER
		elif is_instance_valid(household_state):
			item = household_state.pack_vent_insert(player)
		if item.is_empty():
			_discard_view()
			return
		_lay(item, _goods)
	opened = true
	_pointer = get_viewport().get_visible_rect().size * 0.5
	set_process(true)
	player.stow_rolling_hoop()
	_mouse_before = Input.mouse_mode
	player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_angle, 0.0, OPEN_DEGREES, OPEN_SECONDS)
	tween.tween_callback(func(): settled = true)


## A stack in the hand goes back to its saved square: only a click sets one down.
func close_case() -> void:
	if not opened or not settled or is_instance_valid(_reading):
		return
	settled = false
	if held_paper >= 0:
		_draw = 0.0
		_pose_paper(held_paper)
		held_paper = -1
	if held_item != "":
		_held_turned = bool(CarriedCase.place_of(held_item).turned)
		_settle(held_item)
		held_item = ""
	_tag.visible = false
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(set_angle, OPEN_DEGREES, 0.0, CLOSE_SECONDS)
	tween.tween_callback(_finish_close)


func _finish_close() -> void:
	opened = false
	player.call_locked = false
	Input.mouse_mode = _mouse_before
	_discard_view()
	if _pause_access:
		_pause_access = false
		process_mode = Node.PROCESS_MODE_INHERIT
	if _return_washer:
		_return_washer = false
		if is_instance_valid(fire_stock):
			fire_stock.return_case_washer(player)
	if not _take_in_hand.is_empty():
		var item := _take_in_hand
		_take_in_hand = ""
		if is_instance_valid(household_state):
			household_state.set_hand(item)
	if not _return_kitchen_tool.is_empty():
		var tool_item := _return_kitchen_tool
		_return_kitchen_tool = ""
		if is_instance_valid(household_state) and not household_state.deliver_kitchen_tool(player, tool_item):
			household_state.set_hand(tool_item)
	if not _return_vent_insert.is_empty():
		var item := _return_vent_insert
		_return_vent_insert = ""
		if is_instance_valid(household_state):
			household_state.deliver_vent_insert(player, item)
	if not _use_after_close.is_empty():
		var item := _use_after_close
		_use_after_close = ""
		item_use.use(item)
	closed.emit()


func _discard_view() -> void:
	set_process(false)
	_pad_motion = Vector2.ZERO
	_holder.queue_free()
	_forms.clear()
	_stacks.clear()
	_stays.clear()
	_materials.clear()
	_papers.clear()
	_sheets.clear()
	held_paper = -1
	_draw = 0.0
	_returning = false


## Pose the shelf and solve the two-link stays, in the case's own frame.
func set_angle(degrees: float) -> void:
	_angle = clampf(degrees, 0.0, OPEN_DEGREES)
	_lid.rotation = Vector3(deg_to_rad(_angle), 0, 0)
	var shelf_pin := _hinge + Basis(Vector3.RIGHT, deg_to_rad(_angle - OPEN_DEGREES)) * (STAY_SHELF_OPEN - _hinge)
	var span := shelf_pin - STAY_ROOT
	var knee := (STAY_ROOT + shelf_pin) * 0.5 + Vector3(0, -span.z, span.y).normalized() \
			* sqrt(maxf(0.0, STAY_LINK * STAY_LINK - span.length_squared() * 0.25))
	for side: String in ["Port", "Starboard"]:
		var sign_x := -1.0 if side == "Port" else 1.0
		_pose_stay("Stay_%s_Upper" % side, STAY_ROOT, knee, sign_x * STAY_UPPER_X)
		_pose_stay("Stay_%s_Lower" % side, knee, shelf_pin, sign_x * STAY_LOWER_X)


func _pose_stay(assembly: String, from: Vector3, to: Vector3, x: float) -> void:
	var pivot: Node3D = _stays.get(assembly)
	if pivot == null:
		return
	pivot.transform = Transform3D(Basis(Quaternion(Vector3.UP, (to - from).normalized())), Vector3(x, from.y, from.z))


func _build() -> bool:
	var data := CarriedCase.data()
	var scene: PackedScene = load(str(data.get("asset", "")))
	if scene == null:
		return false
	_floor_size = Vector2(CarriedCase.grid()) * float(data.cell)
	_holder = SubViewportContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.stretch = true
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	_holder.add_child(_viewport)
	_pad_cursor = Label.new()
	_pad_cursor.text = "+"
	_pad_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad_cursor.add_theme_font_size_override("font_size", 26)
	_pad_cursor.add_theme_constant_override("outline_size", 4)
	_pad_cursor.add_theme_color_override("font_outline_color", Color.BLACK)
	_pad_cursor.hide()
	_holder.add_child(_pad_cursor)
	_pad_legend = Label.new()
	_pad_legend.text = "STICK MOVE  ·  A PICK UP / PLACE  ·  Y TURN  ·  B BACK"
	_pad_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad_legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_pad_legend.offset_top = -32.0
	_pad_legend.offset_bottom = -8.0
	_pad_legend.add_theme_constant_override("outline_size", 5)
	_pad_legend.add_theme_color_override("font_outline_color", Color.BLACK)
	_pad_legend.hide()
	_holder.add_child(_pad_legend)
	var root := Node3D.new()
	_viewport.add_child(root)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	root.add_child(_camera)
	_camera.look_at_from_position(Vector3(0, 0.68, 0.52), Vector3(0, 0.085, -0.06))
	_camera.current = true
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-62, 18, 0)
	lamp.light_color = Color(1.0, 0.86, 0.68)
	lamp.light_energy = 1.25
	lamp.shadow_enabled = true
	root.add_child(lamp)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.6, 0.66)
	environment.ambient_light_energy = 0.55
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MATERIAL_SETS))
	var material_sets: Dictionary = parsed.materials if parsed is Dictionary else {}
	var asset := scene.instantiate()
	root.add_child(asset)
	_lid = Node3D.new()
	_lid.name = "Lid"
	var hinge: Array = data.hinge
	_hinge = Vector3(float(hinge[0]), float(hinge[1]), float(hinge[2]))
	_lid.position = _hinge
	root.add_child(_lid)
	# Goods keep grid coordinates; this one parent carries them with the shelf.
	_goods = Node3D.new()
	_goods.name = "Goods"
	_goods.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(OPEN_DEGREES)), _hinge).affine_inverse()
	_lid.add_child(_goods)
	# Template Nodes need a lifetime owner even while hidden. Dictionary.clear()
	# releases references, but does not free detached MeshInstance3D nodes.
	var form_library:=Node3D.new()
	form_library.name="FormTemplates"
	form_library.visible=false
	root.add_child(form_library)
	for part: Dictionary in data.parts:
		var draw := asset.find_child(str(part.name), true, false) as MeshInstance3D
		if draw == null:
			continue
		draw.material_override = _material(str(part.key), float(part.tile), material_sets)
		var assembly := str(part.assembly)
		if assembly == "Lid":
			draw.reparent(_lid, false)
			draw.transform = Transform3D.IDENTITY
		elif assembly.begins_with("Stay_"):
			if not _stays.has(assembly):
				var pivot := Node3D.new()
				pivot.name = assembly
				root.add_child(pivot)
				_stays[assembly] = pivot
			draw.reparent(_stays[assembly], false)
			draw.transform = Transform3D.IDENTITY
		elif assembly.begins_with("Form_"):
			var form := assembly.trim_prefix("Form_")
			if not _forms.has(form):
				_forms[form] = []
			draw.reparent(form_library,false)
			_forms[form].append(draw)
	_card = _label(root, CARD_PIXEL, 34)
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.width = CARD_WIDTH / CARD_PIXEL
	# A left-aligned Label3D starts at its node, so the block starts at the left edge.
	_card.position = CARD_CENTRE + CARD_NORMAL * 0.0003 + Vector3.LEFT * CARD_WIDTH * 0.5
	_card.rotation = Vector3(CARD_LEAN, 0, 0)
	_card.modulate = Color(0.1, 0.07, 0.05)
	_card.text = _contents_card()
	_tag = _label(root, 0.0009, 34)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.modulate = Color(0.96, 0.92, 0.8)
	_tag.outline_size = 8
	_tag.outline_modulate = Color(0.05, 0.03, 0.02)
	_tag.visible = false
	if inventory_holder==PersonInventory.PLAYER:
		_fill_pocket(root)
		for item: String in CarriedCase.book().places:
			_lay(item, _goods)
	_fill_personal_objects(_goods)
	set_angle(0.0)
	return true


## Each paper as a sheet in its container, fanned across it front first, the top showing above the container's
## front panel. Hit tests run front to back: comics, then the folder, then newspapers.
func _fill_pocket(root: Node3D) -> void:
	var contents := PaperPocket.contents(get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog)
	_papers.clear()
	for kind: String in ["comic", "letter", "news"]:
		_papers.append_array(contents.filter(func(paper): return paper.kind == kind))
	for kind: String in CONTAINERS:
		_container(root, kind)
	for index in _papers.size():
		var paper: Dictionary = _papers[index]
		var spec: Dictionary = CONTAINERS[paper.kind]
		var group: Array = _papers.filter(func(other): return other.kind == paper.kind)
		var place: int = group.find(paper)
		var count: int = group.size()
		var sheet := Node3D.new()
		root.add_child(sheet)
		var draw := MeshInstance3D.new()
		draw.mesh = _pocket_box(Vector3(float(spec.w), float(spec.h), 0.0015), "paper")
		sheet.add_child(draw)
		_cover(sheet, paper, spec)
		var step := minf(SHEET_STEP, (float(spec.width) - float(spec.w)) / maxf(count - 1, 1))
		var layer := minf(0.0012, (float(spec.front) - float(spec.depth) - 0.002) / maxf(count, 1))
		sheet.set_meta("x", float(spec.x) + (place - (count - 1) * 0.5) * step)
		sheet.set_meta("depth", float(spec.depth) + layer * (count - 1 - place))
		sheet.set_meta("rise", float(spec.top) + 0.004 * (place % 2))
		sheet.set_meta("height", float(spec.h))
		_sheets.append(sheet)
		_pose_paper(index)


## A container's front panel (and the folder's back board and tab), from the case's own finishes.
func _container(root: Node3D, kind: String) -> void:
	var spec: Dictionary = CONTAINERS[kind]
	var boards: Array = [[float(spec.panel), float(spec.front), str(spec.skin)]]
	if kind == "letter":
		boards.append([float(spec.top) - 0.008, float(spec.depth) - 0.0015, "paper"])  # the folder's back board
	for board: Array in boards:
		var panel := MeshInstance3D.new()
		var height := float(board[0]) - POCKET_BOTTOM
		panel.mesh = _pocket_box(Vector3(float(spec.width), height, 0.003), str(board[2]))
		root.add_child(panel)
		panel.transform = Transform3D(Basis(Vector3.RIGHT, CARD_LEAN),
				POCKET_TOP + Vector3(float(spec.x), 0, 0) + POCKET_UP * (float(board[0]) - height * 0.5) + CARD_NORMAL * float(board[1]))
	if kind == "letter":
		var tab := _label(root, 0.0003, 34)
		tab.text = "EVIDENCE"
		tab.modulate = Color(0.12, 0.09, 0.06)
		tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.rotation = Vector3(CARD_LEAN, 0, 0)
		tab.position = POCKET_TOP + Vector3(float(spec.x), 0, 0) + POCKET_UP * (float(spec.panel) - 0.012) + CARD_NORMAL * (float(spec.front) + 0.002)

func _pocket_box(size: Vector3, key: String) -> ArrayMesh:
	var cache_key := "pocket:" + key
	if not _materials.has(cache_key):
		var finish := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		finish.uv1_triplanar = false
		finish.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
		finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials[cache_key] = finish
	var box := BoxMesh.new()
	box.size = size
	box.material = _materials[cache_key]
	return MetreUV.chart(box)


## What shows of a paper above its pocket: a newspaper's masthead, a comic's cover lettering, a letter's heading.
func _cover(sheet: Node3D, paper: Dictionary, spec: Dictionary) -> void:
	var top := float(spec.h) * 0.5
	var head := _label(sheet, 0.00026, 34)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.modulate = Color(0.1, 0.07, 0.05)
	head.position = Vector3(0, top - 0.011, 0.0009)
	head.text = str(paper.title).to_upper().left(16)
	if paper.kind == "comic" and paper.get("strip", false):
		# One of Lily's strips: her name across the top and the strip's day under it.
		head.text = "LILY"
		head.pixel_size = 0.00040
		head.modulate = Color(0.1, 0.07, 0.05)
		head.position = Vector3(0, top - 0.012, 0.0009)
		var day := _label(sheet, 0.00020, 34)
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day.modulate = Color(0.1, 0.07, 0.05)
		day.text = str(paper.get("date", "")).right(5).replace("-", "/")
		day.position = Vector3(0, top - 0.026, 0.0009)
	elif paper.kind == "comic":
		head.text = "LILITH"
		head.pixel_size = 0.00046
		head.modulate = Color(0.55, 0.1, 0.08)
		head.position = Vector3(0, top - 0.012, 0.0009)
		var number := _label(sheet, 0.00024, 34)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.modulate = Color(0.1, 0.07, 0.05)
		number.text = "No. %d" % int(paper.get("number", 0))
		number.position = Vector3(0, top - 0.027, 0.0009)


func _pose_paper(index: int) -> void:
	var sheet := _sheets[index]
	var out := _draw if index == held_paper else 0.0
	var height := float(sheet.get_meta("height"))
	var top := float(sheet.get_meta("rise")) + out * height
	var lean := Basis(Vector3.RIGHT, CARD_LEAN + SHEET_TIP * out)
	sheet.transform = Transform3D(lean,
			POCKET_TOP + Vector3(float(sheet.get_meta("x")), 0, 0) + lean.y * (top - height * 0.5)
			+ CARD_NORMAL * float(sheet.get_meta("depth")))


## Where a paper's showing top edge is on screen, for the hand and for tests.
func paper_grip_point(index: int) -> Vector2:
	var sheet := _sheets[index]
	return _camera.unproject_position(sheet.global_position + sheet.global_basis.y * (float(sheet.get_meta("height")) * 0.5 - GRIP_BAND * 0.5))


## The front-most paper whose showing edge is under the pointer, or -1.
func _paper_at(position: Vector2) -> int:
	for index in _sheets.size():
		var sheet := _sheets[index]
		var draw := sheet.get_child(0) as MeshInstance3D
		var half := draw.mesh.get_aabb().size.x * 0.5
		var right := sheet.global_basis.x
		var up := sheet.global_basis.y
		var top := sheet.global_position + up * float(sheet.get_meta("height")) * 0.5
		var a := _camera.unproject_position(top - right * half)
		var b := _camera.unproject_position(top + right * half)
		var c := _camera.unproject_position(top - up * GRIP_BAND)
		if Rect2(minf(a.x, b.x), minf(a.y, b.y) - 4.0, absf(b.x - a.x), absf(c.y - a.y) + 8.0).has_point(position):
			return index
	return -1


func _take_paper(index: int, pointer_y: float) -> void:
	held_paper = index
	_draw = 0.0
	_draw_from_y = pointer_y
	_tag.text = str(_papers[index].title)
	_tag.position = _sheets[index].global_position + POCKET_UP * 0.1
	_tag.visible = true


## A paper in the hand: upward motion draws it out, a click lets it go back.
func _paper_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if _pad_cursor.visible:
			_draw_from_y = event.position.y + _draw * DRAW_PIXELS
		_hide_pad_cursor()
		_pointer = event.position
		_draw_paper(event.position.y)
		return true
	if event is InputEventMouseButton and event.pressed:
		_let_paper_go()
		return true
	return false


func _draw_paper(pointer_y: float) -> void:
	_draw = clampf((_draw_from_y - pointer_y) / DRAW_PIXELS, 0.0, 1.0)
	_pose_paper(held_paper)
	if _draw >= DRAW_OPENS:
		_read(held_paper)


func _let_paper_go() -> void:
	var index := held_paper
	_tag.visible = false
	if index < 0:
		return
	_returning = true
	var tween := create_tween()
	tween.tween_method(_settle_draw.bind(index), _draw, 0.0, DRAW_SETTLE_SECONDS)
	tween.tween_callback(_paper_home.bind(index))


func _settle_draw(value: float, index: int) -> void:
	if index >= _sheets.size():
		return
	_draw = value
	_pose_paper(index)


func _paper_home(index: int) -> void:
	_returning = false
	if held_paper == index:
		held_paper = -1


func _read(index: int) -> void:
	var paper := _papers[index]
	_hide_pad_cursor()
	_tag.visible = false
	if paper.kind == "news":
		var catalog := get_tree().get_first_node_in_group("newspaper_catalog") as NewspaperCatalog
		var panel := NewspaperPanel.new()
		panel.name = "PocketNewspaper"
		add_child(panel)
		_reading = panel
		panel.open(player, catalog, str(paper.paper), str(paper.date), _read_done)
		panel.layer = layer + 1
	else:
		var sheet := PocketPaperPanel.new()
		sheet.name = "PocketLetter"
		add_child(sheet)
		_reading = sheet
		sheet.open(paper, _read_done)


## Back from reading: the case still holds the pointer, and the paper goes home.
func _read_done() -> void:
	_reading = null
	player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_let_paper_go()


func _material(key: String, tile: float, sets: Dictionary) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var spec: Dictionary = sets.get(key, {})
	var files: Array = spec.get("files", [])
	var result := StandardMaterial3D.new()
	if files.size() == 3:
		result.albedo_texture = load(TEXTURES + str(files[0]))
		result.roughness_texture = load(TEXTURES + str(files[1]))
		result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		result.normal_enabled = true
		result.normal_texture = load(TEXTURES + str(files[2]))
	result.metallic = float(spec.get("metallic", 0.0))
	result.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = result
	return result


func _label(parent: Node3D, pixel: float, size: int) -> Label3D:
	var label := Label3D.new()
	label.font = FONT
	label.font_size = size
	label.pixel_size = pixel
	label.outline_size = 0
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(label)
	return label


## What the lid's card records: the money, the rent and what lies outside the grid.
func _contents_card() -> String:
	if inventory_holder!=PersonInventory.PLAYER:
		var contents := PersonInventory.pocket_lines(inventory_holder)
		contents.append_array(PersonInventory.object_lines(inventory_holder))
		if contents.is_empty():
			contents.append("EMPTY")
		contents.push_front(inventory_holder.replace("_", " ").to_upper())
		return "\n".join(contents.slice(0, CARD_LINES))
	var lines: PackedStringArray = []
	if is_instance_valid(economy):
		lines.append("CASH  %s" % economy.money(int(economy.book().cash)))
		var due: int = economy.rent_cycles_due()
		lines.append("RENT  %s" % ("%d DUE" % due if due > 0 else "PAID"))
	if not PawnSales.book().tickets.is_empty():
		lines.append("PAWN TICKETS: %d" % PawnSales.book().tickets.size())
	if not MailOrders.held().is_empty():
		lines.append("COUPONS TO POST: %d" % MailOrders.held().size())
	if item_use != null and item_use.ears_stopped():
		lines.append("EARS STOPPED")
	for line: String in PersonInventory.pocket_lines():
		if not line.begins_with("POCKET:"):
			lines.append(line)
	lines.append_array(PersonInventory.object_lines(inventory_holder))
	return "\n".join(lines.slice(0, CARD_LINES))


func _centre(place_x: float, place_y: float, size: Vector2i) -> Vector3:
	var cell := float(CarriedCase.data().cell)
	return Vector3(-_floor_size.x * 0.5 + (place_x + size.x * 0.5) * cell, FLOOR,
			-_floor_size.y * 0.5 + (place_y + size.y * 0.5) * cell)


func _lay(item: String, parent: Node3D) -> void:
	var place := CarriedCase.place_of(item)
	var form := str(place.form)
	var stack := Node3D.new()
	stack.name = item.replace(":", "_")
	parent.add_child(stack)
	if item.begins_with(CarriedCase.FOUND_TRACE_PREFIX):
		stack.add_child(TraceVisual.make(item.trim_prefix(CarriedCase.FOUND_TRACE_PREFIX)))
	elif item.begins_with(CarriedCase.RECORDED_TRACE_PREFIX):
		var id := PlayerOriginals.id_from_item(item)
		if PlayerOriginals.is_packed(id):
			stack.add_child(TraceVisual.make_player_original(id))
	elif item == CarriedCase.MAINTENANCE_WASHER and is_instance_valid(fire_stock):
		var draw: MeshInstance3D = fire_stock.stock.draw(stack, "Gasket")
		draw.position.y = -draw.get_aabb().position.y
	elif item.begins_with(CarriedCase.BOOK_PREFIX) and is_instance_valid(household_state):
		var copy: Node3D = household_state.packed_book(item)
		if is_instance_valid(copy):
			copy.draw_in_valise(stack)
	elif item.begins_with(CarriedCase.VENT_INSERT_PREFIX) and is_instance_valid(household_state):
		var row: Dictionary = household_state.packed_vent_insert(item)
		if not row.is_empty():
			var source: MeshInstance3D = row.draw
			var draw := MeshInstance3D.new()
			draw.mesh = source.mesh
			for surface in draw.mesh.get_surface_count():
				draw.set_surface_override_material(surface, source.get_active_material(surface))
			var bounds := draw.get_aabb()
			draw.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
			stack.add_child(draw)
	elif item.begins_with(CarriedCase.KITCHEN_TOOL_PREFIX) and is_instance_valid(household_state):
		var packed: Dictionary = household_state.packed_kitchen_tool(item)
		if not packed.is_empty():
			var draw: Node3D = packed.station.tool_visual(packed.assembly)
			if draw != null:
				draw.transform = Transform3D.IDENTITY
				stack.add_child(draw)
	elif item == "rolling_hoop":
		preload("res://scripts/player/rolling_hoop.gd").draw_in_case(stack)
	else:
		for template: MeshInstance3D in _forms.get(form, []):
			var copy := template.duplicate() as MeshInstance3D
			copy.transform = Transform3D.IDENTITY
			stack.add_child(copy)
	_stacks[item] = stack
	_settle(item)


func _settle(item: String) -> void:
	var place := CarriedCase.place_of(item)
	var stack: Node3D = _stacks[item]
	stack.position = _centre(float(place.x), float(place.y), CarriedCase.form_size(str(place.form), bool(place.turned)))
	stack.rotation.y = PI * 0.5 if bool(place.turned) else 0.0


## The cursor on the lining, in cells. Vector2.INF when it misses the floor plane.
func _on_floor(position: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(position)
	var along := _camera.project_ray_normal(position)
	if absf(along.y) < 0.0001:
		return Vector3.INF
	return origin + along * ((FLOOR - origin.y) / along.y)


func _cell_at(point: Vector3) -> Vector2:
	var cell := float(CarriedCase.data().cell)
	return Vector2((point.x + _floor_size.x * 0.5) / cell, (point.z + _floor_size.y * 0.5) / cell)


func _item_at(cell: Vector2) -> String:
	var places: Dictionary = CarriedCase.book().places
	for item: String in places:
		var place: Dictionary = places[item]
		var size := CarriedCase.form_size(str(place.form), bool(place.turned))
		if Rect2(float(place.x), float(place.y), size.x, size.y).has_point(cell):
			return item
	return ""


func _point(position: Vector2) -> void:
	_pointer = position
	var at := _on_floor(position)
	if at == Vector3.INF:
		return
	if held_item != "":
		var stack: Node3D = _stacks[held_item]
		stack.position = Vector3(at.x, FLOOR + LIFT, at.z)
		if _past_front(at):
			_tag.text = _verb_tag(held_item)
			_tag.position = stack.position + Vector3(0, 0.05, -0.02)
			_tag.visible = true
			return
		var target := _target_cell(at)
		_show_tag(held_item, stack.position, not CarriedCase.fits(held_item, str(CarriedCase.place_of(held_item).form), target.x, target.y, _held_turned))
		return
	var item := _item_at(_cell_at(at))
	if item == "":
		_tag.visible = false
	else:
		_show_tag(item, _stacks[item].position, false)


## Only the shipped arrangements supply titles. A personal take's paper keeps its
## own edition mark, even if the original recording files have gone missing.
func _original_label(id: String) -> String:
	var song := PlayerOriginals.song_id(id)
	if not _song_titles.has(song):
		_song_titles[song] = song.replace("_", " ").to_upper()
		for filename: String in SongResource.catalog():
			var score := SongResource.load_song(filename)
			if score != null:
				_song_titles[score.id] = score.title
	return "%s\nOriginal %s" % [_song_titles[song], id.right(19)]


func _show_tag(item: String, at: Vector3, blocked: bool) -> void:
	var count := 1
	var record: Dictionary
	if item.begins_with(CarriedCase.RECORDED_TRACE_PREFIX):
		record = {"name": _original_label(PlayerOriginals.id_from_item(item))}
	else:
		count = PersonInventory.goods_count(PersonInventory.PLAYER, item)
		record = PersonInventory.items(PersonInventory.PLAYER).get("goods:" + item, {})
	if item == CarriedCase.MAINTENANCE_WASHER:
		count = 1
		record = {"name": "Fire-hose coupling gasket"}
	elif item.begins_with(CarriedCase.FOUND_TRACE_PREFIX):
		count = 1
		var trace: Dictionary = PhonautogramForge.FOUND.get(item.trim_prefix(CarriedCase.FOUND_TRACE_PREFIX), {})
		record = {"name": trace.get("case_label", "Trace")}
	elif item.begins_with(CarriedCase.BOOK_PREFIX) and is_instance_valid(household_state):
		var copy: Node3D = household_state.packed_book(item)
		if is_instance_valid(copy):
			count = 1
			record = {"name": copy.entry.get("title", copy.title_id)}
	elif item.begins_with(CarriedCase.KITCHEN_TOOL_PREFIX) and is_instance_valid(household_state):
		if not household_state.packed_kitchen_tool(item).is_empty():
			count = 1
			record = {"name": kitchen_tool_name(item)}
	elif item.begins_with(CarriedCase.VENT_INSERT_PREFIX) and is_instance_valid(household_state):
		var insert: Dictionary = household_state.packed_vent_insert(item)
		if not insert.is_empty():
			count = 1
			record = {"name": "Radiator vent insert, grade %d" % int(insert.grade)}
	_tag.text = "%s  x%d%s" % [str(record.get("name", item)), count, "\nNO ROOM" if blocked else ""]
	_tag.position = at + Vector3(0, 0.05, -0.02)
	_tag.visible = true


func _target_cell(at: Vector3) -> Vector2i:
	var size := CarriedCase.form_size(str(CarriedCase.place_of(held_item).form), _held_turned)
	var cell := _cell_at(at)
	return Vector2i(roundi(cell.x - size.x * 0.5), roundi(cell.y - size.y * 0.5))


func _click() -> void:
	var at := _on_floor(_pointer)
	if at == Vector3.INF:
		return
	if held_item == "":
		held_item = _item_at(_cell_at(at))
		if held_item != "":
			_held_turned = bool(CarriedCase.place_of(held_item).turned)
			_point(_pointer)
		return
	if _past_front(at):
		if not _pause_access:
			_take_out(held_item)
		return
	var target := _target_cell(at)
	# Set down only where it fits; otherwise the hand keeps it.
	if CarriedCase.move(held_item, target.x, target.y, _held_turned):
		_settle(held_item)
		held_item = ""
		_tag.visible = false


func _past_front(at: Vector3) -> bool:
	return _cell_at(at).y >= CarriedCase.grid().y + OUT_OF_CASE


func _verb_tag(item: String) -> String:
	if _pause_access:
		return "RETURN TO PLAY TO USE"
	if item.begins_with(CarriedCase.VENT_INSERT_PREFIX) and is_instance_valid(household_state):
		var destination: Node3D = household_state.vent_insert_destination(player, item)
		if not is_instance_valid(destination):
			return "AIM AT A COLD, EMPTY VENT OR THE WORKSHOP RACK"
		return "FIT TO VENT" if destination is RadiatorProp else "RETURN TO RACK"
	if item.begins_with(CarriedCase.KITCHEN_TOOL_PREFIX) and is_instance_valid(household_state):
		return "PUT BACK" if is_instance_valid(household_state.kitchen_tool_destination(player, item)) else "TAKE IN HAND"
	if item == CarriedCase.MAINTENANCE_WASHER or item.begins_with(CarriedCase.BOOK_PREFIX) \
			or item.begins_with(CarriedCase.FOUND_TRACE_PREFIX) or item.begins_with(CarriedCase.RECORDED_TRACE_PREFIX):
		return "TAKE IN HAND"
	if item_use == null:
		return "NOTHING TO DO WITH IT"
	if item_use.use_of(item) == "earplugs" and item_use.ears_stopped():
		return "THEY ARE ALREADY IN"
	return item_use.verb_for(item)


## A use spends one. The rest of the stack goes back to its square, and the last one
## leaves the case. Something with no use stays in the hand.
func _take_out(item: String) -> void:
	if item.begins_with(CarriedCase.VENT_INSERT_PREFIX):
		if is_instance_valid(household_state) and is_instance_valid(household_state.vent_insert_destination(player, item)):
			_return_vent_insert = item
			close_case()
		return
	if item.begins_with(CarriedCase.KITCHEN_TOOL_PREFIX):
		_return_kitchen_tool = item
		close_case()
		return
	if item == CarriedCase.MAINTENANCE_WASHER:
		_return_washer = true
		close_case()
		return
	if item.begins_with(CarriedCase.BOOK_PREFIX) or item.begins_with(CarriedCase.FOUND_TRACE_PREFIX) \
			or item.begins_with(CarriedCase.RECORDED_TRACE_PREFIX):
		_take_in_hand = item
		close_case()
		return
	if item_use != null and item_use.use_of(item) == "roll_hoop" and not item_use.can_pledge(item):
		_use_after_close = item
		close_case()
		return
	if item_use == null or not item_use.use(item):
		return
	held_item = ""
	_tag.visible = false
	if PersonInventory.goods_count(PersonInventory.PLAYER, item) > 0:
		_settle(item)
	else:
		_stacks[item].queue_free()
		_stacks.erase(item)
	_card.text = _contents_card()


func _turn() -> void:
	if held_item == "":
		return
	_held_turned = not _held_turned
	_stacks[held_item].rotation.y = PI * 0.5 if _held_turned else 0.0
	_point(_pointer)

## A representative native miniature, not a physical instrument inside the case.
## The person inventory is the authority; closing the view frees these meshes.
func _fill_personal_objects(parent: Node3D) -> void:
	var record: Dictionary=PersonInventory.items(inventory_holder).get(PersonInventory.BASS,{})
	if record.is_empty() or record.location!="inventory":return
	var miniature := preload("res://scripts/props/harukiya_bass_visual.gd").instantiate()
	if miniature == null: return
	miniature.name = "InventoryBassPreview"
	parent.add_child(miniature)
	miniature.scale = Vector3.ONE * .12
	miniature.position=Vector3(.18,.014,.025)
	var caption:=_label(parent,.00028,30)
	caption.name="InventoryBassCaption"
	caption.text="UPRIGHT BASS"
	caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	caption.position=Vector3(.18,.25,.025)
	caption.modulate=Color(.95,.88,.68)


## "Rolling pin, 3B kitchen": the tool and the home it belongs to.
static func kitchen_tool_name(item: String) -> String:
	var parts := CarriedCase.kitchen_tool_parts(item)
	if parts.is_empty():
		return item
	var names := {"Breadboard": "Breadboard", "RollingPin": "Rolling pin", "MixingBowl": "Mixing bowl", "SinkBridge": "Sink board"}
	var station := str(parts[0])
	# Station ids are "KitchenPrep_<unit>".
	return "%s, %s kitchen" % [names.get(parts[1], parts[1]), station.get_slice("_", 1) if "_" in station else station]
