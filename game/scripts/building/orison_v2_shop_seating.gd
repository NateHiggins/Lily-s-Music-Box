extends RefCounted
## Native furniture replaces only identified source box boundaries. The
## imported shop, its other triangles and its physical actors remain owners.
static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/shop_seating.json","ShopSeating","F01_retail_seating_","seating_part")

static func mount_laundry(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/laundry_fittings.json","LaundryFittings","F01_retail_laundry_","laundry_part")

static func mount_laundry_apparatus(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/laundry_apparatus.json","LaundryApparatus","F01_retail_laundry_apparatus_","laundry_apparatus_part")

static func mount_locksmith(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/locksmith_fittings.json","LocksmithFittings","F01_retail_locksmith_","locksmith_part")

static func mount_cobbler(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/cobbler_fittings.json","CobblerFittings","F01_retail_cobbler_","cobbler_part")

static func mount_news(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/news_fittings.json","NewsFittings","F01_retail_news_","news_part")

static func mount_hardware_drawers(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_drawers.json","HardwareDrawers","F01_retail_hardware_drawers_","hardware_drawer_part")

static func mount_hardware_apparatus(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_apparatus.json","HardwareApparatus","F01_retail_hardware_apparatus_","hardware_apparatus_part")

static func mount_hardware_stock(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_stock.json","HardwareStock","F01_retail_hardware_stock_","hardware_stock_part")

static func mount_hardware_tools(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/hardware_tools.json","HardwareTools","F01_retail_hardware_tools_","hardware_tools_part")

static func mount_photo_cameras(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/photo_cameras.json","PhotoCameras","F01_retail_photo_cameras_","photo_cameras_part")

static func mount_bar_pool(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/bar_pool.json","BarPool","F01_retail_bar_pool_","bar_pool_part","shop_bar")

static func mount_bar_stage(cell: Node3D, layout: Dictionary) -> bool:
	return mount_records(cell,layout,"res://data/orison_v2/bar_stage.json","BarStage","F01_retail_bar_stage_","bar_stage_part","shop_bar")

static func mount_records(cell: Node3D, layout: Dictionary, data_path: String, model_name: String, draw_prefix: String, part_meta: String, cell_identity: String = "") -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if data is not Dictionary or int(data.get("schema_version",0))!=1:return false
	var matches: Array=[]
	for row: Dictionary in data.cells:
		if str(row.id)==(str(cell.name) if cell_identity.is_empty() else cell_identity):matches.append(row)
	if matches.is_empty():return true
	if matches.size()!=1 or cell.has_node(model_name):return false
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
			if str(draw.name).trim_suffix("-col").ends_with("_"+str(box.key)):boxes.append(box)
		if boxes.is_empty():continue
		# Shipping cells quantize positions to their imported AABB. Account for
		# one encoded step while still requiring one outward source boundary.
		var extent:=draw.mesh.get_aabb().size
		var encoded_tolerance:=tolerance+maxf(maxf(extent.x,extent.y),extent.z)/65535.
		var before:=0
		for box: Dictionary in boxes:before+=int(counts[str(box.id)])
		var result:=_without_boxes(draw,boxes,encoded_tolerance,counts)
		if result==null:return false
		var after:=0
		for box: Dictionary in boxes:after+=int(counts[str(box.id)])
		# A source can contain colliding and decorative draws with the same
		# material key. Only the draw that owns a removed boundary is fitted.
		if before==after:continue
		replacements[draw]=result;originals[draw]=draw.mesh
		for box: Dictionary in boxes:
			if draw.mesh.get_surface_count()!=1:return false
			var original:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			if original==null or original.roughness_texture==null or original.normal_texture==null:return false
			# Source drawn glass deliberately carries literal color/alpha and
			# two maps. Preserve that authored optical owner without adding albedo.
			if original.albedo_texture==null and (str(box.key)!="glassish" or original.transparency not in [BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] or original.albedo_color.a<=0. or original.albedo_color.a>=1.):return false
			materials[str(box.key)]=original
	for box: Dictionary in record.replace:
		if counts[str(box.id)]!=int(box.expected_triangles):
			push_error("Shop seating boundary mismatch: "+str(box.id)+" count="+str(counts[str(box.id)]));return false
	# No PackedScene or mesh cache is retained across the Passage's retirement.
	var packed:=ResourceLoader.load(str(data.asset),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed==null:return false
	var model:=packed.instantiate() as Node3D
	if model==null:return false
	model.name=model_name
	var parts: Dictionary={}
	for part: Dictionary in record.parts:
		if parts.has(str(part.name)) or float(part.tile)<=0.:model.free();return false
		if not materials.has(str(part.key)) and (not part.has("catalog_key") or not MatLib.SETS.has(str(part.catalog_key))):model.free();return false
		if part.has("tint"):
			if part.tint is not Array or part.tint.size()!=4:model.free();return false
			for component: Variant in part.tint:
				if (component is not float and component is not int) or not is_finite(float(component)) or float(component)<0. or float(component)>1.:model.free();return false
			if float(part.tint[3])!=1.:model.free();return false
		if part.has("plain_alpha") and (part.plain_alpha is not bool or str(part.key)!="glassish" or part.has("catalog_key")):model.free();return false
		parts[str(part.name)]=part
	var mounted: Dictionary={};var local_materials: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not parts.has(str(draw.name)):draw.free();continue
		var part: Dictionary=parts[str(draw.name)];var key:=str(part.key)
		var material_slot:=key+"|"+str(part.get("catalog_key",""))+"|"+str(part.tile)+"|"+JSON.stringify(part.get("tint",[]))+"|"+str(part.get("plain_alpha",false))
		if not local_materials.has(material_slot):
			var mat: StandardMaterial3D
			if part.has("catalog_key"):
				var catalog_key:=str(part.catalog_key)
				if not MatLib.SETS.has(catalog_key):model.free();return false
				if absf(float(MatLib.SETS[catalog_key][3])-float(part.tile))>.000001:model.free();return false
				mat=MatLib.get_mat(catalog_key).duplicate() as StandardMaterial3D
			else:mat=materials[key].duplicate() as StandardMaterial3D
			if part.has("tint"):
				var tint: Array=part.tint
				mat.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
			if part.get("plain_alpha",false):mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.uv1_triplanar=false;mat.uv1_scale=Vector3.ONE/float(part.tile)
			local_materials[material_slot]=mat
		draw.mesh.surface_set_material(0,local_materials[material_slot])
		# Name retains SurfacePass's retail class and therefore its state owner.
		draw.set_meta(part_meta,str(draw.name));draw.set_meta("material_key",key)
		draw.name=draw_prefix+str(draw.name)
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
