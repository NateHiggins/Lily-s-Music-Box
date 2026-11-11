extends Node3D
## The temporal loop in the V2 world. It adds no furniture of its own: each
## loop's steps are worked on objects the flats already hold, lifted out of
## the way by hand. When a room's steps are done its evidence lies where the
## last thing stood, to be picked up. At home the carried evidence waits at
## the case wall in 4B and is pinned there by hand.
##
## The paper of every card is a copy of an existing V2 slip (its authored
## mesh and registered finish); the words are Label3D.

const Grip := preload("res://scripts/props/loop_shift_grip.gd")
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const PAPER_SOURCE := "4B_wake_slip"
const ROOM_REFERENCE := "4B_meal_table"
const INK := Color(0.09, 0.08, 0.07)
const TAKE_REACH := 0.12
const PIN_REACH := 0.25
const PULL_REACH := 0.05
const STRING_RED := Color(0.6, 0.04, 0.05)
const STRING_WIDTH := 0.005
const SURVEY_RAYS := 900
## The case wall already carries three rows of eight blank slips. Evidence is
## written onto them in order. These are the slips' places as fractions of
## the board, measured from a capture of the V2 board.
const WALL_COLUMNS := 8
const WALL_ROWS := 3
const SLIP_FIRST := Vector2(0.072, 0.09)
const SLIP_PITCH := Vector2(0.1197, 0.1325)
const SLIP_WORDS_WIDTH := 0.1

var world: Node3D
var loop: Node
var adapter: Variant
var errors: Array[String] = []
## Object id to its grip; one grip serves every step that names the object.
var grips: Dictionary = {}
## Clue id to the card lying in its room.
var cards: Dictionary = {}
var wall: Node3D
var wall_cards: Dictionary = {}
## The carried item waiting at the wall to be pinned.
var tucked: Node3D
var tucked_grip: Node
var _paper: Node3D
var _poll := 0.0
var _wall_frame := Transform3D()
var _wall_size := Vector2.ONE
var _paper_centre := Vector3.ZERO
## The piece the string has been taken from and not yet run anywhere.
var string_from := ""
var string_nodes: Dictionary = {}
var loose_end: Node3D
var _string_finish: StandardMaterial3D
var deduction_cards: Dictionary = {}
## Where paper can go in 4B, nearest the board first, and the paper there.
var spots: Array[Dictionary] = []
var papers: Array[Node3D] = []
var surveyed := false
## Turns the copied slip from however it lies in 4B to flat, long side along X,
## face along Z.
var _paper_square := Basis()


func setup(root: Node3D, temporal_loop: Node, world_adapter: Variant) -> bool:
	world = root
	loop = temporal_loop
	adapter = world_adapter
	_paper = adapter.resolve(PAPER_SOURCE) as Node3D
	wall = adapter.resolve(str(loop.table.wall)) as Node3D
	if _paper == null:
		errors.append("no paper to copy: " + PAPER_SOURCE)
	if wall == null:
		errors.append("no case wall: " + str(loop.table.wall))
	for anchor_id: String in loop.table.anchors:
		var anchor: Dictionary = loop.table.anchors[anchor_id]
		for step: Dictionary in anchor.steps:
			if str(step.kind) == "shift":
				_grip_for(str(step.object), step)
		_card_for(anchor_id)
	if _paper != null:
		_square_paper()
	if wall != null and _paper != null:
		_frame_wall()
		_tuck()
	loop.changed.connect(_sync)
	loop.stage_reset.connect(_put_back)
	_sync()
	return errors.is_empty()


func _grip_for(object_id: String, step: Dictionary) -> void:
	if grips.has(object_id):
		return
	var part := adapter.resolve(object_id) as Node3D
	if part == null:
		errors.append("no such object: " + object_id)
		return
	var grip := Grip.new()
	grip.name = "LoopGrip_" + object_id
	add_child(grip)
	var axis: Array = step.axis
	grip.configure(part, Vector3(float(axis[0]), float(axis[1]), float(axis[2])), float(step.reach))
	grip.live = func() -> bool: return _wanted(object_id)
	grip.carried = func() -> void: _carried(object_id)
	grips[object_id] = grip


## An object is live only in a visit whose steps name it and have not used it.
func _wanted(object_id: String) -> bool:
	if not loop.in_visit():
		return false
	for step: Dictionary in loop.table.anchors[loop.visit_anchor()].steps:
		if str(step.kind) == "shift" and str(step.object) == object_id:
			return str(step.id) not in loop.stage().done
	return false


func _carried(object_id: String) -> void:
	var grip: Node = grips[object_id]
	match loop.report_shift(object_id):
		"step":
			grip.set_aside()
		"fault":
			pass # stage_reset has already put the room back
		_:
			grip.put_back()
	_sync()


func _put_back() -> void:
	for grip: Node in grips.values():
		grip.put_back()
	_sync()


func _copy_paper() -> Node3D:
	var sheet := Node3D.new()
	for draw: MeshInstance3D in _paper.find_children("*", "MeshInstance3D", true, false) + ([_paper] if _paper is MeshInstance3D else []):
		var copy := MeshInstance3D.new()
		copy.mesh = draw.mesh
		for surface in draw.get_surface_override_material_count():
			copy.set_surface_override_material(surface, draw.get_surface_override_material(surface))
		copy.material_override = draw.material_override
		copy.transform = _paper.global_transform.affine_inverse() * draw.global_transform
		copy.visibility_range_end = 14.0
		sheet.add_child(copy)
	return sheet


## The slip's own long, short and thin directions, so a copy can be laid or
## hung square whatever way the original happens to lie.
func _square_paper() -> void:
	var box := AABB()
	var first := true
	for draw: MeshInstance3D in _paper.find_children("*", "MeshInstance3D", true, false) + ([_paper] if _paper is MeshInstance3D else []):
		var part_box := (_paper.global_transform.affine_inverse() * draw.global_transform) * draw.get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var sizes: Array[float] = [box.size.x, box.size.y, box.size.z]
	var thin := 0
	var long := 0
	for index in 3:
		if sizes[index] < sizes[thin]: thin = index
		if sizes[index] > sizes[long]: long = index
	if thin == long:
		return
	var local := Basis(axes[long], axes[thin].cross(axes[long]), axes[thin])
	_paper_square = local.inverse()
	_paper_centre = _paper_square * box.get_center()
	set_meta("paper_size", Vector2(sizes[long], sizes[3 - thin - long]))


func _words(text: String, facing: Basis, width_m := 0.16) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 40
	label.pixel_size = width_m / 380.0
	label.modulate = INK
	label.outline_size = 0
	label.width = 380.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.shaded = true
	label.double_sided = false
	label.visibility_range_end = 6.0
	label.basis = facing
	return label


## The evidence of one anchor, lying where its last object stood.
func _card_for(anchor_id: String) -> void:
	var clue: Dictionary = loop.clue_of(anchor_id)
	var rest := adapter.resolve(str(clue.rest)) as Node3D
	if rest == null:
		errors.append("no rest for %s: %s" % [str(clue.id), str(clue.rest)])
		return
	if _paper == null:
		return
	var card := _copy_paper()
	card.name = "LoopClue_" + str(clue.id)
	add_child(card)
	var offset: Array = clue.get("rest_offset", [0.0, 0.0, 0.0])
	_place(card, _sized(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), 0.16, 0.11),
			rest.global_position + Vector3(float(offset[0]), float(offset[1]), float(offset[2])))
	var label := _words(str(clue.title).to_upper(), Basis())
	card.add_child(label)
	label.global_transform = Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP),
			card.global_position + Vector3.UP * 0.004)
	var grip := Grip.new()
	grip.name = "Take"
	card.add_child(grip)
	grip.configure(card, Vector3.UP, TAKE_REACH)
	grip.live = func() -> bool: return loop.clue_ready() and str(loop.clue_of(loop.visit_anchor()).id) == str(clue.id)
	grip.carried = func() -> void: _taken(card)
	card.set_meta("grip", grip)
	card.set_meta("clue", str(clue.id))
	card.visible = false
	cards[str(clue.id)] = card


func _taken(card: Node3D) -> void:
	var result: Dictionary = loop.take_clue()
	if not result.ok:
		(card.get_meta("grip") as Node).put_back()
		return
	card.visible = false
	var player := world.get("player") as PlayerController
	if player != null:
		player.present_service_note(card, {"title": str(result.title).to_upper(), "body": str(result.body),
				"condition": "KEPT", "stamp": "EVIDENCE"})
	_sync()


## The wall's own frame: origin at its centre on the room side, X along the
## wall, Y up, Z out into the room.
func _frame_wall() -> void:
	var box := AABB()
	var first := true
	for draw: MeshInstance3D in wall.find_children("*", "MeshInstance3D", true, false) + ([wall] if wall is MeshInstance3D else []):
		var part_box := draw.global_transform * draw.get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	if first:
		errors.append("the case wall has no surface")
		return
	var out := Vector3.RIGHT if box.size.x < box.size.z else Vector3.BACK
	var reference := adapter.resolve(ROOM_REFERENCE) as Node3D
	if reference != null and out.dot(reference.global_position - box.get_center()) < 0.0:
		out = -out
	var across := Vector3.UP.cross(out).normalized()
	var depth := (box.size.x if out.abs() == Vector3.RIGHT else box.size.z) * 0.5
	_wall_frame = Transform3D(Basis(across, Vector3.UP, out), box.get_center() + out * (depth + 0.006))
	_wall_size = Vector2(box.size.z if out.abs() == Vector3.RIGHT else box.size.x, box.size.y)


## The place of the board's blank slip number `slot`, reading left to right
## and top to bottom.
func slot_position(slot: int) -> Vector3:
	var column := slot % WALL_COLUMNS
	var row := mini(slot / WALL_COLUMNS, WALL_ROWS - 1)
	return _wall_frame * Vector3((-0.5 + SLIP_FIRST.x + SLIP_PITCH.x * float(column)) * _wall_size.x,
			(0.5 - SLIP_FIRST.y - SLIP_PITCH.y * float(row)) * _wall_size.y, 0.0)


func _foot() -> Vector3:
	return _wall_frame * Vector3(0.0, -_wall_size.y * 0.22, 0.0)


func _hang(card: Node3D, at: Vector3, text: String) -> void:
	_place(card, _sized(_wall_frame.basis, 0.15, 0.1), at)
	for old: Node in card.find_children("*", "Label3D", true, false):
		old.free()
	var label := _words(text, Basis(), 0.13)
	card.add_child(label)
	label.global_transform = Transform3D(_wall_frame.basis, at + _wall_frame.basis.z * 0.004)


## The next carried item, tucked at the foot of the wall for the hand to pin.
func _tuck() -> void:
	tucked = _copy_paper()
	tucked.name = "LoopCarried"
	add_child(tucked)
	tucked_grip = Grip.new()
	tucked_grip.name = "Pin"
	tucked.add_child(tucked_grip)
	_hang(tucked, _foot(), "")
	tucked_grip.configure(tucked, Vector3.UP, PIN_REACH)
	tucked_grip.live = func() -> bool: return not loop.in_visit() and not loop.carried().is_empty()
	tucked_grip.carried = _pinned
	tucked.visible = false


func _note(owner: Node, title: String, body: String, condition: String) -> void:
	var player := world.get("player") as PlayerController
	if player != null:
		player.present_service_note(owner, {"title": title, "body": body, "condition": condition, "stamp": "THE WALL"})


func _pinned() -> void:
	var result: Dictionary = loop.pin_next()
	tucked_grip.put_back()
	if not result.ok:
		return
	var body := str(loop.item_text(str(result.item)).body)
	for anchor_id: String in result.opened:
		body += "\nNEW LEAD: %s." % str(loop.table.anchors[anchor_id].title).to_upper()
	if not loop.open_deduction().is_empty():
		body += "\nSOMETHING HERE WANTS JOINING."
	_note(wall, str(loop.item_text(str(result.item)).title).to_upper(), body, "PINNED")
	_sync()


## A pinned piece's pin was pulled. The first pull takes the string from that
## piece; the second, on another piece, runs it there.
func _pulled(item_id: String) -> void:
	((wall_cards[item_id] as Node3D).get_meta("grip") as Node).put_back()
	if string_from.is_empty():
		string_from = item_id
		_sync()
		return
	if string_from == item_id:
		string_from = ""
		_sync()
		return
	var from := string_from
	string_from = ""
	var result: Dictionary = loop.link(from, item_id)
	if not result.ok:
		_sync()
		return
	if not bool(result.held):
		_note(wall, "THE STRING FALLS", "Nothing joins %s to %s." % [str(loop.item_text(from).title), str(loop.item_text(item_id).title)], "NO")
	elif not (result.deductions as Array).is_empty():
		var body := ""
		for deduction_id: String in result.deductions:
			body += str(loop.table.deductions[deduction_id].line) + "\n"
		for anchor_id: String in result.opened:
			body += "NEW LEAD: %s.\n" % str(loop.table.anchors[anchor_id].title).to_upper()
		_note(wall, "IT HOLDS", body.strip_edges(), "DEDUCED")
	_sync()


## `facing` stretched so a copy of the slip comes out `width` by `height` metres.
func _sized(facing: Basis, width: float, height: float) -> Basis:
	var size: Vector2 = get_meta("paper_size", Vector2(0.1, 0.06))
	return Basis(facing.x.normalized() * (width / size.x), facing.y.normalized() * (height / size.y), facing.z.normalized())


## Put a copy of the slip somewhere, its face along `facing.z`, its long side
## along `facing.x`, centred on `at`.
func _place(node: Node3D, facing: Basis, at: Vector3) -> void:
	var turned := facing * _paper_square
	node.global_transform = Transform3D(turned, at - facing * _paper_centre)


## Red string, as a narrow strip of the same paper stock dyed red.
func _ribbon(from: Vector3, to: Vector3) -> Node3D:
	var strip := _copy_paper()
	if _string_finish == null:
		_string_finish = MatLib.get_mat("paper").duplicate() as StandardMaterial3D
		_string_finish.uv1_triplanar = false
		_string_finish.albedo_color = STRING_RED
	for draw: MeshInstance3D in strip.get_children():
		draw.material_override = _string_finish
	add_child(strip)
	var out: Vector3 = _wall_frame.basis.z
	var along := to - from
	_place(strip, _sized(Basis(along.normalized(), out.cross(along.normalized()), out), along.length(), STRING_WIDTH),
			(from + to) * 0.5 + out * 0.009)
	return strip


func _deduction_place(deduction_id: String) -> Vector3:
	var place: int = (loop.ledger().deductions as Array).find(deduction_id)
	return _wall_frame * Vector3((-0.32 + 0.32 * float(place % 3)) * _wall_size.x,
			(-0.08 - 0.2 * float(place / 3)) * _wall_size.y, 0.0)


## Bring every card in line with the ledger.
func _sync() -> void:
	for clue_id: String in cards:
		var card: Node3D = cards[clue_id]
		var grip: Node = card.get_meta("grip")
		var ready: bool = loop.clue_ready() and str(loop.clue_of(loop.visit_anchor()).id) == clue_id
		if ready and not card.visible:
			grip.put_back()
		card.visible = ready
	if tucked == null:
		return
	var waiting: Array[String] = loop.carried()
	var show: bool = not loop.in_visit() and not waiting.is_empty()
	if show:
		tucked_grip.put_back()
		_hang(tucked, _foot(), str(loop.item_text(waiting[0]).title).to_upper())
	tucked.visible = show
	# Pinned pieces: a slip over the board's own blank one, with a pin to pull.
	for item_id: String in loop.on_wall():
		if wall_cards.has(item_id):
			continue
		var pinned := _copy_paper()
		pinned.name = "LoopPinned_" + item_id
		add_child(pinned)
		var at := slot_position(int(loop.ledger().items[item_id].get("slot", wall_cards.size()))) + _wall_frame.basis.z * 0.004
		_place(pinned, _sized(_wall_frame.basis, 0.085, 0.1), at)
		var label := _words(str(loop.item_text(item_id).title).to_upper(), Basis(), SLIP_WORDS_WIDTH)
		pinned.add_child(label)
		label.global_transform = Transform3D(_wall_frame.basis, at + _wall_frame.basis.z * 0.003)
		var grip := Grip.new()
		grip.name = "Pull"
		pinned.add_child(grip)
		grip.configure(pinned, _wall_frame.basis.z, PULL_REACH)
		grip.live = func() -> bool: return not loop.in_visit()
		grip.carried = func() -> void: _pulled(item_id)
		pinned.set_meta("grip", grip)
		wall_cards[item_id] = pinned
	for item_id: String in wall_cards.keys():
		if not loop.pinned(item_id):
			(wall_cards[item_id] as Node).queue_free()
			wall_cards.erase(item_id)
	# Strings that held.
	var wanted := {}
	for string: Array in loop.strings():
		var key := str(string[0]) + "|" + str(string[1])
		wanted[key] = true
		if not string_nodes.has(key) and loop.pinned(str(string[0])) and loop.pinned(str(string[1])):
			string_nodes[key] = _ribbon(slot_position(int(loop.ledger().items[str(string[0])].slot)),
					slot_position(int(loop.ledger().items[str(string[1])].slot)))
	for key: String in string_nodes.keys():
		if not wanted.has(key):
			(string_nodes[key] as Node).queue_free()
			string_nodes.erase(key)
	# The loose end, hanging from the piece the string was taken from.
	if loose_end != null:
		loose_end.queue_free()
		loose_end = null
	if not string_from.is_empty() and loop.pinned(string_from):
		var top := slot_position(int(loop.ledger().items[string_from].slot))
		loose_end = _ribbon(top, top - _wall_frame.basis.y * 0.14 + _wall_frame.basis.x * 0.03)
	# Deductions drawn, written out under the pieces they join.
	for deduction_id: Variant in loop.ledger().deductions:
		if deduction_cards.has(str(deduction_id)):
			continue
		var drawn := _copy_paper()
		drawn.name = "LoopDeduction_" + str(deduction_id)
		add_child(drawn)
		var at := _deduction_place(str(deduction_id)) + _wall_frame.basis.z * 0.005
		_place(drawn, _sized(_wall_frame.basis, 0.24, 0.17), at)
		var label := _words(str(loop.table.deductions[str(deduction_id)].line), Basis(), 0.21)
		drawn.add_child(label)
		label.global_transform = Transform3D(_wall_frame.basis, at + _wall_frame.basis.z * 0.004)
		deduction_cards[str(deduction_id)] = drawn
	_grow()


# --- The wall takes the flat ------------------------------------------------------

## Find where paper can go: every upright surface in sight of the middle of
## the room, nearest the board first. Done once, on a physics frame.
func _survey() -> void:
	surveyed = true
	var space := world.get_world_3d().direct_space_state
	if space == null:
		return
	var out: Vector3 = _wall_frame.basis.z
	var eye: Vector3 = _wall_frame.origin + out * 1.5
	var floor_y := floorf((eye.y + 0.05) / 3.2) * 3.2
	var found: Array[Dictionary] = []
	for index in SURVEY_RAYS:
		var yaw := float(index) * 2.399963
		var height := floor_y + 0.4 + 2.0 * fposmod(float(index) * 0.7548776662, 1.0)
		var from := Vector3(eye.x, height, eye.z)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(cos(yaw), 0.0, sin(yaw)) * 9.0)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.2 or from.distance_to(hit.position) < 0.5:
			continue
		var on_board: Vector3 = _wall_frame.affine_inverse() * (hit.position as Vector3)
		if absf(on_board.z) < 0.08 and absf(on_board.x) < _wall_size.x * 0.5 + 0.06 and absf(on_board.y) < _wall_size.y * 0.5 + 0.06:
			continue
		if world.unit_at_world(hit.position as Vector3) != "4B":
			continue
		var crowded := false
		for other: Dictionary in found:
			crowded = crowded or (other.position as Vector3).distance_to(hit.position) < 0.17
		if crowded:
			continue
		found.append({"position": hit.position, "normal": (hit.normal as Vector3).normalized(),
				"far": (hit.position as Vector3).distance_to(_wall_frame.origin)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.far) < float(b.far))
	spots = found
	_grow()


## Paper up to the case's present spread, nearest the board first.
func _grow() -> void:
	if not surveyed or _paper == null:
		return
	var count: int = mini(int(loop.spread()), spots.size())
	var scrawls: Array = loop.table.scrawls
	while papers.size() < count:
		var index := papers.size()
		var spot: Dictionary = spots[index]
		var normal: Vector3 = spot.normal
		var across := Vector3.UP.cross(normal).normalized()
		var roll := (fposmod(float(index) * 0.7548776, 1.0) - 0.5) * 0.5
		var size := 0.14 + 0.13 * fposmod(float(index) * 0.5698403, 1.0)
		var level := across.rotated(normal, roll)
		var facing := _sized(Basis(level, normal.cross(level), normal), size, size * (0.72 + 0.5 * fposmod(float(index) * 0.3247, 1.0)))
		var sheet := _copy_paper()
		sheet.name = "LoopPaper_%d" % index
		add_child(sheet)
		var at: Vector3 = (spot.position as Vector3) + normal * (0.004 + 0.0004 * float(index % 5))
		_place(sheet, facing, at)
		if index % 3 == 0 and not scrawls.is_empty():
			var label := _words(str(scrawls[(index / 3) % scrawls.size()]), Basis(), size * 0.85)
			sheet.add_child(label)
			label.global_transform = Transform3D(Basis(level, normal.cross(level), normal), at + normal * 0.003)
		papers.append(sheet)
	for index in papers.size():
		(papers[index] as Node3D).visible = index < count


func _physics_process(_delta: float) -> void:
	if not surveyed and wall != null and _paper != null and world.get("startup_ms") != null and float(world.startup_ms) > 0.0:
		_survey()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.25 or loop == null:
		return
	_poll = 0.0
	if loop.in_visit():
		loop.observe(str(world.player_unit()))
