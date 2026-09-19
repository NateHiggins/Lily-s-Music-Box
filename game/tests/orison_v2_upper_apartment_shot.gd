extends Node
## Production composition at authored eye-height viewpoints. Only locomotion
## and input are frozen; no fill lights, hidden ceilings or material overrides.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
const VIEWS := [
	["5a_drafting", Vector3(-9.4,12.8,-4.7), Vector3(-12.5,13.6,-4.6)],
	["5b_kitchen", Vector3(-8.5,12.8,8.4), Vector3(-6.8,13.8,9.4)],
	["5c_bedroom", Vector3(2.2,12.8,8.5), Vector3(1.5,13.5,10.6)],
	["6a_workdesk", Vector3(-9.6,16.0,-10.0), Vector3(-9.7,16.8,-11.9)],
	["6c_sitting", Vector3(-.8,16.0,7.4), Vector3(-4.3,16.8,9.3)],
]
var shots = Harness.new()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not shots.setup(self, "V2 UPPER APARTMENTS", VIEWS.size()):
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	if not clock.configure_date(1928,11,10,20*60):
		get_tree().quit(2)
		return
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
	player.set_lamp_enabled(true)
	var air: Node = world.get_node("LampAtmosphere")
	var ok := true
	for view: Array in VIEWS:
		player.global_position = world.adapter.root.to_global(view[1])
		player.camera.global_position = player.global_position + Vector3.UP * player.STANDING_EYE
		player.camera.look_at(world.adapter.root.to_global(view[2]))
		if not await shots.settle(1.0, str(view[0])):
			ok = false
			break
		if not air.field.ready or not air.field.failed.is_empty() or air.field.updates == 0:
			push_error("Upper apartment capture requires the live voxel lamp field")
			ok = false
			break
		if not await shots.capture(str(view[0])):
			ok = false
			break
	ok = shots.finish() and ok
	world.shutdown_for_tests()
	world.free()
	get_tree().quit(0 if ok else 1)
