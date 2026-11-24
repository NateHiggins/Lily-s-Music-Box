extends Node
## NPC repair pilot, second resident (order w3473eaaf58a9): Malcolm Reed, on the male cast base and the generic
## resident path. His shared walk is measured on his own body and played each frame at the rate that keeps its
## planted foot on the floor; a resident outside the pilot list keeps the plain 1x walk. Headless. Writes a
## schema-2 runtime_contract receipt to OUTPUT when it is set. The foot slip itself is measured by the windowed
## NpcPilotMinaShot with RESIDENT=malcolm_reed.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")

var checks: Array = []
var failures: Array = []
var details := {}


func check(ok: bool, label: String) -> void:
	checks.append({"label": label, "ok": ok})
	if not ok:
		failures.append(label)
	print(("PASS " if ok else "FAIL ") + label)


func _ready() -> void:
	run.call_deferred()


func _resident(id: String) -> Node:
	CastBodies.set_for_test([id])
	var actor := Presentation.new()
	actor.setup(id.capitalize(), id, "", CastBodies.model_for(id))
	actor.externally_driven = true
	add_child(actor)
	for _frame in 8:
		await get_tree().process_frame
	return actor


## Walks `actor` for `seconds` of frame time at `mps`; returns how many frames the rate missed the gait.
func _walk(actor: Node, seconds: float, mps: float) -> Dictionary:
	var player: AnimationPlayer = actor._animation_player
	var gait: ClipGait = actor.walk_gait
	var walked := 0.0
	var off := 0
	var rates := {}
	actor.set_route_motion(true, 0.0, mps)
	while walked < seconds:
		await get_tree().process_frame
		walked += get_process_delta_time()
		actor.set_route_motion(true, 0.0, mps)
		rates[snappedf(player.speed_scale, .05)] = true
		if gait != null and str(player.current_animation) == actor.preferred_walk:
			off += 1 if absf(player.speed_scale - gait.scale_for(player.current_animation_position, mps)) > .25 else 0
	return {"off": off, "rates": rates.size(), "clip": str(player.current_animation)}


func run() -> void:
	var started := Time.get_ticks_msec()
	RealityState.persistence_enabled = false
	ClipGait.clear_cache()
	var malcolm: Node = await _resident("malcolm_reed")
	check(malcolm.cast_body != null and malcolm.mina_animation == null, "Malcolm is on his rebuilt body and the generic path")
	var skeleton: Skeleton3D = malcolm.cast_body.skeleton if malcolm.cast_body != null else null
	var hips: int = skeleton.find_bone("Hips") if skeleton != null else -1
	if hips >= 0:
		var tilt: float = rad_to_deg(skeleton.get_bone_rest(hips).basis.get_rotation_quaternion().get_angle())
		details["hips_rest_degrees"] = snappedf(tilt, .1)
		check(tilt > 5.0, "his body is the male base, hips turned at rest (%.1f deg)" % tilt)
	var gait: ClipGait = malcolm.walk_gait
	check(gait != null, "his walk is measured on his own body")
	if gait != null:
		details["walk_mean_rate"] = snappedf(gait.mean_rate(), .001)
		details["walk_cycle_metres"] = snappedf(gait.cycle_metres, .001)
		check(gait.mean_rate() > .5 and gait.mean_rate() < 2.5, "his walk travels at 1x like a walk, not a run or a shuffle (%.2f m/s)" % gait.mean_rate())
	var level: Dictionary = await _walk(malcolm, 5.0, 1.05)
	details["level"] = level
	check(level.clip == malcolm.preferred_walk, "he walks in the shared walk (%s)" % level.clip)
	check(int(level.off) <= 4, "the playback rate follows the planted foot on the level (%d frames off)" % int(level.off))
	check(int(level.rates) >= 4, "the rate changes through the step (%d rates)" % int(level.rates))
	var stair: Dictionary = await _walk(malcolm, 3.0, .55)
	details["stair_pace"] = stair
	check(int(stair.off) <= 4, "the rate follows the stair pace too (%d frames off)" % int(stair.off))
	malcolm.set_route_motion(false, 0.0, 0.0)
	for _frame in 4:
		await get_tree().process_frame
	check(is_equal_approx(malcolm._animation_player.speed_scale, 1.0) and str(malcolm._animation_player.current_animation) != malcolm.preferred_walk,
			"stopping returns him to his idle at 1x (%s %.2f)" % [malcolm._animation_player.current_animation, malcolm._animation_player.speed_scale])
	malcolm.queue_free()
	await get_tree().process_frame

	# Outside the pilot list the walk is untouched.
	var peter: Node = await _resident("omar_bell")
	check(peter.walk_gait == null, "a resident outside the gate (Omar) keeps the plain walk")
	var plain: Dictionary = await _walk(peter, 2.0, 1.05)
	check(int(plain.rates) == 1 and is_equal_approx(peter._animation_player.speed_scale, 1.0), "his walk plays at 1x as before")
	peter.queue_free()
	await get_tree().process_frame
	_finish(started)


func _finish(started: int) -> void:
	var passed := failures.is_empty()
	var output := OS.get_environment("OUTPUT")
	var written := true
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var result := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": false, "selector": "v2",
				"suite": "NpcPilotGenericGaitTest", "status": "PASS" if passed else "FAIL",
				"scope": "Malcolm Reed's rebuilt male-base body on the generic resident path in isolation: gait measurement, per-frame distance-matched playback at the level and stair paces, stop settling, and the pilot gate. No rendered surface, no foot IK, no route.",
				"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
				"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
					"test_scene_path": "game/" + scene_file_path.trim_prefix("res://"), "test_scene_sha256": FileAccess.get_sha256(scene_file_path)},
				"checks": checks, "failures": failures, "details": details}
		var file := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
		written = file != null
		if written:
			file.store_string(JSON.stringify(result, "\t"))
			file.close()
	print("NPC PILOT GENERIC GAIT ", "PASS" if passed else "FAIL", " ", details)
	get_tree().quit(0 if passed and written else 1)
