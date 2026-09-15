extends Node
## Eye-height production views; native room circuits and carried voxel lamp.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
const VIEWS := [
	["5A",Vector3(-9.65,12.8,-8.05),Vector3(-9.95,14.05,-6.67)],
	["5B",Vector3(-7.55,12.8,7.8),Vector3(-8.985,14.05,7.1)],
	["5C",Vector3(5.5,12.8,4.9),Vector3(4.115,14.05,4.94)],
	["6A",Vector3(-9.65,16,-8.05),Vector3(-9.95,17.25,-6.67)],
	["6B",Vector3(-7.55,16,7.8),Vector3(-8.985,17.25,7.1)],
	["6C",Vector3(5.5,16,4.9),Vector3(4.115,17.25,4.94)],
]
var shots = Harness.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not shots.setup(self,"V2 UPPER KITCHENS",12):
		get_tree().quit(2);return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:
		world.shutdown_for_tests();world.free();get_tree().quit(2);return
	var player := world.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.camera.make_current()
	player.set_lamp_enabled(true)
	var air: Node = world.get_node("LampAtmosphere")
	var ok := true
	for view: Array in VIEWS:
		player.global_position = world.adapter.root.to_global(view[1])
		player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
		player.camera.look_at(world.adapter.root.to_global(view[2]))
		var cabinet: Node = world.adapter.resolve(str(view[0])+"_prep_cabinet")
		for state: String in ["closed","open"]:
			if state == "open":cabinet.call("interact",player)
			if not await shots.settle(1.5,str(view[0])+"_"+state):
				ok = false;break
			if not air.field.ready or not air.field.failed.is_empty() or air.field.updates == 0:
				push_error("Kitchen capture requires the live voxel lamp field")
				ok = false;break
			if not await shots.capture(str(view[0])+"_"+state):
				ok = false;break
		if not ok:break
	ok = shots.finish() and ok
	world.shutdown_for_tests();world.free()
	get_tree().quit(0 if ok else 1)
