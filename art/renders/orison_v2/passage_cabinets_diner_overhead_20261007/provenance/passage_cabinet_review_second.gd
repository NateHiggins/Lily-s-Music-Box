extends "res://tests/orison_v2_city_sweep.gd"
## Temporary visual inspection only; no ledger or runtime-contract authority.

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world starts for cabinet-free visual review")
	if world.startup_failed or world.passage_region.startup_failed:
		world.shutdown_for_tests(); world.free(); get_tree().quit(1); return
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	var passage: OrisonV2PassageRegion = world.passage_region
	check(not passage.cabinets_enabled and passage.receiving_row.cabinets.is_empty(),"default shop cabinets and play actors are absent")
	var vestibule: Dictionary = world.layout.spaces.filter(func(row):return row.id=="F01_VESTIBULE")[0]
	var rect: Array = vestibule.rect
	world.player.global_position = world.adapter.root.to_global(Vector3((rect[0]+rect[2])*.5,0.,(rect[1]+rect[3])*.5))
	for frame in 600:
		if passage.residency.state == "RESIDENT": break
		await get_tree().process_frame
	check(passage.residency.state=="RESIDENT","actual shop geometry is resident")
	if passage.residency.state != "RESIDENT":
		world.shutdown_for_tests(); world.free(); get_tree().quit(1); return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var floor: Dictionary = passage.source_layout.floors.filter(func(row):return row.id=="F01")[0]
	var observations: Array = []
	for spec: Array in [["shop_model_laundry",Vector3(7.6,.03,42.8),Vector3(7.6,.85,44.25)],
		["shop_photo_supplies",Vector3(20.35,.03,60.1),Vector3(21.45,.85,59.35)],
		["shop_radio_service",Vector3(19.45,.03,57.5),Vector3(21.45,.28,57.2)],
		["shop_news_cigars",Vector3(18.15,.03,49.4),Vector3(19.9,.28,50.1)],
		["shop_pawnbroker",Vector3(18.55,.03,53.4),Vector3(18.55,.85,55.02)],
		["shop_luncheonette",Vector3(19.8,.03,40.3),Vector3(18.55,.85,39.75)]]:
		var cell: Node3D = passage.cell_nodes[spec[0]]
		var preferred: Vector3 = spec[1]
		var selected := preferred
		var distance: float = INF
		if not _city_clear_station(world,cell.to_global(selected)) or not _clear_camera_target(world,cell,selected,spec[2]):
			var source: Dictionary = floor.furniture.filter(func(row):return str(row.get("batch",""))==spec[0] and str(row.id).ends_with("_floor"))[0]
			var r: Array = source.rect
			for u in range(1,25):
				for v in range(1,25):
					var at := Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)) and _clear_camera_target(world,cell,at,spec[2]):
						selected=at; distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"sampled floor/capsule station is clear: "+str(spec[0]))
		check(_clear_camera_target(world,cell,selected,spec[2]),"sampled target is visible across the cleared former cabinet floor: "+str(spec[0]))
		world.player.global_position = cell.to_global(selected)
		world.player.velocity = Vector3.ZERO
		world.player.face_world_point(cell.to_global(spec[2]))
		world.player.set_lamp_enabled(true)
		await _settled_optics()
		await shot(str(spec[0]))
		observations.append({"cell":spec[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[spec[2].x,spec[2].y,spec[2].z],"image":str(spec[0])+".png"})
	var directory := OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"views":observations,"scope":"Six sampled cabinet-free shop views; this temporary capture programme grants no route, utility, human acceptance or ledger proof."},"\t"))
	print("CABINET-FREE VISUAL REVIEW: checks=",checks," views=",observations.size()," failures=",failures.size())
	world.shutdown_for_tests(); world.free()
	await _retired_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func _clear_camera_target(world: OrisonV2RuntimeRoot,cell: Node3D,feet: Vector3,target: Vector3) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(cell.to_global(feet+Vector3.UP*1.45),cell.to_global(target),1,[world.player.get_rid()])
	return world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
