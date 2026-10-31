extends CanvasLayer
## The dispensary valise held in front of the player, drawn over the live world in
## its own small 3D world (art/blender/carried_case.md). The front folds down on two
## jointed stays into a shelf, and the goods ride on it. Primary click grabs a stack,
## mouse motion carries it, the next
## click sets it down on the stitched squares (RUL-013); right click turns it. The
## world keeps running while it is open. Everything built here is freed on close,
## so a closed case costs nothing. Lettering is Label3D.

const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const TEXTURES := "res://assets/building/textures/"
const MATERIAL_SETS := "res://data/runtime_material_sets.json"
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

var player: PlayerController
var economy: Node
var item_use: ItemUse
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
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _pointer := Vector2.ZERO
var _held_turned := false
var _floor_size := Vector2.ZERO


func _ready() -> void:
	layer = 40


func _unhandled_input(event: InputEvent) -> void:
	if opened or not event.is_action_pressed("carried_case") or not _available():
		return
	open_case()
	get_viewport().set_input_as_handled()


func _available() -> bool:
	return player != null and not player.call_locked and not player.mouse_released \
			and not player.inspecting() and not player._grab.active() \
			and not is_instance_valid(player.seated_interaction)


func _input(event: InputEvent) -> void:
	if not opened:
		return
	if not settled:
		if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_point(event.position)
	elif event is InputEventMouseButton and event.pressed:
		_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_turn()
	elif event.is_action_pressed("carried_case") or event.is_action_pressed("ui_cancel"):
		close_case()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_turn()
	else:
		return
	get_viewport().set_input_as_handled()


func open_case() -> void:
	if opened or not _build():
		return
	opened = true
	_mouse_before = Input.mouse_mode
	player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_angle, 0.0, OPEN_DEGREES, OPEN_SECONDS)
	tween.tween_callback(func(): settled = true)


## A stack in the hand goes back to its saved square: only a click sets one down.
func close_case() -> void:
	if not opened or not settled:
		return
	settled = false
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
	_holder.queue_free()
	_forms.clear()
	_stacks.clear()
	_stays.clear()
	_materials.clear()


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
	for item: String in CarriedCase.book().places:
		_lay(item, _goods)
	set_angle(0.0)
	return true


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
	var lines: PackedStringArray = []
	if is_instance_valid(economy):
		lines.append("CASH  %s" % economy.money(int(economy.book().cash)))
		var due: int = economy.rent_cycles_due()
		lines.append("RENT  %s" % ("%d DUE" % due if due > 0 else "PAID"))
	if item_use != null and item_use.ears_stopped():
		lines.append("EARS STOPPED")
	for line: String in PersonInventory.pocket_lines():
		if not line.begins_with("POCKET:"):
			lines.append(line)
	return "\n".join(lines.slice(0, CARD_LINES))


func _centre(place_x: float, place_y: float, size: Vector2i) -> Vector3:
	var cell := float(CarriedCase.data().cell)
	return Vector3(-_floor_size.x * 0.5 + (place_x + size.x * 0.5) * cell, FLOOR,
			-_floor_size.y * 0.5 + (place_y + size.y * 0.5) * cell)


func _lay(item: String, parent: Node3D) -> void:
	var place := CarriedCase.place_of(item)
	var form := str(place.form)
	var stack := Node3D.new()
	stack.name = item
	parent.add_child(stack)
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


func _show_tag(item: String, at: Vector3, blocked: bool) -> void:
	var count := PersonInventory.goods_count(PersonInventory.PLAYER, item)
	var record: Dictionary = PersonInventory.items(PersonInventory.PLAYER).get("goods:" + item, {})
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
	if item_use == null:
		return "NOTHING TO DO WITH IT"
	if item_use.use_of(item) == "earplugs" and item_use.ears_stopped():
		return "THEY ARE ALREADY IN"
	return item_use.verb_for(item)


## A use spends one. The rest of the stack goes back to its square, and the last one
## leaves the case. Something with no use stays in the hand.
func _take_out(item: String) -> void:
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
