extends Node
## Focused teardown fault boundary, not player traversal evidence.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var failures: Array[String] = []
var checks := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	print("LOAD TEARDOWN: ", label, " = ", ok)
	if not ok: failures.append(label)

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 1200)
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().process_frame
	_check(not world.startup_failed, "production world starts")
	var residency: Node = world.passage_region.residency
	residency.set_process(false)
	residency.set_physics_process(false)
	if residency.state == "RESIDENT":
		world.passage_region.suspend_geometry()
		residency.state = "DORMANT"
	await get_tree().process_frame
	residency._begin_load()
	_check(residency.state == "LOADING" and residency.snapshot().pending_requests > 0,
			"requests issued but not consumed")
	var staged: WeakRef = weakref(residency._staging)
	var retained_world: WeakRef = weakref(world)
	var started := Time.get_ticks_usec()
	world.shutdown_for_tests()
	var elapsed := float(Time.get_ticks_usec()-started)/1000.0
	_check(residency.snapshot().pending_requests == 0 and staged.get_ref() == null,
			"shutdown drains requests and frees off-tree staging")
	_check(residency._height_resources.is_empty() and residency._material_statistics.is_empty(),
			"shutdown releases material dependency references")
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().process_frame
	_check(retained_world.get_ref() == null, "world released after repeated shutdown")
	# The audio mix thread retires stopped decoders after scene destruction,
	# as in the connected-world reconstruction fixture.
	await get_tree().create_timer(0.25).timeout
	print("PASSAGE LOAD TEARDOWN: %d checks; %d failures; drain_ms=%.3f" % [checks, failures.size(), elapsed])
	get_tree().quit(0 if failures.is_empty() else 1)
