extends RefCounted
## Read-only, fail-closed traversal provider. Authored V2 portals and stairs
## supply topology; loaded collision/support decides whether an edge is usable.
var world: Node3D
var graph := AStar3D.new()
var rooms: Dictionary = {}
var edges: Array[Vector2i] = []
var capsule := CapsuleShape3D.new()
var exclude: Array[RID] = []
var revision := 0
var last_rejection: Dictionary = {}

func _reject(reason: String,point: Vector3,collider: Object=null) -> bool:
	last_rejection={"reason":reason,"point":[point.x,point.y,point.z],"owner":str(collider.get_path()) if collider is Node else ""}
	return false

func setup(root: Node3D, observer: CollisionObject3D) -> void:
	world = root
	exclude = [observer.get_rid()]
	capsule.radius = .30
	capsule.height = 1.35
	for room: Dictionary in world.layout.get("spaces", []):
		var rect: Array = room.rect
		var y: float = world.adapter.root.level_y[str(room.level)]
		var ids: Array[int] = []
		for uv in [Vector2(.5,.5),Vector2(.15,.15),Vector2(.85,.15),Vector2(.15,.85),Vector2(.85,.85)]:
			ids.append(_point(Vector3(lerpf(rect[0],rect[2],uv.x),y,lerpf(rect[1],rect[3],uv.y))))
		rooms[str(room.id)] = ids
	for section in ["doors","openings"]:
		for portal: Dictionary in world.layout.get(section, []):
			var connected: Array = portal.get("connects", [])
			if connected.size()!=2 or not rooms.has(str(connected[0])) or not rooms.has(str(connected[1])): continue
			var center: Array = portal.get("center", [])
			if center.size()!=2: continue
			var y: float = world.adapter.root.level_y[str(portal.level)]
			var id := _point(Vector3(center[0],y,center[1]))
			for room_id in connected: rooms[str(room_id)].append(id)
	for room_id in rooms:
		var ids: Array = rooms[room_id]
		for i in ids.size():
			for j in range(i+1,ids.size()): _edge(ids[i],ids[j])
	for stair: Dictionary in world.layout.get("stairs", []):
		var points := stair_points(world.adapter.root,stair)
		if points.is_empty(): continue
		var ids: Array[int] = []
		for p in points: ids.append(_point(p))
		for i in range(ids.size()-1): _edge(ids[i],ids[i+1])
		for end in [ids[0],ids[-1]]:
			for id in graph.get_point_ids():
				if id in ids: continue
				var delta := graph.get_point_position(id)-graph.get_point_position(end)
				if absf(delta.y)<.1 and delta.length()<6: _edge(end,id)
	# Open-plan spaces sometimes share a boundary without an authored door.
	# Nearby candidate joins are still subjected to the identical physical proof.
	var buckets: Dictionary={}
	for id in graph.get_point_ids():
		var p:=graph.get_point_position(id)
		var key:=Vector3i(floori(p.x/3),roundi(p.y*10),floori(p.z/3))
		for dx in range(-1,2):
			for dz in range(-1,2):
				for other in buckets.get(key+Vector3i(dx,0,dz),[]):
					if p.distance_to(graph.get_point_position(other))<3: _edge(id,other)
		if not buckets.has(key): buckets[key]=[]
		buckets[key].append(id)

## Authored U-stair centreline in blockout-local space, foot to head. Empty
## when the stair has no half landing.
static func stair_points(root: Node3D,stair: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var half := root.get_node_or_null(str(stair.id)+"/HalfLanding") as MeshInstance3D
	if half==null: return points
	var x := float(stair.origin[0]); var z := float(stair.origin[1]); var width := float(stair.width)
	# Turn at the half landing's centre: the guards on its far edge leave the
	# capsule no clearance at the old 0.32 m inset.
	var turn := half.position.z+half.mesh.get_aabb().get_center().z
	var low: float = root.level_y[str(stair.from)]
	var high: float = root.level_y[str(stair.to)]
	var mid := low+float(stair.rise)*int(stair.risers_per_flight)
	var a := x+width*.5; var b := x+width*1.5+float(stair.gap)
	var run:=float(stair.tread)*int(stair.risers_per_flight)
	var north_start:=z+run+float(stair.landing_depth)
	# Keep ramp endpoints distinct from level landings: interpolating one
	# diagonal over both makes the proposed feet sink through real treads.
	# The head exits only 5 cm short of the stair: the fire-line cabinet sits
	# beside the stair head on every floor.
	points.assign([Vector3(a,low,z-.25),Vector3(a,low,z),Vector3(a,mid,z+run),Vector3(a,mid,turn),Vector3(b,mid,turn),Vector3(b,mid,north_start),Vector3(b,high,z+float(stair.landing_depth)),Vector3(b,high,z-.05)])
	return points

func _point(local: Vector3) -> int:
	var id := graph.get_point_count()
	graph.add_point(id,world.adapter.root.to_global(local)+Vector3.UP*.035)
	return id

func _edge(a: int,b: int) -> void:
	if a==b or graph.are_points_connected(a,b): return
	graph.connect_points(a,b)
	edges.append(Vector2i(a,b))

func ray(a: Vector3,b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a,b)
	query.exclude = exclude
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func floor_ray(p: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.30,p-Vector3.UP*.32)
	query.exclude=exclude.duplicate()
	for attempt in 4:
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y>=.65: return hit
		# A ramp's thin end cap can be the first downward hit at its junction.
		# Require a real tread/landing below it, within the same support range.
		var ignored:=query.exclude
		ignored.append(hit.collider.get_rid()); query.exclude=ignored
	return {}

func supported(a: Vector3,b: Vector3) -> bool:
	last_rejection={}
	if not a.is_finite() or not b.is_finite(): return _reject("nonfinite",Vector3.ZERO)
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape=capsule; q.exclude=exclude; q.collide_with_areas=false; q.margin=.005
	# Lower 35 cm accommodates actual stair treads; support is separately proven.
	q.transform=Transform3D(Basis(),a+Vector3.UP*1.0)
	var overlaps:=space.intersect_shape(q,1)
	if not overlaps.is_empty(): return _reject("start_capsule",a,overlaps[0].collider)
	q.motion=b-a
	var motion := space.cast_motion(q)
	if motion.size()!=2 or motion[0]<1: return _reject("capsule_sweep",a.lerp(b,motion[0] if motion.size()==2 else 0.0))
	q.motion=Vector3.ZERO; q.transform.origin=b+Vector3.UP*1.0
	overlaps=space.intersect_shape(q,1)
	if not overlaps.is_empty(): return _reject("end_capsule",b,overlaps[0].collider)
	var count := maxi(1,ceili(a.distance_to(b)/.22))
	var last := a.y
	for i in range(count+1):
		var p := a.lerp(b,float(i)/count)
		var hit := floor_ray(p)
		if hit.is_empty() or hit.normal.y<.65 or not hit.collider is StaticBody3D: return _reject("centre_support",p,hit.get("collider"))
		if absf(float(hit.position.y)-last)>.31: return _reject("step_height",p,hit.collider)
		last=hit.position.y
		for rim in [Vector3(.25,0,0),Vector3(-.25,0,0),Vector3(0,0,.25),Vector3(0,0,-.25)]:
			var support := floor_ray(p+rim)
			if support.is_empty() or support.normal.y<.65 or not support.collider is StaticBody3D: return _reject("rim_support",p+rim,support.get("collider"))
	return true

func request(from: Vector3,target: Vector3) -> PackedVector3Array:
	# Candidate topology is never a promise: remove blocked edges lazily until
	# the shortest candidate is fully proven. No missing-floor fallback exists.
	if not supported(from,from) or not supported(target,target): return PackedVector3Array()
	var search := AStar3D.new()
	for id in graph.get_point_ids(): search.add_point(id,graph.get_point_position(id))
	for edge in edges: search.connect_points(edge.x,edge.y)
	var start := search.get_point_count(); var finish := start+1
	search.add_point(start,from); search.add_point(finish,target)
	for id in graph.get_point_ids():
		var p := graph.get_point_position(id)
		if absf(p.y-from.y)<.35 and p.distance_to(from)<5: search.connect_points(start,id)
		if absf(p.y-target.y)<.35 and p.distance_to(target)<5: search.connect_points(finish,id)
	if absf(from.y-target.y)<.25 and from.distance_to(target)<5: search.connect_points(start,finish)
	var checked: Dictionary = {}
	for attempt in 96:
		var ids := search.get_id_path(start,finish)
		if ids.is_empty(): return PackedVector3Array()
		var valid := true
		for i in range(ids.size()-1):
			var key := Vector2i(mini(ids[i],ids[i+1]),maxi(ids[i],ids[i+1]))
			if checked.has(key): continue
			if not supported(search.get_point_position(ids[i]),search.get_point_position(ids[i+1])):
				search.disconnect_points(ids[i],ids[i+1]); valid=false; break
			checked[key]=true
		if valid:
			revision+=1
			var compact:=PackedVector3Array()
			for point in search.get_point_path(start,finish):
				if compact.is_empty() or compact[-1].distance_to(point)>.01: compact.append(point)
			return compact
	return PackedVector3Array()

static func length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(path.size()-1): total+=path[i].distance_to(path[i+1])
	return total

static func project(path: PackedVector3Array,p: Vector3) -> Dictionary:
	var best := INF; var remaining := length(path); var result: Dictionary = {}
	for i in range(path.size()-1):
		var edge := path[i+1]-path[i]; var distance := edge.length()
		if distance<.001: continue
		var t := clampf((p-path[i]).dot(edge)/edge.length_squared(),0,1)
		var at := path[i]+edge*t; var gap := p.distance_to(at)
		if gap<best:
			best=gap; result={"valid":true,"remaining":remaining-distance*t,"point":at,"segment":i,"gap":gap}
		remaining-=distance
	return result
