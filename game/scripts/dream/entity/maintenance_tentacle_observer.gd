extends Node
## One rare encounter per task per loaded waking world. No new save facts.
const Gang = preload("res://scripts/dream/entity/maintenance_tentacle_gang.gd")
var building: Node
var player: Node3D
var orders: WorkOrders
var encounter: Node3D
var consumed: Dictionary = {}
var task_id := ""
var _due := 0.0
var frequency_divisor := 17
var _doors: Array[WeakRef] = []
var _doors_scanned := false
var anchor_diagnostics: Array[Dictionary] = []
var preparation: Node3D

func _reject_anchor(reason: String, point: Vector3, detail := "") -> void:
	anchor_diagnostics.append({"reason":reason,"point":[point.x,point.y,point.z],"detail":detail})

func setup(world: Node, observer: Node3D, authority: WorkOrders) -> void:
	building = world
	player = observer
	orders = authority
	preparation = Gang.new()
	preparation.name = "PreparedTentacleResources"
	add_child(preparation)
	preparation.prepare_render_resources()
	building.get_tree().node_added.connect(_observe_door)

func _observe_door(node: Node) -> void:
	if node is DoorProp: _doors.append(weakref(node))

func _door_sweeps_clear(at: Vector3) -> bool:
	if not _doors_scanned:
		_doors_scanned = true
		for node in building.find_children("*","Node3D",true,false): _observe_door(node)
	for reference in _doors:
		var door := reference.get_ref() as DoorProp
		if door == null or not building.is_ancestor_of(door): continue
		var hinge: Vector3 = door._body.global_position if is_instance_valid(door._body) else door.global_position
		if at.y > hinge.y+door.height or at.y+.85 < hinge.y: continue
		var horizontal := Vector2(at.x-hinge.x,at.z-hinge.z)
		if horizontal.length() < door.width+.50: return false
	return true

func _physics_process(delta: float) -> void:
	_due -= delta
	if _due > 0: return
	_due = .4
	if not is_instance_valid(player) or not is_instance_valid(orders):
		_cancel()
		return
	if RealityState.save_write_blocked:
		_cancel()
		return
	if is_instance_valid(encounter):
		if encounter.phase == Gang.Phase.CLEARED:
			encounter.queue_free()
			encounter = null
		elif orders.job_stage(task_id) == "missing" or not is_instance_valid(encounter.target) or not encounter.target.is_visible_in_tree():
			_cancel()
		return
	if player.get("call_locked") == true or player.get("mouse_released") == true: return
	if player.get("_grab") != null and player._grab.active(): return
	if orders.job_library == null: return
	var jobs: Dictionary = RealityState.data.get("maintenance_jobs",{})
	var ids := jobs.keys()
	ids.sort()
	for id in ids:
		if consumed.has(id) or orders.job_stage(str(id)) not in ["acknowledged","diagnosed","awaiting_part","repairable"]: continue
		var specification := orders.job_library.job(str(id))
		var target_id := str(specification.get("repair_target_id",""))
		if target_id.is_empty(): continue
		var mechanism := building.find_child(target_id,true,false) as Node3D
		if not is_instance_valid(mechanism) or not mechanism.is_visible_in_tree(): continue
		if player.global_position.distance_to(mechanism.global_position) > 2.0: continue
		var seed_id := (str(id)+":"+target_id).hash()
		if posmod(seed_id,maxi(frequency_divisor,1)) != 0: continue
		var anchor := choose_anchor(mechanism,seed_id)
		if anchor.is_empty(): continue
		encounter = Gang.new()
		building.add_child(encounter)
		var atmosphere := building.get_node_or_null("LampAtmosphere")
		var field: RefCounted = atmosphere.field if atmosphere != null else null
		if encounter.start(mechanism,player,anchor.transform,seed_id,field):
			consumed[id] = true
			task_id = str(id)
		else:
			encounter.queue_free()
			encounter = null
		return

func choose_anchor(mechanism: Node3D, seed_id: int) -> Dictionary:
	anchor_diagnostics.clear()
	var space := mechanism.get_world_3d().direct_space_state
	for offset in 8:
		var angle := TAU*float(posmod(seed_id+offset,8))/8.0
		var near := mechanism.global_position+Vector3(cos(angle)*.5,.15,sin(angle)*.5)
		# Many V2 repair owners are chest-height markers, not floor origins.
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(near+Vector3.UP*.4,near-Vector3.UP*2.1))
		if floor_hit.is_empty() or (floor_hit.normal as Vector3).dot(Vector3.UP)<.95:
			_reject_anchor("support",near)
			continue
		var at: Vector3 = floor_hit.position
		if not _door_sweeps_clear(at):
			_reject_anchor("door_sweep",at)
			continue
		var hand := at+Vector3.UP*.65
		# Reserve a complete cylinder, including the shared root and all tips.
		# Existing controls, doors, held objects and player bodies reject it.
		if player.global_position.distance_to(at)<.60 or player.global_position.distance_to(hand)>1.8:
			_reject_anchor("reach_or_player",at,str(player.global_position))
			continue
		var shape := CylinderShape3D.new()
		shape.radius = .30
		shape.height = .85
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*.44)
		query.collide_with_areas = true
		var overlaps := space.intersect_shape(query,4)
		if not overlaps.is_empty():
			var paths: Array[String] = []
			for overlap in overlaps: paths.append(str(overlap.collider.get_path()))
			_reject_anchor("occupied",at,", ".join(paths))
			continue
		var eye: Node3D = player.get("camera")
		var eye_point: Vector3 = eye.global_position if is_instance_valid(eye) else player.global_position+Vector3.UP*1.3
		var sight := PhysicsRayQueryParameters3D.create(eye_point,hand)
		if player is CollisionObject3D: sight.exclude = [player.get_rid()]
		var obstruction := space.intersect_ray(sight)
		if not obstruction.is_empty():
			_reject_anchor("occluded",at,str(obstruction.collider.get_path()))
			continue
		return {"transform":Transform3D(Basis.IDENTITY,at),"radius":.3,"emergence":"temporary_membrane_pore"}
	return {}

func _cancel() -> void:
	if is_instance_valid(encounter):
		encounter.cleanup()
		encounter.queue_free()
	encounter = null

func _exit_tree() -> void:
	if is_instance_valid(building) and building.is_inside_tree() and building.get_tree().node_added.is_connected(_observe_door):
		building.get_tree().node_added.disconnect(_observe_door)
	_cancel()
