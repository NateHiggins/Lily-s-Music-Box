extends Node3D
## A resident on the cast list wears the rebuilt body (order w9189b10b24ac, Cal first): the V2 resident is built
## from the cast presentation with the shared clips as its base pose; walking, waiting, sitting and attention go
## through it; its own materials stay (no atlas). Off the list the same resident wears the old body.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const WHO := "cal_dwyer"

var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("CAST RESIDENT: [FAIL] ", text)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	run.call_deferred()


func _atlas_meshes(node: Node) -> int:
	var count := 0
	for draw: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if draw.has_meta("v2_resident_atlas"):
			count += 1
	return count


func _make(model: String) -> Presentation:
	var actor := Presentation.new()
	actor.setup("Cal Dwyer", WHO, "4C", model)
	actor.externally_driven = true
	add_child(actor)
	return actor


func run() -> void:
	RealityState.persistence_enabled = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.0, 1.4, 3.2)
	camera.make_current()

	# Off the list: the old body, as before.
	CastBodies.set_for_test([])
	check(CastBodies.model_for(WHO) == CastBodies.old_model(WHO), "off the list Cal is built from his old body")
	var old := _make(CastBodies.model_for(WHO))
	await frames(4)
	check(old.cast_body == null and old._model != null and _atlas_meshes(old._model) > 0, "the old body keeps its V2 atlas")
	old.queue_free()
	await frames(2)

	# On the list: the rebuilt body.
	CastBodies.set_for_test([WHO])
	check(CastBodies.wears_cast_body(WHO), "Cal's rebuilt files are installed and he is on the list")
	var actor := _make(CastBodies.model_for(WHO))
	await frames(8)
	var body: Node3D = actor.cast_body
	check(body != null and bool(body.ready_ok), "Cal's resident is built from the cast presentation")
	if body == null or not bool(body.ready_ok):
		_finish()
		return
	check(bool(body.clip_driven) and actor._animation_player != null, "the shared cast clips drive his base pose")
	check(actor._model == body.model and actor.attention == body.attention, "one model and one attention owner")
	check(_atlas_meshes(body) == 0, "his own materials stay: no resident atlas on the rebuilt body")
	check(not (body.worn_parts() as Array).is_empty(), "he is dressed by the wardrobe rules: %s" % [body.worn_parts()])
	check(actor._animation_player.is_playing() and str(actor._animation_player.current_animation) == actor.preferred_idle,
			"he stands in his own idle (%s)" % actor.preferred_idle)
	var hips: int = body.skeleton.find_bone("Hips")
	var before: Vector3 = body.skeleton.get_bone_global_pose(hips).origin
	actor.set_route_motion(true, 0.0, 1.2)
	await frames(30)
	check(str(actor._animation_player.current_animation) == "walk", "walking plays his walk")
	check(body.skeleton.get_bone_global_pose(hips).origin.distance_to(before) > 0.001, "the walk moves the body")
	actor.set_route_motion(false, 0.0, 0.0)
	await frames(4)
	check(actor.play_seated() and str(actor._animation_player.current_animation) == "clip_06", "he can sit")
	actor.set_loop_activity("rest")
	await frames(2)
	var head: int = body.skeleton.find_bone("Head")
	check(head != -1 and body.attention != null and body.attention.is_processing(), "attention still turns his head over the clip")
	actor.queue_free()
	await frames(2)

	# Mina: her own animation owner (the twenty mina_* clips) runs on the rebuilt body.
	CastBodies.set_for_test([WHO, "mina_vale"])
	var mina := Presentation.new()
	mina.setup("Mina Vale", "mina_vale", "2A", CastBodies.model_for("mina_vale"))
	mina.externally_driven = true
	add_child(mina)
	await frames(8)
	var mina_body: Node3D = mina.cast_body
	check(mina_body != null and bool(mina_body.ready_ok) and bool(mina_body.clip_driven), "Mina's resident is built from her rebuilt body with clips")
	check(mina.mina_animation != null, "Mina's animation behaviour installs on the cast clips")
	if mina.mina_animation != null:
		check(str(mina._animation_player.current_animation).begins_with("mina_"), "Mina stands in her own clip (%s)" % mina._animation_player.current_animation)
		mina.set_route_motion(true, 0.0, 1.2)
		await frames(30)
		check(str(mina._animation_player.current_animation).begins_with("mina_walk"), "Mina walks in her own walk (%s)" % mina._animation_player.current_animation)
	check(mina_body != null and _atlas_meshes(mina_body) == 0, "Mina keeps her own materials")
	mina.queue_free()
	await frames(2)
	CastBodies.set_for_test()
	_finish()


func _finish() -> void:
	print("CAST RESIDENT RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
