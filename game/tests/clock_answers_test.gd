extends Node
## K2-B — the clock's answer and the paper's arrival, on a bench.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/ClockAnswersTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE AMBIGUITY THIS ANSWERS, MEASURED IN PRODUCTION BEFORE A LINE WAS
## WRITTEN. Standing at the pose a hand actually clocks in from —
## b(4.84, -1.50, 1.62), the nearest place whose own 2.10 m prompt ray still
## lands on DetectorReach — pressing E changed NOTHING on the apparatus. Station
## key, stop lever, paper pivot, movement hand and both proof marks were
## byte-identical at 0.15 s, 0.5 s, 1.0 s and 3.0 s. The only answer was a
## `pop`. Meanwhile the thing that did change was the report arriving on the
## register's spindle, 0.69 m away at YAW +58.5 DEGREES against a camera
## frustum half-angle of +-35.0 — outside the frame, with the register body
## outside on the pitch axis as well.
##
## So the clock answers where the hand is: the station key turns, the plunger
## comes down on the sheet, and it leaves a mark. And a foot to the right the
## paper stops appearing and starts ARRIVING, because motion at 58 degrees
## off-axis is what peripheral vision is for.
##
## NEITHER PROP OWNS ANYTHING NEW. The clock's mark is DERIVED from
## FirstShiftDirector's phase and stored nowhere; the register's landing is
## derived from its own `slip_available()`. Both are transient presentation:
## nothing here is saved, and nothing here can be replayed into a second work
## order or a second case transition, because neither prop has ever heard of
## either.

const ClockScript := preload("res://scripts/props/watchman_clock_prop.gd")
const RegisterScript := preload("res://scripts/props/night_register_prop.gd")
const CLOCK_PATH := "res://scripts/props/watchman_clock_prop.gd"

var failures := 0
var checks := 0


## A director that answers like the real one and records every word said to it.
## The clock's whole sanctioned vocabulary is `ritual_phase`, `clock_in` and
## `clock_out`; this proves it says nothing else.
## It EXTENDS the real director rather than standing beside it, because
## `bind_first_shift` is statically typed and a plain Node is silently refused —
## the first version of this bench "passed" 21/21 with every interesting section
## skipped on an out-of-bounds array, which is the most dangerous kind of green.
class StubDirector:
	extends FirstShiftDirector
	var phase := "arrived"
	var heard: Array[String] = []
	var allow := true

	func ritual_phase() -> String:
		return phase

	func clock_in() -> bool:
		heard.append("clock_in")
		if not allow or phase != "arrived":
			return false
		phase = "clocked_in"
		return true

	func clock_out() -> bool:
		heard.append("clock_out")
		if phase != "filed":
			return false
		phase = "complete"
		return true

	func tour_key_carried() -> bool:
		return false


func _ready() -> void:
	RealityState.persistence_enabled = false
	await get_tree().process_frame
	_the_clock_answers()
	_only_a_real_clock_in_arms_it()
	_the_mark_is_derived_not_owned()
	_abort_restores_presentation_only()
	_deterministic()
	_the_paper_arrives()
	_source_discipline()
	_finish()


func _bench() -> Array:
	var clock: Node = ClockScript.new()
	clock.prop_type = "watchman_clock"
	add_child(clock)
	var director := StubDirector.new()
	add_child(director)
	clock.call("bind_first_shift", director)
	return [clock, director]


# --- the answer --------------------------------------------------------------

func _the_clock_answers() -> void:
	var bench := _bench()
	var clock: Node = bench[0]
	var key: Node3D = clock.get_node("StationKey") as Node3D
	var head: Node3D = clock.get_node("PunchHead") as Node3D
	_check(key != null and head != null,
			"the apparatus has a station key and the plunger it drives")
	var rest_angle := key.rotation.z
	var rest_z := head.position.z
	_check(not bool(clock.call("key_turning")), "AS FOUND nothing is turning")

	_check(bool(clock.call("interact_control", "detector", null)),
			"the player clocks in through the production seam")
	_check(bool(clock.call("key_turning")),
			"AND THE KEY TURNS — at the apparatus the hand is on")
	_check(absf(float(clock.call("key_turn_remaining"))
			- ClockScript.KEY_TURN_SECONDS) < 0.001,
			"a whole throw of %.2f s" % ClockScript.KEY_TURN_SECONDS)
	# Drive it to the peak without watching it.
	clock.call("_process", ClockScript.KEY_TURN_SECONDS * 0.5)
	_check(absf(key.rotation.z - rest_angle) > 1.0,
			"the key is a full %.2f rad off its rest at the peak"
					% absf(key.rotation.z - rest_angle))
	_check(absf(head.position.z - rest_z) > 0.02,
			"and the plunger is %.0f mm down on the sheet"
					% (absf(head.position.z - rest_z) * 1000.0))
	# And it comes home.
	clock.call("_process", ClockScript.KEY_TURN_SECONDS)
	_check(not bool(clock.call("key_turning")), "the throw ends")
	_check(absf(key.rotation.z - rest_angle) < 0.001
			and absf(head.position.z - rest_z) < 0.001,
			"and every part comes back exactly where it started")
	(bench[0] as Node).queue_free()
	(bench[1] as Node).queue_free()


func _only_a_real_clock_in_arms_it() -> void:
	var bench := _bench()
	var clock: Node = bench[0]
	var director: StubDirector = bench[1]

	# A REFUSED PRESS ARMS NOTHING.
	#
	# Note what a refused press DOES do, because the first version of this bench
	# asserted the wrong thing: `interact_control` still returns true, because
	# with the ritual not claiming the clock the press falls through to the
	# detector's own service path. That is right — a detector nobody is clocking
	# in on is still a clock a man can work on. What must not happen is the
	# ANSWER, and it does not.
	director.allow = false
	var before: float = clock.call("key_turn_remaining")
	clock.call("interact_control", "detector", null)
	_check(not bool(clock.call("key_turning"))
			and absf(float(clock.call("key_turn_remaining")) - before) < 0.001,
			"A CLOCK-IN THE OWNER REFUSES DOES NOT TURN THE KEY — the answer "
					+ "is to the fact, never to the press")
	_check(director.phase == "arrived", "and the owner's phase never moved")
	director.allow = true

	# The real one.
	_check(bool(clock.call("interact_control", "detector", null)),
			"the accepted clock-in turns the key")
	clock.call("_process", ClockScript.KEY_TURN_SECONDS)
	_check(not bool(clock.call("key_turning")), "and it comes home")

	# IDEMPOTENCE. The shift is open; pressing again is not a second shift.
	var said := director.heard.size()
	for i in 4:
		clock.call("interact_control", "detector", null)
	_check(not bool(clock.call("key_turning")),
			"FOUR MORE PRESSES DO NOT REPLAY THE ANSWER")
	_check(director.heard.size() == said,
			"and say nothing further to the owner (%d words, unchanged)"
					% director.heard.size())
	_check(director.phase == "clocked_in", "the phase is where the owner put it")
	for word in director.heard:
		_check(word in ["clock_in", "clock_out"],
				"the clock's whole vocabulary against its owner is `%s`" % word)
	(bench[0] as Node).queue_free()
	(bench[1] as Node).queue_free()


# --- the mark ----------------------------------------------------------------

func _the_mark_is_derived_not_owned() -> void:
	var bench := _bench()
	var clock: Node = bench[0]
	var director: StubDirector = bench[1]
	var mark: Node3D = clock.get_node("PaperPivot/ShiftPunch") as Node3D
	_check(mark != null, "tonight's punch is on the SHEET's own pivot")
	_check(not bool(clock.call("shift_punched")) and not mark.visible,
			"AS FOUND the sheet carries no shift punch")
	# The mark follows the OWNER's phase, with no interaction at all: this prop
	# is drawing a fact, not keeping one.
	for phase in ["clocked_in", "report_accepted", "returned", "filed"]:
		director.phase = phase
		clock.call("_refresh_mechanism")
		_check(bool(clock.call("shift_punched")) and mark.visible,
				"the punch is on the sheet at phase %s, drawn from the owner "
						% phase + "and never touched here")
	for phase in ["arrived", "complete"]:
		director.phase = phase
		clock.call("_refresh_mechanism")
		_check(not bool(clock.call("shift_punched")) and not mark.visible,
				"and off it at phase %s" % phase)
	# THE POINT OF THE MARK. The dial is off its pin, so the punch lands where
	# the SHEET is standing, not at the hour — SR7-F's fault, written by the
	# player's own hand on their first night.
	_check(not bool(clock.get("dial_seated")),
			"and the dial is still off its pin, which is why that mark is a lie")
	(bench[0] as Node).queue_free()
	(bench[1] as Node).queue_free()


func _abort_restores_presentation_only() -> void:
	var bench := _bench()
	var clock: Node = bench[0]
	var director: StubDirector = bench[1]
	var before: String = JSON.stringify(clock.call("maintenance_snapshot"))
	clock.call("interact_control", "detector", null)
	clock.call("_process", ClockScript.KEY_TURN_SECONDS * 0.4)
	_check(bool(clock.call("key_turning")), "a throw is under way")
	var owner_phase := director.phase
	clock.call("restore_maintenance_snapshot", JSON.parse_string(before))
	_check(JSON.stringify(clock.call("maintenance_snapshot")) == before,
			"ABORT puts every owned fact back, byte for byte")
	_check(director.phase == owner_phase,
			"AND DOES NOT REWRITE THE OWNER — the shift is still %s"
					% director.phase)
	_check(bool(clock.call("shift_punched")),
			"so the punch is still on the sheet, because the owner still says "
					+ "the shift is open")
	(bench[0] as Node).queue_free()
	(bench[1] as Node).queue_free()


func _deterministic() -> void:
	var poses: Array[String] = []
	for run in 2:
		var bench := _bench()
		var clock: Node = bench[0]
		clock.call("interact_control", "detector", null)
		for i in 5:
			clock.call("_process", 0.05)
		var key: Node3D = clock.get_node("StationKey") as Node3D
		var head: Node3D = clock.get_node("PunchHead") as Node3D
		poses.append("%.6f|%.6f|%.6f" % [key.rotation.z, key.position.z,
				head.position.z])
		(bench[0] as Node).queue_free()
		(bench[1] as Node).queue_free()
	_check(poses[0] == poses[1],
			"the same throw driven the same way is the same pose, exactly")


# --- the paper ---------------------------------------------------------------

func _the_paper_arrives() -> void:
	var register: Node = RegisterScript.new()
	register.prop_type = "night_register"
	add_child(register)
	var slip: Node3D = register.get_node("ReportSlip") as Node3D
	var spindle: Node3D = register.get_node("ReportSpindle") as Node3D
	_check(slip != null and spindle != null, "the board has a slip and a spike")
	_check(not bool(register.call("slip_landing")),
			"AS FOUND nothing is landing")
	var rest_y := slip.position.y
	var rest_rot := spindle.rotation.z

	# A BOARD REBUILT WITH PAPER ALREADY ON IT DOES NOT PRETEND IT JUST LANDED.
	# This is what a save resumed mid-shift looks like, and nothing arrived.
	register.call("_refresh_slip_visibility")
	_check(not bool(register.call("slip_landing")),
			"a refresh on a board that has always looked like this lands nothing")

	# A real arrival.
	register.set("_slip_was_available", false)
	register.set("_landing_armed", true)
	if not register.call("slip_available"):
		# Force the only condition the landing reads, without touching a job.
		register.set("slip_taken", false)
	register.call("_refresh_slip_visibility")
	var landed := bool(register.call("slip_landing"))
	_check(landed or not register.call("slip_available"),
			"a false-to-true transition is what starts a landing")
	if landed:
		register.call("_process", RegisterScript.SLIP_LANDING_SECONDS * 0.5)
		_check(absf(slip.position.y - rest_y) > 0.01,
				"the sheet is %.0f mm up the spike mid-fall"
						% (absf(slip.position.y - rest_y) * 1000.0))
		_check(absf(spindle.rotation.z - rest_rot) > 0.05,
				"and the spindle has nodded %.2f rad under it"
						% absf(spindle.rotation.z - rest_rot))
		register.call("_process", RegisterScript.SLIP_LANDING_SECONDS)
		_check(not bool(register.call("slip_landing")), "the landing ends")
		_check(absf(slip.position.y - rest_y) < 0.001
				and absf(spindle.rotation.z - rest_rot) < 0.001,
				"and every part settles exactly where it belongs")
	_check(not RealityState.data.has("shift_punch")
			and not RealityState.data.has("slip_landing")
			and not RealityState.data.has("key_turn"),
			"K2-B wrote no save key of its own")
	register.queue_free()


# --- source discipline -------------------------------------------------------

func _source_discipline() -> void:
	var text := FileAccess.get_file_as_string(CLOCK_PATH)
	var code := ""
	for line in text.split("\n"):
		var stripped := String(line)
		var hash_at := stripped.find("#")
		if hash_at >= 0:
			stripped = stripped.substr(0, hash_at)
		code += stripped.to_lower() + "\n"
	# The clock must never have learned to own a job, a case or a save.
	for word in ["workorders", "realitycases", "realitystate", "activate_case",
			"acknowledge_job", "job_stage", "serialize_jobs", "show_objective",
			"objectivetracker", "current_case_id", "commit(", "persist"]:
		_check(not code.contains(word),
				"the clock never mentions `%s`" % word)
	# Its whole sanctioned vocabulary against the opening owner.
	for allowed in ["ritual_phase", "clock_in", "clock_out"]:
		_check(code.contains(allowed), "it does say `%s`, which is the seam"
				% allowed)
	_check(not code.contains("randf") and not code.contains("randi"),
			"and nothing about this answer is random")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [clock answers ok] ", label)
	else:
		failures += 1
		printerr("  [CLOCK ANSWERS FAIL] ", label)


func _finish() -> void:
	print("CLOCK ANSWERS TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
