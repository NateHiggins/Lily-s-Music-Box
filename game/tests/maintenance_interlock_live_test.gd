extends Node
## SR7-B — the landing interlock exists in the production Orison, and the
## production lift actually obeys it.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/MaintenanceInterlockLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## The audit that preceded SR7-B found a real, rideable elevator -- eight
## stops, a kinematic car, center-parting landing doors with collision, call
## plates -- and no interlock hardware of any kind. "Interlock" meant only
## that a shut door is a wall. There was no latch, keeper, roller, retiring
## cam or proving contact anywhere in the repository.
##
## So this file has two jobs. First, prove the apparatus now stands at a real
## landing. Second, and more important, prove the SEAM: that the production
## `OrisonElevator` consults it, that an unrepaired building behaves exactly as
## it did before, and that a repaired one genuinely refuses to start with the
## door cracked.

var failures := 0
var checks := 0


func _ready() -> void:
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var lock := root.find_child("F01LandingInterlock", true, false) \
			as ElevatorInterlockProp
	_check(lock != null, "the production F01 landing owns an interlock")
	var lift: OrisonElevator = root.get("elevator") as OrisonElevator
	_check(lift != null, "and the production lift is there to be bound to")
	if lock == null or lift == null:
		_finish()
		return

	# --- it is at the real opening ------------------------------------------
	# The F01 landing opening runs x 1.47..2.38 in the core wall at y -6.75,
	# sill 0 to head 2.10. `b2g` maps Blender (x, y, z) to Godot (x, z, -y).
	var placed := lock.position
	var bx := placed.x
	var by := -placed.z
	var bz := placed.y
	_check(bx >= 1.47 and bx <= 2.38,
			"it stands within the landing opening (b x %.2f)" % bx)
	_check(by <= -6.66 and by >= -6.84,
			"inside the reveal of the core wall (b y %.2f)" % by)
	_check(bz > 0.9 and bz < 1.9,
			"at working height on the jamb (b z %.2f)" % bz)
	_check(lock.get_parent() != null
			and str(lock.get_parent().name).contains("F01"),
			"parented to F01, the lobby the player starts in")
	# The landing doors hang inside the hoistway at y -6.675. The lock must sit
	# on the landing side of them or the doors would swallow it as they travel.
	_check(by < -6.675,
			"on the landing side of the door panels, so travel never hides it")

	# --- every part of the patent is present --------------------------------
	for part in ["LockCase", "Keeper", "Latch", "RollerArm", "LockRoller",
			"RetiringCam", "ShutContact", "LockedContact", "BridgingWire",
			"DepthGauge"]:
		_check(lock.get_node_or_null(NodePath(part)) is MeshInstance3D,
				"the mechanism shows its %s" % part)

	# --- the reach and the authored activity --------------------------------
	_check(lock.get_node_or_null("InterlockReach") is PropControlArea
			and lock.control_prompt("interlock").contains("interlock"),
			"the interlock is a literal ray-reachable service point")
	_check(lock.interact_control("interlock", null)
			and lock._service_panel != null
			and lock._service_panel._director != null
			and lock._service_panel._director.active_run != null,
			"that reach opens the shared activity system")
	var run: MaintenanceActivityRun = lock._service_panel._director.active_run
	_check(str(run.activity_id) == "elevator_interlock_proof"
			and str(run.profile.get("historical_source", "")).contains("1,493,069"),
			"and the activity it opens is the authored interlock, by name")

	# --- THE SEAM, before repair --------------------------------------------
	# This is the regression guarantee: an unproved interlock permits
	# everything, so the lift behaves exactly as it did before SR7-B.
	_check(lock.jumper_present and not lock.interlock_proved,
			"the landing is found bridged and unproved")
	_check(lift.landing_permits_start("F01"),
			"an unproved interlock permits the car, so nothing regresses")
	_check(lift.landing_permits_start("F04"),
			"and an unserved landing permits it too")
	var open_t: float = lift.landing_door_open_fraction("F01")
	_check(open_t >= 0.0 and lift.landing_door_open_fraction("NOWHERE") < 0.0,
			"the lift reports its own door and denies landings it lacks")
	_check(lift.current == "F01" and not lift.moving,
			"the car is home and idle at F01, which is why service is allowed")

	# --- work the whole chain on the production mechanism --------------------
	var seen: Array[Dictionary] = []
	lock.maintenance_completed.connect(
			func(r: Dictionary) -> void: seen.append(r))
	var steps: Array = run.profile.get("steps", [])
	var moved := true
	for step in steps:
		var record := step as Dictionary
		lock.preview_maintenance_step(record, float(record.target))
		if str(record.id) == "bring_home":
			# The lift granted the request, so the real production door moved.
			_check(lift.landing_door_open_fraction("F01") <= 0.08,
					"the production landing door came home under service")
			_check(lock.shut_contact_made() and lock.locked_contact_made(),
					"shut contact, then locked contact, in that order")
		if str(record.id) == "prove_refusal":
			_check(lift.landing_door_open_fraction("F01") > 0.5,
					"the production door was cracked for the proving test")
			_check(not lock.circuit_continuous(),
					"and the honest circuit broke when it was")
		if str(record.verb) == "hold_release":
			moved = moved and lock._service_panel._director.submit(
					"hold_release", float(record.target),
					float(record.hold_min_seconds) + 0.4)
		else:
			moved = moved and lock._service_panel._director.submit(
					str(record.verb), float(record.target))
	_check(moved, "every authored verb lands on the production mechanism")
	_check(seen.size() == 1 and lock.interlock_proved and not lock.jumper_present,
			"the final commit alone proves the interlock and reports once")

	# --- THE SEAM, after repair: the earned refusal -------------------------
	# Bring the door home through the lift's own guarded setter, exactly as the
	# prop does. A proved, locked landing must permit the car.
	lock._ask_door(1.0)
	_check(lift.landing_permits_start("F01") and lock.interlock_holds(),
			"a proved and locked landing permits the car")

	# Now crack it and ask the production car to leave. This is the whole
	# point of the apparatus, and it is asserted against the real lift rather
	# than against the prop's own opinion of itself.
	lock._ask_door(0.22)
	_check(not lift.landing_permits_start("F01"),
			"cracking the door withdraws permission")
	_check(not lift.moving, "the car is standing still before the call")
	lift.travel_to("F05")
	_check(not lift.moving and lift.current == "F01",
			"and the production car REFUSES to leave a landing that is not locked")

	# Close it again and the same call is accepted, so the refusal is the
	# interlock talking and not a car that has simply stopped working.
	lock._ask_door(1.0)
	lift.travel_to("F05")
	_check(lift.moving,
			"with the door locked again the very same call is accepted")

	# --- ownership ----------------------------------------------------------
	var patch: Dictionary = seen[0].get("mechanism_patch", {}) if seen.size() == 1 \
			else {}
	var leaked: Array[String] = []
	for key in patch.keys():
		if str(key) not in ["jumper_present", "keeper_true", "door_home",
				"interlock_proved"]:
			leaked.append(str(key))
	_check(leaked.is_empty(),
			"the result patches the interlock and nothing else (%s)"
			% ", ".join(leaked))
	_check(not seen[0].has("job_id") and not seen[0].has("case_id"),
			"it closes no job and advances no case")
	_check(lock.find_children("*", "Light3D", true, false).is_empty(),
			"and the apparatus owns no light of its own")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [live interlock ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE INTERLOCK FAIL] ", label)


func _finish() -> void:
	print("MAINTENANCE INTERLOCK LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
