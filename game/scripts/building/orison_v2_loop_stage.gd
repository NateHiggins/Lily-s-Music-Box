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
const Evidence := preload("res://scripts/building/orison_v2_evidence_stock.gd")
const FONT := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
## Adela's own hand (Lily's choice, 2026-11-11): Cedarville Cursive, written
## thick, as with a marking crayon, so it reads from across the room.
const HAND := preload("res://assets/fonts/cedarvillecursive/Cedarville-Cursive.ttf")
const HAND_INK := Color(0.07, 0.07, 0.12)
const PAPER_SOURCE := "4B_wake_slip"
const ROOM_REFERENCE := "4B_meal_table"
const INK := Color(0.09, 0.08, 0.07)
const TAKE_REACH := 0.12
const PIN_REACH := 0.25
const PULL_REACH := 0.05
## The year across the board, as fractions of the board: where the tape runs
## and how far to either side.
const YEAR_Y := -0.06
const YEAR_HALF := 0.45
const TAG_DROP := 0.05
## Seasons along the year, by the day each begins (day 0 is 10 November 1928).
const SEASON_BANDS := [[0, Color(0.74, 0.5, 0.36)], [21, Color(0.66, 0.74, 0.8)], [111, Color(0.68, 0.8, 0.62)],
		[203, Color(0.9, 0.8, 0.5)], [295, Color(0.78, 0.52, 0.34)], [365, Color.BLACK]]
const MONTHS := [[0, "N"], [21, "D"], [52, "J"], [83, "F"], [111, "M"], [142, "A"], [172, "M"], [203, "J"], [233, "J"],
		[264, "A"], [295, "S"], [325, "O"], [356, "N"]]
const BLACKOUT_DAY := 251
## The building map, to the right of the board: its centre from the board's
## centre, and its size, in metres.
const MAP_CENTRE := Vector2(1.32, 0.02)
const MAP_SIZE := Vector2(1.0, 1.2)
const AREA_CENTRE := Vector2(1.32, -0.84)
const AREA_SIZE := Vector2(0.9, 0.36)
const AREA_SPOTS := [Vector2(-0.18, -0.02), Vector2(0.16, 0.08), Vector2(0.28, -0.1), Vector2(-0.3, 0.12), Vector2(0.02, -0.14)]
const STRING_RED := Color(0.6, 0.04, 0.05)
const STRING_WIDTH := 0.005
const SURVEY_RAYS := 700
const MAX_STRANDS := 70
const MAX_SHEETS := 1300
## A message on every so many sheets, and how far through the spread the hand turns loud and then to a scrawl.
## A household paper on the wall before the case: its size in metres and how far the hand pulls it to take it down.
const COVER_SIZE := Vector2(0.30, 0.22)
const COVER_REACH := 0.30
## How far the hand draws the scissors to make a cut, and how many cuttings sit in a row over the board.
const SNIP_REACH := 0.12
## A print on the wall, in metres, and how many hang in a row under the board.
const PRINT_SIZE := Vector2(0.17, 0.1275)
const PRINT_COLUMNS := 5
const PlateCamera := preload("res://scripts/props/plate_camera.gd")
const PaperPocket := preload("res://scripts/game/paper_pocket.gd")
## How far through the case the windows begin to be papered, and the sheets over each.
const WINDOWS_FROM := 0.70
const WINDOW_COLUMNS := 3
const WINDOW_ROWS := 4
const WindowTreatment := preload("res://scripts/building/orison_v2_window_treatment.gd")
const CLIP_COLUMNS := 6
const MESSAGE_EVERY := 6
## The two papers' names as they head each front, and the faces they are set in.
const MASTHEADS := ["The Borough Record", "The Loud Speaker"]
const MASTHEAD_FONTS := [preload("res://assets/fonts/unifrakturcook/UnifrakturCook-Bold.ttf"), preload("res://assets/fonts/abrilfatface/AbrilFatface-Regular.ttf")]
const MANIC_FROM := 0.30
const SCRAWL_FROM := 0.62
const MAX_PILES := 60
## A stack of paper already in 4B, copied for the gathered newspapers.
const BUNDLE_SOURCE := "4B_slip_stack"
## Things standing in 4B's rooms, to look out from when finding where paper can go.
const ROOM_EYES: Array[String] = ["4B_meal_table", "4B_wake_bed", "4B_couch", "4B_terminal_desk", "4B_sink_counter",
		"4B_hallstand", "4B_wc", "4B_closet_rail", "4B_equipment_shelf", "4B_wireless_table"]
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
## Household paper id -> its sheet on the wall, while it is still up.
var covers: Dictionary = {}
## Paper over 4B's windows, late in the case: where each sheet goes, and the sheets up so far.
var window_spots: Array[Dictionary] = []
var window_papers: Array[Node3D] = []
var windows_found := false
## Her camera, and her prints on the wall by picture number.
var plate_camera: CanvasLayer
var print_cards: Dictionary = {}
## The print waiting at the foot of the wall to be pinned, and its picture number (0 for none).
var waiting_print: Node3D
var waiting_print_number := 0
## The year's occasion hung in a window of the room she is in, and the room and piece it was hung for.
var occasion: Node3D
## The ice card hung in a window of the room she is in, May to September, and the room and pounds it was hung for.
var ice_card: Node3D
var ice_key := ""
var occasion_key := ""
var scissors: Node3D
var scissors_grip: Node
## "<paper>:<date>" -> the cutting on the wall.
var clip_cards: Dictionary = {}
var tucked_item := ""
## The modelled pieces of evidence, the newspaper bundle and the map pin.
var stock: RefCounted
var pile_tops: Array[Node3D] = []
var _paper: Node3D
var _poll := 0.0
## How the borrowed part of the house stood when the visit began, and the run
## of its hours it was last put back for.
var _house_was: Dictionary = {}
var _house_run := ""
var _house_held := false
var _call_held := false
var _talk_held := false
var _wall_frame := Transform3D()
var _wall_size := Vector2.ONE
var _paper_centre := Vector3.ZERO
## The piece the string has been taken from and not yet run anywhere.
var string_from := ""
var string_nodes: Dictionary = {}
var loose_end: Node3D
var _string_finish: StandardMaterial3D
var _tints: Dictionary = {}
## Place code to the pin on the building map.
var cell_pins: Dictionary = {}
## The pinned piece waiting for its day, as a tag on the year.
var loose_tag: Node3D
var loose_tag_grip: Node
var loose_tag_item := ""
var date_tags: Dictionary = {}
var place_strings: Dictionary = {}
var year_parts := 0
var deduction_cards: Dictionary = {}
## Where paper can go in 4B, nearest the board first, and the paper there.
var spots: Array[Dictionary] = []
var papers: Array[Node3D] = []
var surveyed := false
var pile_spots: Array[Dictionary] = []
var piles: Array[Node3D] = []
var high_spots: Array[Dictionary] = []
var strands: Array[Node3D] = []
var _bundle: Node3D
var _bundle_size := Vector3.ONE
var _bundle_foot := Vector3.ZERO
## Cups left standing (plan, section 4: "the rest of the flat joins in"): copies of 4B's own mug on the flat's
## tables, shelves and counters, more of them the further the case has gone.
const MUG_SOURCE := "4B_mug"
const MUGS_FROM := 0.25
const MAX_MUGS := 14
const MUG_SKIP: Array[String] = ["4B_wake_bed", "4B_couch"]
var mug_spots: Array[Dictionary] = []
var mugs: Array[Node3D] = []
var _mug: Node3D
var _mug_foot := Vector3.ZERO
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
	stock = Evidence.new()
	if not stock.prepare():
		errors.append("evidence pieces refused: %s" % str(stock.errors))
	for anchor_id: String in loop.table.anchors:
		if not stock.has(str(loop.clue_of(anchor_id).id)):
			errors.append("no modelled piece for " + str(loop.clue_of(anchor_id).id))
		var anchor: Dictionary = loop.table.anchors[anchor_id]
		for step: Dictionary in anchor.steps:
			if str(step.kind) == "shift":
				_grip_for(str(step.object), step)
		_card_for(anchor_id)
	if _paper != null:
		_square_paper()
	_bundle = adapter.resolve(BUNDLE_SOURCE) as Node3D
	if _bundle == null:
		errors.append("no stack of paper to copy: " + BUNDLE_SOURCE)
	else:
		var box := AABB()
		var first := true
		for draw: MeshInstance3D in _bundle.find_children("*", "MeshInstance3D", true, false) + ([_bundle] if _bundle is MeshInstance3D else []):
			var part_box := (_bundle.global_transform.affine_inverse() * draw.global_transform) * draw.get_aabb()
			box = part_box if first else box.merge(part_box)
			first = false
		_bundle_size = box.size.max(Vector3.ONE * 0.001)
		_bundle_foot = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	_mug = adapter.resolve(MUG_SOURCE) as Node3D
	if _mug == null:
		errors.append("no mug to copy: " + MUG_SOURCE)
	else:
		var low := INF
		for draw: MeshInstance3D in _mug.find_children("*", "MeshInstance3D", true, false) + ([_mug] if _mug is MeshInstance3D else []):
			var part_box := (_mug.global_transform.affine_inverse() * draw.global_transform) * draw.get_aabb()
			low = minf(low, part_box.position.y)
		_mug_foot = Vector3(0.0, low if low < INF else 0.0, 0.0)
	if wall != null and _paper != null:
		_frame_wall()
		_tuck()
		_cover_wall()
		_hang_scissors()
		plate_camera = PlateCamera.new()
		plate_camera.name = "PlateCamera"
		plate_camera.setup(world)
		add_child(plate_camera)
		_dress_wall()
	loop.changed.connect(_sync)
	loop.stage_reset.connect(_put_back)
	# A conversation keeps the clock to its own time while it lasts.
	var talk: Variant = world.get("conversations")
	if talk is Node and (talk as Node).has_signal("conversation_started") and (talk as Node).has_signal("conversation_ended"):
		(talk as Node).connect("conversation_started", func(_resident: String, _entry: String) -> void:
			_talk_held = true
			loop.hold_pace("talk"))
		(talk as Node).connect("conversation_ended", func(_resident: String) -> void:
			_talk_held = false
			loop.release_pace("talk"))
	# A campaign loaded in the middle of a visit: how the house stood before
	# it is in the visit's record.
	if loop.in_visit() and (loop.ledger().visit as Dictionary).get("household") is Dictionary:
		_house_was = ((loop.ledger().visit as Dictionary).household as Dictionary).duplicate(true)
		_house_run = _house_run_identity()
		_house_held = true
	_sync()
	return errors.is_empty()


func _exit_tree() -> void:
	if loop != null and is_instance_valid(loop):
		loop.release_pace("talk")
		loop.release_pace("call")


## The house in a visit: its doors, windows, lights, radiators, cabinets,
## mirrors and shelves are borrowed when the visit begins, put back as they
## were when its hours are run again, and given back when the player comes
## home. A room merely faulted out of order keeps the doors where they are.
func _house_run_identity() -> String:
	if not loop.in_visit():
		return ""
	var book: Dictionary = loop.ledger()
	var visit: Dictionary = book.visit
	var record: Dictionary = book.anchors.get(str(visit.anchor), {})
	return "%s|%s|%s|%d|%d" % [visit.anchor, str(float(visit.left_at)), str(float(visit.loop_started)),
			int(record.get("paid", 0)), int(record.get("loops", 0))]


func _rewind_house() -> void:
	var house: Variant = world.get("household_state")
	if house is not Node or not (house as Node).has_method("visit_restore"):
		return
	if not loop.in_visit():
		if _house_held:
			if not bool(house.visit_restore(_house_was)):
				push_warning("LOOP STAGE: the house would not be given back as it was")
			else:
				RealityState.commit_background()
		_house_was = {}
		_house_run = ""
		_house_held = false
		return
	var visit: Dictionary = loop.ledger().visit
	var run := _house_run_identity()
	if not _house_held:
		_house_was = house.visit_snapshot()
		visit["household"] = _house_was.duplicate(true)
		_house_run = run
		_house_held = true
		RealityState.commit_background()
		return
	if run == _house_run:
		return
	_house_run = run
	if not bool(house.visit_restore(_house_was)):
		push_warning("LOOP STAGE: the house would not be put back for the rerun")
	else:
		RealityState.commit_background()


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
	_rewind_house()
	for grip: Node in grips.values():
		grip.put_back()
	_sync()


func _copy_paper() -> Node3D:
	return _copy_of(_paper)


## A copy of an existing V2 object's surfaces: its authored meshes and finishes.
func _copy_of(source: Node3D) -> Node3D:
	var sheet := Node3D.new()
	for draw: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false) + ([source] if source is MeshInstance3D else []):
		var copy := MeshInstance3D.new()
		copy.mesh = draw.mesh
		for surface in draw.get_surface_override_material_count():
			copy.set_surface_override_material(surface, draw.get_surface_override_material(surface))
		copy.material_override = draw.material_override
		copy.transform = source.global_transform.affine_inverse() * draw.global_transform
		copy.visibility_range_end = 14.0
		# Thin sheets and string throw broken shadows; they lie on what they cover.
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


## One message on a sheet `size` metres wide, as one or two labels. `gone` runs from 0 at the board to 1 in the far
## rooms. Each label's rotation.z is its lean on the sheet and its position its shift across it (x, y) and off it (z);
## the caller sets it on the wall.
##   under a third   the whole line, in her hand, neat and heavy
##   under two thirds   the same line in capitals, bigger, leaning, gone over twice
##   after that   its one word, again and again down the sheet in a child's capitals, gone over, running off the edge
func _message(line: String, tic: String, size: float, gone: float, turn: int) -> Array[Label3D]:
	var made: Array[Label3D] = []
	var wobble := fposmod(float(turn) * 0.6180339, 1.0) - 0.5
	if gone < MANIC_FROM:
		var neat := _hand(line, size * 1.15, 72)
		neat.outline_size = 12
		neat.rotation.z = wobble * 0.08
		made.append(neat)
	elif gone < SCRAWL_FROM:
		for pass_index in 2:
			var loud := _hand(line.to_upper(), size * 1.25, 84)
			# Capitals are wide: a longer line, so the joke is three lines and not a column of syllables.
			loud.width = 760.0
			loud.pixel_size = size * 1.25 / 760.0
			loud.outline_size = 16
			loud.rotation.z = wobble * 0.30 + float(pass_index) * 0.035
			loud.position = Vector3(float(pass_index) * size * 0.012, float(pass_index) * size * -0.010, float(pass_index) * 0.0004)
			made.append(loud)
	else:
		var rows := PackedStringArray()
		var per_row := maxi(1, int(18.0 / float(tic.length() + 1)))
		for row in 7:
			var words := PackedStringArray()
			for _word in per_row + (row % 2):
				words.append(tic)
			rows.append(" ".join(words))
		for pass_index in 2:
			var child := _hand("
".join(rows), size * 1.18, 58)
			child.autowrap_mode = TextServer.AUTOWRAP_OFF
			child.outline_size = 14
			child.line_spacing = -14.0
			child.rotation.z = wobble * 0.5 + float(pass_index) * 0.05
			child.position = Vector3(float(pass_index) * size * 0.02, float(pass_index) * size * 0.015, float(pass_index) * 0.0004)
			made.append(child)
	return made


## Words in Adela's hand. The outline is the same ink, which thickens the stroke.
func _hand(text: String, width_m: float, letter_px := 64) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = HAND
	label.font_size = letter_px
	label.pixel_size = width_m / 430.0
	label.modulate = HAND_INK
	label.outline_modulate = HAND_INK
	label.outline_size = maxi(4, letter_px / 7)
	label.width = 430.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.shaded = true
	label.double_sided = false
	label.visibility_range_end = 9.0
	return label


## A modelled piece of evidence, placed with its back on `at`. `facing.z` is
## the way its face looks and `facing.y` its top. `fit` (metres) shrinks a
## piece too big for its place; zero leaves it life size.
func _piece(item_id: String, facing: Basis, at: Vector3, fit := 0.0) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var body: Node3D = stock.build(item_id) if stock.has(item_id) else null
	var scale := 1.0
	if body == null:
		body = _copy_paper()
		body.transform = Transform3D(_sized(Basis(), 0.12, 0.09) * _paper_square, Vector3.ZERO)
	elif fit > 0.0:
		var size: Vector3 = stock.size(item_id)
		scale = minf(1.0, fit / maxf(maxf(size.x, size.y), 0.001))
	holder.add_child(body)
	var square := facing.orthonormalized()
	holder.global_transform = Transform3D(Basis(square.x * scale, square.y * scale, square.z * scale), at)
	return holder


## The evidence of one anchor, lying where its last object stood.
func _card_for(anchor_id: String) -> void:
	var clue: Dictionary = loop.clue_of(anchor_id)
	var rest := adapter.resolve(str(clue.rest)) as Node3D
	if rest == null:
		errors.append("no rest for %s: %s" % [str(clue.id), str(clue.rest)])
		return
	if _paper == null:
		return
	var offset: Array = clue.get("rest_offset", [0.0, 0.0, 0.0])
	var card := _piece(str(clue.id), Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP),
			rest.global_position + Vector3(float(offset[0]), float(offset[1]), float(offset[2])))
	card.name = "LoopClue_" + str(clue.id)
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
	return _wall_frame * Vector3(_wall_size.x * 0.34, -_wall_size.y * 0.42, 0.0)


## The scissors hang by the foot of the wall. Worked by hand (grab, draw across, let go) they cut the next paper;
## the cutting goes up over the board with its headline in live text. Nothing to cut, or the wall not yet cleared,
## and they stay where they hang.
func _hang_scissors() -> void:
	if not stock.has("scissors") or not stock.has("clipping"):
		return
	var at: Vector3 = _wall_frame * Vector3(-_wall_size.x * 0.40, -_wall_size.y * 0.5 - 0.10, 0.006)
	# Points down, bows up, as on a nail.
	var hung := Basis(-_wall_frame.basis.y, _wall_frame.basis.x, _wall_frame.basis.z)
	scissors = _piece("scissors", hung, at)
	scissors.name = "LoopScissors"
	scissors_grip = Grip.new()
	scissors_grip.name = "Snip"
	scissors.add_child(scissors_grip)
	scissors_grip.configure(scissors, _wall_frame.basis.x, SNIP_REACH)
	scissors_grip.live = func() -> bool: return loop.wall_cleared() and not loop.next_cutting().is_empty()
	scissors_grip.carried = _snipped


func _snipped() -> void:
	var result: Dictionary = loop.cut_clipping()
	if scissors_grip != null:
		scissors_grip.put_back()
	if bool(result.ok):
		_note(wall, "A CUTTING", _headline(str(result.paper)), "CUT")
	_sync()


## What a cutting is headed: the paper's own lead headline for that day, or the paper and day when the catalogue is
## not there to ask.
func _headline(key: String) -> String:
	var paper_id := key.get_slice(":", 0)
	var date := key.get_slice(":", 1)
	if paper_id == "comic":
		var issue: Dictionary = PaperPocket.issue(date)
		return "LILITH No. %d, %s" % [int(issue.get("number", 0)), str(issue.get("title", ""))] if not issue.is_empty() else "LILITH"
	if paper_id == "strip":
		var day: Dictionary = PaperPocket.strip(date)
		return str(day.get("title", "A strip")) if not day.is_empty() else "A strip"
	var catalog := get_tree().get_first_node_in_group("newspaper_catalog")
	if catalog != null:
		var page: Dictionary = catalog.call("issue", paper_id, date)
		var lead: Variant = page.get("lead", {})
		if lead is Dictionary and not str(lead.get("headline", "")).is_empty():
			return str(lead.headline)
	return "%s, %s" % [paper_id.capitalize(), date]


## Cuttings over the board, in the order they were made.
func _sync_clippings() -> void:
	var made: Array = loop.clippings()
	for index in made.size():
		var key := str(made[index])
		if clip_cards.has(key):
			continue
		var column := index % CLIP_COLUMNS
		var row := index / CLIP_COLUMNS
		var roll := (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.30
		var at: Vector3 = _wall_frame * Vector3((-0.42 + 0.84 * float(column) / float(CLIP_COLUMNS - 1)) * _wall_size.x,
				_wall_size.y * 0.5 + 0.11 + 0.15 * float(row), 0.005 + 0.0006 * float(index))
		var level: Vector3 = _wall_frame.basis.x.rotated(_wall_frame.basis.z, roll)
		var card := _piece("clipping", Basis(level, _wall_frame.basis.z.cross(level), _wall_frame.basis.z), at)
		card.name = "LoopClipping_%d" % index
		var words := _words(_headline(key).to_upper(), Basis(), 0.094)
		card.add_child(words)
		words.global_transform = Transform3D(Basis(level, _wall_frame.basis.z.cross(level), _wall_frame.basis.z), at + _wall_frame.basis.z * 0.004 + _wall_frame.basis.z.cross(level) * 0.046)
		clip_cards[key] = card


## Her own prints, under the board in the order they were made (Lily's rulings wall_photos and
## wall_photos_how_20261120). Each is a sheet of paper with the picture the plate took on it. The picture is read
## from the file the camera wrote; a print whose file is gone hangs blank.
func _sync_prints() -> void:
	_sync_waiting_print()
	var made: Array = loop.prints_up()
	for index in made.size():
		var number := int(made[index])
		if print_cards.has(number):
			continue
		var column := index % PRINT_COLUMNS
		var row := index / PRINT_COLUMNS
		var roll := (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.16
		var level: Vector3 = _wall_frame.basis.x.rotated(_wall_frame.basis.z, roll)
		var up: Vector3 = _wall_frame.basis.z.cross(level)
		var at: Vector3 = _wall_frame * Vector3((-0.24 + 0.72 * float(column) / float(PRINT_COLUMNS - 1)) * _wall_size.x,
				-_wall_size.y * 0.5 - 0.34 - 0.17 * float(row), 0.005 + 0.0006 * float(index))
		var card := _copy_paper()
		card.name = "LoopPrint_%d" % number
		add_child(card)
		_place(card, _sized(Basis(level, up, _wall_frame.basis.z), PRINT_SIZE.x, PRINT_SIZE.y), at)
		var path := PhotoSales.picture_path(number)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path)) if FileAccess.file_exists(path) else null
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			var quad := QuadMesh.new()
			quad.size = PRINT_SIZE * 0.88
			var sheet := ArrayMesh.new()
			sheet.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
			var finish := MatLib.get_mat("paper").duplicate() as StandardMaterial3D
			finish.uv1_triplanar = false
			finish.uv1_scale = Vector3.ONE
			finish.uv1_offset = Vector3.ZERO
			finish.albedo_texture = ImageTexture.create_from_image(image)
			# A silver print gone a little warm.
			finish.albedo_color = Color(0.96, 0.90, 0.80)
			finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			var picture := MeshInstance3D.new()
			picture.name = "Picture"
			picture.mesh = sheet
			picture.material_override = finish
			picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			picture.visibility_range_end = 9.0
			card.add_child(picture)
			picture.global_transform = Transform3D(Basis(level, up, _wall_frame.basis.z), at + _wall_frame.basis.z * 0.0022)
			card.set_meta("picture", picture)
		print_cards[number] = card


## The oldest print not yet up waits at the foot of the wall, left of the carried evidence, and is pinned by hand.
func _sync_waiting_print() -> void:
	var number: int = loop.next_print()
	if number == waiting_print_number and (number == 0 or waiting_print != null):
		return
	if waiting_print != null:
		waiting_print.queue_free()
		waiting_print = null
	waiting_print_number = number
	if number <= 0:
		return
	var at: Vector3 = _wall_frame * Vector3(-_wall_size.x * 0.10, -_wall_size.y * 0.42, 0.004)
	waiting_print = _copy_paper()
	waiting_print.name = "LoopPrintWaiting"
	add_child(waiting_print)
	_place(waiting_print, _sized(_wall_frame.basis, PRINT_SIZE.x, PRINT_SIZE.y), at)
	var grip := Grip.new()
	grip.name = "PinPrint"
	waiting_print.add_child(grip)
	grip.configure(waiting_print, Vector3.UP, PIN_REACH)
	grip.live = func() -> bool: return loop.next_print() > 0
	grip.carried = func() -> void:
		grip.put_back()
		if bool(loop.pin_print().ok):
			_note(wall, "A PRINT", "Plate %d, pinned under the board." % number, "PINNED")
		_sync()
	waiting_print.set_meta("grip", grip)


## Her household papers on the wall before it is the case wall: one sheet each, in her hand, to be pulled down by
## hand. A paper already taken down in the save is not put back up.
func _cover_wall() -> void:
	var down: Array = loop.covers_down()
	var count: int = (loop.table.wall_covers as Array).size()
	for index in count:
		var cover: Dictionary = loop.table.wall_covers[index]
		var id := str(cover.id)
		if id in down or loop.wall_cleared():
			continue
		var column := index % 3
		var row := index / 3
		var roll := (fposmod(float(index) * 0.618, 1.0) - 0.5) * 0.22
		var level: Vector3 = _wall_frame.basis.x.rotated(_wall_frame.basis.z, roll)
		var facing := _sized(Basis(level, _wall_frame.basis.z.cross(level), _wall_frame.basis.z), COVER_SIZE.x, COVER_SIZE.y)
		var at: Vector3 = _wall_frame * Vector3((-0.30 + 0.30 * float(column)) * _wall_size.x, (0.22 - 0.36 * float(row)) * _wall_size.y, 0.012 + 0.001 * float(index))
		var sheet := _copy_paper()
		sheet.name = "LoopCover_" + id
		add_child(sheet)
		_place(sheet, facing, at)
		var words := _hand("
".join(PackedStringArray(cover.lines)), COVER_SIZE.x * 0.86, 60)
		sheet.add_child(words)
		words.global_transform = Transform3D(Basis(level, _wall_frame.basis.z.cross(level), _wall_frame.basis.z), at + _wall_frame.basis.z * 0.003)
		var grip := Grip.new()
		grip.name = "TakeDown"
		sheet.add_child(grip)
		grip.configure(sheet, -_wall_frame.basis.y, COVER_REACH)
		grip.live = func() -> bool: return not loop.in_visit() and id not in loop.covers_down()
		grip.carried = func() -> void:
			if loop.cover_down(id):
				grip.set_aside()
		sheet.set_meta("grip", grip)
		covers[id] = sheet


## The carried piece waiting at the foot of the wall for the hand to pin. It is
## built afresh for each piece, because the hand takes hold of its real shape.
func _tuck() -> void:
	tucked = Node3D.new()
	tucked.name = "LoopCarried"
	add_child(tucked)
	tucked.visible = false


func _show_tucked(item_id: String) -> void:
	if item_id == tucked_item and tucked != null:
		tucked.visible = not item_id.is_empty()
		return
	tucked_item = item_id
	if tucked != null:
		tucked.queue_free()
	tucked_grip = null
	if item_id.is_empty():
		_tuck()
		return
	var at := _foot() + _wall_frame.basis.z * 0.004
	tucked = _piece(item_id, _wall_frame.basis, at, 0.2)
	tucked.name = "LoopCarried"
	var label := _words(str(loop.item_text(item_id).title).to_upper(), Basis(), 0.16)
	tucked.add_child(label)
	label.global_transform = Transform3D(_wall_frame.basis, at - _wall_frame.basis.y * 0.13 + _wall_frame.basis.z * 0.003)
	tucked_grip = Grip.new()
	tucked_grip.name = "Pin"
	tucked.add_child(tucked_grip)
	tucked_grip.configure(tucked, Vector3.UP, PIN_REACH)
	tucked_grip.live = func() -> bool: return not loop.in_visit() and not loop.carried().is_empty() and loop.wall_cleared()
	tucked_grip.carried = _pinned


func _note(owner: Node, title: String, body: String, condition: String) -> void:
	var player := world.get("player") as PlayerController
	if player != null:
		player.present_service_note(owner, {"title": title, "body": body, "condition": condition, "stamp": "THE WALL"})


func _pinned() -> void:
	var result: Dictionary = loop.pin_next()
	if tucked_grip != null:
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
		if str(result.get("code", "")) == "unfiled":
			_note(wall, "NOT YET", "Give each piece its day and its place before you join them.", "FILE FIRST")
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


func _ribbon_stock() -> Node3D:
	var strip := _copy_paper()
	if _string_finish == null:
		_string_finish = MatLib.get_mat("paper").duplicate() as StandardMaterial3D
		_string_finish.uv1_triplanar = false
		_string_finish.albedo_color = STRING_RED
		_string_finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	for draw: MeshInstance3D in strip.get_children():
		draw.material_override = _string_finish
	add_child(strip)
	return strip


## Red string, as a narrow strip of the same paper stock dyed red.
func _ribbon(from: Vector3, to: Vector3) -> Node3D:
	var strip := _ribbon_stock()
	var out: Vector3 = _wall_frame.basis.z
	var along := to - from
	_place(strip, _sized(Basis(along.normalized(), out.cross(along.normalized()), out), along.length(), STRING_WIDTH),
			(from + to) * 0.5 + out * 0.009)
	return strip


func _deduction_place(deduction_id: String) -> Vector3:
	var place: int = (loop.ledger().deductions as Array).find(deduction_id)
	# In a row under the board, where there is room to read them.
	return _wall_frame * Vector3(-0.36 + 0.26 * float(place), -_wall_size.y * 0.5 - 0.17, 0.0)


## Bring every card in line with the ledger.
## The year's occasion in a window of the room she is in: 4B at home, the lead's own flat in a visit, dressed for the
## day the clock shows. One piece, hung on the room side of the first window there; gone on an ordinary day.
## The ice card in a window of the room she is in, May to September, turned so the day's pounds stand at the top: its
## four figures are live text round the edges. Hung low on the window, clear of an occasion's piece.
func _sync_ice_card() -> void:
	var unit := "4B"
	if loop.in_visit():
		unit = str(loop.table.anchors.get(loop.visit_anchor(), {}).get("place", "4B"))
	var pounds: int = loop.ice_for(loop.today())
	var key := "%s|%d" % [unit, pounds]
	if key == ice_key:
		return
	ice_key = key
	if ice_card != null:
		ice_card.queue_free()
		ice_card = null
	if pounds <= 0 or not stock.has("ice_card"):
		return
	var figures: Array = []
	for figure: Variant in loop.table.ice_card.figures:
		figures.append(int(figure))
	for node: Node in world.find_children("*", "Node3D", true, false):
		if node.get_script() != WindowTreatment or world.unit_at_world((node as Node3D).global_position) != unit:
			continue
		var dressing := node as Node3D
		var box := AABB()
		var first := true
		for draw: Node in dressing.find_children("*", "VisualInstance3D", true, false):
			var part: AABB = (dressing.global_transform.affine_inverse() * (draw as VisualInstance3D).global_transform) * (draw as VisualInstance3D).get_aabb()
			if part.size.length() < 0.01:
				continue
			box = part if first else box.merge(part)
			first = false
		if first:
			continue
		var thin := box.size.min_axis_index()
		var out := Vector3.ZERO
		out[thin] = 1.0
		var normal: Vector3 = (dressing.global_basis * out).normalized()
		var centre: Vector3 = dressing.global_transform * box.get_center()
		if world.unit_at_world(centre + normal * 0.45) != unit:
			normal = -normal
		# Right-handed (across x up = normal), so a piece is not hung as its mirror image.
		var across := Vector3.UP.cross(normal).normalized()
		var wide := box.size[(thin + 1) % 3] if (thin + 1) % 3 != 1 else box.size[(thin + 2) % 3]
		var at: Vector3 = centre - Vector3.UP * box.size.y * 0.22 + across * wide * 0.28 + normal * (box.size[thin] * 0.5 + 0.03)
		# The card's own figures run 25, 50, 75, 100 clockwise from the top; turned a quarter turn for each step past 25 brings the day's figure to the top.
		var turn := figures.find(pounds)
		var face := Basis(across, Vector3.UP, normal) * Basis(Vector3.BACK, turn * PI / 2.0)
		ice_card = _piece("ice_card", face, at)
		ice_card.name = "LoopIceCard"
		for index in figures.size():
			var label := Label3D.new()
			label.name = "Pounds%d" % int(figures[index])
			label.text = str(figures[index])
			label.font = MASTHEAD_FONTS[0]
			label.font_size = 64
			label.outline_size = 0
			label.modulate = Color(0.10, 0.16, 0.36)
			label.shaded = true
			label.double_sided = false
			label.pixel_size = 0.032 / 64.0
			label.visibility_range_end = 5.0
			ice_card.add_child(label)
			var angle := -index * PI / 2.0
			label.transform = Transform3D(Basis(Vector3.BACK, angle), Basis(Vector3.BACK, angle) * Vector3(0.0, 0.062, 0.0016))
		return


func _sync_occasion() -> void:
	var unit := "4B"
	if loop.in_visit():
		unit = str(loop.table.anchors.get(loop.visit_anchor(), {}).get("place", "4B"))
	var piece: String = loop.occasion_for(loop.today())
	var key := "%s|%s" % [unit, piece]
	if key == occasion_key:
		return
	occasion_key = key
	if occasion != null:
		occasion.queue_free()
		occasion = null
	if piece.is_empty() or not stock.has(piece):
		return
	for node: Node in world.find_children("*", "Node3D", true, false):
		if node.get_script() != WindowTreatment or world.unit_at_world((node as Node3D).global_position) != unit:
			continue
		var dressing := node as Node3D
		var box := AABB()
		var first := true
		for draw: Node in dressing.find_children("*", "VisualInstance3D", true, false):
			var part: AABB = (dressing.global_transform.affine_inverse() * (draw as VisualInstance3D).global_transform) * (draw as VisualInstance3D).get_aabb()
			if part.size.length() < 0.01:
				continue
			box = part if first else box.merge(part)
			first = false
		if first:
			continue
		var thin := box.size.min_axis_index()
		var out := Vector3.ZERO
		out[thin] = 1.0
		var normal: Vector3 = (dressing.global_basis * out).normalized()
		var centre: Vector3 = dressing.global_transform * box.get_center()
		if world.unit_at_world(centre + normal * 0.45) != unit:
			normal = -normal
		# Right-handed (across x up = normal), so a piece is not hung as its mirror image.
		var across := Vector3.UP.cross(normal).normalized()
		var at: Vector3 = centre + Vector3.UP * box.size.y * 0.18 + normal * (box.size[thin] * 0.5 + 0.03)
		occasion = _piece(piece, Basis(across, Vector3.UP, normal), at)
		occasion.name = "LoopOccasion"
		return


func _sync() -> void:
	for clue_id: String in cards:
		var card: Node3D = cards[clue_id]
		var grip: Node = card.get_meta("grip")
		var ready: bool = loop.clue_ready() and str(loop.clue_of(loop.visit_anchor()).id) == clue_id
		if ready and not card.visible:
			grip.put_back()
		card.visible = ready
	_sync_clippings()
	_sync_occasion()
	_sync_ice_card()
	_sync_prints()
	if tucked == null:
		return
	var waiting: Array[String] = loop.carried()
	_show_tucked(waiting[0] if not loop.in_visit() and not waiting.is_empty() else "")
	# Pinned pieces: a slip over the board's own blank one, with a pin to pull.
	for item_id: String in loop.on_wall():
		if wall_cards.has(item_id):
			continue
		var at := slot_position(int(loop.ledger().items[item_id].get("slot", wall_cards.size()))) + _wall_frame.basis.z * 0.004
		var pinned := _piece(item_id, _wall_frame.basis, at, 0.095)
		pinned.name = "LoopPinned_" + item_id
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
		_place(drawn, _sized(_wall_frame.basis, 0.24, 0.25), at)
		var label := _hand(str(loop.table.deductions[str(deduction_id)].line), 0.22, 34)
		drawn.add_child(label)
		label.global_transform = Transform3D(_wall_frame.basis, at + _wall_frame.basis.z * 0.004)
		deduction_cards[str(deduction_id)] = drawn
	_sync_filing()
	_grow()


# --- The year and the maps ----------------------------------------------------------

## A flat piece of the paper stock at a place on the wall (metres from the
## board's centre), dyed.
func _bar(at: Vector2, size: Vector2, tint: Color, lift: float, roll := 0.0) -> Node3D:
	var bar := _copy_paper()
	var key := tint.to_html()
	if not _tints.has(key):
		var finish := MatLib.get_mat("paper").duplicate() as StandardMaterial3D
		finish.uv1_triplanar = false
		finish.albedo_color = tint
		_tints[key] = finish
	for draw: MeshInstance3D in bar.get_children():
		draw.material_override = _tints[key]
	add_child(bar)
	var turned := Basis(_wall_frame.basis.x.rotated(_wall_frame.basis.z, roll), _wall_frame.basis.y.rotated(_wall_frame.basis.z, roll), _wall_frame.basis.z)
	_place(bar, _sized(turned, size.x, size.y), _wall_frame * Vector3(at.x, at.y, lift))
	return bar


func _lettering(text: String, at: Vector2, width: float, lift: float) -> Label3D:
	var label := _words(text, Basis(), width)
	add_child(label)
	label.global_transform = Transform3D(_wall_frame.basis, _wall_frame * Vector3(at.x, at.y, lift))
	return label


## Where a day of the year falls on the tape, in metres from the board's centre.
func day_x(day: int) -> float:
	return (-YEAR_HALF + 2.0 * YEAR_HALF * float(day) / float(loop.days_in_year())) * _wall_size.x


func year_length() -> float:
	return 2.0 * YEAR_HALF * _wall_size.x


## The centre of a place on the building map, in metres from the board's centre.
func cell_at(where: String) -> Vector2:
	var cell: Vector2i = loop._map_cell(loop.table, where)
	var rows: int = (loop.table.filing.places as Array).size()
	var columns: int = (loop.table.filing.columns as Array).size()
	var whole_floor: bool = where in loop.table.filing.places
	var x := MAP_CENTRE.x + (0.0 if whole_floor else (-0.5 + (float(cell.x) + 0.5) / float(columns)) * MAP_SIZE.x)
	return Vector2(x, MAP_CENTRE.y + (0.5 - (float(cell.y) + 0.5) / float(rows)) * (MAP_SIZE.y - 0.1) - 0.05)


## The year across the board, banded by season, and the two maps beside it.
func _dress_wall() -> void:
	var ink := Color(0.1, 0.09, 0.08)
	var y := YEAR_Y * _wall_size.y
	for index in SEASON_BANDS.size() - 1:
		var from := day_x(int(SEASON_BANDS[index][0]))
		var to := day_x(int(SEASON_BANDS[index + 1][0]))
		_bar(Vector2((from + to) * 0.5, y), Vector2(to - from, 0.03), SEASON_BANDS[index][1], 0.004)
		year_parts += 1
	_bar(Vector2(0.0, y), Vector2(year_length(), 0.003), ink, 0.006)
	for month: Array in MONTHS:
		_bar(Vector2(day_x(int(month[0])), y), Vector2(0.002, 0.03), ink, 0.007)
		_lettering(str(month[1]), Vector2(day_x(int(month[0])) + 0.012, y + 0.03), 0.3, 0.007)
	for day: Dictionary in loop.table.calendar:
		_bar(Vector2(day_x(loop.day_of_year(str(day.date))), y - 0.01), Vector2(0.003, 0.012), Color(0.55, 0.05, 0.05), 0.008)
	# The year's events: a mark on the tape at the day each breaks.
	for event: Dictionary in loop.table.events:
		var at := day_x(loop.day_of_year(str(event.breaks)))
		_bar(Vector2(at, y), Vector2(0.006, 0.05), Color(0.1, 0.3, 0.16), 0.009)
		_lettering(str(event.mark), Vector2(at, y - 0.04), 0.18, 0.009)
		year_parts += 1
	# The hours nobody heard.
	_bar(Vector2(day_x(BLACKOUT_DAY), y), Vector2(0.008, 0.05), Color(0.02, 0.02, 0.02), 0.009)
	# The Orison in section.
	_bar(MAP_CENTRE, MAP_SIZE, Color(0.86, 0.82, 0.7), 0.003)
	_lettering("THE ORISON, IN SECTION", Vector2(MAP_CENTRE.x, MAP_CENTRE.y + MAP_SIZE.y * 0.5 - 0.04), 0.5, 0.006)
	var rows: Array = loop.table.filing.places
	var columns: Array = loop.table.filing.columns
	var row_height := (MAP_SIZE.y - 0.1) / float(rows.size())
	var top := MAP_CENTRE.y + (MAP_SIZE.y - 0.1) * 0.5 - 0.05
	for row in rows.size() + 1:
		_bar(Vector2(MAP_CENTRE.x, top - row_height * float(row)), Vector2(MAP_SIZE.x - 0.06, 0.004), ink, 0.005)
	for column in columns.size() + 1:
		var x := MAP_CENTRE.x + (-0.5 + float(column) / float(columns.size())) * (MAP_SIZE.x - 0.06)
		var edge: bool = column == 0 or column == columns.size()
		# Flats are divided only on the six living floors.
		var from_row := 0 if edge else 1
		var to_row := rows.size() if edge else rows.size() - 1
		_bar(Vector2(x, top - row_height * float(from_row + to_row) * 0.5), Vector2(0.004, row_height * float(to_row - from_row)), ink, 0.005)
	for row in rows.size():
		var floor_code := str(rows[row])
		var codes: Array[String] = []
		if floor_code.length() > 1:
			codes.append(floor_code)
		else:
			for column: Variant in columns:
				codes.append(floor_code + str(column))
		for code: String in codes:
			var at := cell_at(code)
			_lettering("BASEMENT" if code == "B1" else code, at + Vector2(0.0, row_height * 0.22), 0.2, 0.006)
			var pin := _bar(at - Vector2(0.0, row_height * 0.16), Vector2(0.034, 0.034), Color(0.55, 0.05, 0.05), 0.008)
			pin.name = "LoopPlace_" + code
			var grip := Grip.new()
			grip.name = "Pull"
			pin.add_child(grip)
			grip.configure(pin, _wall_frame.basis.z, PULL_REACH)
			grip.live = func() -> bool: return not loop.in_visit()
			grip.carried = func() -> void: _cell_pulled(code)
			pin.set_meta("grip", grip)
			cell_pins[code] = pin
	# The neighbourhood, as a sketch.
	_bar(AREA_CENTRE, AREA_SIZE, Color(0.86, 0.82, 0.7), 0.003)
	_bar(AREA_CENTRE + Vector2(-0.05, 0.0), Vector2(0.95, 0.006), ink, 0.005, 0.32)
	_bar(AREA_CENTRE + Vector2(0.0, -0.02), Vector2(0.7, 0.004), ink, 0.005)
	_bar(AREA_CENTRE + Vector2(0.1, 0.0), Vector2(0.004, 0.3), ink, 0.005)
	_bar(AREA_CENTRE + Vector2(0.36, 0.1), Vector2(0.2, 0.012), Color(0.45, 0.55, 0.62), 0.005, -0.5)
	var names: Array = loop.table.neighbourhood
	for index in mini(names.size(), AREA_SPOTS.size()):
		_lettering(str(names[index]), AREA_CENTRE + AREA_SPOTS[index], 0.26, 0.006)
	# The tag that waits for its day.
	loose_tag = _copy_paper()
	loose_tag.name = "LoopTag"
	add_child(loose_tag)
	_place(loose_tag, _sized(_wall_frame.basis, 0.05, 0.065), _wall_frame * Vector3(day_x(0), y - TAG_DROP, 0.011))
	loose_tag_grip = Grip.new()
	loose_tag_grip.name = "Slide"
	loose_tag.add_child(loose_tag_grip)
	loose_tag_grip.gesture = Vector2.RIGHT
	loose_tag_grip.configure(loose_tag, _wall_frame.basis.x, year_length())
	loose_tag_grip.live = func() -> bool: return not loop.in_visit() and not loose_tag_item.is_empty()
	loose_tag_grip.settle = _tag_let_go
	loose_tag.visible = false


## The tag was let go somewhere along the year.
func _tag_let_go(travel: float) -> float:
	if loose_tag_item.is_empty():
		return -1.0
	var day := int(round(travel / year_length() * float(loop.days_in_year())))
	var item_id := loose_tag_item
	var result: Dictionary = loop.file_date(item_id, day)
	if not result.ok:
		return -1.0
	if not bool(result.held):
		_note(wall, "IT WILL NOT STAY", "%s does not belong to that part of the year." % str(loop.item_text(item_id).title), "NO")
		return -1.0
	return -1.0 # filed: _sync has hung its own tag, and this one goes back for the next


## A room's pin on the map was pulled. With the string in hand it is run there.
func _cell_pulled(where: String) -> void:
	((cell_pins[where] as Node3D).get_meta("grip") as Node).put_back()
	if string_from.is_empty():
		_note(wall, where, "Take up the string from a piece first: pull its pin.", "THE MAP")
		return
	var item_id := string_from
	string_from = ""
	var result: Dictionary = loop.file_place(item_id, where)
	if result.ok and not bool(result.held):
		_note(wall, "THE STRING FALLS", "%s was not found in %s." % [str(loop.item_text(item_id).title), "the basement" if where == "B1" else where], "NO")
	_sync()


func _sync_filing() -> void:
	if loose_tag == null:
		return
	var y := YEAR_Y * _wall_size.y - TAG_DROP
	# The tag waiting for its day.
	var waiting: String = "" if loop.in_visit() else str(loop.undated())
	if waiting != loose_tag_item:
		loose_tag_item = waiting
		loose_tag_grip.put_back()
		for old: Node in loose_tag.find_children("*", "Label3D", true, false):
			old.free()
		if not waiting.is_empty():
			var label := _words(str(loop.item_text(waiting).title).to_upper(), Basis(), 0.046)
			loose_tag.add_child(label)
			label.global_transform = Transform3D(_wall_frame.basis, loose_tag.global_transform * Vector3.ZERO + _wall_frame.basis.z * 0.004)
			label.global_position = _wall_frame * Vector3(day_x(0), y, 0.014)
	loose_tag.visible = not loose_tag_item.is_empty()
	# Tags that have their day.
	for item_id: String in loop.on_wall():
		if loop.dated(item_id) and not date_tags.has(item_id):
			var at := Vector2(day_x(loop.item_day(item_id)), y - 0.07 * float(date_tags.size() % 2))
			var tag := _bar(at, Vector2(0.05, 0.065), Color(0.93, 0.9, 0.8), 0.01)
			tag.name = "LoopDated_" + item_id
			var label := _words(str(loop.item_text(item_id).title).to_upper(), Basis(), 0.046)
			tag.add_child(label)
			label.global_transform = Transform3D(_wall_frame.basis, _wall_frame * Vector3(at.x, at.y, 0.013))
			tag.set_meta("at", at)
			date_tags[item_id] = tag
		if loop.placed(item_id) and date_tags.has(item_id) and not place_strings.has(item_id):
			var from: Vector2 = (date_tags[item_id] as Node3D).get_meta("at")
			var to := cell_at(loop.item_where(item_id)) - Vector2(0.0, 0.03)
			place_strings[item_id] = _ribbon(_wall_frame * Vector3(from.x, from.y, 0.004), _wall_frame * Vector3(to.x, to.y, 0.004))
	for item_id: String in date_tags.keys():
		if not loop.dated(item_id):
			(date_tags[item_id] as Node).queue_free()
			date_tags.erase(item_id)
	for item_id: String in place_strings.keys():
		if not loop.placed(item_id):
			(place_strings[item_id] as Node).queue_free()
			place_strings.erase(item_id)


# --- The case takes the flat -------------------------------------------------------
# The flat comes unhinged by degrees. Paper spreads from the board over every
# room of 4B, gathered newspapers pile up along the walls and on the furniture,
# and red string webs across the rooms overhead. At the finished case there is
# no clear surface left.

## Find where paper can go: every upright surface in sight of the middle of
## each room of 4B, nearest the board first; and under those, where a pile of
## newspapers can stand. Done once, on a physics frame.
func _survey() -> void:
	surveyed = true
	var space := world.get_world_3d().direct_space_state
	if space == null:
		return
	var out: Vector3 = _wall_frame.basis.z
	var floor_y := floorf((_wall_frame.origin.y + 0.05) / 3.2) * 3.2
	var eyes: Array[Vector3] = [_wall_frame.origin + out * 1.5]
	for object_id: String in ROOM_EYES:
		var thing := adapter.resolve(object_id) as Node3D
		if thing != null and world.unit_at_world(thing.global_position) == "4B":
			eyes.append(thing.global_position)
	for corner: Vector2 in [MAP_CENTRE + MAP_SIZE * 0.45, MAP_CENTRE - MAP_SIZE * 0.45, AREA_CENTRE + AREA_SIZE * 0.45, AREA_CENTRE - AREA_SIZE * 0.45]:
		var from: Vector3 = _wall_frame * Vector3(corner.x, corner.y, 0.4)
		var behind := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - out * 0.7))
		if behind.is_empty() or absf(from.distance_to(behind.position) - 0.4) > 0.12:
			errors.append("no wall behind the map at %s" % str(corner))
	var found: Array[Dictionary] = []
	var cells := {}
	for eye_index in eyes.size():
		var eye := eyes[eye_index]
		for index in SURVEY_RAYS:
			var yaw := float(index) * 2.399963 + float(eye_index)
			var height := floor_y + 0.25 + 2.3 * fposmod(float(index) * 0.7548776662 + float(eye_index) * 0.37, 1.0)
			var from := Vector3(eye.x, height, eye.z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(cos(yaw), 0.0, sin(yaw)) * 9.0))
			if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.2 or from.distance_to(hit.position) < 0.35:
				continue
			var where: Vector3 = hit.position
			var on_board: Vector3 = _wall_frame.affine_inverse() * where
			if absf(on_board.z) < 0.08 and absf(on_board.x) < _wall_size.x * 0.5 + 0.3 and on_board.y < _wall_size.y * 0.5 + 0.06 					and on_board.y > -_wall_size.y * 0.5 - 0.34:
				continue
			if absf(on_board.z) < 0.08 and absf(on_board.x - MAP_CENTRE.x) < MAP_SIZE.x * 0.5 + 0.04 \
					and on_board.y < MAP_CENTRE.y + MAP_SIZE.y * 0.5 + 0.04 and on_board.y > AREA_CENTRE.y - AREA_SIZE.y * 0.5 - 0.04:
				continue
			if world.unit_at_world(where) != "4B":
				continue
			var cell := Vector3i((where / 0.19).round())
			if cells.has(cell):
				continue
			cells[cell] = true
			found.append({"position": where, "normal": (hit.normal as Vector3).normalized(), "far": where.distance_to(_wall_frame.origin)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.far) < float(b.far))
	spots = _thinned(found, MAX_SHEETS)
	# Piles: straight down from a little out from each papered place.
	var piles: Array[Dictionary] = []
	var pile_cells := {}
	for spot: Dictionary in spots:
		var above: Vector3 = (spot.position as Vector3) + (spot.normal as Vector3) * 0.3
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 3.2))
		if hit.is_empty() or (hit.normal as Vector3).y < 0.9 or world.unit_at_world(hit.position as Vector3) != "4B":
			continue
		var cell := Vector3i(((hit.position as Vector3) / 0.42).round())
		if pile_cells.has(cell):
			continue
		pile_cells[cell] = true
		piles.append({"position": hit.position, "far": float(spot.far)})
	pile_spots = _thinned(piles, MAX_PILES)
	# Cups: level tops at table to shelf height around each place someone sits or works, not the bed or the couch.
	var skip: Array[Node] = []
	for object_id: String in MUG_SKIP:
		var thing := adapter.resolve(object_id) as Node
		if thing != null:
			skip.append(thing)
	var cups: Array[Dictionary] = []
	var cup_cells := {}
	for eye: Vector3 in eyes:
		for step_x in range(-6, 7):
			for step_z in range(-6, 7):
				var at := Vector3(eye.x + float(step_x) * 0.2, floor_y + 1.45, eye.z + float(step_z) * 0.2)
				var top := _level_top(space, at, floor_y, skip)
				if top == Vector3.INF:
					continue
				var cell := Vector3i((top / 0.4).round())
				if cup_cells.has(cell):
					continue
				cup_cells[cell] = true
				cups.append({"position": top, "far": top.distance_to(_wall_frame.origin)})
	cups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.far) < float(b.far))
	mug_spots = _thinned(cups, MAX_MUGS)
	# The web's anchors: papered places above head height.
	for spot: Dictionary in spots:
		if (spot.position as Vector3).y > floor_y + 1.85:
			high_spots.append(spot)
	_grow()


## A level top for a cup straight below `from`: facing up, between table and shelf height, in 4B, not on what
## `skip` holds, and level for a cup's width all round (not an edge). Vector3.INF where there is none.
func _level_top(space: PhysicsDirectSpaceState3D, from: Vector3, floor_y: float, skip: Array[Node]) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.3))
	if hit.is_empty() or (hit.normal as Vector3).y < 0.97:
		return Vector3.INF
	var where: Vector3 = hit.position
	if where.y - floor_y < 0.42 or where.y - floor_y > 1.15 or world.unit_at_world(where) != "4B":
		return Vector3.INF
	var collider := hit.collider as Node
	for thing: Node in skip:
		if collider == thing or thing.is_ancestor_of(collider):
			return Vector3.INF
	for side: Vector3 in [Vector3(0.06, 0, 0), Vector3(-0.06, 0, 0), Vector3(0, 0, 0.06), Vector3(0, 0, -0.06)]:
		var near := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + side, from + side + Vector3.DOWN * 1.3))
		if near.is_empty() or absf((near.position as Vector3).y - where.y) > 0.004:
			return Vector3.INF
	return where


## At most `limit` of the places found, taken evenly so they still reach the
## far rooms, and still nearest the board first.
func _thinned(found: Array[Dictionary], limit: int) -> Array[Dictionary]:
	if found.size() <= limit:
		return found
	var kept: Array[Dictionary] = []
	for index in limit:
		kept.append(found[index * found.size() / limit])
	return kept


## Everything up to the case's present spread, nearest the board first.
func _grow() -> void:
	if not surveyed or _paper == null:
		return
	var share: float = loop.spread_fraction()
	var scrawls: Array = loop.table.scrawls
	var tics: Array = loop.table.tics
	# Paper on the walls and furniture.
	var count: int = int(ceil(float(spots.size()) * pow(share, 1.5)))
	while papers.size() < count:
		var index := papers.size()
		var spot: Dictionary = spots[index]
		var normal: Vector3 = spot.normal
		var across := Vector3.UP.cross(normal).normalized()
		var roll := (fposmod(float(index) * 0.7548776, 1.0) - 0.5) * 0.6
		var size := 0.17 + 0.2 * fposmod(float(index) * 0.5698403, 1.0)
		var level := across.rotated(normal, roll)
		var facing := _sized(Basis(level, normal.cross(level), normal), size, size * (0.72 + 0.5 * fposmod(float(index) * 0.3247, 1.0)))
		var sheet := _copy_paper()
		sheet.name = "LoopPaper_%d" % index
		add_child(sheet)
		var at: Vector3 = (spot.position as Vector3) + normal * (0.004 + 0.0004 * float(index % 5))
		_place(sheet, facing, at)
		if index % MESSAGE_EVERY == 0 and not scrawls.is_empty():
			# Fewer messages, each one whole (Lily, 2026-11-19). The hand goes with the case: neat near the board,
			# then loud, then one word over and over out in the far rooms.
			var turn := index / MESSAGE_EVERY
			var gone := float(index) / float(maxi(1, spots.size() - 1))
			for label: Label3D in _message(str(scrawls[turn % scrawls.size()]), str(tics[turn % tics.size()]), size, gone, turn):
				var lean := label.rotation.z
				var shift := label.position
				sheet.add_child(label)
				label.global_transform = Transform3D(Basis(level, normal.cross(level), normal).rotated(normal, lean),
						at + normal * (0.003 + shift.z) + level * shift.x + normal.cross(level) * shift.y)
		papers.append(sheet)
	for index in papers.size():
		(papers[index] as Node3D).visible = index < count
	# Gathered newspapers, in piles that grow.
	var pile_count: int = int(ceil(float(pile_spots.size()) * pow(share, 1.6))) if _bundle != null else 0
	while piles.size() < pile_count:
		var index := piles.size()
		var pile := _copy_of(_bundle)
		pile.name = "LoopPile_%d" % index
		add_child(pile)
		piles.append(pile)
	for index in piles.size():
		var pile: Node3D = piles[index]
		pile.visible = index < pile_count
		if not pile.visible:
			continue
		# A pile is as tall as the case is far along, and each differs.
		var tall := 0.04 + (0.1 + 0.55 * fposmod(float(index) * 0.4142, 1.0)) * share
		var wide := 0.3 + 0.1 * fposmod(float(index) * 0.2718, 1.0)
		var turn := Basis(Vector3.UP, float(index) * 1.7)
		var stretch := Basis(turn.x * (wide / _bundle_size.x), Vector3.UP * (tall / _bundle_size.y), turn.z * (wide * 0.72 / _bundle_size.z))
		pile.global_transform = Transform3D(stretch, (pile_spots[index].position as Vector3) - stretch * _bundle_foot)
		# A tied bundle of newspapers on top of each pile.
		if stock.has("bundle"):
			while pile_tops.size() <= index:
				var top: Node3D = stock.build("bundle")
				top.name = "LoopBundle_%d" % pile_tops.size()
				add_child(top)
				_masthead(top, pile_tops.size())
				pile_tops.append(top)
			var away: Vector3 = turn.z
			pile_tops[index].global_transform = Transform3D(Basis(away.cross(Vector3.UP), away, Vector3.UP),
					(pile_spots[index].position as Vector3) + Vector3.UP * tall)
	for index in pile_tops.size():
		pile_tops[index].visible = index < pile_count
	# Cups left standing where they were put down, more as the case goes on.
	var mug_count: int = int(ceil(float(mug_spots.size()) * clampf((share - MUGS_FROM) / (1.0 - MUGS_FROM), 0.0, 1.0))) \
			if _mug != null else 0
	while mugs.size() < mug_count:
		var index := mugs.size()
		var mug := _copy_of(_mug)
		mug.name = "LoopMug_%d" % index
		add_child(mug)
		var turn := Basis(Vector3.UP, fposmod(float(index) * 2.399963, TAU))
		mug.global_transform = Transform3D(turn, (mug_spots[index].position as Vector3) + Vector3.UP * 0.0005 - turn * _mug_foot)
		mugs.append(mug)
	for index in mugs.size():
		mugs[index].visible = index < mug_count
	# Late in the case the windows go: paper over the glass, sheet by sheet (plan, section 4: "windows papered over").
	if not windows_found:
		_find_windows()
	var covered := clampf((share - WINDOWS_FROM) / (1.0 - WINDOWS_FROM), 0.0, 1.0)
	var window_count := int(ceil(float(window_spots.size()) * covered))
	while window_papers.size() < window_count:
		var index := window_papers.size()
		var spot: Dictionary = window_spots[index]
		var sheet := _copy_paper()
		sheet.name = "LoopWindowPaper_%d" % index
		add_child(sheet)
		var normal: Vector3 = spot.normal
		var level: Vector3 = (spot.across as Vector3).rotated(normal, (fposmod(float(index) * 0.7548776, 1.0) - 0.5) * 0.35)
		_place(sheet, _sized(Basis(level, normal.cross(level), normal), float(spot.wide), float(spot.tall)), spot.position)
		window_papers.append(sheet)
	for index in window_papers.size():
		(window_papers[index] as Node3D).visible = index < window_count
	# The web: red string overhead, from the board outward and wall to wall.
	var strand_count: int = int(float(MAX_STRANDS) * clampf((share - 0.1) / 0.9, 0.0, 1.0)) if high_spots.size() >= 4 else 0
	while strands.size() < strand_count:
		var index := strands.size()
		var total := high_spots.size()
		var from: Vector3 = _wall_frame * Vector3((fposmod(float(index) * 0.618, 1.0) - 0.5) * _wall_size.x, _wall_size.y * 0.5, 0.0) \
				if index % 3 == 0 else (high_spots[(index * 7) % total].position as Vector3)
		var to: Vector3 = high_spots[(index * 7 + total / 2 + index) % total].position
		if from.distance_to(to) < 0.4:
			to = high_spots[(index * 11 + 3) % total].position
		strands.append(_strand(from, to))
	for index in strands.size():
		(strands[index] as Node3D).visible = index < strand_count


## The top paper of a tied bundle shows its name: the Record in black letter, the Speaker in red (plan, section 4:
## "their mastheads showing"). Live text on the paper, never in a texture. The bundle's own +Z is its top face.
func _masthead(top: Node3D, index: int) -> void:
	var box := AABB()
	var first := true
	for draw: MeshInstance3D in top.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = draw.transform * draw.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return
	var speaker := index % 2 == 1
	var label := Label3D.new()
	label.name = "Masthead"
	label.text = MASTHEADS[1] if speaker else MASTHEADS[0]
	label.font = MASTHEAD_FONTS[1] if speaker else MASTHEAD_FONTS[0]
	label.font_size = 64
	label.outline_size = 0
	label.modulate = Color(0.45, 0.07, 0.06) if speaker else Color(0.08, 0.08, 0.09)
	label.shaded = true
	label.double_sided = false
	label.pixel_size = box.size.x * 0.82 / maxf(1.0, label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x)
	label.visibility_range_end = 5.0
	top.add_child(label)
	label.position = Vector3(box.get_center().x, box.position.y + box.size.y * 0.80, box.end.z + 0.0015)


## Where paper would cover 4B's windows: a grid of overlapping sheets over each window's dressing, on the room side,
## taken window by window so one goes dark before the next is begun. Measured from what hangs there; nothing is moved.
func _find_windows() -> void:
	windows_found = true
	for node: Node in world.find_children("*", "Node3D", true, false):
		if node.get_script() != WindowTreatment:
			continue
		var dressing := node as Node3D
		if world.unit_at_world(dressing.global_position) != "4B":
			continue
		var box := AABB()
		var first := true
		for draw: Node in dressing.find_children("*", "VisualInstance3D", true, false):
			var part: AABB = (dressing.global_transform.affine_inverse() * (draw as VisualInstance3D).global_transform) * (draw as VisualInstance3D).get_aabb()
			if part.size.length() < 0.01:
				continue
			box = part if first else box.merge(part)
			first = false
		if first:
			continue
		var thin := box.size.min_axis_index()
		var wide := 0 if thin != 0 else 2
		var out := Vector3.ZERO
		out[thin] = 1.0
		var normal: Vector3 = (dressing.global_basis * out).normalized()
		var centre: Vector3 = dressing.global_transform * box.get_center()
		if world.unit_at_world(centre + normal * 0.45) != "4B":
			normal = -normal
		var across := Vector3.ZERO
		across[wide] = 1.0
		across = (dressing.global_basis * across).normalized()
		var half_thin: float = box.size[thin] * 0.5
		for row in WINDOW_ROWS:
			for column in WINDOW_COLUMNS:
				var u := (float(column) + 0.5) / float(WINDOW_COLUMNS) - 0.5
				var v := 0.5 - (float(row) + 0.5) / float(WINDOW_ROWS)
				var count := window_spots.size()
				window_spots.append({"position": centre + across * (u * box.size[wide]) + Vector3.UP * (v * box.size.y) + normal * (half_thin + 0.012 + 0.0008 * float(count % 7)),
						"normal": normal, "across": across, "wide": box.size[wide] / float(WINDOW_COLUMNS) * 1.25, "tall": box.size.y / float(WINDOW_ROWS) * 1.25})


## Red string through the air between two points.
func _strand(from: Vector3, to: Vector3) -> Node3D:
	var strip := _ribbon_stock()
	var along := to - from
	var side := along.cross(Vector3.UP)
	side = Vector3.RIGHT if side.length() < 0.001 else side.normalized()
	_place(strip, _sized(Basis(along.normalized(), side, along.normalized().cross(side)), maxf(along.length(), 0.01), STRING_WIDTH), (from + to) * 0.5)
	return strip


func _physics_process(_delta: float) -> void:
	if not surveyed and wall != null and _paper != null and world.get("startup_ms") != null and float(world.startup_ms) > 0.0:
		_survey()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.25 or loop == null:
		return
	_poll = 0.0
	# A conversation that ended without saying so must not hold the clock for good.
	if _talk_held:
		var talk: Variant = world.get("conversations")
		if talk is not Node or str((talk as Node).get("_active_resident")) == "":
			_talk_held = false
			loop.release_pace("talk")
	# A call at the desk has no start of its own to listen for: it is asked.
	var desk: Variant = world.get("call_interface")
	var on_call: bool = desk is Node and int((desk as Node).get("stage")) != 0
	if on_call != _call_held:
		_call_held = on_call
		if on_call:
			loop.hold_pace("call")
		else:
			loop.release_pace("call")
	# Where the player stands, for the last night's roof: a unit, else a place.
	var unit := str(world.player_unit())
	loop.here = unit if unit != "" or not world.has_method("player_agenda_place") 			else str(world.call("player_agenda_place"))
	if loop.in_visit():
		loop.observe(unit)
