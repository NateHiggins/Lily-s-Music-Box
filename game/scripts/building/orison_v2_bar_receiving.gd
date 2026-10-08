extends RefCounted
## Passive fitted cases; ArcadeRow retains all programme and input ownership.
const DATA := "res://data/orison_v2/bar_receiving.json"
const SourceTriangles := preload("res://scripts/building/orison_v2_bar_furniture.gd")

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or decoded.get("schema_version")!=1 or cell.has_node("BarReceiving"): return _reject()
	var data: Dictionary=decoded; var rows := {}
	for floor: Dictionary in layout.floors:
		if floor.id=="F01":
			for row: Dictionary in floor.furniture: rows[str(row.id)]=row
	if data.source_records.size()!=2: return _reject()
	for source: Dictionary in data.source_records:
		if rows.get(str(source.id))!=source or str(source.asm)!="arcade_cab" or not bool(source.exterior): return _reject()
		if int(source.variant) not in [0,1] or source.at.size()!=2 or not is_finite(float(source.yaw)) or not is_finite(float(source.z0)): return _reject()
	var floor: Dictionary=data.floor
	if rows.get(str(floor.id))!=floor or floor.rect.size()!=4 or float(floor.h)<=0.0 or not is_finite(float(floor.z0)) or str(floor.mat).is_empty(): return _reject()
	var originals := {}; var changes := {}; var hulls := {}; var removed := {}
	for record: Dictionary in data.retirement:
		var node := cell.get_node_or_null(str(record.name))
		if node==null or removed.has(node): return _reject()
		if str(record.kind)=="draw":
			var draw := node as MeshInstance3D
			if draw==null or draw.mesh.get_faces().size()>int(record.source_triangles)*3: return _reject()
			var next := SourceTriangles._without_source_triangles(draw,record)
			if next==null: return _reject()
			originals[draw]=draw.mesh; changes[draw]=next
		elif str(record.kind)=="hull":
			var body := node as StaticBody3D
			if body==null: return _reject()
			var shapes := body.find_children("*","CollisionShape3D",true,false)
			if shapes.size()!=1 or shapes[0].shape is not ConcavePolygonShape3D: return _reject()
			var shape := shapes[0] as CollisionShape3D; var faces := (shape.shape as ConcavePolygonShape3D).get_faces()
			if faces.size()!=int(record.source_triangles)*3: return _reject()
			var next := _trim_hull(faces,body.transform*shape.transform,record)
			if next==null: return _reject()
			hulls[shape]={"original":shape.shape,"next":next}
		else: return _reject()
		removed[node]=int(record.count)
	var packed := ResourceLoader.load(str(data.asset),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed==null: return _reject()
	var model := packed.instantiate() as Node3D; model.name="BarReceiving"
	var parts := {}; var materials := {}; var seen := {}
	for part: Dictionary in data.parts:
		if parts.has(str(part.name)) or not MatLib.SETS.has(str(part.catalog_key)) or float(part.tile)<=0.: model.free(); return _reject()
		if absf(float(MatLib.SETS[str(part.catalog_key)][3])-float(part.tile))>.000001 or not rows.has(str(part.assembly)): model.free(); return _reject()
		parts[str(part.name)]=part
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var name := str(draw.name)
		if not parts.has(name) or seen.has(name) or draw.mesh.get_surface_count()!=1: model.free(); return _reject()
		var part: Dictionary=parts[name]; var key := str(part.key)
		if draw.mesh.get_faces().size()!=int(part.triangles)*3: model.free(); return _reject()
		if not materials.has(key):
			var mat := MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
			mat.uv1_triplanar=false; mat.uv1_scale=Vector3.ONE/float(part.tile)
			mat.normal_scale=float(part.normal); mat.roughness=float(part.roughness)
			if part.has("metallic"): mat.metallic=float(part.metallic)
			var tint: Array=part.tint; mat.albedo_color=Color(tint[0],tint[1],tint[2],tint[3]); materials[key]=mat
		draw.mesh.surface_set_material(0,materials[key]); draw.set_meta("material_key",str(part.catalog_key))
		draw.set_meta("bar_receiving_part",name); draw.set_meta("bar_receiving_pigment",float(part.pigment))
		draw.name="F01_retail_bar_native_receiver_"+name
		draw.create_trimesh_collision(); seen[name]=true
	if seen.size()!=parts.size(): model.free(); return _reject()
	for draw: MeshInstance3D in changes:
		draw.mesh=changes[draw]
		if draw.mesh.get_surface_count()==0: draw.hide()
	for shape: CollisionShape3D in hulls: shape.shape=hulls[shape].next
	model.set_meta("original_meshes",originals); model.set_meta("original_hulls",hulls); model.set_meta("removed_triangles",removed)
	cell.add_child(model)
	return true

static func calibrate(cell: Node3D) -> void:
	var model := cell.get_node_or_null("BarReceiving")
	if model==null: return
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var mat := draw.get_surface_override_material(0) as ShaderMaterial
		if mat!=null: mat.set_shader_parameter("pigment_variation",float(draw.get_meta("bar_receiving_pigment")))

static func _reject() -> bool:
	push_error("Native bar receiving rejected: "+str(get_stack()))
	return false

static func _trim_hull(faces: PackedVector3Array, pose: Transform3D, record: Dictionary) -> ConcavePolygonShape3D:
	# Copy the original physics floats directly. A GPU ArrayMesh round trip
	# can quantize widely separated legacy hull coordinates.
	var kept := PackedVector3Array(); var used := {}
	var expected: Array=record.triangles
	var centers: Array[Vector3]=[]
	for triangle: Array in expected:
		centers.append((SourceTriangles._v(triangle[0])+SourceTriangles._v(triangle[1])+SourceTriangles._v(triangle[2]))/3.)
	for start in range(0,faces.size(),3):
		var points: Array[Vector3]=[pose*faces[start],pose*faces[start+1],pose*faces[start+2]]
		var center := (points[0]+points[1]+points[2])/3.; var found := -1
		for i in expected.size():
			if center.distance_to(centers[i])>.001: continue
			if SourceTriangles._same_triangle(points,expected[i],.0005):
				if found!=-1 or used.has(i): return null
				found=i
		if found==-1:
			for i in 3: kept.append(faces[start+i])
		else: used[found]=true
	if used.size()!=int(record.count) or expected.size()!=int(record.count): return null
	var result := ConcavePolygonShape3D.new(); result.set_faces(kept)
	return result
