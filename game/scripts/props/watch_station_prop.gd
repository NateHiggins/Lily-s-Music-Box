class_name WatchStationProp
extends FunctionalProp
## A watchman's signal box: cast-iron case, hinged door, coded wheel and drop.
##
## SR7-J, and the first station on a round the Orison has never actually had.
##
## THE AUDIT CAME FIRST, AND IT CHANGED THE APPARATUS.
##
## SR7-F's detector in the lobby is a NEWMAN/MOOSMANN paper-dial watchman's
## clock. In that system the station key is turned IN THE CLOCK: the mark is
## made by the key's own barrel biting the paper. A key screwed to a wall on
## the second floor cannot make a mark in an instrument standing in the lobby,
## and a station that pretended otherwise would be the same lie SR7-F was built
## to expose. So this is NOT that system.
##
## The period mechanism that CAN mark from a distance is the other one
## entirely: the electric watchman's signal box, fixed at the station and wired
## back to a central register. Its architecture is the inverse of the
## detector's -- the boxes stay on the wall, the watchman carries a tour key,
## and the time record is made at the far end of a wire.
##
## THE TRUTH THIS TEACHES. A mark proves a station mechanism was operated, at a
## place, at a time. That is the whole of what it proves.
##
##   * It does not prove WHO. The key socket in this box is empty and the crank
##     is bare: anything with a hand can work it. The record carries a station,
##     a number and an hour, and there is no field in it for a person, because
##     the iron has no way of knowing one.
##   * It does not prove the work. Marking a station advances no job, diagnoses
##     nothing, repairs nothing and resolves no case. A box on the way to 2A
##     says you passed the box.
##   * It cannot be missed into failure. Nothing here gates the route. The
##     round to Mina's Vantry point is exactly as walkable with this box never
##     touched, and the focused proof asserts it.
##
## AND THE ONE THIS BUILDING ADDS. The wire leaves the top of the case and
## goes into the wall, and what it reaches is NOT MODELLED. There is no central
## register in the Orison. So today the box's own drop is the only evidence in
## the building that anybody came this way -- which is a stronger version of
## the same lesson, honestly labelled rather than papered over.
##
## HISTORICAL BASIS.
##   * G. A. JACKSON, assigned to GAMEWELL FIRE ALARM TELEGRAPH CO.,
##     US 1,479,608, "Attachment for Signal Boxes", filed 27 December 1922,
##     granted 1 January 1924 -- four years before the Orison's 1928. Its
##     hinged frame "is normally retained in closed position by engagement of
##     the latch spring", and is hung so that a section left partly closed
##     swings open under its own weight, "directing attention to the fact that
##     the structure has not been properly restored". A door that refuses to
##     sit half-shut is this apparatus's whole visual grammar.
##   * H. MACHINIST, US 2,220,937, "Tour Key for Watchmen's Signal Systems",
##     filed 18 February 1939. Later than the game, and cited only for its
##     account of the practice already established: "the watchman is provided
##     with an implement, sometimes called a tour key, which he carries on his
##     rounds", "designed to fit into a series of devices in the nature of
##     signal boxes, and to be operated in each of them in a certain order",
##     and "one or more of the boxes in the system is connected electrically
##     with a central station so that a time record is provided". Boxes fixed,
##     key carried, record remote. That is the architecture, in the patent
##     record's own words.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: this box, its number, its drop
## and its counter are authored. The corridor it hangs in, the door it stands
## beside and the hour it reads are not.
##
## THE TOUR KEY IS NOT MODELLED. The socket is empty on purpose: this building
## never issued one. It makes the box weaker evidence than a real 1928 station
## and it makes the "who" lesson literal.
##
## AUTHORING RULE. Local z = 0 is the mounting plane and the case is built
## OUTWARD along +z into the corridor.

## The one neutral fact this apparatus publishes. Nothing subscribes to it
## here: first-shift and campaign integration is the director's seam.
signal station_marked(station_id: String, mark_record: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## The authored stations. One today; the table is the architecture, so a second
## box is a line here and a placement, not a new class.
const STATIONS := {
	"F02_STATION_2A_LANDING": {
		"number": 2,
		"serves": "2A",
		"legend": "STATION 2",
	},
}
## The hour the box reads when no day/night owner is in the tree -- the same
## canonical 03:00 the rest of SR7 tests and renders at.
const CANONICAL_MINUTE := 180.0
## What a mark record is allowed to contain. A station that recorded more than
## this would be claiming to know more than a coded wheel can.
const RECORD_FIELDS := ["station_id", "station_number", "serves", "at_minute",
		"sequence"]

@export var station_id := "F02_STATION_2A_LANDING"

var _case: MeshInstance3D
var _door: Node3D
var _crank: Node3D
var _wheel: Node3D
var _drop: Node3D
var _counter: Node3D
var _socket: MeshInstance3D
var _knock: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _clock_source: Node

## THE DETERMINISTIC PHYSICAL STATE, and all of it.
## `door_open` -- the Gamewell door is shut or open, never between.
## `drop_fallen` -- the box has been worked and not yet reset.
## `marks` -- how many times the wheel has run off its number.
var door_open := false
var drop_fallen := false
var marks := 0

var _balk_left := 0.0
var _balk_focus := ""
var _last_record: Dictionary = {}


func _ready() -> void:
	super()
	_refresh_station()


# --- what the box knows ------------------------------------------------------

func spec() -> Dictionary:
	return STATIONS.get(station_id, {})


func station_number() -> int:
	return int(spec().get("number", 0))


func legend() -> String:
	return str(spec().get("legend", ""))


## The hour, from the same owner the sky and the watchman's detector already
## use. Walked for rather than injected, so no new binding seam and no second
## source of time.
func house_minute() -> float:
	if _clock_source == null or not is_instance_valid(_clock_source):
		var node: Node = self
		while node != null:
			if node.get("day_night_director") != null:
				_clock_source = node.get("day_night_director")
				break
			node = node.get_parent()
	if _clock_source != null and _clock_source.has_method("_minute_now"):
		return float(_clock_source.call("_minute_now"))
	return CANONICAL_MINUTE


func marked() -> bool:
	return drop_fallen


func last_record() -> Dictionary:
	return _last_record.duplicate(true)


# --- working the box ---------------------------------------------------------

## The door. Gamewell's hinge is the reason this is a state and not a flourish:
## a box left half-closed swings open and says so.
func open_door() -> bool:
	if door_open:
		_balk(1.0, "door")
		return false
	door_open = true
	if _click != null:
		_click.play()
	_refresh_station()
	return true


func close_door() -> bool:
	if not door_open:
		_balk(1.0, "door")
		return false
	door_open = false
	if _click != null:
		_click.play()
	_refresh_station()
	return true


## THE MARK. One deliberate turn of the crank runs the coded wheel off this
## station's number, drops the flag and steps the counter.
##
## Refuses with the door shut, because the crank is behind it -- and refuses
## with the drop already fallen, because the transmitter's lock-out pawl is
## exactly what stops one man cranking a station twenty times. Both refusals
## are ACKNOWLEDGED: the box knocks and the pawl is visibly against its stop.
func turn_crank() -> bool:
	if not door_open:
		_balk(1.2, "door")
		return false
	if drop_fallen:
		# The pawl is home. The wheel will not run a second time until the box
		# is reset, and it says so rather than failing silently.
		_balk(1.4, "crank")
		return false
	drop_fallen = true
	marks += 1
	var record := {
		"station_id": station_id,
		"station_number": station_number(),
		"serves": str(spec().get("serves", "")),
		"at_minute": house_minute(),
		"sequence": marks,
	}
	_last_record = record
	if _knock != null:
		_knock.play()
	_refresh_station()
	# THE ONE PUBLICATION. A fact, not a command, and nothing in this file
	# listens to it.
	station_marked.emit(station_id, record.duplicate(true))
	return true


## Resetting the drop is a supervisor's act, not a watchman's -- in the period
## systems the register end reset the boxes. It is here so the apparatus is
## complete and so the abort seam has something honest to restore to.
func reset_station() -> bool:
	if not drop_fallen:
		_balk(1.0, "drop")
		return false
	drop_fallen = false
	if _click != null:
		_click.play()
	_refresh_station()
	return true


# --- the abort seam ----------------------------------------------------------

## The same two methods `MaintenanceActivityPanel` uses, by the same names, so
## a session walked away from leaves the iron exactly as it was found.
func maintenance_snapshot() -> Dictionary:
	return {
		"door_open": door_open,
		"drop_fallen": drop_fallen,
		"marks": marks,
		"last_record": _last_record.duplicate(true),
	}


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	door_open = bool(snapshot.get("door_open", door_open))
	drop_fallen = bool(snapshot.get("drop_fallen", drop_fallen))
	marks = int(snapshot.get("marks", marks))
	_last_record = (snapshot.get("last_record", {}) as Dictionary).duplicate(true)
	_balk_left = 0.0
	_balk_focus = ""
	_refresh_station()


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var iron := Color(0.17, 0.17, 0.19)
	var iron_light := Color(0.26, 0.26, 0.28)
	var brass := Color(0.62, 0.50, 0.24)
	var enamel := Color(0.80, 0.77, 0.70)
	var red := Color(0.44, 0.13, 0.10)

	# THE CASE. A shallow cast-iron box: 0.24 wide, 0.32 tall, standing 0.13
	# off the wall. It is deliberately small -- a signal box is furniture you
	# walk past, not a landmark, and a corridor this narrow cannot afford a
	# projection anybody could walk into.
	_case = make_box(Vector3(0.240, 0.320, 0.026),
			Vector3(0.0, 0.160, 0.013), iron)
	_case.name = "StationCase"
	# THE INSIDE IS PAINTED PALE, and that is not a lighting cheat: signal
	# boxes were finished light inside precisely so the mechanism could be
	# read in a badly lit corridor by a man with a hand lamp. A cast-iron
	# interior photographs as a black hole and reads as one in play too.
	var lining := make_box(Vector3(0.216, 0.296, 0.003),
			Vector3(0.0, 0.160, 0.028), Color(0.68, 0.66, 0.60))
	lining.name = "CaseLining"
	for edge_x in [-0.115, 0.115]:
		var cheek := make_box(Vector3(0.020, 0.320, 0.120),
				Vector3(edge_x, 0.160, 0.060), iron)
		cheek.name = "CaseCheek"
	make_box(Vector3(0.240, 0.020, 0.120), Vector3(0.0, 0.310, 0.060), iron)
	make_box(Vector3(0.240, 0.020, 0.120), Vector3(0.0, 0.010, 0.060), iron)
	# The cast maker's bead across the head, and the number plate under it.
	var bead := make_box(Vector3(0.200, 0.010, 0.008),
			Vector3(0.0, 0.286, 0.122), iron_light)
	bead.name = "CaseBead"
	# The number plate goes on the DOOR, not inside the case. A legend behind
	# a door you have to open first is a legend nobody finds in passing -- and
	# the first sheet proved it, because opening the box hid its own name.

	# THE WIRE. It leaves the head of the case and goes into the wall, and
	# what it reaches is not modelled. Drawn because the box would be a lie
	# without it: this is the only reason a fixed station can mark anything.
	var conduit := make_cyl(0.009, 0.009, 0.075,
			Vector3(0.0, 0.352, 0.030), iron_light, 0.52, 0.60)
	conduit.name = "StationConduit"
	var elbow := make_cyl(0.011, 0.011, 0.030,
			Vector3(0.0, 0.386, 0.016), iron_light, 0.52, 0.60)
	elbow.name = "ConduitElbow"
	elbow.rotation_degrees.x = 90.0

	# THE DOOR, on its own pivot at the left stile so it swings like a door
	# rather than sliding like a panel.
	_door = Node3D.new()
	_door.name = "StationDoor"
	_door.position = Vector3(-0.108, 0.160, 0.118)
	add_child(_door)
	var leaf := make_box(Vector3(0.216, 0.300, 0.014),
			Vector3(0.108, 0.0, 0.0), iron)
	leaf.name = "DoorLeaf"
	_adopt(leaf, _door)
	# The glazed window: the station's number is readable with the box SHUT,
	# which is what makes it findable on a walk instead of a thing you open
	# everything to look for.
	var glass := make_box(Vector3(0.130, 0.090, 0.004),
			Vector3(0.108, 0.026, 0.008), Color(0.55, 0.62, 0.60, 0.30))
	glass.name = "DoorGlass"
	_adopt(glass, _door)
	var sash := make_box(Vector3(0.150, 0.110, 0.006),
			Vector3(0.108, 0.026, 0.004), iron_light)
	sash.name = "DoorSash"
	_adopt(sash, _door)
	var handle := make_cyl(0.008, 0.008, 0.040,
			Vector3(0.196, -0.060, 0.014), brass, 0.36, 0.70)
	handle.name = "DoorHandle"
	handle.rotation_degrees.z = 90.0
	_adopt(handle, _door)
	# The latch spring the Gamewell patent names. Its whole job is that the
	# door is shut or open and never in between.
	var latch := make_box(Vector3(0.014, 0.030, 0.010),
			Vector3(0.212, 0.0, 0.006), brass)
	latch.name = "LatchSpring"
	_adopt(latch, _door)
	var plate := make_box(Vector3(0.156, 0.044, 0.004),
			Vector3(0.108, 0.112, 0.009), enamel)
	plate.name = "StationPlate"
	_adopt(plate, _door)
	_print("StationLegend", legend(), Vector3(0.108, 0.112, 0.013), 0.0180,
			Color(0.14, 0.12, 0.10), _door)

	# INSIDE: the empty tour-key socket, the crank, the coded wheel, the drop
	# and the counter.
	_socket = make_box(Vector3(0.034, 0.034, 0.010),
			Vector3(-0.062, 0.236, 0.074), iron_light)
	_socket.name = "TourKeySocket"
	var keyway := make_box(Vector3(0.006, 0.020, 0.004),
			Vector3(-0.062, 0.236, 0.080), Color(0.05, 0.05, 0.06))
	keyway.name = "SocketKeyway"

	_crank = Node3D.new()
	_crank.name = "StationCrank"
	_crank.position = Vector3(0.052, 0.198, 0.084)
	add_child(_crank)
	var boss := make_cyl(0.016, 0.016, 0.014, Vector3.ZERO, iron_light,
			0.46, 0.62)
	boss.name = "CrankBoss"
	boss.rotation_degrees.x = 90.0
	_adopt(boss, _crank)
	var arm := make_box(Vector3(0.014, 0.066, 0.010),
			Vector3(0.0, 0.033, 0.006), iron_light)
	arm.name = "CrankArm"
	_adopt(arm, _crank)
	var grip := make_cyl(0.008, 0.008, 0.020, Vector3(0.0, 0.056, 0.012),
			brass, 0.38, 0.66)
	grip.name = "CrankGrip"
	grip.rotation_degrees.x = 90.0
	_adopt(grip, _crank)

	# THE CODED WHEEL. Its teeth are this station's number, and the number is
	# cut into the metal rather than held in a variable: a box can only ever
	# transmit the one station it is.
	_wheel = Node3D.new()
	_wheel.name = "CodedWheel"
	_wheel.position = Vector3(-0.030, 0.120, 0.076)
	add_child(_wheel)
	var disc := make_cyl(0.030, 0.030, 0.008, Vector3.ZERO, iron_light,
			0.48, 0.58)
	disc.name = "WheelDisc"
	disc.rotation_degrees.x = 90.0
	_adopt(disc, _wheel)
	for i in maxi(station_number(), 1):
		var tooth := make_box(Vector3(0.007, 0.014, 0.009),
				Vector3(0.0, 0.034, 0.0), brass)
		tooth.name = "WheelTooth%d" % i
		_adopt(tooth, _wheel)
		tooth.rotation.z = -0.42 * float(i)
		tooth.position = Vector3(sin(0.42 * float(i)) * 0.034,
				cos(0.42 * float(i)) * 0.034, 0.0)
	# The lock-out pawl: what refuses a second signal until the box is reset.
	_counter = Node3D.new()
	_counter.name = "LockoutPawl"
	_counter.position = Vector3(0.014, 0.120, 0.082)
	add_child(_counter)
	var pawl := make_box(Vector3(0.038, 0.008, 0.008), Vector3.ZERO, brass)
	pawl.name = "PawlArm"
	_adopt(pawl, _counter)

	# THE DROP. A numbered brass flag on its own pivot: up is unworked, fallen
	# is worked. This is the entire local record, and it is legible with the
	# door open from across the corridor.
	_drop = Node3D.new()
	_drop.name = "StationDrop"
	_drop.position = Vector3(0.058, 0.108, 0.090)
	add_child(_drop)
	# It is the entire local record, so it is built to be read across a
	# corridor: a vermilion tab with the station's own number in enamel on it.
	# The first sheet had it dark red and small, and marked-versus-unmarked
	# came back as two nearly identical dark outlines.
	var flag := make_box(Vector3(0.064, 0.076, 0.005),
			Vector3(0.0, -0.038, 0.0), Color(0.63, 0.17, 0.11))
	flag.name = "DropFlag"
	_adopt(flag, _drop)
	var flag_face := make_box(Vector3(0.050, 0.060, 0.003),
			Vector3(0.0, -0.038, 0.004), Color(0.88, 0.86, 0.80))
	flag_face.name = "DropFace"
	_adopt(flag_face, _drop)
	_print("DropNumber", str(station_number()),
			Vector3(0.0, -0.038, 0.008), 0.0300, Color(0.20, 0.11, 0.09),
			_drop)

	_knock = make_emitter("knock", -14.0)
	_click = make_emitter("pop", -19.0)
	_build_reach()
	_refresh_station()


## `make_box` has no parent argument the way `make_cyl` does, so a box that
## belongs on a pivot is built on the prop and moved, keeping the local offset
## it was authored with.
func _adopt(node: Node3D, pivot: Node3D) -> void:
	var local := node.position
	var spin := node.rotation
	remove_child(node)
	pivot.add_child(node)
	node.position = local
	node.rotation = spin


func _print(node_name: String, text: String, at: Vector3, em: float,
		tint: Color, parent: Node3D = null) -> void:
	if text == "":
		return
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


## ONE literal service point, sized to the case and no larger. A corridor a
## resident walks down cannot afford a body anybody could collide with, and an
## Area3D is not one: it reports overlaps and stops nothing.
func _build_reach() -> void:
	var reach := ControlArea.new()
	reach.name = "StationReach"
	reach.configure("station")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.30, 0.38, 0.22)
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.160, 0.075)
	reach.add_child(shape_node)
	add_child(reach)


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	if control_id != "station":
		return ""
	if not door_open:
		return "[E]  Open the signal box  (%s)" % legend()
	if drop_fallen:
		return "[E]  Close the box  (marked, %02d:%02d)" % [
				int(house_minute()) / 60 % 24, int(house_minute()) % 60]
	return "[E]  Turn the crank"


## The whole box on one reach: shut -> open -> mark -> shut. Each press does
## the next physical thing, and every one of them is reversible until the
## crank goes round.
func interact_control(control_id: String, _player: Node) -> bool:
	if control_id != "station":
		return false
	if not door_open:
		return open_door()
	if drop_fallen:
		return close_door()
	var worked := turn_crank()
	if worked:
		# The latch spring takes the door home the moment the wheel has run.
		close_door()
	return worked


func interact_prompt() -> String:
	return control_prompt("station")


func interact(player: Node) -> void:
	interact_control("station", player)


func service_wire_card() -> Dictionary:
	return {
		"title": legend(),
		"body": "A watchman's signal box. Turning the crank runs its coded "
				+ "wheel off this station's number and drops the flag. It "
				+ "records that the box was worked, at an hour. It has no way "
				+ "of knowing by whom.",
	}


# --- the readable refusal ----------------------------------------------------

## Deterministic, held, and TARGETED -- the thing that refuses is the thing
## that moves, so two refusals on one box are two different photographs. The
## pose is applied here rather than left to `_process`, because a proof sheet
## freezes `_process` and a refusal nobody can photograph is not a refusal.
func _balk(seconds: float, focus := "") -> void:
	var already := _balk_left > 0.0
	_balk_focus = focus
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()
	_refresh_station()


func balking() -> bool:
	return _balk_left > 0.0


func _process(delta: float) -> void:
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_station()


func _refresh_station() -> void:
	if _case == null:
		return
	# The door is shut or open and never between: Gamewell's latch spring, and
	# the reason a half-closed box is a thing you can see from down the hall.
	if _door != null:
		_door.rotation.y = -1.15 if door_open else 0.0
	# The drop is up or fallen. Nothing else it can be.
	if _drop != null:
		_drop.rotation.z = 0.0 if drop_fallen else 1.35
	# The pawl rides home the moment the wheel has run, and stands off while
	# the box is still willing.
	if _counter != null:
		_counter.position.x = 0.014 if drop_fallen else 0.030
	if _wheel != null:
		_wheel.rotation.z = -0.42 * float(station_number()) if drop_fallen \
				else 0.0
	if _crank != null:
		_crank.rotation.z = 0.0

	var balk := clampf(_balk_left, 0.0, 1.0)
	if balk <= 0.0:
		return
	match _balk_focus:
		"door":
			# The leaf shoves against its stop without leaving it.
			if _door != null:
				_door.rotation.y += (0.20 if door_open else -0.20) * balk
		"crank":
			# The crank turns against the pawl and comes back. The wheel does
			# not move, because the wheel is what is being refused.
			if _crank != null:
				_crank.rotation.z = -0.55 * balk
			if _counter != null:
				_counter.position.x = 0.014 - 0.012 * balk
		"drop":
			if _drop != null:
				_drop.rotation.z = 0.22 * balk
