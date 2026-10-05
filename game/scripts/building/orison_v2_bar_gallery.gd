extends RefCounted
## Source-bound bar context for the building's single picture-placement law.
const DATA := "res://data/orison_v2/bar_gallery.json"

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var ctx:=context(layout)
	if data is not Dictionary or int(data.get("schema_version",0))!=1 or ctx.is_empty() or cell.has_node("BarGallery"):return false
	if data.pictures.size()!=22 or data.parts.size()!=4 or data.inspectors.size()!=3:return false
	var ids: Dictionary={}
	for picture: Dictionary in data.pictures:
		var id:=str(picture.id)
		if ids.has(id) or not ctx.rows.has(id) or ctx.rows[id]!=picture.source:return false
		if str(picture.source.mat)!="art":return false
		if picture.position.size()!=3 or str(picture.wall) not in ["north","west"]:return false
		for value: Variant in picture.position:
			if not is_finite(float(value)):return false
		ids[id]=picture
	var owners: Dictionary={};var originals: Dictionary={}
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		for key: String in ["art","wood_dark"]:
			if str(draw.name).trim_suffix("-col").ends_with("furniture_"+key):
				if owners.has(key) or not _source_partition_ok(draw,data.pictures,key):return false
				owners[key]=draw;originals[key]=draw.mesh
	if owners.size()!=2:return false
	var wood_shapes: Array=owners.wood_dark.find_children("*","CollisionShape3D",true,false)
	if wood_shapes.size()!=1 or not wood_shapes[0].shape is ConcavePolygonShape3D:return false
	if not owners.art.find_children("*","CollisionShape3D",true,false).is_empty():return false
	var packed:=ResourceLoader.load(str(data.asset),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed==null:return false
	var model:=packed.instantiate() as Node3D
	if model==null:return false
	model.name="BarGallery"
	var parts: Dictionary={};var materials: Dictionary={}
	for part: Dictionary in data.parts:
		var key:=str(part.key);var tile:=float(part.tile)
		if key not in ["art","wood_dark","paper","iron_blackened"] or parts.has(str(part.name)) or not is_finite(tile) or tile<=0.:model.free();return false
		var mat: StandardMaterial3D
		if key in owners:mat=owners[key].mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		else:
			if not MatLib.SETS.has(key):model.free();return false
			mat=MatLib.get_mat(key).duplicate() as StandardMaterial3D
		if mat==null or mat.albedo_texture==null:model.free();return false
		if key=="art" and tile!=1.:model.free();return false
		if key!="art" and (not MatLib.SETS.has(key) or absf(float(MatLib.SETS[key][3])-tile)>.000001):model.free();return false
		mat.uv1_triplanar=false;mat.uv1_scale=Vector3.ONE/tile
		materials[key]=mat;parts[str(part.name)]=part
	var mounted: Dictionary={}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not parts.has(str(draw.name)) or draw.mesh.get_surface_count()!=1:model.free();return false
		var part: Dictionary=parts[str(draw.name)];var key:=str(part.key)
		draw.mesh.surface_set_material(0,materials[key]);draw.set_meta("gallery_part",str(draw.name));draw.set_meta("material_key",key)
		draw.name="F01_retail_bar_gallery_"+str(draw.name)
		if bool(part.collision):draw.create_trimesh_collision()
		mounted[str(part.name)]=true
	if mounted.size()!=parts.size():model.free();return false
	# Shared reservations belong to this real bar room. Restore only on refusal;
	# never erase other residents' occupied bands to make a picture fit.
	var before:=WallArtLaw._reserved.duplicate(true)
	for picture: Dictionary in data.pictures:
		var r: Array=picture.source.rect;var north:=str(picture.wall)=="north"
		var half_width:=maxf(float(r[2])-float(r[0]),float(r[3])-float(r[1]))*.5
		var half_height:=float(picture.source.h)*.5;var position: Array=picture.position
		var height:=float(position[2])-float(ctx.datum)
		if height-half_height<float(ctx.lowest)-.000003 or height+half_height>float(ctx.highest)+.000003:WallArtLaw._reserved=before;model.free();return false
		var proxy: Dictionary=ctx.proxy.duplicate(true)
		proxy.walls=proxy.walls.filter(func(w):return str(w.id).ends_with("_n" if north else "_w"))
		var rroom: Array=ctx.room.rect
		var along:=(float(position[0])-float(rroom[0]))/(float(rroom[2])-float(rroom[0])) if north else (float(position[1])-float(rroom[1]))/(float(rroom[3])-float(rroom[1]))
		var pose:=WallArtLaw.legal_spot(proxy,ctx.room,str(picture.wall),along,height,Callable(),half_width,half_height)
		if not bool(pose.get("ok",false)) or Vector3(float(pose.x),float(pose.y),float(pose.height)+float(ctx.datum)).distance_to(_v(position))>.000003 or absf(angle_difference(float(pose.yaw),float(picture.yaw)))>.000003:WallArtLaw._reserved=before;model.free();return false
	for key: String in owners:
		owners[key].hide()
		for shape: CollisionShape3D in owners[key].find_children("*","CollisionShape3D",true,false):shape.disabled=true
	model.set_meta("original_owners",owners);model.set_meta("original_meshes",originals);model.set_meta("pictures",ids);model.set_meta("inspectors",data.inspectors)
	cell.add_child(model)
	return true

static func fit_inspections(cell: Node3D, actors: Node3D) -> bool:
	var model:=cell.get_node_or_null("BarGallery")
	if model==null:return false
	var pictures: Dictionary=model.get_meta("pictures");var seen: Dictionary={}
	for record: Dictionary in model.get_meta("inspectors"):
		var zone:=actors.get_node_or_null(str(record.zone)) as InspectableZone
		if zone==null or seen.has(str(record.zone)) or not pictures.has(str(record.picture)):return false
		var picture: Dictionary=pictures[str(record.picture)];var r: Array=picture.source.rect
		var width:=maxf(float(r[2])-float(r[0]),float(r[3])-float(r[1]))
		var normal:=Vector3.BACK if str(picture.wall)=="north" else Vector3.RIGHT
		zone.position=GameBoot.b2g(picture.position)+normal*.020;zone.rotation.y=float(picture.yaw)
		var shape: CollisionShape3D=zone.get_child(0);var box:=BoxShape3D.new();box.size=Vector3(width*.9,float(picture.source.h)*.9,.035);shape.shape=box
		zone.set_meta("gallery_picture",str(record.picture));seen[str(record.zone)]=true
	return seen.size()==3

static func _source_partition_ok(draw: MeshInstance3D, pictures: Array, key: String) -> bool:
	if draw.mesh==null or draw.mesh.get_surface_count()!=1 or not draw.transform.is_equal_approx(Transform3D.IDENTITY):return false
	var arrays:=draw.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index in vertices.size():indices.append(index)
	if indices.size()!=(88 if key=="art" else 264)*3:return false
	var counts: Dictionary={}
	for picture: Dictionary in pictures:counts[str(picture.id)]=0
	for start in range(0,indices.size(),3):
		var match_id:=""
		for picture: Dictionary in pictures:
			var row: Dictionary=picture.source;var r: Array=row.rect
			var low:=GameBoot.b2g([r[0],r[3],row.z0]);var high:=GameBoot.b2g([r[2],r[1],float(row.z0)+float(row.h)])
			var thin:=2 if float(r[2])-float(r[0])>float(r[3])-float(r[1]) else 0
			if key=="art":low[thin]-=.004;high[thin]+=.004
			var points: Array[Vector3]=[vertices[indices[start]],vertices[indices[start+1]],vertices[indices[start+2]]]
			var n: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized();var axis:=n.abs().max_axis_index()
			if absf(n[axis])<.999 or (key=="art" and axis!=thin):continue
			var plane:=low[axis] if absf(points[0][axis]-low[axis])<absf(points[0][axis]-high[axis]) else high[axis]
			var within:=true
			for point: Vector3 in points:
				if absf(point[axis]-plane)>.00003:within=false
				for dimension in 3:
					if point[dimension]<low[dimension]-.00003 or point[dimension]>high[dimension]+.00003:within=false
			if within:
				if not match_id.is_empty():return false
				match_id=str(picture.id)
		if match_id.is_empty():return false
		counts[match_id]+=1
	for id: String in counts:
		if int(counts[id])!=(4 if key=="art" else 12):return false
	return true

static func _v(value: Array) -> Vector3:return Vector3(value[0],value[1],value[2])
static func context(layout: Dictionary) -> Dictionary:
	var floors: Array=layout.get("floors",[]).filter(func(row):return str(row.id)=="F01")
	if floors.size()!=1:return {}
	var floor: Dictionary=floors[0];var rows: Dictionary={}
	for row: Dictionary in floor.furniture:rows[str(row.id)]=row
	for id: String in ["retail_bar_floor","retail_bar_wall_w","retail_bar_wall_n","retail_bar_wall_s","retail_bar_dado_w","retail_bar_wc_wall_e","retail_bar_wc_wall_n_w"]:
		if not rows.has(id):return {}
	var west: Dictionary=rows.retail_bar_wall_w;var north: Dictionary=rows.retail_bar_wall_n
	var south: Dictionary=rows.retail_bar_wall_s;var slab: Dictionary=rows.retail_bar_floor
	var datum:=float(slab.z0)+float(slab.h)
	var room:={"id":"RETAINED_BAR_GALLERY","kind":"bar","rect":[west.rect[2],south.rect[3],north.rect[2],north.rect[1]]}
	var wc_east: Dictionary=rows.retail_bar_wc_wall_e;var wc_north: Dictionary=rows.retail_bar_wc_wall_n_w
	var proxy:={"z":datum,"rooms":[room,{"id":"RETAINED_BAR_WC","kind":"bathroom","rect":[room.rect[0],room.rect[1],wc_east.rect[0],wc_north.rect[3]]}],"walls":[],"furniture":[]}
	for id: String in ["retail_bar_wall_w","retail_bar_wall_n"]:
		var r: Array=rows[id].rect;var horizontal:=id.ends_with("_n")
		proxy.walls.append({"id":id,"a":[r[0],(r[1]+r[3])*.5] if horizontal else [(r[0]+r[2])*.5,r[1]],
			"b":[r[2],(r[1]+r[3])*.5] if horizontal else [(r[0]+r[2])*.5,r[3]],
			"t":float(r[3])-float(r[1]) if horizontal else float(r[2])-float(r[0]),"openings":[]})
	for row: Dictionary in floor.furniture:
		var id:=str(row.id)
		if not id.begins_with("retail_bar") or id.begins_with("retail_bar_gal"):continue
		if "wall_" in id or "floor" in id or "ceil" in id:continue
		var copy:=row.duplicate(true)
		var source_z: float=float(row.get("z0",datum))
		if not row.has("z0") and row.has("at") and row.at.size()>2:source_z=float(row.at[2])
		copy.z0=source_z-datum
		proxy.furniture.append(copy)
	var dado: Dictionary=rows.retail_bar_dado_w
	return {"floor":floor,"rows":rows,"room":room,"proxy":proxy,"datum":datum,
		"lowest":float(dado.z0)+float(dado.h)-datum+.10,
		"highest":float(west.z0)+float(west.h)-datum-.10}
