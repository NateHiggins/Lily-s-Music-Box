extends Node
## Visit-local presentation adapter. All gameplay authorities are read-only.
const Route = preload("res://scripts/dream/critters/guide_bell_route.gd")
const Bell = preload("res://scripts/dream/critters/guide_bell.gd")
const CAP := 8
var building: Node3D
var player: Node3D
var orders: WorkOrders
var provider: RefCounted
var path := PackedVector3Array()
var bells: Array[Node3D] = []
var consumed: Dictionary = {}
var task_id := ""
var target: Node3D
var target_anchor := Vector3.INF
var remaining := INF
var _due := 0.0
var _check_due := 0.0
var _doors: Array[WeakRef] = []
var retired: Array[Dictionary] = []
var route_revision := 0
var _target_position := Vector3.INF
var _target_key := ""

func setup(root: Node3D,observer: Node3D,authority: WorkOrders) -> void:
	building=root; player=observer; orders=authority
	provider=Route.new(); provider.setup(root,observer)
	for node in root.find_children("*","Node3D",true,false): _node_added(node)
	root.get_tree().node_added.connect(_node_added)
	orders.job_stage_changed.connect(_job_changed)

func _node_added(node: Node) -> void:
	if node is DoorProp: _doors.append(weakref(node))

func _job_changed(_id: String,_from: String,_to: String,_state: Dictionary) -> void:
	_due=0
	if not task_id.is_empty() and orders.job_stage(task_id) not in ["acknowledged","diagnosed","awaiting_part","repairable"]: _clear("task_ended")

func active_task() -> String:
	if orders==null or orders.job_library==null: return ""
	var preferred := str(RealityState.data.get("first_shift",{}).get("report_id",""))
	var candidates: Array[String] = []
	for id in RealityState.data.get("maintenance_jobs",{}):
		var stage := orders.job_stage(str(id))
		if stage not in ["acknowledged","diagnosed","awaiting_part","repairable"]: continue
		# These authors explicitly require discovery/evidence before assistance.
		if str(id)=="vantry_chirp_2a" and stage=="acknowledged": continue
		var spec := orders.job_library.job(str(id))
		if str(spec.get("repair_target_id","")).is_empty(): continue
		if spec.get("directional_assistance",false)!=true: continue
		candidates.append(str(id))
	if preferred in candidates: return preferred
	# With several open tasks and no authoritative selection, do not choose one.
	return candidates[0] if candidates.size()==1 else ""

func _physics_process(delta: float) -> void:
	if provider==null: return
	if not is_instance_valid(building) or building.is_queued_for_deletion() or not is_instance_valid(player) or RealityState.save_write_blocked:
		_clear("world_unavailable"); return
	if player.get("call_locked")==true or player.get("mouse_released")==true:
		_clear("scripted_presentation"); return
	var selected := active_task()
	if selected!=task_id: _clear("target_changed"); task_id=selected; _due=0
	if task_id.is_empty(): return
	if target!=null and (not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree()):
		_clear("target_unloaded"); return
	_due-=delta; _check_due-=delta
	var refresh:=_due<=0
	if _due<=0:
		_due=.8
		var id := str(orders.job_library.job(task_id).get("repair_target_id",""))
		var resolved:=target
		if task_id=="vantry_chirp_2a" and is_instance_valid(building.vantry_points):
			resolved=building.vantry_points.active_owner
		elif not is_instance_valid(target) or id!=_target_key:
			resolved=building.find_child(id,true,false) as Node3D
		if resolved!=target:
			_clear_trail("physical_target_changed"); target=resolved
		_target_key=id
		if target==null: return
		if _target_position!=target.global_position:
			_clear_trail("target_anchor_changed"); _target_position=target.global_position
		if path.is_empty(): _rebuild()
	if path.is_empty(): return
	var projection := Route.project(path,player.global_position)
	if projection.is_empty() or float(projection.gap)>1.2 or not provider.supported(player.global_position,projection.point):
		if refresh: _rebuild()
		return
	remaining=float(projection.remaining)
	if _check_due<=0:
		_check_due=.4
		for i in range(int(projection.segment),path.size()-1):
			if not provider.supported(path[i],path[i+1]): _clear_trail("route_blocked"); return
		for bell in bells:
			bell.colony_alarm=0.0
			for controller in building.get_children():
				if not controller.has_method("bind_companion") or controller.get("critters") is not Array: continue
				for specimen: Dictionary in controller.critters:
					if int(specimen.morph.kind)==3 and (specimen.pos as Vector3).distance_to(bell.global_position)<1.1:
						bell.colony_alarm=1.0
	for i in range(bells.size()-1,-1,-1):
		var bell= bells[i]
		bell.update_progress(true,remaining,delta,remaining<1.0)
		if bell.state>=Bell.State.WILTING: consumed[_key(bell.route_coordinate)]=true
		if bell.state==Bell.State.CLEARED:
			retired.append(bell.census()); bell.queue_free(); bells.remove_at(i)
	while retired.size()>64: retired.pop_front()
	if refresh and remaining>2.5: _populate()

func _key(point: Vector3) -> String:
	return task_id+":"+str(_target_position)+":"+str(Vector3(roundf(point.x*2),roundf(point.y*2),roundf(point.z*2)))

func _rebuild() -> void:
	# Derive a supported stance near the physical repair owner, not its elevated
	# handle location. The provider proves the complete final approach too.
	var best := PackedVector3Array()
	var focus:=target.global_position
	if target.has_method("inspection_view"):
		var view: Dictionary=target.inspection_view()
		focus=view.get("at",focus)
	for offset in [Vector3(.8,0,0),Vector3(-.8,0,0),Vector3(0,0,.8),Vector3(0,0,-.8)]:
		var p: Vector3=focus+offset
		var ground: Dictionary=provider.ray(p+Vector3.UP*.4,p-Vector3.UP*2.5)
		if ground.is_empty() or ground.normal.y<.9: continue
		var candidate: Vector3=ground.position+Vector3.UP*.035
		var sight: Dictionary=provider.ray(candidate+Vector3.UP*.8,focus)
		if not sight.is_empty() and sight.collider!=target and not target.is_ancestor_of(sight.collider): continue
		var proposed: PackedVector3Array=provider.request(player.global_position,candidate)
		if proposed.size()>1:
			best=proposed; break
	if best.is_empty():
		_clear_trail("no_supported_revision")
		return
	path=best; target_anchor=path[-1]; route_revision+=1
	_target_position=target.global_position
	var total := Route.length(path)
	for bell in bells:
		if bell.state>=Bell.State.WILTING: continue
		var projection:=Route.project(path,bell.route_coordinate)
		if projection.is_empty() or float(projection.gap)>.2:
			bell.retire("outside_revised_route"); continue
		bell.remaining_to_target_m=float(projection.remaining)
		bell.route_revision=route_revision
		if bell.state==Bell.State.PASSED_PENDING: bell.update_progress(true,total,0.0)
		var next: Vector3=path[mini(int(projection.segment)+1,path.size()-1)]
		if not provider.ray(bell.global_position+Vector3.UP*.35,next+Vector3.UP*.35).is_empty():
			bell.retire("revised_direction_occluded"); continue
		bell.direction_target=next
	bells.sort_custom(func(a,b): return a.remaining_to_target_m>b.remaining_to_target_m)
	remaining=total
	_populate()

func _populate() -> void:
	var total:=Route.length(path)
	if total<2.5: return
	var travelled := 0.0; var last := -3.0
	for i in range(1,path.size()):
		var segment_length:=path[i-1].distance_to(path[i])
		travelled+=segment_length
		if bells.size()>=CAP: break
		if segment_length<.8: continue
		var incoming := (path[i]-path[i-1]).normalized()
		var final := i==path.size()-1
		var outgoing := (path[i+1]-path[i]).normalized() if not final else incoming
		if not final and incoming.dot(outgoing)>.94: continue
		var decision_consumed:=false
		for setback: float in [.65,1.15,1.65]:
			if consumed.has(_key(path[i]-incoming*setback)): decision_consumed=true; break
		if decision_consumed: continue
		# Try a few nearby seams before the decision; furnishing can occupy one.
		for setback: float in [.65,1.15,1.65]:
			if segment_length<setback+.35: continue
			var coordinate := path[i]-incoming*setback
			var progress := travelled-setback
			if progress<1.0 or progress-last<2.75 or consumed.has(_key(coordinate)): continue
			if total-progress>=remaining-Bell.PASS_MARGIN: continue
			var occupied:=false
			for existing in bells:
				if absf(existing.remaining_to_target_m-(total-progress))<2.75: occupied=true; break
			if occupied: continue
			var anchor := surface_anchor(coordinate,incoming)
			if anchor.is_empty(): continue
			var direction := path[i] if not final else target_anchor
			# Do not aim a surface-mounted organism through a wall to the waypoint.
			if not provider.ray(anchor.position+Vector3.UP*.35,direction+Vector3.UP*.35).is_empty(): continue
			var bell := Bell.new(); add_child(bell)
			var atmosphere := building.get_node_or_null("LampAtmosphere")
			var field: RefCounted=atmosphere.field if atmosphere!=null else null
			var encounter_seed: String=str(RealityState.data.get("dream_seed",""))
			if bell.start(anchor,total-progress,direction,(encounter_seed+_key(coordinate)).hash(),progress/total,field):
				bell.route_revision=route_revision
				bells.append(bell); last=progress
				break
			else: bell.queue_free()
	bells.sort_custom(func(a,b): return a.remaining_to_target_m>b.remaining_to_target_m)

func surface_anchor(coordinate: Vector3,forward: Vector3) -> Dictionary:
	if absf(forward.y)>.2: return {} # landings only, never player stair treads
	var side := Vector3(forward.z,0,-forward.x).normalized()
	for sign_value in [-1.0,1.0]:
		var near := coordinate+Vector3.UP*.2
		var wall: Dictionary=provider.ray(near,near+side*sign_value*2.5)
		if wall.is_empty() or not wall.collider is StaticBody3D or absf(wall.normal.y)>.15: continue
		var base: Vector3=wall.position+wall.normal*.28
		var floor_hit: Dictionary=provider.ray(base+Vector3.UP*.15,base-Vector3.UP*.5)
		if floor_hit.is_empty() or floor_hit.normal.y<.95 or not floor_hit.collider is StaticBody3D: continue
		var at: Vector3=floor_hit.position
		if absf(at.y-(coordinate.y-.035))>.10: continue
		# Reserve the route's player capsule plus the fully leaning bell, even
		# though presentation owns no blocker. Narrow treads/seams simply abstain.
		if Vector2(at.x-coordinate.x,at.z-coordinate.z).length()<.75: continue
		var clear := true
		for ref in _doors:
			var door := ref.get_ref() as DoorProp
			if door==null or not building.is_ancestor_of(door): continue
			var d: Vector3=at-door.global_position
			if absf(d.y)<door.height and Vector2(d.x,d.z).length()<door.width+.35: clear=false; break
		if not clear: continue
		var shape := SphereShape3D.new(); shape.radius=.20
		var query := PhysicsShapeQueryParameters3D.new(); query.shape=shape
		query.collide_with_areas=true
		query.transform.origin=at+Vector3.UP*.4; query.exclude=provider.exclude
		if not building.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		if not provider.ray(coordinate+Vector3.UP*1.2,at+Vector3.UP*.45).is_empty(): continue
		return {"owner":floor_hit.collider,"position":at,"coordinate":coordinate}
	return {}

func _clear_trail(why: String) -> void:
	for bell in bells:
		bell.clear_immediately(why); retired.append(bell.census()); bell.queue_free()
	bells.clear(); path.clear(); remaining=INF

func _clear(why: String) -> void:
	_clear_trail(why); target=null; target_anchor=Vector3.INF; task_id=""
	_target_position=Vector3.INF; _target_key=""

func census() -> Dictionary:
	var records: Array=[]
	for bell in bells: records.append(bell.census())
	return {"task_id":task_id,"target_anchor":[target_anchor.x,target_anchor.y,target_anchor.z] if target_anchor.is_finite() else [],"route_revision":route_revision,
		"route_length":Route.length(path),"player_remaining_distance":remaining if is_finite(remaining) else null,"crumbs":records,
		"retired":retired.duplicate(true),"consumed_count":consumed.size()}

func _exit_tree() -> void:
	_clear("scene_teardown"); provider=null; _doors.clear(); consumed.clear()
