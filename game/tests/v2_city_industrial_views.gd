extends Node3D
## Loaded geometry and paired optics of the rail cut and canal edge. Since
## Lily's ruling barrier_distance (2026-11-07) the walkable city ends at 200 m,
## so the canal bank (about 340 m out) is view-only: the old standing bank walk
## is replaced by a check that the bank lies beyond the city edge mist.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Mist := preload("res://scripts/building/orison_v2_city_edge_mist.gd")
const STANDING_MASK := 1 | preload("res://scripts/building/v2_fire_player_contact.gd").LAYER
const RAIL_EYE := Vector3(-290.0, 12.0, 60.0)
const RAIL_AIM := Vector3(-390.0, -3.5, 0.0)
const RAIL_STANDING := Vector3(-430.0, -3.5, 20.0)
const RAIL_YARD_AIM := Vector3(-462.0, -1.5, -24.0)
const CANAL_EYE := Vector3(20.0, 7.0, -310.0)
const CANAL_AIM := Vector3(50.0, -6.0, -360.0)

var failures: Array[String] = []
var frames: Array[Dictionary] = []
var bank_reach: Dictionary = {}


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


## The bank's walk endpoints, measured in the front-door frame, must lie past
## the mist's pass-out ring: no player can stand there any more.
func _bank_beyond_edge(world: OrisonV2RuntimeRoot, frame: Node3D) -> void:
	var boundary := world.get_node_or_null("StreetBoundaries") as Node3D
	if not check(boundary != null and boundary.get_node_or_null("CityEdgeMist") != null, "city edge mist owner"):
		return
	var radii: Array[float] = []
	for local: Vector3 in [Vector3(58.0, -1.0, -334.8), Vector3(58.0, -2.83, -338.0)]:
		var at := boundary.to_local(frame.to_global(local))
		radii.append(Vector2(at.x, at.z).length())
	bank_reach = {"bank_radii_m": radii, "pass_out_m": Mist.PASS_OUT_M}
	check(radii.min() > Mist.PASS_OUT_M + 10.0, "the canal bank lies beyond the walkable city edge")


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
			_mapped(rail, 4)
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
			var rail_floor := _ray(world, frame, RAIL_STANDING + Vector3.UP * 0.2, RAIL_STANDING - Vector3.UP * 0.2)
			check(not rail_floor.is_empty() and (rail_floor.normal as Vector3).dot(Vector3.UP) > 0.98,
				"proven apron standing station retains its actual floor")
			_bank_beyond_edge(world, frame)
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
			if not rail_floor.is_empty():
				var rail_eye := frame.to_local(rail_floor.position) + Vector3.UP * 1.6
				await _view(folder, "rail_standing", camera, frame, rail, rail_eye, RAIL_YARD_AIM)
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
	check(frames.size() == 8, "four paired native views")
	var receipt := FileAccess.open(folder.path_join("edge_review.json"), FileAccess.WRITE)
	if check(receipt != null, "write technical evidence"):
		receipt.store_string(JSON.stringify({"scope": "Paired loaded city edge images; the canal bank is beyond the 200 m walkable edge",
			"source_digest": digest, "frames": frames, "bank_reach": bank_reach, "failures": failures,
			"human_played": false, "artistically_accepted": false}, "\t") + "\n")
		receipt.close()
	print("CITY EDGE REVIEW: ", "PASS" if failures.is_empty() else "FAIL", "; ", frames.size(), " frames; ",
		failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
