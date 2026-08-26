extends Node
## K2-G — the fault has to answer while you are still listening.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/ChirpReachableTest.tscn `
##         -ProjectPath <worktree>/game
##
## THE MEASURED PROBLEM. The authored objective for the one production job is
## "A Vantry point in 2A is issuing a line-test tone. Find it by ear." That
## instruction is correct and specific: three Vantry points exist inside 2A —
## living, bedroom and bathroom — and only the faulted one sounds, so the ear
## is genuinely the discriminator.
##
## The schedule did not honour it. `_chirp_loop` waited randf_range(50, 95)
## BEFORE each chirp and the loop starts at building boot, so a player entering
## 2A arrives at an arbitrary phase: mean wait ~36 s, worst case 95 s. Nothing
## else in the room sounds, so there is no listening to do — only waiting.
##
## This suite pins the schedule's BOUNDS rather than any particular draw, and
## proves the fault stayed a fault.

const HuntScript := preload("res://scripts/game/chirp_hunt.gd")
const HUNT_PATH := "res://scripts/game/chirp_hunt.gd"
const CEILING := 45.0

var failures := 0
var checks := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	await get_tree().process_frame
	_bounds()
	_still_a_fault()
	_fits_the_ceiling()
	_owns_nothing_new()
	_source_discipline()
	_finish()


## The band itself, and the arithmetic the player experience rests on.
func _bounds() -> void:
	var lo: float = HuntScript.CHIRP_MIN
	var hi: float = HuntScript.CHIRP_MAX
	_check(lo > 0.0 and hi > lo,
			"the interval is a real band: %.1f to %.1f s" % [lo, hi])
	_check(hi <= CEILING,
			"the FIRST cue is guaranteed inside the %.0f s ceiling (%.1f s)"
					% [CEILING, hi])
	_check(hi * 2.0 <= CEILING,
			"and a SECOND arrives inside it too (%.1f s), which is what makes "
					% (hi * 2.0) + "the point findable by inference not by luck")
	_check(CEILING - hi >= 15.0,
			"leaving %.1f s of the ceiling for the walk after the first cue"
					% (CEILING - hi))


## The whole risk of this change is turning an intermittent fault into a
## beacon. These are the assertions that would catch that.
func _still_a_fault() -> void:
	var lo: float = HuntScript.CHIRP_MIN
	var hi: float = HuntScript.CHIRP_MAX
	_check(lo >= 8.0,
			"a silence of at least %.1f s between chirps — long enough that the "
					% lo + "player must listen rather than glance")
	_check(hi > lo * 1.4,
			"the interval is genuinely irregular (%.1f-%.1f), so it cannot be "
					% [lo, hi] + "counted like a metronome")
	_check(lo > 1.0,
			"nothing here can produce a continuous tone")


## The arithmetic that the live suite then confirms with a real body.
func _fits_the_ceiling() -> void:
	var hi: float = HuntScript.CHIRP_MAX
	# Worst case: the player crosses the threshold one instant after a chirp.
	var worst_first := hi
	# The measured walk, threshold to under the point, at PlayerController.WALK.
	var walk := 3.72 / 3.0
	_check(worst_first + walk < CEILING,
			"worst case: %.1f s of silence + %.2f s of walking = %.2f s < %.0f"
					% [worst_first, walk, worst_first + walk, CEILING])
	# The old band, for the record, on the same arithmetic.
	_check(95.0 + walk > CEILING,
			"the previous band could not: 95.0 + %.2f = %.2f s" % [walk,
					95.0 + walk])


func _owns_nothing_new() -> void:
	_check(not RealityState.data.has("chirp_schedule")
			and not RealityState.data.has("chirp_reachable")
			and not RealityState.data.has("vantry_hint"),
			"K2-G wrote no save key of its own")
	_check(HuntScript.JOB_ID == "vantry_chirp_2a",
			"the job id is untouched")
	var declared := FileAccess.get_file_as_string(HUNT_PATH)
	_check(declared.contains("const CHIRP_MIN")
			and declared.contains("const CHIRP_MAX"),
			"the schedule is a declared constant of the one owner, not a "
					+ "magic number buried in a loop")


## The change must live inside the existing loop and touch nothing else. The
## window is the constants block through `_on_inspected`, comment-stripped.
func _source_discipline() -> void:
	var text := FileAccess.get_file_as_string(HUNT_PATH)
	var start := text.find("func _chirp_loop")
	var stop := text.find("func _on_inspected")
	_check(start > 0 and stop > start, "the loop is one function")
	var body := ""
	for line in text.substr(start, stop - start).split("\n"):
		var stripped := String(line)
		var hash_at := stripped.find("#")
		if hash_at >= 0:
			stripped = stripped.substr(0, hash_at)
		body += stripped.to_lower() + "\n"
	for word in ["realitystate", "commit(", "realitycases", "first_shift",
			"objective", "player", "global_position", "distance_to", "camera",
			"set_meta", "issue_job", "acknowledge_job", "tween"]:
		_check(not body.contains(word),
				"the loop never touches `%s`" % word)
	_check(body.contains("chirp_min") and body.contains("chirp_max"),
			"but it does read the declared band")
	# The loop must not learn where the player is: a fault that chirps because
	# someone walked in is a beacon wearing a fault's clothes.
	_check(not body.contains("is_inside") or body.contains("is_inside_tree"),
			"and it senses nothing about the listener")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [chirp ok] ", label)
	else:
		failures += 1
		printerr("  [CHIRP FAIL] ", label)


func _finish() -> void:
	print("CHIRP REACHABLE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
