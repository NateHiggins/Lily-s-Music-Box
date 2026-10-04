extends RefCounted
## Native furniture replaces only identified source box boundaries. The
## imported shop, its other triangles and its physical actors remain owners.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/shop_seating.json"))
	if data is not Dictionary or int(data.get("schema_version",0))!=1:return false
	var matches: Array=[]
	for row: Dictionary in data.cells:
		if str(row.id)==str(cell.name):matches.append(row)
	if matches.is_empty():return true
	if matches.size()!=1 or cell.has_node("ShopSeating"):return false
	var record: Dictionary=matches[0]
	var source_rows: Dictionary={}
	for floor: Dictionary in layout.floors:
		if floor.id!="F01":continue
		for row: Dictionary in floor.furniture:source_rows[str(row.id)]=row
	var tolerance:=float(data.tolerance)
	var counts: Dictionary={};var originals: Dictionary={};var materials: Dictionary={}
	for box: Dictionary in record.replace:
		if not source_rows.has(str(box.id)):return false
		var source: Dictionary=source_rows[box.id];var r: Array=source.rect
		if str(source.mat)!=str(box.key) or _v(box.low).distance_to(Vector3(r[0],source.z0,-r[3]))>tolerance or _v(box.high).distance_to(Vector3(r[2],float(source.z0)+float(source.h),-r[1]))>tolerance:return false
		counts[str(box.id)]=0
	var replacements: Dictionary={}
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		var boxes: Array[Dictionary]=[]
		for box: Dictionary in record.replace:
			if str(draw.name).ends_with("_"+str(box.key)):boxes.append(box)
		if boxes.is_empty():continue
		# Shipping cells quantize positions to their imported AABB. Account for
		# one encoded step while still requiring one outward source boundary.
		var extent:=draw.mesh.get_aabb().size
		var encoded_tolerance:=tolerance+maxf(maxf(extent.x,extent.y),extent.z)/65535.
		var result:=_without_boxes(draw,boxes,encoded_tolerance,counts)
		if result==null:return false
		replacements[draw]=result;originals[draw]=draw.mesh
		for box: Dictionary in boxes:
			if draw.mesh.get_surface_count()!=1:return false
			var original:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			if original==null or original.albedo_texture==null or original.roughness_texture==null or original.normal_texture==null:return false
			materials[str(box.key)]=original
	for box: Dictionary in record.replace:
		if counts[str(box.id)]!=int(box.expected_triangles):
			push_error("Shop seating boundary mismatch: "+str(box.id)+" count="+str(counts[str(box.id)]));return false
	# No PackedScene or mesh cache is retained across the Passage's retirement.
	var packed:=ResourceLoader.load(str(data.asset),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed==null:return false
	var model:=packed.instantiate() as Node3D
	if model==null:return false
	model.name="ShopSeating"
	var parts: Dictionary={}
	for part: Dictionary in record.parts:
		if parts.has(str(part.name)) or not materials.has(str(part.key)) or float(part.tile)<=0.:model.free();return false
		parts[str(part.name)]=part
	var mounted: Dictionary={};var local_materials: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not parts.has(str(draw.name)):draw.free();continue
		var part: Dictionary=parts[str(draw.name)];var key:=str(part.key)
		if not local_materials.has(key):
			var mat:=materials[key].duplicate() as StandardMaterial3D
			mat.uv1_triplanar=false;mat.uv1_scale=Vector3.ONE/float(part.tile)
			local_materials[key]=mat
		draw.mesh.surface_set_material(0,local_materials[key])
		# Name retains SurfacePass's retail class and therefore its state owner.
		draw.set_meta("seating_part",str(draw.name));draw.set_meta("material_key",key)
		draw.name="F01_retail_seating_"+str(draw.name)
		draw.create_trimesh_collision();mounted[str(part.name)]=true
	if mounted.size()!=parts.size():model.free();return false
	# Validate collision ownership before altering any imported draw.
	for draw: MeshInstance3D in replacements:
		var collisions:=draw.find_children("*","CollisionShape3D",true,false)
		if collisions.size()!=1 or (collisions[0] as CollisionShape3D).shape is not ConcavePolygonShape3D:model.free();return false
	for draw: MeshInstance3D in replacements:
		draw.mesh=replacements[draw]
		var collision: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
		if draw.mesh.get_surface_count()==0:
			draw.hide();collision.disabled=true
		else:
			var shape:=ConcavePolygonShape3D.new();shape.set_faces(draw.mesh.get_faces());collision.shape=shape
	model.set_meta("original_meshes",originals);model.set_meta("removed_triangles",counts)
	cell.add_child(model)
	return true

static func _without_boxes(draw: MeshInstance3D, boxes: Array[Dictionary], tolerance: float, counts: Dictionary) -> ArrayMesh:
	var result:=ArrayMesh.new()
	var source_surfaces: Array=draw.mesh.get("_surfaces")
	var selected_surfaces: Array=[]
	for surface in draw.mesh.get_surface_count():
		var arrays:=draw.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		if normals.size()!=vertices.size():return null
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size():indices.append(index)
		var retained:=PackedInt32Array()
		for start in range(0,indices.size(),3):
			var p: Array[Vector3]=[];var n:=Vector3.ZERO
			for offset in 3:
				var index:=indices[start+offset];p.append(draw.transform*vertices[index]);n+=draw.basis.inverse().transposed()*normals[index]
			if n.length_squared()<.5:return null
			n=n.normalized();var match_id:=""
			for box: Dictionary in boxes:
				var low:=_v(box.low);var high:=_v(box.high);var within:=true
				for point: Vector3 in p:
					for axis in 3:
						if point[axis]<low[axis]-tolerance or point[axis]>high[axis]+tolerance:within=false
				if not within:continue
				var axis:=n.abs().max_axis_index()
				if absf(n[axis])<.999:continue
				var plane:=high[axis] if n[axis]>0. else low[axis]
				var boundary:=true
				for point: Vector3 in p:
					if absf(point[axis]-plane)>tolerance:boundary=false
				if not boundary:continue
				if not match_id.is_empty():return null
				match_id=str(box.id)
			if match_id.is_empty():
				for offset in 3:retained.append(indices[start+offset])
			else:counts[match_id]+=1
		if retained.is_empty():continue
		# Array reconstruction would quantize decoded normal/tangent values
		# again. Copy the serialized buffers and decoding metadata verbatim;
		# replace only their independently encoded triangle index selection.
		var packed: Dictionary=source_surfaces[surface].duplicate(true)
		var width: int=packed.index_data.size()/int(packed.index_count)
		if width!=2 and width!=4:return null
		var bytes:=PackedByteArray();bytes.resize(retained.size()*width)
		for index in retained.size():
			if width==2:bytes.encode_u16(index*width,retained[index])
			else:bytes.encode_u32(index*width,retained[index])
		packed.index_data=bytes;packed.index_count=retained.size()
		# Old generated LOD indices include the replaced boxes. The retained
		# surface therefore keeps its exact full-resolution triangles.
		packed.lods={};selected_surfaces.append(packed)
	if not selected_surfaces.is_empty():result.set("_surfaces",selected_surfaces)
	return result

static func _v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
