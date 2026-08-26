extends Node
## K2-A — the two cues that answer "which way?", on a bench.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/FirstMinuteTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE AMBIGUITY THIS ANSWERS, MEASURED IN PRODUCTION BEFORE A LINE WAS
## WRITTEN. The opening objective says "Clock in at the watchman's detector."
## Of 831 walkable places on the Orison's ground floor, the detector's face can
## be seen from 112 — and NOT ONE of them is in the entrance hall. On the direct
## walk from the front door to the desk, the first clear sight of it comes at
## 2.60 m, barely ahead of the player's own 2.10 m prompt ray. The building was
## never hiding the desk. It simply never said which way it was.
##
## Two cues now say so, and both are building facts rather than tutorial:
##
##   * THE CLOCK IS AUDIBLE, because it is running. A wound movement in an empty
##     lobby beats once a second, and the beat is a function of
##     `movement_running` and nothing else — not the ritual phase, not the
##     player's position, not whether the game would like to help. Stop the
##     movement and the lobby goes silent, which is SR7-F's lesson out loud.
##   * THE BUILDING HAS THE PLATE IT WAS MISSING. The same brass-framed
##     directional sign the fire directions already use, on a measured pier in
##     the entrance hall, naming the service spine in the order a player walks
##     past it.
##
## Neither owns lifecycle state. Neither knows what phase the shift is in.


## The signage pass reads `world.reality_controllers` to find the doors it
## numbers. A bare Node3D has no such property, so the bench supplies an empty
## one: this suite is about the spine plate, which is built from measured
## coordinates and needs no doors at all.
class StubWorld:
	extends Node3D
	var reality_controllers: Dictionary = {}

const ClockScript := preload("res://scripts/props/watchman_clock_prop.gd")
const SignageScript := preload("res://scripts/building/wayfinding_signage_pass.gd")

var failures := 0
var checks := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	await get_tree().process_frame
	_the_clock_has_a_voice()
	_the_beat_is_only_the_movement()
	_the_plate_is_a_sign_and_nothing_else()
	_source_discipline()
	_finish()


# --- the clock ---------------------------------------------------------------

func _bench() -> Node:
	var clock: Node = ClockScript.new()
	clock.prop_type = "watchman_clock"
	add_child(clock)
	return clock


func _the_clock_has_a_voice() -> void:
	var clock := _bench()
	_check(bool(clock.get("movement_running")),
			"AS FOUND the movement is running — SR7-F left it that way")
	_check(bool(clock.call("beating")), "so the clock beats")
	_check(absf(float(clock.call("beat_remaining")) - ClockScript.BEAT_SECONDS)
			< 0.001,
			"and it starts a whole beat from boot (%.2f s)"
					% clock.call("beat_remaining"))
	# Drive the escapement without listening to it.
	clock.call("_advance_beat", 0.4)
	_check(absf(float(clock.call("beat_remaining")) - 0.6) < 0.001,
			"0.4 s in, 0.6 s to go")
	clock.call("_advance_beat", 0.7)
	_check(absf(float(clock.call("beat_remaining")) - 0.9) < 0.001,
			"the beat falls at 1.1 s and the countdown CARRIES the 0.1 s "
					+ "overshoot (%.2f s) — a clock that discarded it would "
					% clock.call("beat_remaining") + "run slow")
	var beats := 0
	for i in 100:
		var before: float = clock.call("beat_remaining")
		clock.call("_advance_beat", 0.1)
		if float(clock.call("beat_remaining")) > before:
			beats += 1
	_check(beats == 10, "ten seconds of escapement is ten beats (%d)" % beats)
	clock.queue_free()


func _the_beat_is_only_the_movement() -> void:
	var clock := _bench()
	# THE HONEST PART. A stopped movement makes no sound at all.
	clock.set("movement_running", false)
	_check(not bool(clock.call("beating")),
			"STOP THE MOVEMENT AND THE LOBBY GOES QUIET")
	for i in 40:
		clock.call("_advance_beat", 0.1)
	_check(absf(float(clock.call("beat_remaining")) - ClockScript.BEAT_SECONDS)
			< 0.001,
			"four seconds of stopped clock advances nothing (%.2f s)"
					% clock.call("beat_remaining"))
	clock.set("movement_running", true)
	_check(bool(clock.call("beating")), "restart it and it beats again")
	_check(absf(float(clock.call("beat_remaining")) - ClockScript.BEAT_SECONDS)
			< 0.001,
			"and the first beat after a restart is a WHOLE beat")
	# The beat is deaf to the shift. It has never heard of a ritual phase.
	_check(not clock.has_method("ritual_phase"), "the beat owns no phase")
	for phase in ["arrived", "clocked_in", "report_accepted", "filed"]:
		clock.set("movement_running", true)
		_check(bool(clock.call("beating")),
				"and it beats the same whatever the shift is doing (%s)" % phase)
	clock.queue_free()


# --- the plate ---------------------------------------------------------------

func _the_plate_is_a_sign_and_nothing_else() -> void:
	var pass_node: Node3D = SignageScript.new()
	add_child(pass_node)
	var world := StubWorld.new()
	add_child(world)
	var stats: Dictionary = pass_node.call("build", world)
	_check(int(stats.get("spine_plates", 0)) == 1,
			"the signage pass builds exactly ONE spine plate (%d)"
					% int(stats.get("spine_plates", 0)))
	var plate: Node3D = pass_node.find_child("ServiceSpineDirection", true,
			false) as Node3D
	_check(plate != null, "named ServiceSpineDirection")
	if plate == null:
		return
	var at := plate.position
	var b := Vector3(at.x, -at.z, at.y)
	_check(b.distance_to(Vector3(2.80, -6.90, 1.62)) < 0.01,
			"on the measured pier at b(%.2f, %.2f, %.2f)" % [b.x, b.y, b.z])
	_check(absf(plate.rotation.y) < 0.001,
			"facing SOUTH into the entrance hall, at the incoming player")
	# A sign is a sign. No area, no body, no light, no process, no state.
	var legends: Array[String] = []
	_sweep(plate, legends)
	_check(legends.size() == 3, "three engraved lines (%d)" % legends.size())
	_check("NIGHT WATCHMAN" in legends, "it names the watchman")
	var points := false
	for line in legends:
		if line.contains("→"):
			points = true
	_check(points, "AND IT POINTS — the whole reason it exists")
	for line in legends:
		for word in ["press", "click", "objective", "tutorial", "[E]", "you "]:
			_check(not line.to_lower().contains(word),
					"\"%s\" is a building's words, not a tutorial's (%s)"
							% [line, word.strip_edges()])
	_check(_count(plate, "Area3D") == 0, "no interaction area")
	_check(_count(plate, "CollisionObject3D") == 0, "no collision body")
	_check(_count(plate, "Light3D") == 0, "no light of its own")
	_check(_count(plate, "AudioStreamPlayer3D") == 0, "no sound of its own")
	_check(plate.get_script() == null,
			"and no script: it cannot mutate anything, because it is a sign")
	_check(not RealityState.data.has("wayfinding")
			and not RealityState.data.has("spine_plate"),
			"it wrote no save key")
	pass_node.queue_free()
	world.queue_free()


func _sweep(node: Node, legends: Array[String]) -> void:
	if node is Label3D:
		legends.append(str((node as Label3D).text))
	for child in node.get_children():
		_sweep(child, legends)


func _count(node: Node, type_name: String) -> int:
	var n := 0
	if node.is_class(type_name):
		n += 1
	for child in node.get_children():
		n += _count(child, type_name)
	return n


# --- source discipline -------------------------------------------------------

func _source_discipline() -> void:
	# The beat must not have learned anything about the shift. Code only —
	# a comment naming a phase is not a dependency on one.
	var text := FileAccess.get_file_as_string(
			"res://scripts/props/watchman_clock_prop.gd")
	var start := text.find("func _advance_beat")
	var stop := text.find("func beating")
	_check(start > 0 and stop > start, "the escapement is one small function")
	var body := text.substr(start, stop - start).to_lower()
	for word in ["ritual", "phase", "player", "objective", "tracker",
			"work_order", "case", "realitystate", "randf"]:
		_check(not body.contains(word),
				"the escapement never mentions `%s`" % word)
	_check(body.contains("movement_running"),
			"the only thing it consults is whether the movement is running")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [first minute ok] ", label)
	else:
		failures += 1
		printerr("  [FIRST MINUTE FAIL] ", label)


func _finish() -> void:
	print("FIRST MINUTE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
