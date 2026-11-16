extends RefCounted
## Actual visible skin geometry, not an invented character capsule.
var errors: Array[String] = []
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
	if foot<0:return {}
	var lowest := INF
	var answer := {}
	for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if not draw.is_visible_in_tree() or draw.mesh==null or draw.skin==null:continue
		var joint_ids: Array[int] = []
		var rest: Array[Transform3D] = []
		for bind: int in draw.skin.get_bind_count():
			var name: StringName=draw.skin.get_bind_name(bind)
			var joint: int=body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(bind)
			if joint<0:return {}
			joint_ids.append(joint);rest.append(body.get_bone_global_rest(joint)*draw.skin.get_bind_pose(bind))
		for surface: int in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface)
			var vs: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array=arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES]!=null else PackedInt32Array()
			var ws: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS]!=null else PackedFloat32Array()
			if vs.is_empty() or bs.is_empty():continue
			var count := int(bs.size()/vs.size())
			for vertex: int in vs.size():
				var weight := 0.0;var p:=Vector3.ZERO
				for slot: int in count:
					var k:=vertex*count+slot
					if bs[k]<0 or bs[k]>=joint_ids.size():return {}
					if joint_ids[bs[k]]==foot:weight+=ws[k]
					p+=(rest[bs[k]]*vs[vertex])*ws[k]
				if weight<.9999 or p.y>=lowest:continue
				lowest=p.y
				answer={"mesh":str(draw.name),"surface":surface,"vertex":vertex,"fully_foot_weighted":weight,"bone_local_point":body.get_bone_global_rest(foot).affine_inverse()*p,"rest_point":p}
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
