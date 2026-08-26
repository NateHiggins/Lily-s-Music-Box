class_name NightRegisterProp
extends FunctionalProp
## The night register: report spindle, key hooks and the ruled book.
##
## SR7-G, and the first SR7 apparatus that is about ACCOUNTABILITY rather than
## about a machine working or failing.
##
## THE TRUTH THIS TEACHES. A key board tells you what is missing. It never
## tells you where it went.
##
## Two hooks, two keys, one ruled book. The board is scrupulously honest about
## absence — an empty hook with a numbered check hanging in the key's place is
## a fact you can read across the lobby — and completely silent about
## everything else. It cannot say who took the key, whether they went where the
## report sent them, or whether they came back by way of anywhere at all. The
## signed line looks like evidence and is only a receipt.
##
## THE SECOND TRUTH, AND THIS ONE THE BUILDING ITSELF SUPPLIES. The two keys on
## this board do not open the same kind of building.
##
##   * The PLANT key is tagged for the five floor service closets, `F02_DOOR_04`
##     through `F06_DOOR_04`. Those doors ship `"leaf": "locked"` in
##     `building_layout.json` and they are locked right now, at boot, on every
##     residential storey. That key opens something.
##   * The APARTMENT key is tagged for `F02_DOOR_03`, 2B's own entry. That door
##     is NOT locked and never was: `orison_detail_pass.gd` carries
##     `START_LOCKED = false` by the ruling of 2026-08-03, so residents' doors
##     stand closed and unlocked, and what actually opens a flat to you is the
##     case, through `RealityCases.case_changed`.
##
## So the register lists two keys in one column as though they were the same
## permission, and one of them is a formality. Nothing on the board says so.
## The only way to find out is to go and read the doors — which is exactly what
## this apparatus does, read-only, and reports.
##
## OWNERSHIP, AND WHAT THIS PROP REFUSES TO BECOME.
##
##   * It is NOT a second work ledger. `WorkOrders` is the sole authority for
##     work lifecycle state, and this prop only ever PRESENTS what that owner
##     already holds. It calls exactly one mutating method on it,
##     `acknowledge_job`, and only from the `issued` stage — the same public
##     call `ServiceRoundDirector` makes when the player speaks to Lena.
##   * It NEVER issues a job. `ServiceRoundDirector.answer_incoming_call()` is
##     the sole issuing owner for `lena_radiator_round_2b`; if that has not
##     happened the spindle is empty, because there is no report to hold.
##   * It NEVER touches `RealityCases`. No case is activated, advanced or read
##     for permission here.
##   * It NEVER writes a lock. `DoorProp.leaf_state` is owned by the layout and
##     by `orison_detail_pass._unlock_for_case`; this prop reads it and reports.
##   * It adds no quest manager, no patrol, no schedule route, no waypoint
##     chain and no UI surface. Four literal places on a board, touched in any
##     order you like.
##
## ROUTE ORDER IS FREE, and that is a mechanical property rather than a
## promise. The slip, the apartment hook and the plant hook are three
## independent physical objects with no gate between them: room first, plant
## first, either key alone, both at once, or neither.
##
## HISTORICAL BASIS.
##   * R. H. THAYER, assigned to THAYER TELKEE CORP, US 1,749,399, "Key Tag",
##     filed 6 April 1926, granted 4 March 1930. The tag is "adapted to be
##     permanently but detachably secured to a key". Note the dates: in the
##     Orison's 1928 this is a PENDING APPLICATION, so the board is contemporary
##     with the invention of its own tags rather than a period reconstruction.
##     Telkee's numbered-hook-and-numbered-tag key cabinet is the same line of
##     product, continuous to the present day.
##   * THE SPINDLE FILE. Before vertical filing displaced them, paper slips
##     were held on pigeonhole, spike and spindle files — the upright spike
##     that takes a bill or a message through the middle. It is a documented
##     office practice of the period rather than a patent, and it is what a
##     porter's report actually sat on.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: this board, its two checks, the
## numbers stamped on them and the ruled book are authored. The doors it is
## tagged for, their lock states, the 2B report and its lifecycle are not —
## every one of those is production's, read at runtime.
##
## AUTHORING RULE. Local z = 0 is the mounting plane and the apparatus is built
## OUTWARD along +z toward the room.

signal register_signed(record: Dictionary)
signal report_taken(job_id: String)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## SR7-I -- WHICH PAPER IS ON THE SPINDLE.
##
## An AUTHORED ORDER, not a scan. The register presents the first of these
## that the spine is actually holding open, and it can present nothing else.
## Ordering them here rather than sorting a dictionary at runtime means the
## opening report is a decision somebody wrote down, and a third job cannot
## appear on this board by being issued somewhere.
##
## 001 first: Mina's chirp is the report a new watchman takes after clocking
## in. 002 follows only when `ServiceRoundDirector` actually issues it, which
## it gates on 001 being closed -- so the order below agrees with the order
## production already produces, and does not impose one.
const PRESENTABLE_JOBS := ["vantry_chirp_2a", "lena_radiator_round_2b"]
## The stages at which a job is a paper you can hold. `missing` was never
## issued and `closed` is finished; everything between is work in hand, and a
## register that stopped showing a job the moment it was diagnosed would be
## losing the paper halfway through the round.
const PRESENTABLE_STAGES := ["issued", "acknowledged", "diagnosed",
		"awaiting_part", "repairable", "repaired"]
## Where the signed lines live. A small pure-fact record beside
## `mail_taken` and `maintenance_items`, written only when the book is signed.
const STATE_KEY := "night_register"

## The two hooks, and the doors each is tagged for. These ids are read from
## the building at runtime; the prop asserts nothing about their state.
const APARTMENT_HOOK := "apartment"
const PLANT_HOOK := "plant"
const HOOK_DOORS := {
	APARTMENT_HOOK: ["F02_DOOR_03"],
	PLANT_HOOK: ["F02_DOOR_04", "F03_DOOR_04", "F04_DOOR_04", "F05_DOOR_04",
			"F06_DOOR_04"],
}
## The numbers stamped on the two brass checks. A check is what you hang in
## the key's place; the hook is never allowed to be simply empty.
const CHECK_NUMBERS := {APARTMENT_HOOK: 14, PLANT_HOOK: 7}
const HOOK_ORDER := [APARTMENT_HOOK, PLANT_HOOK]

## SR7-H -- THE FOUR CONCLUSIONS, and there are only ever four.
##
## These ids are `FirstShiftDirector.FILING_OUTCOMES` verbatim. SR7-H does NOT
## connect the two owners -- that seam belongs to the first-shift director --
## but a register that spoke a private vocabulary would turn the eventual join
## into a translation table, and a translation table between two owners is
## exactly where a fifth conclusion gets invented.
const OUTCOME_FAULT_CORRECTED := "fault_corrected"
const OUTCOME_DISTURBANCE_PERSISTS := "disturbance_persists"
const OUTCOME_NO_FAULT_FOUND := "no_fault_found"
const OUTCOME_ACCESS_UNSUCCESSFUL := "access_unsuccessful"
## Ordered as the card prints them. Detent 0 of the slide is BLANK, so this
## array is what detents 1..4 select, and nothing else can be selected at all.
const OUTCOMES := [
	OUTCOME_FAULT_CORRECTED,
	OUTCOME_DISTURBANCE_PERSISTS,
	OUTCOME_NO_FAULT_FOUND,
	OUTCOME_ACCESS_UNSUCCESSFUL,
]
## What is PRINTED on the card against each number -- engraved brass on the
## apparatus itself. The impossibility of entering anything else is therefore
## a property of the OBJECT rather than a rule bolted on top of one.
const OUTCOME_CARD := {
	OUTCOME_FAULT_CORRECTED: "1   FAULT CORRECTED",
	OUTCOME_DISTURBANCE_PERSISTS: "2   FAULT CORRECTED, DISTURBANCE PERSISTS",
	OUTCOME_NO_FAULT_FOUND: "3   NO FAULT FOUND",
	OUTCOME_ACCESS_UNSUCCESSFUL: "4   ACCESS UNSUCCESSFUL",
}
## The blank detent is a POSITION, not an absence. A slide resting against a
## printed dash is a fact you can photograph; an unset variable is not.
const CARD_BLANK := "--   NOTHING ENTERED"
## Where the index stands for each detent, along the card's slope. Index 0 is
## the blank; 1..4 are the four conclusions in printed order.
const DETENT_Z := [-0.060, -0.030, 0.000, 0.056, 0.086]

var _work_orders: Node
var _building: Node
## SR7-I. While the board is ENGAGED -- a round open, the paper in hand, a key
## out or a conclusion chosen -- the presented report is pinned to whatever it
## was when the engagement began. Without this the paper could change under a
## player who is halfway up the stairs, which is the one thing a physical
## spindle can never do.
var _latched_job := ""
## What the slip is currently PRINTED with, so the engraving is reset when the
## report changes and not on every refresh.
var _printed_job := ""

var _board: MeshInstance3D
var _shelf: MeshInstance3D
var _spindle: MeshInstance3D
## K2-B: THE PAPER DOES NOT APPEAR, IT ARRIVES.
##
## MEASURED. From the pose a hand clocks in at, this spindle stands 0.69 m away
## at YAW +58.5 DEGREES, against a camera frustum half-angle of +-35.0. The
## report was therefore materialising, silently and instantly, a quarter-turn
## of the head outside the frame. `_refresh_slip_visibility` set
## `_slip.visible = true` and that was the whole of it.
##
## A spike file does not work like that. Paper is dropped onto the spike, the
## sheet slides down the point and the spindle takes the weight and nods. So it
## does that, with the rustle this board already carries an emitter for -- and
## motion at 58 degrees off-axis is exactly what peripheral vision is for. The
## eye is handed the paper by the paper.
const SLIP_LANDING_SECONDS := 0.62
const SLIP_LANDING_RISE := 0.078
const SPINDLE_NOD := 0.22

var _slip: MeshInstance3D
var _stub: MeshInstance3D
var _desk: Node3D
var _card: Node3D
var _slide: Node3D
var _card_labels: Array[Label3D] = []
var _slip_labels: Array[Label3D] = []
var _book: MeshInstance3D
var _page: MeshInstance3D
var _keys: Dictionary = {}
var _checks: Dictionary = {}
var _tags: Dictionary = {}
var _hooks: Dictionary = {}
var _hook_rest: Dictionary = {}
var _clink: AudioStreamPlayer3D
var _paper: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D

var _balk_left := 0.0
## K2-B landing state. Transient presentation; nothing here is ever saved.
var _landing_left := 0.0
var _slip_was_available := false
var _landing_armed := false
var _balk_focus := ""
var _t := 0.0

## The apparatus's own facts. `slip_taken` and `keys_out` are the working
## condition of the board; `signed_lines` is what the book carries. Only
## `sign_register()` moves the last one into RealityState.
var slip_taken := false
var keys_out := {APARTMENT_HOOK: false, PLANT_HOOK: false}
var signed_lines := 0

## SR7-H. The slide's detent, 0..4, where 0 is blank and is where it rests.
## THE PHYSICAL POSITION IS THE SELECTION -- there is no second variable
## holding a chosen outcome, so there is nothing for job state to quietly set,
## and nothing in this prop moves it except a hand.
var index_detent := 0
## A round is open from the moment the report comes off the spindle until it
## is signed for or the session is abandoned. It is the difference between a
## register with something to record and one with nothing.
var round_open := false


func _ready() -> void:
	super()
	_bind_owners()
	# The book shows what the save is actually holding. A board that came up
	# reading zero lines while `RealityState` held four would be a register
	# disagreeing with its own record the moment the game reloaded.
	signed_lines = _stored_lines().size()
	_refresh_board()


## The spine and the building are found by walking up, the way the watchman's
## detector finds the day/night owner: no new binding seam, no registration,
## and a null spine simply means an empty spindle.
func _bind_owners() -> void:
	var node: Node = self
	while node != null:
		if _work_orders == null and node.get("work_orders") != null:
			_work_orders = node.get("work_orders")
			_building = node
		node = node.get_parent()
	if _work_orders != null and _work_orders.has_signal("job_stage_changed") \
			and not _work_orders.job_stage_changed.is_connected(
					_on_job_stage_changed):
		_work_orders.job_stage_changed.connect(_on_job_stage_changed)


func _on_job_stage_changed(job_id: String, _from: String, _to: String,
		_state: Dictionary) -> void:
	# Any presentable job: a stage change on 001 can put 002 on the spindle.
	if job_id in PRESENTABLE_JOBS:
		_refresh_board()


# --- what the spine already holds -------------------------------------------

## The stage `WorkOrders` holds for this job, or "missing". Read-only, and the
## single source of truth for whether a report exists at all.
## The stage the spine holds for a job, or "missing". With no argument, for
## whichever report is on the spindle.
func job_stage(job_id := "") -> String:
	var wanted := job_id if job_id != "" else presented_job_id()
	if _work_orders == null or wanted == "":
		return "missing"
	return str(_work_orders.call("job_stage", wanted))


## SR7-I -- THE SELECTION RULE, and the whole of it.
##
## While engaged, the latched report. Otherwise the first job in the authored
## order that the spine is holding open. Nothing else consults job state to
## decide what is on the spindle, and nothing writes this down: it is derived
## on every read from `WorkOrders`, which is what makes a reload reconstruct
## the same paper without this board persisting a word of it.
func presented_job_id() -> String:
	if _latched_job != "":
		return _latched_job
	return first_open_job()


func first_open_job() -> String:
	if _work_orders == null:
		return ""
	for job_id in PRESENTABLE_JOBS:
		if str(_work_orders.call("job_stage", job_id)) in PRESENTABLE_STAGES:
			return str(job_id)
	return ""


## Engaged: the board is in the middle of something and the paper must not
## change under the player.
func engaged() -> bool:
	return round_open or slip_taken or keys_out_count() > 0 \
			or outcome_selected()


func latched_job() -> String:
	return _latched_job


## The authored record for whichever report is presented.
func _presented_record() -> Dictionary:
	if _work_orders == null or _work_orders.get("job_library") == null:
		return {}
	var job := presented_job_id()
	if job == "":
		return {}
	# `MaintenanceJobLibrary` is a RefCounted, not a Node -- typing this as a
	# Node assigns nothing and silently empties the slip.
	var library: RefCounted = _work_orders.get("job_library")
	return library.call("job", job)


## A slip is on the spindle when the spine holds an open job and nobody has
## taken it. There is no slip for a job that was never issued: this board does
## not invent work.
func slip_available() -> bool:
	return not slip_taken and presented_job_id() != ""


## THE NUMBER PRINTED ON THE PAPER. Split off the authored title, which reads
## "WORK ORDER 001 - THE CHIRP": the register prints the number and the name
## on separate lines and invents neither.
func slip_number() -> String:
	var title := str(_presented_record().get("title", ""))
	if title == "":
		return ""
	var cut := title.find(" \u2014 ")
	return title if cut < 0 else title.substr(0, cut)


func slip_name() -> String:
	var title := str(_presented_record().get("title", ""))
	var cut := title.find(" \u2014 ")
	return "" if cut < 0 else title.substr(cut + 3).strip_edges()


func slip_unit() -> String:
	var unit := str(_presented_record().get("unit", ""))
	return "" if unit == "" else "UNIT " + unit


## The concise symptom: the first sentence of the authored summary, which in
## both existing records is exactly the complaint and nothing else. Reading it
## rather than authoring a second copy here means the paper cannot drift away
## from the job it is a paper for.
func slip_symptom() -> String:
	var summary := str(_presented_record().get("summary", ""))
	if summary == "":
		return ""
	var stop := summary.find(". ")
	return summary if stop < 0 else summary.substr(0, stop + 1)


## What the slip says, reconstructed from the job library per stage exactly as
## the objective tracker does. Never stored, never duplicated.
func slip_text() -> String:
	var record := _presented_record()
	if record.is_empty():
		return ""
	return "%s\n%s" % [str(record.get("title", "")),
			str(record.get("stage_objectives", {}).get(job_stage(), ""))]


# --- what the building already owns -----------------------------------------

## The doors a hook is tagged for.
func tagged_doors(hook: String) -> Array:
	return (HOOK_DOORS.get(hook, []) as Array).duplicate()


## How many of a hook's doors are actually locked, right now, read straight off
## `DoorProp.leaf_state`. THIS PROP NEVER WRITES THAT FIELD. The number is the
## whole second lesson: the plant tag answers 5 and the apartment tag answers
## 0, and nothing on the board itself would have told you.
func locked_count(hook: String) -> int:
	var locked := 0
	for door_id in tagged_doors(hook):
		var door: Node = _find_door(str(door_id))
		if door != null and str(door.get("leaf_state")) == "locked":
			locked += 1
	return locked


func tagged_door_count(hook: String) -> int:
	return tagged_doors(hook).size()


func _find_door(door_id: String) -> Node:
	if _building == null:
		return null
	return _building.find_child(door_id, true, false)


# --- the board's own facts ---------------------------------------------------

func key_out(hook: String) -> bool:
	return bool(keys_out.get(hook, false))


## A hook always reads: either the key hangs on it or the check does. It is
## never simply empty, which is the entire point of a check system.
func hook_reads(hook: String) -> String:
	return "check %d" % int(CHECK_NUMBERS.get(hook, 0)) if key_out(hook) \
			else "key"


func keys_out_count() -> int:
	var out := 0
	for hook in HOOK_ORDER:
		if key_out(str(hook)):
			out += 1
	return out


## Whether anything has happened that the book would have to record.
func has_unsigned_work() -> bool:
	return round_open


# --- SR7-H: the words you sign ----------------------------------------------

## The conclusion the slide is standing on, or "" for the blank detent.
##
## DERIVED, not stored. There is no `selected_outcome` field for job state or
## anything else to set behind the player's back -- the only way to change
## what this returns is to move the slide with a hand, and the only positions
## the slide has are the four the card has printed on it.
func selected_outcome() -> String:
	if index_detent <= 0 or index_detent > OUTCOMES.size():
		return ""
	return str(OUTCOMES[index_detent - 1])


func outcome_selected() -> bool:
	return selected_outcome() != ""


## What the card reads against the slide right now.
func card_line() -> String:
	var outcome := selected_outcome()
	return CARD_BLANK if outcome == "" else str(OUTCOME_CARD[outcome])


## One notch of the slide, wrapping back through blank. This is the whole
## selector: a detented brass index that a hand pushes down a printed column.
##
## It wraps THROUGH blank rather than around it, so every conclusion costs a
## deliberate number of pushes and the blank is never something you skip past
## by accident on your way to a fifth position -- there is no fifth position.
func advance_index() -> bool:
	index_detent = (index_detent + 1) % (OUTCOMES.size() + 1)
	if _clink != null:
		_clink.play()
	_refresh_board()
	return true


## Set the slide directly. Test and tooling surface; the reach uses
## `advance_index`. An id that is not one of the four cannot be set, because
## there is nowhere on the card for the slide to stand.
func select_outcome(outcome: String) -> bool:
	if outcome == "":
		index_detent = 0
		_refresh_board()
		return true
	var at := OUTCOMES.find(outcome)
	if at < 0:
		# There is no detent for it. A conclusion this apparatus cannot print
		# is a conclusion it cannot file.
		_balk(1.2, "index")
		return false
	index_detent = at + 1
	_refresh_board()
	return true


## Everything that has to be true before a line can be written:
##   * a round is actually open,
##   * the report is back on its spindle,
##   * both keys are back on their hooks,
##   * and a conclusion has been deliberately chosen.
func ready_to_file() -> bool:
	return round_open and not slip_taken and keys_out_count() == 0 \
			and outcome_selected()


# --- taking and returning ----------------------------------------------------

## Reversible. Everything below moves the visible board and writes nothing:
## `sign_register()` is the only publication, exactly as
## `apply_maintenance_result` is on every other SR7 apparatus.
func take_slip() -> bool:
	if slip_taken:
		# There is nothing on the spindle to take.
		_balk(1.0, "slip")
		return false
	var job := presented_job_id()
	if job == "" or not slip_available():
		# No report has been made. The board will not manufacture one: the
		# opening report is `CoreLoopDirector.offer_opening_report()`'s to
		# issue and Lena's is `ServiceRoundDirector`'s, and this prop is
		# neither of them.
		_balk(1.2, "slip")
		return false
	slip_taken = true
	# SR7-H: the round is open from here. Nothing else opens one, and nothing
	# closes one but a signature or an abandoned session.
	round_open = true
	if _paper != null:
		_paper.play()
	# SR7-I: the paper is LATCHED to the id read before anything moved. From
	# this instant the presented report cannot change under the player, and
	# every line below acts on that one id rather than re-deriving it.
	_latched_job = job
	# THE ONE MUTATING CALL THIS PROP MAKES ON THE SPINE, and it is the same
	# public call the report's own owner makes. Taking the paper is
	# acknowledging the work; it is not a second ledger, and `_advance_job`
	# refuses it from any stage but `issued` without mutating anything.
	if _work_orders != null and job_stage(job) == "issued":
		_work_orders.call("acknowledge_job", job)
	if job_stage(job) == "acknowledged":
		report_taken.emit(job)
	_refresh_board()
	return true


func replace_slip() -> bool:
	if not slip_taken:
		_balk(1.0, "slip")
		return false
	if keys_out_count() > 0:
		# You do not file the report while you are still holding the
		# building's keys. This constrains no ROUTE -- it says finish, then
		# file -- and it is the one thing a register can honestly enforce.
		_balk(1.4, "slip")
		return false
	slip_taken = false
	if _paper != null:
		_paper.play()
	_refresh_board()
	return true


func take_key(hook: String) -> bool:
	if not keys_out.has(hook):
		return false
	if key_out(hook):
		# The hook is carrying its check, not its key. Somebody has it.
		_balk(1.2, hook)
		return false
	keys_out[hook] = true
	if _clink != null:
		_clink.play()
	_refresh_board()
	return true


func return_key(hook: String) -> bool:
	if not keys_out.has(hook):
		return false
	if not key_out(hook):
		# The key is already on the hook. A second one is somebody's copy, and
		# a board that accepts copies cannot account for anything.
		_balk(1.2, hook)
		return false
	keys_out[hook] = false
	if _clink != null:
		_clink.play()
	_refresh_board()
	return true


# --- the only publication ----------------------------------------------------

## Signing the book. The single writer, the single commit, and the single
## place `RealityState` is touched.
##
## What it records is deliberately thin: the hour, which hooks were empty and
## whether the report was out. It does NOT record where anybody went, because
## the board has no way to know, and writing a richer line would be the
## apparatus telling the same lie it exists to expose.
func sign_register() -> bool:
	if not round_open:
		# An unmarked register. Nothing was taken, so there is nothing to sign
		# for -- and this is also what makes a second signature on one round
		# an idempotent refusal rather than a duplicate line.
		_balk(1.0, "book")
		return false
	if slip_taken:
		# The report is still in your hand. You sign for a round that is over.
		_balk(1.4, "slip")
		return false
	if keys_out_count() > 0:
		# The building's keys are still off the board.
		# `_keys_out_list()` yields Variants; `_balk` takes a String focus, so
		# the hook that is actually missing is named explicitly.
		_balk(1.4, str(_keys_out_list()[0]))
		return false
	if not outcome_selected():
		# THE ONE THIS APPARATUS EXISTS FOR. The slide is standing on the
		# blank. Nothing here will choose a conclusion for you: not the job's
		# stage, not the case, not whether the radiator is warm. You put the
		# words there or there are no words.
		_balk(1.6, "index")
		return false
	var line := {
		"at": Time.get_unix_time_from_system(),
		# THE KEY IS `filing`, and that is not a preference. It is what
		# `FirstShiftDirector.accept_signed_register` reads. The director
		# also requires `report_out` false and `keys_out` empty before it
		# will act on a receipt -- which are, exactly, two of the three
		# conditions this board already refuses to sign without.
		"filing": selected_outcome(),
		"filing_printed": card_line(),
		"report_out": slip_taken,
		"keys_out": _keys_out_list(),
		"job_id": presented_job_id(),
		"job_stage": job_stage(),
	}
	var record: Dictionary = RealityState.data.get(STATE_KEY, {})
	var lines: Array = record.get("lines", [])
	lines.append(line)
	record["lines"] = lines
	RealityState.data[STATE_KEY] = record
	RealityState.commit()
	signed_lines = lines.size()
	# THE ROUND CLOSES HERE AND NOWHERE ELSE. No WorkOrder is closed, no case
	# is advanced: what ends is this board's own session. The slide is left
	# standing where it was put, because a register you have just signed
	# should still be showing what you signed.
	round_open = false
	# SR7-I: AND THE INDEX GOES BACK TO THE BLANK. SR7-H left it standing on
	# what was signed, which reads well for one photograph and is wrong for a
	# board a building shares -- the next watchman would find a conclusion
	# already entered, which is the one thing this selector exists to prevent.
	# It also means a signed round leaves the board genuinely idle, so the
	# next report can come up on the spindle. What was signed is not lost: it
	# is the line in the book and the `filing_printed` in the record.
	index_detent = 0
	if _paper != null:
		_paper.play()
	_balk_left = 0.0
	_refresh_board()
	register_signed.emit(line.duplicate(true))
	return true


func _keys_out_list() -> Array:
	var out: Array = []
	for hook in HOOK_ORDER:
		if key_out(str(hook)):
			out.append(str(hook))
	return out


## The lines the save is currently holding for this board.
func _stored_lines() -> Array:
	return (RealityState.data.get(STATE_KEY, {}) as Dictionary).get("lines", [])


func serialize() -> Dictionary:
	return (RealityState.data.get(STATE_KEY, {}) as Dictionary).duplicate(true)


# --- the abort seam ----------------------------------------------------------

## The same two-method contract `MaintenanceActivityPanel` uses for abort, by
## the same names, so a session that is walked away from puts the keys back on
## their hooks and the slip back on its spindle. Nothing signed, nothing
## written, nothing to undo in RealityState -- because nothing reached it.
func maintenance_snapshot() -> Dictionary:
	return {
		"slip_taken": slip_taken,
		"keys_out": keys_out.duplicate(true),
		"signed_lines": signed_lines,
		"index_detent": index_detent,
		"round_open": round_open,
		"lines": _stored_lines().duplicate(true),
	}


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	slip_taken = bool(snapshot.get("slip_taken", slip_taken))
	var restored: Dictionary = snapshot.get("keys_out", {})
	for hook in HOOK_ORDER:
		if restored.has(hook):
			keys_out[hook] = bool(restored[hook])
	signed_lines = int(snapshot.get("signed_lines", signed_lines))
	# SR7-H. The slide goes back to the detent it was standing on, the round
	# goes back to open or not, and THE WRITTEN LINES GO BACK TOO -- an abort
	# that restored the apparatus but left a signature in the save would be
	# the one irreversible thing on a reversible board.
	index_detent = int(snapshot.get("index_detent", index_detent))
	round_open = bool(snapshot.get("round_open", round_open))
	if snapshot.has("lines"):
		var record: Dictionary = RealityState.data.get(STATE_KEY, {})
		var kept: Array = (snapshot.get("lines", []) as Array).duplicate(true)
		if kept.is_empty():
			record.erase("lines")
			if record.is_empty():
				RealityState.data.erase(STATE_KEY)
			else:
				RealityState.data[STATE_KEY] = record
		else:
			record["lines"] = kept
			RealityState.data[STATE_KEY] = record
		signed_lines = kept.size()
	_balk_left = 0.0
	_refresh_board()


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var oak := Color(0.33, 0.22, 0.14)
	var brass := Color(0.62, 0.50, 0.24)
	var steel := Color(0.44, 0.44, 0.47)
	var paper := Color(0.86, 0.83, 0.74)
	var slate := Color(0.20, 0.20, 0.22)

	# The board itself, and the shelf that carries the book.
	_board = make_box(Vector3(0.62, 0.50, 0.026), Vector3(0.0, 0.25, 0.013),
			oak)
	_board.name = "RegisterBoard"
	for edge_x in [-0.30, 0.30]:
		make_box(Vector3(0.022, 0.50, 0.040), Vector3(edge_x, 0.25, 0.020),
				oak)
	make_box(Vector3(0.62, 0.022, 0.040), Vector3(0.0, 0.489, 0.020), oak)
	# SR7-H WIDENED AND DEEPENED THE WRITING SLOPE, and only the slope: the
	# board face above it is untouched, so the spindle and the hooks keep
	# every coordinate SR7-G measured. A desk wider than the cabinet over it
	# is ordinary furniture, and the conclusion card has to live where the
	# signing happens rather than up on the wall where it would be read once
	# and never looked at again. At 0.72 the shelf spans building y -2.63 to
	# -1.91: 0.23 m clear of the 1D door reveal and 0.23 m clear of the
	# watchman's detector.
	_shelf = make_box(Vector3(0.72, 0.020, 0.240),
			Vector3(0.0, 0.055, 0.120), oak)
	_shelf.name = "RegisterShelf"
	# Two brackets, because a shelf carrying a ledger is carrying real weight.
	for bracket_x in [-0.30, 0.30]:
		var bracket := make_box(Vector3(0.016, 0.070, 0.130),
				Vector3(bracket_x, 0.020, 0.075), oak)
		bracket.name = "ShelfBracket%d" % (0 if bracket_x < 0.0 else 1)

	# THE SPINDLE FILE, left. An upright spike with the report on it: the
	# period way a slip was held, and the reason a taken report leaves a
	# visibly bare spike rather than a gap you have to know about.
	var foot := make_cyl(0.030, 0.034, 0.010, Vector3(-0.185, 0.135, 0.036),
			steel, 0.42, 0.55)
	foot.name = "SpindleFoot"
	_spindle = make_cyl(0.0022, 0.0035, 0.230,
			Vector3(-0.185, 0.255, 0.036), steel, 0.30, 0.70)
	_spindle.name = "ReportSpindle"
	# SR7-I ENLARGED THE PAPER, because a slip that cannot say which report it
	# is has to be identified from a prompt, and a prompt is not an object.
	# 0.18 wide is what the board face allows between its cheeks.
	_slip = make_box(Vector3(0.180, 0.205, 0.0025),
			Vector3(-0.185, 0.250, 0.041), paper)
	_slip.name = "ReportSlip"
	# THE STUB. A slip does not come off a spike cleanly: it tears, and the
	# punched corner stays on the spike. That scrap is the difference between
	# a spindle nobody has filed anything on and a spindle whose report is in
	# somebody's hand -- and it is the ONLY difference, because the board
	# still has no idea whose hand. Without it those two conditions come back
	# as the same photograph, which the first SR7-G sheet demonstrated.
	_stub = make_box(Vector3(0.038, 0.030, 0.0025),
			Vector3(-0.185, 0.176, 0.041), Color(0.80, 0.76, 0.66))
	_stub.name = "ReportStub"
	_stub.rotation.z = -0.22
	_stub.visible = false
	# The printed rule under the work-order number, and the signature rule at
	# the foot. Everything between them is set from the job record itself.
	var head_rule := make_box(Vector3(0.150, 0.0018, 0.0006),
			Vector3(-0.185, 0.303, 0.0425), Color(0.42, 0.36, 0.28))
	head_rule.name = "SlipRule0"
	var foot_rule := make_box(Vector3(0.150, 0.0018, 0.0006),
			Vector3(-0.185, 0.172, 0.0425), Color(0.42, 0.36, 0.28))
	foot_rule.name = "SlipRule1"

	# THE TWO HOOKS, right, with the key on one side of the fact and the
	# numbered check on the other. A hook is never bare.
	var hook_x := {APARTMENT_HOOK: 0.055, PLANT_HOOK: 0.215}
	for hook in HOOK_ORDER:
		var name_id := str(hook)
		var x: float = hook_x[name_id]
		var shank := make_cyl(0.0035, 0.0035, 0.036,
				Vector3(x, 0.400, 0.030), brass, 0.34, 0.72)
		shank.name = "Hook_%s" % name_id
		shank.rotation_degrees.x = 90.0
		var lip := make_cyl(0.0035, 0.0035, 0.020,
				Vector3(x, 0.392, 0.048), brass, 0.34, 0.72)
		lip.name = "HookLip_%s" % name_id
		_hooks[name_id] = shank
		# THE TAG. Stamped brass, and deliberately the same size on both hooks:
		# nothing about the board's own furniture distinguishes a key that
		# opens five locked doors from one that opens a door already open.
		var tag := make_box(Vector3(0.086, 0.030, 0.0035),
				Vector3(x, 0.222, 0.036), brass)
		tag.name = "Tag_%s" % name_id
		_tags[name_id] = tag
		var stamp := make_box(Vector3(0.058, 0.0035, 0.0008),
				Vector3(x, 0.222, 0.039), Color(0.30, 0.24, 0.12))
		stamp.name = "TagStamp_%s" % name_id

	# THE KEYS. Two different objects, because they are two different
	# permissions: a small flat apartment bit key and a long service key with
	# a heavy bow and a big ward.
	var flat_bow := make_cyl(0.014, 0.014, 0.004,
			Vector3(hook_x[APARTMENT_HOOK], 0.352, 0.040), brass, 0.36, 0.70)
	flat_bow.name = "Key_apartment"
	flat_bow.rotation_degrees.x = 90.0
	var flat_shank := make_box(Vector3(0.006, 0.052, 0.004),
			Vector3(hook_x[APARTMENT_HOOK], 0.320, 0.040), brass)
	flat_shank.name = "KeyShank_apartment"
	var flat_bit := make_box(Vector3(0.016, 0.012, 0.004),
			Vector3(hook_x[APARTMENT_HOOK] + 0.008, 0.300, 0.040), brass)
	flat_bit.name = "KeyBit_apartment"
	_keys[APARTMENT_HOOK] = [flat_bow, flat_shank, flat_bit]

	var plant_bow := make_cyl(0.020, 0.020, 0.005,
			Vector3(hook_x[PLANT_HOOK], 0.348, 0.040), steel, 0.40, 0.62)
	plant_bow.name = "Key_plant"
	plant_bow.rotation_degrees.x = 90.0
	var plant_shank := make_box(Vector3(0.009, 0.086, 0.006),
			Vector3(hook_x[PLANT_HOOK], 0.298, 0.040), steel)
	plant_shank.name = "KeyShank_plant"
	var plant_bit := make_box(Vector3(0.026, 0.022, 0.006),
			Vector3(hook_x[PLANT_HOOK] + 0.014, 0.262, 0.040), steel)
	plant_bit.name = "KeyBit_plant"
	_keys[PLANT_HOOK] = [plant_bow, plant_shank, plant_bit]

	# THE CHECKS. What hangs in a key's place. Numbered, round, and obviously
	# not a key from across the room -- which is the whole design requirement
	# of a check.
	for hook in HOOK_ORDER:
		var name_id := str(hook)
		var x: float = hook_x[name_id]
		var check := make_cyl(0.019, 0.019, 0.004,
				Vector3(x, 0.348, 0.040), Color(0.78, 0.67, 0.33), 0.40, 0.55)
		check.name = "Check_%s" % name_id
		check.rotation_degrees.x = 90.0
		check.visible = false
		var digit := make_box(Vector3(0.019, 0.0055, 0.0010),
				Vector3(x, 0.348, 0.0435), Color(0.16, 0.12, 0.05))
		digit.name = "CheckNumber_%s" % name_id
		digit.visible = false
		_checks[name_id] = [check, digit]

	# THE RULED BOOK, on a sloped desk. ONE PIVOT CARRIES THE WHOLE DESK, and
	# that is not tidiness: the book, its open page and every ruled line have
	# to keep one plane, and tilting three separate boxes by the same euler
	# about three different origins does not give you a plane. It gives you a
	# dark slab with a light edge, which is what the first sheet came back
	# with. A register lies flat on its desk or it is not a register.
	_desk = Node3D.new()
	_desk.name = "RegisterDesk"
	# THE SIGN OF THE TILT IS THE WHOLE POINT. Rx(+t) sends the desk's local
	# +z (its front edge) DOWN and toward the room, so the page faces up at
	# the reader. Negative tilts it away and photographs as a black wedge with
	# a white line on it -- which is what the second sheet came back with.
	# Seated so the front edge clears the shelf top at 0.065 and the raised
	# back edge clears the backboard face at 0.026.
	_desk.position = Vector3(0.070, 0.116, 0.106)
	_desk.rotation.x = 0.52
	add_child(_desk)
	_book = make_box(Vector3(0.234, 0.022, 0.152), Vector3.ZERO,
			Color(0.26, 0.17, 0.13))
	_book.name = "RegisterBook"
	_adopt(_book, _desk)
	_page = make_box(Vector3(0.220, 0.004, 0.140),
			Vector3(0.0, 0.012, 0.002), paper)
	_page.name = "RegisterPage"
	_adopt(_page, _desk)
	# The gutter, so the page reads as an OPEN book rather than a card.
	var gutter := make_box(Vector3(0.004, 0.0035, 0.138),
			Vector3(0.0, 0.0145, 0.002), Color(0.58, 0.54, 0.46))
	gutter.name = "RegisterGutter"
	_adopt(gutter, _desk)
	# Ruled lines across the open page. One goes dark per signed line, so the
	# book reads as filling up rather than as a prop.
	for i in 5:
		# Thick enough to be a line at reading distance. A 2 mm rule on a
		# 0.22 m page photographs as nothing: 'the book fills up' was measuring
		# 0.00095 RMSE on its own declared subject before this.
		var line := make_box(Vector3(0.182, 0.0018, 0.0042),
				Vector3(0.0, 0.0150, -0.048 + 0.024 * float(i)),
				Color(0.62, 0.58, 0.51))
		line.name = "RegisterLine%d" % i
		_adopt(line, _desk)

	# The pen, because a register you cannot sign is scenery.
	var pen := make_cyl(0.0022, 0.0034, 0.105,
			Vector3(0.096, 0.018, 0.010), slate, 0.36, 0.18)
	pen.name = "RegisterPen"
	pen.rotation_degrees.x = 90.0
	pen.rotation_degrees.z = 8.0
	_adopt(pen, _desk)

	_build_conclusion_card(brass, paper, slate)

	_clink = make_emitter("knock", -18.0)
	_paper = make_emitter("pop", -20.0)
	_knock = make_emitter("knock", -13.0)
	_build_reaches()
	_refresh_board()


## SR7-I -- THE PAPER SAYS WHICH REPORT IT IS.
##
## Number, name, unit and the complaint, all read out of the authored job
## record. Nothing here is a second copy of the data: change the record and
## the paper changes, and a report the library does not hold cannot be printed
## at all.
##
## Re-set only when the presented report actually changes -- `_refresh_board`
## runs on every touch, and re-laying six labels each time would be work for
## nothing.
func _reprint_slip() -> void:
	var job := presented_job_id()
	if job == _printed_job:
		return
	_printed_job = job
	for label in _slip_labels:
		label.queue_free()
	_slip_labels.clear()
	if job == "":
		return
	_print_slip_line("SlipNumber", slip_number(), 0.318, 0.0150,
			Color(0.16, 0.13, 0.10))
	_print_slip_line("SlipName", slip_name(), 0.288, 0.0118,
			Color(0.28, 0.22, 0.16))
	_print_slip_line("SlipUnit", slip_unit(), 0.258, 0.0140,
			Color(0.16, 0.13, 0.10))
	var lines := _wrap(slip_symptom(), 26)
	for i in mini(lines.size(), 4):
		_print_slip_line("SlipSymptom%d" % i, str(lines[i]),
				0.226 - 0.0135 * float(i), 0.0088, Color(0.30, 0.25, 0.19))
	_refresh_slip_visibility()


## One printed line on the slip. The slip stands in the board face, so unlike
## the conclusion card its lettering needs no tilt at all.
func _print_slip_line(node_name: String, text: String, y: float, em: float,
		tint: Color) -> void:
	if text == "":
		return
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = 64
	label.pixel_size = em / 64.0
	label.modulate = tint
	label.outline_size = 0
	label.position = Vector3(-0.185, y, 0.0435)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.shaded = true
	label.double_sided = false
	add_child(label)
	_slip_labels.append(label)


## Greedy word wrap. The symptom is one authored sentence and the paper is
## 0.18 m wide; something has to decide where the line ends, and doing it here
## keeps the job record free of presentation.
func _wrap(text: String, width: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in text.strip_edges().split(" ", false):
		var candidate := str(word) if line == "" else line + " " + str(word)
		if candidate.length() > width and line != "":
			out.append(line)
			line = str(word)
		else:
			line = candidate
	if line != "":
		out.append(line)
	return out


func _refresh_slip_visibility() -> void:
	var showing := slip_available()
	# THE ARRIVAL, and only a real arrival. `_landing_armed` stays false until
	# the first refresh has run, so a board that is rebuilt with a report
	# ALREADY on its spindle -- which is what a save resumed mid-shift looks
	# like -- does not pretend the paper just landed. Nothing arrived; it was
	# already there.
	if _landing_armed and showing and not _slip_was_available:
		_landing_left = SLIP_LANDING_SECONDS
		if _paper != null:
			_paper.play()
	_slip_was_available = showing
	_landing_armed = true
	if _slip != null:
		_slip.visible = showing
	if _stub != null:
		_stub.visible = slip_taken
	for i in 2:
		var rule := get_node_or_null(NodePath("SlipRule%d" % i))
		if rule != null:
			(rule as MeshInstance3D).visible = showing
	for label in _slip_labels:
		label.visible = showing


## SR7-H -- THE CONCLUSION CARD AND ITS SLIDING INDEX.
##
## An engraved card of four numbered conclusions with a detented brass index
## running down its margin, lying on the writing slope beside the book. It is
## on the DESK rather than up on the board face on purpose: the words you are
## about to sign belong where the signing happens, in the nearest, flattest,
## best-lit plane the apparatus has.
##
## Its own pivot, tilted 0.40 rather than the desk's 0.52 -- a card lies
## flatter than a thick ledger, and the shallower plane turns the printing
## further toward a standing reader. Seated so its dipped front edge still
## clears the shelf top at 0.065 and its raised back edge clears the backboard
## face at 0.026.
func _build_conclusion_card(brass: Color, paper: Color, slate: Color) -> void:
	_card = Node3D.new()
	_card.name = "ConclusionCard"
	_card.position = Vector3(-0.205, 0.114, 0.140)
	_card.rotation.x = 0.40
	add_child(_card)

	var plate := make_box(Vector3(0.280, 0.003, 0.220), Vector3.ZERO, paper)
	plate.name = "ConclusionPlate"
	_adopt(plate, _card)
	var frame_edges := [
		[Vector3(0.280, 0.006, 0.006), Vector3(0.0, 0.002, -0.107)],
		[Vector3(0.280, 0.006, 0.006), Vector3(0.0, 0.002, 0.107)],
		[Vector3(0.006, 0.006, 0.220), Vector3(-0.137, 0.002, 0.0)],
		[Vector3(0.006, 0.006, 0.220), Vector3(0.137, 0.002, 0.0)],
	]
	for edge in frame_edges:
		var rail := make_box(edge[0], edge[1], brass)
		rail.name = "CardRail"
		_adopt(rail, _card)
	# The groove the index runs in. A slide with no track is a loose part.
	var groove := make_box(Vector3(0.016, 0.0035, 0.196),
			Vector3(-0.122, 0.0022, 0.010), Color(0.30, 0.25, 0.16))
	groove.name = "IndexGroove"
	_adopt(groove, _card)

	# 0.0138 em is what fits the longest conclusion between the rails. The
	# first card was set at 0.017 and "DISTURBANCE PERSISTS" ran off the
	# right-hand rail -- which would have made the one ambiguous outcome the
	# only unreadable line on the card.
	_print_card_line("CardTitle", "CONCLUSION", 0.024, -0.090, 0.016,
			Color(0.20, 0.16, 0.11))
	var rule := make_box(Vector3(0.230, 0.0035, 0.0022),
			Vector3(0.020, 0.0035, -0.075), Color(0.42, 0.36, 0.28))
	rule.name = "CardTitleRule"
	_adopt(rule, _card)

	# Row 0 is the blank. It is PRINTED, so the resting position of the index
	# is a legend you can read rather than an empty space you have to notice.
	_print_card_line("CardNumber0", "--", -0.076, DETENT_Z[0], 0.0138,
			Color(0.34, 0.29, 0.22))
	_print_card_line("CardPhrase0", "NOTHING ENTERED", 0.024, DETENT_Z[0],
			0.0138, Color(0.38, 0.33, 0.26))
	for i in OUTCOMES.size():
		var outcome := str(OUTCOMES[i])
		var printed: String = str(OUTCOME_CARD[outcome])
		_print_card_line("CardNumber%d" % (i + 1), printed.substr(0, 1),
				-0.076, DETENT_Z[i + 1], 0.0138, Color(0.16, 0.13, 0.09))
		var phrase := printed.substr(4).strip_edges()
		# The one long conclusion is set over two lines rather than shrunk to
		# fit. Shrinking it would make the only ambiguous outcome the hardest
		# one on the card to read, which is precisely backwards.
		if phrase.contains(", "):
			var parts := phrase.split(", ")
			_print_card_line("CardPhrase%d" % (i + 1), str(parts[0]) + ",",
					0.024, DETENT_Z[i + 1], 0.0138, Color(0.16, 0.13, 0.09))
			_print_card_line("CardPhrase%dB" % (i + 1), str(parts[1]),
					0.030, DETENT_Z[i + 1] + 0.024, 0.0138,
					Color(0.16, 0.13, 0.09))
		else:
			_print_card_line("CardPhrase%d" % (i + 1), phrase, 0.024,
					DETENT_Z[i + 1], 0.0138, Color(0.16, 0.13, 0.09))

	# THE INDEX ITSELF. Brass, detented, and the only thing on this apparatus
	# that decides what gets written down.
	_slide = Node3D.new()
	_slide.name = "ConclusionIndex"
	_card.add_child(_slide)
	var body := make_box(Vector3(0.026, 0.011, 0.024), Vector3.ZERO, brass)
	body.name = "IndexBody"
	_adopt(body, _slide)
	var knurl := make_box(Vector3(0.026, 0.004, 0.006),
			Vector3(0.0, 0.008, 0.0), Color(0.44, 0.35, 0.16))
	knurl.name = "IndexKnurl"
	_adopt(knurl, _slide)
	# The tongue that reaches out of the groove and lands on the line.
	# The tongue stops short of the numerals: an index that lands ON the
	# number it is selecting hides the thing it is pointing at.
	var tongue := make_box(Vector3(0.026, 0.004, 0.005),
			Vector3(0.014, 0.004, 0.0), brass)
	tongue.name = "IndexTongue"
	_adopt(tongue, _slide)
	var nib := make_box(Vector3(0.007, 0.004, 0.011),
			Vector3(0.029, 0.004, 0.0), Color(0.86, 0.74, 0.36))
	nib.name = "IndexNib"
	_adopt(nib, _slide)
	_slide.position = Vector3(-0.122, 0.004, DETENT_Z[0])
	# A stop pin at each end, so the index visibly cannot leave its four
	# conclusions and its blank.
	for stop_z in [DETENT_Z[0] - 0.021, DETENT_Z[DETENT_Z.size() - 1] + 0.021]:
		var stop := make_cyl(0.0035, 0.0035, 0.012,
				Vector3(-0.122, 0.006, stop_z), slate, 0.40, 0.50)
		stop.name = "IndexStop"
		stop.rotation_degrees.x = 90.0
		_adopt(stop, _card)


## One engraved line on the card. `Label3D` is the established lettering idiom
## for Orison props (`lobby_bulletin_board.gd` sets its brass plate the same
## way); nothing here invents a text surface.
func _print_card_line(node_name: String, text: String, x: float, z: float,
		em: float, tint: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font_size = 64
	label.pixel_size = em / 64.0
	label.modulate = tint
	label.outline_size = 0
	label.position = Vector3(x, 0.005, z)
	label.rotation_degrees.x = -90.0
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.shaded = true
	label.double_sided = false
	_card.add_child(label)
	_card_labels.append(label)


## `make_box` has no parent argument the way `make_cyl` does, so a box that
## belongs on the desk is built on the prop and moved. Reparenting keeps the
## local offset it was authored with, which is what the call site meant.
func _adopt(node: Node3D, pivot: Node3D) -> void:
	var local := node.position
	var spin := node.rotation
	remove_child(node)
	pivot.add_child(node)
	node.position = local
	node.rotation = spin


## Four literal service points, one per thing you can physically touch. They
## are the mechanism by which route order stays free: there is no sequence
## between them because there is no gate between them.
func _build_reaches() -> void:
	var reaches := {
		"slip": [Vector3(-0.185, 0.255, 0.055), Vector3(0.20, 0.30, 0.16)],
		"hook_apartment": [Vector3(0.055, 0.330, 0.055),
				Vector3(0.13, 0.20, 0.16)],
		"hook_plant": [Vector3(0.215, 0.320, 0.055),
				Vector3(0.13, 0.22, 0.16)],
		"book": [Vector3(0.075, 0.100, 0.120), Vector3(0.28, 0.16, 0.24)],
		# SR7-H: the index. Its own literal place on the apparatus, so
		# choosing your words is a thing you reach for and not a thing that
		# happens to you while you are signing.
		"index": [Vector3(-0.240, 0.108, 0.150), Vector3(0.16, 0.16, 0.26)],
	}
	for control_id in reaches.keys():
		var reach := ControlArea.new()
		reach.name = "Reach_%s" % str(control_id)
		reach.configure(str(control_id))
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = reaches[control_id][1]
		shape_node.shape = shape
		shape_node.position = reaches[control_id][0]
		reach.add_child(shape_node)
		add_child(reach)


# --- interaction -------------------------------------------------------------

func control_prompt(control_id: String) -> String:
	match control_id:
		"slip":
			if slip_taken:
				return "[E]  File the report back on the spindle"
			if slip_available():
				return "[E]  Take the report off the spindle"
			return "[E]  The spindle is empty"
		"hook_apartment", "hook_plant":
			var hook := _hook_of(control_id)
			if key_out(hook):
				return "[E]  Hang the %s key back (check %d is on the hook)" \
						% [hook, int(CHECK_NUMBERS[hook])]
			return "[E]  Take the %s key (%d door%s, %d locked)" % [hook,
					tagged_door_count(hook),
					"" if tagged_door_count(hook) == 1 else "s",
					locked_count(hook)]
		"index":
			var next := (index_detent + 1) % (OUTCOMES.size() + 1)
			var next_line: String = CARD_BLANK if next == 0 \
					else str(OUTCOME_CARD[OUTCOMES[next - 1]])
			return "[E]  %s  ->  move the index to  %s" % [card_line(),
					next_line]
		"book":
			if not round_open:
				return "[E]  The register is up to date"
			if slip_taken:
				return "[E]  File the report before you sign for it"
			if keys_out_count() > 0:
				return "[E]  The keys are still out"
			if not outcome_selected():
				return "[E]  The index is standing on the blank"
			return "[E]  Sign the register:  %s" % card_line()
	return ""


func _hook_of(control_id: String) -> String:
	return PLANT_HOOK if control_id == "hook_plant" else APARTMENT_HOOK


func interact_control(control_id: String, _player: Node) -> bool:
	match control_id:
		"slip":
			return replace_slip() if slip_taken else take_slip()
		"hook_apartment", "hook_plant":
			var hook := _hook_of(control_id)
			return return_key(hook) if key_out(hook) else take_key(hook)
		"index":
			return advance_index()
		"book":
			return sign_register()
	return false


func interact_prompt() -> String:
	return control_prompt("book")


func interact(player: Node) -> void:
	interact_control("book", player)


func service_wire_card() -> Dictionary:
	return {
		"title": "NIGHT REGISTER",
		"body": "Two hooks, two keys, one ruled book. The board says what is "
				+ "missing and nothing else: not who took it, not where they "
				+ "went, not whether the door it opens was ever locked.",
	}


# --- the readable refusal ----------------------------------------------------

## `design/PROP_ACTIVITIES.md` forbids a silent false, and a refusal that only
## exists while the clock runs cannot be photographed -- the lesson SR7-E paid
## for and SR7-F confirmed. Every refusal here is a held, deterministic pose.
## THE THING THAT REFUSES IS THE THING THAT MOVES, and `focus` is what makes
## that true. A single shared pose is worse than it sounds: two different
## refusals in the same board condition then render as the SAME photograph,
## which the SR7-G sheet demonstrated by returning a byte-identical pair.
func _balk(seconds: float, focus := "") -> void:
	var already := _balk_left > 0.0
	_balk_focus = focus
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()
	# THE POSE IS APPLIED HERE, not left to `_process`. A proof sheet freezes
	# `_process` so a refusal survives the exposure -- and a refusal that only
	# renders on the next tick is a refusal that photographs as nothing at
	# all. SR7-E paid for this once with a byte-identical frame; SR7-G caught
	# it a second time on the sheet.
	_refresh_board()


func balking() -> bool:
	return _balk_left > 0.0


## Seconds left of the paper's landing, and whether it is still landing.
## Public so a deterministic test can drive the pose without watching it.
func slip_landing() -> bool:
	return _landing_left > 0.0


func slip_landing_remaining() -> float:
	return _landing_left


func _process(delta: float) -> void:
	_t += delta
	if _landing_left > 0.0:
		_landing_left = maxf(0.0, _landing_left - delta)
		_refresh_board()
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_board()


func _refresh_board() -> void:
	if _board == null:
		return
	# SR7-I. ONE PLACE DECIDES WHETHER THE PAPER MAY CHANGE. Engaged, the
	# latch holds whatever was on the spindle when the engagement began;
	# idle, there is no latch and the authored order decides afresh. A board
	# left idle therefore picks up 002 the moment 001 closes, and a board
	# mid-round does not.
	if engaged():
		if _latched_job == "":
			_latched_job = first_open_job()
	else:
		_latched_job = ""
	_reprint_slip()
	_refresh_slip_visibility()

	# A hook carries EITHER the key or the check. Never both, never neither.
	for hook in HOOK_ORDER:
		var name_id := str(hook)
		var out := key_out(name_id)
		for part in (_keys.get(name_id, []) as Array):
			(part as MeshInstance3D).visible = not out
		for part in (_checks.get(name_id, []) as Array):
			(part as MeshInstance3D).visible = out

	# The book fills up as it is signed. A written line is ink rather than
	# rule: darker, and SHORTER, because nobody writes into the margin. Two
	# changes rather than one, so the difference survives a photograph.
	for i in 5:
		var line := _desk.get_node_or_null(NodePath("RegisterLine%d" % i)) \
				if _desk != null else null
		if line != null:
			var mi := line as MeshInstance3D
			var written := i < signed_lines
			mi.scale.x = 0.78 if written else 1.0
			mi.position.x = -0.019 if written else 0.0
			var mat := mi.material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color = Color(0.07, 0.06, 0.07) if written \
						else Color(0.62, 0.58, 0.51)

	# THE REFUSAL POSE. Deterministic, held for the balk's duration, never a
	# function of `_t` -- and TARGETED, so the frame says which of the four
	# things on this board just said no.
	var balk := clampf(_balk_left, 0.0, 1.0)
	if _desk != null:
		_desk.rotation.x = 0.52
		_desk.position.z = 0.106
	if _spindle != null:
		_spindle.rotation.z = 0.0
	if _slip != null:
		_slip.position.y = 0.250
	if _stub != null:
		_stub.position.y = 0.176
	if _shelf != null:
		_shelf.position.y = 0.055
	# THE LANDING. Posed from the countdown and never from `_t`, so a frozen
	# frame holds it. It is written here, above the refusal block, so a balk
	# always wins: a board saying no is louder than a board taking paper.
	var landing := clampf(_landing_left / SLIP_LANDING_SECONDS, 0.0, 1.0)
	if landing > 0.0:
		var fall := landing * landing
		if _slip != null:
			_slip.position.y = 0.250 + SLIP_LANDING_RISE * fall
		if _spindle != null:
			_spindle.rotation.z = -SPINDLE_NOD * sin(landing * PI)
	# SR7-H. THE INDEX IS THE SELECTION, so the visible slide is placed from
	# `index_detent` on every refresh and from nothing else. There is no path
	# by which the picture and the record can disagree.
	if _slide != null:
		var detent := clampi(index_detent, 0, DETENT_Z.size() - 1)
		_slide.position = Vector3(-0.122, 0.004, float(DETENT_Z[detent]))
		_slide.rotation.y = 0.0
	for hook in HOOK_ORDER:
		_set_hook_lift(str(hook), 0.0)
	if balk <= 0.0:
		return
	match _balk_focus:
		"book":
			# The desk kicks up off its slope: you cannot sign that.
			if _desk != null:
				_desk.rotation.x = 0.52 - 0.34 * balk
				_desk.position.z = 0.106 + 0.030 * balk
			if _shelf != null:
				_shelf.position.y = 0.055 - 0.010 * balk
		"slip":
			# The spindle leans and the slip rides up its spike.
			if _spindle != null:
				_spindle.rotation.z = 0.26 * balk
			if _slip != null:
				_slip.position.y = 0.250 + 0.055 * balk
			if _stub != null:
				_stub.position.y = 0.176 + 0.040 * balk
		"index":
			# The index rocks in its groove without leaving its detent: the
			# apparatus is refusing to file, not offering to choose for you.
			if _slide != null:
				_slide.rotation.y = 0.34 * balk
				_slide.position.x = -0.122 - 0.016 * balk
		APARTMENT_HOOK, PLANT_HOOK:
			_set_hook_lift(_balk_focus, balk)


## Lifts and cants whatever a hook is carrying -- its key or its check --
## without caring which, because only one of them is ever visible.
func _set_hook_lift(hook: String, amount: float) -> void:
	var lift := 0.052 * amount
	var cant := 0.60 * amount
	for group in [_keys.get(hook, []) as Array, _checks.get(hook, []) as Array]:
		for part in group:
			var mi := part as MeshInstance3D
			if mi == null:
				continue
			if not _hook_rest.has(mi):
				_hook_rest[mi] = mi.position
			mi.position = (_hook_rest[mi] as Vector3) + Vector3(0.0, lift, 0.0)
			var carried := mi.name.begins_with("Key") \
					or mi.name.begins_with("Check")
			mi.rotation.z = cant if carried else 0.0
