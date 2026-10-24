extends Node
## INERT review capture of the V2 front entrance and entry vestibule
## (design/V2_ENTRY_VESTIBULE_2026-10-24.md). Windowed only. Boots the
## production V2 world at night, counts every light that reaches the
## entrance, checks the vestibule dress, and captures the street approach
## and the vestibule interior. Not runtime proof and no acceptance grant.
const Selector := preload("res://scripts/building/building_root_selector.gd")
## The entrance's light census radius, metres from the street door's centre.
const CENSUS_RADIUS := 6.0
var directory: String
var world: OrisonV2RuntimeRoot
var failures := 0
var summary := {"checks": [], "captures": [], "lights": []}


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	summary.checks.append({"label": label, "ok": ok})
	print("ENTRY VESTIBULE CHECK: ", label, " = ", ok)


func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless" \
			or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Entry vestibule review requires windowed capture and SHOT_DIR")
		get_tree().quit(1)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928, 11, 20, 1290)
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
	var file := FileAccess.open(directory.path_join("entry_vestibule_review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, " ", false) + "\n")
	file.close()
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	CampaignTime.set_frozen_for_tests(false)
	print("ENTRY VESTIBULE REVIEW: %d failures; no acceptance grant" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _review() -> void:
	var root: Node3D = world.adapter.root
	var street_door := world.adapter.resolve("F01_DOOR_06") as Node3D
	var inner := world.adapter.resolve("F01_INNER_DOOR") as Node3D
	check(street_door != null and street_door.has_node("F01_DOOR_06_Leaf"),
			"the street door keeps its production leaf")
	check(inner != null and not inner.has_node("Hinge") and not inner.has_node("F01_INNER_DOOR_Leaf"),
			"the vestibule's inner doorway hangs no leaf")
	check(inner != null and inner.has_node("DoorCasings") and inner.has_node("EmptyButts"),
			"the unhung doorway keeps its casings and its empty jamb butts")
	var vestibule := root.find_child("EntryVestibule", true, false) as Node3D
	check(vestibule != null, "the entry vestibule owner is composed")
	if vestibule != null:
		var names := vestibule.find_child("DirectoryNames", true, false)
		check(names != null and names.get_child_count() >= 18,
				"the directory board lists every unit in Label3D")
		for part: String in ["EstablishedPlaque", "NoticeHum", "NoticeHouse",
				"SignalPoint", "Radiator", "DoorMat", "CoatHooks", "F01_ENTRANCE_GAS_LANTERN", "F01_VESTIBULE_GAS_BRACKET", "GasSupply"]:
			check(vestibule.find_child(part, true, false) != null, "vestibule carries " + part)
	var door_at := street_door.global_position if street_door != null else Vector3.ZERO
	for node: Node in world.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		# The player's carried set and the sky are not the entrance's lights.
		if not light.is_visible_in_tree() or light.light_energy <= 0.0 				or light is DirectionalLight3D or world.player.is_ancestor_of(light):
			continue
		var distance := light.global_position.distance_to(door_at)
		if distance > CENSUS_RADIUS:
			continue
		summary.lights.append({"path": str(root.get_path_to(light)) if root.is_ancestor_of(light) else str(light.get_path()),
				"class": light.get_class(), "energy": light.light_energy,
				"distance": snappedf(distance, 0.01), "shadow": light.shadow_enabled})
	if OS.get_environment("ENTRY_PROBE") == "1":
		var probe := AABB(Vector3(-0.8, 0.2, -10.3), Vector3(1.6, 1.8, 0.95))
		for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
			var draw := node as GeometryInstance3D
			var box := root.global_transform.affine_inverse() * draw.global_transform * draw.get_aabb()
			if draw.is_visible_in_tree() and box.intersects(probe) and box.size.length() < 6.0:
				print("DOORWAY PROBE: ", root.get_path_to(draw) if root.is_ancestor_of(draw) else draw.get_path(), " ", box)
	print("ENTRANCE LIGHTS WITHIN %.1f m: %d" % [CENSUS_RADIUS, summary.lights.size()])
	for row: Dictionary in summary.lights:
		print("  ", row)
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	world.player.camera.make_current()
	await _view(root, "street_night", Vector3(2.2, 1.62, -21.0), Vector3(0.0, 2.0, -11.65))
	await _view(root, "kerb_night", Vector3(-1.4, 1.62, -16.0), Vector3(0.0, 1.7, -11.65))
	await _view(root, "under_awning", Vector3(0.7, 1.62, -13.3), Vector3(0.0, 1.5, -11.65))
	await _view(root, "vestibule_entering", Vector3(0.0, 1.6, -11.35), Vector3(0.0, 1.35, -9.3))
	await _view(root, "vestibule_west", Vector3(1.3, 1.6, -10.45), Vector3(-2.33, 1.35, -10.45))
	await _view(root, "vestibule_east", Vector3(-1.3, 1.6, -10.45), Vector3(2.33, 1.0, -10.45))
	await _view(root, "vestibule_north", Vector3(0.3, 1.6, -11.2), Vector3(1.3, 1.1, -9.32))
	await _view(root, "from_lobby", Vector3(0.0, 1.6, -6.6), Vector3(0.0, 1.4, -11.0))
	await _view(root, "directory_close", Vector3(-1.45, 1.55, -10.55), Vector3(-2.33, 1.45, -10.55))
	await _view(root, "notices_close", Vector3(1.38, 1.55, -10.25), Vector3(1.38, 1.4, -9.32))
	await _view(root, "plaque_close", Vector3(-1.5, 1.55, -10.4), Vector3(-1.5, 1.5, -9.32))
	await _view(root, "gas_bracket_close", Vector3(0.6, 1.9, -10.6), Vector3(0.6, 2.4, -9.32))
	await _view(root, "lantern_close", Vector3(-0.2, 1.9, -13.1), Vector3(-0.79, 2.3, -11.95))


func _view(root: Node3D, label: String, at: Vector3, target: Vector3) -> void:
	var camera := world.player.camera
	camera.global_position = root.to_global(at)
	camera.look_at(root.to_global(target))
	for i in 10:
		await RenderingServer.frame_post_draw
	var path := directory.path_join(label + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	summary.captures.append(label + ".png")
