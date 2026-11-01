extends Node3D
## The Luncheonette's counter service. An order comes up as a cup or a plate on the
## counter; the player's hand lifts it, and what is at the top of the lift goes down.
## While anything is left, whoever the timetable has sat at the counter talks. Those
## lines are the resident's dated opinions, overheard: nothing is granted but the
## note that it was heard, so the same opinion still waits at their door.
## Money stays with the sale point, attendance with the resident's whereabouts.

const KEY := "luncheonette_served"
const OVERHEARD_PREFIX := "overheard:"
const STOCK := {"cup": "4B_mug", "plate": "1A_k_plate"}
const SERVED := {"coffee": ["cup"], "soda_from_the_carbonator": ["cup"], "slice_of_pie": ["plate"],
		"coffee_and_pie": ["cup", "plate"], "egg_sandwich": ["plate"], "blue_plate": ["plate"],
		"the_melancholy_special": ["plate"]}
## Seconds of holding each one at the top of the lift before it is gone.
const PORTION := {"cup": 6.0, "plate": 9.0}
const LIFT := 0.42
const AT_MOUTH := 0.9
## Tipped toward the player at the top of the lift, in front of the camera.
const TILT := {"cup": 0.75, "plate": 0.2}
const MOUTH := Vector3(0.0, -0.1, -0.26)
const LIFT_PIXELS := 220.0
const SETTLE_SPEED := 1.4
const POLL_SECONDS := 5.0
const FIRST_LINE_SECONDS := 4.0
const LINE_GAP_SECONDS := 1.5
const CHARACTERS_PER_SECOND := 18.0
## Source metres: the room, and each stool. The seated clip's hips sit this far
## above its own origin, so the origin is set that far below the stool's top.
const ROOM := Rect2(17.0, -44.3, 7.0, 5.0)
const STOOL_X := 18.36
const STOOL_TOP := 0.82
const SEATED_HIPS := 0.48
const SEATED_CLIP := "clip_06"
const STOOL_ALONG := [-43.68, -43.31, -42.95, -42.58, -42.22, -41.85, -41.49, -41.12]
const PARTS_NEARBY := 30.0

var world: Node3D
var conversations: ResidentConversations
var parts: Dictionary = {}
var bodies: Dictionary = {}
var overheard_label: Label
var _held := ""
var _lift := {"cup": 0.0, "plate": 0.0}
var _poll := 0.0
var _line_wait := FIRST_LINE_SECONDS
var _speaker := ""
var _opinion := ""
var _sentences: Array[String] = []
var _names: Dictionary = {}
var _stools: Dictionary = {}


static func served() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"cup": 0.0, "plate": 0.0}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 2:
		return false
	for key: String in ["cup", "plate"]:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])) or float(value[key]) < 0.0:
			return false
	return true


func configure(runtime: Node3D, point: Node3D, talk: ResidentConversations) -> bool:
	world = runtime
	conversations = talk
	var stock := preload("res://scripts/building/orison_v2_surface_stock.gd").new()
	if not stock.prepare():
		return false
	var along := 0.0
	for part_id: String in STOCK:
		var part := Node3D.new()
		part.name = part_id.capitalize()
		add_child(part)
		part.position = Vector3(0.0, 0.0, along)
		along -= 0.36
		if not stock.mount_on(part, str(STOCK[part_id])):
			stock.finish()
			return false
		part.set_meta("home", part.position)
		parts[part_id] = part
		preload("res://scripts/props/manipulation_area.gd").install(part, func(): return _grip(part_id))
	stock.finish()
	point.sold.connect(serve)
	for resident: Dictionary in preload("res://scripts/characters/orison_v2_resident_presentation.gd").roster():
		_names[str(resident.id)] = str(resident.display)
	var layer := CanvasLayer.new()
	layer.layer = 59
	add_child(layer)
	overheard_label = Label.new()
	overheard_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	overheard_label.offset_left = 160.0
	overheard_label.offset_right = -160.0
	overheard_label.offset_top = -170.0
	overheard_label.offset_bottom = -70.0
	overheard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overheard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overheard_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	overheard_label.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	overheard_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	overheard_label.add_theme_constant_override("outline_size", 6)
	overheard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overheard_label)
	RealityState.state_changed.connect(refresh)
	refresh()
	return true


func serve(item_id: String) -> void:
	if not SERVED.has(item_id):
		return
	var left := served()
	for part_id: String in SERVED[item_id]:
		left[part_id] = float(left[part_id]) + float(PORTION[part_id])
	RealityState.commit()
	refresh()
	_line_wait = FIRST_LINE_SECONDS


## Reconstructs the counter from what the save says is left on it.
func refresh() -> void:
	var left := served()
	for part_id: String in parts:
		parts[part_id].visible = float(left[part_id]) > 0.0 or _held == part_id
		if _held != part_id:
			_lift[part_id] = 0.0
			_pose(part_id)


func _grip(part_id: String) -> Dictionary:
	var part: Node3D = parts[part_id]
	if not part.visible or float(served()[part_id]) <= 0.0:
		return {}
	return {"owner": self, "part": part, "frame": self, "kind": "slide", "axis": Vector3.UP,
		"minimum": 0.0, "maximum": LIFT, "gesture_travel_px": LIFT_PIXELS,
		"gesture_screen_axis": Vector2.UP,
		"read": func(): return float(_lift[part_id]),
		"write": func(value: float):
			if _held == part_id:
				_lift[part_id] = value
				_pose(part_id),
		"owns": func(): return _held == part_id,
		"begin": func():
			if _held != "":
				return false
			_held = part_id
			return true,
		"end": func():
			_held = ""
			RealityState.commit()}


func _pose(part_id: String) -> void:
	var part: Node3D = parts[part_id]
	var home: Vector3 = part.get_meta("home")
	var raised := float(_lift[part_id]) / LIFT
	var player := get_tree().get_first_node_in_group("player_controller") as PlayerController
	if raised <= 0.0 or player == null:
		part.position = home
		part.basis = Basis.IDENTITY
		return
	part.position = home.lerp(to_local(player.camera.global_transform * MOUTH), raised)
	part.global_basis = Basis(player.camera.global_basis.x, float(TILT[part_id]) * raised)


func _process(delta: float) -> void:
	var left := served()
	for part_id: String in parts:
		if _held == part_id:
			_pose(part_id)
			if float(_lift[part_id]) >= LIFT * AT_MOUTH and float(left[part_id]) > 0.0:
				left[part_id] = maxf(float(left[part_id]) - delta, 0.0)
		elif float(_lift[part_id]) > 0.0:
			_lift[part_id] = maxf(float(_lift[part_id]) - SETTLE_SPEED * delta * LIFT, 0.0)
			_pose(part_id)
		elif parts[part_id].visible and float(left[part_id]) <= 0.0:
			parts[part_id].visible = false
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		_seat_customers()
	_overhear(delta)


func _player_in_room() -> bool:
	var player := get_tree().get_first_node_in_group("player_controller") as Node3D
	return player != null and ROOM.has_point(_source_xy(player.global_position))


func _source_xy(at: Vector3) -> Vector2:
	var local: Vector3 = world.passage_region.global_transform.affine_inverse() * at
	return Vector2(local.x, -local.z)


## A body arrives or leaves only while the player is outside the room to see it.
func _seat_customers() -> void:
	var player := get_tree().get_first_node_in_group("player_controller") as Node3D
	if player == null or player.global_position.distance_to(global_position) > PARTS_NEARBY or _player_in_room():
		return
	for resident: String in _names:
		var here := str(world.resident_whereabouts(resident).get("place", "")) == "luncheonette"
		if here and not bodies.has(resident):
			_seat(resident)
		elif not here and bodies.has(resident):
			bodies[resident].queue_free()
			bodies.erase(resident)
			_stools.erase(resident)


func _seat(resident: String) -> void:
	var stool := _free_stool(resident)
	var actor: Node3D = preload("res://scripts/characters/orison_v2_resident_presentation.gd").new()
	var source: Dictionary = {}
	for row: Dictionary in preload("res://scripts/characters/orison_v2_resident_presentation.gd").roster():
		if str(row.id) == resident:
			source = row
	actor.setup(str(source.display), resident, str(source.unit), str(source.model))
	actor.externally_driven = true
	actor.face_interacting_player = false
	world.passage_region.transaction_actor_root().add_child(actor)
	actor.global_transform = world.passage_region.global_transform * Transform3D(
			Basis(Vector3.UP, PI * 0.5), GameBoot.b2g([STOOL_X, STOOL_ALONG[stool], STOOL_TOP - SEATED_HIPS]))
	actor.preferred_idle = SEATED_CLIP
	actor._local_loop(SEATED_CLIP)
	actor._play_named("idle")
	bodies[resident] = actor
	_stools[resident] = stool


## Each resident keeps one stool, hashed from the name so it is the same every visit.
func _free_stool(resident: String) -> int:
	var stool := absi(resident.hash()) % STOOL_ALONG.size()
	while _stools.values().has(stool):
		stool = (stool + 1) % STOOL_ALONG.size()
	return stool


func _overhear(delta: float) -> void:
	_line_wait -= delta
	if _line_wait > 0.0:
		return
	overheard_label.text = ""
	var left := served()
	var eating := float(left.cup) > 0.0 or float(left.plate) > 0.0
	if not _player_in_room() or (_sentences.is_empty() and not eating):
		_line_wait = 1.0
		return
	if _sentences.is_empty() and not _next_opinion():
		_line_wait = POLL_SECONDS
		return
	var sentence: String = _sentences.pop_front()
	overheard_label.text = "%s, down the counter: %s" % [_names.get(_speaker, ""), sentence]
	_line_wait = sentence.length() / CHARACTERS_PER_SECOND + LINE_GAP_SECONDS
	if _sentences.is_empty():
		RealityState.grant_knowledge(OVERHEARD_PREFIX + _opinion)
		RealityState.commit()


func _next_opinion() -> bool:
	var today := conversations.today()
	for resident: String in bodies:
		for opinion: Dictionary in conversations.active_opinions(resident, today):
			if RealityState.has_knowledge(OVERHEARD_PREFIX + str(opinion.id)):
				continue
			_speaker = resident
			_opinion = str(opinion.id)
			_sentences = sentences_of(str(opinion.line))
			return not _sentences.is_empty()
	return false


## Breaks a spoken line after each full stop, question or exclamation mark.
static func sentences_of(line: String) -> Array[String]:
	var out: Array[String] = []
	var start := 0
	for index in line.length():
		if line[index] in [".", "?", "!"] and (index + 1 == line.length() or line[index + 1] == " "):
			out.append(line.substr(start, index + 1 - start).strip_edges())
			start = index + 1
	var tail := line.substr(start).strip_edges()
	if tail != "":
		out.append(tail)
	return out
