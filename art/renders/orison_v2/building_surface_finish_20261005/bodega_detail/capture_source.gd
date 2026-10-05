extends "res://tests/orison_v2_roof_membrane_test.gd"
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed:get_tree().quit(1);return
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false);world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var shop:=world.exterior_cell.instance_node("SHOP_BODEGA")
	var sampler: Node=load("res://tests/orison_v2_city_sweep.gd").new()
	var records: Array=[]
	for view: Array in [["counter_front",Vector3(-1.25,.03,-.85),Vector3(-1.25,.88,-1.34)],["practical_drop",Vector3(.85,.03,-3),Vector3(.55,2.97,-2)]]:
		var feet:=shop.to_global(view[1])
		check(sampler._city_clear_station(world,feet),"physical standing station for "+str(view[0]))
		world.player.global_position=feet;world.player.velocity=Vector3.ZERO
		world.player.face_world_point(shop.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
		records.append({"id":view[0],"feet":[feet.x,feet.y,feet.z],"local_target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	sampler.free()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":records,"checks":checks,"failures":failures},"\t"))
	print("BODEGA FINISH DETAIL: checks=",checks," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)
