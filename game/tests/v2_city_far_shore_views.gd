extends Node3D
## Technical optical fixture. No campaign or route authority.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Temporal := preload("res://scripts/game/prologue_temporal_sky.gd")
const ExtremeWeather := preload("res://scripts/building/queens_weather_extension.gd")
const ROOF_EYE := Vector3(-11.0, 20.8702503, 6.0)
const STREET_NOMINAL := Vector3(-280.0, -4.0, -10.0)
const PRODUCTION_PATHS := [
	"res://scripts/building/orison_v2_city_far_shore.gd",
	"res://scripts/building/orison_v2_city_shells.gd",
	"res://data/orison_v2/exterior/city_bridge.json",
	"res://scenes/building/orison_v2_runtime.tscn",
]

var _failures: Array[String] = []
var _frames: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(passed: bool, label: String) -> bool:
	if not passed:
		_failures.append(label)
		push_error("FAR SHORE: " + label)
	return passed


func _runtime_digest() -> String:
	var output: Array = []
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var code := OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], output)
	if code != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()


func _source_binding() -> Dictionary:
	var hashes: Dictionary = {}
	var paths: Array = PRODUCTION_PATHS.duplicate()
	paths.append(get_script().resource_path)
	paths.append(scene_file_path)
	for path: String in paths:
		var digest := FileAccess.get_sha256(path)
		_check(digest.length() == 64, "read source hash for " + path)
		hashes[path] = digest
	var runtime := _runtime_digest()
	_check(runtime.length() == 64, "read full production input digest")
	return {"runtime_inputs_sha256": runtime, "file_sha256": hashes}


func _inspect_skyline(skyline: MeshInstance3D) -> Dictionary:
	_check(skyline.visible and skyline.is_visible_in_tree(), "production skyline starts visible")
	_check(skyline.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "skyline adds no shadow pass")
	_check(skyline.get_child_count() == 0, "skyline is one direct passive mesh with no collision or lights")
	if not _check(skyline.mesh != null and skyline.mesh.get_surface_count() == 1, "one loaded skyline mesh surface"):
		return {}
	var material := skyline.get_active_material(0) as StandardMaterial3D
	if not _check(material != null, "loaded catalogue masonry material"):
		return {}
	_check(material.normal_enabled and not material.uv1_triplanar, "normal maps use the authored UV chart")
	var texture_paths: Array[String] = []
	for texture: Texture2D in [material.albedo_texture, material.roughness_texture, material.normal_texture]:
		if not _check(texture != null, "each masonry map is loaded"):
			continue
		var image := texture.get_image()
		_check(image != null and image.has_mipmaps(), "loaded masonry map has actual mipmaps")
		texture_paths.append(texture.resource_path)
	var arrays := skyline.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	_check(not points.is_empty() and uv.size() == points.size() and tangents.size() == points.size() * 4,
		"skyline retains vertex UVs and tangents")
	return {"mesh_path": str(skyline.get_path()), "vertices": points.size(), "surfaces": 1,
		"shadow_casting": int(skyline.cast_shadow), "child_count": skyline.get_child_count(),
		"world_bounds": str(skyline.global_transform * skyline.get_aabb()), "loaded_masonry": texture_paths}


func _street_floor(world: OrisonV2RuntimeRoot) -> Dictionary:
	var space := world.get_world_3d().direct_space_state
	var exclude: Array[RID] = [world.player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(STREET_NOMINAL + Vector3.UP * 3.0,
		STREET_NOMINAL - Vector3.UP * 4.0, 1, exclude)
	var hit := space.intersect_ray(ray)
	if not _check(not hit.is_empty() and hit.collider is StaticBody3D, "west street has an actual static floor"):
		return {}
	var floor: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if not _check(normal.dot(Vector3.UP) > 0.98 and absf(floor.y - STREET_NOMINAL.y) < 1.5,
			"west street support matches the ordinary route grade"):
		return {}
	var capsule := CapsuleShape3D.new()
	capsule.radius = PlayerController.BODY_RADIUS
	capsule.height = PlayerController.STANDING_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, floor + Vector3.UP * (0.03 + capsule.height * 0.5))
	if not _check(space.intersect_shape(query, 1).is_empty(), "west street has full standing capsule clearance"):
		return {}
	var eye := floor + Vector3.UP * (0.03 + world.player.camera.position.y)
	return {"eye": eye, "floor": str(floor), "normal": str(normal), "owner": str(hit.collider.get_path())}


func _capture_pair(output: String, skyline: MeshInstance3D, camera: Camera3D,
		projection: Node, view: Dictionary, clock_snapshot: Dictionary) -> void:
	projection.sampled_utc = float(view.utc)
	if not _check(projection.view_clock.seek_utc(projection.sampled_utc), "detached civil sample " + str(view.id)):
		return
	camera.global_position = view.eye
	var bearing := deg_to_rad(float(view.bearing))
	var direction := Vector3(sin(bearing), float(view.pitch), -cos(bearing))
	camera.look_at(camera.global_position + direction)
	var pose := camera.global_transform
	projection._publish()
	for visible: bool in [false, true]:
		skyline.visible = visible
		for settle: int in 18:
			await RenderingServer.frame_post_draw
		_check(camera.is_current() and camera.global_transform == pose, "paired camera pose " + str(view.id))
		_check(skyline.is_visible_in_tree() == visible, "paired skyline visibility " + str(view.id))
		_check(RealityState.data.campaign_clock == clock_snapshot, "detached optics preserve actual campaign clock")
		var variant := "present" if visible else "hidden"
		var filename := "%s_%s.png" % [view.id, variant]
		var frame := get_viewport().get_texture().get_image()
		if not _check(frame.get_size() == Vector2i(3440, 1440), "actual native frame dimensions " + filename):
			continue
		var path := output.path_join(filename)
		if not _check(frame.save_png(path) == OK, "save native frame " + filename):
			continue
		_frames.append({"file": filename, "sha256": FileAccess.get_sha256(path),
			"skyline_visible": visible, "pixels": [3440, 1440], "eye": str(camera.global_position),
			"basis": str(camera.global_basis), "bearing": view.bearing, "fov": camera.fov,
			"utc": projection.view_clock.utc_datetime()})
		print("FAR SHORE FRAME ", filename)


func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if not _check(not output.is_empty() and DisplayServer.get_name() != "headless", "hidden native window and evidence directory required"):
		get_tree().quit(2)
		return
	if not _check(DirAccess.make_dir_recursive_absolute(output) == OK, "writable evidence directory"):
		get_tree().quit(2)
		return
	var source := _source_binding()
	_check(OS.get_environment("DAYNIGHT_FORCE").is_empty(), "no environment override of detached date and time")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var clock := CampaignClock.new()
	_check(clock.configure_date(1929, 2, 23, 0), "isolated fixture date initialised once")
	var midnight := float(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))

	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	var record: Dictionary = {"evidence_class": "INERT", "scope": "Source-bound matched optical views only",
		"source": source, "frames": _frames, "failures": _failures, "artistically_accepted": false, "human_played": false}
	if _check(not world.startup_failed and world.player != null, "complete production city starts"):
		await get_tree().physics_frame
		var city := world.get_node_or_null("CityShells") as Node3D
		var skyline := world.get_node_or_null("CityShells/FarShoreSkyline") as MeshInstance3D
		var bridge := world.get_node_or_null("CityShells/QueensboroBridge") as Node3D
		if _check(city != null and skyline != null and bridge != null, "direct production skyline and existing bridge are mounted"):
			record["skyline"] = _inspect_skyline(skyline)
			var street := _street_floor(world)
			if not street.is_empty():
				record["west_street"] = {"eye": str(street.eye), "floor": street.floor,
					"normal": street.normal, "owner": street.owner}
			record["manhattan_landing"] = str(bridge.global_position)
			await _review_views(output, world, city, skyline, bridge, street, midnight)
	print("FAR SHORE TEARDOWN BEGIN")
	world.shutdown_for_tests()
	print("FAR SHORE TEARDOWN SHUTDOWN")
	world.free()
	print("FAR SHORE TEARDOWN FREED")
	for drain: int in 8:
		await get_tree().process_frame
	_check(not is_instance_valid(world), "production world retired")
	_check(_source_binding() == source, "runtime and explicitly named source bytes stayed fixed")
	_check(_frames.size() == 8, "four native visible and hidden pairs are complete")
	record["retired"] = not is_instance_valid(world)
	record["status"] = "PASS" if _failures.is_empty() else "FAIL"
	var receipt := FileAccess.open(output.path_join("optical_review.json"), FileAccess.WRITE)
	if receipt != null:
		receipt.store_string(JSON.stringify(record, "\t") + "\n")
		receipt.close()
	else:
		_check(false, "write technical optical review record")
	print("FAR SHORE VIEW REVIEW: ", "PASS" if _failures.is_empty() else "FAIL",
		"; ", _frames.size(), " frames; ", _failures.size(), " failures")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _review_views(output: String, world: OrisonV2RuntimeRoot, city: Node3D, skyline: MeshInstance3D,
		bridge: Node3D, street: Dictionary, midnight: float) -> void:
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var snapshot: Dictionary = RealityState.data.campaign_clock.duplicate(true)

	var camera := Camera3D.new()
	add_child(camera)
	camera.cull_mask = world.player.camera.cull_mask
	camera.fov = 78.0
	camera.near = world.player.camera.near
	camera.far = world.player.camera.far
	camera.keep_aspect = world.player.camera.keep_aspect
	camera.make_current()
	var projection := Temporal.new()
	add_child(projection)
	projection.world = world
	projection.camera = camera
	projection.director = world.day_night_director
	projection.manager = world.get_node("WakingAtmosphere").weather_manager
	projection._view_extreme = ExtremeWeather.new()
	projection._city = city
	projection.age = Temporal.ROOF_START
	var original_clock: CampaignClock = projection.director._campaign_clock
	var original_extreme: RefCounted = projection.director.extreme_weather
	var original_conditions: Dictionary = projection.director._live_conditions
	projection.director._campaign_clock = projection.view_clock
	projection.director.extreme_weather = projection._view_extreme

	var roof_eye := world.adapter.root.to_global(ROOF_EYE)
	var views: Array[Dictionary] = [
		{"id": "roof_day", "bearing": 323.0, "pitch": 0.085, "utc": midnight + 720 * 60.0, "eye": roof_eye},
		{"id": "roof_dusk", "bearing": 309.0, "pitch": 0.085, "utc": midnight + 1043 * 60.0, "eye": roof_eye},
		{"id": "roof_night", "bearing": 338.0, "pitch": 0.085, "utc": midnight + 1150 * 60.0, "eye": roof_eye},
	]
	if not street.is_empty():
		var eye: Vector3 = street.eye
		var delta := bridge.global_position - eye
		var bearing := fposmod(rad_to_deg(atan2(delta.x, -delta.z)), 360.0)
		views.append({"id": "west_street_day", "bearing": bearing, "pitch": 0.015,
			"utc": midnight + 720 * 60.0, "eye": eye})
	for view: Dictionary in views:
		await _capture_pair(output, skyline, camera, projection, view, snapshot)
	_check(RealityState.data.campaign_clock == snapshot, "final gameplay clock matches frozen snapshot")
	skyline.visible = true
	projection.director._campaign_clock = original_clock
	projection.director.extreme_weather = original_extreme
	projection.director._live_conditions = original_conditions
	world.player.camera.make_current()
	projection.free()
	camera.free()
