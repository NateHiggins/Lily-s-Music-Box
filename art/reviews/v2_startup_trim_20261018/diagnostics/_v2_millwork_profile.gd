extends Node3D
const Trim=preload("res://scripts/building/orison_v2_millwork.gd")
const Reference=preload("res://tests/millwork_unculled_reference.gd")
var failures: Array=[]
var rows: Array=[]
func _ready() -> void:run.call_deferred()
func signature(room: Node3D) -> Dictionary:
	var result: Dictionary={}
	for node: MultiMeshInstance3D in room.find_children("*","MultiMeshInstance3D",true,false):
		result[str(node.name)]={"buffer":node.multimesh.buffer,"sources":node.get_meta("wall_sources"),"piece":node.get_meta("separate_wood_piece"),"mesh":node.multimesh.mesh,"material":node.material_override}
	return result
func run() -> void:
	if DisplayServer.get_name()=="headless":get_tree().quit(1);return
	var stock_root=Node3D.new()
	var script=load("res://tests/_v2_millwork_stock_probe.gd") as GDScript
	if script==null or not script.can_instantiate():get_tree().quit(1);return
	stock_root.set_script(script)
	stock_root.production_materials=true
	stock_root.show_clearance_anchors=false
	stock_root.show_reservation_volumes=false
	add_child(stock_root)
	if not stock_root.failures.is_empty():get_tree().quit(1);return
	var stock: Array[Dictionary]=Trim.collect_wall_stock(stock_root)
	for record: Dictionary in stock_root.layout.spaces:
		if record.get("open_shell",false):continue
		var floor_y: float=stock_root.level_y[record.level]
		var clear: float=stock_root.layout.dimensions.clear_height
		var depth: float=stock_root.layout.dimensions.partition_wall
		var subset: Array[Dictionary]=[]
		for wall: Dictionary in stock:
			var bounds: AABB=wall.bounds
			if bounds.end.y<floor_y or bounds.position.y>floor_y+clear:continue
			subset.append(wall)
		var casings: Array[AABB]=preload("res://scripts/building/orison_v2_window_joinery.gd").clearance_boxes(stock_root,record)
		for mount: Dictionary in stock_root.layout.anchors:
			if str(mount.get("space",""))!=str(record.id) or not mount.has("finish_bounds"):continue
			var box: AABB=stock_root._service_box(mount.finish_bounds);box.position.y+=floor_y;casings.append(box)
		var a=Node3D.new();var b=Node3D.new();add_child(a);add_child(b)
		var t:=Time.get_ticks_usec()
		Reference.build(a,record,floor_y,clear,depth,null,null,stock_root.layout.doors,casings,stock)
		var mid:=Time.get_ticks_usec()
		Trim.build(b,record,floor_y,clear,depth,null,null,stock_root.layout.doors,casings,stock)
		var finish:=Time.get_ticks_usec()
		var first:=signature(a);var second:=signature(b)
		var equal:=var_to_bytes(first)==var_to_bytes(second)
		var instances:=0
		for key: String in first:instances+=(first[key].sources as PackedStringArray).size()
		rows.append({"room":record.id,"equal":equal,"legacy_us":mid-t,"candidate_us":finish-mid,"stock":stock.size(),"subset":subset.size(),"instances":instances})
		if not equal:failures.append(record.id)
		a.free();b.free()
		print("MILLWORK PROFILE ",record.id," equal=",equal," us=",mid-t,"/",finish-mid)
		await get_tree().process_frame
	var report={"evidence_class":"INERT","rows":rows,"failures":failures,"stock":stock.size()}
	var f=FileAccess.open("C:/PleaseRemainOnTheLine/tmp/v2-retirement-20261018/millwork2.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "));f.close()
	stock_root.free()
	print("MILLWORK PROFILE ","PASS" if failures.is_empty() else "FAIL"," rooms=",rows.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
