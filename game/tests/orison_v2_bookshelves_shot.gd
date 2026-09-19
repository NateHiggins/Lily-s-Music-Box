extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
var shots = Harness.new()
func _ready() -> void:call_deferred("_run")
func _run() -> void:
	if not shots.setup(self,"V2 BOOKSHELVES",8):get_tree().quit(2);return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bookshelves.json"))
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(2);return
	var player := world.player
	player.set_physics_process(false);player.set_process_unhandled_input(false)
	player.camera.make_current();player.set_lamp_enabled(true)
	var air: Node=world.get_node("LampAtmosphere")
	var ok := true
	for row: Dictionary in source.shelves:
		var shelf: Node3D = world.adapter.resolve(row.id)
		var stance: Node3D = world.adapter.resolve(row.id+"_STANCE")
		player.global_position=stance.global_position
		player.camera.global_position=player.global_position+Vector3.UP*player.STANDING_EYE
		player.camera.look_at(shelf.to_global(Vector3(0,.8,0)))
		if not await shots.settle(1.8,row.id):ok=false;break
		if not air.field.ready or not air.field.failed.is_empty() or air.field.updates==0:push_error("Shelf capture requires live voxel field");ok=false;break
		if not await shots.capture(row.id):ok=false;break
	ok=shots.finish() and ok
	world.shutdown_for_tests();world.free();get_tree().quit(0 if ok else 1)
