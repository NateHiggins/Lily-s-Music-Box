extends RefCounted
## Actual visible skin geometry, not an invented character capsule.
var errors: Array[String] = []
var outsole_hulls:Dictionary={}
func prepare_outsole_hulls() -> bool:
	var decoded:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/harukiya_outsole_hulls.json"))
	if decoded is not Dictionary:return false
	outsole_hulls=decoded
	for path:String in outsole_hulls.sources:
		var row:Dictionary=outsole_hulls.sources[path]
		var actual:String=FileAccess.get_sha256(path) if str(row.kind)=="raw" else FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
		if actual!=str(row.sha256):return false
	return true
func _skin(draw: MeshInstance3D, body: Skeleton3D, vertices: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	if draw.skin == null:
		for v: Vector3 in vertices: result.append(draw.global_transform*v)
		return result
	if vertices.is_empty() or bones.is_empty() or bones.size() != weights.size() or bones.size()%vertices.size()!=0:
		errors.append("incomplete weighted source: "+str(draw.get_path())); return result
	var joints: Array[int] = []
	var binds: Array[Transform3D] = []
	for i: int in draw.skin.get_bind_count():
		var name: StringName = draw.skin.get_bind_name(i)
		var bone: int = body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(i)
		if bone < 0: errors.append("missing skin bone"); return result
		joints.append(bone); binds.append(body.get_bone_global_pose(bone)*draw.skin.get_bind_pose(i))
	var slots := bones.size()/vertices.size()
	for i: int in vertices.size():
		var p := Vector3.ZERO
		var total := 0.0
		for j: int in int(slots):
			var k := i*int(slots)+j
			if weights[k] <= 0.: continue
			if bones[k] < 0 or bones[k] >= binds.size(): errors.append("invalid skin slot"); return PackedVector3Array()
			p += (binds[bones[k]]*vertices[i])*weights[k]; total += weights[k]
		if absf(total-1.)>.001 or not p.is_finite(): errors.append("invalid skin weights/position"); return PackedVector3Array()
		result.append(body.global_transform*p)
	return result
func snapshot(actor: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var body: Skeleton3D = actor.skeleton
	for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if not draw.is_visible_in_tree() or draw.mesh == null: continue
		for surface: int in draw.mesh.get_surface_count():
			var arrays: Array = draw.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES]!=null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS]!=null else PackedFloat32Array()
			var posed: PackedVector3Array = _skin(draw,body,vertices,bones,weights)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for i: int in posed.size(): indices.append(i)
			if posed.size()!=vertices.size() or indices.size()%3!=0: errors.append("incomplete evaluated surface"); continue
			result.append({"mesh":str(draw.get_path()),"surface":surface,"source_resource":draw.mesh.resource_path,"vertices":posed,"indices":indices})
	return result
func sole_datum(actor: Node3D, side: String) -> Dictionary:
	var body: Skeleton3D = actor.skeleton
	var foot: int = body.find_bone(side+"Foot")
	var toe: int = body.find_bone(side+"ToeBase")
	if foot<0 or toe<0:return {}
	var foot_rest:=body.get_bone_global_rest(foot)
	var toe_rest:=body.get_bone_global_rest(toe)
	var forward:Vector3=(toe_rest.origin-foot_rest.origin).normalized()
	var forefoot_begin:float=toe_rest.origin.distance_to(foot_rest.origin)*.75
	var lowest:=INF;var nearest_to_ball:=INF
	var answer:Dictionary={}
	var hull:Dictionary=outsole_hulls.sides[side] if str(actor.person_id)=="adela_voss" else {}
	var closest_hull:=INF
	for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if not draw.is_visible_in_tree() or draw.mesh==null or draw.skin==null:continue
		var joint_ids:Array[int]=[];var rest:Array[Transform3D]=[]
		for bind:int in draw.skin.get_bind_count():
			var name:StringName=draw.skin.get_bind_name(bind)
			var joint:int=body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(bind)
			if joint<0:return {}
			joint_ids.append(joint);rest.append(body.get_bone_global_rest(joint)*draw.skin.get_bind_pose(bind))
		for surface:int in draw.mesh.get_surface_count():
			var arrays:Array=draw.mesh.surface_get_arrays(surface)
			var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bs:PackedInt32Array=arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES]!=null else PackedInt32Array()
			var ws:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS]!=null else PackedFloat32Array()
			if vs.is_empty() or bs.is_empty():continue
			var count:=int(bs.size()/vs.size())
			for vertex:int in vs.size():
				var weight:=0.;var point:=Vector3.ZERO
				for slot:int in count:
					var k:=vertex*count+slot
					if bs[k]<0 or bs[k]>=joint_ids.size():return {}
					if joint_ids[bs[k]] in [foot,toe]:weight+=ws[k]
					point+=(rest[bs[k]]*vs[vertex])*ws[k]
				if weight<.9999:continue
				if not hull.is_empty():
					var expected:=Vector3(float(hull.rest_point[0]),float(hull.rest_point[1]),float(hull.rest_point[2]))
					var distance:float=point.distance_to(expected)
					if distance>minf(.00001,closest_hull):continue
					closest_hull=distance
					answer={"mesh":str(draw.name),"surface":surface,"vertex":vertex,"fully_foot_chain_weighted":weight,
						"contact_region":"measured supporting-hull toe, imported point independently matched",
						"bone_local_point":foot_rest.affine_inverse()*point,"rest_point":point,
						"pitch_axis":hull.pitch_axis,"pitch_rad":hull.pitch_rad,"source_vertex_id":hull.source_vertex_id,"source_match_error_m":distance}
					continue
				if (point-foot_rest.origin).dot(forward)<forefoot_begin:continue
				var distance:float=point.distance_squared_to(toe_rest.origin)
				if point.y>lowest+.00001 or (absf(point.y-lowest)<=.00001 and distance>=nearest_to_ball):continue
				lowest=point.y;nearest_to_ball=distance
				answer={"mesh":str(draw.name),"surface":surface,"vertex":vertex,
					"fully_foot_chain_weighted":weight,"contact_region":"lowest forefoot sole, nearest ball joint; Foot and ToeBase chain",
					"bone_local_point":foot_rest.affine_inverse()*point,"rest_point":point}
	return answer
func edge_witnesses(rows: Array[Dictionary], space: PhysicsDirectSpaceState3D, max_edges: int, exclude: Array[RID] = []) -> Dictionary:
	var hits: Array[Dictionary]=[]
	var tested:=0;var total:=0
	var ordered:Array[Dictionary]=rows.duplicate()
	ordered.sort_custom(func(a,b):return _working_priority(a)<_working_priority(b))
	for row: Dictionary in ordered:
		var vs: PackedVector3Array=row.vertices;var ids: PackedInt32Array=row.indices;var seen:Dictionary={}
		for i in range(0,ids.size(),3):
			for pair: Vector2i in [Vector2i(ids[i],ids[i+1]),Vector2i(ids[i+1],ids[i+2]),Vector2i(ids[i+2],ids[i])]:
				var low:=mini(pair.x,pair.y);var high:=maxi(pair.x,pair.y);var key:=str(low)+":"+str(high)
				if seen.has(key):continue
				seen[key]=true;total+=1
				if tested>=max_edges:continue
				var a:Vector3=vs[low];var b:Vector3=vs[high]
				if a.distance_to(b)<.000001:continue
				tested+=1
				var query:=PhysicsRayQueryParameters3D.create(a,b,1)
				query.exclude=exclude
				var hit:=space.intersect_ray(query)
				if not hit.is_empty():
					hits.append({"mesh":row.mesh,"surface":row.surface,"edge":[low,high],"from":a,"to":b,"native_collider":str(hit.collider.get_path()),"point":hit.position,"normal":hit.normal})
	return {"tested_edges":tested,"total_edges":total,"truncated":tested<total,"exact_native_edge_intersections":hits,"coverage":"ACTUAL EVALUATED SKIN EDGES ONLY. Does not rule out triangle-interior penetration, enclosed objects, self/cloth collisions or unsampled continuous motion. Hits are unclassified intended contact/penetration witnesses, never blanket exemptions."}

func measured_point(actor: Node3D, witness: Dictionary) -> Vector3:
	for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if str(draw.name)!=str(witness.get("mesh","")) or draw.mesh==null:continue
		var surface:=int(witness.get("surface",-1));var index:=int(witness.get("vertex",-1))
		if surface<0 or surface>=draw.mesh.get_surface_count():return Vector3.INF
		var data:Array=draw.mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX]
		var bones:PackedInt32Array=data[Mesh.ARRAY_BONES] if data[Mesh.ARRAY_BONES]!=null else PackedInt32Array()
		var weights:PackedFloat32Array=data[Mesh.ARRAY_WEIGHTS] if data[Mesh.ARRAY_WEIGHTS]!=null else PackedFloat32Array()
		var posed:PackedVector3Array=_skin(draw,actor.skeleton,vertices,bones,weights)
		return posed[index] if index>=0 and index<posed.size() else Vector3.INF
	return Vector3.INF

func _working_priority(row:Dictionary) -> int:
	var name:=str(row.mesh).to_lower()
	if name.contains("hand") or name.contains("feet"):return 0
	if name.contains("body"):return 1
	if name.contains("top") or name.contains("skirt"):return 2
	return 3
