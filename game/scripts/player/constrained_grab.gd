extends RefCounted
## One latched hand, with all values and permission retained by the mechanism.
var player: Node3D
var target: Dictionary = {}
var contact := Vector3.ZERO
var changed := false
var _holder_pose := Transform3D.IDENTITY

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

func acquire(candidate: Dictionary) -> bool:
	if active() or candidate.is_empty() or candidate.get("blocked",false): return false
	if not is_instance_valid(candidate.get("part")) or not is_instance_valid(candidate.get("owner")): return false
	if candidate.has("begin") and not candidate.begin.call(): return false
	target = candidate
	contact = target.part.to_local(candidate.hit_position)
	changed = false
	_holder_pose=player.global_transform
	return true

func follow_holder() -> void:
	var previous := _holder_pose
	_holder_pose=player.global_transform
	if not active() or target.kind!="free" or player.inspecting(): return
	validate()
	if not active(): return
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
	var old := target
	target = {}
	if is_instance_valid(old.get("owner")):
		if old.has("owns") and not old.owns.call(): changed=false;return
		if old.has("end"): old.end.call()
		if changed and notify_change:
			player.world_modified.emit(old.owner.global_position, str(old.owner.name))
	changed = false

func validate() -> void:
	if not active(): return
	if not is_instance_valid(target.get("owner")) or not is_instance_valid(target.get("part")) or not is_instance_valid(target.get("frame")):
		release()
		return
	if target.has("owns") and not target.owns.call():
		target={};changed=false
		return
	if player.call_locked or player.mouse_released \
			or (not player.touch_input and not player.inspecting() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED) \
			or not target.part.is_inside_tree() \
			or player.camera.global_position.distance_to(target.part.to_global(contact)) > 2.4:
		release()
		return
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,target.part.to_global(contact))
	query.collide_with_areas = true
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider != target.owner and not target.owner.is_ancestor_of(hit.collider) and not _same_assembly(hit): release()

func move(relative: Vector2) -> void:
	validate()
	if not active() or not relative.is_finite(): return
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
		target.write.call(before+frame.global_basis.inverse()*displacement)
		if not before.is_equal_approx(target.read.call()): changed=true
		return
	var local_axis: Vector3 = target.axis.call() if target.axis is Callable else target.axis
	var axis: Vector3 = (frame.global_basis * local_axis).normalized()
	var point: Vector3 = part.to_global(contact)
	var tangent: Vector3 = axis
	if target.kind == "hinge":
		tangent = axis.cross(point-part.global_position)
		# A click on the centre of a small knob still has a useful lever arm.
		if tangent.length() < .025:
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
	var motion_scale: float=float(target.get("motion_scale",1.0))
	if not is_finite(motion_scale) or motion_scale<=0.:return
	step*=motion_scale
	var limit := .24 if target.kind == "hinge" else .08
	step = clampf(step,-limit,limit)
	var before: float = target.read.call()
	var value := clampf(before+step,float(target.minimum),float(target.maximum))
	if is_equal_approx(value,before): return
	target.write.call(value)
	if not is_equal_approx(float(target.read.call()),before): changed = true

func move_depth(distance: float) -> bool:
	validate()
	if not active() or target.kind!="free" or not is_finite(distance): return false
	var point: Vector3=target.part.to_global(contact)
	var axis: Vector3=(point-player.camera.global_position).normalized()
	var before: Vector3=target.read.call()
	target.write.call(before+target.frame.global_basis.inverse()*axis*clampf(distance,-.08,.08))
	if not before.is_equal_approx(target.read.call()): changed=true
	return true
