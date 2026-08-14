class_name WorkOrders
extends Node
## The maintenance spine, and the sole authority for work lifecycle state.
##
## Two contracts live here, one owner:
##
## - **Simple orders** (`issue`/`activate`/`close`): the original minimal
##   contract, kept for code-issued customers with no diagnosis, part or
##   repair — the chirp hunt and the 4B clock. Unchanged.
## - **Maintenance jobs** (`issue_job` …): the ruled M1 lifecycle for jobs
##   authored in `data/maintenance_jobs.json` —
##   issued → acknowledged → diagnosed → awaiting_part → repairable →
##   repaired → closed. Reported and discovered origins converge on the
##   same stage machine at acknowledgement; illegal skips and reversals are
##   rejected without mutation.
##
## The objective tracker only presents state; job objective text is
## reconstructed from the data library per stage and never persisted. Case
## modules must not grow private "work-order-like" booleans around this.

signal order_issued(order_id: String, order: Dictionary)
signal order_activated(order_id: String, order: Dictionary)
signal order_closed(order_id: String, order: Dictionary)
## Fires for every job transition, including issue (from_stage == "").
signal job_issued(job_id: String, state: Dictionary)
signal job_stage_changed(job_id: String, from_stage: String,
		to_stage: String, state: Dictionary)

var tracker: ObjectiveTracker
var job_library: MaintenanceJobLibrary


func setup(objective_tracker: ObjectiveTracker) -> void:
	tracker = objective_tracker
	if not RealityState.data.has("work_orders"):
		RealityState.data.work_orders = {}
	if not RealityState.data.has("maintenance_jobs"):
		RealityState.data.maintenance_jobs = {}


func bind_job_library(library: MaintenanceJobLibrary) -> void:
	job_library = library


func issue(order_id: String, title: String, objective: String,
		source := "building") -> bool:
	var orders: Dictionary = RealityState.data.get("work_orders", {})
	if orders.has(order_id):
		return false
	orders[order_id] = {
		"title": title, "objective": objective, "source": source,
		"status": "issued", "issued_at": Time.get_unix_time_from_system(),
	}
	RealityState.data.work_orders = orders
	RealityState.commit()
	order_issued.emit(order_id, orders[order_id].duplicate(true))
	return true


func activate(order_id: String) -> bool:
	var order := _order(order_id)
	if order.is_empty() or str(order.get("status", "")) == "closed":
		return false
	order.status = "active"
	RealityState.commit()
	_show(order)
	order_activated.emit(order_id, order.duplicate(true))
	return true


func close(order_id: String, closing_note := "WORK ORDER CLOSED") -> bool:
	var order := _order(order_id)
	if order.is_empty() or str(order.get("status", "")) == "closed":
		return false
	order.status = "closed"
	order.closed_at = Time.get_unix_time_from_system()
	RealityState.commit()
	if tracker:
		tracker.show_objective(str(order.title), closing_note)
	order_closed.emit(order_id, order.duplicate(true))
	return true


func status(order_id: String) -> String:
	return str(_order(order_id).get("status", "missing"))


func is_active(order_id: String) -> bool:
	return status(order_id) == "active"


func _order(order_id: String) -> Dictionary:
	var orders: Dictionary = RealityState.data.get("work_orders", {})
	return orders.get(order_id, {})


func _show(order: Dictionary) -> void:
	if tracker:
		tracker.show_objective(str(order.title), str(order.objective))


## --- Maintenance jobs: the ruled M1 lifecycle -------------------------------


func issue_job(job_id: String, origin: String) -> bool:
	if job_library == null or not job_library.has_job(job_id):
		return false
	if origin not in MaintenanceJobLibrary.ORIGINS \
			or not job_library.job(job_id).get("origins", {}).has(origin):
		return false
	var jobs := _jobs()
	if jobs.has(job_id):
		return false
	jobs[job_id] = {
		"stage": "issued", "origin": origin, "evidence": [],
		"repair_result": {},
		"issued_at": Time.get_unix_time_from_system(),
	}
	RealityState.commit()
	_present_job(job_id)
	var copy: Dictionary = jobs[job_id].duplicate(true)
	job_issued.emit(job_id, copy)
	job_stage_changed.emit(job_id, "", "issued", copy)
	return true


func acknowledge_job(job_id: String) -> bool:
	# Both origins converge here: after acknowledgement the recorded origin
	# is history, not a branch.
	return _advance_job(job_id, ["issued"], "acknowledged")


func diagnose_job(job_id: String) -> bool:
	return _advance_job(job_id, ["acknowledged"], "diagnosed")


func mark_job_awaiting_part(job_id: String) -> bool:
	if job_library == null or not job_library.requires_part(job_id):
		return false
	return _advance_job(job_id, ["diagnosed"], "awaiting_part")


func mark_job_repairable(job_id: String) -> bool:
	# A job with no required part skips procurement legally; one with a part
	# must pass through awaiting_part. The data decides, not the caller.
	if job_library == null:
		return false
	var from: Array = ["awaiting_part"] \
			if job_library.requires_part(job_id) else ["diagnosed"]
	return _advance_job(job_id, from, "repairable")


func record_job_repair(job_id: String, result: Dictionary) -> bool:
	var state := _job(job_id)
	if state.is_empty() or str(state.stage) != "repairable":
		return false
	if str(result.get("quality", "")) not in MaintenanceJobLibrary.REPAIR_QUALITIES:
		return false
	if result.get("note", "") is not String:
		return false
	state.repair_result = {"quality": str(result.quality),
			"note": str(result.get("note", ""))}
	return _advance_job(job_id, ["repairable"], "repaired")


func close_job(job_id: String) -> bool:
	return _advance_job(job_id, ["repaired"], "closed")


func record_job_evidence(job_id: String, flag: String) -> bool:
	var state := _job(job_id)
	if state.is_empty() or str(state.stage) == "closed":
		return false
	if job_library == null or not job_library.declares_evidence(job_id, flag):
		return false
	if flag in state.evidence:
		return false
	state.evidence.append(flag)
	RealityState.commit()
	return true


func job_stage(job_id: String) -> String:
	return str(_job(job_id).get("stage", "missing"))


## Open jobs currently blocked on this part. The shop service reads this to
## gate its transaction; nothing here knows what a shop is.
func jobs_awaiting_part(item_id: String) -> Array[String]:
	var waiting: Array[String] = []
	if job_library == null or item_id.is_empty():
		return waiting
	for job_id in _jobs():
		if job_stage(str(job_id)) == "awaiting_part" and str(job_library.job(
				str(job_id)).get("required_item_id", "")) == item_id:
			waiting.append(str(job_id))
	waiting.sort()
	return waiting


func job_state(job_id: String) -> Dictionary:
	return _job(job_id).duplicate(true)


## Install a job record migrated from an older save shape. Migration only:
## it refuses to overwrite an existing record, and the record is validated
## like a restore. The caller owns the mapping; this owns the legality.
func adopt_job(job_id: String, origin: String, stage: String,
		evidence: Array) -> bool:
	if _jobs().has(job_id):
		return false
	var record := {
		"stage": stage, "origin": origin, "evidence": evidence.duplicate(),
		"repair_result": {},
		"issued_at": Time.get_unix_time_from_system(),
		"migrated_from": "legacy_order",
	}
	if not _valid_job_record(job_id, record):
		return false
	_jobs()[job_id] = record
	RealityState.commit()
	_present_job(job_id)
	var copy: Dictionary = record.duplicate(true)
	job_issued.emit(job_id, copy)
	job_stage_changed.emit(job_id, "", stage, copy)
	return true


## Delete a legacy simple order whose fault has been adopted by the
## data-authored lifecycle. Migration cleanup only.
func retire_order(order_id: String) -> bool:
	var orders: Dictionary = RealityState.data.get("work_orders", {})
	if not orders.has(order_id):
		return false
	orders.erase(order_id)
	RealityState.commit()
	return true


## Authoritative facts only, as pure data for the K4 persistence wiring.
## Objective text and any other presentation is deliberately absent: it is
## reconstructed from the job library on restore.
func serialize_jobs() -> Dictionary:
	return {"jobs": _jobs().duplicate(true)}


func restore_jobs(payload: Dictionary) -> bool:
	var incoming: Variant = payload.get("jobs")
	if incoming is not Dictionary or job_library == null:
		return false
	for job_id in incoming:
		if not _valid_job_record(str(job_id), incoming[job_id]):
			return false
	RealityState.data.maintenance_jobs = (incoming as Dictionary).duplicate(true)
	RealityState.commit()
	for job_id in _jobs():
		if job_stage(str(job_id)) != "closed":
			_present_job(str(job_id))
	return true


func _valid_job_record(job_id: String, record: Variant) -> bool:
	if record is not Dictionary or not job_library.has_job(job_id):
		return false
	var state := record as Dictionary
	if str(state.get("stage", "")) not in MaintenanceJobLibrary.STAGES:
		return false
	if str(state.get("origin", "")) not in MaintenanceJobLibrary.ORIGINS:
		return false
	if state.get("evidence") is not Array:
		return false
	for flag in state.evidence:
		if not job_library.declares_evidence(job_id, str(flag)):
			return false
	return state.get("repair_result") is Dictionary


func _advance_job(job_id: String, from_stages: Array, to_stage: String) -> bool:
	var state := _job(job_id)
	if state.is_empty() or str(state.stage) not in from_stages:
		return false
	var from := str(state.stage)
	state.stage = to_stage
	RealityState.commit()
	_present_job(job_id)
	job_stage_changed.emit(job_id, from, to_stage, state.duplicate(true))
	return true


func _present_job(job_id: String) -> void:
	if tracker == null or job_library == null:
		return
	var definition := job_library.job(job_id)
	tracker.show_objective(str(definition.get("title", job_id)),
			job_library.stage_objective(job_id, job_stage(job_id)))


func _job(job_id: String) -> Dictionary:
	return _jobs().get(job_id, {})


func _jobs() -> Dictionary:
	if not RealityState.data.has("maintenance_jobs"):
		RealityState.data.maintenance_jobs = {}
	return RealityState.data.maintenance_jobs
