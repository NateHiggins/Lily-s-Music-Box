class_name ElevatorInterlockProp
extends FunctionalProp
## The landing-door interlock at the production elevator's F01 opening.
##
## SR7-B. The mechanical basis is the interlock named in
## `design/ORISON_SERVICE_ROUND_BRIEF.md`: Otis's landing-door interlock
## (E. L. Dunn, US 1,493,069, filed 1921, granted 1924), read alongside the
## hoistway-door interlock definition in the first American Elevator Safety
## Code of 1921.
##
## THE TRUTH THIS TEACHES. The 1921 code does not say the door must be SHUT.
## It says the car may not move away from a landing unless the door at that
## landing is "locked in the closed position" -- and that is two different
## facts, proved by two different contacts wired in series:
##
##   the SHUT contact    made when the door's leading edge is home;
##   the LOCKED contact  made only when the latch has actually entered the
##                       keeper to its full depth.
##
## A door can be shut and not locked. That is the whole gap the interlock
## exists to close. And a wire laid across the pair reads as perfect
## continuity while proving neither -- which is why the fault this round
## corrects is not a broken part but a working bridge.
##
## AUTHORING RULE. Local z = 0 is the mounting plane on the hoistway side of
## the reveal, and the apparatus is built OUTWARD along +z toward the lobby.
## The prop carries no rotation: `GameBoot.b2g` maps Blender -y to Godot +z,
## and the lobby is at Blender -y from the shaft, so an unrotated prop already
## faces the room.
##
## OWNERSHIP. This prop owns the interlock and nothing else. It does not own
## the elevator, its doors, its car or its state; it asks `OrisonElevator`
## through two guarded public methods and accepts a refusal. It closes no job,
## advances no case, publishes no plant state, creates no Dream fact and holds
## no save record. Only `apply_maintenance_result` changes its durable local
## condition.

signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## The keeper is true when the latch can enter to full depth. The authored
## activity targets this, so the book and the mechanism agree on "trued"
## without either importing the other.
const KEEPER_TRUE := 0.78
## Below this the latch is not in the keeper, whatever the door is doing.
const LOCKED_DEPTH := 0.70
## The door's leading edge is home at this much of its travel.
const SHUT_HOME := 0.92

var _service_panel: MaintenanceActivityPanel
var _elevator: Node                     # OrisonElevator, when one is bound
var _level := "F01"

var _case: MeshInstance3D
var _keeper: MeshInstance3D
var _latch: MeshInstance3D
var _roller_arm: MeshInstance3D
var _roller: MeshInstance3D
var _cam: MeshInstance3D
var _jumper: MeshInstance3D
var _gauge: MeshInstance3D
var _shut_face: MeshInstance3D
var _locked_face: MeshInstance3D
var _shut_mat: StandardMaterial3D
var _locked_mat: StandardMaterial3D
var _knock: AudioStreamPlayer3D
var _balk_left := 0.0
var _t := 0.0

## The mechanism's own facts.
##
## `jumper_present` true is the fault the round exists to correct. Note what it
## is NOT: nothing here is broken. The lock works, the door works, the car
## answers. Somebody simply made the circuit stop being able to say no.
var jumper_present := true
var keeper_true := 0.34
var door_home := 0.0
var gauge_set := 0.0
var interlock_proved := false


# --- geometry ---------------------------------------------------------------

func _build_visual() -> void:
	var iron := Color(0.13, 0.12, 0.115)
	var steel := Color(0.44, 0.45, 0.47)
	var brass := Color(0.46, 0.37, 0.19)

	# The lock case, screwed to the hoistway side of the strike jamb. Everything
	# else hangs off it, the way a real interlock is one bolted-on assembly
	# rather than parts scattered around a doorway.
	_case = make_box(Vector3(0.15, 0.34, 0.075), Vector3(0.0, 0.0, 0.038), iron)
	_case.name = "LockCase"
	var km := _case.material_override as StandardMaterial3D
	if km != null:
		km.metallic = 0.45
		km.roughness = 0.62
	# A maker's plate, because every one of these carried one.
	make_box(Vector3(0.075, 0.028, 0.006), Vector3(0.0, 0.125, 0.079),
			Color(0.50, 0.42, 0.24))

	# THE KEEPER: the slotted plate the latch is supposed to drop into. When it
	# is out of true the slot no longer lines up with the latch's fall.
	_keeper = make_box(Vector3(0.055, 0.10, 0.028),
			Vector3(0.0, -0.105, 0.088), steel)
	_keeper.name = "Keeper"
	var pm := _keeper.material_override as StandardMaterial3D
	if pm != null:
		pm.metallic = 0.66
		pm.roughness = 0.40
	# The mouth of the keeper, so the slot reads as a slot and the depth the
	# latch reaches is legible against something.
	make_box(Vector3(0.022, 0.062, 0.032), Vector3(0.0, -0.105, 0.094),
			Color(0.045, 0.042, 0.040))

	# THE LATCH: it falls into the keeper under its own weight. Full depth is
	# the only thing that makes the locked contact.
	_latch = make_box(Vector3(0.030, 0.135, 0.024),
			Vector3(0.0, -0.010, 0.098), Color(0.52, 0.48, 0.30))
	_latch.name = "Latch"
	var lm := _latch.material_override as StandardMaterial3D
	if lm != null:
		lm.metallic = 0.60
		lm.roughness = 0.44

	# THE ROLLER ARM and its roller. This is what the car's retiring cam pushes
	# to lift the latch, and it is the reason the door can only be opened where
	# the car actually is.
	_roller_arm = make_box(Vector3(0.125, 0.024, 0.024),
			Vector3(-0.072, 0.045, 0.100), Color(0.50, 0.46, 0.29))
	_roller_arm.name = "RollerArm"
	_roller = make_cyl(0.022, 0.022, 0.020,
			Vector3(-0.133, 0.045, 0.100), Color(0.34, 0.30, 0.26), 0.38, 0.55)
	_roller.name = "LockRoller"
	_roller.rotation_degrees.x = 90.0

	# THE RETIRING CAM, riding on the car just clear of the landing. It extends
	# to unlock only where the car is, and retires before the car may run.
	_cam = make_box(Vector3(0.026, 0.24, 0.050),
			Vector3(-0.180, 0.0, 0.086), Color(0.28, 0.27, 0.26))
	_cam.name = "RetiringCam"
	var cm := _cam.material_override as StandardMaterial3D
	if cm != null:
		cm.metallic = 0.55
		cm.roughness = 0.50

	# THE CONTACT BLOCK: two pairs of silver faces on a pale fibre plate, wired
	# in series. Shut on the left, locked on the right, which is the order they
	# make.
	#
	# A CONTACT IS A GAP THAT CLOSES, and that is how these are built. The first
	# proof sheet tried to say "made" with albedo alone and came back
	# unreadable: in a warm 1928 lobby every small metal face is the same brown.
	# A gap is legible at any colour temperature and any exposure, and it is
	# also simply what the hardware does. The pale fibre behind them gives the
	# silver something to be seen against.
	make_box(Vector3(0.150, 0.115, 0.024), Vector3(0.012, 0.150, 0.082),
			Color(0.62, 0.55, 0.41))
	for pair_x in [-0.042, 0.066]:
		# The fixed face, screwed to the fibre. Its moving partner comes down
		# onto it.
		make_box(Vector3(0.048, 0.020, 0.020),
				Vector3(pair_x, 0.118, 0.100), Color(0.66, 0.66, 0.62))
	_shut_face = make_box(Vector3(0.048, 0.020, 0.020),
			Vector3(-0.042, 0.170, 0.100), Color(0.70, 0.70, 0.66))
	_shut_face.name = "ShutContact"
	_shut_mat = _shut_face.material_override as StandardMaterial3D
	_locked_face = make_box(Vector3(0.048, 0.020, 0.020),
			Vector3(0.066, 0.170, 0.100), Color(0.70, 0.70, 0.66))
	_locked_face.name = "LockedContact"
	_locked_mat = _locked_face.material_override as StandardMaterial3D
	for mat in [_shut_mat, _locked_mat]:
		if mat != null:
			mat.metallic = 0.78
			mat.roughness = 0.24

	# THE BRIDGE. One length of copper across both terminals. It is the newest
	# thing on the whole assembly, which is the tell.
	# The bridge lies across BOTH gaps at once, from the outer terminal of the
	# shut pair to the outer terminal of the locked pair. One wire, two lies.
	_jumper = make_box(Vector3(0.145, 0.011, 0.011),
			Vector3(0.012, 0.144, 0.118), Color(0.62, 0.36, 0.15))
	_jumper.name = "BridgingWire"
	var jm := _jumper.material_override as StandardMaterial3D
	if jm != null:
		jm.metallic = 0.72
		jm.roughness = 0.34

	# The depth gauge, hanging on its hook until the first verb sets it against
	# the keeper. Inspection before adjustment.
	_gauge = make_box(Vector3(0.014, 0.088, 0.010),
			Vector3(0.052, -0.105, 0.104), brass)
	_gauge.name = "DepthGauge"

	_knock = make_emitter("knock", -15.0)
	_build_lock_reach()
	_refresh_mechanism()


## The literal service point, over the lock case where a hand would work.
## Built in the visual pass so `FunctionalProp._build_primary_interaction`
## finds an authored area and does not wrap the whole assembly in a coarser
## one -- the arrangement the porter's board and the dumbwaiter both use.
func _build_lock_reach() -> void:
	var lock := ControlArea.new()
	lock.name = "InterlockReach"
	lock.configure("interlock")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.52, 0.44, 0.26)
	shape_node.shape = shape
	shape_node.position = Vector3(-0.06, 0.03, 0.11)
	lock.add_child(shape_node)
	add_child(lock)


# --- binding to the real elevator -------------------------------------------

## Bound by the detail pass to the production `OrisonElevator`. The prop keeps
## a plain `Node` reference and only ever calls two guarded public methods, so
## it can be built, tested and previewed with no elevator at all.
func bind_elevator(elevator: Node, level := "F01") -> void:
	_elevator = elevator
	_level = level
	if _elevator != null and _elevator.has_method("register_landing_interlock"):
		_elevator.call("register_landing_interlock", _level, self)
	_read_door_from_elevator()
	_refresh_mechanism()


## The interlock does not own the door; it reads it. When no elevator is bound
## the local `door_home` stands on its own so the mechanism is still whole.
func _read_door_from_elevator() -> void:
	if _elevator == null or not _elevator.has_method("landing_door_open_fraction"):
		return
	var open_t: float = float(_elevator.call("landing_door_open_fraction", _level))
	if open_t >= 0.0:
		door_home = clampf(1.0 - open_t, 0.0, 1.0)


## Ask the elevator to hold its own door where the service needs it. The
## elevator is free to refuse, and does whenever the car is not idle at this
## landing; the interlock then works only on itself and says so by balking.
func _ask_door(home: float) -> bool:
	var wanted := clampf(home, 0.0, 1.0)
	if _elevator == null or not _elevator.has_method("set_landing_door_for_service"):
		door_home = wanted
		return true
	var granted: bool = bool(_elevator.call("set_landing_door_for_service",
			_level, 1.0 - wanted))
	if granted:
		door_home = wanted
	return granted


# --- the electrical truth ----------------------------------------------------

## Made when the door's leading edge is home. Shut is not locked.
func shut_contact_made() -> bool:
	return door_home >= SHUT_HOME


## How far the latch has actually entered the keeper. An untrue keeper caps it
## no matter how hard the door is shut, which is exactly the failure the code's
## wording is aimed at.
func latch_depth() -> float:
	if door_home < SHUT_HOME:
		return 0.0
	return clampf(keeper_true / KEEPER_TRUE, 0.0, 1.0)


## Made only when the latch is home to full depth.
func locked_contact_made() -> bool:
	return latch_depth() >= LOCKED_DEPTH


## What the safety circuit READS. With the bridge on it reads continuous
## whatever the door and latch are doing -- that is the counterfeit, and it is
## deliberately not the same function as `interlock_holds`.
func circuit_continuous() -> bool:
	if jumper_present:
		return true
	return shut_contact_made() and locked_contact_made()


## What is actually TRUE. A bridge cannot enter this function.
func interlock_holds() -> bool:
	return shut_contact_made() and locked_contact_made()


## The public answer `OrisonElevator` consults. Until the interlock has been
## proved it permits everything, so an unrepaired building behaves exactly as
## it did before this apparatus existed. Only a proved interlock can refuse.
func permits_car_start() -> bool:
	if not interlock_proved:
		return true
	return interlock_holds()


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	if control_id != "interlock":
		return ""
	if jumper_present:
		return "[E]  Examine the landing interlock"
	return "[E]  Check the landing interlock"


func interact_control(control_id: String, player: Node) -> bool:
	if control_id != "interlock":
		return false
	return _begin_interlock_service(player)


func interact(player: Node) -> void:
	_begin_interlock_service(player)


func _begin_interlock_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "elevator_interlock_proof"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {"jumper_present": jumper_present, "keeper_true": keeper_true,
			"door_home": door_home, "gauge_set": gauge_set,
			"interlock_proved": interlock_proved}


## Reversible. Working the visible hardware moves the visible hardware and
## publishes nothing: `interlock_proved` -- the fact the elevator would read --
## is deliberately untouched here and moves only in `apply_maintenance_result`.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"gauge_keeper":
			gauge_set = worked
		"pull_jumper":
			# Taking the bridge off is the one step that needs nothing first.
			jumper_present = worked < 0.5
		"true_keeper":
			# With the bridge on, both contacts read made at every setting, so
			# there is no signal to true the keeper AGAINST. Adjusting now is
			# adjusting to a lie, and the mechanism refuses to pretend
			# otherwise.
			if jumper_present:
				_balk(1.0)
			elif gauge_set < 0.25:
				# Nothing to work to until the depth has been read.
				_balk(0.8)
			else:
				keeper_true = worked
		"bring_home":
			var granted := _ask_door(worked)
			if not granted:
				_balk(1.0)
			elif door_home >= SHUT_HOME and not locked_contact_made():
				# Shut, and still not locked. This is the exact gap the round
				# is about, so it is shown rather than corrected silently.
				_balk(1.2)
		"prove_refusal":
			# The proving test: crack the door and watch the circuit break.
			var opened := _ask_door(worked)
			if not opened:
				_balk(1.0)
			elif jumper_present:
				# The bridge answers for the contacts. Nothing can be proved
				# through it, and a bridged circuit is never a repair.
				_balk(1.4)
			elif worked >= SHUT_HOME:
				# A door still home proves nothing. An interlock is proved by
				# what it refuses.
				_balk(0.9)
	_refresh_mechanism()


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	jumper_present = bool(snapshot.get("jumper_present", jumper_present))
	keeper_true = float(snapshot.get("keeper_true", keeper_true))
	gauge_set = float(snapshot.get("gauge_set", gauge_set))
	interlock_proved = bool(snapshot.get("interlock_proved", interlock_proved))
	_ask_door(float(snapshot.get("door_home", door_home)))
	_balk_left = 0.0
	_refresh_mechanism()


## The only guarded publication. Nothing above this line proves the interlock.
func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if patch.has("jumper_present"):
		jumper_present = bool(patch["jumper_present"])
	if patch.has("keeper_true"):
		keeper_true = clampf(float(patch["keeper_true"]), 0.0, 1.0)
	if patch.has("door_home"):
		_ask_door(float(patch["door_home"]))
	if patch.has("interlock_proved"):
		# An interlock is never "proved" while a bridge is on it, whatever a
		# data file asks for. The mechanism is the last word on its own state.
		interlock_proved = bool(patch["interlock_proved"]) and not jumper_present
	gauge_set = 0.0
	_balk_left = 0.0
	_refresh_mechanism()
	maintenance_completed.emit(result.duplicate(true))


# --- the readable refusal ----------------------------------------------------

## A balk is a knock and a visible shudder in the latch that clears itself. A
## silent false is forbidden by `design/PROP_ACTIVITIES.md`; this is the honest
## refusal that rule asks for.
func _balk(seconds: float) -> void:
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if _knock != null:
		_knock.play()


func balking() -> bool:
	return _balk_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_mechanism()


func _refresh_mechanism() -> void:
	if _latch == null:
		return
	# The latch falls as far as the keeper lets it. It never leaves and never
	# scales away: what changes is how deep it sits and whether the slot is
	# under it.
	var depth := latch_depth()
	_latch.position.y = -0.010 - 0.072 * depth
	# An untrued keeper is offset from the latch's fall, which is why the latch
	# stands shy. The offset is the fault, visibly.
	if _keeper != null:
		_keeper.position.x = 0.030 * (1.0 - clampf(keeper_true / KEEPER_TRUE,
				0.0, 1.0))
	# The retiring cam is extended against the roller only where the car is
	# standing, and the arm rides on it.
	var extended := 1.0 if door_home < SHUT_HOME else 0.0
	if _cam != null:
		_cam.position.x = -0.180 + 0.042 * extended
	if _roller_arm != null:
		_roller_arm.rotation.z = 0.20 * extended
	if _roller != null:
		_roller.position.x = -0.133 + 0.026 * extended
	# THE CONTACTS. Each moving face travels down onto its fixed partner. Made
	# is metal touching metal; open is a gap you can see across the room. The
	# albedo shift is secondary and only confirms what the gap already says.
	if _shut_face != null:
		_shut_face.position.y = 0.140 if shut_contact_made() else 0.170
	if _locked_face != null:
		_locked_face.position.y = 0.140 if locked_contact_made() else 0.170
	if _shut_mat != null:
		_shut_mat.albedo_color = Color(0.82, 0.82, 0.78) \
				if shut_contact_made() else Color(0.44, 0.44, 0.42)
	if _locked_mat != null:
		_locked_mat.albedo_color = Color(0.82, 0.82, 0.78) \
				if locked_contact_made() else Color(0.44, 0.44, 0.42)
	# The bridge, and the gauge.
	if _jumper != null:
		_jumper.visible = jumper_present
	if _gauge != null:
		_gauge.rotation.z = -1.32 * (1.0 - gauge_set)
		_gauge.position.x = 0.052 - 0.030 * gauge_set
	if _balk_left > 0.0:
		var shake := sin(_t * 47.0) * 0.007 * clampf(_balk_left, 0.0, 1.0)
		_latch.position.y += shake
		if _roller_arm != null:
			_roller_arm.rotation.z += shake * 2.2


func service_wire_card() -> Dictionary:
	return {
		"title": "LANDING DOOR INTERLOCK",
		"body": "Two contacts in series: one proves the door shut, one proves "
				+ "the latch home. The code asks for locked, not merely closed.",
	}
