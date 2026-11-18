extends Node3D
## The dream's pursuer casts the shadow of the resident it borrows, on the body they now wear (order w9189b10b24ac):
## each of the six dream subjects on a rebuilt body is borrowed dressed and standing, every surface shadows only;
## someone taken off the rebuilt list still falls back to their old body.
const CastPresentation := preload("res://scripts/characters/cast_model_presentation.gd")

var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("DREAM SILHOUETTE: [FAIL] ", text)


func _ready() -> void:
	run.call_deferred()


func _geometry_shadows_only(node: Node) -> bool:
	if node is GeometryInstance3D and (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return false
	for child in node.get_children():
		if not _geometry_shadows_only(child):
			return false
	return true


func _borrow(slug: String) -> DreamPursuer:
	var pursuer := DreamPursuer.new()
	add_child(pursuer)
	pursuer._borrow_silhouette(slug)
	return pursuer


## A wall and floor under one light, each borrowed shadow cast on them, for a person to look at.
func _shadow_shots(dir: String, subjects: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var stage := Node3D.new()
	add_child(stage)
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.78, 0.75, 0.68)
	for spec: Array in [[Vector3(6, 0.1, 6), Vector3(0, -0.05, 0)], [Vector3(6, 3, 0.1), Vector3(0, 1.5, -1.2)]]:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[0]
		mesh.material = plaster
		box.mesh = mesh
		box.position = spec[1]
		stage.add_child(box)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.4, 1.4, 2.4)
	lamp.look_at_from_position(lamp.position, Vector3(0, 1.0, -1.2))
	lamp.spot_range = 8.0
	lamp.spot_angle = 50.0
	lamp.light_energy = 6.0
	lamp.shadow_enabled = true
	stage.add_child(lamp)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(1.6, 1.3, 2.8), Vector3(0, 0.9, -0.6))
	camera.make_current()
	for slug: String in subjects:
		var pursuer := _borrow(slug)
		for frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("shadow_%s.png" % slug))
		pursuer.queue_free()
		await get_tree().process_frame
	stage.queue_free()


func run() -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dream_profiles.json"))
	var subjects: Array[String] = []
	for line in FileAccess.get_file_as_string("res://data/dream_profiles.json").split("\n"):
		if line.contains("\"silhouette_resident\""):
			subjects.append(line.get_slice("\"", 3))
	check(subjects.size() == 6 and profiles != null, "six dream profiles name a resident to borrow: %s" % [subjects])
	for slug: String in subjects:
		check(CastBodies.wears_cast_body(slug), "%s wears a rebuilt body" % slug)
		var pursuer := _borrow(slug)
		await get_tree().process_frame
		var proxy: Node = pursuer.get_node_or_null("BorrowedSilhouette")
		check(proxy != null and proxy.get_script() == CastPresentation and bool(proxy.ready_ok), "%s's shadow is the rebuilt body" % slug)
		check(pursuer.silhouette_source == slug, "%s is named as the silhouette's source" % slug)
		check(proxy != null and not (proxy.worn_parts() as Array).is_empty(), "%s is dressed" % slug)
		check(proxy != null and _geometry_shadows_only(proxy), "%s's every surface casts shadow only" % slug)
		pursuer.queue_free()
		await get_tree().process_frame
	var shots := OS.get_environment("SHOT_DIR")
	if not shots.is_empty():
		await _shadow_shots(shots, subjects)
	# Off the list, the old body is still borrowed.
	CastBodies.set_for_test([])
	var old := _borrow("mina_vale")
	await get_tree().process_frame
	var old_proxy: Node = old.get_node_or_null("BorrowedSilhouette")
	check(old_proxy != null and old_proxy.get_script() != CastPresentation and old.silhouette_source == "mina_vale", "a resident off the list casts the old body's shadow")
	CastBodies.set_for_test()
	print("DREAM SILHOUETTE RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
