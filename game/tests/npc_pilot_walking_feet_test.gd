extends Node3D
## Walking foot placement (order w3473eaaf58a9; Lily's ruling npc_generic_stairs_20261124). On a stair of the
## house's dimensions with collider treads, the two pilot bodies (Mina on the female base, Malcolm on the male) walk
## the ramp line as the route carries them; foot placement keeps their feet on the tread tops instead of in them, on
## the level it leaves the clip alone, and no bone is written twice. A resident outside the pilot is untouched.
## Headless. Writes a schema-2 runtime_contract receipt to OUTPUT when it is set; the windowed NpcPilotMinaShot
## (sink_* figures) is the visual measurement.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const RISE := 0.16
const TREAD := 0.285
const RISERS := 10
const STAIR_X := 3.0

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


func _solid(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child(body)


## A player-sized CharacterBody3D standing on the fifth tread and a RigidBody3D crate resting on the third, both on
## layer 1 like the player and loose props, both in the feet's path.
func _intruders() -> Array[Node]:
	var bodies: Array[Node] = []
	var player := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.3
	capsule_shape.height = 1.75
	capsule.shape = capsule_shape
	player.add_child(capsule)
	player.collision_layer = 1
	player.position = Vector3(STAIR_X + 4.5 * TREAD, 5 * RISE + 0.875, 0)
	add_child(player)
	bodies.append(player)
	var crate := RigidBody3D.new()
	crate.freeze = true
	var box := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.25, 0.3, 0.6)
	box.shape = box_shape
	crate.add_child(box)
	crate.collision_layer = 1
	crate.position = Vector3(STAIR_X + 2.5 * TREAD, 3 * RISE + 0.15, 0)
	add_child(crate)
	bodies.append(crate)
	return bodies


func _floor_at(x: float) -> float:
	if x < STAIR_X:
		return 0.0
	return minf(floor((x - STAIR_X) / TREAD) + 1.0, RISERS) * RISE


func _intruder_tread_support(actor: Node3D) -> Dictionary:
	var samples := 0
	var mismatches: Array[Dictionary] = []
	for tread: int in [2, 4]:
		for fraction: float in [0.25, 0.5, 0.75]:
			for z: float in [-0.24, 0.0, 0.24]:
				var x := STAIR_X + (tread + fraction) * TREAD
				var ramp_y := (tread + fraction) * RISE
				var expected := (tread + 1) * RISE
				var at := Vector3(x, ramp_y, z)
				var actual: float = actor.walking_feet._floor_under(actor.get_world_3d(), at, ramp_y)
				samples += 1
				if not is_finite(actual) or not is_equal_approx(actual, expected):
					mismatches.append({"at": str(at), "expected": expected, "actual": str(actual)})
	return {"samples": samples, "mismatches": mismatches}


## Walks `actor` from `from_x` for `seconds` along +x at `pace`, height on the ramp line, and returns the median and
## 90th percentile of how far the deepest heel or toe joint sits below the floor under it, and the largest offset
## the stage asked for.
func _walk(actor: Node3D, from_x: float, seconds: float, pace: float, slope: float) -> Dictionary:
	var skeleton: Skeleton3D = actor.cast_body.skeleton
	var joints: Array[int] = [skeleton.find_bone("LeftToeBase"), skeleton.find_bone("RightToeBase"),
			skeleton.find_bone("LeftFoot"), skeleton.find_bone("RightFoot")]
	actor.global_position = Vector3(from_x, 0, 0)
	actor.global_rotation.y = PI * 0.5
	var x := from_x
	var t := 0.0
	var sinks: Array[float] = []
	## The lowest heel or toe joint's height above the floor under it: lifted onto something that is not the
	## floor, it rises.
	var hovers: Array[float] = []
	var asked := 0.0
	while t < seconds:
		await get_tree().physics_frame
		await get_tree().process_frame
		var delta := get_process_delta_time()
		t += delta
		x += pace * delta
		actor.global_position = Vector3(x, clampf((x - STAIR_X) / TREAD * RISE, 0.0, RISERS * RISE) if slope != 0.0 else 0.0, 0)
		actor.set_route_motion(true, slope, pace)
		if t < 0.6:
			continue
		var world := skeleton.global_transform
		var deepest := -INF
		var placed: Array[Vector3] = []
		if actor.walking_feet != null and pipeline_on(actor):
			placed = actor.walking_feet.last_feet_world
		if placed.is_empty():
			for bone: int in joints:
				placed.append(world * skeleton.get_bone_global_pose(bone).origin)
		for p: Vector3 in placed:
			deepest = maxf(deepest, (_floor_at(p.x) if slope != 0.0 else 0.0) - p.y)
		sinks.append(deepest)
		hovers.append(-deepest)
		if actor.walking_feet != null:
			asked = maxf(asked, absf(float(actor.walking_feet.last_offsets[0])))
	sinks.sort()
	hovers.sort()
	return {"hover_p90": snappedf(hovers[hovers.size() * 9 / 10], .001), "hover_max": snappedf(hovers[hovers.size() - 1], .001),"sink_median": snappedf(sinks[sinks.size() / 2], .001), "sink_p90": snappedf(sinks[sinks.size() * 9 / 10], .001),
			"largest_offset": snappedf(asked, .001), "frames": sinks.size()}


## The stage is installed and switched on (the comparison climb switches it off).
func pipeline_on(actor: Node3D) -> bool:
	return actor.walking_feet != null and actor.walking_feet.active


func _resident(id: String) -> Node3D:
	CastBodies.set_for_test([id])
	var actor: Node3D = Presentation.new()
	actor.setup(id.capitalize(), id, "", CastBodies.model_for(id))
	actor.externally_driven = true
	add_child(actor)
	for _frame in 8:
		await get_tree().process_frame
	var attention: Node = actor.cast_body.get("attention") if actor.cast_body != null else null
	if attention != null:
		attention.staged_target = Vector3(20, 1.5, 0)
	return actor


func run() -> void:
	var started := Time.get_ticks_msec()
	RealityState.persistence_enabled = false
	_solid(Vector3(30, 0.02, 2), Vector3(0, -0.01, 0))
	for i in RISERS:
		var top := (i + 1) * RISE
		_solid(Vector3(TREAD, top, 2), Vector3(STAIR_X + (i + 0.5) * TREAD, top * 0.5, 0))
	_solid(Vector3(3, RISERS * RISE, 2), Vector3(STAIR_X + RISERS * TREAD + 1.5, RISERS * RISE * 0.5, 0))
	for frame in 3:
		await get_tree().physics_frame
	# RESIDENTS=a,b,... checks a batch; the default is the two pilot bodies.
	var who := OS.get_environment("RESIDENTS")
	var residents: PackedStringArray = who.split(",", false) if not who.is_empty() else PackedStringArray(["mina_vale", "malcolm_reed"])
	for id: String in residents:
		var actor: Node3D = await _resident(id)
		check(actor.walking_feet != null, "%s has walking foot placement installed" % id)
		if actor.walking_feet == null:
			actor.queue_free()
			continue
		var pipeline: Node = actor.cast_body.get("attention").pipeline
		var level: Dictionary = await _walk(actor, -4.0, 2.5, 1.05, 0.0)
		check(float(level.largest_offset) < 0.01, "%s on the level: the clip is left alone (largest offset %.3f m)" % [id, float(level.largest_offset)])
		var on: Dictionary = await _walk(actor, STAIR_X + 0.2, 3.5, 0.55, RISE / TREAD)
		check(float(on.largest_offset) > 0.05, "%s on the stair: the tread under a foot is found (largest offset %.3f m)" % [id, float(on.largest_offset)])
		check(int(pipeline.refused_writes) == 0 and actor.walking_feet.get_index() == pipeline.get_index() + 1,
				"%s: the stage runs straight after the pose pipeline, which refuses no write (%d refused)" % [id, int(pipeline.refused_writes)])
		# Bodies that are not the floor, on the stair in the feet's path: a player-sized body standing on a tread, and
		# a loose crate resting on one. The feet must still follow the treads, as in the clear climb.
		var clear_support := _intruder_tread_support(actor)
		var intruders := _intruders()
		for _frame in 2:
			await get_tree().physics_frame
		var crowded_support := _intruder_tread_support(actor)
		details[id + "_support"] = {"clear": clear_support, "crowded": crowded_support}
		check(clear_support.mismatches.is_empty() and crowded_support.mismatches.is_empty(),
				"%s: fixed samples read the tread under both clear and crowded columns" % id)
		var crowded: Dictionary = await _walk(actor, STAIR_X + 0.2, 3.5, 0.55, RISE / TREAD)
		for body: Node in intruders:
			body.queue_free()
		await get_tree().physics_frame
		details[id + "_crowded"] = crowded
		check(float(crowded.hover_p90) < float(on.hover_p90) + 0.02 and float(crowded.hover_max) < float(on.hover_max) + 0.03,
				"%s's feet follow the treads past a player body and a loose crate (hover p90 %.3f m vs %.3f m, peak %.3f m vs %.3f m)" %
				[id, float(crowded.hover_p90), float(on.hover_p90), float(crowded.hover_max), float(on.hover_max)])
		# The same climb without the stage, for the comparison.
		actor.walking_feet.active = false
		var off: Dictionary = await _walk(actor, STAIR_X + 0.2, 3.5, 0.55, RISE / TREAD)
		var per_frame := float(actor.walking_feet.cost_usec) / maxf(float(actor.walking_feet.worked_frames), 1.0)
		details[id] = {"level": level, "stair_on": on, "stair_off": off, "usec_per_frame": snappedf(per_frame, .1),
				"rays_per_frame": snappedf(float(actor.walking_feet.rays) / maxf(float(actor.walking_feet.worked_frames), 1.0), .01)}
		check(per_frame < 250.0, "%s: the stage costs %.0f us a frame while walking" % [id, per_frame])
		check(float(on.sink_median) < float(off.sink_median) - 0.03,
				"%s's feet stand on the treads, not in them (sink median %.3f m with, %.3f m without)" % [id, float(on.sink_median), float(off.sink_median)])
		actor.set_route_motion(false, 0.0, 0.0)
		actor.queue_free()
		await get_tree().process_frame
	# Every regular resident is in the gate now; Adela's rebuilt body (staff) is the outside witness.
	var peter: Node3D = await _resident("adela_voss")
	check(peter.cast_body != null, "Adela's rebuilt body is mounted for the witness")
	check(peter.walking_feet == null, "a body outside the gate (Adela) has no foot placement")
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
				"suite": "NpcPilotWalkingFeetTest", "status": "PASS" if passed else "FAIL",
				"scope": "Walking foot placement on selected rebuilt bodies over a synthetic stair. Clear and crowded columns sample the same tread positions before comparing the timed climbs. No production stair or rendered surface.",
				"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
				"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": FileAccess.get_sha256(get_script().resource_path),
					"test_scene_path": "game/" + scene_file_path.trim_prefix("res://"), "test_scene_sha256": FileAccess.get_sha256(scene_file_path)},
				"checks": checks, "failures": failures, "details": details}
		var file := FileAccess.open(output.path_join("runtime_contract.json"), FileAccess.WRITE)
		written = file != null
		if written:
			file.store_string(JSON.stringify(result, "\t"))
			file.close()
	print("NPC PILOT WALKING FEET ", "PASS" if passed else "FAIL", " ", details)
	get_tree().quit(0 if passed and written else 1)
