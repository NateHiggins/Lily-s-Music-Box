class_name FirstShiftDirector
extends Node
## Owns the one-time handoff from the authored arrival to normal case play.
## It deliberately delegates the camera and sound work to VirusSoundDirector;
## campaign state, startup policy, and the first actionable objective live here.

signal ritual_changed(phase: String, state: Dictionary)

const PHASE_ARRIVED := "arrived"
const PHASE_CLOCKED_IN := "clocked_in"
const PHASE_REPORT_ACCEPTED := "report_accepted"
const PHASE_RETURNED := "returned"
const PHASE_FILED := "filed"
const PHASE_COMPLETE := "complete"
const FILING_OUTCOMES: Array[String] = [
	"fault_corrected",
	"disturbance_persists",
	"no_fault_found",
	"access_unsuccessful",
]

var building: Node3D
var tracker: ObjectiveTracker
var intro: VirusSoundDirector
var work_orders: WorkOrders

## The shift begins on the south walk, just outside the passenger side of the
## eastbound car. Looking across the road teaches the complete 30 ft crossing
## before a word of UI does. Plan coordinates are converted here so exterior
## staging has one authority.
const ARRIVAL_POSITION_B := Vector3(-3.60, -24.72, 0.10)
const ARRIVAL_LOOK_TARGET_B := Vector3(0.0, -9.82, 2.15)


func setup(root: Node3D, objective_tracker: ObjectiveTracker,
		intro_director: VirusSoundDirector,
		order_spine: WorkOrders = null) -> void:
	building = root
	tracker = objective_tracker
	intro = intro_director
	work_orders = order_spine


func _ready() -> void:
	if intro:
		intro.intro_finished.connect(_on_intro_finished)
	call_deferred("_begin_if_needed")


func _begin_if_needed() -> void:
	if bool(RealityState.data.get("intro_complete", false)):
		_place_at_arrival()
		present_resume()
		return
	if get_tree().current_scene != building:
		return
	# Ruled 2026-08-04: no seized-camera arrival. A new game starts on the
	# south kerb facing the building, player in control from the first
	# frame. The authored thirty-second flyover survives behind
	# VirusSoundDirector.toggle_intro for scenario use.
	begin_first_shift()


## Public for a deterministic harness as well as the production deferred boot.
## `intro_complete` is the one-shot fact: loading an existing campaign can
## restore the curb spawn, but it can never manufacture the car again.
func begin_first_shift() -> bool:
	if bool(RealityState.data.get("intro_complete", false)):
		return false
	_place_at_arrival()
	if building and building.street_traffic:
		building.street_traffic.begin_arrival()
	RealityState.data.intro_complete = true
	RealityState.commit()
	if tracker:
		tracker.show_objective("FIRST SHIFT — ORISON APARTMENTS",
				"Report to the watchman's station. Seat the paper, take one " +
				"report, and sign out only the keys you need.")
	_emit_ritual()
	return true


## The ritual is deliberately thinner than the systems it joins. It records
## what the player physically did at the desk, never a copy of a job or case.
func ritual_state() -> Dictionary:
	return _ritual().duplicate(true)


func ritual_phase() -> String:
	return str(_ritual().get("phase", PHASE_ARRIVED))


## Reconstruct presentation from owners after load. No lifecycle method is
## called here: a resume may explain where the player was, never move them.
func present_resume() -> void:
	match ritual_phase():
		PHASE_ARRIVED:
			_show("FIRST SHIFT — ORISON APARTMENTS",
					"Report to the watchman's station. Seat the paper, take one " +
					"report, and sign out only the keys you need.")
		PHASE_CLOCKED_IN:
			_show("NIGHT REGISTER",
					"Read the waiting reports. Take one; the clock records the shift, not the case.")
		PHASE_REPORT_ACCEPTED:
			_present_active_report()
		PHASE_RETURNED:
			_show("NIGHT REGISTER",
					"Return the keys. File what happened—not what you think happened.")
		PHASE_FILED:
			_show("NIGHT REGISTER", "Remove the detector dial and clock out.")


func _present_active_report() -> void:
	if work_orders == null or work_orders.job_library == null:
		return
	var job_id := str(_ritual().get("report_id", ""))
	var spec: Dictionary = work_orders.job_library.job(job_id)
	var stage := work_orders.job_stage(job_id)
	if spec.is_empty() or stage == "missing":
		return
	_show(str(spec.get("title", "NIGHT REGISTER")),
			work_orders.job_library.stage_objective(job_id, stage))


func clock_in() -> bool:
	if not bool(RealityState.data.get("intro_complete", false)) \
			or ritual_phase() != PHASE_ARRIVED:
		return false
	var state := _ritual()
	state.phase = PHASE_CLOCKED_IN
	_commit_ritual()
	_show("NIGHT REGISTER", "Read the waiting reports. Take one; the clock records the shift, not the case.")
	return true


## Accepting the paper is the sole onboarding seam between the physical desk
## and the two existing authorities. The job must already exist as issued work.
func accept_report(job_id: String) -> bool:
	if ritual_phase() != PHASE_CLOCKED_IN or work_orders == null \
			or work_orders.job_stage(job_id) not in ["issued", "acknowledged"]:
		return false
	var spec: Dictionary = work_orders.job_library.job(job_id) \
			if work_orders.job_library != null else {}
	if spec.is_empty():
		return false
	if work_orders.job_stage(job_id) == "issued" \
			and not work_orders.acknowledge_job(job_id):
		return false
	var case_id := str(spec.get("case_id", ""))
	if not case_id.is_empty():
		var case_state := RealityState.case_state(case_id)
		if case_state.is_empty() or str(case_state.get("stage", "unseen")) == "unseen":
			RealityCases.activate_case(case_id)
	var state := _ritual()
	state.phase = PHASE_REPORT_ACCEPTED
	state.report_id = job_id
	_commit_ritual()
	return true


func return_to_station() -> bool:
	if ritual_phase() != PHASE_REPORT_ACCEPTED or work_orders == null:
		return false
	var job_id := str(_ritual().get("report_id", ""))
	if work_orders.job_stage(job_id) not in ["repaired", "closed"]:
		return false
	_ritual().phase = PHASE_RETURNED
	_commit_ritual()
	_show("NIGHT REGISTER", "Return the keys. File what happened—not what you think happened.")
	return true


func file_outcome(outcome: String) -> bool:
	if ritual_phase() != PHASE_RETURNED or outcome not in FILING_OUTCOMES:
		return false
	var state := _ritual()
	state.phase = PHASE_FILED
	state.filing = outcome
	_commit_ritual()
	_show("NIGHT REGISTER", "Remove the detector dial and clock out.")
	return true


## The physical register publishes a receipt, not a command. Validate every
## fact before moving the ritual so an incomplete, stale or invented line is
## inert. SR7-H supplies `filing`; older register lines intentionally do not.
func accept_signed_register(record: Dictionary) -> bool:
	if ritual_phase() != PHASE_REPORT_ACCEPTED:
		return false
	var filing := str(record.get("filing", ""))
	if filing not in FILING_OUTCOMES \
			or str(record.get("job_id", "")) != str(_ritual().get("report_id", "")) \
			or bool(record.get("report_out", true)) \
			or not (record.get("keys_out", []) as Array).is_empty():
		return false
	if not return_to_station():
		return false
	return file_outcome(filing)


func clock_out() -> bool:
	if ritual_phase() != PHASE_FILED:
		return false
	_ritual().phase = PHASE_COMPLETE
	_commit_ritual()
	return true


func _ritual() -> Dictionary:
	if not RealityState.data.has("first_shift") \
			or RealityState.data.first_shift is not Dictionary:
		RealityState.data.first_shift = {}
	var state: Dictionary = RealityState.data.first_shift
	if not state.has("phase"):
		state.phase = PHASE_ARRIVED
	return state


func _commit_ritual() -> void:
	RealityState.commit()
	_emit_ritual()


func _emit_ritual() -> void:
	ritual_changed.emit(ritual_phase(), ritual_state())


func _show(title: String, text: String) -> void:
	if tracker:
		tracker.show_objective(title, text)


func _on_intro_finished() -> void:
	if bool(RealityState.data.get("intro_complete", false)):
		return
	begin_first_shift()


func _place_at_arrival() -> void:
	if building == null or building.player == null:
		return
	var player: PlayerController = building.player
	player.global_position = GameBoot.b2g([
		ARRIVAL_POSITION_B.x, ARRIVAL_POSITION_B.y, ARRIVAL_POSITION_B.z])
	player.velocity = Vector3.ZERO
	player.noclip = false
	player.call_locked = false
	player.collision_layer = 1
	player.collision_mask = 1
	player.camera.position = Vector3(0, PlayerController.STANDING_EYE, 0)
	player.camera.rotation = Vector3.ZERO
	var target := GameBoot.b2g([
		ARRIVAL_LOOK_TARGET_B.x, ARRIVAL_LOOK_TARGET_B.y,
		ARRIVAL_LOOK_TARGET_B.z])
	var flat_direction := target - player.global_position
	flat_direction.y = 0.0
	player.rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
