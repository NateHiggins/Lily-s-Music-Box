extends RefCounted
const Trim=preload("res://scripts/building/orison_v2_millwork.gd")
const Reference=preload("res://tests/millwork_unculled_reference.gd")
func signature(room: Node3D) -> Dictionary:
	var result: Dictionary={}
	for node: MultiMeshInstance3D in room.find_children("*","MultiMeshInstance3D",true,false):
		result[str(node.name)]={"buffer":node.multimesh.buffer,"sources":node.get_meta("wall_sources"),"piece":node.get_meta("separate_wood_piece"),"mesh":node.multimesh.mesh,"material":node.material_override}
	return result
func run(world: OrisonV2RuntimeRoot,suite: Node) -> void:
	var shell=world.adapter.root
	var stock: Array[Dictionary]=Trim.collect_wall_stock(shell)
	var rows: Array=[]
	var holder=Node3D.new();world.add_child(holder)
	var controls: Array[Dictionary]=[
		{"id":"below","bounds":AABB(Vector3(0,-2,0),Vector3(1,1.99,1))},
		{"id":"touch_low","bounds":AABB(Vector3(0,-1,0),Vector3(1,1,1))},
		{"id":"cross_storey","bounds":AABB(Vector3(0,-3,0),Vector3(1,9,1))},
		{"id":"inside","bounds":AABB(Vector3(0,1,0),Vector3.ONE)},
		{"id":"touch_high","bounds":AABB(Vector3(0,3,0),Vector3.ONE)},
		{"id":"above","bounds":AABB(Vector3(0,3.01,0),Vector3.ONE)}]
	var selected:=Trim.wall_stock_for_band(controls,0,3)
	var ids: Array=[]
	for wall: Dictionary in selected:ids.append(wall.id)
	suite.check(ids==["touch_low","cross_storey","inside","touch_high"],"trim culling keeps touching and crossing stock in original order")
	for record: Dictionary in shell.layout.spaces:
		if record.get("open_shell",false) or str(record.id) in shell.space_geometry_exclusions:continue
		var floor_y: float=shell.level_y[record.level]
		var clear: float=shell.layout.dimensions.clear_height
		var depth: float=shell.layout.dimensions.partition_wall
		var casings: Array[AABB]=preload("res://scripts/building/orison_v2_window_joinery.gd").clearance_boxes(shell,record)
		for mount: Dictionary in shell.layout.anchors:
			if str(mount.get("space",""))!=str(record.id) or not mount.has("finish_bounds"):continue
			var box: AABB=shell._service_box(mount.finish_bounds);box.position.y+=floor_y;casings.append(box)
		var original=Node3D.new();var candidate=Node3D.new();holder.add_child(original);holder.add_child(candidate)
		var started:=Time.get_ticks_usec()
		Reference.build(original,record,floor_y,clear,depth,null,null,shell.layout.doors,casings,stock)
		var middle:=Time.get_ticks_usec()
		Trim.build(candidate,record,floor_y,clear,depth,null,null,shell.layout.doors,casings,stock)
		var finished:=Time.get_ticks_usec()
		var before:=signature(original);var after:=signature(candidate)
		var equal:=var_to_bytes(before)==var_to_bytes(after)
		for key: String in before:
			equal=equal and after.has(key)
			if after.has(key):equal=equal and before[key].mesh==after[key].mesh and before[key].material==after[key].material
		var instances:=0
		for key: String in before:instances+=(before[key].sources as PackedStringArray).size()
		suite.check(equal,"trim instance buffers, geometry, material and wall sources unchanged: "+str(record.id))
		rows.append({"room":record.id,"equal":equal,"instances":instances,"unculled_us":middle-started,"culled_us":finished-middle})
		original.free();candidate.free()
	holder.free()
	var output:=OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		var file=FileAccess.open(output.path_join("millwork_culling.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class":"INERT","stock":stock.size(),"rooms":rows},"  "))
