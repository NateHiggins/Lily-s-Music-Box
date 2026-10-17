extends Node3D
## INERT imported-mesh physics diagnosis; no production-world acceptance.
func _ready() -> void: _run.call_deferred()

func _run() -> void:
	var factory := preload("res://scripts/building/orison_v2_native_domestic_furniture.gd").new()
	if not factory.prepare(): push_error("bench factory failed");get_tree().quit(1);return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_surface_props.json"))
	var stock: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_surface_stock.json"))
	var bodies: Dictionary={}
	var selected: Array[Dictionary]=[]
	for row: Dictionary in source.props:
		if row.id not in ["5C_overalls","4C_jersey","2A_cushion_a","2A_cushion_b"]:continue
		selected.append(row)
		if bodies.has(row.support):continue
		var body := StaticBody3D.new();body.name=row.support
		body.position=Vector3(float(bodies.size())*4.,12.8,-20.)
		add_child(body)
		if not factory.mount_on(body,row.support):push_error("bench mount failed");get_tree().quit(1);return
		bodies[row.support]=body
	await get_tree().physics_frame;await get_tree().physics_frame
	var records: Array[Dictionary]=[]
	var failures: Array[String]=[]
	for row: Dictionary in selected:
		var body: StaticBody3D=bodies[row.support]
		var pose := Transform3D(Basis(Vector3.UP,float(row.yaw)),Vector3(row.position[0],row.position[1],row.position[2]))
		for contact: Dictionary in stock.contacts:
			if contact.assembly!=row.id:continue
			var p: Array=contact.point
			var at: Vector3=body.to_global(pose*Vector3(p[0],p[1],p[2]))
			var short: Dictionary=_ray(at,.004)
			var long: Dictionary=_ray(at,.25)
			var qualifies: bool=_qualifies(long,at,body)
			var floating_at := at+Vector3.UP*.01
			var floating_qualifies: bool=_qualifies(_ray(floating_at,.25),floating_at,body)
			if not qualifies:failures.append("actual bearing: "+str(row.id)+" / "+str(contact.label))
			if floating_qualifies:failures.append("floating negative control: "+str(row.id))
			var nearby: Array[Dictionary]=[]
			for offset in [Vector3(.00001,0,0),Vector3(-.00001,0,0),Vector3(0,0,.00001),Vector3(0,0,-.00001),Vector3(.0002,0,.0002)]:
				nearby.append(_record(_ray(at+offset,.25),at))
			var result: Dictionary={"id":row.id,"label":contact.label,"local":str(body.to_local(at)),"short":_record(short,at),"long":_record(long,at),"nearby":nearby,"long_qualifies":qualifies,"floating_negative_control_qualifies":floating_qualifies}
			records.append(result)
			print("CONTACT BENCH ",JSON.stringify(result))
	var out := OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		FileAccess.open(out.path_join("contact_bench.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Imported native mesh/physics ray diagnosis, not composed-world acceptance.","records":records,"failures":failures},"\t"))
	for body: StaticBody3D in bodies.values():body.free()
	factory.finish()
	print("SEATING CONTACT BENCH: ","PASS" if failures.is_empty() else "FAIL","; ",records.size()," bearings and floating negative controls; ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func _qualifies(hit: Dictionary,at: Vector3,body: StaticBody3D) -> bool:
	return not hit.is_empty() and hit.collider==body and hit.position.distance_to(at)<.00004 and hit.normal.y>.99

func _ray(at: Vector3,half: float) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*half,at-Vector3.UP*half,1))

func _record(hit: Dictionary,at: Vector3) -> Dictionary:
	if hit.is_empty():return {"hit":false}
	return {"hit":true,"distance":hit.position.distance_to(at),"normal":str(hit.normal),"delta":str(hit.position-at),"collider":str(hit.collider.name)}
