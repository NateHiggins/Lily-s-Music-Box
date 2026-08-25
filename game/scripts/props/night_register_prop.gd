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

## The job this board carries a report for. Presented, never issued.
const JOB_ID := "lena_radiator_round_2b"
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

var _work_orders: Node
var _building: Node

var _board: MeshInstance3D
var _shelf: MeshInstance3D
var _spindle: MeshInstance3D
var _slip: MeshInstance3D
var _stub: MeshInstance3D
var _desk: Node3D
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
var _balk_focus := ""
var _t := 0.0

## The apparatus's own facts. `slip_taken` and `keys_out` are the working
## condition of the board; `signed_lines` is what the book carries. Only
## `sign_register()` moves the last one into RealityState.
var slip_taken := false
var keys_out := {APARTMENT_HOOK: false, PLANT_HOOK: false}
var signed_lines := 0


func _ready() -> void:
	super()
	_bind_owners()
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
	if job_id == JOB_ID:
		_refresh_board()


# --- what the spine already holds -------------------------------------------

## The stage `WorkOrders` holds for this job, or "missing". Read-only, and the
## single source of truth for whether a report exists at all.
func job_stage() -> String:
	if _work_orders == null:
		return "missing"
	return str(_work_orders.call("job_stage", JOB_ID))


## A slip is on the spindle when the spine holds a live job and nobody has
## taken it. There is no slip for a job that was never issued: this board does
## not invent work.
func slip_available() -> bool:
	return not slip_taken and job_stage() not in ["missing", "closed"]


## What the slip says, reconstructed from the job library per stage exactly as
## the objective tracker does. Never stored, never duplicated.
func slip_text() -> String:
	if _work_orders == null or _work_orders.get("job_library") == null:
		return ""
	# `MaintenanceJobLibrary` is a RefCounted, not a Node -- typing this as a
	# Node assigns nothing and silently empties the slip.
	var library: RefCounted = _work_orders.get("job_library")
	var record: Dictionary = library.call("job", JOB_ID)
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


## Whether anything has happened that the book would have to record. Signing a
## register that has nothing on it is the fifth refusal.
func has_unsigned_work() -> bool:
	return slip_taken or keys_out_count() > 0


# --- taking and returning ----------------------------------------------------

## Reversible. Everything below moves the visible board and writes nothing:
## `sign_register()` is the only publication, exactly as
## `apply_maintenance_result` is on every other SR7 apparatus.
func take_slip() -> bool:
	if slip_taken:
		# There is nothing on the spindle to take.
		_balk(1.0, "slip")
		return false
	if not slip_available():
		# No report has been made. The board will not manufacture one, because
		# ServiceRoundDirector owns issuing and this prop is not it.
		_balk(1.2, "slip")
		return false
	slip_taken = true
	if _paper != null:
		_paper.play()
	# THE ONE MUTATING CALL THIS PROP MAKES ON THE SPINE, and it is the same
	# public call the service round makes when the player speaks to Lena.
	# Taking the paper is acknowledging the work; it is not a second ledger,
	# and `_advance_job` refuses it from any stage but `issued` without
	# mutating anything.
	if _work_orders != null and job_stage() == "issued":
		_work_orders.call("acknowledge_job", JOB_ID)
	if job_stage() == "acknowledged":
		report_taken.emit(JOB_ID)
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
	if not has_unsigned_work():
		# An unmarked register. There is nothing to sign for.
		_balk(1.0, "book")
		return false
	var line := {
		"at": Time.get_unix_time_from_system(),
		"report_out": slip_taken,
		"keys_out": _keys_out_list(),
		"job_id": JOB_ID,
		"job_stage": job_stage(),
	}
	var record: Dictionary = RealityState.data.get(STATE_KEY, {})
	var lines: Array = record.get("lines", [])
	lines.append(line)
	record["lines"] = lines
	RealityState.data[STATE_KEY] = record
	RealityState.commit()
	signed_lines = lines.size()
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
	}


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	slip_taken = bool(snapshot.get("slip_taken", slip_taken))
	var restored: Dictionary = snapshot.get("keys_out", {})
	for hook in HOOK_ORDER:
		if restored.has(hook):
			keys_out[hook] = bool(restored[hook])
	signed_lines = int(snapshot.get("signed_lines", signed_lines))
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
	_shelf = make_box(Vector3(0.62, 0.020, 0.170),
			Vector3(0.0, 0.055, 0.085), oak)
	_shelf.name = "RegisterShelf"
	# Two brackets, because a shelf carrying a ledger is carrying real weight.
	for bracket_x in [-0.24, 0.24]:
		var bracket := make_box(Vector3(0.016, 0.070, 0.090),
				Vector3(bracket_x, 0.020, 0.055), oak)
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
	_slip = make_box(Vector3(0.135, 0.175, 0.0025),
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
	# Three ruled lines, so the slip reads as a printed form rather than a
	# white card, and so it is legible as PAPER at a glance in a photograph.
	for i in 3:
		var rule := make_box(Vector3(0.100, 0.0018, 0.0006),
				Vector3(-0.185, 0.300 - 0.030 * float(i), 0.0425),
				Color(0.42, 0.36, 0.28))
		rule.name = "SlipRule%d" % i

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

	_clink = make_emitter("knock", -18.0)
	_paper = make_emitter("pop", -20.0)
	_knock = make_emitter("knock", -13.0)
	_build_reaches()
	_refresh_board()


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
		"book": [Vector3(0.075, 0.085, 0.100), Vector3(0.30, 0.16, 0.22)],
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
		"book":
			if not has_unsigned_work():
				return "[E]  The register is up to date"
			return "[E]  Sign the register"
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


func _process(delta: float) -> void:
	_t += delta
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_board()


func _refresh_board() -> void:
	if _board == null:
		return
	if _slip != null:
		_slip.visible = slip_available()
	if _stub != null:
		_stub.visible = slip_taken
	for i in 3:
		var rule := get_node_or_null(NodePath("SlipRule%d" % i))
		if rule != null:
			(rule as MeshInstance3D).visible = slip_available()

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
			mi.rotation.z = cant if mi.name.begins_with("Key") 					or mi.name.begins_with("Check") else 0.0
