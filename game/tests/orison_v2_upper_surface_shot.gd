extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
var shots = Harness.new()
func _ready() -> void:call_deferred("_run")
func _run() -> void:
	if not shots.setup(self,"V2 UPPER SURFACES",14):get_tree().quit(2);return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_surface_props.json"))
	var groups := {}
	for row: Dictionary in source.props:
		if str(row.unit)[0] not in ["5","6"]:continue
		if not groups.has(row.support):groups[row.support]=[]
		groups[row.support].append(row)
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(2);return
	var player := world.player
	player.set_physics_process(false);player.set_process_unhandled_input(false)
	player.camera.make_current();player.set_lamp_enabled(true)
	var air: Node = world.get_node("LampAtmosphere")
	var ok := true
	for identity: String in groups:
		var support: Node3D = world.adapter.resolve(identity)
		var stance: Node3D = world.adapter.resolve(identity+"_STANCE")
		player.global_position = stance.global_position
		player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
		var center := Vector3.ZERO
		for row: Dictionary in groups[identity]:center += Vector3(row.position[0],row.position[1]+.05,row.position[2])
		center /= groups[identity].size()
		player.camera.look_at(support.to_global(center))
		if not await shots.settle(1.2,identity):ok=false;break
		if not air.field.ready or not air.field.failed.is_empty() or air.field.updates==0:push_error("Surface capture requires live voxel field");ok=false;break
		if not await shots.capture(identity):ok=false;break
	ok=shots.finish() and ok
	world.shutdown_for_tests();world.free();get_tree().quit(0 if ok else 1)
