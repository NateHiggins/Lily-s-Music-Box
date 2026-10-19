extends RefCounted
## Conservative swept shell cells derived from the actual imported skin.
## Keeps the bore open. Covers linear travel of the skinned vertices between
## endpoint poses, not arbitrary rigid rotation arcs or cloth self-contact.
var rig: RefCounted
var sections: Array[Dictionary]=[]
var exclusions: Array[RID]=[]
var space: PhysicsDirectSpaceState3D
var ready:=false
var error:=""
var broad_queries:=0
var shell_queries:=0
var chunked:=true
var last_collider: Object
var _radius:=0.0
var _box:=BoxShape3D.new()
var _shell:=ConvexPolygonShape3D.new()
var _query:=PhysicsShapeQueryParameters3D.new()
var _response_planes: Array[Dictionary]=[]
var _response_valid:=false
var _response_truncated:=false
var _response_limit:=128
func _fail(message: String) -> bool:
	error=message;return false
func configure(owner_rig: RefCounted,world: PhysicsDirectSpaceState3D,exclude: Array[RID]) -> bool:
	if ready or owner_rig==null or not owner_rig.configured:return _fail("unconfigured or already bound hose")
	rig=owner_rig;space=world;exclusions=exclude.duplicate()
	_box.margin=.000001;_shell.margin=.000001;_query.margin=0.
	_query.collision_mask=1;_query.collide_with_areas=false;_query.exclude=exclusions
	var draws: Array[Node]=rig.model.find_children("*","MeshInstance3D",true,false)
	if draws.size()!=1:return _fail("expected one native cloth skin")
	var draw: MeshInstance3D=draws[0]
	if draw.skin==null or draw.mesh.get_surface_count()!=1:return _fail("missing native skin")
	var groups: Array[Dictionary]=[]
	for i in rig.indices.size():groups.append({})
	var bind_ring:=PackedInt32Array();bind_ring.resize(draw.skin.get_bind_count());bind_ring.fill(-1)
	for i in bind_ring.size():
		var name: StringName=draw.skin.get_bind_name(i)
		var bone: int=rig.skeleton.find_bone(str(name)) if not name.is_empty() else draw.skin.get_bind_bone(i)
		bind_ring[i]=rig.indices.find(bone)
	var arrays: Array=draw.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	if vertices.is_empty() or bones.size()!=weights.size() or bones.size()%vertices.size()!=0:return _fail("invalid native weights")
	var slots: int=bones.size()/vertices.size()
	var into_model: Transform3D=rig.model.global_transform.affine_inverse()*draw.global_transform
	for i in vertices.size():
		var ring: int=-1;var influences:=0
		for slot in slots:
			var at: int=i*slots+slot
			if weights[at]<=.000001:continue
			if absf(weights[at]-1.)>.000001 or bones[at]<0 or bones[at]>=bind_ring.size():return _fail("cloth is not single-ring weighted")
			ring=bind_ring[bones[at]];influences+=1
		if influences!=1 or ring<0:return _fail("unmapped ring influence")
		var point: Vector3=rig.original_frames[ring].affine_inverse()*(into_model*vertices[i])
		if not point.is_finite() or absf(point.y)>.000002:return _fail("imported ring is not in its native plane")
		groups[ring][point]=true
	for ring in groups.size():
		var points: Array=groups[ring].keys()
		if points.size()!=64:return _fail("expected64actual inner/outer section vertices: "+str([ring,points.size()]))
		var radii:=Vector2.ZERO
		for p: Vector3 in points:radii=radii.max(Vector2(absf(p.x),absf(p.z)))
		if radii.x<=0. or radii.y<=0.:return _fail("collapsed native section")
		var outer: Array[Vector3]=[];var inner: Array[Vector3]=[]
		for p: Vector3 in points:
			if Vector2(p.x/radii.x,p.z/radii.y).length()>.9999:outer.append(p)
			else:inner.append(p)
		if outer.size()!=32 or inner.size()!=32:return _fail("invalid annular native section: "+str(ring))
		var inner_radii:=Vector2.ZERO
		for p: Vector3 in inner:inner_radii=inner_radii.max(Vector2(absf(p.x),absf(p.z)))
		var sorted_outer:=PackedVector3Array();var sorted_inner:=PackedVector3Array();sorted_outer.resize(32);sorted_inner.resize(32)
		var seen: Dictionary={}
		for p: Vector3 in outer:
			var index: int=posmod(roundi(atan2(p.z/radii.y,p.x/radii.x)*32./TAU),32)
			if seen.has(index):return _fail("duplicate native outer angle")
			seen[index]=true;sorted_outer[index]=p
		seen.clear()
		for p: Vector3 in inner:
			var index: int=posmod(roundi(atan2(p.z/inner_radii.y,p.x/inner_radii.x)*32./TAU),32)
			if seen.has(index):return _fail("duplicate native inner angle")
			seen[index]=true;sorted_inner[index]=p
		var bounds:=AABB(points[0],Vector3.ZERO)
		for p: Vector3 in points:
			bounds=bounds.expand(p);_radius=maxf(_radius,(rig.original_frames[ring].basis*p).length())
		sections.append({"outer":sorted_outer,"inner":sorted_inner,"bounds":bounds})
	ready=sections.size()==rig.indices.size()
	return ready
func _hits_box(bounds: AABB) -> bool:
	_box.size=Vector3(maxf(bounds.size.x,.000002),maxf(bounds.size.y,.000002),maxf(bounds.size.z,.000002))
	_query.shape=_box;_query.transform=Transform3D(Basis.IDENTITY,bounds.get_center())
	return not space.intersect_shape(_query,1).is_empty()
func veto(before: PackedVector3Array,after: PackedVector3Array) -> bool:return _test(before,after,false)
func intersects_pose(points: PackedVector3Array) -> bool:return _test(points,points,true)
func contact_constraints(points: PackedVector3Array,limit: int=128) -> Dictionary:
	# Native shell contacts supply tangent half-spaces for the response solver.
	# These are local contact constraints, not a replacement collision test.
	_response_limit=clampi(limit,1,4096)
	_test(points,points,true,true)
	return {"valid":_response_valid,"truncated":_response_truncated,"planes":_response_planes.duplicate(true)}
func motion_constraints(before: PackedVector3Array,after: PackedVector3Array,limit: int=128) -> Dictionary:
	_response_limit=clampi(limit,1,4096)
	_test(before,after,true,true)
	return {"valid":_response_valid,"truncated":_response_truncated,"planes":_response_planes.duplicate(true)}
func _cell_hull(posed: Array[PackedVector3Array],sector: int,origin: Vector3,fraction: float) -> PackedVector3Array:
	var hull:=PackedVector3Array()
	for row in 4:
		for index in [sector,(sector+1)%32,sector+32,(sector+1)%32+32]:
			var p: Vector3=posed[row][index]
			if row>=2:p=posed[row-2][index].lerp(p,fraction)
			hull.append(p-origin)
	return hull
func _contact_plane(ring: int,frame: Transform3D,world: Transform3D,info: Dictionary) -> Dictionary:
	if info.is_empty():return {}
	var normal: Vector3=info.normal
	var point: Vector3=info.point
	if not normal.is_finite() or not point.is_finite() or normal.length_squared()<.99:return {}
	var local: Vector3=world.basis.transposed()*normal
	var scale: float=local.length()
	if not is_finite(scale) or scale<.000001:return {}
	local/=scale
	var surface: float=(normal.dot(point)-normal.dot(world.origin))/scale
	var support:=INF
	for p: Vector3 in sections[ring].outer:support=minf(support,local.dot(frame.basis*p))
	return {"ring":ring,"normal":local,"offset":surface-support+.000003,"rid":info.rid}
func _test(before: PackedVector3Array,after: PackedVector3Array,include_still: bool,collect: bool=false) -> bool:
	broad_queries=0;shell_queries=0;last_collider=null
	_response_planes.clear();_response_valid=false;_response_truncated=false
	if not ready or before.size()!=sections.size() or after.size()!=sections.size():return true
	var world: Transform3D=rig.model.global_transform
	var whole:=AABB(before[0],Vector3.ZERO)
	for i in before.size():
		if not before[i].is_finite() or not after[i].is_finite():return true
		var a: Vector3=before[mini(i+1,before.size()-1)]-before[maxi(i-1,0)]
		var b: Vector3=after[mini(i+1,after.size()-1)]-after[maxi(i-1,0)]
		if not is_finite(a.length_squared()) or not is_finite(b.length_squared()) or a.length_squared()<1e-14 or b.length_squared()<1e-14:return true
		whole=whole.expand(before[i]).expand(after[i])
	_response_valid=true
	broad_queries+=1
	if not _hits_box(world*whole.grow(_radius+.000002)):return false
	var old: Array[Transform3D]=rig.model_frames(before);var next: Array[Transform3D]=rig.model_frames(after)
	if old.is_empty() or next.is_empty():_response_valid=false;return true
	# Chunk bounds avoid thousands of native shape queries on long, clear
	# spans. Every occupied chunk still gets the original per-cell narrow test.
	var bounds_by_segment: Array[AABB]=[];bounds_by_segment.resize(sections.size()-1)
	var occupied:=PackedByteArray();occupied.resize(sections.size()-1);occupied.fill(0)
	for start in range(0,sections.size()-1,32):
		var chunk:=AABB(world*old[start].origin,Vector3.ZERO)
		for i in range(start,mini(start+32,sections.size()-1)):
			var bounds: AABB=(world*old[i])*sections[i].bounds
			bounds=bounds.merge((world*old[i+1])*sections[i+1].bounds)
			bounds=bounds.merge((world*next[i])*sections[i].bounds).merge((world*next[i+1])*sections[i+1].bounds)
			bounds_by_segment[i]=bounds;chunk=chunk.merge(bounds)
		if chunked:broad_queries+=1
		if not chunked or _hits_box(chunk.grow(.000002)):
			for i in range(start,mini(start+32,sections.size()-1)):occupied[i]=1
	for i in range(sections.size()-1):
		if occupied[i]==0:continue
		if not include_still and old[i]==next[i] and old[i+1]==next[i+1]:continue
		var bounds: AABB=bounds_by_segment[i]
		broad_queries+=1
		if not _hits_box(bounds.grow(.000002)):continue
		var posed: Array[PackedVector3Array]=[]
		for frame: Transform3D in [world*old[i],world*old[i+1],world*next[i],world*next[i+1]]:
			var index: int=i if posed.size()%2==0 else i+1
			var points:=PackedVector3Array()
			for layer: String in ["outer","inner"]:
				for p: Vector3 in sections[index][layer]:
					points.append(frame*p)
			posed.append(points)
		var origin: Vector3=bounds.get_center()
		for sector in 32:
			_shell.points=_cell_hull(posed,sector,origin,1.);_query.shape=_shell;_query.transform=Transform3D(Basis.IDENTITY,origin)
			shell_queries+=1
			var hits: Array[Dictionary]=space.intersect_shape(_query,1)
			if hits.is_empty():continue
			last_collider=hits[0].collider
			if not collect:return true
			if before!=after:
				# Locate first contact on the conservative linear-vertex sweep.
				# A final-pose manifold can report the underside of a thin wall
				# after tunnelling, giving the response solver the wrong normal.
				var low:=0.;var high:=1.
				for refinement in 14:
					var middle: float=(low+high)*.5
					_shell.points=_cell_hull(posed,sector,origin,middle)
					if space.intersect_shape(_query,1).is_empty():low=middle
					else:high=middle
				_shell.points=_cell_hull(posed,sector,origin,high)
			var info: Dictionary=space.get_rest_info(_query)
			for ring: int in [i,i+1]:
				var plane: Dictionary=_contact_plane(ring,next[ring],world,info)
				if plane.is_empty():_response_valid=false;return true
				_response_planes.append(plane)
			if _response_planes.size()>=_response_limit:_response_truncated=true;return true
			# One tangent support per segment is re-evaluated after response;
			# corners and curved obstacles may need several solver iterations.
			break
	return not _response_planes.is_empty()
