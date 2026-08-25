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

## SR7-I. The two reports the board is authored to present, in that order.
## Every SR7-G/H proof below now runs on 001, the opening report, because that
## is the paper a new watchman actually meets first.
const JOB_2A := "vantry_chirp_2a"
const JOB_2B := "lena_radiator_round_2b"

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
	_conclusions()
	_presentation_rule()
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


## `mark_job_repairable` routes through `awaiting_part` for any job whose
## record declares a `required_item_id`, and 001 declares one where 002 does
## not. The data decides; this walks whichever road the data lays down.
func _drive_to_repairable(job_id: String) -> void:
	work_orders.diagnose_job(job_id)
	if work_orders.job_library.requires_part(job_id):
		work_orders.mark_job_awaiting_part(job_id)
	work_orders.mark_job_repairable(job_id)


func _fresh_board() -> void:
	# Each section starts from a clean campaign. The register's signed lines
	# live in `RealityState`, so a board that is "fresh" while the save still
	# holds the previous section's signatures is not fresh at all -- it comes
	# up reading them, which is exactly what a real one should do.
	RealityState.reset_campaign_for_tests()
	work_orders.setup(null)
	board.queue_free()
	board = RegisterScript.new() as NightRegisterProp
	board.prop_type = "night_register"
	building.add_child(board)


## SR7-H: a round the board will actually accept a signature for -- report
## taken and filed back, both keys returned, and a conclusion chosen by hand.
func _complete_round(outcome: String) -> void:
	work_orders.issue_job(JOB_2A, "reported")
	board.take_slip()
	board.take_key(NightRegisterProp.PLANT_HOOK)
	board.return_key(NightRegisterProp.PLANT_HOOK)
	board.replace_slip()
	board.select_outcome(outcome)


# --- the board presents what the spine holds ---------------------------------

func _presentation() -> void:
	# SR7-I. The board carries an authored ORDER of reports, and both of them
	# are real records in the existing library. It carries no third.
	_check("the board's authored order is 001 then 002, and only those two",
			NightRegisterProp.PRESENTABLE_JOBS == [JOB_2A, JOB_2B])
	for job_id in NightRegisterProp.PRESENTABLE_JOBS:
		_check("%s is a record the existing job library already holds"
						% str(job_id),
				not work_orders.job_library.job(str(job_id)).is_empty())
	_check("and `closed` and `missing` are the only unpresentable stages",
			MaintenanceJobLibrary.STAGES.size()
					== NightRegisterProp.PRESENTABLE_STAGES.size() + 1
			and "closed" not in NightRegisterProp.PRESENTABLE_STAGES)
	_check("with no job issued the spindle is empty",
			work_orders.job_stage(JOB_2A) == "missing"
			and not board.slip_available()
			and board.job_stage() == "missing")
	# THE CENTRAL NEGATIVE. A board that manufactured its own report would be
	# a second ledger; this one simply has nothing to hold.
	_check("touching an empty spindle issues NOTHING",
			not board.take_slip()
			and work_orders.job_stage(JOB_2A) == "missing"
			and RealityState.data.get("maintenance_jobs", {}).is_empty())
	_check("and it says so rather than failing silently", board.balking())

	# The one issuing owner does its job. `ServiceRoundDirector` makes exactly
	# this call from `answer_incoming_call`.
	work_orders.issue_job(JOB_2A, "reported")
	_check("once the spine issues the job, a slip appears on the spindle",
			board.slip_available() and board.job_stage() == "issued")
	_check("and the slip reads the library, holding no copy of its own",
			board.slip_text().contains("THE CHIRP")
			and board.slip_text().contains("Find it by ear"))

	var jobs_before: int = RealityState.data.get("maintenance_jobs", {}).size()
	_check("taking the report acknowledges the EXISTING job",
			board.take_slip()
			and work_orders.job_stage(JOB_2A)
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
			work_orders.job_stage(JOB_2A) == "acknowledged")
	board.replace_slip()


func _refusals() -> void:
	_fresh_board()
	work_orders.issue_job(JOB_2A, "reported")

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

	# REFUSAL 5: an unmarked register. SR7-H made "nothing to record" mean
	# NO ROUND WAS EVER OPENED, rather than SR7-G's "nothing is currently in
	# your hands" -- so this needs a board nobody has taken a report from.
	_fresh_board()
	_check("REFUSAL: a register with nothing to record will not be signed",
			not board.has_unsigned_work()
			and not board.sign_register()
			and board.balking()
			and board.signed_lines == 0)

	# --- SR7-H: THE THREE THINGS THAT MUST BE TRUE BEFORE A SIGNATURE ------
	# None of these is about ROUTE. They say the round is over and that you
	# have decided what you are willing to put on paper.
	_fresh_board()
	work_orders.issue_job(JOB_2A, "reported")
	board.take_slip()
	board.take_key(NightRegisterProp.PLANT_HOOK)
	board.select_outcome(NightRegisterProp.OUTCOME_FAULT_CORRECTED)
	_check("REFUSAL: you cannot sign while the keys are still out",
			not board.sign_register() and board.balking()
			and board.signed_lines == 0)
	board.return_key(NightRegisterProp.PLANT_HOOK)
	_check("REFUSAL: you cannot sign while the report is still in your hand",
			board.slip_taken and not board.sign_register()
			and board.balking() and board.signed_lines == 0)
	board.replace_slip()
	board.select_outcome("")
	_check("REFUSAL: you cannot sign with the index on the blank",
			not board.outcome_selected() and not board.sign_register()
			and board.balking() and board.signed_lines == 0)
	board.select_outcome(NightRegisterProp.OUTCOME_NO_FAULT_FOUND)
	_check("and with all three answered, the same board signs",
			board.ready_to_file() and board.sign_register()
			and board.signed_lines == 1)
	# IDEMPOTENT. The round closed; a second press has nothing to file.
	_check("REFUSAL: signing again files nothing and adds no line",
			not board.sign_register() and board.balking()
			and board.signed_lines == 1
			and (RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array).size() == 1)

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
	# On its own board: the SR7-H signing block above files a real line, and a
	# pose test that also asserts "nothing was written" has to start from a
	# register nobody has signed.
	_fresh_board()
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
		work_orders.issue_job(JOB_2A, "reported")
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
	work_orders.issue_job(JOB_2A, "reported")
	_check("and the report with no key at all is a legal condition",
			board.take_slip() and board.keys_out_count() == 0)


# --- abort -------------------------------------------------------------------

func _abort() -> void:
	_fresh_board()
	work_orders.issue_job(JOB_2A, "reported")
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

	# --- SR7-H: THE ABORT HAS TO CARRY THE WORDS TOO -----------------------
	_fresh_board()
	_complete_round(NightRegisterProp.OUTCOME_DISTURBANCE_PERSISTS)
	board.sign_register()
	var filed_lines: int = (RealityState.data.get(
			NightRegisterProp.STATE_KEY, {}).get("lines", []) as Array).size()
	# SR7-I: a signed round leaves the board IDLE and the index back on the
	# blank, so the next watchman cannot find a conclusion already entered
	# and the next report can come up on the spindle.
	_check("a signed round leaves one line and the index back on the blank",
			filed_lines == 1 and board.signed_lines == 1
			and board.selected_outcome() == "" and not board.engaged())

	# The state an abort actually has to protect is MID-round, with a
	# conclusion chosen and nothing yet written.
	_complete_round(NightRegisterProp.OUTCOME_ACCESS_UNSUCCESSFUL)
	var filed: Dictionary = board.maintenance_snapshot()
	_check("mid-round: a conclusion is chosen and nothing is written",
			board.selected_outcome()
					== NightRegisterProp.OUTCOME_ACCESS_UNSUCCESSFUL
			and board.signed_lines == filed_lines)
	board.sign_register()
	_check("a second round files a second line under a different conclusion",
			board.signed_lines == 2
			and str((RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array)[1].filing)
					== NightRegisterProp.OUTCOME_ACCESS_UNSUCCESSFUL)

	board.restore_maintenance_snapshot(filed)
	_check("ABORT puts the index back on the conclusion it was standing on",
			board.selected_outcome()
					== NightRegisterProp.OUTCOME_ACCESS_UNSUCCESSFUL
			and board.index_detent == 4)
	# THE ONE IRREVERSIBLE THING ON A REVERSIBLE BOARD, if it were allowed to
	# be: an abort that restored the apparatus but left the signature in the
	# save. The written lines come back too.
	_check("ABORT rolls the written lines back to exactly what was there (%d)"
					% filed_lines,
			board.signed_lines == filed_lines
			and (RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array).size() == filed_lines)
	var after_words: Dictionary = board.maintenance_snapshot()
	var words_drift: Array[String] = []
	for key in filed.keys():
		if str(after_words.get(key)) != str(filed.get(key)):
			words_drift.append(str(key))
	_check("ABORT restores the whole board byte-for-byte, words included (%s)"
					% ", ".join(words_drift),
			words_drift.is_empty() and after_words.size() == filed.size())
	# The stage the spine holds is NOT rolled back, and that is correct: the
	# acknowledgement was real work by its real owner. Abort owns the board,
	# never the ledger.
	_check("abort does not roll back the SPINE, which owns its own lifecycle",
			work_orders.job_stage(JOB_2A) == "acknowledged")


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
	_complete_round(NightRegisterProp.OUTCOME_FAULT_CORRECTED)
	_check("nothing has reached RealityState before the book is signed",
			not RealityState.data.has(NightRegisterProp.STATE_KEY))

	var seen: Array[Dictionary] = []
	board.register_signed.connect(func(r: Dictionary) -> void: seen.append(r))
	_check("signing the register writes one line and reports EXACTLY once",
			board.sign_register() and seen.size() == 1
			and board.signed_lines == 1)
	var line: Dictionary = seen[0]
	# SR7-H. The record carries the words. It is neutral -- an id and the
	# printing it came from -- and it is the vocabulary the first-shift owner
	# already speaks, so the eventual join needs no translation table.
	_check("the published record carries the SELECTED conclusion",
			str(line.filing) == NightRegisterProp.OUTCOME_FAULT_CORRECTED
			and str(line.filing_printed).contains("FAULT CORRECTED"))
	_check("the record still carries the hour, the job and the hooks",
			line.has("at") and not bool(line.report_out)
			and (line.keys_out as Array).is_empty()
			and str(line.job_id) == JOB_2A)
	# THE THESIS, ASSERTED. The board records the CLAIM. It writes nothing
	# about where anybody went and nothing that would verify the claim.
	var extra: Array[String] = []
	for key in line.keys():
		if str(key) not in ["at", "filing", "filing_printed", "report_out",
				"keys_out", "job_id", "job_stage"]:
			extra.append(str(key))
	_check("and records NOTHING beyond the claim and its circumstances (%s)"
					% ", ".join(extra),
			extra.is_empty())
	_check("the signed line persists under the board's own small state key",
			(RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array).size() == 1)

	# THE SHAPE THE CONSUMER ACTUALLY READS, asserted without wiring the two
	# owners together. `FirstShiftDirector.accept_signed_register` requires a
	# `filing` in `FILING_OUTCOMES`, a matching `job_id`, `report_out` false
	# and an empty `keys_out` -- and drops anything else SILENTLY, by design.
	# A receipt the consumer would quietly ignore is not a receipt, and the
	# last three of those four are, exactly, the conditions this board already
	# refuses to sign without.
	_check("the published receipt satisfies the director's guard verbatim",
			str(line.filing) in FirstShiftDirector.FILING_OUTCOMES
			and str(line.job_id) == JOB_2A
			and not bool(line.report_out)
			and (line.keys_out as Array).is_empty())

	_complete_round(NightRegisterProp.OUTCOME_NO_FAULT_FOUND)
	board.sign_register()
	_check("a second ROUND is a second line, never an overwrite",
			board.signed_lines == 2 and seen.size() == 2
			and str(seen[1].filing)
					== NightRegisterProp.OUTCOME_NO_FAULT_FOUND
			and (RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array).size() == 2)


# --- SR7-I: which paper is on the spindle ------------------------------------

func _presentation_rule() -> void:
	# EMPTY SPINDLE. Nothing issued, nothing to present, and touching it does
	# not manufacture work -- the opening report belongs to
	# `CoreLoopDirector.offer_opening_report()` and Lena's to
	# `ServiceRoundDirector`.
	_fresh_board()
	_check("with neither report issued the spindle is empty",
			board.presented_job_id() == "" and board.first_open_job() == ""
			and not board.slip_available() and board.slip_number() == "")
	var jobs_before: int = RealityState.data.get(
			"maintenance_jobs", {}).size()
	_check("and touching it issues NOTHING",
			not board.take_slip() and board.balking()
			and RealityState.data.get("maintenance_jobs", {}).size()
					== jobs_before
			and work_orders.job_stage(JOB_2A) == "missing"
			and work_orders.job_stage(JOB_2B) == "missing")

	# MINA 2A IS THE OPENING REPORT. Issued by its own owner's public call.
	work_orders.issue_job(JOB_2A, "reported")
	_check("once 001 is issued it is the paper on the spindle",
			board.presented_job_id() == JOB_2A and board.slip_available())
	_check("and the paper IDENTIFIES ITSELF: number, unit and symptom",
			board.slip_number() == "WORK ORDER 001"
			and board.slip_unit() == "UNIT 2A"
			and board.slip_symptom().contains("line-test tone")
			and board.slip_name() == "THE CHIRP")

	# TAKING IT ACKNOWLEDGES EXACTLY THAT JOB, and reports the id it took.
	var taken: Array[String] = []
	board.report_taken.connect(func(j: String) -> void: taken.append(j))
	_check("taking it acknowledges exactly 001, and says which it took",
			board.take_slip() and taken == [JOB_2A]
			and work_orders.job_stage(JOB_2A) == "acknowledged"
			and work_orders.job_stage(JOB_2B) == "missing")
	_check("no second job record was created (%d)" % jobs_before,
			RealityState.data.get("maintenance_jobs", {}).size()
					== jobs_before + 1)
	_check("and the board is now LATCHED to the paper in your hand",
			board.engaged() and board.latched_job() == JOB_2A)

	# 002 CANNOT DISPLACE AN OPEN 001 ROUND. Issue Lena's report mid-round and
	# close Mina's underneath it: the paper in hand does not change.
	work_orders.issue_job(JOB_2B, "reported")
	_check("002 issued mid-round does not touch the paper in hand",
			board.presented_job_id() == JOB_2A
			and board.latched_job() == JOB_2A)
	_drive_to_repairable(JOB_2A)
	work_orders.record_job_repair(JOB_2A,
			{"quality": "good", "note": "capsule replaced"})
	work_orders.close_job(JOB_2A)
	_check("the spine closed 001 under its own power",
			work_orders.job_stage(JOB_2A) == "closed")
	# THE ONE THAT MATTERS. 001 is closed and 002 is open; the authored order
	# would now choose 002. The latch says no, because a physical spindle
	# cannot swap the paper somebody is already carrying.
	_check("EVEN WITH 001 CLOSED the open round keeps its own paper",
			board.presented_job_id() == JOB_2A
			and board.first_open_job() == JOB_2B)

	# FILING RECORDS THE DYNAMIC ID -- the paper actually carried, not a
	# constant and not whatever is on the spindle now.
	var signed: Array[Dictionary] = []
	board.register_signed.connect(
			func(r: Dictionary) -> void: signed.append(r))
	board.replace_slip()
	board.select_outcome(NightRegisterProp.OUTCOME_FAULT_CORRECTED)
	_check("the round files under 001, the job it was actually taken for",
			board.sign_register() and signed.size() == 1
			and str(signed[0].job_id) == JOB_2A
			and str(signed[0].filing)
					== NightRegisterProp.OUTCOME_FAULT_CORRECTED)
	_check("filing closed no job and advanced nothing",
			work_orders.job_stage(JOB_2A) == "closed"
			and work_orders.job_stage(JOB_2B) == "issued")

	# AND NOW THE PAPER CHANGES, because the board is idle again.
	_check("with the round signed off, 002 comes up on the spindle",
			not board.engaged() and board.latched_job() == ""
			and board.presented_job_id() == JOB_2B
			and board.slip_available())
	_check("and the new paper identifies ITSELF, not the old one",
			board.slip_number() == "WORK ORDER 002"
			and board.slip_unit() == "UNIT 2B"
			and board.slip_symptom().contains("radiator")
			and board.slip_name() == "BORROWED BREATH")
	# THE TWO PAPERS ARE DIFFERENT PAPERS, in every printed field.
	_check("2A and 2B share not one printed line",
			board.slip_number() != "WORK ORDER 001"
			and board.slip_unit() != "UNIT 2A"
			and not board.slip_symptom().contains("line-test tone"))

	# AND THE PRINTING ON THE PAPER IS REAL GEOMETRY, not a prompt string.
	# Read back off the apparatus rather than through `find_children`: within
	# one `_ready()` nothing has been freed yet, so a name search still turns
	# up the PREVIOUS report's labels, which are queued for deletion and about
	# to vanish. What the board says it has printed is the honest question.
	var printed: Array[String] = []
	var all_live := true
	for label in (board.get("_slip_labels") as Array):
		var line := label as Label3D
		printed.append(str(line.text))
		all_live = all_live and line.is_inside_tree() 				and not line.is_queued_for_deletion()
	_check("the paper carries its own printed identity (%s)"
					% " / ".join(printed),
			printed.has("WORK ORDER 002") and printed.has("UNIT 2B")
			and printed.size() >= 4)
	_check("and that printing is live geometry in the tree, not a string",
			all_live and not printed.has("WORK ORDER 001"))
	board.take_slip()
	var hidden := true
	for label in (board.get("_slip_labels") as Array):
		hidden = hidden and not (label as Label3D).visible
	_check("the printing leaves the spindle with the paper", hidden)
	board.replace_slip()

	# EXISTING SIGNED LINES KEEP THEIR OWN JOB, whatever is on the spindle now.
	_check("the line already in the book still reads 001",
			str((RealityState.data.get(NightRegisterProp.STATE_KEY, {})
					.get("lines", []) as Array)[0].job_id) == JOB_2A)

	# RELOAD. A new board over the same save reconstructs the same report,
	# because the rule derives it from `WorkOrders` -- which its own owner
	# persists -- and this board writes not a word of it down.
	var before := board.presented_job_id()
	board.queue_free()
	board = RegisterScript.new() as NightRegisterProp
	board.prop_type = "night_register"
	building.add_child(board)
	_check("a board rebuilt over the same save presents the same report",
			board.presented_job_id() == before and before == JOB_2B)
	_check("and it comes up reading the line the book already holds",
			board.signed_lines == 1)
	_check("the register persists NO report of its own: only signed lines",
			(RealityState.data.get(NightRegisterProp.STATE_KEY, {}) as Dictionary)
					.keys() == ["lines"])

	# MID-ROUND RELOAD. 002 taken, then rebuilt: the acknowledged stage the
	# spine is holding is enough to put the same paper back on the spindle.
	board.take_slip()
	_check("002 taken and acknowledged", board.latched_job() == JOB_2B
			and work_orders.job_stage(JOB_2B) == "acknowledged")
	board.queue_free()
	board = RegisterScript.new() as NightRegisterProp
	board.prop_type = "night_register"
	building.add_child(board)
	_check("after a reload mid-round the same report is still presented",
			board.presented_job_id() == JOB_2B)

	# A CLOSED BOARD. Both jobs finished: the spindle is bare again, and it
	# does not reach back for a closed one.
	_drive_to_repairable(JOB_2B)
	work_orders.record_job_repair(JOB_2B,
			{"quality": "good", "note": "vent freed"})
	work_orders.close_job(JOB_2B)
	board.queue_free()
	board = RegisterScript.new() as NightRegisterProp
	board.prop_type = "night_register"
	building.add_child(board)
	_check("with both reports closed the spindle is empty again",
			board.presented_job_id() == "" and not board.slip_available())


# --- SR7-H: the words, and who is allowed to choose them ---------------------

func _conclusions() -> void:
	_check("there are four conclusions and only four",
			NightRegisterProp.OUTCOMES.size() == 4
			and NightRegisterProp.OUTCOME_CARD.size() == 4)
	# The vocabulary is `FirstShiftDirector.FILING_OUTCOMES` verbatim. SR7-H
	# does not CONNECT the two owners -- that seam is the director's -- but a
	# private vocabulary would make the join a translation table, and a
	# translation table between two owners is where a fifth one gets invented.
	_check("and they are the first-shift director's ids, verbatim",
			NightRegisterProp.OUTCOMES == ["fault_corrected",
					"disturbance_persists", "no_fault_found",
					"access_unsuccessful"])
	for outcome in NightRegisterProp.OUTCOMES:
		_check("the card has %s printed on it" % str(outcome),
				str(NightRegisterProp.OUTCOME_CARD[outcome]).length() > 8)

	# NO DEFAULT. A board fresh out of the box stands on the blank, and the
	# blank is a PRINTED position rather than an absence.
	_fresh_board()
	_check("a fresh board has NO conclusion selected and reads as blank",
			board.index_detent == 0 and board.selected_outcome() == ""
			and not board.outcome_selected()
			and board.card_line() == NightRegisterProp.CARD_BLANK)

	# NOT DERIVED FROM JOB STATE. Drive the spine right through its lifecycle
	# and the index must not move a millimetre.
	work_orders.issue_job(JOB_2A, "reported")
	board.take_slip()
	_drive_to_repairable(JOB_2A)
	# `record_job_repair` validates the quality against
	# `MaintenanceJobLibrary.REPAIR_QUALITIES`, so this has to be a real one:
	# the point of the check below is that the spine genuinely reached
	# `repaired` on its own, not that a stub said it did.
	work_orders.record_job_repair(JOB_2A,
			{"quality": "good", "note": "vent freed and clocked"})
	_check("the spine reached `repaired` under its own power",
			work_orders.job_stage(JOB_2A) == "repaired")
	_check("AND THE INDEX HAS NOT MOVED. No stage picks a conclusion.",
			board.index_detent == 0 and board.selected_outcome() == "")

	# A REPAIRED JOB MAY STILL BE FILED AS "DISTURBANCE PERSISTS". The
	# register records what the player is willing to sign and does not check
	# that claim against the machinery -- which is the whole reason a person
	# rather than a state machine chooses the words.
	board.take_key(NightRegisterProp.PLANT_HOOK)
	board.return_key(NightRegisterProp.PLANT_HOOK)
	board.replace_slip()
	board.select_outcome(NightRegisterProp.OUTCOME_DISTURBANCE_PERSISTS)
	var claims: Array[Dictionary] = []
	board.register_signed.connect(
			func(r: Dictionary) -> void: claims.append(r))
	_check("a REPAIRED job can be filed as 'disturbance persists'",
			board.sign_register() and claims.size() == 1
			and str(claims[0].filing)
					== NightRegisterProp.OUTCOME_DISTURBANCE_PERSISTS
			and str(claims[0].job_stage) == "repaired")
	_check("and the spine is not corrected, contradicted or advanced by it",
			work_orders.job_stage(JOB_2A) == "repaired")
	_complete_round(NightRegisterProp.OUTCOME_FAULT_CORRECTED)
	_check("the same repaired job can equally be filed as 'fault corrected'",
			board.sign_register() and claims.size() == 2
			and str(claims[1].filing)
					== NightRegisterProp.OUTCOME_FAULT_CORRECTED
			and str(claims[1].job_stage) == "repaired")

	# NO FREE TEXT AND NO FIFTH CONCLUSION. The selector is a detented index
	# over an engraved card: there is nowhere for it to stand that is not one
	# of the four, so an invalid conclusion is not rejected by a rule -- it is
	# unreachable by the object.
	_fresh_board()
	for bogus in ["the walls were breathing", "haunted", "fault_Corrected",
			"disturbance persists", "5", "no_fault_found "]:
		_check("REFUSAL: %s is not a conclusion this card can print"
						% JSON.stringify(bogus),
				not board.select_outcome(bogus)
				and board.selected_outcome() == ""
				and board.index_detent == 0)
	_check("clearing the index back to blank is always allowed",
			board.select_outcome("") and board.selected_outcome() == "")

	# THE INDEX HAS FIVE STOPS AND WRAPS THROUGH THE BLANK. Pushing it forever
	# cannot reach a sixth, and it always comes back past nothing-entered.
	var visited: Array[String] = []
	for i in 11:
		visited.append(board.card_line())
		board.advance_index()
	var distinct := {}
	for v in visited:
		distinct[v] = true
	_check("the index cycles through exactly five stops and no more (%d)"
					% distinct.size(),
			distinct.size() == 5)
	_check("and it never stands anywhere outside its five detents",
			board.index_detent >= 0
			and board.index_detent <= NightRegisterProp.OUTCOMES.size())

	# ALL FOUR ARE REACHABLE BY HAND, one deliberate push at a time.
	for i in NightRegisterProp.OUTCOMES.size():
		_fresh_board()
		var wanted := str(NightRegisterProp.OUTCOMES[i])
		var pushes := 0
		while board.selected_outcome() != wanted and pushes < 8:
			board.advance_index()
			pushes += 1
		_check("%s is reached by %d deliberate pushes of the index"
						% [wanted, pushes],
				board.selected_outcome() == wanted and pushes == i + 1)


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
	# Every method this prop is capable of invoking on the spine, read out of
	# its own source. `job_stage` is a read; `acknowledge_job` is the single
	# mutation. Anything else appearing here would be a new owner.
	var spine_calls: Array[String] = []
	var pieces := code.split("_work_orders.call(\"")
	# Piece 0 is the text BEFORE the first call site, never a method name.
	for i in range(1, pieces.size()):
		var name := str(pieces[i]).split("\"")[0]
		if str(name) not in spine_calls:
			spine_calls.append(str(name))
	spine_calls.sort()
	_check("the ONLY spine methods it can reach are job_stage and "
					+ "acknowledge_job (%s)" % ", ".join(spine_calls),
			spine_calls == ["acknowledge_job", "job_stage"])
	_check("and it can neither issue, close nor repair anything",
			not code.contains("issue_job") and not code.contains("close_job")
			and not code.contains("record_job")
			and not code.contains("diagnose_job")
			and not code.contains("offer_opening_report"))
	_check("no case state was created by anything on this board",
			RealityState.case_state("lena_unraveling").get("stage", "unseen")
					== "unseen")
	_check("exactly five literal service points, one per thing you can touch",
			board.find_children("*", "PropControlArea", true, false).size() == 5)
	for control_id in ["slip", "hook_apartment", "hook_plant", "index",
			"book"]:
		_check("the %s is ray-reachable and prompts for itself" % control_id,
				board.get_node_or_null(NodePath("Reach_%s" % control_id))
						is PropControlArea
				and board.control_prompt(control_id) != "")
	_check("the apparatus owns no light and no collision body but its reaches",
			board.find_children("*", "Light3D", true, false).is_empty()
			and board.find_children("*", "CollisionObject3D", true,
					false).size() == 5)
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
