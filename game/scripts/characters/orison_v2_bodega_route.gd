extends RefCounted
## Physical bodega routing only; semantic desired_id remains with the route owner.
const SERVICE := "service_stance"
const ALIGN := "street_alignment"
const OFA := "resident_overflow_approach"
const OF := "resident_overflow"
const FRONT := "resident_wait_front"
const REAR := "resident_wait_rear"
const AF := "resident_access_front"
const AR := "resident_access_rear"
const ST := "resident_service_turn"
const ET := "resident_entry_turn"
const EXT := "exterior_stance"
const INT := "interior_arrival"
const PUBLIC_STREET := "public_street"
const PUBLIC_TURN := "public_inbound_turn"
const TRANSIT_HOLDS := [SERVICE, FRONT, REAR, OF, OFA]
const EDGES := [[ALIGN,OFA],[OFA,OF],[OF,EXT],[EXT,INT],[INT,ET],[ET,ST],
	[ST,AF],[AF,AR],[AF,FRONT],[AR,REAR],[ST,SERVICE]]
var route: Node3D
var owner: Node3D
var errors: Array[String] = []
var _nodes: Dictionary = {}
var _enabled := false
var _bound := false
var _managed := false
var _cancelled := false
var _holding := ""
var _station := ""
var _leg := PackedInt64Array()
var _leg_kind := ""
var _initial := -1

func attach(selected: Node3D) -> bool:
	if route != null or not is_instance_valid(selected): return false
	route = selected; owner = route.world.get("bodega_admission") as Node3D
	if owner == null: return true # Old reduced fixtures only; production root must require owner.
	for name: String in [SERVICE,ALIGN,EXT,INT]:
		var identity := "bodega" if name == SERVICE else "bodega_route_%d" % {ALIGN:2,EXT:3,INT:4}[name]
		if not route.identities.has(identity): return _fault("missing original bodega node " + identity)
		_nodes[name] = int(route.identities[identity])
	for name: String in [SERVICE,ALIGN,EXT,INT,FRONT,REAR,AF,AR,ST,ET,OF,OFA]:
		var marker := owner.call("position_marker",name) as Node3D
		if marker == null: return _fault("missing configured admission marker " + name)
		if _nodes.has(name):
			if route.graph.get_point_position(_nodes[name]).distance_to(marker.global_position) > .001: return _fault("source frame mismatch " + name)
		else: _nodes[name] = int(route._point("bodega_"+name,marker.global_position))
	if not route.identities.has("street"): return _fault("missing ordinary street approach")
	_nodes[PUBLIC_STREET]=int(route.identities.street)
	var resolver: Object=route.world.exterior_cell.spatial_resolver
	var turn: Dictionary=resolver.call("resolve_placement","STREET_ORISON_01","resident_bodega_inbound_turn")
	if turn.get("instance_id","")!="STREET_ORISON_01" or turn.get("placement_id","")!="resident_bodega_inbound_turn" or not turn.get("position") is Vector3:
		return _fault("missing authored public inbound corner")
	_nodes[PUBLIC_TURN]=int(route._point("bodega_public_inbound_turn",turn.position))
	for pair: Array in [[PUBLIC_STREET,PUBLIC_TURN],[PUBLIC_TURN,ALIGN]]:
		var a:=int(_nodes[pair[0]]); var b:=int(_nodes[pair[1]])
		if not route.graph.are_points_connected(a,b): route.graph.connect_points(a,b)
	for edge: Array in EDGES:
		var a := int(_nodes[edge[0]]); var b := int(_nodes[edge[1]])
		if not route.graph.are_points_connected(a,b): route.graph.connect_points(a,b)
	_enabled = true; return true

func bind_actor() -> bool:
	if not _enabled: return true
	if _bound: return true
	_bound = bool(owner.call("bind",str(route.resident),route.actor))
	return _bound

## Called once before generic fallback and before any accepted construction placement.
## Caller alone assigns current_id/feet, then calls initial_arrived before next setup.
func initial_placement() -> Dictionary:
	if not _enabled or route.destination != "bodega": return {"handled":false}
	if not _bound: return {"handled":true,"ok":false,"reason":"actor not bound"}
	var marker := owner.call("request_service",str(route.resident),route.actor) as Node3D
	if marker != null:
		_holding = str(marker.name)
		if _point_clear(int(_nodes[SERVICE])) and bool(owner.call("try_service",str(route.resident),route.actor,true)):
			return _initial_at(int(_nodes[SERVICE]),"initial service transfer")
		if _nodes.has(_holding) and _point_clear(int(_nodes[_holding])): return _initial_at(int(_nodes[_holding]),"initial queued stance")
	# Capacity/physical refusal never authorizes a doorway or iteration-order fallback.
	var home := int(route.identities.get(str(route.places.get("unit","")),-1))
	if home >= 0:
		for point: int in route.graph.get_id_path(home,int(_nodes[ALIGN])):
			if _nodes.values().has(point): break
			if _point_clear(point) and _doors_clear(point): return _initial_at(point,"upstream capacity/clearance hold")
	return {"handled":true,"ok":false,"reason":"no supported free original upstream vertex"}

func _initial_at(point: int, reason: String) -> Dictionary:
	var feet := _floor(route.graph.get_point_position(point))
	_initial = point
	return {"handled":true,"ok":feet.is_finite(),"point_id":point,"feet":feet,"reason":reason}

func initial_arrived() -> bool:
	if not _enabled: return true
	if not is_instance_valid(owner) or _initial < 0 or not _at(_initial): return false
	_station = str(_nodes.find_key(_initial))
	return bool(owner.call("arrive_service",str(route.resident),route.actor)) if _station == SERVICE else true

## Retire only a queued upstream request before the existing unseen handoff.
## Do not start a new approach while a hidden actor is waiting to reappear.
func release_upstream_for_outside() -> bool:
	if not _enabled: return true
	if not _bound or not is_instance_valid(owner) or not _vertex(): return false
	if bool(owner.call("has_service",str(route.resident),route.actor)) or bool(owner.call("has_transit",str(route.resident),route.actor)): return false
	if _nodes.values().has(int(route.current_id)) and int(route.current_id)!=int(_nodes[PUBLIC_STREET]): return false
	if not bool(owner.call("release_service",str(route.resident),route.actor,false)): return false
	_holding=""; _station=""; _leg.clear(); _leg_kind=""; route.path.clear(); _managed=false
	return true

func manages_path() -> bool:
	return _managed

## Invoke BEFORE semantic early-arrival return and generic planning.
## false: stop this frame. true+managed: consume installed exact path, skip generic
## planning. true+unmanaged: retain normal generic/bar behavior unchanged.
func guide_path() -> bool:
	_managed = false
	if not _enabled: return true
	if not _bound or not is_instance_valid(owner) or not is_instance_valid(route.actor): return _fault("binding retired")
	var wants: bool = route.destination == "bodega" and not _cancelled
	_managed = wants or not _holding.is_empty() or not _leg.is_empty() or bool(owner.call("has_service",str(route.resident),route.actor)) or bool(owner.call("has_transit",str(route.resident),route.actor))
	if not _managed: return not _cancelled
	if not _leg.is_empty():
		# Retargets finish a committed local leg; global approach may cancel at a vertex.
		if not wants and _leg_kind == "approach" and _vertex() and (not _nodes.values().has(int(route.current_id)) or int(route.current_id) in [int(_nodes[PUBLIC_STREET]),int(_nodes[PUBLIC_TURN])]):
			owner.call("release_service",str(route.resident),route.actor,false); _holding=""; _leg.clear(); route.path.clear()
			_managed=false; return not _cancelled
		if int(route.current_id) == int(_leg[-1]) and route.path.is_empty() and _vertex():
			if not _finish_leg(): return false
		else: return _install_tail()
	if not _vertex():
		# Preserve the sole committed old edge when semantic intent changes mid-edge.
		if route.path.is_empty(): return _fault("mid-edge without committed next vertex")
		route.path.resize(1); route.planned_id=route.desired_id; return true
	if not wants: return _depart()
	var marker := owner.call("request_service",str(route.resident),route.actor) as Node3D
	if marker == null: return _wait("bodega capacity: hold upstream vertex")
	_holding=str(marker.name)
	if bool(owner.call("has_service",str(route.resident),route.actor)):
		if _at(int(_nodes[SERVICE])):
			_station=SERVICE
			if not bool(owner.call("arrive_service",str(route.resident),route.actor)): return _wait("service arrival not acknowledged")
			return _wait("standing at bodega service")
		return _transit(_transfer(_station),"transfer")
	if _station in [FRONT,REAR,OF] and _at(int(_nodes[_station])):
		var path := _transfer(_station)
		# Acquire service transfer BEFORE service-bound transit, avoiding departure deadlock.
		if not _people_path_clear(path) or not bool(owner.call("try_service",str(route.resident),route.actor,_point_clear(int(_nodes[SERVICE])))): return _wait("waiting for service transfer")
		return _transit(path,"transfer")
	if _at(int(_nodes[OFA])): _station=OFA; return _transit(_entry(_holding),"entry")
	# Outside circulation uses original home/street graph to alignment, never a service shortcut.
	var approach := _public_approach(int(route.current_id))
	if approach.is_empty(): return _fault("no ordinary upstream approach")
	return _start_ids(approach,"approach")

## The shared pavement turn remains available to a standing player. Grocery
## arrivals use their own authored corner, rather than pushing through her.
func _public_approach(from: int) -> PackedInt64Array:
	var continuation := [int(_nodes[PUBLIC_TURN]),int(_nodes[ALIGN]),int(_nodes[OFA])]
	var index := continuation.find(from)
	if index>=0: return PackedInt64Array(continuation.slice(index))
	var result: PackedInt64Array=route.graph.get_id_path(from,int(_nodes[PUBLIC_STREET]))
	if result.is_empty(): return result
	for point: int in continuation: result.append(point)
	return result

func _depart() -> bool:
	if _station.is_empty():
		owner.call("release_service",str(route.resident),route.actor,false); _holding=""; _managed=false
		return not _cancelled
	var path := _exit(_station)
	if path.is_empty(): return _fault("no departure itinerary from " + _station)
	# A blocked prospective head cannot queue ahead of the body it needs to leave.
	if not _people_path_clear(path): return _wait("departure path occupied; retain waiting station")
	# Reserve transit at exact held stance BEFORE releasing a queued service slot.
	var slot := TRANSIT_HOLDS.find(_station)
	var allowed: Array[int] = [slot]
	if slot < 0 or owner.call("request_transit",str(route.resident),route.actor,allowed) == null: return _wait("departure holding unavailable")
	if not bool(owner.call("has_service",str(route.resident),route.actor)):
		if not bool(owner.call("release_service",str(route.resident),route.actor,false)): return _wait("queued departure retains service holding")
	return _transit(path,"exit")

func _transit(names: Array, kind: String) -> bool:
	if names.is_empty(): return _fault("missing supported local itinerary")
	# Eligibility precedes FIFO insertion. In particular, an overflow occupant
	# must be able to depart before a newcomer queues a path through that station.
	if not _people_path_clear(names): return _wait("local itinerary physically occupied")
	var slot := TRANSIT_HOLDS.find(_station)
	var allowed: Array[int] = [slot]
	if slot < 0 or owner.call("request_transit",str(route.resident),route.actor,allowed) == null: return _wait("transit holding unavailable")
	if not bool(owner.call("try_transit",str(route.resident),route.actor,true)): return _wait("waiting for short circulation token/people")
	var ids := PackedInt64Array()
	for name: String in names: ids.append(int(_nodes[name]))
	return _start_ids(ids,kind)

func _start_ids(ids: PackedInt64Array, kind: String) -> bool:
	if ids.is_empty() or int(ids[0]) != int(route.current_id): return _fault("itinerary must begin at exact current vertex")
	for i in ids.size()-1:
		if not route.graph.are_points_connected(ids[i],ids[i+1]): return _fault("unregistered itinerary edge")
	_leg=ids; _leg_kind=kind; return _install_tail()

func _install_tail() -> bool:
	var index := _leg.find(int(route.current_id))
	if index < 0 and _leg_kind == "approach":
		# BarRoute may legitimately visit a holding detour outside this old path.
		# Preserve its current physical edge, then resume from the reached vertex.
		if not _vertex():
			if route.path.is_empty(): return _fault("bar detour lost its committed edge")
			route.path.resize(1); route.planned_id=route.desired_id; return true
		_leg=_public_approach(int(route.current_id))
		if _leg.is_empty(): return _fault("bar detour has no upstream continuation")
		index=0
	if index < 0: return _fault("current vertex left committed local itinerary")
	route.path=_leg.slice(index+1); route.planned_id=route.desired_id
	return true

func _finish_leg() -> bool:
	_station=str(_nodes.find_key(int(_leg[-1])))
	if _leg_kind == "transfer" and not bool(owner.call("arrive_service",str(route.resident),route.actor)): return _wait("service foot acknowledgement pending")
	if _leg_kind in ["entry","transfer","exit"]:
		if not bool(owner.call("release_transit",str(route.resident),route.actor,true)): return _wait("transit release pending")
	if _leg_kind == "exit":
		if not bool(owner.call("release_service",str(route.resident),route.actor,true)): return _wait("service release pending after physical exit")
		_holding=""; _station=""
	_leg.clear(); _leg_kind=""; return true

func _entry(target: String) -> Array:
	if target == OF: return [OFA,OF]
	var names := [OFA,OF,EXT,INT,ET,ST,AF]
	if target == FRONT: names.append(FRONT)
	elif target == REAR: names.append(AR); names.append(REAR)
	else: return []
	return names

func _transfer(at: String) -> Array:
	if at == FRONT: return [FRONT,AF,ST,SERVICE]
	if at == REAR: return [REAR,AR,AF,ST,SERVICE]
	if at == OF: return [OF,EXT,INT,ET,ST,SERVICE]
	return []

func _exit(at: String) -> Array:
	if at == SERVICE: return [SERVICE,INT,EXT,ALIGN]
	if at == FRONT: return [FRONT,AF,ST,ET,INT,EXT,ALIGN]
	if at == REAR: return [REAR,AR,AF,ST,ET,INT,EXT,ALIGN]
	if at == OF: return [OF,EXT,ALIGN]
	if at == OFA: return [OFA,ALIGN]
	return []

func clear_step(next: Vector3) -> bool:
	if not _enabled or not _managed: return true
	# Ordinary door readiness runs FIRST. No leaf is removed/excluded to admit travel.
	if not _people_clear(next): return false
	var feet := _floor(next)
	if not feet.is_finite(): return false
	var query := PhysicsShapeQueryParameters3D.new(); query.shape=route._capsule; query.collision_mask=1
	query.exclude=[route.world.player.get_rid()]; query.transform.origin=route.actor.global_position+Vector3.UP*.95
	query.motion=feet-route.actor.global_position
	var space:=route.get_world_3d().direct_space_state; var cast:=space.cast_motion(query)
	if cast.size()!=2 or cast[0]<1.0: return false
	query.transform.origin+=query.motion; query.motion=Vector3.ZERO
	return space.intersect_shape(query,1).is_empty()

func _people_path_clear(names: Array) -> bool:
	if names.is_empty(): return false
	for body: Node3D in _people():
		if body == route.actor: continue
		var separation := .65 if body is PlayerController else .60
		for i in names.size()-1:
			var a := _floor(route.graph.get_point_position(_nodes[names[i]])); var b := _floor(route.graph.get_point_position(_nodes[names[i+1]]))
			if not a.is_finite() or not b.is_finite(): return false
			var nearest := Geometry3D.get_closest_point_to_segment(body.global_position,a,b)
			if absf(nearest.y-body.global_position.y)<1.6 and Vector2(nearest.x-body.global_position.x,nearest.z-body.global_position.z).length()<separation: return false
	return true

func _floor(at: Vector3) -> Vector3:
	var hit := route.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.34,at-Vector3.UP*.5,1))
	if hit.is_empty() or hit.normal.y<.45 or absf(hit.position.y-at.y)>.25: return Vector3.INF
	return Vector3(at.x,hit.position.y,at.z)

func _point_clear(point: int) -> bool:
	var feet := _floor(route.graph.get_point_position(point))
	if not feet.is_finite() or not _people_clear(feet, true): return false
	var query := PhysicsShapeQueryParameters3D.new(); query.shape=route._capsule; query.collision_mask=1
	query.exclude=[route.world.player.get_rid()]; query.transform.origin=feet+Vector3.UP*.95
	return route.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _doors_clear(point: int) -> bool:
	for door: DoorProp in route._doors:
		if not door.standing_position_clear(route.graph.get_point_position(point),.28,1.65): return false
	return true

func _at(point: int) -> bool:
	var feet := _floor(route.graph.get_point_position(point))
	return feet.is_finite() and route.actor.global_position.distance_to(feet)<=.06

func _vertex() -> bool:
	var point: Vector3=route.graph.get_point_position(int(route.current_id)); var at: Vector3=route.actor.global_position
	return Vector2(at.x-point.x,at.z-point.z).length()<.04 and absf(at.y-point.y)<.3

func _wait(reason: String) -> bool:
	route.blocked_reason=reason; route.path.clear(); return false

func _fault(reason: String) -> bool:
	if reason not in errors: errors.append(reason)
	return _wait("bodega guide refused: "+reason) if is_instance_valid(route) else false

## Live cancellation is a request, never a false clearance certificate. Continue
## guide_path until safe departure. On actual body deletion the owner prunes weak refs.
func cancel() -> bool:
	_cancelled=true
	if not _enabled or not _bound: return true
	if not is_instance_valid(owner): return false # Missing state owner certifies no clearance.
	return _holding.is_empty() and _leg.is_empty() and not bool(owner.call("has_service",str(route.resident),route.actor)) and not bool(owner.call("has_transit",str(route.resident),route.actor))

## Include a queued-for-deletion presentation until it actually leaves the tree.
## Logical FIFO pruning is never evidence that its physical space is clear.
func _people() -> Array[Node3D]:
	var people: Array[Node3D] = []
	for node in route.get_tree().get_nodes_in_group("animated_residents"):
		if is_instance_valid(node) and node is Node3D and node.is_inside_tree() and node.visible: people.append(node)
	if is_instance_valid(route.world.player): people.append(route.world.player)
	return people

func _people_clear(next: Vector3, absolute: bool = false) -> bool:
	for body: Node3D in _people():
		if body == route.actor or absf(body.global_position.y-next.y)>1.6: continue
		var separation := .65 if body is PlayerController else .60
		var gap := Vector2(next.x-body.global_position.x,next.z-body.global_position.z).length()
		if gap >= separation: continue
		var at: Vector3 = route.actor.global_position
		var previous := Vector2(at.x-body.global_position.x,at.z-body.global_position.z).length()
		if absolute or gap <= previous+.00001: return false
	return true
