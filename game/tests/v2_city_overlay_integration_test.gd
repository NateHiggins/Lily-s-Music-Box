extends Node3D
## Combined production mount, existing placement probes, and matched station captures.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const NearProbe := preload("res://tests/v2_near_furniture_probe.gd")
const Near := preload("res://scripts/building/orison_v2_city_near_furniture.gd")
const FrontsProbe := preload("res://tests/v2_city_fronts_probe.gd")

var failures: Array[String] = []
var checks := 0
var world: OrisonV2RuntimeRoot

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("CITY OVERLAYS: " + description)
	return ok

func _run() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928, 11, 17, 14 * 60)
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled = false
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	world = Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms <= 0.0 and not world.startup_failed:
		await get_tree().process_frame
	var near := world.get_node_or_null("CityNearFurniture") as Node3D
	var fronts := world.get_node_or_null("CityFronts") as Node3D
	var timing := {}
	if _check(not world.startup_failed and near != null and fronts != null, "production composes both overlays"):
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(near.get_parent() == world and fronts.get_parent() == world
			and near.global_transform.is_equal_approx(Transform3D.IDENTITY)
			and fronts.global_transform.is_equal_approx(Transform3D.IDENTITY), "both overlays use the surveyed world frame")
		var shapes := _check_furniture(near)
		_check_walks(shapes)
		_check(fronts.find_children("*", "CollisionObject3D", true, false).is_empty(), "overhead fronts preserve all existing collision owners")
		_check(fronts._shop_letters.size() == fronts.data.signs.size() and not fronts._shop_letters.is_empty(), "each shop sign has authored lettering")
		_check_fronts(fronts)
		if failures.is_empty() and DisplayServer.get_name() != "headless":
			timing = await _review(window_camera(), near, fronts, clock, output)
	var file := FileAccess.open(output.path_join("city_overlay_integration.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"frame_ms":timing},"\t"))
		file.close()
	world.shutdown_for_tests()
	world.free()
	await get_tree().process_frame
	print("CITY OVERLAYS: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() and file != null else 1)

func _check_furniture(near: Node3D) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	var excluded: Array[RID] = [world.player.get_rid()]
	for body: StaticBody3D in near.find_children("*", "StaticBody3D", true, false):
		excluded.append(body.get_rid())
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			shapes.append(shape)
	var space := world.get_world_3d().direct_space_state
	var survey := NearProbe.new()
	var groups: Array = near.data.furniture.duplicate()
	groups.append({"kind":"telegraph_pole", "items":near.data.poles})
	var expected := 0
	for group: Dictionary in groups:
		var kind := String(group.kind)
		var body := near.get_node_or_null("Near_%s_collision" % kind) as StaticBody3D
		expected += group["items"].size()
		if not _check(body != null and body.get_child_count() == group["items"].size(), "mounted collision count for " + kind): continue
		var size: Vector3 = Near.SIZES[kind]
		for index in group["items"].size():
			var item: Array = group["items"][index]
			var collision := body.get_child(index) as CollisionShape3D
			var center := Vector3(item[0], float(item[1])+size.y*.5, item[2])
			_check(collision.global_position.is_equal_approx(center), "surveyed collider location %s %d" % [kind,index])
			var verdict: Dictionary = survey._judge(space, world, excluded, kind, item, size)
			_check(verdict.is_empty(), "existing world clearance %s %d %s" % [kind,index,verdict])
	survey.free()
	_check(shapes.size() == expected and expected > 0, "one physical collider per installed piece")
	return shapes

func _check_fronts(fronts: Node3D) -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../art/blender/data/city_fronts/accepted.json").simplify_path()
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(source is Dictionary and source.get("items") is Dictionary, "accepted exterior source inventory is available"):
		return
	var survey := FrontsProbe.new()
	var space := world.get_world_3d().direct_space_state
	var excluded: Array[RID] = [world.player.get_rid()]
	for kind: String in source.items:
		for row: Dictionary in source.items[kind]:
			var item := row.duplicate(true)
			var verdict: Dictionary = survey._judge(space, world, excluded, kind, item)
			var original := Vector3(row.at[0], row.at[1], row.at[2])
			var fitted := Vector3(item.at[0], item.at[1], item.at[2])
			_check(verdict.is_empty() and original.distance_to(fitted) < .002,
				"accepted %s retains its installed support and clearance at %s %s" % [kind, original, verdict])
	survey.free()
	for index in fronts._shop_letters.size():
		var label: Label3D = fronts._shop_letters[index]
		var width := label.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x * label.pixel_size
		var blockers: Array[String] = []
		var eye := label.global_position + label.global_basis.z*7.0 - Vector3.UP*1.65
		for fraction: float in [-.48, -.24, 0, .24, .48]:
			var face := label.to_global(Vector3(width*fraction, 0, .004))
			var lower_letters := face - Vector3.UP*label.font_size*label.pixel_size*.23
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, lower_letters, 1, excluded))
			if not hit.is_empty():
				blockers.append(str(hit.collider.get_path()))
		_check(blockers.is_empty(), "existing trim clears the fitted lettering %s %s" % [label.text, blockers])

func _check_walks(shapes: Array[CollisionShape3D]) -> void:
	for id: String in ["ROUTE_ORISON_TO_SHOP_BODEGA", "ROUTE_STREET_TO_ARCADE"]:
		var route: Dictionary = world.exterior_cell.route(id)
		if not _check(route.get("nodes", []).size() > 1, "registered route " + id): continue
		for index in route.nodes.size()-1:
			var start: Vector3 = route.nodes[index].placement.position + Vector3.UP*.75
			var end: Vector3 = route.nodes[index+1].placement.position + Vector3.UP*.75
			var clear := true
			for shape: CollisionShape3D in shapes:
				var size: Vector3 = (shape.shape as BoxShape3D).size
				var bounds: AABB = shape.global_transform * AABB(-size*.5,size)
				if bounds.grow(world.player._capsule.radius).intersects_segment(start,end) != null:
					clear = false
					break
			_check(clear, "installed furniture clears player envelope on %s segment %d" % [id,index])

func window_camera() -> Camera3D:
	world.player.set_physics_process(false)
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 800.0
	world.add_child(camera)
	camera.make_current()
	return camera

func _review(camera: Camera3D, near: Node3D, fronts: Node3D, clock: CampaignClock, output: String) -> Dictionary:
	var corner: Dictionary = near.data.signs[0]
	var post := Vector3(corner.x, corner.y, corner.z)
	camera.global_position = post + Vector3(-3.2, 1.7, 4.5)
	camera.look_at(post + Vector3.UP*2.6)
	await _capture(output.path_join("corner_day.png"))
	var corner_timing := await _timing(near, fronts)
	for index in fronts.data.signs.size():
		var shop: Dictionary = fronts.data.signs[index]
		var center := Vector3(shop.at[0], shop.at[1], shop.at[2])
		var normal := Vector3(sin(shop.yaw), 0, cos(shop.yaw))
		camera.global_position = center + normal*maxf(7.0, float(shop.width)) - Vector3.UP*1.65
		camera.look_at(center)
		await _capture(output.path_join("shop_%d_day.png" % index))
	var sign: Dictionary = fronts.data.signs[0]
	var at := Vector3(sign.at[0], sign.at[1], sign.at[2])
	var facing := Vector3(sin(sign.yaw), 0, cos(sign.yaw))
	camera.global_position = at + facing*7.0 - Vector3.UP*1.5
	camera.look_at(at)
	var front_timing := await _timing(near, fronts)
	_check(fronts._shop_letters[0].shaded,"day lettering takes scene light")
	clock.configure_date(1928,11,17,21*60)
	var deadline := Time.get_ticks_msec()+8000
	while fronts._shop_letters[0].shaded and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not fronts._shop_letters[0].shaded,"the production clock lights the lettering after dark")
	await _capture(output.path_join("front_night.png"))
	return {"corner":corner_timing,"front":front_timing}

func _capture(path: String) -> void:
	for frame in 20: await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(path) == OK, "wrote " + path.get_file())

func _timing(near: Node3D, fronts: Node3D) -> Dictionary:
	var shown: Array[float] = []
	var hidden: Array[float] = []
	for visible: bool in [true,false,false,true]:
		near.visible = visible
		fronts.visible = visible
		for frame in 12: await RenderingServer.frame_post_draw
		var samples := shown if visible else hidden
		for frame in 45:
			var started := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			samples.append((Time.get_ticks_usec()-started)/1000.0)
	shown.sort()
	hidden.sort()
	return {"shown_p50":shown[45],"shown_p95":shown[85],"hidden_p50":hidden[45],"hidden_p95":hidden[85],"samples_each":90}
