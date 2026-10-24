extends Node3D
## INERT actual shell architecture stock; no gameplay acceptance.
func _ready() -> void:call_deferred("_run")
func _run() -> void:
	var shell:=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.production_materials=true;shell.show_clearance_anchors=false;shell.show_reservation_volumes=false
	add_child(shell)
	preload("res://scripts/building/orison_v2_bathroom_finishes.gd").build(shell,shell.layout,shell.level_y,shell.architectural_materials,preload("res://scripts/building/orison_v2_millwork.gd").collect_wall_stock(shell))
	var metric:=preload("res://tests/orison_v2_roof_bulkhead_caps_test.gd").new()
	var count:=0
	var bad: Array=[]
	for draw: MeshInstance3D in shell.find_children("Bathroom*","MeshInstance3D",true,false):
		metric._check_cap_mapping(draw.mesh,true);count+=1
		var arrays:=draw.mesh.surface_get_arrays(0)
		if draw.name=="BathroomTileEdging":
			var intrusions:=0
			for frame: AABB in draw.get_meta("frame_clearance_boxes"):
				var interior:=frame.grow(-.00005)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					if interior.has_point(vertex):intrusions+=1
			metric.check(intrusions==0,"actual ceramic vertices clear door and window joinery: "+str(draw.get_path())+" intrusions="+str(intrusions))
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		for offset in range(0,indices.size(),3):
			var a:=indices[offset];var b:=indices[offset+1];var c:=indices[offset+2]
			if absf((uv[b]-uv[a]).cross(uv[c]-uv[a]))<=1e-12:
				bad.append({"path":str(draw.get_path()),"points":[vertices[a],vertices[b],vertices[c]],"uv":[uv[a],uv[b],uv[c]],"normals":[normals[a],normals[b],normals[c]],"tangents":[tangents.slice(a*4,a*4+4),tangents.slice(b*4,b*4+4),tangents.slice(c*4,c*4+4)]})
	var source:=preload("res://assets/props/bath_shower.glb").instantiate()
	var native:=0
	for draw: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		metric._check_cap_mapping(draw.mesh,true);native+=1
	source.free()
	metric.check(native==17,"all seventeen native shower material stocks pass imported UV and basis checks")
	metric.check(count==57,"all nineteen wet rooms contain all three fixed finish batches")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var stock:=preload("res://scripts/building/orison_v2_millwork.gd").collect_wall_stock(shell)
	var fitting:=preload("res://scripts/building/orison_v2_domestic_fittings.gd").new()
	var mounts: Array=[]
	for record: Dictionary in shell.layout.anchors:
		if not str(record.id).ends_with("_SHOWER_01"):continue
		var anchor:=shell.get_node(str(record.id)) as Node3D
		var install: Transform3D=anchor.global_transform*Transform3D(Basis.IDENTITY,preload("res://scripts/building/orison_v2_shower_placement.gd").local_offset(str(record.id)))
		var relative: Transform3D=install.affine_inverse()*shell.global_transform
		var center: float=fitting._shower_foot_depth(relative,stock,0.0)
		var left: float=fitting._shower_foot_depth(relative,stock,-.34)
		print("MOUNT WALL DATUM: ",record.id," center=",center," left=",left)
		if not is_finite(left) or not is_finite(fitting._shower_foot_depth(relative,stock,.34)):
			var feasible: Array=[]
			for millimetres in range(0,301):
				var candidate: Transform3D=anchor.global_transform*Transform3D(Basis.IDENTITY,Vector3(float(millimetres)/1000.0,0,0))
				var pose: Transform3D=candidate.affine_inverse()*shell.global_transform
				var center_depth: float=fitting._shower_foot_depth(pose,stock,0.0)
				var left_depth: float=fitting._shower_foot_depth(pose,stock,-.34)
				var right_depth: float=fitting._shower_foot_depth(pose,stock,.34)
				if is_finite(center_depth) and is_finite(left_depth) and is_finite(right_depth) and absf(left_depth-center_depth)<.002 and absf(right_depth-center_depth)<.002:feasible.append(millimetres)
			print("FULL PAD FEASIBLE OFFSET mm: ",record.id," ",feasible)

		for x: float in [-.34,.34]:
			var full_pad: float=fitting._shower_foot_depth(relative,stock,x)
			metric.check(is_finite(full_pad) and absf(full_pad-center)<.002,"complete mounting plate footprint has wall backing: "+str(record.id)+" x="+str(x)+" depth="+str(full_pad))
		for point: Vector2 in [Vector2(-.34,2.02),Vector2(.34,2.02),Vector2(-.34,2.19),Vector2(.34,2.19),Vector2(-.095,.98),Vector2(.095,.98),Vector2(0,1.18),Vector2(0,1.65)]:
			var depth:=center
			var ray:=PhysicsRayQueryParameters3D.create(install*Vector3(point.x,point.y,depth-.03),install*Vector3(point.x,point.y,depth+.02),1)
			var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
			var error:=INF if hit.is_empty() else absf((install.affine_inverse()*hit.position).z-depth)
			mounts.append({"id":record.id,"point":point,"depth":depth,"error":error,"left_depth":left})
			metric.check(error<.002,"native foot has independent actual shell backing: "+str(record.id)+" "+str(point)+" error="+str(error))
	metric.check(mounts.size()==144,"all eight supporting contacts on all eighteen showers are surveyed")
	var output:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("stock.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Static original shell finish stock, no interactions/runtime qualification","draws":count,"mounts":mounts,"bad":bad,"failures":metric.failures},"\t"))
	print("BATH FINISH STOCK: ",count," draws; ",metric.failures.size()," failures")
	var failed: bool=not metric.failures.is_empty()
	metric.free();shell.free();get_tree().quit(1 if failed else 0)
