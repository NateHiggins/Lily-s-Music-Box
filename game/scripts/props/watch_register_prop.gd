class_name WatchRegisterProp
extends FunctionalProp
## The watchman's signal register: line relay, numbered drops, gong, counter.
##
## SR7-K, and the end of SR7-J's wire.
##
## SR7-J left one honest limitation on the record: the station box's conduit
## entered the wall and reached nothing. This is what it reaches.
##
## THE TRUTH THIS TEACHES. An indication here proves the CIRCUIT operated.
##
## That is a different fact from the one the box makes, and weaker in a
## specific way. The box's drop is mechanical and local: it falls because a
## hand turned a crank, and nothing can argue with it. This board's shutter
## falls because current arrived down a wire. So:
##
##   * A shutter down proves a signal came in over the line, at this number,
##     in this order. It does not prove who turned the tour key, and it does
##     not prove anything whatever about what they did next.
##   * A shutter UP proves nothing at all. It might mean nobody worked the
##     station. It might mean the line is open and the box is standing there
##     with its drop down, perfectly truthful, telling nobody.
##
## THE LINE IS CLOSED-CIRCUIT, which is the period answer to exactly that: a
## healthy watchman's line rests closed so that a break is an abnormal
## condition the board can show, rather than silence indistinguishable from
## silence. The pilot reads LINE CLOSED or LINE OPEN and it is the first thing
## on the case a reader's eye should land on.
##
## WHAT IT DOES NOT RECORD, and this is the honest one: TIME.
##
## A drop annunciator indicates number and order. It has no clock and no tape.
## The hour lives in two other instruments and neither of them is this one --
## the watchman's paper-dial detector (SR7-F), which SR7-F spent its whole
## increment proving you cannot take on trust, and the night register (SR7-G/H),
## which is a book a person writes in. Three instruments, three jobs. The
## temptation to make this one answer all three questions is exactly the
## console this must not become.
##
## HISTORICAL BASIS.
##   * R. M. HOPKINS, assigned to AMERICAN DISTRICT TELEGRAPH CO,
##     US 1,394,832, "Watchman's Registry System", filed 10 October 1919,
##     granted 25 October 1921. It registers "the visits of watchmen to certain
##     stations which they are supposed to visit regularly", the station
##     transmitter "sending in the corresponding signal". ADT is the right firm
##     and 1921 is the right decade for a building reopened in 1928.
##   * O. M. LEICH, assigned to CRACRAFT LEICH ELECTRIC COMPANY, US 1,144,605,
##     "Annunciator", filed 18 August 1913, granted 29 June 1915. "A drop
##     shutter 9 is provided which is controlled by the shutter arm 10 secured
##     to the armature 11", it stays down until restored, and the signal
##     "responds directly in accordance with the signals transmitted" -- an
##     annunciator that COUNTS the code rather than merely buzzing. That count
##     is why this board can name a station instead of just announcing one.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: this case, its four shutter
## positions, its counter and its pilot are authored. The lobby wall it hangs
## on, the run it hangs in and the station at the far end of its line are not.
##
## AUTHORING RULE. Local z = 0 is the mounting plane and the case is built
## OUTWARD along +z into the lobby.

## Raised when a signal is displayed. A fact ABOUT THIS BOARD, not a second
## copy of the station's fact: nothing subscribes to it here.
signal signal_displayed(station_number: int, sequence: int)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## Four shutter positions, because a board with one is a lamp. Only station 2
## exists today; 1, 3 and 4 are wired to nothing and say so by never falling.
const SHUTTER_NUMBERS := [1, 2, 3, 4]
## What a displayed indication is allowed to carry. Number and order. NOT time,
## and not a person -- neither of which came down the wire.
const INDICATION_FIELDS := ["station_number", "sequence"]
## Where a drop sits parked, and where it sits fallen. It travels in a
## straight line between them and never leaves the plane of the board.
## Parked sits entirely behind the hood; fallen sits entirely in the window.
## The two never overlap, so an unsignalled position is an EMPTY window and a
## signalled one is a numbered leaf -- the loudest read the board can give.
const SHUTTER_REST_Y := 0.300
const SHUTTER_DROP_Y := 0.216

var _case: MeshInstance3D
var _pilot_open: MeshInstance3D
var _pilot_closed: MeshInstance3D
var _relay: Node3D
var _gong: MeshInstance3D
var _lever: Node3D
var _shutters: Dictionary = {}
var _counter_label: Label3D
var _pilot_label: Label3D
var _gong_sound: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D

## THE DETERMINISTIC PHYSICAL STATE.
## `line_closed` -- the circuit condition the pilot shows.
## `dropped` -- which numbered shutters are down.
## `signals_taken` -- the counter, which only ever goes up.
var line_closed := true
var dropped: Array[int] = []
var signals_taken := 0

var _balk_left := 0.0
var _balk_focus := ""
var _last_indication: Dictionary = {}


func _ready() -> void:
	super()
	_refresh_register()


# --- the line ----------------------------------------------------------------

## Set by the network, or by the test key on the case. Nothing here ever closes
## the line on its own.
func set_line_closed(closed: bool) -> void:
	if line_closed == closed:
		return
	line_closed = closed
	if _click != null:
		_click.play()
	_refresh_register()


func line_reads() -> String:
	return "LINE CLOSED" if line_closed else "LINE OPEN"


# --- receiving ---------------------------------------------------------------

## THE ONE THING THE WIRE CALLS. Returns whether the indication was displayed,
## so the network can tell a delivery from a signal that went nowhere.
##
## Refuses on an open line, because there is no current to release an armature
## with -- and refuses a number this board has no shutter for, because a board
## cannot show a station it was never wired to.
func receive_signal(record: Dictionary) -> bool:
	var number := int(record.get("station_number", 0))
	if not line_closed:
		# Nothing arrives. The board does not even know it was called, which is
		# precisely the failure being modelled: silence here is ambiguous.
		return false
	if number not in SHUTTER_NUMBERS:
		_balk(1.2, "shutters")
		return false
	if number in dropped:
		# The shutter is already down. A real board would step its counter
		# again; this one refuses, because SR7-J's lock-out means a second
		# signal from one station is not a thing that can honestly happen, and
		# a board that quietly counted one would be manufacturing evidence.
		_balk(1.4, "shutters")
		return false
	dropped.append(number)
	dropped.sort()
	signals_taken += 1
	_last_indication = {
		"station_number": number,
		"sequence": signals_taken,
	}
	if _gong_sound != null:
		_gong_sound.play()
	_refresh_register()
	signal_displayed.emit(number, signals_taken)
	return true


func shows(number: int) -> bool:
	return number in dropped


func indication_count() -> int:
	return dropped.size()


func last_indication() -> Dictionary:
	return _last_indication.duplicate(true)


# --- the reset lever ---------------------------------------------------------

## Restores the shutters, exactly as Leich's are restored. THE COUNTER DOES NOT
## GO BACK: a board can be tidied, but the number of signals it has taken is
## not a thing anybody gets to tidy away.
func reset_shutters() -> bool:
	if dropped.is_empty():
		_balk(1.0, "lever")
		return false
	dropped.clear()
	if _click != null:
		_click.play()
	_refresh_register()
	return true


## The test key. Period boards carried one; it is how a watchman found out the
## line was open before the morning did.
func throw_test_key() -> bool:
	set_line_closed(not line_closed)
	return true


# --- the abort seam ----------------------------------------------------------

## The same two methods the rest of SR7 uses. Note what is NOT in here: the
## facts the network is holding. Restoring this board puts the brass back and
## cannot reach into a consumer to un-say what was said.
func maintenance_snapshot() -> Dictionary:
	return {
		"line_closed": line_closed,
		"dropped": dropped.duplicate(),
		"signals_taken": signals_taken,
		"last_indication": _last_indication.duplicate(true),
	}


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	line_closed = bool(snapshot.get("line_closed", line_closed))
	var kept: Array = snapshot.get("dropped", [])
	dropped.clear()
	for number in kept:
		dropped.append(int(number))
	signals_taken = int(snapshot.get("signals_taken", signals_taken))
	_last_indication = (snapshot.get("last_indication", {})
			as Dictionary).duplicate(true)
	_balk_left = 0.0
	_balk_focus = ""
	_refresh_register()


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var oak := Color(0.31, 0.20, 0.13)
	var brass := Color(0.62, 0.50, 0.24)
	var brass_bright := Color(0.76, 0.63, 0.30)
	var enamel := Color(0.83, 0.80, 0.73)
	var slate := Color(0.19, 0.19, 0.21)
	var red := Color(0.63, 0.17, 0.11)
	var green := Color(0.20, 0.42, 0.24)

	# The case: an oak box with a deep reveal, 0.40 x 0.46, standing 0.11 off
	# the wall. Smaller than the night register beside it on purpose -- this
	# is an instrument, not a desk.
	_case = make_box(Vector3(0.400, 0.460, 0.024),
			Vector3(0.0, 0.230, 0.012), oak)
	_case.name = "RegisterCase"
	var backing := make_box(Vector3(0.362, 0.422, 0.003),
			Vector3(0.0, 0.230, 0.026), Color(0.14, 0.14, 0.16))
	backing.name = "RegisterBacking"
	for edge_x in [-0.194, 0.194]:
		var cheek := make_box(Vector3(0.014, 0.460, 0.100),
				Vector3(edge_x, 0.230, 0.050), oak)
		cheek.name = "CaseCheek"
	make_box(Vector3(0.400, 0.016, 0.100), Vector3(0.0, 0.452, 0.050), oak)
	make_box(Vector3(0.400, 0.016, 0.100), Vector3(0.0, 0.008, 0.050), oak)
	var head := make_box(Vector3(0.372, 0.040, 0.004),
			Vector3(0.0, 0.428, 0.098), enamel)
	head.name = "RegisterHead"
	_print("RegisterTitle", "SIGNAL REGISTER", Vector3(0.0, 0.428, 0.102),
			0.0180, Color(0.16, 0.13, 0.11))

	# THE CONDUIT, entering from BELOW. SR7-J's box sends its wire up into the
	# wall; this is where it comes back out, and the two are drawn as one run
	# because a wire with only one end is a decoration.
	var conduit := make_cyl(0.010, 0.010, 0.080,
			Vector3(-0.140, -0.036, 0.030), Color(0.36, 0.36, 0.38),
			0.52, 0.60)
	conduit.name = "RegisterConduit"
	var elbow := make_cyl(0.012, 0.012, 0.032,
			Vector3(-0.140, 0.004, 0.018), Color(0.36, 0.36, 0.38), 0.52, 0.60)
	elbow.name = "ConduitElbow"
	elbow.rotation_degrees.x = 90.0

	# THE LINE PILOT, top left and first thing read. Two enamel plates, one
	# lit at a time, because "closed" and "open" are the two states a
	# closed-circuit line has and there is no third.
	_pilot_closed = make_box(Vector3(0.150, 0.044, 0.004),
			Vector3(-0.100, 0.372, 0.098), green)
	_pilot_closed.name = "PilotClosed"
	_pilot_open = make_box(Vector3(0.150, 0.044, 0.004),
			Vector3(-0.100, 0.372, 0.098), red)
	_pilot_open.name = "PilotOpen"
	_pilot_label = _print("PilotLegend", "LINE CLOSED",
			Vector3(-0.100, 0.372, 0.103), 0.0140, Color(0.94, 0.92, 0.86))

	# THE LINE RELAY, top right: the armature that current actually moves.
	_relay = Node3D.new()
	_relay.name = "LineRelay"
	_relay.position = Vector3(0.108, 0.372, 0.060)
	add_child(_relay)
	var coil := make_cyl(0.024, 0.024, 0.044, Vector3.ZERO, Color(0.30, 0.16,
			0.10), 0.62, 0.10)
	coil.name = "RelayCoil"
	coil.rotation_degrees.x = 90.0
	_adopt(coil, _relay)
	var armature := make_box(Vector3(0.056, 0.008, 0.010),
			Vector3(0.0, 0.030, 0.020), brass_bright)
	armature.name = "RelayArmature"
	_adopt(armature, _relay)

	# THE FOUR NUMBERED DROPS. A gravity drop FALLS: it does not swing out of
	# the case on a hinge. An earlier build pivoted them and the raised ones
	# stood out into the lobby like little shelves with their numbers facing
	# the ceiling -- unreadable, and wrong about the mechanism. They now slide
	# straight down in their own guides and stay flush with the board all the
	# way, which is both what a drop does and what a drop looks like.
	#
	# At rest the leaf is parked above its window behind the guard rail, so an
	# unsignalled position reads as an EMPTY window. The station number is
	# engraved on the case under each window and is therefore legible whether
	# the position has been signalled or not.
	for i in SHUTTER_NUMBERS.size():
		var number: int = SHUTTER_NUMBERS[i]
		var x := -0.129 + 0.086 * float(i)
		var frame := make_box(Vector3(0.074, 0.092, 0.004),
				Vector3(x, 0.216, 0.090), Color(0.09, 0.09, 0.11))
		frame.name = "ShutterFrame%d" % number
		for side in [-0.037, 0.037]:
			var guide := make_box(Vector3(0.006, 0.176, 0.010),
					Vector3(x + side, 0.258, 0.095), Color(0.34, 0.28, 0.14))
			guide.name = "ShutterGuide%d" % number
		var pivot := Node3D.new()
		pivot.name = "Shutter%d" % number
		pivot.position = Vector3(x, SHUTTER_REST_Y, 0.094)
		add_child(pivot)
		var leaf := make_box(Vector3(0.064, 0.080, 0.004), Vector3.ZERO, brass)
		leaf.name = "ShutterLeaf%d" % number
		_adopt(leaf, pivot)
		var face := make_box(Vector3(0.052, 0.066, 0.003),
				Vector3(0.0, 0.0, 0.003), enamel)
		face.name = "ShutterFace%d" % number
		_adopt(face, pivot)
		_print("ShutterMark%d" % number, str(number),
				Vector3(0.0, 0.0, 0.007), 0.0330,
				Color(0.18, 0.14, 0.11), pivot)
		_shutters[number] = pivot
		# The engraved position number on the CASE, always readable.
		_print("PositionNumber%d" % number, str(number),
				Vector3(x, 0.152, 0.098), 0.0155, Color(0.72, 0.70, 0.64))
	# THE HOOD. It covers the parked position completely -- 0.078 of leaf
	# behind 0.082 of oak -- so a drop that has not fallen is not a leaf
	# sitting high in a window, it is nothing at all. An earlier build left
	# the parked drops peeking over a shallow rail and into the pilot row.
	var hood := make_box(Vector3(0.376, 0.082, 0.012),
			Vector3(0.0, 0.300, 0.102), oak)
	hood.name = "ShutterHood"
	var hood_lip := make_box(Vector3(0.376, 0.008, 0.020),
			Vector3(0.0, 0.261, 0.106), Color(0.42, 0.34, 0.17))
	hood_lip.name = "ShutterHoodLip"

	# THE COUNTER, bottom left: a numeral drum behind a window. It steps once
	# per signal taken and it does not step back.
	var counter_plate := make_box(Vector3(0.130, 0.056, 0.004),
			Vector3(-0.106, 0.108, 0.096), slate)
	counter_plate.name = "CounterPlate"
	var counter_window := make_box(Vector3(0.062, 0.040, 0.003),
			Vector3(-0.106, 0.108, 0.100), Color(0.88, 0.86, 0.80))
	counter_window.name = "CounterWindow"
	_counter_label = _print("CounterNumber", "000",
			Vector3(-0.106, 0.108, 0.104), 0.0250, Color(0.14, 0.12, 0.10))
	_print("CounterLegend", "SIGNALS", Vector3(-0.106, 0.062, 0.098), 0.0105,
			Color(0.70, 0.68, 0.62))

	# THE GONG, bottom centre-right. Struck once per signal.
	_gong = make_cyl(0.036, 0.030, 0.014, Vector3(0.062, 0.106, 0.058),
			brass_bright, 0.30, 0.80)
	_gong.name = "RegisterGong"
	_gong.rotation_degrees.x = 90.0

	# THE RESET LEVER, bottom right, on its own pivot so throwing it reads.
	_lever = Node3D.new()
	_lever.name = "ResetLever"
	_lever.position = Vector3(0.152, 0.086, 0.070)
	add_child(_lever)
	var lever_arm := make_box(Vector3(0.012, 0.062, 0.010),
			Vector3(0.0, 0.031, 0.0), brass)
	lever_arm.name = "LeverArm"
	_adopt(lever_arm, _lever)
	var lever_knob := make_cyl(0.011, 0.011, 0.016,
			Vector3(0.0, 0.062, 0.004), slate, 0.42, 0.20)
	lever_knob.name = "LeverKnob"
	lever_knob.rotation_degrees.x = 90.0
	_adopt(lever_knob, _lever)
	_print("LeverLegend", "RESET", Vector3(0.152, 0.046, 0.098), 0.0105,
			Color(0.70, 0.68, 0.62))

	_gong_sound = make_emitter("knock", -12.0)
	_click = make_emitter("pop", -18.0)
	_build_reaches()
	_refresh_register()


func _adopt(node: Node3D, pivot: Node3D) -> void:
	var local := node.position
	var spin := node.rotation
	remove_child(node)
	pivot.add_child(node)
	node.position = local
	node.rotation = spin


func _print(node_name: String, text: String, at: Vector3, em: float,
		tint: Color, parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = 64
	label.pixel_size = em / 64.0
	label.modulate = tint
	label.outline_size = 0
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = true
	label.double_sided = false
	(parent if parent != null else self).add_child(label)
	return label


## Two literal service points: the reset lever and the line test key. Both are
## Area3D reaches, which report overlaps and obstruct nothing.
func _build_reaches() -> void:
	var reaches := {
		"reset": [Vector3(0.152, 0.100, 0.090), Vector3(0.13, 0.16, 0.20)],
		"line": [Vector3(-0.100, 0.372, 0.090), Vector3(0.20, 0.10, 0.20)],
	}
	for control_id in reaches.keys():
		var reach := ControlArea.new()
		reach.name = "Reach_%s" % str(control_id)
		reach.configure(str(control_id))
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = reaches[control_id][1]
		shape_node.shape = shape
		shape_node.position = reaches[control_id][0]
		reach.add_child(shape_node)
		add_child(reach)


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	match control_id:
		"reset":
			if dropped.is_empty():
				return "[E]  The board is clear  (%d signals)" % signals_taken
			return "[E]  Restore the shutters  (%s down)" % _dropped_text()
		"line":
			return "[E]  Throw the test key  (%s)" % line_reads()
	return ""


func _dropped_text() -> String:
	var out: Array[String] = []
	for number in dropped:
		out.append(str(number))
	return ", ".join(out)


func interact_control(control_id: String, _player: Node) -> bool:
	match control_id:
		"reset":
			return reset_shutters()
		"line":
			return throw_test_key()
	return false


func interact_prompt() -> String:
	return control_prompt("reset")


func interact(player: Node) -> void:
	interact_control("reset", player)


func service_wire_card() -> Dictionary:
	return {
		"title": "SIGNAL REGISTER",
		"body": "The far end of the watchman's line. A shutter down means a "
				+ "signal came in at that number, in that order. It does not "
				+ "say who sent it, and a shutter still up may only mean the "
				+ "line is open.",
	}


# --- the readable refusal ----------------------------------------------------

func _balk(seconds: float, focus := "") -> void:
	var already := _balk_left > 0.0
	_balk_focus = focus
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _click != null:
		_click.play()
	_refresh_register()


func balking() -> bool:
	return _balk_left > 0.0


func _process(delta: float) -> void:
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_register()


func _refresh_register() -> void:
	if _case == null:
		return
	# THE PILOT IS THE FIRST THING READ, and it is two plates with one lit.
	if _pilot_closed != null:
		_pilot_closed.visible = line_closed
	if _pilot_open != null:
		_pilot_open.visible = not line_closed
	if _pilot_label != null:
		_pilot_label.text = line_reads()
	# Every drop is parked or fallen. Nothing else it can be, and it is flush
	# against the board either way.
	for number in SHUTTER_NUMBERS:
		var pivot: Node3D = _shutters.get(number)
		if pivot != null:
			pivot.position.y = SHUTTER_DROP_Y if number in dropped 					else SHUTTER_REST_Y
	if _counter_label != null:
		_counter_label.text = "%03d" % signals_taken
	# The relay armature sits pulled in on a closed line and stands off an
	# open one: the board's own health, visible without reading a word.
	if _relay != null:
		_relay.position.z = 0.060 if line_closed else 0.052
	# EVERY MOVING PART GOES TO REST BEFORE THE BALK BLOCK, not inside it. A
	# pose applied only while refusing is a pose that never comes back, and
	# the lever stayed thrown after its refusal until this line existed.
	if _lever != null:
		_lever.rotation.x = 0.0

	var balk := clampf(_balk_left, 0.0, 1.0)
	if balk <= 0.0:
		return
	match _balk_focus:
		"shutters":
			# The whole rank jumps in its guides without any of them changing
			# state: a signal the board will not take.
			for number in SHUTTER_NUMBERS:
				var pivot: Node3D = _shutters.get(number)
				if pivot != null:
					pivot.position.y += 0.011 * balk
		"lever":
			if _lever != null:
				_lever.rotation.x = -0.55 * balk
