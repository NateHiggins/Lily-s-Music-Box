extends Node
## Matched production views: circuit off/on, then room plus carried lamp.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
const VIEWS := preload("res://tests/orison_v2_upper_apartment_shot.gd").VIEWS
const ROOMS := ["F05_A_MAIN","F05_B_KITCHEN","F05_C_BED1","F06_A_STUDY","F06_C_MAIN"]
var shots = Harness.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not shots.setup(self,"V2 UPPER LIGHTING",VIEWS.size()*3):
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(2)
		return
	var player := world.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.camera.make_current()
	var ok := true
	for i in VIEWS.size():
		var view: Array = VIEWS[i]
		player.global_position = world.adapter.root.to_global(view[1])
		player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
		player.camera.look_at(world.adapter.root.to_global(view[2]))
		var plate: Node = world.adapter.resolve(ROOMS[i]+"_SWITCH")
		for state: String in ["off","on","lamp"]:
			player.set_lamp_enabled(state == "lamp")
			if state != "lamp":plate.call("interact",player)
			# Let the real filament cool before treating a frame as lamp-off.
			if not await shots.settle(3.0 if state == "off" else 1.0,str(view[0])+"_"+state):
				ok = false
				break
			if state != "lamp" and player.flashlight.visible:
				push_error("Room-only capture still has a visible carried lamp")
				ok = false
				break
			if not await shots.capture(str(view[0])+"_"+state):
				ok = false
				break
		if not ok:break
	ok = shots.finish() and ok
	world.shutdown_for_tests()
	world.free()
	get_tree().quit(0 if ok else 1)
