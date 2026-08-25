extends Node
## SR7-C — the ball cock stands on the real roof tank, and touches nothing else.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/MaintenanceBallcockLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## The audit that preceded SR7-C found a real timber water tank on the roof --
## `art/data/gen_layout.py` bakes it at building (-9.45, 4.95), 2.80 x 2.20 x
## 2.30, on four cast-iron legs -- and NOTHING else. No inlet, no float, no
## valve, no overflow, no marker, no owner; the generator's own note records
## that an earlier `watertank` marker was deleted because it "owned nothing".
## There is no water system anywhere in the Orison to join.
##
## So this file proves three things. That the apparatus now stands on the real
## tank, in the real roof the player can walk out onto. That its overflow
## discharges over the roof water butt the generator already claims stands
## under one. And -- the part that matters most for a building with exactly one
## real water owner -- that servicing it does not touch the boiler.

var failures := 0
var checks := 0

## The production tank, from `art/data/gen_layout.py`, in building coordinates.
const TANK := [-9.45, 4.95, -6.65, 7.15]
const TANK_BASE_LOCAL := 1.6
const ROOF_Z := 19.2
## The roof water butt the overflow is routed over.
const BUTT := [-10.2, 4.1, -9.4, 4.9]


func _ready() -> void:
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var cock := root.find_child("ROOF_TANK_BALLCOCK", true, false) \
			as RoofTankBallcockProp
	_check(cock != null, "the production roof tank owns a ball cock")
	if cock == null:
		_finish()
		return

	# --- it stands on the real tank -----------------------------------------
	var at := cock.global_position
	var bx := at.x
	var by := -at.z
	var bz := at.y
	print("[BALLCOCK LIVE] global b(%.2f, %.2f, %.2f)" % [bx, by, bz])
	_check(bx >= TANK[0] - 0.20 and bx <= TANK[2] + 0.20,
			"it is within the tank's plan width (b x %.2f)" % bx)
	_check(by <= TANK[1] + 0.10 and by >= TANK[1] - 0.40,
			"hung on the tank's south face (b y %.2f, face %.2f)"
					% [by, TANK[1]])
	# The roof deck is at 19.2 and the tank's underside at 20.8. The apparatus
	# has to be reachable from the deck, which means BELOW eye height, while
	# still being on the tank -- so it hangs under the tank's south-west corner.
	_check(bz > ROOF_Z + 0.9 and bz < ROOF_Z + 1.9,
			"at a standing hand's height above the roof deck (b z %.2f)" % bz)
	_check(cock.get_parent() != null
			and str(cock.get_parent().name) == "ROOF",
			"parented to the ROOF floor node")
	_check(str(cock.name).begins_with("ROOF_"),
			"named to the roof id convention the presentation audit enforces")

	# The float has to ride inside the tank's own height, not above its lid.
	var float_node := cock.get_node_or_null("Float") as MeshInstance3D
	_check(float_node != null
			and float_node.global_position.y < ROOF_Z + TANK_BASE_LOCAL + 2.30
			and float_node.global_position.y > ROOF_Z + TANK_BASE_LOCAL,
			"the float rides within the real tank's own height (%.2f)"
					% (float_node.global_position.y if float_node else -1.0))

	# --- the overflow lands where production already says it does -----------
	var witness := cock.get_node_or_null("OverflowWitness") as MeshInstance3D
	_check(witness != null, "the apparatus has an overflow witness")
	if witness != null:
		var wx := witness.global_position.x
		var wy := -witness.global_position.z
		print("[BALLCOCK LIVE] witness b(%.2f, %.2f)" % [wx, wy])
		_check(wx >= BUTT[0] - 0.35 and wx <= BUTT[2] + 0.35
				and wy >= BUTT[1] - 0.35 and wy <= BUTT[3] + 0.35,
				"and it discharges over the roof water butt (b %.2f, %.2f)"
						% [wx, wy])

	# --- the reach and the authored activity --------------------------------
	_check(cock.get_node_or_null("BallcockReach") is PropControlArea
			and cock.control_prompt("ballcock").contains("overflow"),
			"the cock is a ray-reachable service point announcing its fault")
	_check(cock.interact_control("ballcock", null)
			and cock._service_panel != null
			and cock._service_panel._director != null
			and cock._service_panel._director.active_run != null,
			"that reach opens the shared activity system")
	var run: MaintenanceActivityRun = cock._service_panel._director.active_run
	_check(str(run.activity_id) == "roof_tank_ballcock_service"
			and str(run.profile.get("historical_source", "")).contains("951,172"),
			"and the activity it opens is the authored ball cock, by name")

	# --- THE OWNERSHIP BOUNDARY ---------------------------------------------
	# The Orison has exactly one real water owner -- the basement boiler's
	# feedwater -- and it is a steam plant, not a gravity tank. Servicing the
	# roof must not move it by so much as a millimetre.
	var boiler: BoilerProp = root.find_child("B1_BOILER_01", true, false) \
			as BoilerProp
	_check(boiler != null, "the production boiler is present to be left alone")
	var boiler_before := boiler.maintenance_snapshot() if boiler else {}
	var boiler_events: Array = []
	if boiler != null and boiler.has_signal("boiler_state_changed"):
		boiler.boiler_state_changed.connect(
				func(state: Dictionary) -> void: boiler_events.append(state))

	# --- work the whole chain on the production apparatus -------------------
	var seen: Array[Dictionary] = []
	cock.maintenance_completed.connect(
			func(r: Dictionary) -> void: seen.append(r))
	_check(cock.overflow_running(),
			"the tank is found overflowing on the production roof")
	var steps: Array = run.profile.get("steps", [])
	var moved := true
	for step in steps:
		var record := step as Dictionary
		cock.preview_maintenance_step(record, float(record.target))
		if str(record.id) == "read_the_float":
			_check(cock.overflow_running()
					and is_equal_approx(cock.float_ride(), 0.86),
					"the float reads full while the overflow is still running")
		if str(record.id) == "lift_the_float":
			_check(not cock.float_waterlogged,
					"held clear of a dead inlet, the float empties itself")
		if str(record.verb) == "hold_release":
			moved = moved and cock._service_panel._director.submit(
					"hold_release", float(record.target),
					float(record.hold_min_seconds) + 0.4)
		else:
			moved = moved and cock._service_panel._director.submit(
					str(record.verb), float(record.target))
	_check(moved, "every authored verb lands on the production apparatus")
	_check(seen.size() == 1 and cock.ballcock_serviced and cock.valve_holds(),
			"the final commit alone services the cock and reports once")
	_check(not cock.overflow_running(),
			"and the production overflow has stopped running")
	var stream := cock.get_node_or_null("OverflowStream") as MeshInstance3D
	_check(stream != null and not stream.visible,
			"the running water is gone from the witness")

	# --- nothing else moved -------------------------------------------------
	if boiler != null:
		var boiler_after := boiler.maintenance_snapshot()
		_check(boiler_after == boiler_before,
				"the boiler's water is untouched (%s)" % str(boiler_after))
		_check(boiler_events.is_empty(),
				"and it published no state while the roof was serviced")
	var patch: Dictionary = seen[0].get("mechanism_patch", {}) if seen.size() == 1 \
			else {}
	var leaked: Array[String] = []
	for key in patch.keys():
		if str(key) not in ["float_waterlogged", "weight_set", "riser_open",
				"overflow_running", "ballcock_serviced"]:
			leaked.append(str(key))
	_check(leaked.is_empty(),
			"the result patches the apparatus and nothing else (%s)"
					% ", ".join(leaked))
	_check(not seen[0].has("job_id") and not seen[0].has("case_id"),
			"it closes no job and advances no case")
	_check(cock.find_children("*", "Light3D", true, false).is_empty(),
			"the apparatus owns no light of its own")
	_check(cock.find_children("*", "CollisionObject3D", true, false).size() == 1,
			"and exactly one collision body, its own reach")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [live ballcock ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE BALLCOCK FAIL] ", label)


func _finish() -> void:
	print("MAINTENANCE BALLCOCK LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
