extends RefCounted
## Local optical repair on unchanged source faces; keep the original physical owner.
static func apply(cell: Node3D, layout: Dictionary) -> bool:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bar_ceiling_finish.json"))
	if data is not Dictionary or int(data.get("schema_version",0))!=1 or cell.has_meta("bar_ceiling_finish"):return false
	var rows: Dictionary={}
	for floor: Dictionary in layout.floors:
		if str(floor.id)!=str(data.source_floor):continue
		for row: Dictionary in floor.furniture:rows[str(row.id)]=row
	var tolerance:=float(data.tolerance)
	if not is_finite(tolerance) or tolerance<=0. or tolerance>.00003:return false
	var counts: Dictionary={};var expected:=0;var boxes: Array[Dictionary]=[]
	for box: Dictionary in data.replace:
		if not rows.has(str(box.id)) or counts.has(str(box.id)):return false
		var row: Dictionary=rows[box.id];var rect: Array=row.rect
		if str(row.mat)!=str(box.key) or _v(box.low).distance_to(Vector3(rect[0],row.z0,-rect[3]))>tolerance or _v(box.high).distance_to(Vector3(rect[2],float(row.z0)+float(row.h),-rect[1]))>tolerance:return false
		counts[str(box.id)]=0;boxes.append(box);expected+=int(box.expected_triangles)
	var owner: MeshInstance3D
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		if str(draw.name).trim_suffix("-col")==str(data.owner_name).trim_suffix("-col"):
			if owner!=null:return false
			owner=draw
	if owner==null or not owner.transform.is_equal_approx(Transform3D.IDENTITY):return false
	var collisions:=owner.find_children("*","CollisionShape3D",true,false)
	if collisions.size()!=1 or (collisions[0] as CollisionShape3D).shape is not ConcavePolygonShape3D:return false
	var retained:=preload("res://scripts/building/orison_v2_shop_seating.gd")._without_boxes(owner,boxes,tolerance,counts)
	if retained==null:return false
	for box: Dictionary in boxes:
		if int(counts[str(box.id)])!=int(box.expected_triangles):return false
	var packed:=ResourceLoader.load(str(data.asset),"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed==null:return false
	var model:=packed.instantiate() as Node3D
	if model==null:return false
	var draws:=model.find_children("*","MeshInstance3D",true,false)
	var part: Dictionary=data.part;var key:=str(part.key);var tile:=float(part.tile)
	if draws.size()!=1 or not MatLib.SETS.has(key) or not is_finite(tile) or tile<=0. or absf(float(MatLib.SETS[key][3])-tile)>.000001:model.free();return false
	var source:=draws[0] as MeshInstance3D
	if str(source.name)!=str(part.name) or source.mesh.get_surface_count()!=1 or not source.transform.is_equal_approx(Transform3D.IDENTITY) or source.mesh.get_faces().size()!=expected*3:model.free();return false
	var before:=_face_counts(owner.mesh.get_faces());var after:=_face_counts(retained.get_faces());var added:=_face_counts(source.mesh.get_faces())
	for signature: String in added:after[signature]=int(after.get(signature,0))+int(added[signature])
	if before!=after:model.free();return false
	var surface:=retained.get_surface_count();retained.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.mesh.surface_get_arrays(0))
	var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
	material.resource_name="M_"+key;material.uv1_triplanar=false;material.uv1_scale=Vector3.ONE/tile;retained.surface_set_material(surface,material)
	var shape:=ConcavePolygonShape3D.new();shape.set_faces(retained.get_faces())
	var original:=owner.mesh;owner.mesh=retained;(collisions[0] as CollisionShape3D).shape=shape
	cell.set_meta("bar_ceiling_finish",{"owner":owner,"original_mesh":original,"removed_triangles":counts,"finish_surface":surface})
	model.free();return true

static func _face_counts(faces: PackedVector3Array) -> Dictionary:
	var result: Dictionary={}
	for i in range(0,faces.size(),3):
		var points: Array[String]=[]
		for j in 3:
			var at: Vector3=faces[i+j]*100000.;points.append("%d,%d,%d"%[roundi(at.x),roundi(at.y),roundi(at.z)])
		points.sort();var n: Vector3=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
		var signature: String="|".join(points)+";%d,%d,%d"%[roundi(n.x),roundi(n.y),roundi(n.z)]
		result[signature]=int(result.get(signature,0))+1
	return result

static func _v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
