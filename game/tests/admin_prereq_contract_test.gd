extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_test_clock()
	_test_frames()
	_test_lineages()
	_test_dream_revision()
	if failures == 0:
		print("ADMIN PREREQ CONTRACT: PASS %d/%d" % [checks, checks])
		get_tree().quit(0)
	else:
		print("ADMIN PREREQ CONTRACT: FAIL %d/%d" % [failures, checks])
		get_tree().quit(1)


func _test_clock() -> void:
	var clock := CampaignClock.new()
	_check("clock accepts an explicit captured epoch",
			clock.configure_start("fri", 100, 23 * 60 + 59))
	clock.advance_to(2.0)
	var info := clock.day_info()
	_check("simulation crosses midnight independently of host date",
			str(info.day) == "sat" and int(info.doy) == 101
			and is_equal_approx(float(info.minute_of_day), 1.0))
	var reconstructed := CampaignClock.new()
	_check("campaign epoch and elapsed time reconstruct from durable state",
			str(reconstructed.day_info().day) == "sat"
			and not reconstructed.advance_to(1.0))


func _test_frames() -> void:
	var frame := OrisonV2FrameContract.new()
	_check("shared coordinate and namespace frame validates",
			frame.load_path(OrisonV2FrameContract.PATH))
	_check("legacy hero-shop aliases canonicalize to the ruled bodega id",
			frame.shop_id("BODEGA") == "SHOP_BODEGA")
	_check("v2 exterior outputs are isolated from v1 authorities",
			frame.exterior_home().begins_with("res://data/orison_v2/"))


func _test_lineages() -> void:
	var registry := CorruptionLineageRegistry.new()
	_check("element lineage registry refuses no ordinary owners", registry.load_registry())
	_check("street era jurisdiction is addressable without a resident wound",
			not registry.era_influence("street").is_empty()
			and registry.resident_wound("street").is_empty())
	_check("resident wound remains an independent column",
			registry.resident_wound("b1_boiler") == "lena_radiator_round_2b")


func _test_dream_revision() -> void:
	RealityState.data.dream = {"phase": "armed", "active": false,
			"case_id": "case", "profile_id": "profile", "window": {},
			"seed_hex": "f123456789abcdef", "maze_revision": 1,
			"night_index": -1, "spawn_anchor": -1, "outcome": ""}
	var director := DreamDirector.new()
	var loop := CoreLoopDirector.new()
	add_child(director)
	add_child(loop)
	director.setup(loop)
	_check("compatible saved dream revision reconstructs", director.phase() == "armed")
	RealityState.data.dream.maze_revision = 999
	director._reconcile_saved_revision()
	_check("unsupported future dream revision cancels before world swap",
			director.phase() == "awake" and not bool(director.dream_state().active))
	director.free()
	loop.free()


func _check(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("  PASS: " + label)
	else:
		failures += 1
		push_error("  FAIL: " + label)
