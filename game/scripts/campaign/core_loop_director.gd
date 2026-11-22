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
var return_anchor_resolver: Callable
## Transient session guard so one arming emits one dream request; a restore
## resets it, which is exactly the resume-once contract.
var _dream_request_sent := false
## The release print this session already asked for, so one queue head emits
## one request. Transient for the same resume-once reason as above.
var _release_request_sent := ""


func setup(spine: WorkOrders, the_player: Node3D,
		building_layout: Dictionary, anchor_resolver := Callable()) -> void:
	if work_orders != null and is_instance_valid(work_orders) \
			and work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		work_orders.job_stage_changed.disconnect(_on_job_stage_changed)
	work_orders = spine
	player = the_player
	layout = building_layout
	return_anchor_resolver = anchor_resolver
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
	if not (_state().release_dreams as Array).is_empty():
		set_process(true)


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


## Read-only authored identity for developer tooling. The debug panel may ask
## to preview the dream without manufacturing Mina's completed shift, but the
## case/profile/window still come from the same job record as production.
func authored_dream_request() -> Dictionary:
	if work_orders == null or work_orders.job_library == null:
		return {}
	var definition := work_orders.job_library.job(JOB_ID)
	var case_id := str(definition.get("case_id", ""))
	var profile_id := str(definition.get("dream_profile_id", ""))
	var window: Variant = definition.get("dream_window", {})
	if case_id.is_empty() or profile_id.is_empty() or window is not Dictionary:
		return {}
	return {
		"case_id": case_id,
		"profile_id": profile_id,
		"window": (window as Dictionary).duplicate(true),
	}


## The campaign shell keeps this coordinator while replacing the world. Drop
## only scene-owned references and their signal; committed loop facts remain.
func detach_world() -> void:
	if work_orders != null and is_instance_valid(work_orders) \
			and work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		work_orders.job_stage_changed.disconnect(_on_job_stage_changed)
	work_orders = null
	player = null
	layout = {}
	return_anchor_resolver = Callable()
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
##
## The opening-shift station may call the same seam once it can physically
## present job 001. Keeping the offer here means neither the clock nor report
## rack manufactures WorkOrders state, and it remains safe on restore.
func offer_opening_report() -> bool:
	if work_orders == null or work_orders.job_stage(JOB_ID) != "missing":
		return false
	return work_orders.issue_job(JOB_ID, "reported")


func _on_resident_interaction(case_id: String, resident_id: String) -> void:
	if case_id != _case_id() or resident_id != _resident_id():
		return
	offer_opening_report()


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
	# Mina's print is also her attachment's release dream. Whichever path
	# reaches it first plays it; the other never arms it again.
	var profile := _dream_profile_id()
	if profile in (state.release_dreams_done as Array):
		state.boundary = "wake_complete"
		RealityState.commit()
		wake_completed.emit(str(state.safe_return_anchor))
		return
	if _drop_queued_release(profile):
		(state.release_dreams_done as Array).append(profile)
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
		_process_release_dream()
		return
	# A persistent shell can remove a waking world between frames. Its
	# WorkOrders owner may already be gone even though this coordinator's
	# teardown is still queued.
	if work_orders == null or not is_instance_valid(work_orders) \
			or work_orders.job_library == null:
		set_process(false)
		return
	if _protected() or not first_deduction_made():
		return
	# Another dream (a release print) is in flight: wait for it to end rather
	# than send a request DreamDirector must refuse. A restore that already
	# armed this job's own print needs no second request.
	var dream := _dream_state()
	if str(dream.get("phase", "awake")) != "awake":
		if str(dream.get("profile_id", "")) == _dream_profile_id():
			_dream_request_sent = true
			set_process(false)
		return
	_dream_request_sent = true
	set_process(false)
	dream_requested.emit(_case_id(), _dream_profile_id(),
			work_orders.job_library.job(JOB_ID).get("dream_window", {}))


## Adela's attachments (design/ORISON_ADELA_ATTACHMENTS_2026-11-22.md). The
## paper decides when an attachment is let go; this coordinator only queues
## that resident's release print and arms one at a time, after Mina's job
## dream, when no call or conversation protects the player and no other dream
## is in flight. A second release waits for the next night. The slot is the
## release order (ruling attach_dream_order_20261122), so the sixth print
## dreamed is the hardest, whichever resident it belongs to.
func request_release_dream(profile_id: String) -> bool:
	var incarnation := profile_id.trim_suffix("_release_print")
	if incarnation == profile_id or not DreamIncarnationProfile.CASE_IDS.has(incarnation):
		return false
	var state := _state()
	if profile_id in (state.release_dreams_done as Array) or is_release_dream(profile_id):
		return false
	# Mina's chirp job plays the same print; never arm it twice.
	if profile_id == _dream_profile_id() \
			and (bool(state.dream_pending) or str(state.boundary) == "wake_complete"):
		(state.release_dreams_done as Array).append(profile_id)
		RealityState.commit()
		return false
	(state.release_dreams as Array).append({
		"case_id": str(DreamIncarnationProfile.CASE_IDS[incarnation]),
		"profile_id": profile_id})
	RealityState.commit()
	set_process(true)
	return true


## True while the print is queued or armed as a release dream.
func is_release_dream(profile_id: String) -> bool:
	return (_state().release_dreams as Array).any(func(row: Variant) -> bool:
		return row is Dictionary and str((row as Dictionary).get("profile_id", "")) == profile_id)


func release_dream_done(profile_id: String) -> bool:
	return profile_id in (_state().release_dreams_done as Array)


## The window a release print carries: the same protected contexts as the
## job's dream, and the campaign slot by release order.
func release_window() -> Dictionary:
	return {"protected_contexts": ["call", "conversation"], "release": true,
			"campaign_slot": mini((_state().release_dreams_done as Array).size() + 1, 6)}


func _process_release_dream() -> void:
	var queue: Array = _state().release_dreams
	if queue.is_empty() or queue[0] is not Dictionary:
		set_process(false)
		return
	var head: Dictionary = queue[0]
	var profile := str(head.get("profile_id", ""))
	if _release_request_sent == profile:
		set_process(false)
		return
	if _protected() or not first_deduction_made():
		return
	var dream := _dream_state()
	if str(dream.get("phase", "awake")) != "awake":
		if str(dream.get("profile_id", "")) == profile:
			_release_request_sent = profile
			set_process(false)
		return
	_release_request_sent = profile
	set_process(false)
	dream_requested.emit(str(head.get("case_id", "")), profile, release_window())


## The wake boundary for a release print. Records the print as dreamed, moves
## the player to the 4B bedside like the job's wake, and lets the next queued
## release arm for the next night. Mina's loop boundary is not touched.
func notify_release_wake(profile_id: String) -> bool:
	if not _drop_queued_release(profile_id):
		return false
	var state := _state()
	if profile_id not in (state.release_dreams_done as Array):
		(state.release_dreams_done as Array).append(profile_id)
	RealityState.commit()
	_release_request_sent = ""
	return_player_to_safe_anchor()
	set_process(true)
	return true


func _drop_queued_release(profile_id: String) -> bool:
	var queue: Array = _state().release_dreams
	for at in queue.size():
		if queue[at] is Dictionary and str((queue[at] as Dictionary).get("profile_id", "")) == profile_id:
			queue.remove_at(at)
			return true
	return false


func _dream_state() -> Dictionary:
	var dream: Variant = RealityState.data.get("dream")
	return dream if dream is Dictionary else {}


## Bible IX, amended 2026-11-22: the campaign first shows the dream after the
## first deduction, not at the end of the first shift. A request that is ready
## earlier (the job's print, or a release print) stays pending until the case
## wall in 4B has written out its first deduction.
func first_deduction_made() -> bool:
	var temporal: Variant = RealityState.data.get("temporal")
	return temporal is Dictionary and (temporal as Dictionary).get("deductions") is Array 			and not ((temporal as Dictionary).deductions as Array).is_empty()


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
	return_player_to_safe_anchor()
	wake_completed.emit(str(state.safe_return_anchor))
	return true


## Movement half of the wake boundary, separated so the debug dream preview
## can rebuild at the same authored bedside without claiming that the golden
## loop advanced or emitting its campaign-only wake signal.
func return_player_to_safe_anchor() -> bool:
	var anchor := resolve_return_anchor()
	if player == null or not is_instance_valid(player) or anchor.is_empty():
		return false
	player.global_position = anchor.position
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	var facing: Variant = anchor.get("facing_position")
	if facing is Vector3 and facing.is_finite() and player.has_method("face_world_point"):
		player.call("face_world_point", facing)
	return true


## The safe return anchor is the authored 4B bed: the unique `bed`
## furniture record plus its floor's authored elevation. Runtime selects
## the bedside standing spot from that record; nothing is invented.
func resolve_return_anchor() -> Dictionary:
	if return_anchor_resolver.is_valid():
		var explicit: Variant = return_anchor_resolver.call(RETURN_ANCHOR_ID)
		if explicit is Dictionary and not explicit.is_empty():
			return explicit
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
		"release_dreams": [],
		"release_dreams_done": [],
	})
	if state.release_dreams is not Array:
		state.release_dreams = []
	if state.release_dreams_done is not Array:
		state.release_dreams_done = []
	return state
