class_name DoorCheckCloserProp
extends FunctionalProp
## An overhead liquid door check and spring on the one stair door the Orison
## has: spring box, spindle, jointed arm, shoe, and a leakage port that decides
## whether the leaf ever reaches its latch.
##
## SR7-Q. THE DOOR IS NOT CLOSED.
##
## THE AUDIT CAME FIRST, AND IT CORRECTED THE BRIEF.
##
## There are 113 door leaves in the built Orison and exactly ONE of them stands
## on the stair enclosure: `ROOF_DOOR_01`, the galvanized service leaf at the
## head of the stair, b(-1.33, -3.25, 19.20), 0.96 by 2.10. Every other stair
## core in the building opens through a 3.2 m cased opening with no leaf in it
## at all. "Stair-enclosure doors" in the plural does not describe this
## building. In the singular it describes the best door in it for this
## apparatus, which is why this exists rather than a report saying no.
##
## PRODUCTION HAD THE WORD AND NOT THE THING. `data/prop_service_wire.json`
## already carries a card reading "A HEAVY PUBLIC LEAF USES A CLOSER TO SPEND
## ITS RETURN SLOWLY INSTEAD OF SLAMMING THE FRAME" with a
## `CLOSER {closer_state}` field, and `landmark_entry_door.gd` mentions a closer
## in a comment. NOTHING FILLS EITHER. No closer state, no closer script, no
## self-closing door anywhere: `DoorProp` moves a leaf only when a hand or a
## resident asks it to.
##
## THE TRUTH THIS TEACHES:
##
##     shuts_by_hand()  is true of every leaf in the building, always
##     closes_itself()  is a different question entirely
##
##     connected() = arm_shipped        the arm is on its spindle
##     metered()   = port_open          the leakage port will pass liquid
##     ready()     = connected() AND metered()
##
## A DOOR THAT CAN BE SHUT IS NOT A DOOR THAT WILL CLOSE ITSELF, and the only
## way to tell them apart is to let go of it.
##
## AS FOUND the closer is complete to look at. Box on the head, cylinder full,
## spring inside it, shoe bolted to the leaf, arm present. THE ARM IS OFF ITS
## SPINDLE -- unshipped, hanging on its own elbow -- so the spring has nothing
## to push and the leaf stays wherever the last hand left it. Nothing is
## missing and nothing is broken.
##
## AND THE SECOND FACT, WHICH IS THE ONE THE SHEET MEASURES. Shipping the arm
## is not the end of it. Dizer's own patent says the speed of the closing
## movement is decided by the size of the leakage port; a port screwed shut
## gives the spring nothing to move the liquid through, and the leaf comes off
## its hold and STOPS. So this apparatus will not request a close it cannot
## deliver: with the port shut it lets the leaf stand, and records that the leaf
## stopped short rather than pretending a door closed.
##
## THERE IS NO TIMER AND NO HIDDEN METER. Every fact this thing knows is a
## piece of its own iron: whether the arm's eye is on the spindle, and how far
## the regulating screw is out. Both are on the outside of the box where a hand
## can reach them and a camera can see them.
##
## HISTORICAL BASIS -- DOCUMENTED, PRE-1928.
##   * W. M. DIZER of Brookline, Massachusetts, US 866,719, "Door Check and
##     Closer", filed 20 February 1907, patented 24 September 1907. The whole
##     apparatus in one source: a cylinder that "contains a liquid" with "a
##     ported piston therein"; a spring in a box above the door whose
##     "resiliency ... operates to close the door"; an arm linking the
##     piston-rod to a spindle, the cylinder secured to the door and the spring
##     mechanism to the frame; and -- the sentence the check setting comes from
##     -- "the speed of the closing movement of the door is determined by the
##     size of the leakage port."
##   * J. B. ERWIN of Milwaukee, Wisconsin, US 797,273, "Door Closer and
##     Check", filed 9 October 1903, patented 15 August 1905. Cited for what a
##     closer is FOR, in the patent record's own words: "to provide a simple and
##     efficient device for checking and regulating the movement of a door ...
##     whereby the same is prevented from slamming", the door being "closed by a
##     spring 3, acting through the shaft 4, lever 5, lever 6, pivotal bolts 7
##     and 8". Erwin's check is a centrifugal governor rather than a liquid one,
##     so it is cited for the purpose and the linkage and NOT for this unit's
##     mechanism.
##
## WHAT I DELIBERATELY DO NOT CLAIM. I found no pre-1928 source requiring that
## a stair door be self-closing, specifying a closing force, a closing time, or
## an inspection interval, so THIS APPARATUS ASSERTS NONE OF THEM. It has no
## schedule, no due date, no required force and no timing standard. It reports
## one thing: whether the leaf came home on its own this time. No modern
## life-safety rule is projected backward anywhere in this file.
##
## ORISON-SPECIFIC INFERENCE: that this building fitted a check to the bulkhead
## leaf at the head of its stair, which is the one leaf in the Orison where
## weather and a stair shaft meet. AUTHORED FAULT: that this unit's arm was
## knocked off its spindle at some point nobody recorded, and that its port was
## left shut.
##
## OWNERSHIP. `DoorProp` remains the sole authority for the leaf. This
## apparatus READS `open`, `leaf_state` and `_moving`, and REQUESTS motion
## through `npc_set_open()`, the same seam `resident_routines.gd` already uses.
## It never writes `leaf_state`, never writes `open`, never touches the leaf's
## transform, and it CANNOT UNLOCK ANYTHING -- a locked leaf is refused, not
## opened. The only transform it maintains is its own arm and its own shoe.
##
## AUTHORING RULE. This prop is a child of the DoorProp NODE, which is the
## frame-fixed hinge line, never of `HingedLeaf`, which is the moving leaf.
## Local +x runs along the head toward the leaf's free edge; local -z is the
## side the leaf swings toward.

## The one neutral fact this apparatus publishes. Nothing subscribes to it.
signal closer_proved(record: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## The two facts that make a closer. Neither is the lock, and neither is the
## leaf's position.
const READY_TERMS := ["arm_shipped", "port_open"]
## What a hand can put a hand on. Nothing else in this apparatus is a control.
const CONTROLS := ["arm", "valve", "hold", "leaf"]
## What a proof record may contain. Every field is something this iron can
## establish by being looked at or by being let go of.
const RECORD_FIELDS := ["door_name", "at_minute", "arm_shipped", "port_open",
		"ready", "requested_by_closer", "reached_closed", "stopped_short"]
## Dizer's leakage port. Screwed home it passes nothing; past this it passes
## enough for the spring to bring the leaf home.
const PORT_WORKING := 0.45
const PORT_STEPS := 5
const HEAD_LEGEND := "DOOR CHECK"

## THE LINKAGE, IN METRES, AND WHY THESE NUMBERS AND NOT PRETTIER ONES.
## The spindle sits near the hinge end of the box, the shoe is bolted to the
## leaf two thirds of the way out, and the two arm links have to REACH IT --
## both with the leaf shut and with it standing at its full hundred degrees.
## The first version of this apparatus had a 0.19 + 0.17 arm and a shoe at
## x 0.76, which needs 0.956 m of arm at full open and had 0.36. It
## photographed as an arm waving at a shoe it could never touch. These lengths
## were solved against the open case (0.602 m required) and then given 18 mm of
## slack, which is why the arm is nearly straight in the open frames -- as a
## real one is.
const SPINDLE := Vector3(0.140, 1.885, -0.090)
const SHOE_PIN := Vector3(0.620, 1.885, -0.078)
const ARM_MAIN := 0.30
const ARM_FORE := 0.32
## `DoorProp` swings a leaf a hundred degrees. The shoe goes with it.
const LEAF_SWING_DEG := 100.0
## Where the regulating screw lives when nothing is refusing. A REST POSE HAS
## TO BE WRITTEN DOWN SOMEWHERE, or a refusal that nudges a part leaves it
## nudged: the valve balk shifts this by 14 mm, `_refresh_closer` used to reset
## only its rotation, and the proof sheet caught it -- a "calm" frame taken
## after five refusals sat 0.00414 off the same state taken before them, on a
## run whose A/A floor is exactly zero.
const VALVE_REST := Vector3(0.423, 1.955, -0.098)

@export var door_path := NodePath("..")

# --- the facts this apparatus owns -------------------------------------------

## The arm's eye is off the spindle. Everything else about the closer is right.
var arm_shipped := false
## The regulating screw, 0 (home) to 1 (wide). Found screwed home.
var port_turns := 0.0
## Whether a hand has actually read the arm this inspection.
var arm_seen := false
## The hold-open catch, thrown so the arm can be worked on safely.
var leaf_held := false
## What the last unattended attempt did.
var last_attempt := ""

var _door: Node = null
var _arm: Node3D
var _forearm: Node3D
var _shoe: Node3D
var _valve: Node3D
var _hold: Node3D
var _knock: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D

var _balk_left := 0.0
var _balk_focus := ""
## The leaf position this apparatus's own arm is currently drawn for.
var _followed := false
var _last_record: Dictionary = {}
var _clock_source: Node = null


# --- what a closer is --------------------------------------------------------

## The arm is on its spindle. Without this the spring pushes nothing.
func connected() -> bool:
	return arm_shipped


## The leakage port will pass liquid. Without this the spring cannot move it.
func metered() -> bool:
	return port_turns >= PORT_WORKING


func ready() -> bool:
	return connected() and metered()


## True of every leaf in the building, at all times, and it is not evidence of
## anything. It is here so that the difference has a name.
func shuts_by_hand() -> bool:
	return true


## Only ever set by an attempt this apparatus itself asked for.
func closes_itself() -> bool:
	return last_attempt == "closed"


## The two names in `READY_TERMS`, whichever of them is still against it, in
## the order a hand can actually fix them: you cannot meter an arm that drives
## nothing.
func faults() -> Array[String]:
	var missing: Array[String] = []
	if not connected():
		missing.append(READY_TERMS[0])
	if not metered():
		missing.append(READY_TERMS[1])
	return missing


func door() -> Node:
	if _door == null or not is_instance_valid(_door):
		_door = get_node_or_null(door_path)
	return _door


func leaf_open() -> bool:
	var leaf := door()
	return leaf != null and bool(leaf.get("open"))


func leaf_locked() -> bool:
	var leaf := door()
	return leaf != null and str(leaf.get("leaf_state")) == "locked"


func leaf_moving() -> bool:
	var leaf := door()
	return leaf != null and bool(leaf.get("_moving"))


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
	return 180.0


func last_record() -> Dictionary:
	return _last_record.duplicate(true)


func port_reads() -> String:
	return "%d/%d" % [int(round(port_turns * PORT_STEPS)), PORT_STEPS]


func balking() -> bool:
	return _balk_left > 0.0


func balk_focus() -> String:
	return _balk_focus


# --- the hand work -----------------------------------------------------------

## Look at the arm. Nothing else in this apparatus tells you what is wrong.
func read_arm() -> bool:
	arm_seen = true
	if _click != null:
		_click.play()
	_refresh_closer()
	return true


## Throw the hold-open catch. The arm cannot be worked while the spring can
## take the leaf out of your hands.
func hold_leaf() -> bool:
	if leaf_held:
		_balk(1.4, "hold")
		return false
	if leaf_moving():
		_balk(1.6, "hold")
		return false
	leaf_held = true
	if _knock != null:
		_knock.play()
	_refresh_closer()
	return true


func release_leaf() -> bool:
	if not leaf_held:
		_balk(1.4, "hold")
		return false
	leaf_held = false
	if _click != null:
		_click.play()
	_refresh_closer()
	return true


## Ship the arm's eye back onto the spindle.
func ship_arm() -> bool:
	if arm_shipped:
		_balk(1.4, "arm")
		return false
	if not leaf_held:
		# The spring is live the moment the eye seats. Working it with the leaf
		# free is how a man loses a hand off a ladder.
		_balk(2.0, "hold")
		return false
	arm_shipped = true
	arm_seen = true
	if _knock != null:
		_knock.play()
	_refresh_closer()
	return true


func unship_arm() -> bool:
	if not arm_shipped:
		_balk(1.4, "arm")
		return false
	if not leaf_held:
		_balk(2.0, "hold")
		return false
	arm_shipped = false
	if _knock != null:
		_knock.play()
	_refresh_closer()
	return true


## Back the regulating screw out one turn. Dizer's leakage port: how far it is
## open is how fast the leaf comes home, and whether it comes home at all.
func turn_check() -> bool:
	if not arm_shipped:
		# Metering a cylinder whose arm drives nothing is adjusting a thing that
		# is not connected to anything.
		_balk(1.8, "arm")
		return false
	var notch := int(round(port_turns * PORT_STEPS)) + 1
	if notch > PORT_STEPS:
		notch = 0
	port_turns = float(notch) / float(PORT_STEPS)
	if _click != null:
		_click.play()
	_refresh_closer()
	return true


## Let the leaf go and watch. This is the only thing in this apparatus that is
## evidence, and it is the only thing that moves the door.
func prove_close() -> bool:
	var leaf := door()
	if leaf == null:
		_balk(1.6, "arm")
		return false
	if leaf_locked():
		# A locked leaf is not a closed leaf and a closer is not a key. This
		# apparatus refuses rather than unlocking anything.
		_balk(2.2, "lock")
		return false
	if leaf_moving():
		_balk(1.4, "arm")
		return false
	if leaf_held:
		# The catch is thrown. Whatever the leaf does now is the catch's doing.
		_balk(2.0, "hold")
		return false
	if not leaf_open():
		# A door already shut proves nothing about what shuts it. THIS IS THE
		# REFUSAL THAT CARRIES THE WHOLE INCREMENT.
		_balk(2.2, "leaf")
		return false
	if not arm_seen:
		_balk(1.8, "arm")
		return false
	if not ready():
		# The closer cannot deliver a close, so it does not ask for one. The
		# leaf stands where it is and the attempt says so.
		last_attempt = "stopped_short"
		_last_record = _record(false, false)
		_balk(2.2, _focus_for_fault())
		closer_proved.emit(_last_record.duplicate(true))
		return false
	# The one request this apparatus ever makes, through the seam residents use.
	leaf.call("npc_set_open", false)
	last_attempt = "closed"
	_last_record = _record(true, true)
	if _click != null:
		_click.play()
	_refresh_closer()
	closer_proved.emit(_last_record.duplicate(true))
	return true


func _focus_for_fault() -> String:
	if not arm_shipped:
		return "arm"
	if not port_turns >= PORT_WORKING:
		return "valve"
	return "leaf"


func _record(requested: bool, reached: bool) -> Dictionary:
	var leaf := door()
	return {
		"door_name": str(leaf.name) if leaf != null else "",
		"at_minute": house_minute(),
		"arm_shipped": arm_shipped,
		"port_open": metered(),
		"ready": ready(),
		"requested_by_closer": requested,
		"reached_closed": reached,
		"stopped_short": not reached,
	}


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {
		"arm_shipped": arm_shipped,
		"port_turns": port_turns,
		"arm_seen": arm_seen,
		"leaf_held": leaf_held,
		"last_attempt": last_attempt,
	}


## Abort restores this apparatus's transient work and NOTHING ELSE. It does not
## move the leaf back, because the leaf was never this apparatus's to hold, and
## it cannot retract a record already published.
func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	arm_shipped = bool(snapshot.get("arm_shipped", false))
	port_turns = float(snapshot.get("port_turns", 0.0))
	arm_seen = bool(snapshot.get("arm_seen", false))
	leaf_held = bool(snapshot.get("leaf_held", false))
	last_attempt = str(snapshot.get("last_attempt", ""))
	_balk_left = 0.0
	_balk_focus = ""
	_refresh_closer()


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	match control_id:
		"arm":
			if not arm_shipped:
				if arm_seen:
					return "[E]  Ship the arm back on its spindle"
				return "[E]  Look at the arm"
			return "[E]  Take the arm off its spindle"
		"valve":
			return "[E]  Regulating screw  (%s)" % port_reads()
		"hold":
			if leaf_held:
				return "[E]  Take the catch off"
			return "[E]  Throw the hold-open catch"
		"leaf":
			if leaf_locked():
				return "[E]  The leaf is locked"
			if leaf_held:
				return "[E]  The catch is holding it"
			if not leaf_open():
				return "[E]  The leaf is already shut"
			return "[E]  Let it go and watch"
	return ""


func interact_control(control_id: String, _player: Node) -> bool:
	match control_id:
		"arm":
			if not arm_seen:
				return read_arm()
			return unship_arm() if arm_shipped else ship_arm()
		"valve":
			return turn_check()
		"hold":
			return release_leaf() if leaf_held else hold_leaf()
		"leaf":
			return prove_close()
	return false


## The answer to a player looking straight at it — the lesson SR7-N paid for.
func interact_prompt() -> String:
	return control_prompt("arm")


func interact(player: Node) -> void:
	interact_control("arm", player)


# --- pose --------------------------------------------------------------------

func _balk(seconds: float, focus := "") -> void:
	var already := _balk_left > 0.0
	_balk_focus = focus
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()
	# Applied here rather than left to `_process`, because a frozen sheet does
	# not tick and a refusal nobody can photograph is not a refusal.
	_refresh_closer()


func _process(delta: float) -> void:
	# One bool off one cached node. An arm bolted between a frame and a leaf
	# follows the leaf whether anybody asked it to or not, and `DoorProp` has
	# no signal to be told by. This READS the door's public `open`; it is the
	# apparatus's own arm that moves.
	var swung := leaf_open()
	if swung != _followed:
		_followed = swung
		_swing_arm(swung)
	if _balk_left <= 0.0:
		return
	_balk_left = maxf(0.0, _balk_left - delta)
	if _balk_left <= 0.0:
		_balk_focus = ""
		_refresh_closer()


## The arm going with the leaf, over the same half second `DoorProp` spends on
## it, so the two are never seen disagreeing. Every property here belongs to
## this apparatus; not one of them is the door's.
func _swing_arm(swung: bool) -> void:
	if _shoe == null or _arm == null or _forearm == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_shoe, "rotation:y",
			deg_to_rad(LEAF_SWING_DEG) if swung else 0.0,
			0.5).set_trans(Tween.TRANS_SINE)
	if not arm_shipped:
		return
	var angles := _arm_angles(swung)
	tween.tween_property(_arm, "rotation:y", angles.x,
			0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_forearm, "rotation:y", angles.y,
			0.5).set_trans(Tween.TRANS_SINE)


## Every owned fact, put back onto the iron. THE LEAF IS NEVER POSED HERE: this
## reads the door's angle and moves only this apparatus's own arm and shoe.
func _refresh_closer() -> void:
	var swung := leaf_open()
	_followed = swung
	if _shoe != null:
		# The shoe is bolted to the leaf, so it rides where the leaf is. This
		# apparatus draws it; it does not decide where the leaf went.
		_shoe.rotation.y = deg_to_rad(LEAF_SWING_DEG) if swung else 0.0
	var angles := _arm_angles(swung)
	if _arm != null:
		_arm.position = SPINDLE
		if not arm_shipped:
			# UNSHIPPED: the eye is off the spindle and the whole arm hangs on
			# its own elbow, well clear of the shoe. That is the diagnosis, and
			# it is the one pose in this file that is NOT a reach solution --
			# because an arm that is connected to nothing is not solving for
			# anything.
			_arm.rotation = Vector3(0.0, -0.34, -0.92)
		else:
			_arm.rotation = Vector3(0.0, angles.x, 0.0)
	if _forearm != null:
		_forearm.rotation.y = -0.95 if not arm_shipped else angles.y
	if _valve != null:
		_valve.rotation.x = port_turns * TAU * 0.75
		_valve.position = VALVE_REST
	if _hold != null:
		_hold.rotation.z = deg_to_rad(-78.0) if leaf_held else 0.0
	if _balk_left <= 0.0:
		return
	# --- refusals, each one a different photograph ---------------------------
	match _balk_focus:
		"arm":
			if _arm != null:
				_arm.rotation.z += 0.22
				_arm.position.z -= 0.030
		"valve":
			if _valve != null:
				_valve.rotation.x += 0.55
				_valve.position.x += 0.014  # undone by VALVE_REST above
		"hold":
			if _hold != null:
				_hold.rotation.z += 0.34 if leaf_held else -0.26
		"leaf":
			# The leaf is where it is and this apparatus will not move it to
			# make a point. What jogs is the arm that had nothing to do.
			if _arm != null:
				_arm.rotation.y += 0.16
		"lock":
			if _hold != null:
				_hold.rotation.z += 0.18
			if _arm != null:
				_arm.rotation.y -= 0.10


## Where the shoe pin stands, in the XZ plane, for a shut or a swung leaf. The
## shoe is on the leaf and the leaf turns about this node's own origin, which
## IS the hinge line -- so this is the same rotation `DoorProp` applies, done
## to this apparatus's own bracket rather than to the leaf.
func _shoe_xz(swung: bool) -> Vector2:
	if not swung:
		return Vector2(SHOE_PIN.x, SHOE_PIN.z)
	var a := deg_to_rad(LEAF_SWING_DEG)
	return Vector2(SHOE_PIN.x * cos(a) + SHOE_PIN.z * sin(a),
			-SHOE_PIN.x * sin(a) + SHOE_PIN.z * cos(a))


## Two links, one shoe: the arm and forearm angles that actually put the eye ON
## the pin. Plain trigonometry, solved every time the leaf moves, so the arm can
## never be drawn reaching for a shoe it does not touch.
func _arm_angles(swung: bool) -> Vector2:
	var pin := _shoe_xz(swung)
	var dx := pin.x - SPINDLE.x
	var dz := pin.y - SPINDLE.z
	var reach := clampf(sqrt(dx * dx + dz * dz), 0.001,
			ARM_MAIN + ARM_FORE - 0.001)
	var phi := atan2(-dz, dx)
	var beta := acos(clampf(
			(reach * reach + ARM_MAIN * ARM_MAIN - ARM_FORE * ARM_FORE)
			/ (2.0 * reach * ARM_MAIN), -1.0, 1.0))
	var gamma := acos(clampf(
			(ARM_MAIN * ARM_MAIN + ARM_FORE * ARM_FORE - reach * reach)
			/ (2.0 * ARM_MAIN * ARM_FORE), -1.0, 1.0))
	return Vector2(phi + beta, -(PI - gamma))


# --- build -------------------------------------------------------------------

func _build_visual() -> void:
	_build_box()
	_build_arm()
	_build_shoe()
	_build_hold()
	_build_reaches()
	_knock = make_emitter("knock", -15.0)
	_click = make_emitter("pop", -20.0)
	_refresh_closer()


## Dizer's spring box and cylinder, on the frame head above the leaf, with the
## spindle under its hinge end where a top-jamb closer carries one.
func _build_box() -> void:
	var iron := Color(0.225, 0.215, 0.205)
	var brass := Color(0.72, 0.56, 0.24)
	var plate := make_box(Vector3(0.400, 0.115, 0.016),
			Vector3(0.235, 1.955, -0.062), iron)
	plate.name = "HeadPlate"
	for strap_x in [0.062, 0.408]:
		make_box(Vector3(0.028, 0.135, 0.052),
				Vector3(strap_x, 1.955, -0.082), iron)
	var barrel := make_cyl(0.043, 0.043, 0.330,
			Vector3(0.235, 1.955, -0.098), iron, 0.42, 0.55)
	barrel.name = "CheckCylinder"
	barrel.rotation.z = PI * 0.5
	make_cyl(0.047, 0.047, 0.022, Vector3(0.073, 1.955, -0.098), brass, 0.34,
			0.78).rotation.z = PI * 0.5
	make_cyl(0.047, 0.047, 0.022, Vector3(0.397, 1.955, -0.098), brass, 0.34,
			0.78).rotation.z = PI * 0.5
	# The filler plug: where the liquid goes in, and the first thing a man
	# looks at when he thinks the cylinder is empty.
	make_cyl(0.014, 0.014, 0.018, Vector3(0.180, 1.996, -0.098), brass, 0.32,
			0.80)
	# THE REGULATING SCREW, on the far end of the cylinder. Its slot is the
	# reading, and how far it is out is how fast the leaf comes home.
	_valve = Node3D.new()
	_valve.name = "RegulatingScrew"
	_valve.position = VALVE_REST
	add_child(_valve)
	var head := make_cyl(0.019, 0.019, 0.020, Vector3.ZERO, brass, 0.30, 0.82,
			_valve)
	head.rotation.z = PI * 0.5
	# THE INDEX TANG, and it is this long because the first sheet measured the
	# earlier one. A 30 mm slot cut in the screw head moved its own tight crop
	# by 0.000375 against an A/A floor of exactly zero -- which is to say the
	# setting was NOT readable, whatever the comment claimed. A brass tang
	# sweeping past a witness mark is how a man actually reads a regulating
	# screw, and it is what this now carries.
	_move(make_box(Vector3(0.007, 0.052, 0.010), Vector3.ZERO, brass), _valve,
			Vector3(0.013, 0.020, 0.0))
	# The witness mark it is read against: fixed to the cylinder, never turns.
	make_box(Vector3(0.005, 0.026, 0.007), Vector3(0.436, 2.000, -0.098),
			Color(0.86, 0.84, 0.78))
	# The spindle the arm ships onto, under the box's hinge end.
	make_cyl(0.013, 0.013, 0.052, SPINDLE + Vector3(0.0, 0.022, 0.0), brass,
			0.34, 0.78)
	_letter("HeadLegend", HEAD_LEGEND, Vector3(0.235, 1.912, -0.056), 0.0135,
			Color(0.80, 0.78, 0.72))


## The jointed arm: main arm on the spindle, forearm to the shoe. Both are
## THIS apparatus's own geometry and neither is ever the leaf.
func _build_arm() -> void:
	var iron := Color(0.235, 0.225, 0.215)
	_arm = Node3D.new()
	_arm.name = "MainArm"
	_arm.position = SPINDLE
	add_child(_arm)
	make_cyl(0.016, 0.016, 0.030, Vector3.ZERO, iron, 0.44, 0.60, _arm)
	_move(make_box(Vector3(ARM_MAIN, 0.026, 0.021), Vector3.ZERO, iron), _arm,
			Vector3(ARM_MAIN * 0.5, 0.0, 0.0))
	_forearm = Node3D.new()
	_forearm.name = "Forearm"
	_forearm.position = Vector3(ARM_MAIN, 0.0, 0.0)
	_arm.add_child(_forearm)
	make_cyl(0.013, 0.013, 0.026, Vector3.ZERO, iron, 0.44, 0.60, _forearm)
	_move(make_box(Vector3(ARM_FORE - 0.03, 0.021, 0.018), Vector3.ZERO, iron),
			_forearm, Vector3((ARM_FORE - 0.03) * 0.5, 0.0, 0.0))
	# The eye that goes over the shoe pin, and whose being off it is the fault.
	make_ring(0.015, 0.005, Vector3(ARM_FORE, 0.0, 0.0), iron, 0.44, 0.60,
			_forearm).rotation.x = PI * 0.5


## The shoe, bolted to the leaf's top rail. Drawn here and turned about the
## hinge line by the door's own reported angle; the leaf itself is never
## written.
func _build_shoe() -> void:
	var iron := Color(0.215, 0.205, 0.195)
	_shoe = Node3D.new()
	_shoe.name = "ShoePivot"
	add_child(_shoe)
	_move(make_box(Vector3(0.080, 0.052, 0.022), Vector3.ZERO, iron), _shoe,
			SHOE_PIN + Vector3(0.0, 0.0, 0.020))
	_move(make_cyl(0.010, 0.010, 0.036, Vector3.ZERO, iron, 0.42, 0.60), _shoe,
			SHOE_PIN)


## The hold-open catch: a plain iron bar on the head near the free edge, thrown
## down across the leaf so a man can work the arm without the spring in his
## hands.
func _build_hold() -> void:
	var iron := Color(0.195, 0.188, 0.180)
	# The lug that carries it, bolted up under the head. The first pass hung
	# the catch on nothing at all and it photographed as a bar floating in the
	# doorway; a thing bolted to a building has to be seen bolted to it.
	make_box(Vector3(0.044, 0.052, 0.020), Vector3(0.560, 2.062, -0.084), iron)
	_hold = Node3D.new()
	_hold.name = "HoldOpenCatch"
	_hold.position = Vector3(0.560, 2.040, -0.084)
	add_child(_hold)
	make_cyl(0.011, 0.011, 0.024, Vector3.ZERO, iron, 0.44, 0.60, _hold)
	_move(make_box(Vector3(0.026, 0.170, 0.018), Vector3.ZERO, iron), _hold,
			Vector3(0.0, -0.085, 0.0))


## `make_box` hangs its mesh on the prop; this moves one onto a sub-pivot
## without going through `reparent`.
func _move(mesh: MeshInstance3D, parent: Node3D, at: Vector3) -> MeshInstance3D:
	remove_child(mesh)
	parent.add_child(mesh)
	mesh.position = at
	return mesh


func _letter(node_name: String, text: String, at: Vector3, em: float,
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
	label.rotation.y = PI
	(parent if parent != null else self).add_child(label)
	return label


## Four places to put a hand. The only ordering between them is what the spring
## imposes: you cannot ship a live arm, and you cannot meter an arm that drives
## nothing.
func _build_reaches() -> void:
	var reaches := {
		"arm": [Vector3(0.185, 1.860, -0.115), Vector3(0.22, 0.20, 0.16)],
		"valve": [Vector3(0.440, 1.955, -0.098), Vector3(0.09, 0.09, 0.12)],
		"hold": [Vector3(0.560, 1.960, -0.090), Vector3(0.11, 0.22, 0.14)],
		"leaf": [Vector3(0.620, 1.700, -0.070), Vector3(0.26, 0.22, 0.16)],
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


func service_wire_card() -> Dictionary:
	return {
		"title": "OVERHEAD DOOR CHECK",
		"body": "A SPRING SHUTS THE LEAF AND THE LEAKAGE PORT DECIDES HOW "
				+ "SLOWLY STOP A LEAF THAT SHUTS BY HAND PROVES NEITHER STOP",
		"condition": "ARM %s / PORT %s / READY %s" % [
				"SHIPPED" if arm_shipped else "OFF", port_reads(),
				"YES" if ready() else "NO"],
		"stamp": "DOOR CHECK",
	}
