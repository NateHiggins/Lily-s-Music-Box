extends Node3D
## Loaded geometry, paired optics and one nearby standing bank walk.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const WalkDriver := preload("res://tests/orison_v2_vertical_route_test.gd")
const STANDING_MASK := 1 | preload("res://scripts/building/v2_fire_player_contact.gd").LAYER
const RAIL_EYE := Vector3(-290.0, 12.0, 60.0)
const RAIL_AIM := Vector3(-390.0, -3.5, 0.0)
const CANAL_EYE := Vector3(20.0, 7.0, -310.0)
const CANAL_AIM := Vector3(50.0, -6.0, -360.0)

var failures: Array[String] = []
var frames: Array[Dictionary] = []
var walk: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> bool:
	if not ok:
		failures.append(label)
		push_error("CITY EDGE REVIEW: " + label)
	return ok


func _digest() -> String:
	var result: Array = []
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var exit := OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], result)
	if exit != 0 or result.is_empty():
		return ""
	return str(result[0]).strip_edges()


func _ray(world: OrisonV2RuntimeRoot, frame: Node3D, start: Vector3, stop: Vector3) -> Dictionary:
	var parameters := PhysicsRayQueryParameters3D.create(frame.to_global(start),
		frame.to_global(stop), STANDING_MASK, [world.player.get_rid()])
	return world.get_world_3d().direct_space_state.intersect_ray(parameters)


func _mapped(draw: MeshInstance3D, surfaces: int) -> void:
	if not check(draw.mesh != null and draw.mesh.get_surface_count() == surfaces,
			"loaded surface roster for " + str(draw.name)):
		return
	for index in surfaces:
		var active := draw.get_active_material(index)
		var mat := active.get_meta("v2_weather_source", active) as StandardMaterial3D if active != null else null
		if not check(mat != null and mat.normal_enabled and not mat.uv1_triplanar,
				"authored PBR charts for " + str(draw.name)):
			continue
		for texture: Texture2D in [mat.albedo_texture, mat.roughness_texture, mat.normal_texture]:
			if check(texture != null, "mapped " + str(draw.name)):
				check(texture.get_image().has_mipmaps(), "loaded mip chain " + texture.resource_path)


func _view(folder: String, label: String, camera: Camera3D, frame: Node3D,
		stock: Node3D, eye: Vector3, aim: Vector3) -> void:
	camera.global_position = frame.to_global(eye)
	camera.look_at(frame.to_global(aim))
	var pose := camera.global_transform
	for show: bool in [false, true]:
		stock.visible = show
		for settle in 18:
			await RenderingServer.frame_post_draw
		check(camera.global_transform == pose and stock.is_visible_in_tree() == show,
			"paired native camera and stock " + label)
		var image := get_viewport().get_texture().get_image()
		var file := "%s_%s.png" % [label, "present" if show else "hidden"]
		if check(image.get_size() == Vector2i(3440, 1440), "native frame " + file):
			var path := folder.path_join(file)
			if check(image.save_png(path) == OK, "write frame " + file):
				frames.append({"file": file, "sha256": FileAccess.get_sha256(path), "visible": show,
					"eye": str(pose.origin), "basis": str(pose.basis)})
	stock.visible = true


func _bank_walk(world: OrisonV2RuntimeRoot, frame: Node3D) -> void:
	var start := Vector3(58.0, -1.0, -334.8)
	var finish := Vector3(58.0, -2.83, -338.0)
	var support := _ray(world, frame, start + Vector3.UP * 2.0, start - Vector3.UP * 2.0)
	var target := _ray(world, frame, finish + Vector3.UP * 0.8, finish - Vector3.UP * 0.8)
	if not check(not support.is_empty() and not target.is_empty(), "existing bank supports both walk endpoints"):
		return
	var point: Vector3 = support.position
	var body := CapsuleShape3D.new()
	body.height = PlayerController.STANDING_HEIGHT
	body.radius = PlayerController.BODY_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body
	query.collision_mask = STANDING_MASK
	query.exclude = [world.player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (0.03 + body.height * 0.5))
	if not check(world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "full standing bank placement"):
		return
	world.player.global_position = point + Vector3.UP * 0.03
	world.player.velocity = Vector3.ZERO
	world.player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for settle in 12:
		await get_tree().physics_frame
	var driver := WalkDriver.new()
	driver.externally_managed = true
	driver.world = world
	driver.player = world.player
	driver.route_label = "V2 CANAL LANDWARD BANK"
	add_child(driver)
	var recoveries := world.safety_net.recoveries
	var reached := await driver._walk(frame.to_local(target.position))
	var returned := await driver._walk(frame.to_local(support.position)) if reached else false
	check(reached and returned and world.player.is_on_floor() and not world.player.noclip and not world.player.crouched
		and world.safety_net.recoveries == recoveries, "ordinary standing input descends and returns on the existing bank")
	walk.assign(driver.trace)
	driver.free()


func _run() -> void:
	var folder := OS.get_environment("SHOT_DIR")
	if not check(not folder.is_empty() and DisplayServer.get_name() != "headless"
		and DirAccess.make_dir_recursive_absolute(folder) == OK, "hidden native viewport and evidence directory"):
		get_tree().quit(2)
		return
	var digest := _digest()
	check(digest.length() == 64, "bound production runtime source")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	check(CampaignClock.new().configure_date(1929, 2, 23, 720), "fixed isolated review date")
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	if check(not world.startup_failed and world.player != null, "native production composition"):
		await get_tree().physics_frame
		var frame: Node3D = world.adapter.root
		var rail := frame.get_node_or_null("Ground/IndustrialCutSidings") as MeshInstance3D
		var bank := frame.get_node_or_null("Ground/CanalBulkhead") as MeshInstance3D
		if check(rail != null and bank != null, "both direct production edge meshes"):
			_mapped(rail, 3)
			_mapped(bank, 2)
			check(rail.get_child_count() == 0 and rail.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"rail has no collision, lighting or shadow overhead")
			var physical := bank.get_node_or_null("SourceCollision") as StaticBody3D
			var face := _ray(world, frame, Vector3(57.25, -5.3, -346.0), Vector3(57.25, -5.3, -342.9))
			check(physical != null and face.get("collider") == physical
				and absf(frame.to_local(face.get("position", Vector3.ZERO)).z + 343.0) < 0.01,
				"visible timber face owns the new fixed collision")
			var native := _ray(world, frame, Vector3(58.0, 0.0, -338.0), Vector3(58.0, -5.0, -338.0))
			check(not native.is_empty() and native.get("collider") != physical
				and absf(frame.to_local(native.position).y + 2.82968) < 0.02,
				"landward ground remains the original grade")
			var coping := _ray(world, frame, Vector3(58.0, -2.0, -343.1), Vector3(58.0, -6.0, -343.1))
			check(physical != null and coping.get("collider") == physical
				and absf(frame.to_local(coping.get("position", Vector3.ZERO)).y + 4.2) < 0.01,
				"coping top agrees with the physical stock")
			var opposite := _ray(world, frame, Vector3(58.0, 8.0, -393.5), Vector3(58.0, -6.0, -393.5))
			check(not opposite.is_empty() and opposite.get("collider") != physical, "opposed bank has native support")
			await _bank_walk(world, frame)
			world.player.set_physics_process(false)
			world.player.set_lamp_enabled(false)
			world.service_set_carrier.set_capture_hidden(true)
			for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
				layer.hide()
			world.process_mode = Node.PROCESS_MODE_DISABLED
			var camera := Camera3D.new()
			add_child(camera)
			camera.cull_mask = world.player.camera.cull_mask
			camera.fov = world.player.camera.fov
			camera.near = world.player.camera.near
			camera.far = world.player.camera.far
			camera.keep_aspect = world.player.camera.keep_aspect
			camera.make_current()
			await _view(folder, "rail_cut", camera, frame, rail, RAIL_EYE, RAIL_AIM)
			await _view(folder, "canal", camera, frame, bank, CANAL_EYE, CANAL_AIM)
			if not opposite.is_empty():
				var opposed_eye := frame.to_local(opposite.position) + Vector3.UP * 1.6
				await _view(folder, "opposed_canal", camera, frame, bank, opposed_eye, Vector3(58.0, -5.1, -343.0))
			world.player.camera.make_current()
			camera.free()
	world.shutdown_for_tests()
	world.free()
	await get_tree().process_frame
	check(not is_instance_valid(world), "production world retired")
	check(digest == _digest(), "production runtime source stayed fixed")
	check(frames.size() == 6, "three paired native views")
	var receipt := FileAccess.open(folder.path_join("edge_review.json"), FileAccess.WRITE)
	if check(receipt != null, "write technical evidence"):
		receipt.store_string(JSON.stringify({"scope": "Paired loaded city edge images and nearby standing bank walk",
			"source_digest": digest, "frames": frames, "walk": walk, "failures": failures,
			"human_played": false, "artistically_accepted": false}, "\t") + "\n")
		receipt.close()
	print("CITY EDGE REVIEW: ", "PASS" if failures.is_empty() else "FAIL", "; ", frames.size(), " frames; ",
		failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
