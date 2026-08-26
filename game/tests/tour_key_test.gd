extends Node
## SR7-L focused proof: the key is not the man, and the key is not a permit.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/TourKeyTest.tscn `
##         -ProjectPath <checkout>/game
##
## Three things this file exists to make true:
##   * possession proves the hook is empty and NOTHING else;
##   * the key gates one optional thing — the station's crank — and no door;
##   * a key nobody took, or nobody brought back, blocks no work at all.

const GuardScript := preload("res://scripts/props/tour_key_guard_prop.gd")
const StationScript := preload("res://scripts/props/watch_station_prop.gd")
const NetworkScript := preload("res://scripts/building/watch_station_network.gd")
const RegisterScript := preload("res://scripts/props/watch_register_prop.gd")

var failures := 0
var checks := 0

var guard: TourKeyGuardProp
var station: WatchStationProp
var network: WatchStationNetwork
var board: WatchRegisterProp
var taken: Array[int] = []
var returned := 0
var facts: Array[Dictionary] = []


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()

	_the_guard()
	_custody()
	_the_gate()
	_the_round()
	_opens_no_door()
	_blocks_nothing()
	_abort()
	_ownership()

	print("TOUR KEY TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


## A whole line: guard, station, wire, board.
func _wire_up() -> void:
	for old in [guard, station, network, board]:
		if old != null:
			old.queue_free()
	network = NetworkScript.new() as WatchStationNetwork
	add_child(network)
	guard = GuardScript.new() as TourKeyGuardProp
	guard.prop_type = "tour_key_guard"
	add_child(guard)
	board = RegisterScript.new() as WatchRegisterProp
	board.prop_type = "signal_register"
	add_child(board)
	station = StationScript.new() as WatchStationProp
	station.prop_type = "watch_station"
	station.station_id = "F02_STATION_2A_LANDING"
	add_child(station)
	network.attach_key_guard(guard)
	network.attach_receiver(board)
	network.register(station)
	taken.clear()
	returned = 0
	facts.clear()
	guard.tour_key_taken.connect(func(n: int) -> void: taken.append(n))
	guard.tour_key_returned.connect(func() -> void: returned += 1)
	network.station_marked.connect(
			func(_i: String, r: Dictionary) -> void: facts.append(r))


# --- the guard ---------------------------------------------------------------

func _the_guard() -> void:
	_wire_up()
	_check("the tour key hangs on its own guard, on its own hook",
			guard.key_on_hook and not guard.key_carried()
			and guard.hook_reads() == TourKeyGuardProp.KEY_LEGEND)
	# A DIFFERENT CHECK NUMBER FROM THE NIGHT REGISTER'S TWO. One building,
	# one check series, three hooks -- and this hook is not on that board.
	_check("its check number is distinct from the apartment and plant keys",
			TourKeyGuardProp.CHECK_NUMBER == 3
			and TourKeyGuardProp.CHECK_NUMBER
					!= NightRegisterProp.CHECK_NUMBERS[
							NightRegisterProp.APARTMENT_HOOK]
			and TourKeyGuardProp.CHECK_NUMBER
					!= NightRegisterProp.CHECK_NUMBERS[
							NightRegisterProp.PLANT_HOOK])
	_check("and it is a different apparatus, not a third hook on that board",
			not guard.has_method("sign_register")
			and not guard.has_method("take_slip")
			and not guard.has_method("take_key_hook"))
	for part in ["GuardPlate", "GuardHook", "GuardLatch", "TourKey",
			"TourCheck", "KeyBarrel", "KeyWard"]:
		_check("the guard shows its %s" % part,
				guard.find_child(part, true, false) != null)


func _custody() -> void:
	_wire_up()
	var key := guard.find_child("TourKey", true, false) as Node3D
	var check := guard.find_child("TourCheck", true, false) as Node3D
	var latch := guard.find_child("GuardLatch", true, false) as Node3D
	_check("as found: the key is on the hook and the check is not",
			key.visible and not check.visible)
	var latched: float = latch.rotation.z

	# TAKING IT REPLACES IT WITH A NUMBERED CHECK.
	_check("taking the key hangs the check in its place",
			guard.take_key() and guard.key_carried()
			and not key.visible and check.visible
			and guard.hook_reads() == "check 3")
	_check("and it says which check, once",
			taken == [TourKeyGuardProp.CHECK_NUMBER] and returned == 0)
	_check("the latch stands open on an emptied hook (%.2f -> %.2f)"
					% [latched, latch.rotation.z],
			absf(latch.rotation.z - latched) > 0.5)
	# REPEAT TAKE.
	_check("REFUSAL: a hook carrying its check has no second key to give",
			not guard.take_key() and guard.balking()
			and guard.key_carried() and taken.size() == 1)
	guard.restore_maintenance_snapshot(guard.maintenance_snapshot())

	# RETURNING IT RESTORES THE HOOK.
	_check("hanging it back restores the hook",
			guard.return_key() and guard.key_on_hook
			and key.visible and not check.visible
			and returned == 1)
	_check("and the latch lies across it again",
			absf(latch.rotation.z - latched) < 0.0001)
	# COPIED KEY.
	_check("REFUSAL: a loaded hook will not take a second, copied key",
			not guard.return_key() and guard.balking()
			and guard.key_on_hook and returned == 1)
	# POSSESSION PROVES ONLY ABSENCE. The check carries a number, never a name.
	guard.restore_maintenance_snapshot(guard.maintenance_snapshot())
	guard.take_key()
	_check("what the hook reads is a NUMBER, and there is nowhere for a name",
			guard.hook_reads() == "check 3"
			and not guard.hook_reads().contains("watchman")
			and guard.maintenance_snapshot().keys() == ["key_on_hook"])


# --- the gate ----------------------------------------------------------------

func _the_gate() -> void:
	_wire_up()
	_check("with the key on its hook, the station reports no key at the box",
			not guard.key_carried() and not network.tour_key_carried()
			and not station.tour_key_available())
	station.open_door()
	# THE REFUSAL SR7-J COULD NOT MAKE. Its socket was empty and the box
	# worked anyway; that was the one thing about it that was not period-true.
	var socket := station.find_child("TourKeySocket", true, false) as Node3D
	var crank := station.find_child("StationCrank", true, false) as Node3D
	var seated: float = socket.position.z
	station.set_process(false)
	_check("REFUSAL: the crank will not run the wheel with an empty socket",
			not station.turn_crank() and station.balking()
			and not station.marked() and station.marks == 0)
	_check("and the refusal SHOWS the socket, not the pawl (%.3f -> %.3f)"
					% [seated, socket.position.z],
			socket.position.z > seated + 0.005
			and crank.rotation.z > 0.4)
	_check("nothing was made, carried or shown",
			facts.is_empty() and network.mark_count() == 0
			and network.delivered_count() == 0
			and board.indication_count() == 0)
	station.restore_maintenance_snapshot(station.maintenance_snapshot())
	station.set_process(true)

	# A LINE WITH NO GUARD AT ALL answers honestly rather than permissively.
	var lone := NetworkScript.new() as WatchStationNetwork
	add_child(lone)
	_check("a network with no guard says the key is not carried",
			not lone.has_key_guard() and not lone.tour_key_carried())
	_check("and one guard per line: a second is refused",
			lone.attach_key_guard(guard) and not lone.attach_key_guard(guard))
	lone.queue_free()


# --- the round ---------------------------------------------------------------

func _the_round() -> void:
	_wire_up()
	guard.take_key()
	_check("with the key carried, the box knows it",
			network.tour_key_carried() and station.tour_key_available())
	station.open_door()
	_check("ONE crank makes ONE drop, ONE fact and ONE indication",
			station.turn_crank() and station.marked() and station.marks == 1
			and facts.size() == 1 and network.mark_count() == 1
			and network.delivered_count() == 1
			and board.indication_count() == 1)
	_check("and the board and the box agree on the number",
			board.shows(station.station_number())
			and int(board.last_indication().station_number)
					== station.station_number())
	# REPEAT CRANK, with the key still in hand: the pawl, not the socket.
	for i in 3:
		station.turn_crank()
	_check("REPEAT: three more cranks add no drop, no fact, no indication",
			station.marks == 1 and facts.size() == 1
			and network.delivered_count() == 1
			and board.signals_taken == 1)
	# AND THE KEY GOES BACK, which changes nothing that already happened.
	_check("returning the key restores the hook and retracts nothing",
			guard.return_key() and guard.key_on_hook
			and station.marked() and network.mark_count() == 1
			and board.indication_count() == 1)
	_check("and the box now refuses again, because the socket is empty again",
			not station.tour_key_available())


# --- it opens no door --------------------------------------------------------

func _opens_no_door() -> void:
	# THE STRONGEST FORM OF THIS IS ABSENCE. The guard cannot write a lock
	# because it contains no way to name one.
	var raw := FileAccess.get_file_as_string(
			"res://scripts/props/tour_key_guard_prop.gd")
	var code := ""
	for line in raw.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	for forbidden in ["leaf_state", "DoorProp", "unlock", "locked",
			"START_LOCKED", "_unit_doors"]:
		_check("the tour key cannot reach `%s`" % forbidden,
				not code.contains(forbidden))
	_check("it names no door, no unit and no room",
			not code.contains("F02_DOOR") and not code.contains("WSTOR")
			and not code.contains("apartment") and not code.contains("plant"))
	_check("and the ONE thing it is asked about is whether it is carried",
			guard.has_method("key_carried") and guard.has_method("take_key")
			and guard.has_method("return_key")
			and not guard.has_method("opens")
			and not guard.has_method("unlock_door"))


# --- and it blocks nothing ---------------------------------------------------

func _blocks_nothing() -> void:
	_wire_up()
	# THE CORE RULE. A watchman with no key never touches the guard, never
	# works the box, and is in no way impeded: the station mark was optional
	# in SR7-J and the key does not make it less so.
	_check("a key never taken leaves the guard loaded and quiet",
			guard.key_on_hook and not guard.balking()
			and network.mark_count() == 0)
	_check("the station is still reachable, still prompts, still opens",
			station.control_prompt("station") != "" and station.open_door()
			and station.door_open)
	_check("it simply cannot be MARKED, and says so rather than going silent",
			not station.turn_crank() and station.balking())
	station.restore_maintenance_snapshot(station.maintenance_snapshot())
	_check("nothing about the guard or the box declares itself required",
			not guard.has_method("required") and not guard.has_method("gate")
			and not station.has_method("required")
			and not station.has_method("blocks_route"))
	# AN UNRETURNED KEY IS EQUALLY INERT.
	guard.take_key()
	_check("a key taken and never brought back blocks nothing either",
			guard.key_carried() and not guard.balking()
			and station.control_prompt("station") != "")


# --- abort -------------------------------------------------------------------

func _abort() -> void:
	_wire_up()
	var found: Dictionary = guard.maintenance_snapshot()
	guard.take_key()
	station.open_door()
	station.turn_crank()
	guard.take_key()   # refused; leaves a pose standing
	_check("a session took the key, marked the station and holds a refusal",
			guard.key_carried() and station.marked() and guard.balking()
			and network.mark_count() == 1)
	guard.restore_maintenance_snapshot(found)
	_check("ABORT hangs the key back and clears the pose",
			guard.key_on_hook and not guard.balking())
	var after: Dictionary = guard.maintenance_snapshot()
	var drift: Array[String] = []
	for key in found.keys():
		if str(after.get(key)) != str(found.get(key)):
			drift.append(str(key))
	_check("and every fact the guard had is restored (%s)"
					% ", ".join(drift),
			drift.is_empty() and after.size() == found.size())
	var key_mesh := guard.find_child("TourKey", true, false) as Node3D
	_check("the brass itself is back on the hook, not just the boolean",
			key_mesh.visible and absf(key_mesh.rotation.z) < 0.0001)
	# THE LINE ABORT DOES NOT CROSS, a third time.
	_check("ABORT CANNOT RETRACT the mark the round already made",
			network.mark_count() == 1 and network.delivered_count() == 1
			and facts.size() == 1 and station.marked()
			and board.indication_count() == 1)


# --- what none of it owns ----------------------------------------------------

func _ownership() -> void:
	var raw := FileAccess.get_file_as_string(
			"res://scripts/props/tour_key_guard_prop.gd")
	var code := ""
	for line in raw.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	for forbidden in ["WorkOrders", "RealityCases", "RealityState",
			"MaintenanceInventory", "ObjectiveTracker", "ScheduleDirector",
			"AcousticGraphData", "FirstShiftDirector", "CoreLoopDirector",
			"dream", "activate_case", "issue_job"]:
		_check("the guard cannot reach `%s`" % forbidden,
				not code.contains(forbidden))
	# NOT MaintenanceInventory, and the reason is in that file's own contract:
	# single use per campaign, a second grant refused, and it commits to the
	# save. A key taken and hung back nightly is none of those.
	var inv := FileAccess.get_file_as_string(
			"res://scripts/game/maintenance_inventory.gd")
	_check("and that owner rules itself out in its own words",
			inv.contains("granted at most once per campaign")
			and inv.contains("RealityState.commit()"))
	# TRANSIENT BY DESIGN.
	var save_before := JSON.stringify(RealityState.data)
	_wire_up()
	guard.take_key()
	station.open_door()
	station.turn_crank()
	guard.return_key()
	_check("a whole keyed round writes NOTHING to the save",
			JSON.stringify(RealityState.data) == save_before)
	_check("the guard owns no light, and one Area reach that stops nothing",
			guard.find_children("*", "Light3D", true, false).is_empty()
			and guard.find_children("*", "CollisionObject3D", true,
					false).size() == 1
			and guard.find_children("*", "CollisionObject3D", true,
					false)[0] is Area3D)
	# The receiver still shows only number and sequence.
	var extra: Array[String] = []
	for key in board.last_indication().keys():
		if str(key) not in WatchRegisterProp.INDICATION_FIELDS:
			extra.append(str(key))
	_check("and the receiver still displays number and order only (%s)"
					% ", ".join(extra),
			extra.is_empty()
			and not board.last_indication().has("check")
			and not board.last_indication().has("carried_by"))


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [tour key ok] ", label)
	else:
		failures += 1
		printerr("  [TOUR KEY FAIL] ", label)
