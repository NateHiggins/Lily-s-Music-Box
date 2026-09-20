extends Node
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Harness := preload("res://tests/shot_harness.gd")
var shots = Harness.new()
func _ready() -> void:call_deferred("_run")
func _run() -> void:
	if not shots.setup(self,"V2 UPPER RADIOS",12):get_tree().quit(2);return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new();clock.configure_date(1928,11,10,20*60)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/v2_upper_radio_probes.json"))
	var world := Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(2);return
	var player := world.player
	player.set_physics_process(false);player.set_process_unhandled_input(false);player.camera.make_current()
	var air: Node=world.get_node("LampAtmosphere")
	var capsule := CapsuleShape3D.new();capsule.radius=.38;capsule.height=1.524
	var ok := true
	for row: Dictionary in source.receivers:
		var identity := "DomesticRadio_"+str(row.unit)
		var radio := world.adapter.resolve(identity) as DomesticRadioProp
		var stance := world.adapter.resolve(identity+"_STANCE") as Node3D
		player.global_position=stance.global_position
		player.camera.global_position=player.global_position+Vector3.UP*player.STANDING_EYE
		player.camera.look_at(radio.to_global(Vector3(0,.15,0)))
		player.set_lamp_enabled(false)
		if not await shots.settle(3.1,identity):ok=false;break
		var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule
		query.transform=Transform3D(Basis.IDENTITY,player.global_position+Vector3.UP*.8);query.exclude=[player.get_rid()]
		if not player.get_world_3d().direct_space_state.intersect_shape(query).is_empty():push_error("Radio standing capsule blocked: "+identity);ok=false;break
		var lo := Vector3(row.bounds[0][0],row.bounds[0][1],row.bounds[0][2]);var hi := Vector3(row.bounds[1][0],row.bounds[1][1],row.bounds[1][2])
		var actual: AABB=radio.call("_visual_bounds")
		if not AABB(lo,hi-lo).grow(.002).encloses(actual):push_error("Native receiver exceeds source clearance: %s %s" % [identity,actual]);ok=false;break
		if player.flashlight.visible:push_error("Room-only capture needs cooled carried filament");ok=false;break
		player.use_primary_interaction()
		if not radio.powered or not radio.get("_programme").playing:push_error("Player E failed to start receiver: "+identity);ok=false;break
		if player.telegram_hud.last_card.get("condition") != "PLAYING":push_error("Wireless message did not follow actual receiver state");ok=false;break
		if not await shots.settle(.6,identity+"_message"):ok=false;break
		if not await shots.capture(identity+"_room"):ok=false;break
		player.set_lamp_enabled(true)
		if not await shots.settle(1.0,identity+"_lamp"):ok=false;break
		if not air.field.ready or not air.field.failed.is_empty() or air.field.updates==0:push_error("Receiver capture needs live voxel field");ok=false;break
		if not await shots.capture(identity+"_lamp"):ok=false;break
		player.use_primary_interaction()
		if radio.powered or radio.get("_programme").playing:push_error("Player E failed to stop receiver: "+identity);ok=false;break
	ok=shots.finish() and ok
	world.shutdown_for_tests();world.free()
	# Let deferred renderer releases and already queued scene timers drain
	# after synchronous world retirement before ending the engine process.
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0 if ok else 1)
