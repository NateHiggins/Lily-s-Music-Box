extends Node
## Prepared native composition check. Ray clearance is not a capsule walkthrough.
const Connection := preload("res://scripts/building/orison_v2_world_connection.gd")
const Resolver := preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
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
		var world := Runtime.instantiate()
		add_child(world)
		await get_tree().process_frame
		await get_tree().physics_frame
		_check(not world.startup_failed, "composition %d starts" % iteration)
		if not world.startup_failed:
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
		world.shutdown_for_tests()
		remove_child(world)
		world.free()
		await get_tree().process_frame
		_check(get_tree().get_nodes_in_group("orison_v2_exterior_cell").is_empty(), "exterior detaches on reconstruction")
	print("CONNECTED WORLD: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
