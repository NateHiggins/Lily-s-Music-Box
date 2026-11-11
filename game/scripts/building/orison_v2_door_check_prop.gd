extends "res://scripts/props/door_check_closer_prop.gd"
## The overhead liquid door check on V2's roof stair door
## (v1r_door_closer_b_20261109), worked by direct manipulation (RUL-013).
##
## The V1 apparatus keeps its facts (arm_shipped, port_turns, arm_seen,
## leaf_held, last_attempt), its predicates, its refusals, its record and its
## words. Three things are V2's:
##
## THE IRON IS REAL AND IT IS ON THE OTHER SIDE. V1 drew the box on the side the
## leaf swings toward, where a real leaf would have to pass through it. This one
## is the top-jamb fitting: plate and cylinder on the head on the STAIR side,
## spindle under the hinge end, the arm reaching through the opening to a shoe
## on the leaf's stair face. Nothing fixed stands in the swing. The two links
## keep V1's lengths (ARM_MAIN, ARM_FORE); the spindle and shoe were solved
## against the real leaf's hundred degrees in art/blender/scripts/
## build_fire_apparatus.py.
##
## THE ARM FOLLOWS THE LEAF, NOT A BOOL. V1 followed `open`. This reads the
## leaf's own reported angle (`mechanism_snapshot`) every frame and solves both
## links onto the shoe pin, so a leaf held half open by a hand has an arm that
## reaches it.
##
## LETTING GO OF THE LEAF IS THE PROOF. Every other V2 door eases itself shut. On
## this leaf the check decides: with the arm shipped and the port passing, the
## spring brings the leaf home at the rate the port allows and it latches; with
## the arm off or the port screwed shut (as found) the leaf stands where the hand
## left it, and V1's own `prove_close()` records that it stopped short. The leaf
## is still `DoorProp`'s: this apparatus reads its angle, moves it only through
## its public `restore_mechanism`, and never unlocks anything.
##
## THE HAND: the regulating screw turns (three quarters of a turn, home to wide),
## the catch throws over its centre, and the arm is lifted onto its spindle or
## let down off it. V1's refusals are the travel stops: the screw will not be
## metered with the arm off, and the arm will not be shipped or unshipped with
## the catch off.

signal manipulation_changed

const Stock := preload("res://scripts/building/orison_v2_native_fire_apparatus.gd")

## Radians a second the spring brings the leaf home: with the port only just
## passing, and with the screw backed right out.
const CLOSE_RATE_CHECKED := 0.18
const CLOSE_RATE_WIDE := 0.90
const VALVE_SWEEP := TAU * 0.75
## Seventy-eight degrees, V1's throw for the catch.
const HOLD_THROW := -1.3613568
## The arm cannot be lifted past here against a live spring.
const ARM_LIVE_STOP := 0.35
const ARM_UNSHIP_AT := 0.85
## V1's pose for an arm off its spindle.
const ARM_HUNG := Vector3(0.0, -0.34, -0.92)
const FOREARM_HUNG := -0.95

var stock: RefCounted
var spindle := Vector3.ZERO
var shoe_pin := Vector3.ZERO
var hinge_z := 0.0
## 0 hanging off the spindle .. 1 shipped.
var arm_seat := 0.0
## 0 free .. 1 thrown.
var hold_throw := 0.0
## True while the spring is bringing the leaf home.
var closing := false

var _hand := ""
var _refused := false
var _settle: Tween
var _settle_property := ""
var _settle_goal := 0.0
var _drawn_angle := INF
var _watching := false
var _station_clock := 0.0
var _notch := 0
var _leaf_signal_bound := false


# --- build -------------------------------------------------------------------

func _build_visual() -> void:
	stock = Stock.shared()
	if stock == null:
		push_error("V2 door check has no native stock")
		return
	spindle = stock.datum("door_check", "spindle")
	shoe_pin = stock.datum("door_check", "shoe_pin")
	hinge_z = float(stock.data.door_check.hinge_axis_z)
	for part_name: String in ["Check__Body_ON_iron_blackened", "Check__BodyBrass_ON_brass",
			"Check__Witness_ON_indicator_enamel"]:
		add_child(stock.draw(part_name))
	# V1 writes its own SPINDLE and VALVE_REST onto these two every refresh; the
	# mounts carry them to where this fitting's spindle and screw really are.
	var arm_mount := Node3D.new()
	arm_mount.name = "ArmMount"
	arm_mount.position = spindle - SPINDLE
	add_child(arm_mount)
	_arm = stock.draw("Check__MainArm_ON_iron_blackened", "MainArm")
	arm_mount.add_child(_arm)
	_forearm = stock.draw("Check__Forearm_ON_iron_blackened", "Forearm")
	_forearm.position = Vector3(ARM_MAIN, 0.0, 0.0)
	_arm.add_child(_forearm)
	_shoe = stock.draw("Check__Shoe_ON_iron_blackened", "ShoePivot")
	_shoe.position = Vector3(0.0, 0.0, hinge_z)
	add_child(_shoe)
	var valve_mount := Node3D.new()
	valve_mount.name = "ValveMount"
	valve_mount.position = stock.datum("door_check", "valve_rest") - VALVE_REST
	add_child(valve_mount)
	_valve = stock.draw("Check__RegulatingScrew_ON_brass", "RegulatingScrew")
	valve_mount.add_child(_valve)
	_hold = stock.draw("Check__HoldOpenCatch_ON_iron_blackened", "HoldOpenCatch")
	_hold.position = stock.datum("door_check", "hold_pivot")
	add_child(_hold)
	var legend := _letter("HeadLegend", HEAD_LEGEND, stock.datum("door_check", "legend"), 0.0135,
			Color(0.80, 0.78, 0.72))
	legend.rotation.y = 0.0   # V1's faced the swing side; this one faces the stair
	_reach("valve", valve_mount, VALVE_REST + Vector3(0.006, 0.0, 0.0), Vector3(0.06, 0.12, 0.12))
	_reach("hold", self, _hold.position + Vector3(0.012, 0.018, 0.008), Vector3(0.07, 0.07, 0.05))
	_reach("arm", _arm, Vector3(ARM_MAIN * 0.5, 0.0, 0.0), Vector3(ARM_MAIN, 0.05, 0.05))
	_reach("arm", _forearm, Vector3(ARM_FORE * 0.5, float(stock.data.door_check.forearm_drop), 0.0),
			Vector3(ARM_FORE - 0.04, 0.05, 0.05))
	_knock = make_emitter("knock", -15.0)
	_click = make_emitter("pop", -20.0)
	arm_seat = 1.0 if arm_shipped else 0.0
	hold_throw = 1.0 if leaf_held else 0.0
	_notch = int(round(port_turns * PORT_STEPS))
	set_physics_process(true)
	_refresh_closer()


func _reach(control_id: String, parent: Node3D, at: Vector3, size: Vector3) -> void:
	var reach := ControlArea.new()
	reach.name = "Reach_%s" % control_id
	reach.configure(control_id)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = at
	reach.add_child(shape_node)
	parent.add_child(reach, true)


## Whether this stock fits the leaf it has been hung on: the fitting is made for
## one door's height, hinge line and swing.
func fits(leaf: Node) -> bool:
	if stock == null or leaf == null or not leaf.has_method("motion_target_angle"):
		return false
	var made: Dictionary = stock.data.door_check
	return absf(float(leaf.get("height")) - float(made.leaf_height)) < 0.002 \
			and absf(float(leaf.get("_hinge_offset")) + float(made.hinge_axis_z)) < 0.002 \
			and float(leaf.call("motion_target_angle", true)) > 1.7


# --- the leaf, read and never owned -------------------------------------------

## The leaf's own reported angle about its hinge line.
func leaf_angle() -> float:
	var leaf := door()
	if leaf == null or not leaf.has_method("mechanism_snapshot"):
		return 0.0
	return float(leaf.call("mechanism_snapshot").angle)


func leaf_in_hand() -> bool:
	var leaf := door()
	return leaf != null and bool(leaf.get("_hand_gripped"))


## Where the shoe pin stands for the leaf as it is, in this prop's (x, z).
func _shoe_xz(_swung: bool) -> Vector2:
	var angle := leaf_angle()
	var out := Vector2(shoe_pin.x, shoe_pin.z - hinge_z)
	return Vector2(out.x * cos(angle) + out.y * sin(angle),
			-out.x * sin(angle) + out.y * cos(angle) + hinge_z)


## V1's two-link solution, about this fitting's spindle, elbow out over the
## stair so the links never cross the leaf.
func _arm_angles(swung: bool) -> Vector2:
	var pin := _shoe_xz(swung)
	var dx := pin.x - spindle.x
	var dz := pin.y - spindle.z
	var reach := clampf(sqrt(dx * dx + dz * dz), 0.001, ARM_MAIN + ARM_FORE - 0.001)
	var phi := atan2(-dz, dx)
	var beta := acos(clampf((reach * reach + ARM_MAIN * ARM_MAIN - ARM_FORE * ARM_FORE)
			/ (2.0 * reach * ARM_MAIN), -1.0, 1.0))
	var gamma := acos(clampf((ARM_MAIN * ARM_MAIN + ARM_FORE * ARM_FORE - reach * reach)
			/ (2.0 * ARM_MAIN * ARM_FORE), -1.0, 1.0))
	return Vector2(phi - beta, PI - gamma)


## The eye on the end of the forearm, in world space.
func forearm_eye() -> Vector3:
	return _forearm.to_global(Vector3(ARM_FORE, 0.0, 0.0))


## The shoe's pin, in world space, at the height of the arm.
func shoe_pin_world() -> Vector3:
	return _shoe.to_global(Vector3(shoe_pin.x, shoe_pin.y, shoe_pin.z - hinge_z))


## V1 swung the arm over half a second when `open` flipped. The arm here is
## solved from the leaf's angle every frame, so there is nothing to tween.
func _swing_arm(_swung: bool) -> void:
	pass


func _process(delta: float) -> void:
	super._process(delta)
	_bind_leaf()
	var angle := leaf_angle()
	if not is_equal_approx(angle, _drawn_angle):
		_refresh_closer()


func _bind_leaf() -> void:
	if _leaf_signal_bound:
		return
	var leaf := door()
	if leaf != null and leaf.has_signal("manipulation_changed"):
		leaf.connect("manipulation_changed", _on_leaf_let_go)
		_leaf_signal_bound = true


## A hand has just let go of the leaf. That is the only test this apparatus has
## ever had, so V1's proof runs on it.
func _on_leaf_let_go() -> void:
	if closing or leaf_in_hand() or not leaf_open():
		return
	prove_close()


# --- what the check does to a leaf nobody is holding --------------------------

## Radians a second the leaf comes home at, or nothing at all.
func close_rate() -> float:
	if not ready() or leaf_held:
		return 0.0
	return lerpf(CLOSE_RATE_CHECKED, CLOSE_RATE_WIDE,
			clampf(inverse_lerp(PORT_WORKING, 1.0, port_turns), 0.0, 1.0))


## V1 asked the door to shut itself over half a second. Here the spring does it,
## at the rate the port allows; V1 still makes every refusal and the record of a
## leaf that stopped short.
func prove_close() -> bool:
	var leaf := door()
	var can_deliver := leaf != null and not leaf_locked() and not leaf_moving() \
			and not leaf_held and leaf_open() and arm_seen and ready()
	if not can_deliver:
		return super.prove_close()
	_watching = true
	closing = true
	return true


func _physics_process(delta: float) -> void:
	var leaf := door()
	if leaf == null or stock == null:
		return
	var angle := leaf_angle()
	if absf(angle) < 0.0005:
		closing = false
		_watching = false
		return
	if leaf_in_hand() or leaf_moving() or bool(leaf.get("_key_turning")) or leaf_locked():
		# Somebody else has the leaf. Whatever happens now is not this spring's.
		closing = false
		_watching = false
		_station_clock = 0.0
		return
	var rate := close_rate()
	if rate <= 0.0 or bool(leaf.call("hose_blocks_close")) or _someone_in_the_swing(leaf):
		# The leaf stands. Re-seat it now and then so the building's ordinary
		# easy-closing never shuts a leaf this check would not have shut.
		closing = false
		_station_clock -= delta
		if _station_clock <= 0.0:
			_station_clock = 1.0
			leaf.call("restore_mechanism", {"angle": angle})
		return
	closing = true
	var next := move_toward(angle, 0.0, rate * delta)
	leaf.call("restore_mechanism", {"angle": next})
	if absf(next) < 0.0005:
		_latched(leaf, rate)


func _latched(leaf: Node, rate: float) -> void:
	closing = false
	if _knock != null:
		_knock.volume_db = lerpf(-22.0, -9.0, clampf(inverse_lerp(CLOSE_RATE_CHECKED, CLOSE_RATE_WIDE, rate), 0.0, 1.0))
		_knock.play()
	if _watching:
		_watching = false
		last_attempt = "closed"
		_last_record = _record(true, true)
		closer_proved.emit(_last_record.duplicate(true))
	leaf.emit_signal("manipulation_changed")
	_refresh_closer()


## A resident has no say over a spring: never bring the leaf home on one.
func _someone_in_the_swing(leaf: Node) -> bool:
	var frame := leaf as Node3D
	if frame == null:
		return false
	for node: Node in get_tree().get_nodes_in_group("animated_residents"):
		var body := node as Node3D
		if body == null or not body.visible:
			continue
		var at := frame.to_local(body.global_position)
		if at.y > -0.2 and at.y < float(leaf.get("height")) + 0.2 \
				and Vector2(at.x, at.z).length() < float(leaf.get("width")) + 0.45:
			return true
	return false


# --- V1's hand work, kept in step with where the parts are ---------------------

func ship_arm() -> bool:
	var done := super.ship_arm()
	if done and _hand != "arm":
		arm_seat = 1.0
		_refresh_closer()
	return done


func unship_arm() -> bool:
	var done := super.unship_arm()
	if done and _hand != "arm":
		arm_seat = 0.0
		_refresh_closer()
	return done


func hold_leaf() -> bool:
	var done := super.hold_leaf()
	if done and _hand != "hold":
		hold_throw = 1.0
		_refresh_closer()
	return done


func release_leaf() -> bool:
	var done := super.release_leaf()
	if done and _hand != "hold":
		hold_throw = 0.0
		_refresh_closer()
	return done


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	_finish_settle()
	_hand = ""
	super.restore_maintenance_snapshot(snapshot)
	arm_seat = 1.0 if arm_shipped else 0.0
	hold_throw = 1.0 if leaf_held else 0.0
	_notch = int(round(port_turns * PORT_STEPS))
	closing = false
	_watching = false
	_refresh_closer()


# --- direct manipulation -------------------------------------------------------

func control_grip(control_id: String, _area: Node) -> Dictionary:
	if stock == null:
		return {"legacy": true}
	match control_id:
		"valve":
			return _grip("valve", _valve, 0.0, VALVE_SWEEP, 520.0, Vector2.RIGHT,
					func() -> float: return port_turns * VALVE_SWEEP, _turn_screw, _begin_screw)
		"hold":
			return _grip("hold", _hold, 0.0, 1.0, 150.0, Vector2.DOWN,
					func() -> float: return hold_throw, _throw_catch, _begin_catch)
		"arm":
			return _grip("arm", _arm, 0.0, 1.0, 300.0, Vector2.UP,
					func() -> float: return arm_seat, _lift_arm, _begin_arm)
	return {"legacy": true}


func _grip(id: String, part: Node3D, low: float, high: float, pixels: float, screen: Vector2,
		read: Callable, write: Callable, begin: Callable) -> Dictionary:
	return {"owner": self, "part": part, "frame": self, "kind": "hinge", "axis": Vector3.RIGHT,
		"minimum": low, "maximum": high, "gesture_travel_px": pixels, "gesture_screen_axis": screen,
		"unobstructed_hold": true, "read": read, "write": write, "begin": begin,
		"owns": func() -> bool: return _hand == id, "end": _end_hand}


func _take(id: String) -> bool:
	if _hand != "":
		return false
	_finish_settle()
	_hand = id
	_refused = false
	return true


func _begin_screw() -> bool:
	if not arm_shipped:
		turn_check()   # V1's refusal: metering an arm that drives nothing
		return false
	return _take("valve")


func _begin_catch() -> bool:
	if leaf_moving():
		_balk(1.6, "hold")
		return false
	return _take("hold")


func _begin_arm() -> bool:
	if not _take("arm"):
		return false
	if not arm_seen:
		read_arm()   # taking hold of it is looking at it
	return true


## The regulating screw follows the hand; the port is how far it is out.
func _turn_screw(angle: float) -> void:
	if _hand != "valve":
		return
	port_turns = clampf(angle / VALVE_SWEEP, 0.0, 1.0)
	var notch := int(round(port_turns * PORT_STEPS))
	if notch != _notch:
		_notch = notch
		if _click != null:
			_click.play()
	_refresh_closer()


## The catch goes over its centre: V1's fact changes there and nowhere else.
func _throw_catch(value: float) -> void:
	if _hand != "hold":
		return
	hold_throw = clampf(value, 0.0, 1.0)
	if not leaf_held and hold_throw >= 0.9:
		hold_leaf()
	elif leaf_held and hold_throw <= 0.1:
		release_leaf()
	_refresh_closer()


func _lift_arm(value: float) -> void:
	if _hand != "arm":
		return
	var wanted := clampf(value, 0.0, 1.0)
	if not arm_shipped:
		if not leaf_held and wanted > ARM_LIVE_STOP:
			# The spring is live the moment the eye seats: V1 refuses.
			wanted = ARM_LIVE_STOP
			if not _refused:
				_refused = true
				ship_arm()
		arm_seat = wanted
		if leaf_held and arm_seat >= 1.0:
			ship_arm()
	else:
		if not leaf_held and wanted < 1.0:
			wanted = 1.0
			if not _refused:
				_refused = true
				unship_arm()
		arm_seat = wanted
		if leaf_held and arm_seat <= ARM_UNSHIP_AT:
			unship_arm()
	_refresh_closer()


func _end_hand() -> void:
	var was := _hand
	_hand = ""
	match was:
		"hold":
			# Over-centre: it falls to whichever side it was left on.
			_settle_to("hold_throw", 1.0 if leaf_held else 0.0)
		"arm":
			# An arm that is not on its spindle hangs; one that is, sits.
			_settle_to("arm_seat", 1.0 if arm_shipped else 0.0)
	if was != "":
		manipulation_changed.emit()
	_refresh_closer()


func _settle_to(property: String, goal: float) -> void:
	_finish_settle()
	var from: float = get(property)
	_settle_property = property
	_settle_goal = goal
	if is_equal_approx(from, goal) or not is_inside_tree():
		_finish_settle()
		return
	_settle = create_tween()
	_settle.tween_method(_set_travel.bind(property), from, goal,
			clampf(absf(goal - from) * 0.5, 0.06, 0.35)).set_trans(Tween.TRANS_SINE)
	_settle.tween_callback(_finish_settle)


func _finish_settle() -> void:
	if _settle != null and _settle.is_valid():
		_settle.kill()
	_settle = null
	if _settle_property.is_empty():
		return
	var property := _settle_property
	_settle_property = ""
	_set_travel(_settle_goal, property)


func _set_travel(value: float, property: String) -> void:
	set(property, value)
	_refresh_closer()


# --- pose --------------------------------------------------------------------

func _refresh_closer() -> void:
	super._refresh_closer()
	if stock == null or _arm == null or _forearm == null or _shoe == null:
		return
	var angle := leaf_angle()
	_drawn_angle = angle
	# The shoe is bolted to the leaf: it stands at the leaf's own angle.
	_shoe.rotation.y = angle
	# The arm between hanging and shipped, wherever the hand has it.
	var solved := _arm_angles(false)
	if arm_seat > 0.0 and arm_seat < 1.0:
		var hung := Quaternion.from_euler(ARM_HUNG)
		var seated := Quaternion.from_euler(Vector3(0.0, solved.x, 0.0))
		_arm.quaternion = hung.slerp(seated, arm_seat)
		_forearm.rotation.y = lerp_angle(FOREARM_HUNG, solved.y, arm_seat)
	# The catch, between free and thrown, keeping whatever V1's refusal added.
	if _hold != null:
		var v1_throw := HOLD_THROW if leaf_held else 0.0
		_hold.rotation.z = HOLD_THROW * hold_throw + (_hold.rotation.z - v1_throw)
