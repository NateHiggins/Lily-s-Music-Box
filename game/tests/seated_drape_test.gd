extends Node3D
## Seated drapes (Omni w39b8516474ec): a gown that ships <id>__<part>_seated shows it while its wearer sits and the
## standing skirt otherwise. Real assets through the game's own presentation; no building, dialogue or saves.
## SEATED_DRAPE_ACTORS "id=res://path/id.gltf,..." overrides who is checked; SHOT_DIR (windowed) also saves frames.
const Presentation := preload("res://scripts/characters/cast_model_presentation.gd")
const DEFAULT_ACTORS := "adela_voss=res://assets/characters/cast/adela_voss/adela_voss.gltf,stacy=res://assets/characters/stacy/stacy.gltf,lily=res://assets/characters/lily/lily.gltf"
## What each changes into to show the drape leaves with the gown.
const CHANGE := {"adela_voss": ["a_top", "a_bottom", "a_over", "a_feet"], "stacy": ["work_top", "work_bottom", "work_feet"], "lily": ["work_top", "work_bottom", "work_feet"]}
var checks := 0
var failures: Array[String] = []


func check(ok: bool, text: String) -> void:
	checks += 1
	print("SEATED DRAPE: ", text, " = ", ok)
	if not ok:
		failures.append(text)


func frames(count: int) -> void:
	for _frame in count:
		await get_tree().process_frame


func _ready() -> void:
	var notice := get_node_or_null("/root/SaveStatusNotice")
	if notice is CanvasLayer:
		(notice as CanvasLayer).visible = false
	run.call_deferred()


## Thighs level and forward, shins hanging: a chair, written straight onto the skeleton.
func sit(body: Skeleton3D, amount: float) -> void:
	var swing := Basis(Vector3.RIGHT, -PI * 0.5 * amount)
	for side: String in ["Left", "Right"]:
		var thigh := body.find_bone(side + "UpLeg")
		var shin := body.find_bone(side + "Leg")
		var thigh_rest := body.get_bone_global_rest(thigh)
		var shin_rest := body.get_bone_global_rest(shin)
		var thigh_now := Transform3D(swing * thigh_rest.basis, thigh_rest.origin)
		body.set_bone_global_pose(thigh, thigh_now)
		body.set_bone_global_pose(shin, Transform3D(shin_rest.basis, (thigh_now * (thigh_rest.affine_inverse() * shin_rest)).origin))


func shown(draws: Array) -> int:
	var count := 0
	for draw: MeshInstance3D in draws:
		if is_instance_valid(draw) and draw.visible:
			count += 1
	return count


func run() -> void:
	RealityState.persistence_enabled = false
	var out := OS.get_environment("SHOT_DIR")
	var camera: Camera3D = null
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		get_viewport().msaa_3d = Viewport.MSAA_8X
		var world := WorldEnvironment.new()
		world.environment = Environment.new()
		world.environment.background_mode = Environment.BG_COLOR
		world.environment.background_color = Color(0.34, 0.35, 0.37)
		world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.environment.ambient_light_color = Color(0.8, 0.8, 0.82)
		world.environment.ambient_light_energy = 0.6
		world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		add_child(world)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-32, 30, 0)
		key.light_energy = 1.2
		key.shadow_enabled = true
		add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20, -140, 0)
		fill.light_energy = 0.45
		add_child(fill)
		var floor_draw := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(8, 8)
		floor_draw.mesh = plane
		var floor_look := StandardMaterial3D.new()
		floor_look.albedo_color = Color(0.4, 0.38, 0.36)
		floor_draw.material_override = floor_look
		add_child(floor_draw)
		camera = Camera3D.new()
		add_child(camera)
		camera.make_current()
	var actors := OS.get_environment("SEATED_DRAPE_ACTORS")
	if actors.is_empty():
		actors = DEFAULT_ACTORS
	for entry: String in actors.split(",", false):
		var id := entry.get_slice("=", 0)
		var actor := Presentation.new()
		actor.name = "Seated_" + id
		actor.configure(id, entry.get_slice("=", 1), ["p_top", "p_feet", "p_head"], "at_ease")
		add_child(actor)
		check(actor.ready_ok, id + " presents in the stage gown")
		if not actor.ready_ok:
			actor.queue_free()
			continue
		await frames(6)
		var seated: Array = actor.skeleton.find_children("p_top_seated_*", "MeshInstance3D", false, false)
		var standing: Array = []
		for draw: MeshInstance3D in seated:
			standing.append(actor.skeleton.get_node_or_null(str(draw.name).replace("p_top_seated_", "p_top_")))
		check(not seated.is_empty() and null not in standing, id + " gown ships a seated drape paired with its standing skirt")
		if seated.is_empty() or null in standing:
			actor.queue_free()
			continue
		check(not actor.draped() and shown(seated) == 0 and shown(standing) == standing.size(), id + " standing shows the standing skirt only")
		for draw: MeshInstance3D in seated:
			check(draw.skin != null and draw.get_node_or_null(draw.skeleton) == actor.skeleton, id + " " + str(draw.name) + " is skinned to her own skeleton")
		if camera != null:
			await shoot(camera, out, id, "standing", 0.0)
		actor.clip_driven = true
		for step in 12:
			sit(actor.skeleton, float(step + 1) / 12.0)
			await frames(1)
		await frames(4)
		check(actor.draped() and shown(seated) == seated.size() and shown(standing) == 0, id + " seated shows the drape only")
		if camera != null:
			var foot := (actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("LeftFoot"))).origin
			var hips := (actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("Hips"))).origin
			var drop := foot.y - 0.08
			actor.position.y -= drop
			var seat := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.46, hips.y - drop - 0.1, 0.42)
			seat.mesh = box
			seat.position = Vector3(0.0, box.size.y * 0.5, hips.z - 0.05)
			add_child(seat)
			await frames(3)
			await shoot(camera, out, id, "seated", hips.y - drop - 0.9)
			seat.queue_free()
			actor.position.y = 0.0
		# A half-risen wearer keeps what she has: the switch has slack both ways.
		sit(actor.skeleton, 0.62)
		await frames(4)
		check(actor.draped(), id + " keeps the drape while half risen")
		sit(actor.skeleton, 0.0)
		await frames(4)
		check(not actor.draped() and shown(seated) == 0 and shown(standing) == standing.size(), id + " standing again shows the standing skirt")
		check(actor.wear(CHANGE.get(id, [])), id + " takes the gown off")
		await frames(3)
		check(actor.skeleton.find_children("p_top_seated_*", "MeshInstance3D", false, false).is_empty() and not actor.draped(), id + " drape leaves with the gown")
		actor.queue_free()
		await frames(3)
	print("SEATED DRAPE RESULT: %d checks / %d failures" % [checks, failures.size()])
	for text: String in failures:
		print("SEATED DRAPE FAIL: ", text)
	get_tree().quit(0 if failures.is_empty() else 1)


func shoot(camera: Camera3D, out: String, id: String, label: String, lower: float) -> void:
	for view: Array in [["front", 0.0], ["three_quarter", 38.0], ["side", 90.0], ["back_quarter", 142.0]]:
		var around := deg_to_rad(float(view[1]))
		camera.fov = 30.0
		camera.position = Vector3(sin(around) * 4.6, 1.2 + lower * 0.5, cos(around) * 4.6)
		camera.look_at(Vector3(0.0, 0.9 + lower, 0.0))
		await frames(4)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s_%s.png" % [id, label, view[0]]))
