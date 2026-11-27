extends Node3D
## Public-floor velocity proposals only. Route, door, service and save owners stay
## authoritative; the ordinary motor validates and executes every proposed step.
const StandingOccupancy := preload("res://scripts/characters/standing_occupancy.gd")
const Solver := preload("res://scripts/characters/public_avoidance_proposals.gd")
const PLAYER_SEPARATION := .65
const COURTESY_APPROACH_DISTANCE := 1.0
var solver := Solver.new()
var _world: WeakRef
var _bounds := Rect2()
var _floor_y := 0.0
var _configured := false
var _retired := false
var _paused := false
var _routes: Dictionary = {}
var _poses: Dictionary = {}
var _submitted: Dictionary = {}
var _proposals: Dictionary = {}
var _bodies: Array[WeakRef] = []
var stats := {"proposals":0,"missing_or_changed":0,"peer_veto":0,"native_veto":0,"executed":0}

func configure(world: Node3D, exterior: Node3D) -> bool:
	if _configured or _retired or not is_instance_valid(world) or not is_instance_valid(exterior): return false
	var resolver: Object=exterior.get("spatial_resolver")
	var spec: Dictionary=resolver.call("template_record_for_instance","STREET_ORISON_01")
	var raw: Array=spec.get("boundary_xz_m",[])
	var threshold: Dictionary=resolver.call("resolve_surface","STREET_ORISON_01","orison_threshold")
	var street:=exterior.call("instance_node","STREET_ORISON_01") as Node3D
	if raw.size()!=4 or threshold.is_empty() or street==null: return false
	# Resolver points use its registered world frame; template bounds are local.
	# The rendered exterior may have a separately prepared transform.
	var registered: Transform3D=resolver.call("instance_world_transform","STREET_ORISON_01")
	var local_threshold: Vector3=registered.affine_inverse()*Vector3(threshold.point)
	var corners: Array[Vector3]=[]
	for x: float in [float(raw[0]),float(raw[2])]:
		for z: float in [maxf(float(raw[1]),local_threshold.z),float(raw[3])]: corners.append(street.to_global(Vector3(x,0,z)))
	var lo:=Vector2(INF,INF); var hi:=Vector2(-INF,-INF)
	for point: Vector3 in corners: lo=lo.min(Vector2(point.x,point.z)); hi=hi.max(Vector2(point.x,point.z))
	_bounds=Rect2(lo,hi-lo); _floor_y=street.global_position.y
	_world=weakref(world); _configured=_bounds.has_area(); return _configured

func _ready() -> void:
	process_physics_priority=-100; process_mode=Node.PROCESS_MODE_ALWAYS
	solver.open()

## The fitted lamp scene owns its collision sizes and coordinate frame.
func register_lamp_posts(lamps: Node3D) -> void:
	for child in lamps.find_children("*", "CollisionShape3D", true, false):
		var collision := child as CollisionShape3D
		var cylinder := collision.shape as CylinderShape3D
		if cylinder == null or collision.disabled:
			continue
		var scale := collision.global_basis.get_scale().abs()
		var radius := cylinder.radius * maxf(scale.x, scale.z)
		var height := cylinder.height * scale.y
		var base := collision.global_position - Vector3.UP * height * 0.5
		if _inside(base, radius):
			solver.add_static_cylinder(base, radius, height)

func _live(body: Node3D) -> bool:
	return is_instance_valid(body) and body.is_inside_tree() and body.is_visible_in_tree()

func _inside(at: Vector3, margin: float = 0.0) -> bool:
	return absf(at.y-_floor_y)<.35+margin and _bounds.grow(margin).has_point(Vector2(at.x,at.z))

func _can_steer(route: Node3D) -> bool:
	if not is_instance_valid(route) or not route.can_process() or not route.is_physics_processing() or route.is_queued_for_deletion() or not _live(route.actor) or route.path.is_empty(): return false
	# The real door owner already admitted an authored crossing. Lateral RVO
	# can drive opposed bodies into its jambs; retain the ordinary straight
	# motor proposal until that passage custody is released. Peer/courtesy,
	# support, swept native collision and door checks still validate each step.
	if not route._door_passages.is_empty(): return false
	if not _inside(route.actor.global_position) or route._talking(): return false
	var world: Node3D=_world.get_ref()
	if world.player.call_locked and not ResidentConversations.permits_background_work(route.actor, world.player): return false
	if route.actor.mina_animation!=null and route.actor.mina_animation.route_busy: return false
	if route._bodega_route!=null and route._bodega_route._leg_kind in ["entry","transfer","exit"]: return false
	if route._bar_route!=null and (not route._bar_route._gate.is_empty() or route._bar_route.owns_local_edge()): return false
	return true

func _physics_process(delta: float) -> void:
	if not _configured or _retired or _world.get_ref()==null: return
	if get_tree().paused:
		if not _paused:
			NavigationServer3D.map_set_active(solver.map,false); _paused=true
			_proposals.clear(); _submitted.clear()
		return
	if _paused:
		for entry: Dictionary in solver.agents.values(): entry.frame=-1
		NavigationServer3D.map_set_active(solver.map,true); _paused=false
	var world: Node3D=_world.get_ref()
	_bodies.clear(); _routes.clear(); _proposals.clear()
	var nodes: Array[Node3D]=[]
	for node in get_tree().get_nodes_in_group("animated_residents"):
		if node is Node3D and _live(node): nodes.append(node)
	if _live(world.player): nodes.append(world.player)
	var rows: Array[Dictionary]=[]; var goals: Dictionary={}; var seen: Dictionary={}
	for body: Node3D in nodes:
		_bodies.append(weakref(body))
		var id: int=body.get_instance_id(); var at: Vector3=body.global_position
		var column := StandingOccupancy.read(body)
		if column.get("invalid", false):
			push_error("Public foot traffic refused invalid standing column"); shutdown(); return
		if not column.is_empty(): at = column.base
		var measured: Vector3=(at-Vector3(_poses.get(id,at)))/delta
		_poses[id]=at; seen[id]=true
		if not _inside(at,1.65): continue
		var route: Node3D=body.get_parent()
		if route==null or not route.has_method("_proposed_step") or route.get("actor")!=body or route.get("world")!=world: route=null
		if route!=null: _routes[id]=weakref(route)
		var steer: bool=route!=null and _can_steer(route)
		var wanted: Vector3=measured
		var limit:=1.05
		if steer:
			limit=float(route.route_speed)
			var target: Vector3=route.graph.get_point_position(route.path[0])
			wanted=Vector3(target.x-at.x,0,target.z-at.z).limit_length(limit*delta)/delta; goals[id]=target
		var reply: Dictionary=solver.take(id)
		if not reply.is_empty() and _submitted.has(id): _proposals[id]={"target":_submitted[id],"velocity":reply.velocity,"age":reply.age}
		var snapshot := {"id":id,"feet":at,"preferred":wanted,"steer":steer,"player":body==world.player,"max_speed":limit}
		if not column.is_empty():
			snapshot["radius"] = maxf(.30, float(column.radius) + .02)
			snapshot["height"] = float(column.height)
		rows.append(snapshot); _poses[id]=at
	for row: Dictionary in rows:
		if not row.steer or row.preferred.length_squared()<.001: continue
		var bias:=false
		for peer: Dictionary in rows:
			if peer.id==row.id or not peer.steer or peer.preferred.length_squared()<.001: continue
			var offset: Vector3=peer.feet-row.feet
			if offset.length()<2.5 and offset.dot(row.preferred)>0 and row.preferred.normalized().dot(peer.preferred.normalized())<-.3: bias=true
		if bias: row.preferred=(row.preferred+Vector3(row.preferred.z,0,-row.preferred.x).normalized()*.12).limit_length(row.max_speed)
	for id in _poses.keys():
		if not seen.has(id): _poses.erase(id)
	_submitted=goals
	if not solver.submit(rows):
		push_error("Public foot traffic rejected an actual body snapshot")
		shutdown()

func propose(route: Node3D, target: Vector3, delta: float) -> Vector3:
	var at: Vector3=route.actor.global_position
	var straight:=at+Vector3(target.x-at.x,0,target.z-at.z).limit_length(delta*route.route_speed)
	if not _configured or _retired: return at
	# A street-side avoidance offset can put a resident outside the oak portal's
	# usable opening. Centre on the approach before stepping toward its jamb.
	# The route's real admission, sweep, peer and solid checks still run.
	if not route._door_passages.is_empty():
		for door: DoorProp in route._door_passages:
			if door.get_meta("semantic_id", "") != "F01_DOOR_06" or not door.is_ready_for_passage(): continue
			var side := float(route._door_passages[door].side)
			var local := door.to_local(at)
			if side * local.z <= 0.0 or door.to_local(target).z * side > 0.0: continue
			var centre := door.width * 0.5
			if absf(local.x - centre) > 0.08:
				var aligned := door.to_global(Vector3(centre, local.y, local.z))
				return at + Vector3(aligned.x-at.x, 0, aligned.z-at.z).limit_length(delta*route.route_speed)
		return straight
	if not _can_steer(route): return straight
	var reply: Dictionary=_proposals.get(route.actor.get_instance_id(),{})
	if reply.is_empty() or Vector3(reply.target).distance_to(target)>.001:
		stats.missing_or_changed+=1; return at
	# Avoidance can orbit a stationary player covering an exact through vertex.
	# Offer the authored approach to the ordinary motor so it can yield, cue
	# and squeeze through with the usual peer and native clearance checks.
	var retained_turn: bool = route.planned_id != route.desired_id and route.path[0] != route.desired_id
	if (route.path.size() > 1 or retained_turn) and at.distance_to(target) < COURTESY_APPROACH_DISTANCE:
		var world: Node3D = _world.get_ref()
		var player: PlayerController = world.player
		if _live(player) and player.velocity.length_squared() < .01:
			var offset := player.global_position - target
			if absf(offset.y) < 1.6 and Vector2(offset.x,offset.z).length() < PLAYER_SEPARATION:
				return straight
	var next: Vector3=at+Vector3(reply.velocity).limit_length(route.route_speed)*delta
	# A valid avoidance reply can stall at an immovable person. Keep collecting
	# only real peer contact; a missing solver reply above never grants passage.
	if (next-at).length() < delta * .1:
		var touching := false
		var permitted := true
		for reference: WeakRef in _bodies:
			var peer := reference.get_ref() as Node3D
			if not _live(peer) or peer == route.actor: continue
			var column := StandingOccupancy.read(peer)
			if column.get("invalid", false): return at
			var base: Vector3 = peer.global_position if column.is_empty() else column.base
			if column.is_empty():
				if absf(base.y-at.y)>1.6: continue
			elif at.y >= base.y + float(column.height) or at.y + 1.65 <= base.y: continue
			var contact := .75 if column.is_empty() else maxf(.75,.28 + float(column.radius) + .04)
			var offset := Vector2(base.x-at.x,base.z-at.z)
			var step := Vector2(straight.x-at.x,straight.z-at.z)
			if (offset-step).length()<contact and offset.dot(step)>0:
				touching = true
				if not route.squeeze.permits(route.actor,peer): permitted = false
		if touching and permitted: next = at+(straight-at).limit_length(delta*.65)
	# Crossing into/out of public space belongs to the authored edge. Never
	# carry lateral avoidance beyond this owner's scope or HOLD at the border.
	if not _inside(next): return straight
	stats.proposals+=1; return next

func clear_step(route: Node3D, next: Vector3) -> bool:
	var at: Vector3=route.actor.global_position
	if not _configured or _retired: return false
	if not (_inside(at,.75) or _inside(next,.75)): return true
	for reference: WeakRef in _bodies:
		var body:=reference.get_ref() as Node3D
		if not _live(body) or body==route.actor: continue
		var column := StandingOccupancy.read(body)
		if column.get("invalid", false): return false
		var base: Vector3 = body.global_position if column.is_empty() else column.base
		if column.is_empty():
			if absf(base.y-next.y)>1.6: continue
		elif next.y >= base.y + float(column.height) or next.y + 1.65 <= base.y: continue
		var separation:=PLAYER_SEPARATION if body is PlayerController else .60
		if not column.is_empty(): separation = maxf(separation,.28 + float(column.radius) + .04)
		var gap:=Vector2(next.x-base.x,next.z-base.z).length()
		var before:=Vector2(at.x-base.x,at.z-base.z).length()
		if gap<separation and gap<=before+.00001 and not route.squeeze.permits(route.actor, body): stats.peer_veto+=1; return false
	var space:=route.get_world_3d().direct_space_state
	var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(next+Vector3.UP*.34,next-Vector3.UP*.5,1))
	if hit.is_empty() or absf(hit.position.y-at.y)>.25: stats.native_veto+=1; return false
	var feet:=Vector3(next.x,hit.position.y,next.z)
	var query:=PhysicsShapeQueryParameters3D.new(); query.shape=route._capsule; query.collision_mask=1; query.exclude=[route.world.player.get_rid()]
	query.transform.origin=at+Vector3.UP*(.25+route._capsule.height*.5); query.motion=feet-at
	var cast:=space.cast_motion(query)
	if cast.size()!=2 or cast[0]<1.0: stats.native_veto+=1; return false
	query.transform.origin+=query.motion; query.motion=Vector3.ZERO
	if not space.intersect_shape(query,1).is_empty(): stats.native_veto+=1; return false
	return true

func note_executed() -> void:
	stats.executed+=1

func shutdown() -> void:
	if _retired: return
	_retired=true; set_physics_process(false); solver.close()
	_proposals.clear(); _submitted.clear(); _routes.clear(); _bodies.clear(); _poses.clear()

func _exit_tree() -> void:
	shutdown()
