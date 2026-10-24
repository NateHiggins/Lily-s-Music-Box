extends "res://tests/orison_v2_news_fittings_test.gd"
## Current playable retirement; historical active-cabinet receipts stay intact.
func _init() -> void:capture_enabled=false
func _prepare_resident_world(world: OrisonV2RuntimeRoot) -> bool:
	var passage:=world.passage_region
	check(passage!=null and not passage.startup_failed,"retirement has a valid production passage owner")
	if passage==null or passage.startup_failed:return false
	# This is stationary geometry discovery, not a played navigation claim.
	# A prior room review can legitimately have streamed the passage out.
	var vestibules: Array=world.layout.spaces.filter(func(row):return row.id=="F01_VESTIBULE")
	check(vestibules.size()==1,"retirement discovers the existing vestibule from the production layout")
	if vestibules.size()!=1:return false
	var rect: Array=vestibules[0].rect
	world.player.set_physics_process(false)
	world.player.global_position=world.adapter.root.to_global(Vector3((rect[0]+rect[2])*.5,0.,(rect[1]+rect[3])*.5))
	world.player.velocity=Vector3.ZERO
	await get_tree().physics_frame;await get_tree().physics_frame
	var started:=Time.get_ticks_msec()
	# The rejected fixed600-frame run is still LOADING at12.7s, with eleven
	# staged cells and one request pending. Cooperative fitting deliberately
	# yields; a frame count is not a fixture-readiness deadline.
	var deadline:=started+60000
	var frame_index:=0
	var samples: Array[Dictionary]=[]
	while Time.get_ticks_msec()<deadline:
		if passage.residency.state in ["RESIDENT","FAILED"] or passage.startup_failed:break
		if frame_index%60==0:samples.append(_residency_sample(passage,world.player,frame_index,started))
		await get_tree().process_frame
		frame_index+=1
	samples.append(_residency_sample(passage,world.player,frame_index,started))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("retirement_prefetch.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Stationary inspection fixture readiness, bounded60s wall-clock wait; no played navigation or streaming-latency qualification","samples":samples},"\t"))
	var ready: bool=passage.residency.state=="RESIDENT" and not passage.startup_failed
	check(ready,"normal vestibule prefetch makes retirement geometry resident")
	for identity: String in ["passage","shop_radio_service","shop_model_laundry","shop_photo_supplies","shop_news_cigars","shop_pawnbroker","shop_luncheonette"]:
		var present: bool=passage.cell_nodes.has(identity)
		check(present,"retirement requires its installed source cell: "+identity)
		ready=ready and present
	return ready

func _residency_sample(passage: OrisonV2PassageRegion,player: PlayerController,frame_index: int,started: int) -> Dictionary:
	var owner: Node=passage.residency
	return {"frame":frame_index,"elapsed_ms":Time.get_ticks_msec()-started,"player_local":str(owner.frame.to_local(player.global_position)),"prefetch_contains_player":owner._prefetch_box.has_point(owner.frame.to_local(player.global_position)),"wanted":owner._wanted,"processing":owner.is_processing(),"physics_processing":owner.is_physics_processing(),"stopped":owner._stopped,"staged_cells":owner._staged_cells.keys(),"fitting_cell":owner._fit_identity,"remaining_operations":owner._fit_operations.size(),"operation":str(owner._fit_operations[0][0]) if not owner._fit_operations.is_empty() else "","snapshot":owner.snapshot()}
func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var directory:=OS.get_environment("SHOT_DIR")
	var result:=DirAccess.make_dir_recursive_absolute(directory)
	check(result==OK,"diagnostic output directory is available before inherited validators write")
	if result!=OK:return {"checks":checks,"failures":failures.duplicate()}
	if not await _prepare_resident_world(world):return _finish_retirement(0)
	var inherited_result: Dictionary=await super.validate_in_world(world)
	check(inherited_result.has_all(["checks","failures"]),"inherited News validator returns a complete result")
	if not inherited_result.has_all(["checks","failures"]):return _finish_retirement(0)
	check(world.get_tree().get_nodes_in_group("arcade_cabinets").is_empty(),"no arcade cabinet actor, game screen or interaction owner enters playable V2")
	var passage:=world.passage_region
	check(not passage.cabinets_enabled and passage.receiving_row.cabinets.is_empty() and not passage.receiving_row.has_focused_panel(),"passage has no receiving games or focused game panels")
	var cells: Dictionary=passage.cell_nodes
	var retired:=0
	for pair: Array in [["radio","shop_radio_service"],["laundry","shop_model_laundry"],["photo","shop_photo_supplies"],["news","shop_news_cigars"],["pawn","shop_pawnbroker"],["diner","shop_luncheonette"]]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/"+str(pair[0])+"_receiving.json"))
		var cell:=cells[str(pair[1])] as Node3D
		for record: Dictionary in data.original_draws:
			var draw:=cell.get_node(str(record.name)) as MeshInstance3D
			check(draw!=null and not draw.visible and draw.mesh.get_faces().size()==int(record.expected_triangles)*3,"original cabinet draw is preserved intact and absent from play: "+str(record.name));retired+=1
		var hull:=cell.get_node(str(data.hull_name)) as StaticBody3D
		check(hull.collision_layer==0 and hull.collision_mask==0 and (hull.get_child(0) as CollisionShape3D).disabled,"retired shop cabinet cannot obstruct movement: "+str(pair[0]))
		for node: Node in cell.get_children():
			check(not str(node.name).ends_with("Receiving"),"retired shop has no replacement arcade chassis: "+str(pair[0]))
	var bar:=world.bar_region.get_node("RetainedBarGeometry") as Node3D
	check(bar.get_node_or_null("BarReceiving")==null,"bar has no native replacement arcade cases")
	var retirement:=bar.get_node_or_null("RetiredBarCabinets")
	check(retirement!=null,"bar records exact source-triangle and hull retirement")
	if retirement!=null:
		var original_meshes: Dictionary=retirement.get_meta("original_meshes")
		var hulls: Dictionary=retirement.get_meta("original_hulls")
		var removed: Dictionary=retirement.get_meta("removed_triangles")
		for draw: MeshInstance3D in original_meshes:
			check(original_meshes[draw].get_faces().size()/3-draw.mesh.get_faces().size()/3==int(removed[draw]),"bar removes only the exact cabinet-owned triangles and keeps neighbouring scenery")
		for shape: CollisionShape3D in hulls:
			check(shape.shape==hulls[shape].next,"bar retains its original collision owner with only cabinet faces removed")
		check(not original_meshes.is_empty() and not hulls.is_empty(),"bar retirement includes both visual and physical source stock")
	check(retired>=40,"retirement covers the complete installed shop cabinet row")
	check(world.get_tree().get_nodes_in_group("arcade_cabinets").is_empty(),"normal passage prefetch cannot respawn retired cabinet actors")
	return _finish_retirement(retired)

func _finish_retirement(retired: int) -> Dictionary:
	var output:=OS.get_environment("SHOT_DIR")
	FileAccess.open(output.path_join("retirement.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Playable V2 cabinet retirement and inherited News fitting checks; historical active-cabinet tests are not runtime qualification for this state","retired_shop_draws":retired,"checks":checks,"failures":failures},"\t"))
	return {"checks":checks,"failures":failures.duplicate()}
