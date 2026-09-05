extends Node
const Registry := preload("res://scripts/building/orison_v2_shop_bucket_registry.gd")
const Simulation := preload("res://scripts/building/orison_v2_shop_simulation.gd")
var failures: Array[String] = []
var checks := 0
var refreshes := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("SHOP SIMULATION: " + label)

func _refresh() -> Dictionary:
	refreshes += 1
	return {"ok": true}

func _run() -> void:
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	_check(clock.configure_date(1928, 11, 10, 0), "authored test epoch")
	var schedules := ScheduleDirector.new()
	add_child(schedules)
	schedules.setup(null, {})
	# Controlled resident timetable, resolved by the production authority.
	schedules.data = {"residents": {
		"visitor_a": {"blocks": [{"start_min": 10, "end_min": 20, "place": "bodega", "activity": "errand"}]},
		"visitor_b": {"blocks": [{"start_min": 10, "end_min": 20, "place": "bodega", "activity": "errand"}]}}}
	var registry := Registry.new()
	_check(registry.load_source() and registry.initialize_missing_state(), "source-backed buckets initialized")
	var simulation := Simulation.new()
	add_child(simulation)
	_check(simulation.setup(clock, schedules, registry, Callable(self, "_refresh")), "runtime consumer binds")
	clock.advance_to(9.0)
	_check(simulation.advance_current(), "pre-visit interval advances")
	_check(int(registry.snapshot("SHOP_BODEGA").stock) == 24, "elapsed time alone does not consume stock")
	clock.advance_to(10.0)
	_check(simulation.advance_current(), "visit boundary advances")
	var visited := registry.snapshot("SHOP_BODEGA")
	_check(int(visited.stock) == 22 and int(visited.transactions) == 2, "two authored visits consume exactly two units")
	var refresh_count := refreshes
	_check(simulation.advance_current() and registry.snapshot("SHOP_BODEGA") == visited
			and refreshes == refresh_count, "same interval is a presentation and state no-op")
	var packet := schedules.place_activity_facts("bodega", 10.0, 20.0, clock)
	_check(not registry.advance_batch({"SHOP_BODEGA": packet, "UNKNOWN_SHOP": packet}), "unknown sibling is refused")
	_check(registry.snapshot("SHOP_BODEGA") == visited, "batch refusal preserves valid sibling bytes")
	simulation.shutdown()
	simulation.free()
	var reconstructed := Simulation.new()
	add_child(reconstructed)
	_check(reconstructed.setup(clock, schedules, registry, Callable(self, "_refresh")), "simulation reconstructs from saved cursor")
	_check(registry.snapshot("SHOP_BODEGA") == visited, "reconstruction does not replay visits")
	clock.advance_to(3000.0)
	_check(reconstructed.advance_current(), "long catch-up first slice")
	_check(float(registry.snapshot("SHOP_BODEGA").last_advanced_minute) == 1450.0, "catch-up bounded to one day")
	_check(reconstructed.advance_current(), "long catch-up second slice")
	_check(float(registry.snapshot("SHOP_BODEGA").last_advanced_minute) == 2890.0, "next slice resumes its durable boundary")
	_check(reconstructed.advance_current(), "long catch-up final slice")
	_check(float(registry.snapshot("SHOP_BODEGA").last_advanced_minute) == 3000.0, "catch-up reaches campaign time")
	_check(int(registry.snapshot("SHOP_BODEGA").transactions) == 6, "daily visits neither skipped nor repeated")
	reconstructed.shutdown()
	reconstructed.free()
	schedules.free()
	registry.teardown()
	print("SHOP SIMULATION: %d checks; %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
