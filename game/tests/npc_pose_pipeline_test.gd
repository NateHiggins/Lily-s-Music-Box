extends Node
## The pose pipeline on the cast's present bodies, with no building loaded:
## Mina and Cal stand side by side in their idle clips and are told to attend
## to a point. The head must land on the point when a neck can reach it, stop
## at the neck's limits when it cannot, get there without a jump, return to the
## clip when released, and every bone must have one writer. Adela's and the
## doodle's skeletons must also be recognised. With SHOT_DIR and a window it
## saves captures.

const Pipeline := preload("res://scripts/characters/pose_pipeline.gd")
const STEP := 1.0 / 60.0

var _fails := 0
var _checks := 0
var _stage: Node3D
var _camera: Camera3D
var _marker: MeshInstance3D
var _actors: Dictionary = {}


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _model_path(id: String) -> String:
	for extension: String in ["gltf", "glb"]:
		var path := "res://assets/characters/%s/%s.%s" % [id, id, extension]
		if ResourceLoader.exists(path):
			return path
	return ""


func _stand(id: String, at: Vector3, animate: bool) -> Dictionary:
	var scene := load(_model_path(id)) as PackedScene
	if scene == null:
		return {}
	var model := scene.instantiate() as Node3D
	_stage.add_child(model)
	model.position = at
	var player: AnimationPlayer = null
	if animate:
		var found := model.find_children("*", "AnimationPlayer", true, false)
		if found.is_empty():
			ResidentMovesLibrary.apply(model)
			found = model.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			player = found[0] as AnimationPlayer
			var chosen := ""
			for clip: String in player.get_animation_list():
				var plain := clip.to_lower()
				if "idle" in plain and not ("sit" in plain or "seat" in plain) and (chosen.is_empty() or clip.length() < chosen.length()):
					chosen = clip
			print("  %s clips: %s; standing in '%s'" % [id, player.get_animation_list(), chosen])
			if not chosen.is_empty():
				player.play(chosen)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return {}
	var skeleton := skeletons[0] as Skeleton3D
	var pipeline := Pipeline.new()
	pipeline.name = "PosePipeline"
	skeleton.add_child(pipeline)
	var bound: bool = pipeline.bind(skeleton)
	pipeline.fixed_delta = STEP
	return {"id": id, "model": model, "skeleton": skeleton, "pipeline": pipeline, "bound": bound, "player": player}


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _degrees(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(a.normalized().angle_to(b.normalized()))


## Where the actor's own front, side and up point in the world.
func _axes(actor: Dictionary) -> Dictionary:
	var basis: Basis = (actor.skeleton as Skeleton3D).global_transform.basis.orthonormalized()
	var forward: Vector3 = basis * (actor.pipeline.profile.forward as Vector3)
	var up: Vector3 = basis * (actor.pipeline.profile.up as Vector3)
	return {"forward": forward, "up": up, "side": up.cross(forward).normalized()}


func _snap(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	for index in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("POSE PIPELINE SHOT: ", label)


func _build_stage() -> void:
	_stage = Node3D.new()
	add_child(_stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.32, 0.33, 0.35)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.75, 0.78)
	environment.environment.ambient_light_energy = 0.7
	_stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 150, 0)
	_stage.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 32
	_stage.add_child(_camera)
	_camera.current = true
	_marker = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.05
	ball.height = 0.1
	_marker.mesh = ball
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.9, 0.2, 0.1)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = paint
	_stage.add_child(_marker)


func _ready() -> void:
	# Explicit real-asset mode; the default legacy regression path is unchanged.
	if not OS.get_environment("MPFB_GLB_DIR").is_empty():
		var probe: Node = (load("res://tests/npc_mpfb_profile_test.gd") as GDScript).new()
		add_child(probe)
		return
	_build_stage()
	_actors["mina_vale"] = _stand("mina_vale", Vector3(-0.55, 0, 0), true)
	_actors["cal_dwyer"] = _stand("cal_dwyer", Vector3(0.55, 0, 0), true)
	var adela := _stand("adela_voss", Vector3(40, 0, 0), false)
	var doodle := _stand("player_doodle", Vector3(44, 0, 0), false)
	await _frames(20)

	print("NPC POSE PIPELINE: rig profiles")
	var families := {"mina_vale": "meshy_biped", "cal_dwyer": "meshy_biped"}
	for id: String in families:
		var actor: Dictionary = _actors[id]
		_check(not actor.is_empty() and bool(actor.bound), "%s's skeleton takes a rig profile" % id)
		if actor.is_empty() or not bool(actor.bound):
			_finish()
			return
		var profile: RefCounted = actor.pipeline.profile
		_check(str(profile.family) == str(families[id]), "%s is read as %s (%s)" % [id, families[id], profile.family])
		_check(absf((profile.forward as Vector3).dot(profile.up)) < 0.01, "%s's measured front and up are square to each other" % id)
		var axes := _axes(actor)
		_check((axes.up as Vector3).dot(Vector3.UP) > 0.95, "%s's measured up is the world's up (%.2f)" % [id, (axes.up as Vector3).dot(Vector3.UP)])
		_check(absf((axes.forward as Vector3).y) < 0.2, "%s's measured front is level (%.2f)" % [id, (axes.forward as Vector3).y])
		for joint: String in ["pelvis", "spine_low", "chest", "neck", "head"]:
			_check(profile.has(joint), "%s has a %s" % [id, joint])
		_check(not profile.can("jaw") and not profile.can("eyes"), "%s's profile says plainly that this body has no jaw and no eyes to move" % id)
		_check(actor.player != null and (actor.player as AnimationPlayer).is_playing(), "%s is in an idle clip under the pipeline" % id)
	_check(not adela.is_empty() and bool(adela.bound) and str(adela.pipeline.profile.family) == "adela_rigify", "Adela's skeleton is read as its own family")
	_check(not doodle.is_empty() and bool(doodle.bound) and str(doodle.pipeline.profile.family) == "doodle", "the doodle's skeleton is read as its own family")
	if not doodle.is_empty() and not bool(doodle.bound):
		var names: Array[String] = []
		for bone in (doodle.skeleton as Skeleton3D).get_bone_count():
			names.append((doodle.skeleton as Skeleton3D).get_bone_name(bone))
		print("  doodle bones: ", names)
	var front: Vector3 = _axes(_actors.mina_vale).forward
	_check(front.dot(_axes(_actors.cal_dwyer).forward) > 0.98, "Mina and Cal are measured as facing the same way, whatever their bone frames say")

	# The camera stands in front of the pair, where their measured fronts point.
	_camera.position = Vector3(0, 1.5, 0) + front * 3.4
	_camera.look_at(Vector3(0, 1.38, 0))
	await _frames(30)
	_marker.visible = false
	await _snap("01_rest")

	print("NPC POSE PIPELINE: at rest the clip is left alone")
	for id: String in families:
		var pipeline: Node = _actors[id].pipeline
		_check(int(pipeline.frames) > 20, "%s's pipeline runs every frame (%d)" % [id, pipeline.frames])
		_check(is_zero_approx(pipeline.gaze_weight()), "%s's head is the clip's when nothing is attended to" % id)
		_check((pipeline.writers as Dictionary).size() == 1 and (pipeline.writers as Dictionary).values() == ["posture"], "%s at rest has one bone written, by posture (%s)" % [id, pipeline.writers])

	print("NPC POSE PIPELINE: attending to a point in reach")
	var reach_errors: Dictionary = {}
	for id: String in families:
		var actor: Dictionary = _actors[id]
		var pipeline: Node = actor.pipeline
		var axes := _axes(actor)
		var eye: Vector3 = pipeline.eye_world()
		var point: Vector3 = eye + (axes.forward as Vector3) * 1.6 + (axes.side as Vector3) * 1.1 + (axes.up as Vector3) * 0.35
		if id == "mina_vale":
			_marker.global_position = point
		var before: Vector3 = pipeline.facing_world()
		var worst_step := 0.0
		var first_step := -1.0
		var previous := before
		pipeline.attend(point)
		for index in 150:
			await get_tree().process_frame
			var now_facing: Vector3 = pipeline.facing_world()
			var moved := _degrees(previous, now_facing)
			if first_step < 0.0:
				first_step = moved
			worst_step = maxf(worst_step, moved)
			previous = now_facing
		var error := _degrees(pipeline.facing_world(), point - pipeline.eye_world())
		reach_errors[id] = error
		_check(error < 2.5, "%s's face is on the point (%.2f degrees off)" % [id, error])
		_check(_degrees(before, pipeline.facing_world()) > 20.0, "%s's head really turned (%.1f degrees)" % [id, _degrees(before, pipeline.facing_world())])
		_check(first_step < 1.5, "%s's head does not jump when attention starts (%.2f degrees in the first frame)" % [id, first_step])
		_check(worst_step < 6.0, "%s's head never moves faster than a head does (%.2f degrees in a frame)" % [id, worst_step])
		var written: Dictionary = pipeline.writers
		_check(written.size() == 4, "%s has four bones written: lower spine, chest, neck, head (%d)" % [id, written.size()])
		_check(written.values().count("gaze") == 3 and written.values().count("posture") == 1, "%s's bones each belong to one layer" % id)
		_check(int(pipeline.refused_writes) == 0, "%s: no bone was written twice (%d refused)" % [id, pipeline.refused_writes])
	_check(absf(float(reach_errors.mina_vale) - float(reach_errors.cal_dwyer)) < 1.5, "the two bodies land the same, within a degree and a half")
	_marker.visible = true
	await _snap("02_attend_side_and_up")

	print("NPC POSE PIPELINE: a point behind is refused by the neck")
	for id: String in families:
		var actor: Dictionary = _actors[id]
		var pipeline: Node = actor.pipeline
		var axes := _axes(actor)
		var point: Vector3 = pipeline.eye_world() - (axes.forward as Vector3) * 2.0 + (axes.side as Vector3) * 0.6 + (axes.up as Vector3) * 3.0
		if id == "mina_vale":
			_marker.global_position = point
		pipeline.attend(point)
		await _frames(150)
		var skeleton_basis: Basis = (actor.skeleton as Skeleton3D).global_transform.basis.orthonormalized()
		var chest: Vector3 = skeleton_basis * (pipeline.last_chest_forward as Vector3)
		var facing: Vector3 = pipeline.facing_world()
		var up: Vector3 = axes.up
		var chest_level := (chest - up * chest.dot(up)).normalized()
		var facing_level := (facing - up * facing.dot(up)).normalized()
		var yaw := _degrees(chest_level, facing_level)
		var pitch := rad_to_deg(asin(clampf(facing.dot(up), -1.0, 1.0)))
		var limit_yaw := rad_to_deg(float(pipeline.profile.gaze_yaw))
		var limit_pitch := rad_to_deg(float(pipeline.profile.gaze_pitch))
		_check(yaw <= limit_yaw + 1.5 and yaw > limit_yaw - 6.0, "%s turns as far as a neck goes and stops (%.1f of %.0f degrees)" % [id, yaw, limit_yaw])
		_check(pitch <= limit_pitch + 1.5 and pitch > limit_pitch - 6.0, "%s tips up as far as a neck goes and stops (%.1f of %.0f degrees)" % [id, pitch, limit_pitch])
		_check(_degrees(skeleton_basis * (pipeline.last_goal as Vector3), facing) < 0.5, "%s's head lands where the pipeline aimed it (%.2f degrees off)" % [id, _degrees(skeleton_basis * (pipeline.last_goal as Vector3), facing)])
		_check(int(pipeline.refused_writes) == 0, "%s: still no bone written twice" % id)
	await _snap("03_behind_is_bounded")

	print("NPC POSE PIPELINE: released, the head goes back to the clip")
	_marker.visible = false
	for id: String in families:
		var pipeline: Node = _actors[id].pipeline
		var held: Vector3 = pipeline.facing_world()
		pipeline.rest()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(_degrees(held, pipeline.facing_world()) < 6.0, "%s's head does not snap back when released (%.2f degrees)" % [id, _degrees(held, pipeline.facing_world())])
		await _frames(120)
		_check(is_zero_approx(pipeline.gaze_weight()), "%s's gaze has let go" % id)
		_check((pipeline.writers as Dictionary).size() == 1, "%s is back to the clip with only breath on it" % id)
		var axes := _axes(_actors[id])
		_check(_degrees(pipeline.facing_world(), axes.forward) < 25.0, "%s faces front again (%.1f degrees off her own front)" % [id, _degrees(pipeline.facing_world(), axes.forward)])
	await _snap("04_released")

	print("NPC POSE PIPELINE: a resident actor owns its own attention")
	var resident := AnimatedResident.new()
	resident.setup("Mina Vale", "mina_vale", "4B", _model_path("mina_vale"))
	resident.position = Vector3(20, 0, 0)
	_stage.add_child(resident)
	await _frames(10)
	var attention: Node = resident.attention
	_check(attention != null and attention.pipeline != null, "the actor fits an attention owner and a pose pipeline to its own model")
	if attention != null:
		var owner_pipeline: Node = attention.pipeline
		var resident_front: Vector3 = (owner_pipeline.get_skeleton() as Skeleton3D).global_transform.basis.orthonormalized() * (owner_pipeline.profile.forward as Vector3)
		var side_step := Vector3.UP.cross(resident_front).normalized()
		Engine.time_scale = 4.0
		attention.staged_target = resident.global_position + Vector3(0, 1.5, 0) + resident_front * 12.0
		await _frames(60)
		_check(not attention.is_looking() and is_zero_approx(owner_pipeline.gaze_weight()), "someone twelve metres off is not attended to")
		attention.staged_target = resident.global_position + Vector3(0, 1.55, 0) + resident_front * 1.6 + side_step * 1.2
		var looked := 0
		var looked_away := 0
		var was_looking := false
		var noticed_after := -1
		for frame in 900:
			await get_tree().process_frame
			var looking: bool = attention.is_looking()
			if looking and not was_looking:
				looked += 1
				if noticed_after < 0:
					noticed_after = frame
			if was_looking and not looking:
				looked_away += 1
			was_looking = looking
		_check(looked >= 1 and noticed_after > 2, "someone who comes near is noticed after a moment, not at once (frame %d)" % noticed_after)
		_check(looked >= 2 and looked_away >= 1, "the resident looks, looks away and looks back (%d looks, %d away)" % [looked, looked_away])
		attention.staged_target = resident.global_position + Vector3(0, 1.5, 0) + resident_front * 12.0
		await _frames(120)
		_check(not attention.is_looking(), "when they leave, the resident lets them go")
		attention.conversing = true
		attention._begin_look()
		await _frames(30)
		_check(attention.is_looking(), "in conversation the resident holds the caller's eye from any distance")
		attention.conversing = false
		Engine.time_scale = 1.0

	print("NPC POSE PIPELINE: cost")
	for id: String in families:
		var pipeline: Node = _actors[id].pipeline
		var each := float(pipeline.cost_usec) / maxf(float(pipeline.frames), 1.0)
		print("  %s: %.1f microseconds a frame over %d frames" % [id, each, pipeline.frames])
		_check(each < 400.0, "%s's pipeline costs under 0.4 ms a frame (%.1f us)" % [id, each])
	_finish()


func _finish() -> void:
	print("NPC POSE PIPELINE TEST: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)
