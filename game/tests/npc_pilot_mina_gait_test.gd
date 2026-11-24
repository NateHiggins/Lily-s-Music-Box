extends Node
## NPC repair pilot (order w3473eaaf58a9): distance matching on Mina's rebuilt body. The travelling clips are measured
## on her skeleton at install, play frame by frame at the rate that keeps the planted foot on the floor, the stop
## settles without the sliding stop clip, and the route paces stair edges without touching the base route_speed.
## Headless. Writes a schema-2 runtime_contract receipt to OUTPUT when it is set. No rendered surface: the foot
## slip itself is measured by the windowed NpcPilotMinaShot.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const Route := preload("res://scripts/characters/orison_v2_resident_route.gd")

var checks: Array = []
var failures: Array = []
var details := {}


func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	var started := Time.get_ticks_msec()
	RealityState.persistence_enabled = false
	ClipGait.clear_cache()
	CastBodies.set_for_test(["mina_vale"])
	var mina := Presentation.new()
	mina.setup("Mina Vale", "mina_vale", "2A", CastBodies.model_for("mina_vale"))
	mina.externally_driven = true
	add_child(mina)
	await frames(8)
	var behaviour = mina.mina_animation
	check(mina.cast_body != null and behaviour != null, "Mina's cast body installs her animation behaviour")
	if behaviour == null:
		_finish(started)
		return
	var player: AnimationPlayer = mina._animation_player
	for clip: String in ["mina_walk", "mina_stairs_up", "mina_stairs_down", "mina_walk_start"]:
		check(behaviour.gaits.has(clip), "%s is measured on her body" % clip)
	var walk: ClipGait = behaviour.gaits.get("mina_walk")
	if walk != null:
		details["walk_mean_rate"] = snappedf(walk.mean_rate(), .001)
		details["walk_cycle_metres"] = snappedf(walk.cycle_metres, .001)
		check(walk.mean_rate() > .5 and walk.mean_rate() < 1.1, "her walk covers a person's ground at 1x (%.2f m/s)" % walk.mean_rate())
		check(walk.scale_for(0.0, 100.0) == ClipGait.MAX_SCALE and walk.scale_for(0.0, .001) == ClipGait.MIN_SCALE, "the playback rate is bounded")
	check(not behaviour.gaits.has("mina_idle_calm") and not behaviour.gaits.has("mina_turn_around"), "idles and turns keep the plain rate")

	# From a standstill into the walk: the start clip is matched too, then the walk; every frame's rate is the gait's.
	mina.set_route_motion(true, 0.0, 1.05)
	var mismatches := 0
	var rates := {}
	var walked := 0.0
	# Seconds, not frames: headless frames are short, and the walk start runs about 2 s of clip time.
	while walked < 7.0:
		await get_tree().process_frame
		walked += get_process_delta_time()
		mina.set_route_motion(true, 0.0, 1.05)
		var gait: ClipGait = behaviour.gaits.get(str(player.current_animation))
		if gait == null:
			continue
		var want := gait.scale_for(player.current_animation_position, 1.05)
		mismatches += 1 if absf(player.speed_scale - want) > .25 else 0
		rates[snappedf(player.speed_scale, .05)] = true
	details["walk_rate_mismatches"] = mismatches
	details["walk_distinct_rates"] = rates.size()
	check(str(player.current_animation) == "mina_walk", "she settles into her walk (%s)" % player.current_animation)
	check(mismatches <= 8, "the playback rate follows the clip's planted foot (%d frames off)" % mismatches)
	check(rates.size() >= 4, "the rate changes through the step, not one scale (%d rates)" % rates.size())

	# Stopping: the route has stopped the body, so the stop clip (which walks on) is skipped.
	mina.set_route_motion(false, 0.0, 0.0)
	await frames(6)
	check(str(player.current_animation) != "mina_walk_stop", "a stop settles straight into the idle (%s)" % player.current_animation)

	# Stairs: the stair clip at the climbing pace, within bounds.
	mina.set_route_motion(true, RISE_SLOPE, Route.STAIR_PACE)
	var climbed := 0.0
	while climbed < 7.0:
		await get_tree().process_frame
		climbed += get_process_delta_time()
		mina.set_route_motion(true, RISE_SLOPE, Route.STAIR_PACE)
	check(str(player.current_animation) == "mina_stairs_up", "she climbs in her stair clip (%s)" % player.current_animation)
	check(player.speed_scale >= ClipGait.MIN_SCALE and player.speed_scale <= ClipGait.MAX_SCALE, "the climb plays within bounds (%.2f)" % player.speed_scale)
	mina.queue_free()
	await frames(2)

	# The route: stair edges are paced, the flat is not, and the base pace is untouched.
	var route = Route.new()
	check(is_equal_approx(route._pace_on(Vector3.ZERO, Vector3(.285, .16, 0)), Route.STAIR_PACE), "a rising stair edge is walked at the stair pace")
	check(is_equal_approx(route._pace_on(Vector3(0, 1.6, 0), Vector3(.285, 1.44, 0)), Route.STAIR_PACE), "a falling stair edge is walked at the stair pace")
	check(is_equal_approx(route._pace_on(Vector3.ZERO, Vector3(2, .05, 0)), 1.05), "a level or ramped floor keeps the base pace")
	check(is_equal_approx(route.route_speed, 1.05), "the base route_speed stays 1.05")
	route.free()
	_finish(started)


const RISE_SLOPE := .16 / .285


func _finish(started: int) -> void:
	var passed := failures.is_empty()
	var output := OS.get_environment("OUTPUT")
	var written := true
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": false, "selector": "v2",
				"suite": "NpcPilotMinaGaitTest", "status": "PASS" if passed else "FAIL",
				"scope": "Mina's rebuilt cast body in isolation: gait measurement, per-frame distance-matched playback, stop settling, stair pacing in the route. No rendered surface, no foot IK, no other resident.",
				"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
				"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
					"test_scene_path": "game/" + scene_file_path.trim_prefix("res://"), "test_scene_sha256": FileAccess.get_sha256(scene_file_path)},
				"checks": checks, "failures": failures, "details": details}
		var file := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
		written = file != null
		if written:
			file.store_string(JSON.stringify(result, "\t"))
			file.close()
	print("NPC PILOT MINA GAIT ", "PASS" if passed else "FAIL", " ", details)
	get_tree().quit(0 if passed and written else 1)
