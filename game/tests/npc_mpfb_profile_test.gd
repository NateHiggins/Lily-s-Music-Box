extends Node
## Real exported bodies, through the existing profile and sole pose writer.
## MPFB_GLB_DIR contains lily/lily.glb and stacy/stacy.glb. Absolute external
## proof paths are imported with GLTFDocument, never ResourceLoader guesses.
const Profile := preload("res://scripts/characters/rig_profile.gd")
const Pipeline := preload("res://scripts/characters/pose_pipeline.gd")
const STEP := 1.0 / 60.0
var failures: Array[String] = []
var checks := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	print("MPFB PROFILE: ", text, " = ", ok)
	if not ok:
		failures.append(text)


func _ready() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func mean_rest(body: Skeleton3D, names: Array[String]) -> Vector3:
	var result := Vector3.ZERO
	for bone: String in names:
		var index := body.find_bone(bone)
		if index < 0:
			return Vector3.ZERO
		result += body.get_bone_global_rest(index).origin
	return result / float(names.size())


func run() -> void:
	var directory := OS.get_environment("MPFB_GLB_DIR")
	if directory.is_empty():
		push_error("Supply MPFB_GLB_DIR containing the two real exported bodies")
		get_tree().quit(2)
		return
	for id: String in ["lily", "stacy"]:
		var path := directory.path_join(id).path_join(id + ".glb")
		check(FileAccess.file_exists(path), id + " real proof exists")
		if not FileAccess.file_exists(path):
			continue
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(path, state)
		check(error == OK, id + " GLTF import succeeds")
		if error != OK:
			continue
		var model := document.generate_scene(state)
		check(model != null, id + " real scene generated")
		if model == null:
			continue
		var holder := Node3D.new()
		add_child(holder)
		# Test under a turned and translated parent: no hardcoded world yaw.
		holder.rotation.y = deg_to_rad(37.0 if id == "lily" else -61.0)
		holder.position = Vector3(3.0, 0.0, -2.0)
		holder.add_child(model)
		var bodies := model.find_children("*", "Skeleton3D", true, false)
		check(bodies.size() == 1, id + " one shared skeleton")
		if bodies.size() != 1:
			holder.queue_free()
			continue
		var body := bodies[0] as Skeleton3D
		var fitted := Profile.for_skeleton(body)
		check(fitted != null, id + " detected")
		if fitted == null:
			holder.queue_free()
			continue
		check(fitted.family == "mpfb_mixamo_76" and fitted.errors.is_empty(), id + " measured MPFB family without errors")
		check(body.get_bone_count() == 76, id + " exact shared bone count")
		for side: String in ["left", "right"]:
			for finger: String in ["thumb", "index", "middle", "ring", "pinky"]:
				for segment in range(1, 4):
					check(fitted.has("%s_%s_%d" % [side, finger, segment]), id + " finger semantic " + "%s_%s_%d" % [side, finger, segment])
		var up := (mean_rest(body, ["Neck"]) - mean_rest(body, ["Hips"])).normalized()
		var fore := mean_rest(body, ["LeftToeBase", "RightToeBase"]) - mean_rest(body, ["LeftFoot", "RightFoot"])
		fore = (fore - up * fore.dot(up)).normalized()
		check(fore.dot(fitted.forward) > 0.99999 and up.dot(fitted.up) > 0.99999, id + " rest landmarks determine frame")
		check(absf((fitted.forward as Vector3).dot(fitted.up)) < 0.00001, id + " frame orthogonal")
		var pipeline := Pipeline.new()
		body.add_child(pipeline)
		check(pipeline.bind(body), id + " existing sole pose pipeline binds")
		pipeline.fixed_delta = STEP
		await frames(30)
		check(pipeline.frames > 0, id + " engine actually invokes modifier")
		check(pipeline.writers.size() == 1 and pipeline.writers.values() == ["posture"], id + " rest only breath writer")
		var basis := body.global_basis.orthonormalized()
		var front: Vector3 = basis * fitted.forward
		var upwards: Vector3 = basis * fitted.up
		var sidewards := upwards.cross(front).normalized()
		var target: Vector3 = pipeline.eye_world() + front * 2.0 + sidewards * 0.7 + upwards * 0.2
		pipeline.attend(target)
		await frames(150)
		var difference := rad_to_deg(pipeline.facing_world().angle_to((target - pipeline.eye_world()).normalized()))
		check(difference < 2.5, id + " real rig gaze reaches target: " + str(difference))
		check(pipeline.writers.size() == 4 and pipeline.writers.values().count("gaze") == 3 and pipeline.refused_writes == 0, id + " four distinct writers without conflict")
		pipeline.attend(pipeline.eye_world() - front * 2.0 + sidewards * 0.5 + upwards * 3.0)
		await frames(150)
		var facing: Vector3 = pipeline.facing_world()
		var chest: Vector3 = basis * pipeline.last_chest_forward
		var flat_chest := (chest - upwards * chest.dot(upwards)).normalized()
		var flat_face := (facing - upwards * facing.dot(upwards)).normalized()
		check(flat_chest.angle_to(flat_face) <= fitted.gaze_yaw + deg_to_rad(1.5), id + " behind target respects neck yaw")
		check(absf(asin(clampf(facing.dot(upwards), -1.0, 1.0))) <= fitted.gaze_pitch + deg_to_rad(1.5), id + " behind target respects pitch")
		pipeline.rest()
		await frames(150)
		check(is_zero_approx(pipeline.gaze_weight()) and pipeline.writers.size() == 1 and pipeline.refused_writes == 0, id + " release restores rest ownership")
		# Detection cannot silently qualify a changed skeleton with extra joints.
		var wrong := Skeleton3D.new()
		for bone in body.get_bone_count():
			wrong.add_bone(body.get_bone_name(bone))
			wrong.set_bone_parent(bone, body.get_bone_parent(bone))
			wrong.set_bone_rest(bone, body.get_bone_rest(bone))
		wrong.add_bone("UnexpectedExtraJoint")
		var rejected := Profile.for_skeleton(wrong)
		check(rejected != null and not rejected.errors.is_empty(), id + " changed 77-bone contract rejected")
		wrong.free()
		var coincident := Profile.for_skeleton(body)
		coincident._rest_frame = {"forward_from": ["left_foot"], "forward_to": ["left_foot"], "up_from": ["pelvis"], "up_to": ["neck"]}
		coincident._measure()
		check(not coincident.errors.is_empty(), id + " coincident frame landmarks rejected")
		holder.queue_free()
		await frames(2)
	print("MPFB PROFILE RESULT: ", checks, " checks / ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
