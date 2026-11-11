extends "res://scripts/props/dead_letters_prop.gd"
## Dead letters in V2: the sorting desk in the house office, worked by hand
## (Lily, v1r_dead_letters: direct manipulation, no panel).
##
## V1's DeadLetters keeps every rule: the deck, the tray of eight, what is
## right, what it scores, what is recorded as astray and what a dead letter
## teaches. This script only puts the letter in the hand. The top letter is
## taken from the tray and slid along the brass rail at the foot of the rack
## to a stack (A to D) or to the dead-letter box at the end; standing there
## it is lifted up the face of the stack and let go at a floor, which files
## it in that hole. Let go low, it sinks back to the rail and nothing is
## filed. A letter filed right stays in its hole; one filed wrong is handed
## back to the tray, on edge against the back, and the round goes on as V1
## scores it. When the tray is empty its handle draws a fresh one.
const Manipulation := preload("res://scripts/props/manipulation_area.gd")
## V1's three papers (dead_letters_prop.gd), none of them white.
const PAPERS: Array[Color] = [Color(0.86, 0.83, 0.74), Color(0.80, 0.78, 0.72), Color(0.74, 0.70, 0.60)]
## The bank's own elevation, as V1's panel drew it: four stacks, six floors,
## floor six at the top.
const STACKS := 4
const FLOORS := 6
const DEAD_STOP := STACKS + 1
## Along the rail, where a letter leaving the tray stands up on its edge.
const STANDS_AT := 0.10
const TRAY_DRAW := 0.10
const LYING := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))

var stock: RefCounted
var game := DeadLetters.new()
## V1's verdict on the last letter let go.
var reveal: Dictionary = {}
var letters: Array[Node3D] = []
var carriage: Node3D
var tray: Node3D
var tally: Label3D
## The letter in hand: along the rail from the tray, up the face of the rack,
## and the stop it stands at (0 the tray, 1 to 4 the stacks, 5 the dead box).
var along := 0.0
var lift := 0.0
var stop := 0
var _held := ""
var _tray_out := 0.0
var _tray_rest := Vector3.ZERO
var _carriage_rest := Vector3.ZERO
var _address: Label3D
var _clues: Label3D
var _in_hole: Dictionary = {}
var _handed_back := 0


func _build_visual() -> void:
	add_child(stock.part_node("sorting_desk", "Body"))
	tray = stock.part_node("sorting_desk", "Tray")
	add_child(tray)
	_tray_rest = tray.position
	carriage = stock.part_node("sorting_desk", "Carriage")
	add_child(carriage)
	_carriage_rest = carriage.position
	_rustle = make_emitter("tick", -18.0)
	if not game.load_deck():
		push_error("dead letters desk: no deck")
		return
	# The cards over the holes: unit and name, as V1's panel lettered them.
	for floor_index in FLOORS:
		for stack in STACKS:
			var box: Dictionary = game.boxes[(FLOORS - 1 - floor_index) * STACKS + stack]
			var names: Array = box.get("names", [])
			var text := str(box.get("unit", ""))
			if bool(box.get("player", false)):
				text += "  you"
			elif not names.is_empty():
				var name_words := str(names[0]).split(" ")
				text += "  " + name_words[name_words.size() - 1]
			var card: Label3D = stock.words(text, 0.2, 0.015)
			card.position = stock.row_labels[floor_index][stack]
			add_child(card)
	var drawer: Label3D = stock.words("DEAD LETTERS", 0.21, 0.02)
	drawer.position = stock.dead_label
	add_child(drawer)
	tally = stock.words("", stock.tally_width, 0.0085)
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tally.transform = Transform3D(LYING, stock.tally)
	add_child(tally)
	_address = stock.words("", 0.21, 0.014)
	_address.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_address.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_address.position = Vector3(0.0, 0.124, 0.0024)
	_clues = stock.words("", 0.21, 0.0085)
	_clues.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_clues.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_clues.position = Vector3(0.0, 0.082, 0.0024)
	Manipulation.install(carriage, _carriage_grip)
	for draw: MeshInstance3D in tray.find_children("*", "MeshInstance3D", true, false):
		if str(draw.get_meta("house_office_part", "")).ends_with("_ON_brass"):
			Manipulation.install(draw, _tray_grip)
	deal()


## The desk is worked by hand; there is nothing to open.
func interact_prompt() -> String:
	return ""


func interact(_player: Node) -> void:
	pass


## A fresh tray, as V1 dealt one each time the post was taken up.
func deal(seed_value := 0) -> void:
	for label: Label3D in [_address, _clues]:
		if label.get_parent() != null:
			label.get_parent().remove_child(label)
	for letter: Node3D in letters:
		letter.get_parent().remove_child(letter)
		letter.queue_free()
	letters.clear()
	_in_hole.clear()
	_handed_back = 0
	_held = ""
	reveal = {}
	game.start(seed_value)
	for index in game.tray.size():
		var letter: Node3D = stock.part_node("sorting_desk", "Letter", PAPERS[index % PAPERS.size()])
		letter.name = "Letter_%d" % index
		add_child(letter)
		letter.transform = Transform3D(LYING, _on_tray(index))
		Manipulation.install(letter, _letter_grip.bind(index))
		letters.append(letter)
	_take_up()
	_refresh()


func in_hand() -> Node3D:
	return null if game.done() else letters[game.at]


## Where a filed letter went: its node, still at the desk.
func letter_node(index: int) -> Node3D:
	return letters[index]


func stop_position(which: int) -> float:
	if which <= 0:
		return 0.0
	return stock.dead_stop if which == DEAD_STOP else stock.stops[which - 1]


## The unit the letter in hand stands before at this height, "" when it has
## not been lifted to a hole.
func unit_before() -> String:
	if stop == 0:
		return ""
	if stop == DEAD_STOP:
		return DeadLetters.DEAD if lift >= stock.dead_lift * 0.5 else ""
	if lift < stock.rows[0] * 0.5:
		return ""
	return str(game.boxes[(FLOORS - 1 - _floor_before()) * STACKS + stop - 1].get("unit", ""))


## The lift that stands a letter before `unit` at stop `which`; less than
## zero when the unit is not in that stack.
func lift_for(which: int, unit: String) -> float:
	if which == DEAD_STOP:
		return stock.dead_lift if unit == DeadLetters.DEAD else -1.0
	for floor_index in FLOORS:
		if which >= 1 and str(game.boxes[(FLOORS - 1 - floor_index) * STACKS + which - 1].get("unit", "")) == unit:
			return stock.rows[floor_index]
	return -1.0


func _floor_before() -> int:
	var nearest := 0
	for floor_index in FLOORS:
		if absf(lift - float(stock.rows[floor_index])) < absf(lift - float(stock.rows[nearest])):
			nearest = floor_index
	return nearest


func _on_tray(index: int) -> Vector3:
	return stock.tray + Vector3(0.0, float(game.tray.size() - 1 - index) * stock.sheet, 0.0)


func _take_up() -> void:
	along = 0.0
	lift = 0.0
	stop = 0
	for label: Label3D in [_address, _clues]:
		if label.get_parent() != null:
			label.get_parent().remove_child(label)
	if game.done():
		carriage.position = _carriage_rest
		return
	var face := game.face_of(game.current())
	_address.text = "%s\n%s" % [str(face[0]), str(face[1])]
	var lines := PackedStringArray()
	for index in range(2, face.size()):
		lines.append("· " + str(face[index]))
	_clues.text = "\n".join(lines)
	letters[game.at].add_child(_address)
	letters[game.at].add_child(_clues)
	_pose()


func _pose() -> void:
	if game.done():
		return
	var held := letters[game.at]
	if stop == 0 and along < STANDS_AT:
		held.transform = Transform3D(LYING, _on_tray(game.at) + Vector3(along, 0.0, 0.0))
	else:
		held.transform = Transform3D(Basis(), stock.rail + Vector3(along, lift, 0.0))
	carriage.position = _carriage_rest + Vector3(maxf(along - stock.carriage_home, 0.0), 0.0, 0.0)


func _letter_grip(index: int) -> Dictionary:
	if game.done() or index != game.at or _held != "":
		return {}
	if stop == 0:
		return {"owner": self, "part": letters[index], "frame": self, "kind": "slide", "axis": Vector3.RIGHT,
			"minimum": 0.0, "maximum": stock.dead_stop, "read": func() -> float: return along,
			"write": _ride.bind("letter"), "begin": _take.bind("letter"), "owns": _has.bind("letter"), "end": _rest_on_rail}
	return {"owner": self, "part": letters[index], "frame": self, "kind": "slide", "axis": Vector3.UP,
		"minimum": 0.0, "maximum": stock.dead_lift if stop == DEAD_STOP else stock.rows[FLOORS - 1],
		"read": func() -> float: return lift, "write": _raise, "begin": _take.bind("lift"), "owns": _has.bind("lift"),
		"end": _let_go}


## The clip under a standing letter: it slides the letter to another stack,
## or back to the tray.
func _carriage_grip() -> Dictionary:
	if game.done() or stop == 0 or lift > 0.0 or _held != "":
		return {}
	return {"owner": self, "part": carriage, "frame": self, "kind": "slide", "axis": Vector3.RIGHT,
		"minimum": 0.0, "maximum": stock.dead_stop, "read": func() -> float: return along,
		"write": _ride.bind("carriage"), "begin": _take.bind("carriage"), "owns": _has.bind("carriage"), "end": _rest_on_rail}


## The empty tray's handle: drawn out toward the hand, it comes back full.
func _tray_grip() -> Dictionary:
	if not game.done() or _held != "":
		return {}
	return {"owner": self, "part": tray, "frame": self, "kind": "slide", "axis": Vector3.BACK,
		"minimum": 0.0, "maximum": TRAY_DRAW, "read": func() -> float: return _tray_out,
		"write": _draw_tray, "begin": _take.bind("tray"), "owns": _has.bind("tray"), "end": _tray_let_go}


func _take(what: String) -> bool:
	if _held != "":
		return false
	_held = what
	return true


func _has(what: String) -> bool:
	return _held == what


func _ride(value: float, what: String) -> void:
	if _held != what or not is_finite(value):
		return
	along = clampf(value, 0.0, stock.dead_stop)
	_pose()


## Let go along the rail, the letter comes to rest at the nearest stop.
func _rest_on_rail() -> void:
	_held = ""
	var nearest := 0
	for which in DEAD_STOP + 1:
		if absf(along - stop_position(which)) < absf(along - stop_position(nearest)):
			nearest = which
	stop = nearest
	along = stop_position(stop)
	lift = 0.0
	_pose()


func _raise(value: float) -> void:
	if _held != "lift" or not is_finite(value):
		return
	lift = clampf(value, 0.0, stock.dead_lift if stop == DEAD_STOP else stock.rows[FLOORS - 1])
	_pose()


## Let go up the face of the rack: before a hole, V1 judges it; lower, the
## letter sinks back to the rail.
func _let_go() -> void:
	_held = ""
	var unit := unit_before()
	if unit.is_empty():
		lift = 0.0
		_pose()
		return
	var filed := letters[game.at]
	var hole_lift: float = stock.dead_lift if stop == DEAD_STOP else stock.rows[_floor_before()]
	reveal = game.file_into(unit)
	if _rustle != null:
		_rustle.play()
	var grip := filed.get_node_or_null("ManipulationTarget")
	if grip != null:
		filed.remove_child(grip)
		grip.queue_free()
	if bool(reveal.get("right", false)):
		var already := int(_in_hole.get(unit, 0))
		_in_hole[unit] = already + 1
		filed.transform = Transform3D(LYING, stock.rail + Vector3(along, hole_lift + float(already) * stock.sheet,
				stock.dead_front if stop == DEAD_STOP else stock.hole_front))
	else:
		# Handed back: on edge against the back of the tray, out of the round.
		filed.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-5.0)),
				stock.astray + Vector3(0.0, 0.0, float(_handed_back) * 0.0045))
		filed.reparent(tray)
		_handed_back += 1
	filed.set_meta("dead_letters_went_to", unit)
	_take_up()
	_refresh()


func _draw_tray(value: float) -> void:
	if _held != "tray" or not is_finite(value):
		return
	_tray_out = clampf(value, 0.0, TRAY_DRAW)
	tray.position = _tray_rest + Vector3.BACK * _tray_out


func _tray_let_go() -> void:
	_held = ""
	var drawn := _tray_out >= TRAY_DRAW * 0.9
	_tray_out = 0.0
	tray.position = _tray_rest
	if drawn:
		deal()


## The tally slip: V1's panel's own lines.
func _refresh() -> void:
	var lines := PackedStringArray()
	if game.done():
		lines.append("TRAY EMPTY")
		lines.append("%d filed, %d gone astray." % [game.filed, game.missed])
		for stray: Dictionary in game.misfiled:
			lines.append("%s went to %s — should have been %s" % [str(stray["to"]), str(stray["went_to"]), str(stray["belonged"])])
		lines.append("nothing here is undone; a letter in the wrong box is just somewhere else now.")
	else:
		lines.append("TRAY  %d of %d" % [mini(game.at + 1, game.tray.size()), game.tray.size()])
	lines.append("filed      %d" % game.filed)
	lines.append("astray     %d" % game.missed)
	lines.append("score      %d" % game.score)
	if not reveal.is_empty():
		lines.append("RIGHT" if bool(reveal["right"]) else "ASTRAY")
		lines.append(str(reveal["why"]))
	tally.text = "\n".join(lines)
