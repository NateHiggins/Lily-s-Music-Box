extends Node
## Authored controls in the full production world at standing eye height.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
var shots = Harness.new()
func _ready() -> void:call_deferred("_run")
func _run() -> void:
	if not shots.setup(self,"V2 UPPER SERVICES",34):get_tree().quit(2);return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.configure_date(1928,11,10,20*60)
	var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_services_probes.json"))
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(2);return
	var player := world.player
	player.set_physics_process(false);player.set_process_unhandled_input(false)
	player.camera.make_current();player.set_lamp_enabled(false)
	if not await shots.settle(3.0,"filament_cooldown"):get_tree().quit(2);return
	var ok := true
	for probe: Dictionary in probes.services:
		var prop: Node3D = world.adapter.resolve(probe.id)
		var y := 12.8 if probe.level == "F05" else 16.0
		player.global_position = world.adapter.root.to_global(Vector3(probe.stance[0],y,probe.stance[2]))
		player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
		var target: Vector3
		if probe.kind == "mirror":target = prop.call("mirror_center")
		elif probe.kind == "toaster":target = prop.to_global(Vector3(0,.11,0))
		else:target = prop.to_global(Vector3(0,-.3,0))
		player.camera.look_at(target)
		for state: String in (["closed","open"] if probe.kind == "mirror" else ["installed"]):
			if state == "open":prop.call("set_door_open",true)
			if not await shots.settle(1.0,str(probe.id)+"_"+state):ok=false;break
			if player.flashlight.visible:push_error("Room-light capture retains a carried lamp");ok=false;break
			if not await shots.capture(str(probe.unit)+"_"+str(probe.kind)+"_"+state):ok=false;break
		if not ok:break
	for unit: String in ["5A","5B","5C","6A","6B","6C"]:
		for kind: String in ["sink_details","toilet_roll"]:
			var identity := unit+"_wc" if kind == "toilet_roll" else "F0"+unit[0]+"_"+unit+"_SINK_01"
			var support: Node3D = world.adapter.resolve(identity)
			var stance: Node3D = world.adapter.resolve(identity+"_STANCE")
			player.global_position = stance.global_position
			player.camera.global_position = player.global_position+Vector3.UP*player.STANDING_EYE
			player.camera.look_at(support.to_global(Vector3(0,.6,-.08)))
			if not await shots.settle(.8,unit+"_"+kind) or not await shots.capture(unit+"_"+kind):ok=false;break
		if not ok:break
	ok = shots.finish() and ok
	world.shutdown_for_tests();world.free();get_tree().quit(0 if ok else 1)
