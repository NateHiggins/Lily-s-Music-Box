extends "res://tests/orison_v2_news_fittings_test.gd"
## Current playable retirement; historical active-cabinet receipts stay intact.
func _init() -> void:capture_enabled=false
func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var directory:=OS.get_environment("SHOT_DIR")
	var result:=DirAccess.make_dir_recursive_absolute(directory)
	check(result==OK,"diagnostic output directory is available before inherited validators write")
	if result!=OK:return {"checks":checks,"failures":failures.duplicate()}
	await super.validate_in_world(world)
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
	var output:=OS.get_environment("SHOT_DIR")
	FileAccess.open(output.path_join("retirement.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Playable V2 cabinet retirement and inherited News fitting checks; historical active-cabinet tests are not runtime qualification for this state","retired_shop_draws":retired,"checks":checks,"failures":failures},"\t"))
	return {"checks":checks,"failures":failures.duplicate()}
