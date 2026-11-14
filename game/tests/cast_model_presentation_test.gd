extends Node
## Focused real-asset intake/lifecycle test; no building, dialogue or saves.
const Presentation := preload("res://scripts/characters/cast_model_presentation.gd")
var extension := "gltf"
var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	print("CAST COMPONENT: ", text, " = ", ok)
	if not ok:
		failures.append(text)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	run.call_deferred()


func source_path(id: String) -> String:
	return "res://assets/characters/%s/%s.%s" % [id, id, extension]


## Vertex bone values index Skin binds, not necessarily Skeleton bone indices.
func hair_bound_to_head(actor: Presentation, mesh_name: String) -> bool:
	var meshes := actor.model.find_children(mesh_name, "MeshInstance3D", true, false)
	if meshes.size() != 1:
		return false
	var draw := meshes[0] as MeshInstance3D
	if draw.mesh == null or draw.skin == null or draw.get_node_or_null(draw.skeleton) != actor.skeleton:
		return false
	var weighted := false
	for surface in draw.mesh.get_surface_count():
		var arrays := draw.mesh.surface_get_arrays(surface)
		if typeof(arrays[Mesh.ARRAY_BONES]) != TYPE_PACKED_INT32_ARRAY or typeof(arrays[Mesh.ARRAY_WEIGHTS]) != TYPE_PACKED_FLOAT32_ARRAY:
			return false
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones.is_empty() or bones.size() != weights.size() or bones.size() % vertices.size() != 0:
			return false
		var influences := int(bones.size() / vertices.size())
		for vertex in vertices.size():
			var total := 0.0
			for influence in influences:
				total += weights[vertex * influences + influence]
			if absf(total - 1.0) > 0.001:
				return false
		for index in weights.size():
			if weights[index] <= 0.00001:
				continue
			weighted = true
			var bind := bones[index]
			if bind < 0 or bind >= draw.skin.get_bind_count():
				return false
			var bind_name := draw.skin.get_bind_name(bind)
			var bone := actor.skeleton.find_bone(bind_name) if not bind_name.is_empty() else draw.skin.get_bind_bone(bind)
			if bone < 0 or bone >= actor.skeleton.get_bone_count() or actor.skeleton.get_bone_name(bone) != &"Head":
				return false
	return weighted


func run() -> void:
	RealityState.persistence_enabled = false
	extension = OS.get_environment("ORISON_CAST_MODEL_EXTENSION").to_lower()
	if extension.is_empty():
		extension = "gltf"
	if extension not in ["gltf", "glb"]:
		check(false, "fixture extension must be gltf or glb")
		get_tree().quit(1)
		return
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.35, 2)
	camera.look_at(Vector3(0, 1.3, 0))
	camera.current = true
	for id: String in ["lily", "stacy"]:
		var actor := Presentation.new()
		actor.configure(id, source_path(id), ["work_top", "work_bottom", "work_feet"])
		add_child(actor)
		check(actor.ready_ok and actor.errors.is_empty(), id + " complete actual base/wardrobe/profile/pose/face binds")
		if not actor.ready_ok:
			actor.queue_free()
			continue
		await frames(30)
		check(actor.wardrobe.worn.size() == 3 and actor.wardrobe.mesh_count() >= 3, id + " all three requested slots mounted")
		check(actor.model.find_children("Skin_*", "MeshInstance3D", true, false).size() == 8, id + " body partitions retained")
		check(actor.find_children("*", "CollisionObject3D", true, false).is_empty(), id + " no new physics or interaction authority")
		check(actor.find_children("*", "AnimationPlayer", true, false).is_empty(), id + " no legacy movement graft")
		for draw: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
			check(draw.material_override == null, id + " imported material retained on " + str(draw.name))
		var body: Skeleton3D = actor.skeleton
		var lowest_rest := minf(body.get_bone_global_rest(body.find_bone("LeftFoot")).origin.y, body.get_bone_global_rest(body.find_bone("RightFoot")).origin.y)
		var lowest_pose := minf(body.get_bone_global_pose(body.find_bone("LeftFoot")).origin.y, body.get_bone_global_pose(body.find_bone("RightFoot")).origin.y)
		check(absf(lowest_pose - lowest_rest) < 0.035, id + " authored base pose keeps lower foot grounded")
		check(actor.attention.pipeline.frames > 0 and actor.attention.pipeline.refused_writes == 0, id + " sole pose modifier runs without write conflicts")
		check(actor.face.bound and actor.face.can_speak_shapes(), id + " actual face binds")
		var heads := actor.model.find_children("Skin_head", "MeshInstance3D", true, false)
		var actual_face := heads.size() == 1
		for shape: String in Presentation.REQUIRED_FACE:
			var on_head := false
			for target: Array in actor.face.targets.get(shape, []):
				on_head = on_head or (heads.size() == 1 and target[0] == heads[0])
			actual_face = actual_face and on_head
		check(actual_face, id + " every required facial channel binds actual Skin_head")
		check(hair_bound_to_head(actor, "Hair"), id + " actual Hair vertices bind only Head through Skin")
		check(hair_bound_to_head(actor, "HairCap"), id + " actual HairCap vertices bind only Head through Skin")
		check(actor.hair.ready_ok and actor.hair.motion.ready_ok and actor.hair.motion.frames > 0, id + " shared hair shader and final Head observer are active")
		check(actor.hair.motion.get_parent() == body and actor.hair.motion.get_index() == body.get_child_count() - 1, id + " hair observer runs after existing pose and skirt modifiers")
		for hair_name: String in ["Hair", "HairCap"]:
			var hair_material: ShaderMaterial = actor.hair.materials[hair_name]
			check(hair_material.shader.resource_path == "res://shaders/character_hair.gdshader", id + " reviewed shared shader on " + hair_name)
			check(hair_material.get_shader_parameter("roughness_channel") == Vector3(0, 1, 0), id + " packed glTF roughness uses green on " + hair_name)
			check(hair_material.get_shader_parameter("is_cap") == (hair_name == "HairCap"), id + " cap versus card rendering on " + hair_name)
			for channel: String in ["albedo_tex", "normal_tex", "rough_tex"]:
				var texture := hair_material.get_shader_parameter(channel) as Texture2D
				var image := texture.get_image() if texture != null else null
				check(image != null and image.has_mipmaps(), id + " loaded mipmaps " + hair_name + "/" + channel)
		var peak_motion := 0.0
		for _step in 8:
			actor.position.x += 0.002
			await frames(1)
			peak_motion = maxf(peak_motion, actor.hair.motion.last_sway.length())
		check(peak_motion > 0.000001 and peak_motion <= 0.01201, id + " actual final Head motion drives bounded hair sway")
		actor.speak_cues([{"start": 0.0, "end": 2.0, "value": "D"}])
		check(actor.face.is_speaking(), id + " cue API reaches sole face writer")
		actor.stop_speaking()
		check(not actor.face.is_speaking(), id + " interruption clears speech")
		actor.express("interest", 0.7)
		check(actor.face.expression() == "interest", id + " expression forwards")
		actor.speak_untimed(2.0)
		check(actor.face.is_speaking(), id + " untimed speech forwards")
		actor.set_active(false)
		check(not actor.hair.motion.active and actor.hair.motion.last_sway == Vector3.ZERO, id + " inactive hair resets and pauses")
		check(not actor.visible and not actor.is_processing() and not actor.face.is_processing() and not actor.attention.is_processing() and not actor.attention.pipeline.active, id + " off-shift hides and pauses presentation writers")
		check(not actor.face.is_speaking(), id + " off-shift interrupts rather than resuming speech")
		var face_clock: float = actor.face.get("_clock")
		actor.set_active(false)
		check(is_equal_approx(actor.face.get("_clock"), face_clock), id + " repeated inactive presence does not step face again")
		var clock_before: float = actor.get("_clock")
		var modifier_frames: int = actor.attention.pipeline.frames
		await frames(10)
		check(is_equal_approx(actor.get("_clock"), clock_before) and actor.attention.pipeline.frames == modifier_frames, id + " inactive clocks and modifier remain frozen")
		actor.set_active(true)
		await frames(10)
		check(actor.visible and actor.ready_ok and actor.attention.pipeline.frames > modifier_frames, id + " reactivation restores model without reload")
		actor.queue_free()
		await frames(2)
	# Stacy's investigator looks (owner's ruling stacy_investigator_look_r2_20261113): the street look with coat
	# and trilby, and the indoor look in shirt and braces, worn on her installed body beside her work parts.
	for look: Array in [["i_top", "i_bottom", "i_feet", "k_over", "k_head"], ["i_top", "i_bottom", "i_feet"]]:
		var dressed := Presentation.new()
		dressed.configure("stacy", source_path("stacy"), look)
		add_child(dressed)
		var label := "stacy %s look" % ("street" if look.size() == 5 else "indoor")
		check(dressed.ready_ok and dressed.errors.is_empty(), label + " binds on her installed body")
		if dressed.ready_ok:
			await frames(10)
			check(dressed.wardrobe.worn.size() == look.size() and dressed.wardrobe.mesh_count() >= look.size(), label + " mounts every requested slot")
			check(dressed.model.find_children("Skin_*", "MeshInstance3D", true, false).size() == 8, label + " keeps the body partitions")
		dressed.queue_free()
		await frames(2)
	# The approved stage looks (Lily and Adela 2026-11-12, Stacy 2026-11-13) and Lily's four looks of 2026-11-14:
	# each binds on the installed body, mounts every slot, keeps the body partitions, and the stage looks take
	# their stage makeup.
	var looks: Array = [
		["lily", ["p_top", "p_feet", "p_head"], "stage"], ["adela_voss", ["p_top", "p_feet", "p_head"], "stage"],
		["stacy", ["p_top", "p_feet", "p_head"], "stage"],
		["lily", ["x_top", "x_bottom", "x_feet", "x_over"], ""], ["lily", ["s_top", "x_feet"], ""],
		["lily", ["s_top", "s_over", "x_feet"], ""], ["lily", ["h_top", "h_bottom", "h_feet"], ""],
		["lily", ["h_top", "h_bottom", "h_feet", "c_over"], ""],
	]
	for entry: Array in looks:
		var who: String = entry[0]
		var parts: Array = entry[1]
		var label := "%s %s" % [who, ",".join(parts)]
		var worn := Presentation.new()
		# Adela's model lives with the cast; Lily's and Stacy's have their own folders.
		var source := "res://assets/characters/cast/%s/%s.%s" % [who, who, extension] if who == "adela_voss" else source_path(who)
		worn.configure(who, source, parts)
		add_child(worn)
		check(worn.ready_ok and worn.errors.is_empty(), label + " binds on the installed body")
		if worn.ready_ok:
			await frames(10)
			check(worn.wardrobe.worn.size() == parts.size() and worn.wardrobe.mesh_count() >= parts.size(), label + " mounts every requested slot")
			check(worn.model.find_children("Skin_*", "MeshInstance3D", true, false).size() == 8, label + " keeps the body partitions")
			if not str(entry[2]).is_empty():
				check(worn.set_makeup(str(entry[2])), label + " takes its " + str(entry[2]) + " makeup")
		worn.queue_free()
		await frames(2)
	# Expected failure cases must remain hidden and not silently show partial skin.
	var absent := Presentation.new()
	absent.report_errors = false
	absent.configure("lily", "res://assets/characters/lily/not_here." + extension, ["work_top", "work_bottom", "work_feet"])
	add_child(absent)
	check(not absent.ready_ok and not absent.visible and absent.errors.size() == 1 and absent.errors[0].begins_with("base model must be an imported resource:"), "missing source fails closed with expected refusal")
	absent.queue_free()
	var partial := Presentation.new()
	partial.report_errors = false
	partial.configure("lily", source_path("lily"), ["work_top", "work_feet"])
	add_child(partial)
	check(not partial.ready_ok and not partial.visible and partial.errors.has("current intake requires top, bottom and feet; partial dress refused"), "partial wardrobe fails closed with expected refusal")
	partial.queue_free()
	var unknown_pose := Presentation.new()
	unknown_pose.report_errors = false
	unknown_pose.configure("lily", source_path("lily"), ["work_top", "work_bottom", "work_feet"], "not_authored")
	add_child(unknown_pose)
	check(not unknown_pose.ready_ok and not unknown_pose.visible and unknown_pose.errors.has("authored stand pose missing; A-pose fallback refused"), "unknown pose does not fall back to A-pose")
	unknown_pose.queue_free()
	await frames(2)
	print("CAST COMPONENT RESULT: ", checks, " checks / ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
