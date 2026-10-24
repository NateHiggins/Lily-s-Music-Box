extends Node
## INERT review capture of the V2 street lamps (design/V2_STREET_LAMPS_2026-10-24.md).
## Windowed only. Checks the posts, the retired placeholders, the moved
## authored lights and the finishes, then captures the street at night. Not
## runtime proof and no acceptance grant.
const Selector := preload("res://scripts/building/building_root_selector.gd")
const Lamps := preload("res://scripts/building/orison_v2_street_lamps.gd")
var directory: String
var world: OrisonV2RuntimeRoot
var failures := 0
var summary := {"checks": [], "captures": []}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	summary.checks.append({"label": label, "ok": ok})
	print("STREET LAMP CHECK: ", label, " = ", ok)


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless" \
			or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Street lamp review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 20, 1260)
	Selector.reset_for_tests("v2")
	world = (load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.startup_failed:
		push_error("Production world failed")
		get_tree().quit(1)
		return
	await _review()
	var file := FileAccess.open(directory.path_join("street_lamps_review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, " ", false) + "\n")
	file.close()
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	CampaignTime.set_frozen_for_tests(false)
	print("STREET LAMP REVIEW: %d failures; no acceptance grant" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _review() -> void:
	var data := Lamps.load_table()
	var street := world.exterior_cell.instance_node(str(data.street_instance))
	var root := street.get_node_or_null("StreetLamps") as Node3D
	check(root != null, "production V2 mounts the street lamps in the street frame")
	if root == null:
		return
	var globe: Array = data.globe_local
	for lamp: Dictionary in data.lamps:
		var post := root.get_node_or_null(str(lamp.id)) as MeshInstance3D
		check(post != null and post.visible, "post stands: " + str(lamp.id))
		if post == null:
			continue
		var ok := true
		for surface in post.mesh.get_surface_count():
			var mat := post.mesh.surface_get_material(surface) as StandardMaterial3D
			ok = ok and mat != null and not mat.uv1_triplanar and mat.albedo_texture != null \
					and mat.normal_texture != null and mat.roughness_texture != null and mat.normal_enabled \
					and post.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV] != null \
					and mat.albedo_texture.get_image().has_mipmaps()
		check(ok, "every lamp surface samples authored UVs with catalogue maps and mips: " + str(lamp.id))
		for draw: MeshInstance3D in post.get_meta("original_draws", []):
			check(not draw.visible, "placeholder retired: " + str(draw.get_meta("authored_record_id", "")))
		var want := street.to_global(post.transform * Vector3(globe[0], globe[1], globe[2]))
		var found := false
		for light: OmniLight3D in street.find_children("*", "OmniLight3D", true, false):
			if light.global_position.distance_to(want) < 0.05:
				found = true
		check(found, "the lamp's light sits in its globe: " + str(lamp.id))

	var clock := root.get_node_or_null("LampClock")
	check(clock != null, "the lamps keep their own clock")
	if clock != null:
		clock.clock_override = {"valid": true, "month": 11, "minute_of_day": 720.0}
		clock.refresh()
		var dark := true
		for light: OmniLight3D in clock.lights:
			dark = dark and not light.visible
		check(dark and clock.lit == 0.0, "street lamps are out at noon")
		clock.clock_override = {"valid": true, "month": 11, "minute_of_day": 1260.0}
		clock.refresh()
		var lit: bool = clock.lights.size() == (data.lamps as Array).size()
		for light: OmniLight3D in clock.lights:
			lit = lit and light.visible and light.light_energy > 0.0
		check(lit and clock.lit == 1.0, "and lit at nine at night")
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	var traffic := world.period_traffic as OrisonV2StreetTraffic
	if traffic != null:
		traffic.stage([{"id": "ice_wagon", "lane_west": true, "x": 1.0, "travel": 0.4},
				{"id": "model_a_tudor", "lane_west": false, "x": 10.0}])
	world.player.camera.make_current()
	await _view(street, "pavement_east", Vector3(-6.0, 1.62, 2.6), Vector3(12.0, 2.6, 5.0))
	await _view(street, "pavement_west", Vector3(19.0, 1.62, 2.8), Vector3(-6.0, 2.4, 6.0))
	await _view(street, "from_arcade_side", Vector3(-9.5, 1.62, 16.2), Vector3(2.0, 2.4, 6.0))
	await _view(street, "signal_box", Vector3(12.2, 1.6, 2.5), Vector3(13.3, 1.6, 4.1))
	await _view(street, "crook_and_globe", Vector3(5.6, 1.7, 2.2), Vector3(8.1, 3.9, 4.8))
	if traffic != null:
		traffic.frozen = false


func _view(street: Node3D, label: String, at: Vector3, target: Vector3) -> void:
	var camera := world.player.camera
	camera.global_position = street.to_global(at)
	camera.look_at(street.to_global(target))
	for i in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	summary.captures.append(label + ".png")
