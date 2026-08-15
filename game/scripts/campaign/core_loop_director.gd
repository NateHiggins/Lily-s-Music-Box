class_name CoreLoopDirector
extends Node
## The thin K4 coordinator for the golden shift. It listens at authoritative
## boundaries and connects them; it owns none of the rules it connects.
##
## What it does:
## - hears Mina's complaint (the existing resident-interaction event) and
##   issues the one authored job with reported origin — or recognizes an
##   already-discovered job and touches nothing;
## - hears the job reach `repaired` and requests the earned conversation;
## - hears RealityCases' authoritative `conversation_changed_rule`, closes the
##   repaired work order only when Mina has earned her complete rule, then
##   waits for case integration before opening the dream window;
## - evaluates the job's data-authored dream window, suppresses the request
##   while a call or conversation protects the player (`call_locked`), and
##   emits the data-authored case/profile request to DreamDirector;
## - accepts the wake boundary and returns the player to the authored 4B
##   bedside anchor without undoing any committed work.
##
## What it must never absorb: WorkOrders lifecycle rules, ChirpHunt fault
## behavior, shop/inventory transactions, repair mechanics, dialogue logic,
## case truth, sleep-pressure rules, dream gameplay, or presentation.
##
## Persisted facts (RealityState.data.core_loop) are orchestration only:
## active job id, loop boundary, conversation requested/complete, dream
## pending, safe return anchor id. Everything else is reconstructed from
## its domain owner on restore.

signal conversation_requested(case_id: String, resident_id: String)
signal dream_requested(case_id: String, profile_id: String, window: Dictionary)
signal wake_completed(anchor_id: String)

const JOB_ID := ChirpHunt.JOB_ID
const RETURN_ANCHOR_ID := "F04_B_BED"
## Ordered loop boundaries; persisted as the authoritative campaign position.
const BOUNDARIES: Array[String] = ["idle", "job_open", "conversation_pending",
		"conversation_complete", "dream_pending", "wake_complete"]

var work_orders: WorkOrders
var player: Node3D
var layout: Dictionary = {}
## Transient session guard so one arming emits one dream request; a restore
## resets it, which is exactly the resume-once contract.
var _dream_request_sent := false


func setup(spine: WorkOrders, the_player: Node3D,
		building_layout: Dictionary) -> void:
	if work_orders != null and is_instance_valid(work_orders) \
			and work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		work_orders.job_stage_changed.disconnect(_on_job_stage_changed)
	work_orders = spine
	player = the_player
	layout = building_layout
	if not work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		work_orders.job_stage_changed.connect(_on_job_stage_changed)
	if not RealityCases.resident_interaction_requested.is_connected(
			_on_resident_interaction):
		RealityCases.resident_interaction_requested.connect(
				_on_resident_interaction)
	if not RealityCases.conversation_changed_rule.is_connected(_on_rule_changed):
		RealityCases.conversation_changed_rule.connect(_on_rule_changed)
	if not RealityCases.case_resolved.is_connected(_on_case_resolved):
		RealityCases.case_resolved.connect(_on_case_resolved)
	set_process(false)
	_reconcile_boundary()
	if str(_state().get("boundary", "idle")) == "conversation_complete" \
			and bool(RealityState.case_state(_case_id()).get("resolved", false)):
		_evaluate_dream_window()
	if bool(_state().get("dream_pending", false)):
		_arm_dream_request()


## A job can exist before this coordinator does — a legacy save migrated by
## ChirpHunt during build, or a restore. Opening the boundary from the
## job's authoritative existence is reconciliation, not a rule: WorkOrders
## still owns every stage.
func _reconcile_boundary() -> void:
	var state := _state()
	if str(state.get("boundary", "idle")) == "idle" \
			and work_orders.job_stage(JOB_ID) != "missing":
		state.active_job_id = JOB_ID
		state.boundary = "job_open"
		RealityState.commit()


func boundary() -> String:
	return str(_state().get("boundary", "idle"))


func loop_state() -> Dictionary:
	return _state().duplicate(true)


## The campaign shell keeps this coordinator while replacing the world. Drop
## only scene-owned references and their signal; committed loop facts remain.
func detach_world() -> void:
	if work_orders != null and is_instance_valid(work_orders) \
			and work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		work_orders.job_stage_changed.disconnect(_on_job_stage_changed)
	work_orders = null
	player = null
	layout = {}
	set_process(false)


func _case_id() -> String:
	if work_orders == null or work_orders.job_library == null:
		return ""
	return str(work_orders.job_library.job(JOB_ID).get("case_id", ""))


func _resident_id() -> String:
	if work_orders == null or work_orders.job_library == null:
		return ""
	return str(work_orders.job_library.job(JOB_ID).get("resident_id", ""))


func _dream_profile_id() -> String:
	if work_orders == null or work_orders.job_library == null:
		return ""
	return str(work_orders.job_library.job(JOB_ID).get(
			"dream_profile_id", ""))


## Mina's complaint arrives through the existing interaction event. A
## missing job is issued with reported origin; an existing one — whatever
## its origin or stage — is recognized and left alone.
func _on_resident_interaction(case_id: String, resident_id: String) -> void:
	if case_id != _case_id() or resident_id != _resident_id():
		return
	if work_orders.job_stage(JOB_ID) == "missing":
		work_orders.issue_job(JOB_ID, "reported")


func _on_job_stage_changed(job_id: String, _from: String, to_stage: String,
		_job: Dictionary) -> void:
	if job_id != JOB_ID:
		return
	_reconcile_boundary()
	var state := _state()
	match to_stage:
		"repaired":
			if str(state.boundary) == "job_open" \
					and not bool(state.conversation_requested):
				state.boundary = "conversation_pending"
				state.conversation_requested = true
				RealityState.commit()
				conversation_requested.emit(_case_id(), _resident_id())


## The one event allowed to close the repaired order. Everything else —
## unrelated cases, ordinary conversation flags, the dialogue UI closing —
## is not this event and is ignored.
func _on_rule_changed(case_id: String, _flag: String,
		case_state: Dictionary) -> void:
	if case_id != _case_id():
		return
	var state := _state()
	if str(state.boundary) != "conversation_pending" \
			or work_orders.job_stage(JOB_ID) != "repaired" \
			or str(case_state.get("stage", "")) != "integration_ready":
		return
	if not work_orders.close_job(JOB_ID):
		return
	state.conversation_complete = true
	state.boundary = "conversation_complete"
	RealityState.commit()


## Conversation changes the rule; the case owner's final quiet calibration
## commits it. The dream is punctuation after that complete sentence, not an
## interruption between recognition and integration.
func _on_case_resolved(case_id: String, _case: Dictionary) -> void:
	if case_id != _case_id():
		return
	var state := _state()
	if str(state.boundary) != "conversation_complete" \
			or work_orders.job_stage(JOB_ID) != "closed":
		return
	_evaluate_dream_window()


## The data decides eligibility; the coordinator only reads it. Eligible
## means the job passed the authored stage and the conversation is done.
func _evaluate_dream_window() -> void:
	var state := _state()
	if bool(state.dream_pending) or str(state.boundary) != "conversation_complete":
		return
	var window: Dictionary = work_orders.job_library.job(JOB_ID).get(
			"dream_window", {})
	var gate := str(window.get("eligible_after_stage", ""))
	if work_orders.job_stage(JOB_ID) not in [gate, "closed"]:
		return
	state.dream_pending = true
	state.boundary = "dream_pending"
	RealityState.commit()
	_arm_dream_request()


## A call or conversation in progress protects the player (Bible §I.1);
## `call_locked` is the one authoritative engaged flag every call, dialogue
## tree and panel already sets. The gate stays armed until unprotected,
## then emits exactly once per arming.
func _arm_dream_request() -> void:
	_dream_request_sent = false
	set_process(true)


func _process(_delta: float) -> void:
	if _dream_request_sent or not bool(_state().get("dream_pending", false)):
		set_process(false)
		return
	# A persistent shell can remove a waking world between frames. Its
	# WorkOrders owner may already be gone even though this coordinator's
	# teardown is still queued.
	if work_orders == null or not is_instance_valid(work_orders) \
			or work_orders.job_library == null:
		set_process(false)
		return
	if _protected():
		return
	_dream_request_sent = true
	set_process(false)
	dream_requested.emit(_case_id(), _dream_profile_id(),
			work_orders.job_library.job(JOB_ID).get("dream_window", {}))


func _protected() -> bool:
	return player != null and bool(player.get("call_locked"))


## The wake boundary, called by DreamDirector after waking Orison is rebuilt
## (the direct-building K6 harness uses a stub). Moves
## the player to the authored bedside anchor and flips orchestration facts;
## repair, consumption, evidence, conversation and closure are other
## owners' committed work and are not touched.
func notify_wake_complete() -> bool:
	var state := _state()
	if not bool(state.get("dream_pending", false)):
		return false
	state.dream_pending = false
	state.boundary = "wake_complete"
	RealityState.commit()
	_dream_request_sent = false
	set_process(false)
	var anchor := resolve_return_anchor()
	if player != null and not anchor.is_empty():
		player.global_position = anchor.position
		if "velocity" in player:
			player.velocity = Vector3.ZERO
	wake_completed.emit(str(state.safe_return_anchor))
	return true


## The safe return anchor is the authored 4B bed: the unique `bed`
## furniture record plus its floor's authored elevation. Runtime selects
## the bedside standing spot from that record; nothing is invented.
func resolve_return_anchor() -> Dictionary:
	for floor in layout.get("floors", []):
		if str(floor.get("id", "")) != "F04":
			continue
		for record in floor.get("furniture", []):
			if str(record.get("id", "")) != "bed":
				continue
			var rect: Array = record.rect
			var floor_z := float(floor.get("z", 0.0))
			return {"id": RETURN_ANCHOR_ID, "position": GameBoot.b2g([
					float(rect[2]) + 0.45,
					(float(rect[1]) + float(rect[3])) * 0.5,
					floor_z + 0.15])}
	push_warning("safe return anchor furniture missing: bed/F04")
	return {}


## Self-healing accessor: a fresh campaign (including a mid-session reset)
## leaves an empty record, and a restored save must keep its own values, so
## defaults are merged without overwriting on every access.
func _state() -> Dictionary:
	if not RealityState.data.has("core_loop") \
			or RealityState.data.core_loop is not Dictionary:
		RealityState.data.core_loop = {}
	var state: Dictionary = RealityState.data.core_loop
	state.merge({
		"active_job_id": "",
		"boundary": "idle",
		"conversation_requested": false,
		"conversation_complete": false,
		"dream_pending": false,
		"safe_return_anchor": RETURN_ANCHOR_ID,
	})
	return state
