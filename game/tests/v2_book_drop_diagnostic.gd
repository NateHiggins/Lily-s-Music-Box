extends "res://tests/v2_readable_library_bench.gd"
## INERT controlled native drop diagnostic, no runtime qualification.
func _run() -> void:
	RealityState.persistence_enabled=false
	check(contact_precision.bind(get_world_3d()),"native contact precision")
	var stock:=preload("res://scripts/building/v2_readable_library_stock.gd").new()
	if not check(stock.prepare(),"native library prepares"): get_tree().quit(1);return
	var floor_body:=StaticBody3D.new();floor_body.position.y=-.1;add_child(floor_body)
	var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,.2,8);floor_shape.shape=box;floor_body.add_child(floor_shape)
	var shelf:=Shelf.new();shelf.native_stock=stock;shelf.owner_name="Iris Bell";shelf.unit="5C";shelf.case_style="plain";shelf.position.x=10.;add_child(shelf)
	var book: Node3D=shelf._books.values()[2]
	var records: Array=[]
	for variant: String in ["one_closed_hull","three_native_groups"]:
		book.freeze=true;book.shelf_slot=-1
		book.global_transform=Transform3D(Basis(Vector3.RIGHT,.36),Vector3(-.1,1.,0.))
		book.linear_velocity=Vector3.ZERO;book.angular_velocity=Vector3.ZERO
		book._closed_solid.disabled=variant!="one_closed_hull"
		for solid: CollisionShape3D in book._group_solids.values(): solid.disabled=variant=="one_closed_hull"
		book._rest_until=-1
		for frame in 3: await get_tree().physics_frame
		book.freeze=false;book.sleeping=false
		var elapsed:=0
		for frame in 600:
			await get_tree().physics_frame;elapsed+=1
			if book.sleeping:break
		var row: Dictionary={"variant":variant,"frames":elapsed,"sleeping":book.sleeping,"position":str(book.global_position),"velocity":str(book.linear_velocity),"spin":str(book.angular_velocity)}
		records.append(row);print("BOOK DROP: ",row)
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("drop.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records},"\t"))
	get_tree().quit()
