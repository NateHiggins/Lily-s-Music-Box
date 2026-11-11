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
const PIN_REACH := 0.3
const WALL_COLUMNS := 4
const WALL_PITCH := Vector2(0.27, 0.2)

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


func _words(text: String, facing: Basis) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 40
	label.pixel_size = 0.00042
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
	card.global_transform = Transform3D(_paper.global_transform.basis.orthonormalized(),
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
	set_meta("wall_extent", Vector2(box.size.z if out.abs() == Vector3.RIGHT else box.size.x, box.size.y))


func slot_position(slot: int) -> Vector3:
	var column := slot % WALL_COLUMNS
	var row := slot / WALL_COLUMNS
	return _wall_frame * Vector3((float(column) - float(WALL_COLUMNS - 1) * 0.5) * WALL_PITCH.x,
			0.3 - float(row) * WALL_PITCH.y, 0.0)


func _hang(card: Node3D, at: Vector3, text: String) -> void:
	# The slip lies flat where it was copied from; stand it up against the wall.
	var stand := Basis(Quaternion(Vector3.UP, _wall_frame.basis.z))
	card.global_transform = Transform3D(stand * _paper.global_transform.basis.orthonormalized(), at)
	for old: Node in card.find_children("*", "Label3D", true, false):
		old.free()
	var label := _words(text, Basis())
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
	_hang(tucked, _wall_frame * Vector3(0.0, -0.45, 0.0), "")
	tucked_grip.configure(tucked, Vector3.UP, PIN_REACH)
	tucked_grip.live = func() -> bool: return not loop.in_visit() and not loop.carried().is_empty()
	tucked_grip.carried = _pinned
	tucked.visible = false


func _pinned() -> void:
	var result: Dictionary = loop.pin_next()
	tucked_grip.put_back()
	if not result.ok:
		return
	var body := str(loop.item_text(str(result.item)).body)
	for anchor_id: String in result.opened:
		body += "\nNEW LEAD: %s." % str(loop.table.anchors[anchor_id].title).to_upper()
	for deduction_id: String in result.deductions:
		body += "\n" + str(loop.table.deductions[deduction_id].line)
	var player := world.get("player") as PlayerController
	if player != null:
		player.present_service_note(wall, {"title": str(loop.item_text(str(result.item)).title).to_upper(), "body": body,
				"condition": "PINNED", "stamp": "THE WALL"})
	_sync()


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
		_hang(tucked, _wall_frame * Vector3(0.0, -0.45, 0.0), str(loop.item_text(waiting[0]).title).to_upper())
	tucked.visible = show
	for item_id: String in loop.on_wall():
		if wall_cards.has(item_id):
			continue
		var pinned := _copy_paper()
		pinned.name = "LoopPinned_" + item_id
		add_child(pinned)
		_hang(pinned, slot_position(int(loop.ledger().items[item_id].get("slot", wall_cards.size()))),
				str(loop.item_text(item_id).title).to_upper())
		wall_cards[item_id] = pinned
	for item_id: String in wall_cards.keys():
		if not loop.pinned(item_id):
			(wall_cards[item_id] as Node).queue_free()
			wall_cards.erase(item_id)


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.25 or loop == null:
		return
	_poll = 0.0
	if loop.in_visit():
		loop.observe(str(world.player_unit()))
