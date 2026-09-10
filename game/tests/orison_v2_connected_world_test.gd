extends Node
## Prepared native composition check. Ray clearance is not a capsule walkthrough.
const Connection := preload("res://scripts/building/orison_v2_world_connection.gd")
const Resolver := preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Fittings := preload("res://scripts/building/orison_v2_domestic_fittings.gd")
const Furniture := preload("res://scripts/building/orison_v2_domestic_furniture.gd")
var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CONNECTED WORLD: " + label)

func _run() -> void:
	RealityState.persistence_enabled = false
	var resolver: Variant = Resolver.load_default()
	var source := Connection.read_object("res://data/orison_v2_blockout.json")
	var geometry := Connection.read_object("res://data/orison_v2/exterior/exterior_geometry.json")
	var config := Connection.read_object(Connection.CONFIG_PATH)
	var preserved := geometry.duplicate(true)
	var plan := Connection.prepare(source, geometry, resolver, config)
	_check(not plan.is_empty(), "named threshold resolves")
	_check(geometry == preserved, "standalone geometry remains unchanged")
	var missing := config.duplicate(true)
	missing.door_id = "MISSING_THRESHOLD"
	_check(Connection.prepare(source, geometry, resolver, missing).is_empty(), "missing door refused")
	var blocked := config.duplicate(true)
	blocked.split_boxes = ["MISSING_TRIM"]
	_check(Connection.prepare(source, geometry, resolver, blocked).is_empty(), "missing portal cut refused")
	var duplicate := source.duplicate(true)
	duplicate.doors.append(Connection.unique_record(source.doors, config.door_id).duplicate(true))
	_check(Connection.prepare(duplicate, geometry, resolver, config).is_empty(), "duplicate door refused")
	resolver.teardown()
	for iteration in 2:
		RealityState.reset_campaign_for_tests()
		var fixed_clock := CampaignClock.new()
		_check(fixed_clock.configure_date(1928, 11, 10, 20 * 60), "fixed November evening")
		var world := Runtime.instantiate()
		add_child(world)
		await get_tree().process_frame
		await get_tree().physics_frame
		_check(not world.startup_failed, "composition %d starts" % iteration)
		if not world.startup_failed:
			var furniture_source := Connection.read_object(Furniture.PATH)
			var furniture_loader := Furniture.new()
			_check(furniture_loader.validate(furniture_source, world.adapter), "furniture source validates")
			var invalid_furniture := furniture_source.duplicate(true)
			invalid_furniture.furniture[0].surfaces[0].vertices.pop_back()
			_check(not furniture_loader.validate(invalid_furniture, world.adapter), "incomplete furniture triangle refused")
			for record: Dictionary in furniture_source.furniture:
				var body := world.adapter.resolve(str(record.id)) as StaticBody3D
				_check(body != null and body.get_meta("v2_furniture_id", "") == str(record.id),
						"furniture has a collision owner: " + str(record.id))
				if body != null:
					_check(body.find_children("*", "MeshInstance3D", true, false).size() >= record.surfaces.size(),
							"furniture has its extracted visible surfaces: " + str(record.id))
			var wc := world.adapter.resolve("3B_wc") as BakedFurnitureInteraction
			var wardrobe := world.adapter.resolve("3B_aw_wardrobe") as BakedFurnitureInteraction
			_check(wardrobe != null and wardrobe.owner_unit == "3B", "wardrobe preserves household ownership")
			if wardrobe != null:
				_check(wardrobe.interact_prompt() == "[E] Open private wardrobe", "wardrobe starts closed")
				wardrobe.interact()
				_check(wardrobe.interact_prompt() == "[E] Close private wardrobe", "wardrobe uses existing open action")
				await get_tree().create_timer(0.5).timeout
			var invalid_wardrobe := furniture_source.duplicate(true)
			for record: Dictionary in invalid_wardrobe.furniture:
				if record.kind == "wardrobe":
					record.mechanism.id = "another_household"
			_check(not furniture_loader.validate(invalid_wardrobe, world.adapter), "mismatched wardrobe owner refused")
			_check(wc != null and wc.owner_unit == "3B", "WC preserves household owner")
			if wc != null:
				_check(wc.interact_prompt() == "[E] Flush water closet", "WC starts ready")
				wc.interact()
				_check(wc.interact_prompt() == "[E] Test refilling cistern handle", "WC enters existing refill behavior")
			var fitting_source := Connection.read_object(Fittings.PATH)
			var loader := Fittings.new()
			_check(loader.validate(fitting_source, world.adapter), "domestic fitting records validate")
			for side in [-1.0, 1.0, 0.0, 1.5, "1"]:
				var drain_source := fitting_source.duplicate(true)
				drain_source.fittings[0].properties.drain_side = side
				_check(loader.validate(drain_source, world.adapter) == (typeof(side) == TYPE_FLOAT and absf(float(side)) == 1.0),
						"drain side accepts only numeric left/right: " + str(side))
			var duplicate_fitting := fitting_source.duplicate(true)
			duplicate_fitting.fittings.append(duplicate_fitting.fittings[0].duplicate(true))
			_check(not loader.validate(duplicate_fitting, world.adapter), "duplicate fitting refused")
			var bad_property := fitting_source.duplicate(true)
			bad_property.fittings[0].properties["unknown_setting"] = true
			_check(not loader.validate(bad_property, world.adapter), "unknown appliance setting refused")
			for fitting: Dictionary in fitting_source.fittings:
				var prop := world.find_child(str(fitting.id), true, false) as FunctionalProp
				_check(prop != null and prop.prop_type == str(fitting.kind)
						and str(prop.get("unit")) == str(fitting.unit), "fitting has one production owner: " + str(fitting.id))
				if prop != null:
					_check(prop.has_method("interact_prompt") and not str(prop.call("interact_prompt")).is_empty(),
							"fitting exposes its production interaction: " + str(fitting.id))
			var waking_environments := 0
			for environment_node in world.find_children("*", "WorldEnvironment", true, false):
				if environment_node.get_viewport() == world.get_viewport():
					waking_environments += 1
			_check(waking_environments == 1, "waking viewport owns one world environment")
			_check(world.day_night_director != null and not world.day_night_director.resolved_profile().is_empty(),
					"runtime atmosphere consumes campaign day/night profile")
			_check(world.shop_simulation != null and not world.shop_simulation.failed,
					"runtime owns active shop simulation")
			var exterior: Node3D = world.exterior_cell
			_check(exterior.global_transform.is_equal_approx(Transform3D.IDENTITY), "exterior keeps canonical frame")
			_check(exterior.player == world.player and exterior.work_orders == world.work_orders
					and exterior.maintenance_inventory == world.maintenance_inventory
					and exterior.shop_service == world.shop_service, "exterior shares gameplay authorities")
			_check(not exterior.route_guides_visible(), "exterior route guides hidden")
			var arrival: Dictionary = world.arrival_placement()
			world.first_shift_director.call("_place_at_arrival")
			_check(world.player.global_position.is_equal_approx(arrival.position), "first shift uses V2 arrival")
			var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, 1.0), Vector3(0, 1.0, -1.0))
			ray.exclude = [world.player.get_rid()]
			_check(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "front portal ray is unobstructed")
			_check(exterior.service_counter("SHOP_BODEGA") != null, "bodega service counter is mounted")
			var omar_radiator := world.find_child("F03_B_RADIATOR_01", true, false) as RadiatorProp
			_check(omar_radiator != null and omar_radiator.unit == "3B"
					and omar_radiator.section_count == 7, "3B radiator uses its preserved owner configuration")
			var construction: Node3D = world.adapter.root
			for station: Dictionary in world.layout.capsule_stations:
				if str(station.level) != "F03":
					continue
				var coordinates: Array = station.position
				var elevation := 0.0
				for level: Dictionary in world.layout.levels:
					if str(level.id) == str(station.level):
						elevation = float(level.y)
				var capsule := CapsuleShape3D.new()
				capsule.radius = 0.33
				capsule.height = 1.524
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, construction.to_global(Vector3(
						float(coordinates[0]), elevation + float(coordinates[1]), float(coordinates[2]))))
				query.exclude = [world.player.get_rid()]
				query.collide_with_areas = false
				_check(world.get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty(),
						"F03 capsule station clear: " + str(station.id))
				var ground := PhysicsRayQueryParameters3D.create(query.transform.origin,
						query.transform.origin - Vector3.UP * 1.1)
				ground.exclude = [world.player.get_rid()]
				_check(not world.get_world_3d().direct_space_state.intersect_ray(ground).is_empty(),
						"F03 capsule station has floor: " + str(station.id))
		if not world.startup_failed:
			await _verify_3b_switches(world)
		if iteration == 0 and not OS.get_environment("SHOT_DIR").is_empty() and not world.startup_failed:
			await _capture_3b(world)
		world.shutdown_for_tests()
		remove_child(world)
		world.free()
		# AudioServer retires stopped decoder instances on its mix thread.
		await get_tree().create_timer(0.25).timeout
		_check(get_tree().get_nodes_in_group("orison_v2_exterior_cell").is_empty(), "exterior detaches on reconstruction")
	print("CONNECTED WORLD: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

## Controlled standing poses exercise production targeting/input, not a walked route.
func _verify_3b_switches(world: Node3D) -> void:
	var player: CharacterBody3D = world.player
	var saved_pose := player.global_transform
	var saved_camera: Transform3D = player.camera.transform
	var was_processing := player.is_physics_processing()
	var was_looking := player.is_processing_unhandled_input()
	player.set_physics_process(false)
	# This fixture owns standing poses. Desktop mouse motion must not turn
	# its prescribed aim while ordinary polled interaction remains active.
	player.set_process_unhandled_input(false)
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var source := Connection.read_object("res://data/orison_v2/room_lighting.json")
	for record: Dictionary in source.switches:
		var plate := world.find_child(str(record.id), true, false) as StaticBody3D
		_check(plate != null, "mounted switch: " + str(record.id))
		if plate == null: continue
		var feet := plate.global_position - plate.global_basis.z * 0.75
		for anchor: Dictionary in world.layout.anchors:
			if anchor.id == record.id:
				feet.y = plate.global_position.y - float(anchor.position[1]) + 0.02
		player.global_position = feet
		player.camera.global_position = feet + Vector3.UP * player.STANDING_EYE
		player.camera.look_at(plate.to_global(Vector3(0, 0, -0.045)))
		await get_tree().physics_frame
		await get_tree().process_frame
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.33
		capsule.height = 1.524
		var stance := PhysicsShapeQueryParameters3D.new()
		stance.shape = capsule
		stance.transform.origin = feet + Vector3.UP * 0.762
		stance.exclude = [player.get_rid()]
		_check(world.get_world_3d().direct_space_state.intersect_shape(stance).is_empty(),
				"switch standing capsule clear: " + str(record.id))
		var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
				player.camera.global_position - player.camera.global_basis.z * 2.1)
		ray.collide_with_areas = true
		ray.exclude = [player.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		print("SWITCH TARGET ", record.id, " feet=", feet, " hit=", hit.get("collider"), " at=", hit.get("position"))
		_check(hit.get("collider") == plate, "player targets switch: " + str(record.id))
		player._update_prompt()
		_check("light" in player._prompt.text.to_lower(), "switch player prompt: " + str(record.id))
		for expected_on in [false, true]:
			# Timer callbacks run after Node._process. Inject at the next frame
			# boundary so the production just-pressed poll can observe the action.
			await get_tree().process_frame
			Input.action_press("interact")
			await get_tree().process_frame
			await get_tree().process_frame
			Input.action_release("interact")
			await get_tree().create_timer(0.8).timeout
			for fixture_record: Dictionary in source.fixtures:
				if fixture_record.kind == "lamp": continue
				var fixture := world.find_child(str(fixture_record.id), true, false) as LightFixtureProp
				var wanted: bool = expected_on if fixture_record.room == record.room else true
				_check(fixture.powered == wanted, "switch circuit isolation %s -> %s: %s" % [record.id, fixture_record.id, wanted])
				if fixture_record.room == record.room:
					_check(fixture.light.light_energy > 0.05 if wanted else fixture.light.light_energy < 0.05,
							"switch light output follows power: " + str(record.id))
			var task_lamp := world.find_child("F03_B_LAMP_01", true, false) as LampProp
			_check(task_lamp.is_locally_enabled(), "room switch preserves task lamp: " + str(record.id))
		# Looking away must not reuse the previous switch target.
		player.camera.look_at(player.camera.global_position - plate.global_basis.z)
		await get_tree().process_frame
		Input.action_press("interact")
		await get_tree().process_frame
		await get_tree().process_frame
		Input.action_release("interact")
		for fixture_record: Dictionary in source.fixtures:
			if fixture_record.kind == "lamp": continue
			var fixture := world.find_child(str(fixture_record.id), true, false) as LightFixtureProp
			_check(fixture.powered, "looking away leaves circuit on: " + str(fixture_record.id))
	player.global_transform = saved_pose
	player.camera.transform = saved_camera
	player.set_physics_process(was_processing)
	player.set_process_unhandled_input(was_looking)

func _capture_3b(world: Node3D) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var player: CharacterBody3D = world.player
	var was_processing := player.is_physics_processing()
	player.set_physics_process(false)
	player.set_lamp_enabled(false)
	var camera: Camera3D = player.camera
	camera.make_current()
	var construction: Node3D = world.adapter.root
	var views := [
		["3b_work", Vector3(13.6, 8.0, -2.5), Vector3(13.65, 7.3, -0.2)],
		["3b_kitchen", Vector3(10.2, 8.0, -7.35), Vector3(11.6, 7.2, -5.7)],
		["3b_sleep", Vector3(12.1, 8.0, -9.2), Vector3(10.45, 7.1, -10.5)],
		["3b_storage", Vector3(11.8, 8.0, -10.0), Vector3(10.4, 7.5, -8.5)],
		["3b_bath", Vector3(14.2, 8.0, -10.25), Vector3(14.4, 7.25, -11.8)]]
	var lighting_views: Array[Dictionary] = []
	for view: Array in views:
		player.global_position = construction.to_global(view[1]) - Vector3.UP * player.STANDING_EYE
		camera.global_position = construction.to_global(view[1])
		camera.look_at(construction.to_global(view[2]), Vector3.UP)
		await get_tree().create_timer(1.0).timeout
		var rig: LightRig = world.get_node("WakingAtmosphere/LightRig")
		var fixtures: Array[Dictionary] = []
		for fixture in rig.debug_fixtures():
			if not str(fixture.name).begins_with("F03_B_") and str(fixture.name)!="3B_LT_SCONCE":continue
			fixtures.append({"id":str(fixture.name),"position":str(fixture.global_position),"floor":rig._fixture_floor(fixture),"powered":fixture.get("powered"),"energy":fixture.light.light_energy,"light_position":str(fixture.light.global_position)})
		lighting_views.append({"view":str(view[0]),"rig":rig.stats(),"fixtures":fixtures})
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(directory.path_join(str(view[0]) + ".png"))
		_check(result == OK, "rendered view saved: " + str(view[0]))
	var lighting_file:=FileAccess.open(directory.path_join("lighting.json"),FileAccess.WRITE)
	lighting_file.store_string(JSON.stringify(lighting_views,"  "))
	player.set_physics_process(was_processing)
