extends Node
## SR7-G focused proof: the night register presents work, it does not own it.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/NightRegisterTest.tscn `
##         -ProjectPath <checkout>/game
##
## The board is built against a stand-in building so every fact here is about
## the APPARATUS. The production spine, the real doors and the real lobby are
## proved separately in `NightRegisterLiveTest`.
##
## The four things this file exists to make impossible:
##   * a second work ledger,
##   * a second case owner,
##   * a key that changes a lock,
##   * a route order.

const RegisterScript := preload("res://scripts/props/night_register_prop.gd")

var failures := 0
var checks := 0

var work_orders: WorkOrders
var building: StandInBuilding
var board: NightRegisterProp


## The smallest thing the prop's `_bind_owners()` walk will accept: a node
## carrying a `work_orders` property, with doors under it that answer
## `leaf_state`. Nothing else about a building is needed to prove the board.
class StandInBuilding extends Node3D:
	var work_orders: WorkOrders


class StandInDoor extends Node:
	var leaf_state := "closed"


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_build()

	_presentation()
	_refusals()
	_route_order()
	_abort()
	_access_ownership()
	_signing()
	_ownership()

	print("NIGHT REGISTER TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


func _build() -> void:
	work_orders = WorkOrders.new()
	work_orders.setup(null)
	work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(work_orders)
	building = StandInBuilding.new()
	building.work_orders = work_orders
	add_child(building)
	# The five service closets locked, 2B's entry not: the shape production
	# actually ships, asserted against the real building in the live test.
	for door_id in ["F02_DOOR_04", "F03_DOOR_04", "F04_DOOR_04",
			"F05_DOOR_04", "F06_DOOR_04"]:
		var locked := StandInDoor.new()
		locked.name = door_id
		locked.leaf_state = "locked"
		building.add_child(locked)
	var entry := StandInDoor.new()
	entry.name = "F02_DOOR_03"
	entry.leaf_state = "closed"
	building.add_child(entry)
	board = RegisterScript.new() as NightRegisterProp
	board.prop_type = "night_register"
	building.add_child(board)


func _fresh_board() -> void:
	board.queue_free()
	board = RegisterScript.new() as NightRegisterProp
	board.prop_type = "night_register"
	building.add_child(board)


# --- the board presents what the spine holds ---------------------------------

func _presentation() -> void:
	_check("the book validates: the board carries the authored 2B job id",
			NightRegisterProp.JOB_ID == "lena_radiator_round_2b"
			and not work_orders.job_library.job(
					NightRegisterProp.JOB_ID).is_empty())
	_check("with no job issued the spindle is empty",
			work_orders.job_stage(NightRegisterProp.JOB_ID) == "missing"
			and not board.slip_available()
			and board.job_stage() == "missing")
	# THE CENTRAL NEGATIVE. A board that manufactured its own report would be
	# a second ledger; this one simply has nothing to hold.
	_check("touching an empty spindle issues NOTHING",
			not board.take_slip()
			and work_orders.job_stage(NightRegisterProp.JOB_ID) == "missing"
			and RealityState.data.get("maintenance_jobs", {}).is_empty())
	_check("and it says so rather than failing silently", board.balking())

	# The one issuing owner does its job. `ServiceRoundDirector` makes exactly
	# this call from `answer_incoming_call`.
	work_orders.issue_job(NightRegisterProp.JOB_ID, "reported")
	_check("once the spine issues the job, a slip appears on the spindle",
			board.slip_available() and board.job_stage() == "issued")
	_check("and the slip reads the library, holding no copy of its own",
			board.slip_text().contains("BORROWED BREATH")
			and board.slip_text().contains("Go to 2B"))

	var jobs_before: int = RealityState.data.get("maintenance_jobs", {}).size()
	_check("taking the report acknowledges the EXISTING job",
			board.take_slip()
			and work_orders.job_stage(NightRegisterProp.JOB_ID)
					== "acknowledged")
	_check("and creates no second job record (%d before, %d after)"
					% [jobs_before,
							RealityState.data.get("maintenance_jobs", {}).size()],
			RealityState.data.get("maintenance_jobs", {}).size() == jobs_before)
	var stub := board.find_child("ReportStub", true, false) as MeshInstance3D
	var slip := board.find_child("ReportSlip", true, false) as MeshInstance3D
	# THREE CONDITIONS, THREE PICTURES. Nothing reported, report in hand, and
	# report filed have to be distinguishable on the board itself -- otherwise
	# the first and second are the same photograph, which is where this sheet
	# started.
	_check("the slip is off the spindle and its torn stub is left on the spike",
			board.slip_taken and not board.slip_available()
			and stub.visible and not slip.visible)
	board.replace_slip()
	_check("filed again: the slip is back and the stub is gone",
			slip.visible and not stub.visible)
	board.take_slip()
	# Acknowledging twice is the classic duplicate-ledger bug. WorkOrders
	# rejects the illegal transition without mutating, and so the board is
	# safe to touch repeatedly.
	board.replace_slip()
	board.take_slip()
	_check("taking it again cannot re-acknowledge or double-advance",
			work_orders.job_stage(NightRegisterProp.JOB_ID) == "acknowledged")
	board.replace_slip()


func _refusals() -> void:
	_fresh_board()
	work_orders.issue_job(NightRegisterProp.JOB_ID, "reported")

	# REFUSAL 1: a hook carrying its check has no key on it.
	board.take_key(NightRegisterProp.PLANT_HOOK)
	_check("REFUSAL: a key already signed out cannot be taken twice",
			not board.take_key(NightRegisterProp.PLANT_HOOK)
			and board.balking()
			and board.key_out(NightRegisterProp.PLANT_HOOK))

	# REFUSAL 2: a board that accepts a second copy accounts for nothing.
	board.return_key(NightRegisterProp.PLANT_HOOK)
	_check("REFUSAL: a key already on its hook will not take a second copy",
			not board.return_key(NightRegisterProp.PLANT_HOOK)
			and board.balking()
			and not board.key_out(NightRegisterProp.PLANT_HOOK))

	# REFUSAL 3: the only thing a register can honestly enforce.
	board.take_slip()
	board.take_key(NightRegisterProp.APARTMENT_HOOK)
	_check("REFUSAL: the report will not go back while a key is still out",
			not board.replace_slip()
			and board.balking()
			and board.slip_taken)
	board.return_key(NightRegisterProp.APARTMENT_HOOK)
	_check("and it goes back the moment the key does",
			board.replace_slip() and not board.slip_taken)

	# REFUSAL 4: nothing on the spindle.
	_check("REFUSAL: a spindle that already holds its slip gives you nothing",
			not board.replace_slip() and board.balking())

	# REFUSAL 5: an unmarked register.
	_check("REFUSAL: a register with nothing to record will not be signed",
			not board.has_unsigned_work()
			and not board.sign_register()
			and board.balking()
			and board.signed_lines == 0)

	# THE ASSERTIONS THAT CATCH A REFUSAL NOBODY CAN SEE. Two separate
	# defects, both of which the SR7-G sheet actually hit before this existed:
	#
	#   1. `balking()` true while nothing moved, because the pose was left to
	#      `_process` -- and a proof sheet freezes `_process` to hold the
	#      world still, so the refusal photographed as nothing at all.
	#   2. every refusal wearing the SAME pose, so two different refusals in
	#      one board condition came back byte-identical.
	#
	# `_process` is off here on purpose: that is the state a camera sees, and
	# `restore_maintenance_snapshot` over the CURRENT snapshot is the only way
	# to clear a held balk without it.
	var desk := board.find_child("RegisterDesk", true, false) as Node3D
	var plant_check := board.find_child("Check_plant", true, false) 			as MeshInstance3D
	_check("the apparatus has a desk and a check a refusal can visibly move",
			desk != null and plant_check != null)
	board.set_process(false)
	board.take_key(NightRegisterProp.PLANT_HOOK)
	board.restore_maintenance_snapshot(board.maintenance_snapshot())
	var desk_rest: float = desk.rotation.x
	var check_rest: float = plant_check.position.y

	board.take_key(NightRegisterProp.PLANT_HOOK)
	var check_refused: float = plant_check.position.y
	_check("a hook refusal lifts THAT HOOK without waiting for a tick "
					+ "(rest %.3f, refused %.3f)" % [check_rest, check_refused],
			board.balking() and absf(check_refused - check_rest) > 0.02)
	_check("and it leaves the desk exactly where it was",
			absf(desk.rotation.x - desk_rest) < 0.0001)

	board.restore_maintenance_snapshot(board.maintenance_snapshot())
	_check("the pose returns to rest when the refusal is cleared",
			not board.balking()
			and absf(plant_check.position.y - check_rest) < 0.0001
			and absf(desk.rotation.x - desk_rest) < 0.0001)

	board.return_key(NightRegisterProp.PLANT_HOOK)
	board.restore_maintenance_snapshot(board.maintenance_snapshot())
	_check("with the key back there is nothing left to sign for",
			not board.has_unsigned_work())
	board.sign_register()
	var desk_refused: float = desk.rotation.x
	_check("a book refusal moves THE DESK instead (rest %.3f, refused %.3f)"
					% [desk_rest, desk_refused],
			board.balking() and absf(desk_refused - desk_rest) > 0.15)
	_check("THE THING THAT REFUSES IS THE THING THAT MOVES: two refusals in "
					+ "one condition are two different pictures",
			absf(desk_refused - desk_rest) > 0.15
			and absf(plant_check.position.y - check_rest) < 0.0001)
	_check("and a refused signature still wrote nothing",
			board.signed_lines == 0
			and not RealityState.data.has(NightRegisterProp.STATE_KEY))
	board.restore_maintenance_snapshot(board.maintenance_snapshot())
	board.set_process(true)


# --- route order is a mechanical property ------------------------------------

func _route_order() -> void:
	# Six orders over three independent objects. If any gate existed between
	# them, one of these would end somewhere different.
	var orders := [
		["slip", "apartment", "plant"],
		["slip", "plant", "apartment"],
		["apartment", "slip", "plant"],
		["apartment", "plant", "slip"],
		["plant", "slip", "apartment"],
		["plant", "apartment", "slip"],
	]
	var reached: Array[String] = []
	for order in orders:
		_fresh_board()
		work_orders.issue_job(NightRegisterProp.JOB_ID, "reported")
		var all_ok := true
		for step in order:
			match str(step):
				"slip":
					all_ok = all_ok and board.take_slip()
				"apartment":
					all_ok = all_ok and board.take_key(
							NightRegisterProp.APARTMENT_HOOK)
				"plant":
					all_ok = all_ok and board.take_key(
							NightRegisterProp.PLANT_HOOK)
		_check("route %s is walkable end to end" % "-".join(order), all_ok)
		reached.append("%s|%s|%s" % [board.slip_taken,
				board.key_out(NightRegisterProp.APARTMENT_HOOK),
				board.key_out(NightRegisterProp.PLANT_HOOK)])
	var distinct := {}
	for r in reached:
		distinct[r] = true
	_check("all six orders reach ONE identical condition (%s)"
					% ", ".join(distinct.keys()),
			distinct.size() == 1 and reached.size() == 6)

	# Either key alone, and neither: the choice is not "all or nothing".
	_fresh_board()
	_check("the plant key alone is a legal condition",
			board.take_key(NightRegisterProp.PLANT_HOOK)
			and board.key_out(NightRegisterProp.PLANT_HOOK)
			and not board.key_out(NightRegisterProp.APARTMENT_HOOK))
	_fresh_board()
	_check("the apartment key alone is a legal condition",
			board.take_key(NightRegisterProp.APARTMENT_HOOK)
			and board.key_out(NightRegisterProp.APARTMENT_HOOK)
			and not board.key_out(NightRegisterProp.PLANT_HOOK))
	_fresh_board()
	work_orders.issue_job(NightRegisterProp.JOB_ID, "reported")
	_check("and the report with no key at all is a legal condition",
			board.take_slip() and board.keys_out_count() == 0)


# --- abort -------------------------------------------------------------------

func _abort() -> void:
	_fresh_board()
	work_orders.issue_job(NightRegisterProp.JOB_ID, "reported")
	var found: Dictionary = board.maintenance_snapshot()
	board.take_slip()
	board.take_key(NightRegisterProp.APARTMENT_HOOK)
	board.take_key(NightRegisterProp.PLANT_HOOK)
	board.take_key(NightRegisterProp.PLANT_HOOK)   # leaves a refusal standing
	_check("a session can take the report and both keys",
			board.slip_taken and board.keys_out_count() == 2
			and board.balking())

	board.restore_maintenance_snapshot(found)
	_check("ABORT puts both keys back on their hooks",
			not board.key_out(NightRegisterProp.APARTMENT_HOOK)
			and not board.key_out(NightRegisterProp.PLANT_HOOK))
	_check("ABORT puts the report back on the spindle",
			not board.slip_taken and board.slip_available())
	_check("ABORT clears the refusal it was holding", not board.balking())
	var after: Dictionary = board.maintenance_snapshot()
	var drifted: Array[String] = []
	for key in found.keys():
		if str(after.get(key)) != str(found.get(key)):
			drifted.append(str(key))
	_check("ABORT restores every fact the board had, exactly (%s)"
					% ", ".join(drifted),
			drifted.is_empty() and after.size() == found.size())
	_check("and an aborted session wrote nothing to the register",
			board.signed_lines == 0
			and not RealityState.data.has(NightRegisterProp.STATE_KEY))
	# The stage the spine holds is NOT rolled back, and that is correct: the
	# acknowledgement was real work by its real owner. Abort owns the board,
	# never the ledger.
	_check("abort does not roll back the SPINE, which owns its own lifecycle",
			work_orders.job_stage(NightRegisterProp.JOB_ID) == "acknowledged")


# --- the keys respect an ownership they do not hold --------------------------

func _access_ownership() -> void:
	_fresh_board()
	_check("the plant hook is tagged for the five service closets",
			board.tagged_door_count(NightRegisterProp.PLANT_HOOK) == 5
			and board.tagged_doors(NightRegisterProp.PLANT_HOOK).has(
					"F04_DOOR_04"))
	_check("the apartment hook is tagged for 2B's own entry, and only that",
			board.tagged_door_count(NightRegisterProp.APARTMENT_HOOK) == 1
			and board.tagged_doors(NightRegisterProp.APARTMENT_HOOK)
					== ["F02_DOOR_03"])
	# THE SECOND LESSON, MEASURED. Two keys, two completely different kinds of
	# permission, and nothing on the board distinguishes them.
	_check("the plant key's five doors are all genuinely locked (%d/5)"
					% board.locked_count(NightRegisterProp.PLANT_HOOK),
			board.locked_count(NightRegisterProp.PLANT_HOOK) == 5)
	_check("the apartment key's door is not locked at all (%d/1)"
					% board.locked_count(NightRegisterProp.APARTMENT_HOOK),
			board.locked_count(NightRegisterProp.APARTMENT_HOOK) == 0)

	var before: Dictionary = {}
	for door in building.get_children():
		if door is StandInDoor:
			before[door.name] = str(door.leaf_state)
	board.take_key(NightRegisterProp.PLANT_HOOK)
	board.take_key(NightRegisterProp.APARTMENT_HOOK)
	board.return_key(NightRegisterProp.PLANT_HOOK)
	board.return_key(NightRegisterProp.APARTMENT_HOOK)
	var drifted: Array[String] = []
	for door in building.get_children():
		if door is StandInDoor and str(door.leaf_state) != before[door.name]:
			drifted.append(str(door.name))
	# THE HARD LINE. `DoorProp.leaf_state` belongs to the layout and to
	# `orison_detail_pass._unlock_for_case`. A key board that wrote it would be
	# a second access owner, and this one is physically incapable of it.
	_check("taking and returning BOTH keys changes not one lock (%s)"
					% ", ".join(drifted),
			drifted.is_empty() and before.size() == 6)
	_check("a hook always reads either its key or its numbered check",
			board.hook_reads(NightRegisterProp.PLANT_HOOK) == "key"
			and board.take_key(NightRegisterProp.PLANT_HOOK)
			and board.hook_reads(NightRegisterProp.PLANT_HOOK) == "check 7")


# --- signing is the only publication -----------------------------------------

func _signing() -> void:
	_fresh_board()
	work_orders.issue_job(NightRegisterProp.JOB_ID, "reported")
	board.take_slip()
	board.take_key(NightRegisterProp.PLANT_HOOK)
	_check("nothing has reached RealityState before the book is signed",
			not RealityState.data.has(NightRegisterProp.STATE_KEY))

	var seen: Array[Dictionary] = []
	board.register_signed.connect(func(r: Dictionary) -> void: seen.append(r))
	_check("signing the register writes one line and reports once",
			board.sign_register() and seen.size() == 1
			and board.signed_lines == 1)
	var line: Dictionary = seen[0]
	_check("the line records the hour, the report and which hooks were empty",
			line.has("at") and bool(line.report_out)
			and (line.keys_out as Array) == ["plant"]
			and str(line.job_id) == NightRegisterProp.JOB_ID)
	# THE THESIS, ASSERTED. The board cannot write where anybody went, so it
	# does not pretend to. A richer line would be the apparatus telling the
	# very lie it exists to expose.
	var extra: Array[String] = []
	for key in line.keys():
		if str(key) not in ["at", "report_out", "keys_out", "job_id",
				"job_stage"]:
			extra.append(str(key))
	_check("and records NOTHING about where the key went (%s)"
					% ", ".join(extra),
			extra.is_empty())
	_check("the signed line persists under the board's own small state key",
			(RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array).size() == 1)
	board.sign_register()
	_check("a second signature is a second line, never an overwrite",
			board.signed_lines == 2
			and (RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array).size() == 2)


# --- what the board is not ---------------------------------------------------

func _ownership() -> void:
	# Read as text, deliberately. Behaviour proves what the board DOES; only
	# the source proves what it cannot do at all, and "there is no second
	# ledger" is a claim about absence.
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/night_register_prop.gd")
	var code := ""
	for raw in source.split("
"):
		if not raw.strip_edges().begins_with("#"):
			code += raw + "
"
	_check("the board is not a work order owner: no issue path exists",
			not code.contains("issue_job"))
	_check("and it never activates, resolves or reopens a case",
			not code.contains("activate_case")
			and not code.contains("resolve_case")
			and not code.contains("reopen_case")
			and not code.contains("RealityCases"))
	_check("it writes no lock: `leaf_state` is only ever read",
			not code.contains("leaf_state ="))
	_check("and `acknowledge_job` is the ONE mutating spine call it makes",
			code.count("_work_orders.call(") == 2
			and code.contains("\"acknowledge_job\"")
			and not code.contains("close_job")
			and not code.contains("record_job"))
	_check("no case state was created by anything on this board",
			RealityState.case_state("lena_unraveling").get("stage", "unseen")
					== "unseen")
	_check("exactly four literal service points, one per thing you can touch",
			board.find_children("*", "PropControlArea", true, false).size() == 4)
	for control_id in ["slip", "hook_apartment", "hook_plant", "book"]:
		_check("the %s is ray-reachable and prompts for itself" % control_id,
				board.get_node_or_null(NodePath("Reach_%s" % control_id))
						is PropControlArea
				and board.control_prompt(control_id) != "")
	_check("the apparatus owns no light and no collision body but its reaches",
			board.find_children("*", "Light3D", true, false).is_empty()
			and board.find_children("*", "CollisionObject3D", true,
					false).size() == 4)
	for part in ["RegisterBoard", "RegisterShelf", "ReportSpindle",
			"ReportSlip", "ReportStub", "RegisterBook", "RegisterPage", "RegisterPen",
			"Key_apartment", "Key_plant", "Check_apartment", "Check_plant",
			"Tag_apartment", "Tag_plant"]:
		_check("the apparatus shows its %s" % part,
				board.find_child(part, true, false) is MeshInstance3D)
	# The two keys are visibly different objects, because they are two
	# different permissions and the render has to say so without a caption.
	var flat := board.find_child("KeyShank_apartment", true, false) \
			as MeshInstance3D
	var heavy := board.find_child("KeyShank_plant", true, false) \
			as MeshInstance3D
	_check("the plant key is visibly the bigger key",
			flat != null and heavy != null
			and (heavy.mesh as BoxMesh).size.y
					> (flat.mesh as BoxMesh).size.y * 1.5)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [register ok] ", label)
	else:
		failures += 1
		printerr("  [REGISTER FAIL] ", label)
