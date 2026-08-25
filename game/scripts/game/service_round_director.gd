class_name ServiceRoundDirector
extends Node
## The travel-bearing waking service round. WorkOrders owns every durable
## lifecycle fact; this node only translates events from four existing owners
## into legal calls on that public contract.

signal incoming_call_changed(waiting: bool)
signal route_beat(beat: String)

const JOB_ID := "lena_radiator_round_2b"
const PREVIOUS_JOB_ID := "vantry_chirp_2a"
const CASE_ID := "lena_unraveling"
const RESIDENT_ID := "lena_ortiz"
const RADIATOR_ID := "F02_B_RADIATOR_01"
const BOARD_ID := "LobbyPorterBoard"
const BOILER_ID := "B1_BOILER_01"

var work_orders: WorkOrders
var building: Node
var player: PlayerController
var dialogue: CaseDialoguePanel
var _radiator: RadiatorProp
var _board: OtisProp
var _boiler: BoilerProp
var _call_waiting := false


func setup(spine: WorkOrders, world: Node, the_player: PlayerController,
		carrier: ServiceSetCarrier = null) -> void:
	work_orders = spine
	building = world
	player = the_player
	dialogue = CaseDialoguePanel.new()
	dialogue.name = "ServiceRoundDialogue"
	add_child(dialogue)
	_bind_world_owners()
	if not RealityCases.resident_interaction_requested.is_connected(
			_on_resident_interaction):
		RealityCases.resident_interaction_requested.connect(
				_on_resident_interaction)
	if work_orders and not work_orders.job_stage_changed.is_connected(
			_on_job_stage_changed):
		work_orders.job_stage_changed.connect(_on_job_stage_changed)
	if player and not player.world_modified.is_connected(_on_world_modified):
		player.world_modified.connect(_on_world_modified)
	if carrier:
		carrier.bind_service_round(self)
	_refresh_call_gate()


func has_incoming_call() -> bool:
	return _call_waiting


## The carried service set calls this when R is pressed while its line jewel
## is waiting. Issuing happens before the dialogue surface opens, so closing or
## losing that surface cannot lose the resident's report.
func answer_incoming_call() -> bool:
	if not _call_waiting or work_orders == null:
		return false
	if not work_orders.issue_job(JOB_ID, "reported"):
		return false
	_set_call_waiting(false)
	route_beat.emit("call")
	dialogue.present("LENA ORTIZ · SERVICE SET",
			"Two-B's radiator breathes, but the iron stays cold. Please don't replace the first thing that looks guilty. Come hear it before you decide.", [
				{"text": "I'll read the whole line first.", "action": Callable()},
				{"text": "I'm coming up. Don't touch the valve.", "action": Callable()}
			])
	return true


func _bind_world_owners() -> void:
	if building == null:
		return
	_radiator = building.get_node_or_null(RADIATOR_ID) as RadiatorProp
	_boiler = building.get_node_or_null(BOILER_ID) as BoilerProp
	_board = building.find_child(BOARD_ID, true, false) as OtisProp
	if _radiator and not _radiator.maintenance_completed.is_connected(
			_on_radiator_completed):
		_radiator.maintenance_completed.connect(_on_radiator_completed)
	if _board and not _board.maintenance_completed.is_connected(
			_on_board_completed):
		_board.maintenance_completed.connect(_on_board_completed)
	if _boiler and not _boiler.maintenance_completed.is_connected(
			_on_boiler_completed):
		_boiler.maintenance_completed.connect(_on_boiler_completed)


func _on_job_stage_changed(job_id: String, _from: String, _to: String,
		_state: Dictionary) -> void:
	if job_id == PREVIOUS_JOB_ID or job_id == JOB_ID:
		_refresh_call_gate()


func _refresh_call_gate() -> void:
	if work_orders == null:
		_set_call_waiting(false)
		return
	_set_call_waiting(work_orders.job_stage(PREVIOUS_JOB_ID) == "closed"
			and work_orders.job_stage(JOB_ID) == "missing")


func _set_call_waiting(waiting: bool) -> void:
	if _call_waiting == waiting:
		return
	_call_waiting = waiting
	incoming_call_changed.emit(waiting)


func _on_resident_interaction(case_id: String, resident_id: String) -> void:
	if case_id != CASE_ID or resident_id != RESIDENT_ID or work_orders == null:
		return
	match work_orders.job_stage(JOB_ID):
		"issued":
			if work_orders.acknowledge_job(JOB_ID):
				route_beat.emit("resident")
				_present_threshold()
		"repaired":
			_present_return()


func _present_threshold() -> void:
	dialogue.present("LENA ORTIZ · 2B",
			"It hisses first, then the pipe knocks downstairs, then this room gets nothing. If you show me the route, I'll believe the patch.", [
				{"text": "Vent, call contacts, boiler glass. In that order.",
					"action": Callable()},
				{"text": "I'll bring back evidence, not a guess.",
					"action": Callable()}
			])


func _present_return() -> void:
	var close_round := func():
		RealityCases.record_conversation(CASE_ID,
				"service_round_visible_patch", 1)
		if work_orders.close_job(JOB_ID):
			route_beat.emit("resident_return")
	dialogue.present("LENA ORTIZ · 2B",
			"I can see where you opened it, and I can hear air leave before the iron warms. You didn't hide the repair.", [
				{"text": "A visible patch can still hold.", "action": close_round},
				{"text": "The whole building proved this local fault.",
					"action": close_round}
			])


## Opening the correct service reach is the inspection. The activity may be
## aborted without changing the radiator; completion is deliberately ignored
## until the comparisons make the job repairable.
func _on_world_modified(_where: Vector3, what: String) -> void:
	if what != RADIATOR_ID or work_orders == null \
			or work_orders.job_stage(JOB_ID) != "acknowledged":
		return
	if work_orders.record_job_evidence(JOB_ID, "radiator_airbound"):
		route_beat.emit("radiator_evidence")


func _on_board_completed(_result: Dictionary) -> void:
	_record_comparison("lobby_contact_compared", "lobby_comparison",
			"radiator_airbound")


func _on_boiler_completed(_result: Dictionary) -> void:
	_record_comparison("boiler_pressure_compared", "basement_comparison",
			"lobby_contact_compared")


func _record_comparison(flag: String, beat: String, prerequisite: String) -> void:
	if work_orders == null or work_orders.job_stage(JOB_ID) != "acknowledged":
		return
	if prerequisite not in work_orders.job_state(JOB_ID).get("evidence", []):
		return
	if work_orders.record_job_evidence(JOB_ID, flag):
		route_beat.emit(beat)
	_try_finish_diagnosis()


func _try_finish_diagnosis() -> void:
	var state := work_orders.job_state(JOB_ID)
	var evidence: Array = state.get("evidence", [])
	for required in ["radiator_airbound", "lobby_contact_compared",
			"boiler_pressure_compared"]:
		if required not in evidence:
			return
	if work_orders.diagnose_job(JOB_ID) \
			and work_orders.mark_job_repairable(JOB_ID):
		route_beat.emit("diagnosis")


func _on_radiator_completed(result: Dictionary) -> void:
	if work_orders == null or work_orders.job_stage(JOB_ID) != "repairable":
		return
	if work_orders.record_job_repair(JOB_ID, {
			"quality": "good",
			"note": str(result.get("note",
					"vent freed and clocked; one-pipe supply fully open"))}):
		route_beat.emit("repair")
