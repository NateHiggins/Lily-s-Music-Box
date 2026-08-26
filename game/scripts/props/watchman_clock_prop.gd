class_name WatchmanClockProp
extends FunctionalProp
## The watchman's time detector: paper dial, drive pin and station keys.
##
## SR7-F, and the last of the fixed SR7 order.
##
## THE TRUTH THIS TEACHES. A watchman's clock can run, tick, take every mark
## you give it and prove absolutely nothing.
##
## The paper dial turns once round in a day ON THE CLOCK'S OWN SPINDLE. Where a
## key's mark falls AROUND the dial is when it was made; how far OUT from the
## centre is which station made it. Both facts live in one puncture, and both
## depend on the paper having moved while the night went by.
##
## A dial that is merely dropped over the arbor -- centre hole on, drive pin
## NOT through its index hole -- sits perfectly still while the movement runs
## behind it. The hands sweep. The keys emboss. The sheet fills up. And every
## mark of the whole night lands at the same angle, so the record reads as one
## instant: six stations visited simultaneously, which is the one thing a
## watchman certainly did not do. The instrument looks healthy from every angle
## except the only one that matters.
##
## HISTORICAL BASIS.
##   * A. NEWMAN of Chicago, US 676,764, patented 18 June 1901, "Watchman's
##     Clock". The paper dial "rotates once in twenty-four hours with the
##     spindle", is graduated and numbered, and is embossed with the characters
##     of whichever station key is turned in it. WITH THE SPINDLE is the whole
##     load-bearing phrase: the dial is not a passenger, it is driven, and a
##     dial that is not driven is a blank sheet with holes in it.
##   * P. MOOSMANN of Brooklyn, US 1,351,056, filed 1 June 1916, granted
##     31 August 1920, "Watchman's Time-Detector". "each key has a barrel of
##     predetermined length which differs from the barrels of the remaining
##     keys, so that the indicating mark made by the use of each key may be
##     identified by the position on the dial" -- that is the radius axis. Its
##     stop-flange exists because, in the patent's own account, a watchman
##     could otherwise copy a key and work the detector without visiting the
##     station at all. The period knew perfectly well that this instrument's
##     entire value is defeatable, which is why SR7-F is about proving it
##     rather than about reading it.
##
## ORISON-SPECIFIC INFERENCE, stated plainly: that THIS detector's dial is off
## its drive pin tonight, the six stations on last night's sheet, the reading
## index, the stop lever's particular shape and the two proof marks are
## authored. The instrument, its dial geometry and the two axes are not.
##
## AUTHORING RULE. Local z = 0 is the mounting plane and the apparatus is built
## OUTWARD along +z toward the room.
##
## OWNERSHIP. This prop owns its own detector and nothing else. It READS the
## house clock and never sets it; it creates no patrol, no station network, no
## resident schedule and no route. It closes no job, advances no case, mutates
## no Dream state and adds no save owner. Only `apply_maintenance_result` may
## record the detector honest.

signal maintenance_completed(result: Dictionary)

const ControlArea = preload("res://scripts/props/prop_control_area.gd")

## The canonical house hour: 03:00, which is what `DAYNIGHT=0` pins and what
## every test and render runs at. `_house_minute()` prefers the real director
## when one is in the tree and falls back to this.
const CANONICAL_MINUTE := 180.0
## Where a fresh dial lands when it is dropped on. The datum is the amount it
## must then be turned, so the correct setting is this plus the hour.
const FRESH_DIAL_OFFSET := 0.585
## How close the datum must be before the record's hours mean anything.
const DATUM_TOLERANCE := 0.06
## Radius on the dial for each of the six stations, innermost first. Moosmann's
## key barrels differ in length, and this is what that difference buys.
const STATION_RADII := [0.030, 0.044, 0.058, 0.072, 0.086, 0.100]

var _service_panel: MaintenanceActivityPanel
var _clock_source: Node
var _first_shift: FirstShiftDirector

## The two pivots this apparatus turns on, and the whole thesis in two nodes.
## `_arbor` is the spindle: it carries the drive pin and it turns with the
## movement. `_paper` is the sheet: it carries the graduations, the index hole
## and every mark ever punched. They are the SAME angle only when the pin is
## through the hole. Everything else in the case is fixed to the case.
var _arbor: Node3D
var _paper: Node3D
var _case: MeshInstance3D
var _glass: MeshInstance3D
var _dial: MeshInstance3D
var _spindle: MeshInstance3D
var _drive_pin: MeshInstance3D
var _index_hole: MeshInstance3D
var _stop_lever: MeshInstance3D
var _station_key: MeshInstance3D
var _reading_index: MeshInstance3D
var _hand: MeshInstance3D
var _night_marks: Array[MeshInstance3D] = []
var _proof_a: MeshInstance3D
var _proof_b: MeshInstance3D
var _tick: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _punch: AudioStreamPlayer3D
var _balk_left := 0.0
var _t := 0.0

## The apparatus's own facts.
##
## `dial_seated` false is the fault, and note what it is NOT: the movement is
## running, the hands are sweeping, the keys emboss, and last night's sheet is
## covered in marks. Nothing is broken. The paper simply was not moving.
var dial_seated := false
var movement_running := true
var datum := 0.0
var datum_set := false
var reading := 0.0
var proof_first := -1.0
var proof_second := -1.0
var detector_honest := false


# --- the house clock, read and never set ------------------------------------

## The building's own hour, in minutes past midnight.
##
## Read-only, and deliberately sourced from the SAME owner the sky uses rather
## than re-deriving it: two clocks in one building is exactly the class of bug
## this apparatus is about. `_minute_now()` is that owner's private helper and
## is called as one, which is the smallest honest read available -- there is no
## public accessor, and duplicating its DAYNIGHT/DAYNIGHT_FORCE logic here
## would create the second source of truth rather than avoid it.
func _house_minute() -> float:
	if _clock_source == null or not is_instance_valid(_clock_source):
		var node: Node = self
		while node != null:
			var director: Variant = node.get("day_night_director")
			if director != null and director is Node:
				_clock_source = director
				break
			node = node.get_parent()
	if _clock_source != null and _clock_source.has_method("_minute_now"):
		return float(_clock_source.call("_minute_now"))
	return CANONICAL_MINUTE


## Where the dial's graduation has to stand for the record to tell the truth.
func correct_datum() -> float:
	return fposmod(_house_minute() / 1440.0 + FRESH_DIAL_OFFSET, 1.0)


# --- the physical model ------------------------------------------------------

## Whether the paper is actually being carried round. Newman's "with the
## spindle": a running movement is necessary and nowhere near sufficient.
func dial_turns() -> bool:
	return movement_running and dial_seated


## How far the datum is from the house hour, in dial turns.
func datum_error() -> float:
	var delta := absf(datum - correct_datum())
	return minf(delta, 1.0 - delta)


## Whether a mark made now would carry an honest hour.
func record_is_honest() -> bool:
	return dial_turns() and datum_set and datum_error() <= DATUM_TOLERANCE


## The proof itself: two marks with daylight between them. One mark proves a
## key was turned. Only two, at different angles, prove the paper moved.
func marks_prove_movement() -> bool:
	if proof_first < 0.0 or proof_second < 0.0:
		return false
	var gap := absf(proof_second - proof_first)
	return minf(gap, 1.0 - gap) > 0.012


# --- geometry ----------------------------------------------------------------

func _build_visual() -> void:
	var oak := Color(0.29, 0.19, 0.11)
	var brass := Color(0.50, 0.40, 0.21)
	var paper := Color(0.84, 0.81, 0.71)
	var steel := Color(0.46, 0.46, 0.48)

	# The case, hung on the wall at the porter's post.
	_case = make_box(Vector3(0.34, 0.40, 0.05), Vector3(0.0, 0.20, 0.025), oak)
	_case.name = "DetectorCase"
	for cheek_x in [-0.165, 0.165]:
		make_box(Vector3(0.028, 0.40, 0.13), Vector3(cheek_x, 0.20, 0.085), oak)
	make_box(Vector3(0.34, 0.028, 0.13), Vector3(0.0, 0.395, 0.085), oak)
	make_box(Vector3(0.34, 0.028, 0.13), Vector3(0.0, 0.005, 0.085), oak)

	# THE TWO PIVOTS. `_arbor` is the spindle and `_paper` is the sheet, and
	# the entire fault this apparatus teaches is the angle between them.
	#
	# The prop's local XY plane is the face of the case and +Z is out into the
	# room, so both pivots turn on Z -- which is how a disc actually spins in
	# its own plane. Driving a tipped cylinder's `rotation.y` instead turns it
	# edge-on to the glass, which is wrong and looks it.
	_arbor = Node3D.new()
	_arbor.name = "SpindlePivot"
	_arbor.position = Vector3(0.0, 0.22, 0.118)
	add_child(_arbor)
	_paper = Node3D.new()
	_paper.name = "PaperPivot"
	_paper.position = Vector3(0.0, 0.22, 0.112)
	add_child(_paper)

	# THE PAPER DIAL. Graduated and numbered, as Newman has it, and the whole
	# reason this apparatus is worth photographing: a record you can read at a
	# glance if you know what a good one looks like.
	#
	# Everything printed or punched on the sheet is a child of `_paper`, so it
	# all turns together. That is not tidiness: a graduation that stayed put
	# while the paper moved would make the datum meaningless, and the datum is
	# what the fourth step of the round exists to set.
	_dial = make_cyl(0.125, 0.125, 0.004, Vector3.ZERO, paper, 0.86, 0.0,
		_paper)
	_dial.name = "PaperDial"
	_dial.rotation_degrees.x = 90.0
	# A sheet of paper is round. The shared helper's 14 segments read as a
	# visible polygon at the range this apparatus is inspected from.
	var disc := _dial.mesh as CylinderMesh
	if disc != null:
		disc.radial_segments = 48
	# Twenty-four graduations round the rim. These are what the datum is set
	# against and what makes an angle readable as an hour.
	for hour in 24:
		var a := TAU * float(hour) / 24.0
		var long := (hour % 6) == 0
		var tick := make_box(
			Vector3(0.004, 0.016 if long else 0.009, 0.002),
			Vector3(sin(a) * 0.113, cos(a) * 0.113, 0.004),
			Color(0.30, 0.24, 0.17) if long else Color(0.46, 0.40, 0.30))
		tick.rotation.z = -a
		_adopt(tick, _paper)

	# THE SPINDLE and its DRIVE PIN, both on the arbor. The pin is the entire
	# difference between a dial that records and a dial that only collects
	# holes, and it keeps turning with the movement whatever the paper does.
	_spindle = make_cyl(0.008, 0.008, 0.030, Vector3.ZERO,
		steel, 0.34, 0.72, _arbor)
	_spindle.name = "DriveSpindle"
	_spindle.rotation_degrees.x = 90.0
	_drive_pin = make_cyl(0.0035, 0.0035, 0.020, Vector3(0.020, 0.0, 0.0),
		Color(0.78, 0.68, 0.30), 0.30, 0.76, _arbor)
	_drive_pin.name = "DrivePin"
	_drive_pin.rotation_degrees.x = 90.0
	# The dial's index hole, which the pin must come up through. It is punched
	# in the PAPER, so it rides with the paper and not with the pin -- and when
	# the two are not at the same angle you are looking straight at the fault.
	_index_hole = make_cyl(0.0060, 0.0060, 0.006, Vector3(0.020, 0.0, 0.002),
		Color(0.16, 0.13, 0.10), 0.90, 0.0, _paper)
	_index_hole.name = "IndexHole"
	_index_hole.rotation_degrees.x = 90.0

	# LAST NIGHT'S RECORD. Six stations, and every one of them on the same
	# radial line: the picture of a dial that never moved.
	for i in STATION_RADII.size():
		var mark := make_cyl(0.0048, 0.0048, 0.005, Vector3.ZERO,
			Color(0.14, 0.11, 0.08), 0.88, 0.0, _paper)
		mark.name = "NightMark%d" % i
		mark.rotation_degrees.x = 90.0
		_night_marks.append(mark)

	# The two proof marks, made during the round and invisible until then.
	# They are the only two marks on the sheet that mean anything, so they are
	# drawn to be read rather than found.
	_proof_a = make_cyl(0.0055, 0.0055, 0.006, Vector3.ZERO,
		Color(0.09, 0.07, 0.26), 0.84, 0.0, _paper)
	_proof_a.name = "ProofMarkFirst"
	_proof_a.rotation_degrees.x = 90.0
	_proof_a.visible = false
	_proof_b = make_cyl(0.0055, 0.0055, 0.006, Vector3.ZERO,
		Color(0.09, 0.07, 0.26), 0.84, 0.0, _paper)
	_proof_b.name = "ProofMarkSecond"
	_proof_b.rotation_degrees.x = 90.0
	_proof_b.visible = false

	# THE HANDS. They belong to the movement, not to the paper, and they keep
	# sweeping whatever the paper is doing -- which is exactly how this fault
	# survives an inspection.
	_hand = make_box(Vector3(0.006, 0.070, 0.003), Vector3(0.0, 0.255, 0.121),
		Color(0.20, 0.16, 0.12))
	_hand.name = "MovementHand"

	# The glazed door, so the record is readable without opening the case.
	_glass = make_box(Vector3(0.30, 0.36, 0.006), Vector3(0.0, 0.20, 0.140),
			Color(0.62, 0.68, 0.66))
	_glass.name = "GlassLid"
	var gm := _glass.material_override as StandardMaterial3D
	if gm != null:
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_color = Color(0.62, 0.68, 0.66, 0.20)
		gm.roughness = 0.05

	# The stop lever, the station key on its hasp, and the reading index.
	_stop_lever = make_box(Vector3(0.070, 0.018, 0.018),
			Vector3(0.115, 0.055, 0.128), brass)
	_stop_lever.name = "StopLever"
	_station_key = make_box(Vector3(0.016, 0.052, 0.016),
			Vector3(-0.125, 0.058, 0.128), Color(0.56, 0.48, 0.26))
	_station_key.name = "StationKey"
	_reading_index = make_box(Vector3(0.005, 0.115, 0.004),
			Vector3(0.0, 0.276, 0.126), Color(0.64, 0.56, 0.30))
	_reading_index.name = "ReadingIndex"

	_tick = make_emitter("tick", -22.0)
	_knock = make_emitter("knock", -14.0)
	_punch = make_emitter("pop", -16.0)
	_build_detector_reach()
	_refresh_mechanism()


## `make_box` has no parent argument the way `make_cyl` does, so a box that
## belongs on a pivot is built on the prop and moved. Reparenting keeps the
## local offset it was authored with, which is what the call site meant.
func _adopt(node: Node3D, pivot: Node3D) -> void:
	var local := node.position
	var spin := node.rotation
	remove_child(node)
	pivot.add_child(node)
	node.position = local
	node.rotation = spin


## The service point, over the dial and the stop lever. Built in the visual
## pass so the base class finds an authored area rather than wrapping the whole
## case in a coarser one.
func _build_detector_reach() -> void:
	var reach := ControlArea.new()
	reach.name = "DetectorReach"
	reach.configure("detector")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.40, 0.44, 0.28)
	shape_node.shape = shape
	shape_node.position = Vector3(0.0, 0.20, 0.12)
	reach.add_child(shape_node)
	add_child(reach)


# --- interaction -------------------------------------------------------------

## Routine watch duty and detector maintenance meet at the same cabinet, but
## they are not the same mutation. The director owns the opening ritual; this
## prop merely provides its physical hand. In particular, clocking in never
## sets `dial_seated`, `datum_set` or `detector_honest` behind SR7-F's guard.
func bind_first_shift(director: FirstShiftDirector) -> void:
	_first_shift = director


func _ritual_phase() -> String:
	if _first_shift == null or not is_instance_valid(_first_shift):
		return ""
	return _first_shift.ritual_phase()

func control_prompt(control_id: String) -> String:
	if control_id != "detector":
		return ""
	match _ritual_phase():
		FirstShiftDirector.PHASE_ARRIVED:
			return "[E]  Clock in — seat tonight's paper dial"
		FirstShiftDirector.PHASE_CLOCKED_IN:
			return "Shift open — read the waiting reports"
		FirstShiftDirector.PHASE_REPORT_ACCEPTED:
			return "Shift open — make your round"
		FirstShiftDirector.PHASE_RETURNED:
			return "Shift open — file the report"
		FirstShiftDirector.PHASE_FILED:
			if _first_shift.tour_key_carried():
				return "Return the tour key before clocking out"
			return "[E]  Clock out — remove tonight's paper"
	if not detector_honest:
		return "[E]  Read the watchman's dial"
	return "[E]  Check the watchman's dial"


func interact_control(control_id: String, player: Node) -> bool:
	if control_id != "detector":
		return false
	if _perform_ritual_action():
		return true
	if _ritual_owns_clock():
		return true
	return _begin_detector_service(player)


func interact(player: Node) -> void:
	if _perform_ritual_action():
		return
	if _ritual_owns_clock():
		return
	_begin_detector_service(player)


func _perform_ritual_action() -> bool:
	if _first_shift == null or not is_instance_valid(_first_shift):
		return false
	var worked := false
	match _first_shift.ritual_phase():
		FirstShiftDirector.PHASE_ARRIVED:
			worked = _first_shift.clock_in()
		FirstShiftDirector.PHASE_FILED:
			worked = _first_shift.clock_out()
	if worked and _punch != null:
		_punch.play()
	return worked


func _ritual_owns_clock() -> bool:
	return _ritual_phase() in [
		FirstShiftDirector.PHASE_CLOCKED_IN,
		FirstShiftDirector.PHASE_REPORT_ACCEPTED,
		FirstShiftDirector.PHASE_RETURNED,
		FirstShiftDirector.PHASE_FILED,
	]


func _begin_detector_service(player: Node) -> bool:
	if _service_panel and is_instance_valid(_service_panel):
		return false
	var script: GDScript = load("res://scripts/ui/maintenance_activity_panel.gd")
	_service_panel = script.new()
	get_tree().current_scene.add_child(_service_panel)
	if not _service_panel.open(player, self, "watchman_detector_dial"):
		_service_panel.queue_free()
		_service_panel = null
		return false
	return true


func maintenance_panel_closed() -> void:
	_service_panel = null


# --- the shared maintenance contract -----------------------------------------

func maintenance_snapshot() -> Dictionary:
	return {"dial_seated": dial_seated, "movement_running": movement_running,
			"datum": datum, "datum_set": datum_set, "reading": reading,
			"proof_first": proof_first, "proof_second": proof_second,
			"detector_honest": detector_honest}


## Reversible. Working the visible detector moves the visible detector and
## publishes nothing: `detector_honest` is deliberately untouched here and
## moves only in `apply_maintenance_result`.
func preview_maintenance_step(step: Dictionary, value: float) -> void:
	var worked := clampf(value, 0.0, 1.0)
	match str(step.get("id", "")):
		"read_the_dial":
			reading = worked
		"stop_the_movement":
			var was := movement_running
			movement_running = worked >= 0.5
			if movement_running != was and _tick != null:
				_tick.play()
		"seat_the_dial":
			if movement_running:
				# You cannot seat a dial against a turning spindle, and trying
				# tears the paper across the index hole.
				_balk(1.2)
			else:
				var was_off := not dial_seated
				dial_seated = worked >= 0.35
				if dial_seated and was_off and not datum_set:
					# The sheet drops onto the pin WHERE THE PIN IS. The spindle is
					# stopped and does not jump to meet it, so the dial inherits the
					# angle the movement was standing at -- which is not the datum,
					# and `datum_set` stays false until somebody checks it against
					# the house.
					datum = fposmod(_house_minute() / 1440.0, 1.0)
		"set_the_datum":
			if not dial_seated:
				# There is nothing to set: a loose dial has no datum, only a
				# position it happens to be lying in.
				_balk(0.9)
			else:
				datum = worked
				datum_set = datum_error() <= DATUM_TOLERANCE
				if not datum_set:
					# Set to the wrong hour the record would be a careful,
					# legible, wholly false account of the night.
					_balk(1.0)
		"prove_the_round":
			if not dial_seated:
				_balk(1.2)
			elif not movement_running:
				# THE FAULT ITSELF. With the spindle stopped both marks land on
				# the same radius at the same angle, which is precisely the
				# record this round exists to throw away.
				_balk(1.4)
			elif not datum_set:
				_balk(1.0)
			else:
				# The first turn of the key marks; the hold lets the dial carry
				# it away; the release marks again.
				if proof_first < 0.0:
					proof_first = _dial_angle()
					if _punch != null:
						_punch.play()
				proof_second = fposmod(proof_first + 0.026
						+ 0.05 * worked, 1.0)
	_refresh_mechanism()


## Where the dial stands right now, as a fraction of a turn.
func _dial_angle() -> float:
	return fposmod(datum, 1.0)


func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
	dial_seated = bool(snapshot.get("dial_seated", dial_seated))
	movement_running = bool(snapshot.get("movement_running", movement_running))
	datum = float(snapshot.get("datum", datum))
	datum_set = bool(snapshot.get("datum_set", datum_set))
	reading = float(snapshot.get("reading", reading))
	proof_first = float(snapshot.get("proof_first", proof_first))
	proof_second = float(snapshot.get("proof_second", proof_second))
	detector_honest = bool(snapshot.get("detector_honest", detector_honest))
	_balk_left = 0.0
	_refresh_mechanism()


## The only guarded publication. Nothing above this line records the detector
## honest.
func apply_maintenance_result(result: Dictionary) -> void:
	var patch: Dictionary = result.get("mechanism_patch", {})
	if patch.has("dial_seated"):
		dial_seated = bool(patch["dial_seated"])
	if patch.has("movement_running"):
		movement_running = bool(patch["movement_running"])
	if patch.has("datum_set") and bool(patch["datum_set"]):
		datum = correct_datum()
		datum_set = true
	if patch.has("detector_honest"):
		# A detector is not honest because a data file says so. It is honest
		# when the paper is on the pin, the movement is running and the datum
		# agrees with the house -- and the apparatus is the last word on that.
		detector_honest = bool(patch["detector_honest"]) and record_is_honest()
	reading = 0.0
	_balk_left = 0.0
	_refresh_mechanism()
	maintenance_completed.emit(result.duplicate(true))


# --- the readable refusal ----------------------------------------------------

## A balk is a knock in the case and a visible pose held for as long as it
## lasts. `design/PROP_ACTIVITIES.md` forbids a silent false, and a refusal
## that only exists while the clock runs cannot be photographed -- the lesson
## SR7-E paid for.
func _balk(seconds: float) -> void:
	var already := _balk_left > 0.0
	_balk_left = maxf(_balk_left, clampf(seconds, 0.0, 3.0))
	if not already and _knock != null:
		_knock.play()


func balking() -> bool:
	return _balk_left > 0.0


func _process(delta: float) -> void:
	_t += delta
	if _balk_left > 0.0:
		_balk_left = maxf(0.0, _balk_left - delta)
		_refresh_mechanism()


func _refresh_mechanism() -> void:
	if _dial == null or _paper == null or _arbor == null:
		return

	# THE TWO ANGLES. The spindle stands at the hour the movement has reached.
	# The paper stands at its datum ONLY if it is on the pin; off the pin it
	# stays exactly where it was dropped and the movement runs behind it.
	# Setting the datum IS setting the spindle -- you turn the movement and the
	# paper clamped to it comes round with the pin. So a seated dial and its
	# arbor are one angle by definition, and the pin sits in the hole. Off the
	# pin the spindle free-runs at whatever hour the movement has reached.
	var spindle_turn := fposmod(_house_minute() / 1440.0, 1.0)
	_arbor.rotation.z = -TAU * (_dial_angle() if dial_seated else spindle_turn)
	_paper.rotation.z = -TAU * (_dial_angle() if dial_seated else 0.0)

	# The pin stands proud of the paper only when it is through the hole. Off
	# the hole it sits BEHIND the sheet, which is why nothing catches.
	if _drive_pin != null:
		_drive_pin.position.z = 0.006 if dial_seated else -0.010

	# LAST NIGHT'S SIX MARKS. All on one angle, spread along the radius: six
	# stations recorded at one instant. This is the fault, drawn -- and it is
	# drawn in the paper's own frame, so it turns with the sheet like the ink
	# it is.
	var night_angle := -TAU * 0.16
	for i in _night_marks.size():
		var mark := _night_marks[i]
		var r: float = STATION_RADII[i]
		mark.position.x = sin(night_angle) * r
		mark.position.y = cos(night_angle) * r
		mark.position.z = 0.003
		mark.visible = true

	# The two proof marks, at whatever angles they were actually made.
	if _proof_a != null:
		_proof_a.visible = proof_first >= 0.0
		if proof_first >= 0.0:
			var a := -TAU * proof_first
			_proof_a.position = Vector3(sin(a) * 0.078, cos(a) * 0.078, 0.004)
	if _proof_b != null:
		_proof_b.visible = proof_second >= 0.0
		if proof_second >= 0.0:
			var b := -TAU * proof_second
			_proof_b.position = Vector3(sin(b) * 0.078, cos(b) * 0.078, 0.004)

	# The hand belongs to the movement and sweeps whether or not the paper
	# does, which is the deceit. It stops with the movement, because a stopped
	# clock that still shows a sweeping hand would be a different lie.
	if _hand != null:
		var hand_a := -TAU * fposmod(_house_minute() / 720.0, 1.0)
		_hand.rotation.z = hand_a
		_hand.position.x = sin(hand_a) * 0.035
		_hand.position.y = 0.255 + cos(hand_a) * 0.035 - 0.035

	# The stop lever, thrown or standing.
	if _stop_lever != null:
		_stop_lever.rotation.z = 0.0 if movement_running else -0.62
	# The reading index sweeps the record. It is mounted on the case, not on
	# the sheet: you hold it still and turn the paper under it.
	if _reading_index != null:
		var read_a := -TAU * (0.06 + 0.30 * clampf(reading, 0.0, 1.0))
		_reading_index.rotation.z = read_a
		_reading_index.position.x = sin(read_a) * 0.058
		_reading_index.position.y = 0.22 + cos(read_a) * 0.058

	# THE REFUSAL POSE: deterministic, held for the balk's duration, and never
	# a function of `_t`. The sheet lifts off its seat, the station key swings
	# out of the hasp and the stop lever kicks -- three separate things moving
	# at once, because one 6 mm lift is not a photograph anybody can read.
	var balk := clampf(_balk_left, 0.0, 1.0)
	if balk > 0.0:
		_paper.position.y = 0.22 + 0.026 * balk
		_paper.position.z = 0.112 + 0.020 * balk
		_paper.rotation.x = 0.30 * balk
		if _station_key != null:
			_station_key.rotation.z = 0.72 * balk
			_station_key.position.y = 0.058 + 0.022 * balk
		if _stop_lever != null:
			_stop_lever.rotation.z += 0.22 * balk
	else:
		_paper.position.y = 0.22
		_paper.position.z = 0.112
		_paper.rotation.x = 0.0
		if _station_key != null:
			_station_key.rotation.z = 0.0
			_station_key.position.y = 0.058


func service_wire_card() -> Dictionary:
	return {
		"title": "WATCHMAN'S TIME DETECTOR",
		"body": "The dial turns once a day on the clock's spindle. Round the "
				+ "dial is when; out from the centre is which station. A dial "
				+ "off its pin records a whole night at one instant.",
	}
