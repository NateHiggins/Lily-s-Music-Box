extends RefCounted
## One latched hand, with all values and permission retained by the mechanism.
var player: Node3D
var target: Dictionary = {}
var contact := Vector3.ZERO
var changed := false
var _motion_origin: Variant
var _holder_pose := Transform3D.IDENTITY
var last_hit: Dictionary = {}
var motion_feedback := "grabbed"
var _feedback_pending := false
var _feedback_requested: Variant
var _feedback_frame := 0
var _feedback_limit := false
var _feedback_until := 0
var profiling := false
var profile_records: Array[Dictionary] = []
var _held_depth := 0.0
var _held_body: PhysicsBody3D
var _added_holder_exception := false
var _added_stock_exception := false
var _gesture_axis := Vector2.ZERO

func _record_cost(stage: String, owner_name: String, started: int) -> void:
	if not profiling: return
	profile_records.append({"stage":stage,"owner":owner_name,"ms":float(Time.get_ticks_usec()-started)/1000.0})
	if profile_records.size()>256: profile_records.pop_front()

func _init(holder: Node3D) -> void:
	player = holder

func find_target() -> Dictionary:
	var camera: Camera3D = player.camera
	var cursor: Vector2 = player.get_viewport().get_mouse_position() if player.inspecting() else camera.get_viewport().get_visible_rect().size*.5
	var origin := camera.project_ray_origin(cursor)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(cursor)*2.1)
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	last_hit = hit
	if hit.is_empty(): return {}
	var node: Node = hit.collider
	while node != null:
		if node.has_method("manipulation_target"):
			var result: Dictionary = node.call("manipulation_target",hit)
			if result.get("legacy",false): return {}
			if result.is_empty(): return {"blocked":true}
			var inspection_owner := _context_owner(result,true)
			if player.inspecting() and inspection_owner!=player.inspect_owner: return {"blocked":true}
			if not result.is_empty(): result["hit_position"] = hit.position
			return result
		node = node.get_parent()
	return {}

func _context_owner(descriptor: Dictionary,inspection := false) -> Node3D:
	var owner: Node3D=descriptor.get("owner")
	if owner!=null and not inspection and owner.has_method("interaction_owner_for"): return owner.interaction_owner_for(descriptor.part)
	if owner!=null and owner.has_method("inspection_owner_for"): return owner.inspection_owner_for(descriptor.part)
	return owner

func _same_assembly(hit: Dictionary) -> bool:
	var node: Node=hit.collider
	while node!=null:
		if node.has_method("manipulation_target"):
			var other: Dictionary=node.manipulation_target(hit)
			return not other.is_empty() and _context_owner(other)==_context_owner(target)
		node=node.get_parent()
	return false

func active() -> bool:
	return not target.is_empty()

func holding_pickup() -> bool:
	return active() and target.kind=="free" and bool(target.get("pickup",true)) and not player.inspecting()

func held_physics_body() -> PhysicsBody3D:
	return _held_body if holding_pickup() and is_instance_valid(_held_body) else null

func acquire(candidate: Dictionary) -> bool:
	if active() or candidate.is_empty() or candidate.get("blocked",false): return false
	if not is_instance_valid(candidate.get("part")) or not is_instance_valid(candidate.get("owner")): return false
	var started := Time.get_ticks_usec() if profiling else 0
	if candidate.has("begin") and not candidate.begin.call(): return false
	_record_cost("begin",str(candidate.owner.name),started)
	target = candidate
	_gesture_axis=candidate.get("gesture_screen_axis",Vector2.ZERO)
	if candidate.has("bind_holder"):candidate.bind_holder.call(player)
	contact = target.part.to_local(candidate.hit_position)
	changed = false
	motion_feedback = "grabbed"
	_feedback_pending = false
	_feedback_until = 0
	_motion_origin=target.read.call()
	_held_depth=0.
	_holder_pose=player.global_transform
	_bind_carrier_collision()
	return true

func _bind_carrier_collision() -> void:
	if not holding_pickup() or player is not PhysicsBody3D: return
	var body: Node=target.part
	while body!=null and body is not PhysicsBody3D: body=body.get_parent()
	if body==null or body==player: return
	_held_body=body as PhysicsBody3D
	var holder:=player as PhysicsBody3D
	_added_holder_exception=not holder.get_collision_exceptions().has(_held_body)
	_added_stock_exception=not _held_body.get_collision_exceptions().has(holder)
	if _added_holder_exception: holder.add_collision_exception_with(_held_body)
	if _added_stock_exception: _held_body.add_collision_exception_with(holder)

func _unbind_carrier_collision() -> void:
	if is_instance_valid(_held_body) and is_instance_valid(player):
		var holder:=player as PhysicsBody3D
		if holder!=null:
			if _added_holder_exception: holder.remove_collision_exception_with(_held_body)
			if _added_stock_exception: _held_body.remove_collision_exception_with(holder)
	_held_body=null;_added_holder_exception=false;_added_stock_exception=false

func follow_holder() -> void:
	var previous := _holder_pose
	_holder_pose=player.global_transform
	if not active() or target.kind!="free" or player.inspecting(): return
	validate()
	if not active(): return
	if holding_pickup():
		var hold: Variant=target.get("hold_pose")
		var view: Transform3D=player.camera.global_transform.translated_local(Vector3(0,0,-_held_depth))
		if hold is Callable and hold.is_valid(): hold.call(view)
		else:
			# Free stock shares the existing owner's constrained setter. A
			# tether, pilot, wall or stop may keep it short of the hand pose.
			var point: Vector3=target.part.to_global(contact)
			var motion: Vector3=(view*Vector3(.17,-.16,-.48)-point).limit_length(.06)
			if motion.length_squared()>1e-10:
				var before: Vector3=target.read.call()
				var request: Vector3=before+target.frame.global_basis.inverse()*motion
				target.write.call(request)
				# Continuous hand-follow must retain the last published result;
				# replacing it with optimistic feedback every tick hides stops.
				_expect_motion(request,false,true)
		_observe_motion()
		return
	var point: Vector3=target.part.to_global(contact)
	var motion: Vector3=_holder_pose*previous.affine_inverse()*point-point
	if motion.length()>.5:
		release()
		return
	if motion.length_squared()<1e-12: return
	var before: Vector3=target.read.call()
	target.write.call(before+target.frame.global_basis.inverse()*motion)
	if not before.is_equal_approx(target.read.call()): changed=true
	validate()

func release(notify_change := true) -> void:
	if not active(): return
	_observe_motion()
	var old := target
	var accepted_change:=changed
	_unbind_carrier_collision()
	target = {}
	_feedback_pending = false
	changed=false
	if is_instance_valid(old.get("owner")):
		var started := Time.get_ticks_usec() if profiling else 0
		var owner_name := str(old.owner.name)
		if old.has("owns") and not old.owns.call(): changed=false;return
		if old.has("end"): old.end.call()
		_record_cost("end",owner_name,started)
		if accepted_change and notify_change:
			var origin: Vector3=old.owner.global_position
			var resolve: Variant=old.get("change_origin")
			if resolve is Callable and resolve.is_valid():
				var physical: Variant=resolve.call()
				if physical is Vector3 and physical.is_finite(): origin=physical
			started=Time.get_ticks_usec() if profiling else 0
			player.world_modified.emit(origin, str(old.owner.name))
			_record_cost("world_modified",owner_name,started)
	changed = false

func _observe_motion() -> void:
	# AnimatableBody3D may publish an accepted transform on the next physics
	# tick. Observe the real readback, not just the immediate setter result.
	if not active() or not is_instance_valid(target.get("part")) or not is_instance_valid(target.get("owner")) or not is_instance_valid(target.get("frame")):return
	var current: Variant=target.read.call()
	if current is Vector3 and _motion_origin is Vector3:
		changed=changed or not current.is_equal_approx(_motion_origin)
	elif typeof(current) in [TYPE_FLOAT,TYPE_INT] and typeof(_motion_origin) in [TYPE_FLOAT,TYPE_INT]:
		changed=changed or not is_equal_approx(float(current),float(_motion_origin))
	# Read back the owner's accepted value after physics publishes moving bodies.
	# No extra sweep or collision query belongs to the indicator.
	var pending: Variant=target.get("motion_pending")
	if pending is Callable and pending.is_valid() and bool(pending.call()):
		motion_feedback="grabbed"
		return
	if _feedback_pending and Engine.get_physics_frames() > _feedback_frame:
		var accepted: bool = current.is_equal_approx(_feedback_requested) if current is Vector3 else absf(float(current)-float(_feedback_requested)) < .0001
		motion_feedback = ("limit" if _feedback_limit else "grabbed") if accepted else "blocked"
		_feedback_pending = false
		_feedback_until = Time.get_ticks_msec()+250
	elif not _feedback_pending and Time.get_ticks_msec() > _feedback_until:
		motion_feedback = "grabbed"

func _expect_motion(requested: Variant, at_limit := false, retain_feedback := false) -> void:
	_feedback_requested = requested
	_feedback_limit = at_limit
	_feedback_frame = Engine.get_physics_frames()
	_feedback_pending = true
	if not retain_feedback:motion_feedback = "limit" if at_limit else "grabbed"

func feedback(aimed: Dictionary) -> Dictionary:
	var descriptor := target if active() else aimed
	var owner := _context_owner(descriptor, true)
	if not active() and descriptor.get("blocked",false) and descriptor.get("fixed_stock",false):
		return {"state":"idle","inspectable":false}
	var state: String=motion_feedback if active() else "available" if descriptor.get("part") is Node3D else "blocked" if descriptor.get("blocked",false) else "idle"
	# Some free mechanisms accept a swept proposal in two phases. Their
	# authoritative result is available before physics publishes a transform.
	# Read that same result at presentation; do not scan or infer another hit.
	var constraint: Variant=descriptor.get("constraint_feedback")
	if active() and constraint is Callable and constraint.is_valid():
		var observed: Variant=constraint.call()
		if observed is String and observed in ["grabbed","blocked","limit"]:state=observed
	return {"state":state,
		"inspectable":is_instance_valid(owner) and owner.has_method("inspection_view")}

func validate() -> void:
	if not active(): return
	if not is_instance_valid(target.get("owner")) or not is_instance_valid(target.get("part")) or not is_instance_valid(target.get("frame")):
		release()
		return
	if target.has("owns") and not target.owns.call():
		target={};changed=false
		return
	_observe_motion()
	var reach: Vector3=target.reach_point.call() if target.has("reach_point") else target.part.to_global(contact)
	if player.call_locked or player.mouse_released \
			or (not player.touch_input and not player.inspecting() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED) \
			or not target.part.is_inside_tree() \
			or player.camera.global_position.distance_to(reach) > 2.4:
		release()
		return
	# A held pickup may be occluded when its swept hand pose meets a wall.
	# Keep possession and let the owner's physical constraint stop it. Reach,
	# cancellation and ownership checks above still apply.
	if holding_pickup() or target.get("unobstructed_hold",false): return
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,target.part.to_global(contact))
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != target.owner and not target.owner.is_ancestor_of(hit.collider) and not _same_assembly(hit): release()

func move(relative: Vector2) -> void:
	validate()
	if not active() or not relative.is_finite(): return
	if holding_pickup():
		player.apply_look(relative)
		return
	var camera: Camera3D = player.camera
	var part: Node3D = target.part
	var frame: Node3D = target.frame
	if target.kind == "free":
		var point: Vector3=part.to_global(contact)
		if camera.is_position_behind(point): release();return
		var depth: float=-camera.to_local(point).z
		var screen: Vector2=camera.unproject_position(point)
		var displacement: Vector3=camera.project_position(screen+relative,depth)-point
		displacement=displacement.limit_length(.08)
		var before: Vector3=target.read.call()
		var started := Time.get_ticks_usec() if profiling else 0
		target.write.call(before+frame.global_basis.inverse()*displacement)
		_record_cost("free_motion",str(target.owner.name),started)
		_expect_motion(before+frame.global_basis.inverse()*displacement)
		if not before.is_equal_approx(target.read.call()): changed=true
		return
	var local_axis: Vector3 = target.axis.call() if target.axis is Callable else target.axis
	var axis: Vector3 = (frame.global_basis * local_axis).normalized()
	var point: Vector3 = part.to_global(contact)
	var tangent: Vector3 = axis
	if target.kind == "hinge":
		tangent = axis.cross(point-part.global_position)
		# A click on the centre of a small knob still has a useful lever arm.
		if tangent.length() < float(target.get("minimum_lever",.025)):
			tangent = axis.cross(camera.global_basis.x)*.06
			if tangent.length() < .01: tangent = axis.cross(camera.global_basis.y)*.06
	if camera.is_position_behind(point):
		release()
		return
	var screen_axis := (camera.unproject_position(point+tangent*.01)-camera.unproject_position(point))/.01
	# A closed leaf viewed face-on initially moves into/out of the screen.
	# Pulling down/pushing up supplies that otherwise invisible depth component.
	if screen_axis.length() < 24.0 and absf(tangent.dot(camera.global_basis.z)) > tangent.length()*.5:
		screen_axis = Vector2(0,tangent.dot(camera.global_basis.z)*180.0)
	if screen_axis.length_squared() < .01: return
	var step := relative.dot(screen_axis)/screen_axis.length_squared()
	var gesture_pixels: float=float(target.get("gesture_travel_px",0.))
	var gesture_range: float=float(target.maximum)-float(target.minimum)
	if gesture_pixels>0.:
		if not is_finite(gesture_pixels) or gesture_pixels<1. or not is_finite(gesture_range) or gesture_range<=0.:return
		# A long or bent rail can share one bounded gesture. Keep its initial
		# screen direction so crossing a rail corner does not reverse the hand.
		if _gesture_axis.is_zero_approx():_gesture_axis=screen_axis.normalized()
		step=relative.dot(_gesture_axis)*gesture_range/gesture_pixels
	var motion_scale: float=float(target.get("motion_scale",1.0))
	if not is_finite(motion_scale) or motion_scale<=0.:return
	step*=motion_scale
	var limit := .24 if target.kind == "hinge" else .08
	if gesture_pixels>0.:limit=gesture_range*.24
	step = clampf(step,-limit,limit)
	var before: float = target.read.call()
	var value := clampf(before+step,float(target.minimum),float(target.maximum))
	if is_zero_approx(step): return
	_expect_motion(value, not is_equal_approx(value,before+step))
	if is_equal_approx(value,before): return
	var started := Time.get_ticks_usec() if profiling else 0
	target.write.call(value)
	_record_cost("constrained_motion",str(target.owner.name),started)
	if not is_equal_approx(float(target.read.call()),before): changed = true

func move_depth(distance: float) -> bool:
	validate()
	if not active() or target.kind!="free" or not is_finite(distance): return false
	if holding_pickup():
		_held_depth=clampf(_held_depth+clampf(distance,-.08,.08),-.12,.35)
		return true
	var point: Vector3=target.part.to_global(contact)
	var axis: Vector3=(point-player.camera.global_position).normalized()
	var before: Vector3=target.read.call()
	target.write.call(before+target.frame.global_basis.inverse()*axis*clampf(distance,-.08,.08))
	_expect_motion(before+target.frame.global_basis.inverse()*axis*clampf(distance,-.08,.08))
	if not before.is_equal_approx(target.read.call()): changed=true
	return true
