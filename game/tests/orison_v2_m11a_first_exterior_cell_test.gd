extends Node
## M11A objective proof for the first production exterior cell.
##
## The production source contains one street and one shop. This harness builds
## that exact source for the player-facing route, then injects a disposable
## second street/shop record through the same public resolver, bucket registry,
## and generic builder. The injected records never enter the capture source.

const CELL_SCENE_PATH := \
		"res://scenes/building/orison_v2_exterior_cell.tscn"
const SPATIAL_PATH := "res://data/orison_v2/exterior/regions.json"
const GEOMETRY_PATH := "res://data/orison_v2/exterior/exterior_geometry.json"
const BUCKET_PATH := "res://data/orison_v2/exterior/shop_buckets.json"
const SAVE_PATH := "user://tests/m11a_first_exterior_cell.json"
const RECEIPT_ENV := "M11A_OBJECTIVE_RECEIPT"

const SpatialResolver := preload(
		"res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const SemanticState := preload(
		"res://scripts/building/orison_v2_exterior_semantic_state.gd")
const ShopBucketRegistry := preload(
		"res://scripts/building/orison_v2_shop_bucket_registry.gd")
const Selector := preload("res://scripts/building/building_root_selector.gd")

const PRIMARY_STREET := "STREET_ORISON_01"
const PRIMARY_SHOP := "SHOP_BODEGA"
const PRIMARY_THRESHOLD := "THRESHOLD_SHOP_BODEGA_FRONT"
const OUTBOUND_ROUTE := "ROUTE_ORISON_TO_SHOP_BODEGA"
const RETURN_ROUTE := "ROUTE_SHOP_BODEGA_TO_ORISON"
const STOREFRONT_LEAF := "SHOP_BODEGA_STOREFRONT_LEAF"
const SEMANTIC_STATE_ID := "PLAYER_EXTERIOR_ROUTE"
const JOB_ID := "vantry_chirp_2a"

const SECOND_STREET := "STREET_ROTATED_02"
const SECOND_SHOP := "SHOP_BODEGA_ROTATED_02"
const SECOND_THRESHOLD := "THRESHOLD_SHOP_BODEGA_ROTATED_02_FRONT"
const SECOND_OUTBOUND := "ROUTE_ORISON_02_TO_SHOP_BODEGA_ROTATED_02"
const SECOND_RETURN := "ROUTE_SHOP_BODEGA_ROTATED_02_TO_ORISON_02"
const SECOND_YAW_DEGREES := 35.0

const PROTECTED := {
	"res://data/building_layout.json":
		"68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d",
	"res://../art/data/building_layout.json":
		"68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d",
	"res://scripts/building/building_root_selector.gd":
		"d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802",
	"res://assets/building/floor_01.gltf":
		"906f1f48c2fc8ff6e6af3048d0abca46416cd103bee8d818606a3c32c71fe5b1",
	"res://assets/building/floor_01.bin":
		"e1d3454afb6079602b8cfe0dcb00d255e6aa68f7f247c5ecc39bd5791cfdc477",
	"res://assets/building/floor_02.gltf":
		"b3977546cabc72775ad63be53bfb2001ace51d13094b4ed8b719a979adc2d640",
	"res://assets/building/floor_02.bin":
		"4b7d16ae8ed7df4a90f0626746ca5987bd02c61268f372fced86a3782760b69e",
	"res://assets/building/floor_03.gltf":
		"21c506695edf27effa20c711f1daed939c807a774f5076656e8ff3e8be898d3f",
	"res://assets/building/floor_03.bin":
		"8f84cb67f5f2fa8f2c5a5e47fbc418630957dbc8d6a96576e005c92ac6fcc9f8",
	"res://assets/building/floor_04.gltf":
		"c1a03abba15f481e6318e27d5035dae13e3e5173f16c2f208711769ce3bf8df1",
	"res://assets/building/floor_04.bin":
		"f57f45d79738086a5da23afd7d9a04d6f5596641193ec22856929de30b03e266",
	"res://assets/building/floor_05.gltf":
		"d5860b28c47a110fcced5b8cd22c0f5d4ae0fc036dfc0d44fbe884a2def41e7a",
	"res://assets/building/floor_05.bin":
		"a8e7f0fd106696a1c6c9823f30cf013b0f664e4dac5d763fc2c3d2c072dd54d8",
	"res://assets/building/floor_06.gltf":
		"96991ecf897b7882c68897eb9c8df5a678046e1567e8f59d51f21f6646209422",
	"res://assets/building/floor_06.bin":
		"8389d2264ea4c6e4eb59fb35b58d7480b3823641c1471b593a85613883bd9f5f",
	"res://assets/building/floor_b1.gltf":
		"f151ff10c8d2420340fc522df5e9eb2ffbdf200be6068b302c6769881af8eb3e",
	"res://assets/building/floor_b1.bin":
		"226437a3e2816882c04749918a4d99540ff2a4714d0a914b2dd2606ace8c4449",
}

var failures := 0
var passes := 0
var _cell_scene: PackedScene
var _baseline_counts := {}
var _receipt := {
	"schema_version": 2,
	"task": "ORISON-V2-M11A-A",
	"checks": [],
	"route": {},
	"presentation": {},
	"save_reconstruction": {},
	"piece_two": {},
	"teardown": {},
	"protected": {},
}
var _old_persistence := true
var _old_save_path := ""


func _ready() -> void:
	_old_persistence = RealityState.persistence_enabled
	_old_save_path = RealityState.save_path
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases._ready()
	_cell_scene = load(CELL_SCENE_PATH) as PackedScene
	_check(_cell_scene != null, "production exterior module scene loads")
	if _cell_scene == null:
		_finish()
		return
	# Warm only source-independent renderer/service caches before measuring the
	# ownership baseline. Every subsequently tested module must return here.
	await _warm_and_release()
	_baseline_counts = _object_counts()
	_receipt["teardown"]["baseline"] = _baseline_counts.duplicate(true)

	_test_authoritative_bucket_reader()
	await _test_primary_runtime_route_and_save()
	await _test_rotated_piece_two()
	_test_protected_boundary()
	await _settle_teardown()
	var final_counts: Dictionary = _object_counts()
	_receipt["teardown"]["final"] = final_counts.duplicate(true)
	var orphan_delta := int(final_counts.orphan_nodes) \
			- int(_baseline_counts.orphan_nodes)
	var object_delta := int(final_counts.objects) - int(_baseline_counts.objects)
	var resource_delta := int(final_counts.resources) \
			- int(_baseline_counts.resources)
	_receipt["teardown"]["delta"] = {
		"objects": object_delta,
		"resources": resource_delta,
		"orphan_nodes": orphan_delta,
	}
	_check(orphan_delta == 0, "teardown retains zero orphan nodes")
	_check(object_delta <= 0, "teardown retains zero ObjectDB instances")
	_check(resource_delta <= 0, "teardown retains zero resources")
	_finish()


func _warm_and_release() -> void:
	var warm: Node = _cell_scene.instantiate()
	add_child(warm)
	await get_tree().physics_frame
	if warm.has_method("shutdown_for_tests"):
		warm.call("shutdown_for_tests")
	remove_child(warm)
	warm.free()
	warm = null
	await _settle_teardown()
	RealityState.reset_campaign_for_tests()


## Required proofs 1-7: authoritative data, all fields, shared registry path,
## timetable catch-up, idempotence/refusal, and inventory authority ownership.
func _test_authoritative_bucket_reader() -> void:
	RealityState.reset_campaign_for_tests()
	var parsed: Dictionary = _read_json(BUCKET_PATH)
	var registry: Variant = ShopBucketRegistry.new()
	var loaded: bool = registry.load_source()
	var record: Dictionary = registry.source_record(PRIMARY_SHOP)
	_check(loaded and registry.source_ids() == [PRIMARY_SHOP]
			and record == parsed.get("shops", [])[0],
			"authoritative source reader returns canonical SHOP_BODEGA")
	var expected_record_keys := ["id", "initial_state", "lineage_id",
			"region_id", "rendering_tier", "schedule_place",
			"simulation_tier", "stock_units_per_visit"]
	var record_keys: Array = record.keys()
	record_keys.sort()
	var state_keys: Array = (record.get("initial_state", {}) as Dictionary).keys()
	state_keys.sort()
	_check(record_keys == expected_record_keys and state_keys == ["condition",
			"hours", "last_advanced_minute", "staffing", "stock",
			"transactions"], "every durable bodega source field is consumed")

	var extended: Dictionary = _extended_bucket_source()
	_check(registry.configure(extended) and registry.initialize_missing_state()
			and registry.source_ids() == [PRIMARY_SHOP, SECOND_SHOP]
			and not registry.snapshot(PRIMARY_SHOP).is_empty()
			and not registry.snapshot(SECOND_SHOP).is_empty(),
			"two shop identities use one registry and durable bucket path")

	var schedule := ScheduleDirector.new()
	add_child(schedule)
	schedule.setup(null, {})
	var clock := CampaignClock.new()
	var clock_ok: bool = clock.configure_start("mon", 1, 0)
	var facts: Dictionary = schedule.place_activity_facts(
			"bodega", 0.0, 1440.0, clock)
	var visits: Array = facts.get("visits", [])
	var advanced_both: bool = clock_ok and not visits.is_empty()
	for shop_id: String in [PRIMARY_SHOP, SECOND_SHOP]:
		advanced_both = advanced_both and registry.bind_state(shop_id) \
				and registry.advance(1440.0, facts)
	var primary_after: Dictionary = registry.snapshot(PRIMARY_SHOP)
	var second_after: Dictionary = registry.snapshot(SECOND_SHOP)
	var expected_transactions: int = mini(visits.size(), 24)
	_check(advanced_both and primary_after == second_after
			and int(primary_after.transactions) == expected_transactions
			and int(primary_after.stock) == 24 - expected_transactions
			and int(primary_after.condition) == 100
			and primary_after.staffing == record.initial_state.staffing
			and primary_after.hours == record.initial_state.hours,
			"resident timetable facts drive pure two-bucket catch-up")
	var before_repeat: PackedByteArray = var_to_bytes(primary_after)
	var repeated: bool = registry.bind_state(PRIMARY_SHOP) \
			and registry.advance(1440.0, facts)
	_check(repeated and var_to_bytes(registry.snapshot(PRIMARY_SHOP)) \
			== before_repeat, "same-target shop advancement is idempotent")

	var state_before_refusal: PackedByteArray = var_to_bytes(RealityState.data)
	var backward: bool = registry.advance(1200.0, facts)
	var duplicate_source: Dictionary = _extended_bucket_source()
	(duplicate_source.shops as Array).append(
			(duplicate_source.shops as Array)[0].duplicate(true))
	var duplicate_registry: Variant = ShopBucketRegistry.new()
	var duplicate_refused: bool = not duplicate_registry.configure(duplicate_source)
	var missing_lineage: Dictionary = _extended_bucket_source()
	(missing_lineage.shops as Array)[1]["lineage_id"] = ""
	var lineage_registry: Variant = ShopBucketRegistry.new()
	var lineage_refused: bool = not lineage_registry.configure(missing_lineage)
	var malformed: Dictionary = _extended_bucket_source()
	(malformed.shops as Array)[1].erase("stock_units_per_visit")
	var malformed_registry: Variant = ShopBucketRegistry.new()
	var malformed_refused: bool = not malformed_registry.configure(malformed)
	_check(not backward and duplicate_refused and lineage_refused
			and malformed_refused
			and var_to_bytes(RealityState.data) == state_before_refusal,
			"backward, duplicate, missing-lineage, and malformed records refuse atomically")

	var tracker := ObjectiveTracker.new()
	var orders := WorkOrders.new()
	var inventory := MaintenanceInventory.new()
	var shop_service := MaintenanceShopService.new()
	tracker.presentation_enabled = false
	add_child(tracker)
	orders.setup(tracker)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	inventory.setup()
	add_child(inventory)
	shop_service.setup(inventory, orders)
	add_child(shop_service)
	var authority_before: PackedByteArray = var_to_bytes(
			RealityState.data.maintenance_items)
	var capsule_record: Dictionary = shop_service.stock_record(
			"carbon_transmitter_capsule")
	var denied: bool = not shop_service.acquire("carbon_transmitter_capsule",
			PRIMARY_SHOP)
	_check(str(capsule_record.get("shop_id", "")) == "hardware_paint"
			and not str(capsule_record.get("provenance", "")).is_empty()
			and denied and var_to_bytes(RealityState.data.maintenance_items)
			== authority_before and shop_service.inventory == inventory
			and shop_service.work_orders == orders,
			"authored hardware-paint provenance refuses a bodega grant while MaintenanceInventory and WorkOrders remain authoritative")
	shop_service.unmount_all_counters()
	for node: Node in [shop_service, inventory, orders, tracker]:
		remove_child(node)
		node.free()
	remove_child(schedule)
	schedule.free()
	registry.teardown()
	duplicate_registry.teardown()
	lineage_registry.teardown()
	malformed_registry.teardown()
	RealityState.reset_campaign_for_tests()


## Required proofs 8-15: exact semantic save/reconstruction, no coordinates,
## public surface route, collision traversal, public storefront/counter acts,
## work-order continuity, and deterministic public teardown.
func _test_primary_runtime_route_and_save() -> void:
	RealityState.reset_campaign_for_tests()
	RealityState.save_path = SAVE_PATH
	RealityState.persistence_enabled = false
	var module: Node = _cell_scene.instantiate()
	add_child(module)
	await get_tree().physics_frame
	await get_tree().process_frame
	var startup_ok: bool = not bool(module.get("startup_failed"))
	_check(startup_ok and module.is_in_group("production_exterior_module"),
			"bounded production exterior cell starts from authoritative sources")
	if not startup_ok:
		_receipt["route"]["startup_errors"] = module.get("startup_errors")
		await _release_module(module, "primary_startup_failure")
		return

	var player := module.get("player") as PlayerController
	var orders := module.get("work_orders") as WorkOrders
	var inventory := module.get("maintenance_inventory") as MaintenanceInventory
	var shop_service := module.get("shop_service") as MaintenanceShopService
	var resolver: Variant = module.get("spatial_resolver")
	var bucket_registry: Variant = module.get("shop_bucket_registry")
	_check(player != null and orders != null and inventory != null
			and shop_service != null and resolver != null
			and bucket_registry != null
			and module.find_children("*", "PlayerController", true, false).size() == 1
			and module.find_children("WorkOrders", "", true, false).size() == 1
			and module.find_children("MaintenanceInventory", "", true, false).size() == 1,
			"one production player, work-order, inventory, and shop authority is composed")
	var surface: Dictionary = resolver.resolve_surface(PRIMARY_STREET, "pavement")
	var threshold: Dictionary = resolver.resolve_threshold(PRIMARY_THRESHOLD)
	var outbound: Dictionary = module.call("route", OUTBOUND_ROUTE)
	var returning: Dictionary = module.call("route", RETURN_ROUTE)
	_check(not surface.is_empty() and surface.kind == "walkable"
			and not threshold.is_empty()
			and not outbound.is_empty() and not returning.is_empty(),
			"public surfaces, threshold, and both semantic routes resolve")

	var geometry: Dictionary = _read_json(GEOMETRY_PATH)
	var declared: Dictionary = _declared_geometry_counts(geometry,
			resolver.instance_ids())
	var cost: Dictionary = module.call("cost_report")
	_receipt["route"]["cost"] = cost.duplicate(true)
	_receipt["route"]["declared_records"] = declared
	_check(_geometry_cost_is_consumed(cost, declared),
			"generic builder consumes every declared primary geometry record")
	_test_presentation_invariants(module, resolver, outbound, returning,
			threshold, cost)

	var modified: Array[String] = []
	player.world_modified.connect(func(_where: Vector3, what: String):
		modified.append(what))
	var outbound_nodes: Array = outbound.get("nodes", [])
	var return_nodes: Array = returning.get("nodes", [])
	var route_valid: bool = outbound_nodes.size() == 5 \
			and return_nodes.size() == 5
	_check(route_valid, "accepted route has five named nodes in each direction")
	if not route_valid:
		await _release_module(module, "primary_route_invalid")
		return

	var placed_initial: bool = bool(module.call("place_player_at_route_waypoint",
			OUTBOUND_ROUTE, "ORISON_EXIT"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var initial: Vector3 = player.global_position
	_check(placed_initial and initial.distance_to(
			outbound_nodes[0].placement.position) < 0.1,
			"public semantic initial-placement contract places the player at ORISON_EXIT")
	var traversal: Dictionary = {"initial_placement": _vec(initial),
			"teleports_after_initial": 0,
			"legs": [], "distance_m": 0.0}
	var outbound_to_exterior: Array = outbound_nodes.slice(1, 4)
	var reached_exterior: bool = await _walk_named(player, outbound_to_exterior,
			traversal, "outbound")
	var door := module.call("interaction_leaf", STOREFRONT_LEAF) as DoorProp
	var door_hit := false
	if reached_exterior and door != null:
		var door_target := door.global_transform * Vector3(
				door.width * 0.5, minf(1.15, door.height * 0.55), 0.0)
		door_hit = await _public_interact(player, door, door_target)
	await get_tree().create_timer(0.58).timeout
	var door_opened: bool = door_hit and door != null and door.open
	_check(door_opened and modified.has(STOREFRONT_LEAF),
			"PlayerController ray opens the real storefront leaf")
	var reached_interior: bool = door_opened and await _walk_named(player,
			[outbound_nodes[4]], traversal, "threshold_to_interior")
	_check(reached_exterior and reached_interior and not player.noclip
			and player.is_on_floor(),
			"production PlayerController traverses collision-bearing street and threshold")

	var issued: bool = orders.issue_job(JOB_ID, "reported") \
			and orders.acknowledge_job(JOB_ID) \
			and orders.diagnose_job(JOB_ID) \
			and orders.mark_job_awaiting_part(JOB_ID)
	var service_stance: Dictionary = resolver.resolve_placement(
			PRIMARY_SHOP, "service_stance")
	var reached_counter: bool = issued and await _walk_named(player, [{
		"id": "BODEGA_SERVICE_STANCE", "placement": service_stance}],
			traversal, "interior_to_counter")
	var counter := module.call("service_counter", PRIMARY_SHOP) as Area3D
	var inventory_before: PackedByteArray = var_to_bytes(
			RealityState.data.maintenance_items)
	var job_before: Dictionary = orders.job_state(JOB_ID)
	var counter_hit := false
	if reached_counter and counter != null:
		counter_hit = await _public_interact(player, counter,
				counter.global_position + Vector3.UP * 0.12)
	await get_tree().process_frame
	var no_false_part: bool = inventory_before \
			== var_to_bytes(RealityState.data.maintenance_items) \
			and orders.job_state(JOB_ID) == job_before \
			and orders.job_stage(JOB_ID) == "awaiting_part" \
			and shop_service.pending_item(PRIMARY_SHOP).is_empty()
	_check(counter_hit and modified.has("SemanticShopCounter")
			and str(counter.get_meta("semantic_shop_id", "")) == PRIMARY_SHOP
			and no_false_part,
			"public bodega counter transaction refuses an unrelated maintenance part without mutating authorities")

	var semantics: Variant = SemanticState.new()
	var returned_to_interior: bool = await _walk_named(player, [{
		"id": "BODEGA_INTERIOR_RETURN", "placement":
			outbound_nodes[4].placement}], traversal, "counter_to_return_route")
	var returned_to_pavement: bool = returned_to_interior \
			and await _walk_named(player,
			return_nodes.slice(1, 4), traversal, "return_to_pavement")
	var recorded: bool = returned_to_pavement \
			and semantics.record_progress(SEMANTIC_STATE_ID,
					resolver, RETURN_ROUTE, "PAVEMENT_TURN", PRIMARY_THRESHOLD)
	var returned_to_orison: bool = returned_to_pavement \
			and await _walk_named(player, [return_nodes[4]], traversal,
					"pavement_to_orison")
	_check(returned_to_orison and player.global_position.distance_to(
			return_nodes[-1].placement.position) < 0.35 and not player.noclip,
			"same collision-bearing controller follows the semantic return to Orison")
	_receipt["route"]["traversal"] = traversal

	var schedule := ScheduleDirector.new()
	add_child(schedule)
	schedule.setup(null, {})
	var clock := CampaignClock.new()
	clock.configure_start("mon", 1, 0)
	var facts: Dictionary = schedule.place_activity_facts(
			"bodega", 0.0, 1440.0, clock)
	var advanced: bool = bucket_registry.bind_state(PRIMARY_SHOP) \
			and bucket_registry.advance(1440.0, facts)
	var stocked_after_advance: Dictionary = module.call(
			"refresh_shop_presentation")
	var stocked_shop: Dictionary = (stocked_after_advance.get("shops", {}) \
			as Dictionary).get(PRIMARY_SHOP, {})
	var second_day_facts: Dictionary = schedule.place_activity_facts(
			"bodega", 1440.0, 2880.0, clock)
	var depleted: bool = advanced \
			and bucket_registry.advance(2880.0, second_day_facts)
	var depleted_presentation: Dictionary = module.call(
			"refresh_shop_presentation")
	var depleted_shop: Dictionary = (depleted_presentation.get("shops", {}) \
			as Dictionary).get(PRIMARY_SHOP, {})
	_check(advanced and bool(stocked_shop.get(
			"stock_visuals_visible", false)) \
			and int(stocked_shop.get("stock", -1)) > 0 \
			and depleted and int(depleted_shop.get("stock", -1)) == 0 \
			and not bool(depleted_shop.get("stock_visuals_visible", true)) \
			and int(depleted_shop.get("stock_visuals", 0)) == 18,
			"public timetable advancement hides only depleted stock-role visuals")
	var saved_bucket: Dictionary = bucket_registry.snapshot(PRIMARY_SHOP)
	var saved_semantics: Dictionary = semantics.snapshot(SEMANTIC_STATE_ID)
	var saved_job: Dictionary = orders.job_state(JOB_ID)
	var canonical_saved_bucket: Dictionary = JSON.parse_string(
			JSON.stringify(saved_bucket))
	var canonical_saved_semantics: Dictionary = JSON.parse_string(
			JSON.stringify(saved_semantics))
	var canonical_saved_job: Dictionary = JSON.parse_string(
			JSON.stringify(saved_job))
	var saved_subset: Dictionary = {"shop_buckets": RealityState.data.shop_buckets,
			"exterior_semantics": RealityState.data.exterior_semantics,
			"maintenance_jobs": RealityState.data.maintenance_jobs,
			"maintenance_items": RealityState.data.maintenance_items}
	var subset_text: String = JSON.stringify(saved_subset)
	# JSON's number model is floating-point, so an integral runtime fact such
	# as 1440 reloads as 1440.0. Compare against the exact value set that the
	# actual JSON boundary writes, not against Variant's pre-serialization type
	# tags. The explicit bucket/cursor/job assertions below remain independent.
	var canonical_saved_value: Variant = JSON.parse_string(subset_text)
	var canonical_saved_subset: Dictionary = canonical_saved_value \
			if canonical_saved_value is Dictionary else {}
	var saved_exterior := {"shop_buckets": RealityState.data.shop_buckets,
			"exterior_semantics": RealityState.data.exterior_semantics}
	var no_coordinates: bool = not _contains_world_coordinate_key(saved_exterior)
	RealityState.persistence_enabled = true
	var saved_to_disk: bool = depleted and recorded and no_coordinates \
			and RealityState.save_game()
	var save_hash: String = FileAccess.get_sha256(SAVE_PATH) \
			if saved_to_disk else ""
	_check(saved_to_disk and not save_hash.is_empty() and no_coordinates,
			"save contains semantic exterior identities and no raw world coordinates")

	var primary_weak: WeakRef = weakref(module)
	var player_weak: WeakRef = weakref(player)
	var first_teardown: Dictionary = await _release_module(
			module, "primary_before_reload")
	module = null
	player = null
	orders = null
	inventory = null
	shop_service = null
	resolver = null
	bucket_registry = null
	semantics = null
	remove_child(schedule)
	schedule.free()
	schedule = null
	await _settle_teardown()
	_check(primary_weak.get_ref() == null and player_weak.get_ref() == null,
			"primary module and PlayerController release after public teardown")
	_check(bool(first_teardown.get("ok", false))
			and bool(first_teardown.get("repeat_already_torn_down", false))
			and int(first_teardown.get("retained_strong_references", -1)) == 0,
			"public teardown is deterministic, idempotent, and clears strong references")

	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	var loaded_subset: Dictionary = {"shop_buckets": RealityState.data.shop_buckets,
			"exterior_semantics": RealityState.data.exterior_semantics,
			"maintenance_jobs": RealityState.data.maintenance_jobs,
			"maintenance_items": RealityState.data.maintenance_items}
	# The ruled exterior root remains at identity. Injecting the production
	# controller under a transformed external parent proves the public seam
	# consumes the reconstructed world placement rather than assigning it as
	# a parent-relative coordinate.
	var external_player_parent := Node3D.new()
	external_player_parent.position = Vector3(2.75, 0.0, -1.5)
	external_player_parent.rotation.y = deg_to_rad(13.0)
	var reconstructed_player := PlayerController.new()
	external_player_parent.add_child(reconstructed_player)
	var reconstructed: Node3D = _cell_scene.instantiate() as Node3D
	var player_injected: bool = bool(reconstructed.call(
			"configure_dependencies", {"player":reconstructed_player}))
	add_child(external_player_parent)
	add_child(reconstructed)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(player_injected and not bool(reconstructed.get("startup_failed")),
			"reconstruction composes an externally parented production PlayerController")
	var reconstructed_resolver: Variant = reconstructed.get("spatial_resolver")
	var reconstructed_bucket: Variant = reconstructed.get("shop_bucket_registry")
	var reconstructed_presentation: Dictionary = reconstructed.call(
			"presentation_state")
	var reconstructed_shop: Dictionary = ((reconstructed_presentation.get(
			"bucket_presentation", {}) as Dictionary).get("shops", {}) \
			as Dictionary).get(PRIMARY_SHOP, {})
	_check(int(reconstructed_shop.get("stock", -1)) == 0 \
			and int(reconstructed_shop.get("stock_visuals", 0)) == 18 \
			and not bool(reconstructed_shop.get(
					"stock_visuals_visible", true)),
			"reconstruction restores the bucket-driven depleted fixture state")
	var reconstructed_semantics: Variant = SemanticState.new()
	var cursor: Dictionary = reconstructed_semantics.reconstruct(
			SEMANTIC_STATE_ID, reconstructed_resolver)
	var resolved_cursor: Dictionary = cursor.get("cursor", {})
	var cursor_placement: Dictionary = resolved_cursor.get("placement", {})
	var placement_consumed: bool = not cursor_placement.is_empty() \
			and reconstructed_player != null \
			and bool(reconstructed.call("place_player_at_route_waypoint",
					str(cursor.get("route_id", "")),
					str(cursor.get("waypoint_id", ""))))
	# Give CharacterBody3D enough deterministic physics ticks to reacquire the
	# named pavement after the legitimate reconstruction placement.
	for _frame: int in range(8):
		await get_tree().physics_frame
	var expected_reconstructed_position := cursor_placement.get(
			"position", Vector3.INF) as Vector3
	placement_consumed = placement_consumed \
			and reconstructed_player.global_position.distance_to(
					expected_reconstructed_position) < 0.1 \
			and reconstructed_player.is_on_floor()
	var subset_exact: bool = loaded_subset == canonical_saved_subset
	var bucket_exact: bool = reconstructed_bucket.snapshot(PRIMARY_SHOP) \
			== canonical_saved_bucket
	var semantic_exact: bool = reconstructed_semantics.snapshot(
			SEMANTIC_STATE_ID) == canonical_saved_semantics
	var job_exact: bool = (reconstructed.get("work_orders") as WorkOrders).job_state(
			JOB_ID) == canonical_saved_job
	var cursor_exact: bool = str(cursor.get("route_id", "")) == RETURN_ROUTE \
			and str(cursor.get("waypoint_id", "")) == "PAVEMENT_TURN" \
			and str(cursor.get("threshold_id", "")) == PRIMARY_THRESHOLD
	var reload_exact: bool = subset_exact and bucket_exact \
			and semantic_exact and job_exact and cursor_exact \
			and placement_consumed
	_check(reload_exact,
			"save, destruction, reload, and source reconstruction preserve exact semantic facts")
	_receipt["save_reconstruction"] = {
		"save_sha256": save_hash,
		"saved_subset_sha256": JSON.stringify(
				canonical_saved_subset).sha256_text(),
		"loaded_subset_sha256": JSON.stringify(loaded_subset).sha256_text(),
		"bucket": canonical_saved_bucket,
		"semantic_cursor": canonical_saved_semantics,
		"job_stage": str(saved_job.get("stage", "")),
		"no_world_coordinates": no_coordinates,
		"reconstruction_world_position": _vec(
				reconstructed_player.global_position),
		"reconstruction_expected_world_position": _vec(
				expected_reconstructed_position),
		"exact": reload_exact,
		"exact_comparisons": {"serialized_subset":subset_exact,
				"bucket":bucket_exact, "semantic_cursor":semantic_exact,
				"work_order":job_exact, "reconstructed_route":cursor_exact,
				"public_placement_consumed":placement_consumed,
				"depleted_presentation":not bool(reconstructed_shop.get(
						"stock_visuals_visible", true))},
		"first_teardown": first_teardown,
	}
	var reconstructed_weak: WeakRef = weakref(reconstructed)
	var reconstructed_player_weak: WeakRef = weakref(reconstructed_player)
	var second_teardown: Dictionary = await _release_module(
			reconstructed, "reconstructed_after_load")
	reconstructed = null
	reconstructed_resolver = null
	reconstructed_bucket = null
	reconstructed_semantics = null
	remove_child(external_player_parent)
	external_player_parent.free()
	external_player_parent = null
	reconstructed_player = null
	await _settle_teardown()
	_check(reconstructed_weak.get_ref() == null \
			and reconstructed_player_weak.get_ref() == null,
			"reconstructed module and injected controller release through public teardown")
	_receipt["save_reconstruction"]["second_teardown"] = second_teardown
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()


func _test_presentation_invariants(module: Node, resolver: Variant,
		outbound: Dictionary, returning: Dictionary, threshold: Dictionary,
		cost: Dictionary) -> void:
	var cursor_before: Dictionary = resolver.reconstruct_route(
			RETURN_ROUTE, "PAVEMENT_TURN")
	var enabled: Dictionary = module.call("set_route_guides_visible", true)
	var enabled_state: Dictionary = module.call("presentation_state")
	var presentation: Dictionary = module.call("refresh_shop_presentation")
	var bucket: Dictionary = module.call("shop_snapshot", PRIMARY_SHOP)
	var shop_presentation: Dictionary = (presentation.get("shops", {}) \
			as Dictionary).get(PRIMARY_SHOP, {})
	_check(bool(enabled.get("ok", false))
			and bool(enabled.get("guide_visuals_visible", false))
			and int(enabled.get("affected_visuals", 0)) > 0,
			"explicit source-authored route-guide visuals can be enabled")
	_check(bool(presentation.get("ok", false))
			and bool(shop_presentation.get("stock_visuals_visible", false))
			and int(shop_presentation.get("stock_visuals", 0)) > 0
			and int(shop_presentation.get("stock", -1))
					== int(bucket.get("stock", -2)),
			"stocked fixture presentation reads the existing durable bodega bucket")

	var hidden: Dictionary = module.call("set_route_guides_visible", false)
	var hidden_state: Dictionary = module.call("presentation_state")
	var cost_after: Dictionary = module.call("cost_report")
	var outbound_after: Dictionary = module.call("route", OUTBOUND_ROUTE)
	var returning_after: Dictionary = module.call("route", RETURN_ROUTE)
	var threshold_after: Dictionary = resolver.resolve_threshold(
			PRIMARY_THRESHOLD)
	var cursor_after: Dictionary = resolver.reconstruct_route(
			RETURN_ROUTE, "PAVEMENT_TURN")
	var hidden_invariants := bool(hidden.get("ok", false)) \
			and not bool(hidden.get("guide_visuals_visible", true)) \
			and not bool(hidden_state.get("guide_visuals_visible", true)) \
			and int(cost_after.get("collision_shapes", -1)) \
					== int(cost.get("collision_shapes", -2)) \
			and int(cost_after.get("collision_objects", -1)) \
					== int(cost.get("collision_objects", -2)) \
			and outbound_after == outbound and returning_after == returning \
			and threshold_after == threshold and cursor_after == cursor_before
	_check(hidden_invariants,
			"hidden guides preserve collision, threshold identity, routes, and semantic reconstruction")
	_receipt["presentation"] = {
		"source_roles": ["environment", "route_guide", "stock"],
		"enabled": enabled,
		"enabled_state": enabled_state,
		"hidden": hidden,
		"hidden_state": hidden_state,
		"bucket_presentation": presentation,
		"collision_shapes_before": cost.get("collision_shapes", -1),
		"collision_shapes_hidden": cost_after.get("collision_shapes", -1),
		"collision_objects_before": cost.get("collision_objects", -1),
		"collision_objects_hidden": cost_after.get("collision_objects", -1),
		"threshold_id": str(threshold_after.get("id", "")),
		"reconstruction_route_id": str(cursor_after.get("route_id", "")),
		"reconstruction_waypoint_id": str(cursor_after.get("waypoint_id", "")),
		"human_packet_required_state": "hidden",
	}


## Required proof 11 and piece-two contract: the same source-generic builder
## receives a second root at nonzero yaw plus a second shop, threshold, route,
## and bucket. Nothing here is written to production JSON.
func _test_rotated_piece_two() -> void:
	RealityState.reset_campaign_for_tests()
	var spatial_source: Dictionary = _extended_spatial_source()
	var resolver: Variant = SpatialResolver.new()
	var resolver_ok: bool = resolver.configure(spatial_source)
	var registry: Variant = ShopBucketRegistry.new()
	var registry_ok: bool = registry.configure(_extended_bucket_source())
	var module: Node = _cell_scene.instantiate()
	var configured: bool = resolver_ok and registry_ok and bool(module.call(
			"configure_dependencies", {
				"spatial_resolver": resolver,
				"shop_bucket_registry": registry,
			}))
	add_child(module)
	await get_tree().physics_frame
	await get_tree().process_frame
	var built: bool = configured and not bool(module.get("startup_failed"))
	_check(built and resolver.instance_ids().has(SECOND_STREET)
			and resolver.instance_ids().has(SECOND_SHOP)
			and registry.source_ids().has(SECOND_SHOP),
			"disposable second street and shop construct through the same production paths")
	if not built:
		_receipt["piece_two"]["startup_errors"] = module.get("startup_errors")
		await _release_module(module, "piece_two_startup_failure")
		return

	var root_transform: Transform3D = resolver.instance_world_transform(
			SECOND_STREET)
	var shop_transform: Transform3D = resolver.instance_world_transform(
			SECOND_SHOP)
	var owner_surface: Dictionary = resolver.resolve_surface(
			SECOND_STREET, "pavement")
	var shop_record: Dictionary = resolver.instance_record(SECOND_SHOP)
	var offset: Vector3 = _array_vec3(shop_record.offset_uvn_m)
	var expected_origin: Vector3 = owner_surface.point \
			+ (owner_surface.u_axis as Vector3) * offset.x \
			+ (owner_surface.v_axis as Vector3) * offset.y \
			+ (owner_surface.normal as Vector3) * offset.z
	var yaw_measured: float = rad_to_deg(Vector3.RIGHT.signed_angle_to(
			root_transform.basis.x.normalized(), Vector3.UP))
	var rotated_attached: bool = absf(absf(yaw_measured) \
			- SECOND_YAW_DEGREES) < 0.01 \
			and shop_transform.origin.distance_to(expected_origin) < 0.0001 \
			and shop_transform.basis.x.normalized().dot(
				root_transform.basis.x.normalized()) > 0.9999 \
			and not resolver.resolve_threshold(SECOND_THRESHOLD).is_empty() \
			and not module.call("route", SECOND_OUTBOUND).is_empty() \
			and not module.call("route", SECOND_RETURN).is_empty()
	_check(rotated_attached,
			"nonzero-yaw shop remains attached to its named owning surface and routes")

	var instances: Node = module.get_node_or_null("ExteriorInstances")
	var first_cost: Dictionary = _combined_instance_cost(instances,
			[PRIMARY_STREET, PRIMARY_SHOP])
	var second_cost: Dictionary = _combined_instance_cost(instances,
			[SECOND_STREET, SECOND_SHOP])
	var comparable: bool = not first_cost.is_empty() and first_cost == second_cost
	_check(comparable,
			"rotated second instance has identical node, mesh, and collision cost")
	_check(module.call("service_counter", PRIMARY_SHOP) != null
			and module.call("service_counter", SECOND_SHOP) != null
			and not module.call("shop_snapshot", PRIMARY_SHOP).is_empty()
			and not module.call("shop_snapshot", SECOND_SHOP).is_empty(),
			"both shops expose one public counter and one durable simulation bucket")
	var production_text: String = FileAccess.get_file_as_string(SPATIAL_PATH)
	_check(not production_text.contains(SECOND_STREET)
			and not production_text.contains(SECOND_SHOP),
			"piece-two fixture remains absent from production and human evidence source")
	_receipt["piece_two"] = {
		"root_yaw_degrees": yaw_measured,
		"shop_origin": _vec(shop_transform.origin),
		"expected_attached_origin": _vec(expected_origin),
		"attachment_error_m": shop_transform.origin.distance_to(expected_origin),
		"first_instance_cost": first_cost,
		"second_instance_cost": second_cost,
		"costs_identical": comparable,
		"production_source_contains_fixture": production_text.contains(SECOND_SHOP),
	}
	var module_weak: WeakRef = weakref(module)
	var teardown: Dictionary = await _release_module(module, "piece_two")
	module = null
	resolver.teardown()
	registry.teardown()
	resolver = null
	registry = null
	await _settle_teardown()
	_check(module_weak.get_ref() == null,
			"rotated expansion module releases without retained scene owners")
	_receipt["piece_two"]["teardown"] = teardown
	RealityState.reset_campaign_for_tests()


func _test_protected_boundary() -> void:
	var all_match := true
	var comparison := {}
	for path: String in PROTECTED:
		var actual := FileAccess.get_sha256(path)
		var expected := str(PROTECTED[path])
		comparison[path] = {"before": expected, "after": actual,
				"match": actual == expected}
		all_match = all_match and actual == expected
	_receipt["protected"] = comparison
	_check(all_match, "both layouts, selector, and every floor GLTF/BIN hash are unchanged")
	_check(Selector.DEFAULT_ID == "v1" and Selector.selected_id() == "v1",
			"committed and absent-session production selector remain v1")


func _walk_named(player: PlayerController, raw_nodes: Array,
		receipt: Dictionary, phase: String) -> bool:
	for raw: Variant in raw_nodes:
		if raw is not Dictionary:
			return false
		var node: Dictionary = raw
		var placement: Dictionary = node.get("placement", {})
		if placement.is_empty():
			return false
		var target: Vector3 = placement.get("position", Vector3.INF)
		if not target.is_finite():
			return false
		var start := player.global_position
		var frames := 0
		var max_frames := maxi(240, int(ceil(start.distance_to(target)
				/ PlayerController.WALK * 60.0)) + 240)
		while Vector2(player.global_position.x - target.x,
				player.global_position.z - target.z).length() > 0.14:
			var delta := target - player.global_position
			delta.y = 0.0
			player.autopilot = delta.normalized()
			await get_tree().physics_frame
			frames += 1
			if frames > max_frames or player.noclip:
				player.autopilot = Vector3.ZERO
				(receipt.legs as Array).append({"phase":phase,
						"id":str(node.get("id", "")), "ok":false,
						"frames":frames, "from":_vec(start),
						"target":_vec(target), "at":_vec(player.global_position)})
				return false
		player.autopilot = Vector3.ZERO
		await get_tree().physics_frame
		var planar := Vector2(player.global_position.x - target.x,
				player.global_position.z - target.z).length()
		var leg_distance := Vector2(start.x - player.global_position.x,
				start.z - player.global_position.z).length()
		receipt.distance_m = float(receipt.distance_m) + leg_distance
		(receipt.legs as Array).append({"phase":phase,
				"id":str(node.get("id", "")), "ok":planar <= 0.22,
				"frames":frames, "distance_m":leg_distance,
				"target":_vec(target), "at":_vec(player.global_position),
				"on_floor":player.is_on_floor(), "noclip":player.noclip})
		if planar > 0.22 or not player.is_on_floor():
			return false
	return true


func _public_interact(player: PlayerController, expected_owner: Node,
		target: Vector3) -> bool:
	if player == null or expected_owner == null:
		return false
	player.camera.look_at(target, Vector3.UP)
	await get_tree().physics_frame
	var from := player.camera.global_position
	var to := from + player.camera.global_transform.basis * Vector3(0, 0, -2.1)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var owner: Node = hit.collider
	var belongs := false
	while owner != null:
		if owner == expected_owner:
			belongs = true
			break
		owner = owner.get_parent()
	if not belongs:
		return false
	player.use_primary_interaction()
	await get_tree().process_frame
	return true


func _release_module(module: Node, label: String) -> Dictionary:
	if module == null:
		return {"label":label, "public_api":false}
	var report: Variant = module.call("shutdown_for_tests") \
			if module.has_method("shutdown_for_tests") else {}
	var repeated: Variant = module.call("shutdown_for_tests") \
			if module.has_method("shutdown_for_tests") else {}
	if module.get_parent() == self:
		remove_child(module)
	module.free()
	await _settle_teardown()
	var result: Dictionary = report.duplicate(true) if report is Dictionary else {}
	result["label"] = label
	result["public_api"] = report is Dictionary
	result["repeat_already_torn_down"] = repeated is Dictionary \
			and bool((repeated as Dictionary).get("already_torn_down", false))
	return result


func _settle_teardown() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _extended_bucket_source() -> Dictionary:
	var source := _read_json(BUCKET_PATH)
	var second: Dictionary = (source.shops as Array)[0].duplicate(true)
	second.id = SECOND_SHOP
	second.initial_state = second.initial_state.duplicate(true)
	(source.shops as Array).append(second)
	return source


func _extended_spatial_source() -> Dictionary:
	var source := _read_json(SPATIAL_PATH)
	(source.instances as Array).append({
		"id": SECOND_STREET,
		"template_id": "TEMPLATE_STREET_SEGMENT_V1",
		"region_id": "REGION_STREET",
		"lineage_id": "street",
		"owner_instance_id": "",
		"owner_surface_id": "",
		"offset_uvn_m": [34.0, 22.0, 0.0],
		"local_yaw_degrees": SECOND_YAW_DEGREES,
		"root_frame_identity": "ORISON_FRONT_DOOR_THRESHOLD",
		"semantic_identity": "ORISON_SIDE_PAVEMENT_ROTATED_02",
		"display_name": "DISPOSABLE ROTATED PAVEMENT",
	})
	(source.instances as Array).append({
		"id": SECOND_SHOP,
		"template_id": "TEMPLATE_BODEGA_CELL_V1",
		"region_id": "REGION_SHOPS",
		"lineage_id": "shopfronts",
		"owner_instance_id": SECOND_STREET,
		"owner_surface_id": "pavement",
		"offset_uvn_m": [9.155, -0.875, 0.0],
		"local_yaw_degrees": 0.0,
		"root_frame_identity": "",
		"semantic_identity": SECOND_SHOP,
		"display_name": "DISPOSABLE ROTATED BODEGA",
	})
	(source.thresholds as Array).append({
		"id": SECOND_THRESHOLD,
		"shop_id": SECOND_SHOP,
		"region_id": "REGION_SHOPS",
		"lineage_id": "shopfronts",
		"owner_instance_id": SECOND_SHOP,
		"owner_surface_id": "threshold",
		"exterior_placement_id": "exterior_stance",
		"interior_placement_id": "interior_arrival",
		"interactive_leaf_id": "%s_STOREFRONT_LEAF" % SECOND_SHOP,
	})
	(source.routes as Array).append(_second_route(SECOND_OUTBOUND,
			"toward_shop", false))
	(source.routes as Array).append(_second_route(SECOND_RETURN,
			"toward_orison", true))
	return source


func _second_route(route_id: String, direction: String,
		reverse: bool) -> Dictionary:
	var nodes := [
		{"id":"ORISON_02_EXIT", "owner_instance_id":SECOND_STREET,
				"placement_id":"orison_exit"},
		{"id":"PAVEMENT_02_TURN", "owner_instance_id":SECOND_STREET,
				"placement_id":"pavement_out"},
		{"id":"BODEGA_02_ALIGNMENT", "owner_instance_id":SECOND_SHOP,
				"placement_id":"street_alignment"},
		{"id":"BODEGA_02_EXTERIOR", "owner_instance_id":SECOND_SHOP,
				"placement_id":"exterior_stance"},
		{"id":"BODEGA_02_INTERIOR", "owner_instance_id":SECOND_SHOP,
				"placement_id":"interior_arrival"},
	]
	if reverse:
		nodes.reverse()
	return {"id":route_id, "direction":direction, "lineage_id":"street",
			"region_ids":["REGION_STREET", "REGION_SHOPS"] \
				if not reverse else ["REGION_SHOPS", "REGION_STREET"],
			"threshold_ids":[SECOND_THRESHOLD], "nodes":nodes}


func _combined_instance_cost(instances: Node, ids: Array[String]) -> Dictionary:
	if instances == null:
		return {}
	var total := {"nodes":0, "meshes":0, "collision_shapes":0,
			"collision_objects":0, "doors":0, "lights":0, "labels":0}
	for id: String in ids:
		var root := instances.get_node_or_null(NodePath(id))
		if root == null:
			return {}
		var census := _subtree_cost(root)
		for key: String in total:
			total[key] = int(total[key]) + int(census[key])
	return total


func _subtree_cost(root: Node) -> Dictionary:
	var result := {"nodes":1, "meshes":0, "collision_shapes":0,
			"collision_objects":0, "doors":0, "lights":0, "labels":0}
	if root is MeshInstance3D:
		result.meshes += 1
	if root is CollisionShape3D:
		result.collision_shapes += 1
	if root is CollisionObject3D:
		result.collision_objects += 1
	if root is DoorProp:
		result.doors += 1
	if root is Light3D:
		result.lights += 1
	if root is Label3D:
		result.labels += 1
	for child: Node in root.get_children():
		var nested := _subtree_cost(child)
		for key: String in result:
			result[key] = int(result[key]) + int(nested[key])
	return result


func _declared_geometry_counts(source: Dictionary,
		instance_ids: Array[String]) -> Dictionary:
	var templates := {}
	for value: Variant in source.get("templates", []):
		if value is Dictionary:
			templates[str(value.get("id", ""))] = value
	var spatial := _read_json(SPATIAL_PATH)
	var instance_templates := {}
	for value: Variant in spatial.get("instances", []):
		if value is Dictionary:
			instance_templates[str(value.get("id", ""))] = str(
					value.get("template_id", ""))
	var result := {"instances":instance_ids.size(), "boxes":0,
			"visible_boxes":0, "collision_boxes":0, "labels":0,
			"lights":0, "doors":0, "functional_props":0,
			"service_counters":0}
	for instance_id: String in instance_ids:
		var template: Dictionary = templates.get(
				instance_templates.get(instance_id, ""), {})
		for box: Variant in template.get("boxes", []):
			result.boxes += 1
			if bool((box as Dictionary).get("visible", false)):
				result.visible_boxes += 1
			if bool((box as Dictionary).get("collision", false)):
				result.collision_boxes += 1
		for key: String in ["labels", "lights", "doors", "functional_props",
				"service_counters"]:
			result[key] = int(result[key]) + (template.get(key, []) as Array).size()
	return result


func _geometry_cost_is_consumed(cost: Dictionary,
		declared: Dictionary) -> bool:
	if cost.is_empty():
		return false
	return int(cost.get("instances", -1)) == int(declared.instances) \
			and int(cost.get("meshes", -1)) >= int(declared.visible_boxes) \
			and int(cost.get("collision_shapes", -1)) \
				>= int(declared.collision_boxes) \
			and int(cost.get("doors", -1)) == int(declared.doors) \
			and int(cost.get("counters", -1)) == int(declared.service_counters) \
			and int(cost.get("lights", -1)) >= int(declared.lights) \
			and int(cost.get("labels", -1)) >= int(declared.labels)


func _contains_world_coordinate_key(value: Variant) -> bool:
	if value is Dictionary:
		for raw_key: Variant in value:
			var key := str(raw_key).to_lower()
			if key in ["x", "y", "z", "position", "global_position",
					"world_position", "transform", "basis", "origin",
					"coordinates", "coordinate"]:
				return true
			if _contains_world_coordinate_key((value as Dictionary)[raw_key]):
				return true
	elif value is Array:
		for child: Variant in value:
			if _contains_world_coordinate_key(child):
				return true
	return false


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _array_vec3(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.INF


func _vec(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _object_counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(
				Performance.OBJECT_RESOURCE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(
				Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _check(ok: bool, label: String) -> void:
	(_receipt.checks as Array).append({"label":label, "pass":ok})
	if ok:
		passes += 1
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)


func _write_receipt() -> void:
	_receipt["result"] = "PASS" if failures == 0 else "FAIL"
	_receipt["passes"] = passes
	_receipt["failures"] = failures
	var path := OS.get_environment(RECEIPT_ENV)
	if path.is_empty():
		path = "user://tests/m11a_first_exterior_cell_objective_receipt.json"
	var absolute := ProjectSettings.globalize_path(path) \
			if path.begins_with("res://") or path.begins_with("user://") else path
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("M11A objective receipt could not be written: " + absolute)
		return
	file.store_string(JSON.stringify(_receipt, "\t"))
	print("[M11A RECEIPT] " + absolute)


func _finish() -> void:
	RealityState.save_path = _old_save_path
	RealityState.persistence_enabled = _old_persistence
	RealityState.reset_campaign_for_tests()
	Selector.reset_for_tests()
	_write_receipt()
	print("ORISON V2 M11A FIRST EXTERIOR CELL: %s checks=%d" % [
			"PASS" if failures == 0 else "FAIL (%d)" % failures,
			passes + failures])
	get_tree().quit(failures)
