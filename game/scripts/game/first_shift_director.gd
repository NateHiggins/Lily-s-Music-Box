class_name FirstShiftDirector
extends Node
## Owns the one-time handoff from the authored arrival to normal case play.
## It deliberately delegates the camera and sound work to VirusSoundDirector;
## campaign state, startup policy, and the first actionable objective live here.

signal ritual_changed(phase: String, state: Dictionary)
signal station_mark_observed(station_id: String, record: Dictionary)

const PHASE_ARRIVED := "arrived"
const PHASE_CLOCKED_IN := "clocked_in"
const PHASE_REPORT_ACCEPTED := "report_accepted"
const PHASE_RETURNED := "returned"
const PHASE_FILED := "filed"
const PHASE_COMPLETE := "complete"
const OPENING_JOB_ID := "vantry_chirp_2a"
const OPENING_STATION_ID := "F02_STATION_2A_LANDING"
const ARRIVAL_INSTRUCTION := \
		"Cross to the Orison lobby. Clock in at the watchman's detector; " \
		+ "tonight's first report is waiting beside it."
const CLOCKED_IN_INSTRUCTION := \
		"At the sloping register, lift the waiting report from its spindle. " \
		+ "The clock records your shift; the paper begins the case."
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
var _opening_report_offer: Callable
var _station_marks: Array[Dictionary] = []
var _tour_key_carried := false

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
				ARRIVAL_INSTRUCTION)
	_emit_ritual()
	return true


## The ritual is deliberately thinner than the systems it joins. It records
## what the player physically did at the desk, never a copy of a job or case.
func ritual_state() -> Dictionary:
	return _ritual().duplicate(true)


func ritual_phase() -> String:
	return str(_ritual().get("phase", PHASE_ARRIVED))


## Injection keeps the clock ignorant of campaign ordering. Production binds
## the campaign coordinator only when the physical register can present its
## job; until then an unbound first shift manufactures nothing.
func bind_opening_report_offer(offer: Callable) -> void:
	_opening_report_offer = offer


## Optional session evidence from SR7-J's network. It is deliberately absent
## from RealityState: the current building has no central tape/register owner,
## and onboarding must not quietly invent one. SR7-K may supply that owner.
func observe_station_mark(station_id: String, record: Dictionary) -> bool:
	if ritual_phase() != PHASE_REPORT_ACCEPTED \
			or station_id != str(record.get("station_id", "")):
		return false
	var sequence := int(record.get("sequence", -1))
	for seen in _station_marks:
		if str(seen.get("station_id", "")) == station_id \
				and int(seen.get("sequence", -2)) == sequence:
			return false
	_station_marks.append(record.duplicate(true))
	station_mark_observed.emit(station_id, record.duplicate(true))
	if str(_ritual().get("report_id", "")) == OPENING_JOB_ID:
		_present_active_report()
	return true


## SR7-K's central board is the evidence visible at the watchman's desk. It
## knows number and sequence only; that limitation is preserved here. A local
## drop with an open wire never calls this method and therefore proves nothing
## to the opening station.
func observe_central_signal(station_number: int, sequence: int) -> bool:
	if station_number != 2:
		return false
	return observe_station_mark(OPENING_STATION_ID, {
		"station_id": OPENING_STATION_ID,
		"station_number": station_number,
		"sequence": sequence,
		"delivered": true,
	})


## Custody is session state owned by the iron hook, not campaign state. First
## shift observes it only to teach the physical handoff and to prevent a
## clock-out that leaves the building's tour key in the player's pocket.
func observe_tour_key_taken(_check_number: int) -> void:
	_tour_key_carried = true
	if ritual_phase() == PHASE_REPORT_ACCEPTED:
		_present_active_report()


func observe_tour_key_returned() -> void:
	_tour_key_carried = false
	if ritual_phase() == PHASE_REPORT_ACCEPTED:
		_present_active_report()
	elif ritual_phase() == PHASE_FILED:
		_show("NIGHT REGISTER", "Remove the detector dial and clock out.")


func tour_key_carried() -> bool:
	return _tour_key_carried


func station_marks() -> Array[Dictionary]:
	return _station_marks.duplicate(true)


func has_station_mark(station_id: String) -> bool:
	for record in _station_marks:
		if str(record.get("station_id", "")) == station_id:
			return true
	return false


## Reconstruct presentation from owners after load. No lifecycle method is
## called here: a resume may explain where the player was, never move them.
func present_resume() -> void:
	match ritual_phase():
		PHASE_ARRIVED:
			_show("FIRST SHIFT — ORISON APARTMENTS",
					ARRIVAL_INSTRUCTION)
		PHASE_CLOCKED_IN:
			_show("NIGHT REGISTER", CLOCKED_IN_INSTRUCTION)
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
	var objective := work_orders.job_library.stage_objective(job_id, stage)
	if job_id == OPENING_JOB_ID and not has_station_mark(OPENING_STATION_ID):
		objective = _first_step(spec) + objective + _round_texture()
	_show(str(spec.get("title", "NIGHT REGISTER")), objective)


## K2-C: ONE IMMEDIATE VERB, AHEAD OF THE JOB'S OWN WORDS.
##
## MEASURED AT THE ACCEPTANCE POSE, b(4.84, -2.27, 1.62), facing the spindle the
## paper just came off. NOT ONE THING THIS CARD NAMED WAS IN THE FRAME: the
## tour key sits at yaw -60.9 degrees, the detector at +62.5, and STATION 2 at
## -175.3 and a floor up. The stair is at +154.9 and occluded.
##
## And the leading verb asked for a sense the building cannot deliver from
## there. "Follow the chirp" is a fine instruction beside the grille and a poor
## one at the desk: the fault fires on a 50-to-95-second random timer from an
## emitter whose `max_distance` is 16 m, at a point a storey up through a slab
## -- into a lobby where 141 emitters are already running. A player who stands
## still and listens, as instructed, hears the building and not the chirp.
##
## So the card now opens with the one thing a hand can act on in the next few
## seconds: WHERE. The unit and its floor come off the job spec rather than
## being written here, so this is presentation of `WorkOrders`' own fact and
## works for any job, not a second copy of this one.
func _first_step(spec: Dictionary) -> String:
	var unit := str(spec.get("unit", ""))
	if unit.is_empty():
		return ""
	var floor_number := int(unit.substr(0, 1)) if unit.substr(0, 1).is_valid_int() 			else 0
	if floor_number <= 1:
		return "Unit %s, on this floor. " % unit
	var climb := floor_number - 1
	return "Unit %s, %s up. " % [unit,
			"one floor" if climb == 1 else "%d floors" % climb]


## The round's accountability texture, and it is deliberately NOT a step.
##
## The old card made these clauses two and three of three imperatives -- "take
## the TOUR KEY", "work STATION 2" -- which reads as a checklist and, worse,
## reads as a gate. Neither is one: the audit confirms the job reaches
## `acknowledged` and the case reaches `active` with no key carried and no
## station mark, and nothing anywhere gates on either. They are stated here as
## things that EXIST and are on the way, in the indicative rather than the
## imperative, so a player who ignores both is not disobeying an instruction.
func _round_texture() -> String:
	# TOUR KEY and STATION 2 stay shouted. That is this card's existing
	# voice for a named thing, six suites assert on it, and writing them in
	# sentence case broke all six for a reason that had nothing to do with
	# what was being tested.
	var texture := ""
	if not _tour_key_carried:
		texture += " The TOUR KEY hangs by the register; it opens no door, but"
		texture += " a round is signed for."
	texture += " STATION 2 is on the way up if you want the mark — evidence,"
	texture += " never permission."
	return texture


func clock_in() -> bool:
	if not bool(RealityState.data.get("intro_complete", false)) \
			or ritual_phase() != PHASE_ARRIVED:
		return false
	var state := _ritual()
	state.phase = PHASE_CLOCKED_IN
	if _opening_report_offer.is_valid():
		_opening_report_offer.call()
	_commit_ritual()
	_show("NIGHT REGISTER", CLOCKED_IN_INSTRUCTION)
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
	_present_active_report()
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
	if _tour_key_carried:
		_show("NIGHT REGISTER",
				"Hang the TOUR KEY back on its hook. Then remove the detector dial and clock out.")
	else:
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
	if ritual_phase() != PHASE_FILED or _tour_key_carried:
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
