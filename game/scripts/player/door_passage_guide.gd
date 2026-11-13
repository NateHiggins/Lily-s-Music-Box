extends RefCounted
## Directional assistance only. The player's ordinary capsule, gravity and
## move_and_slide remain authoritative; this owner never assigns a transform.
var door: DoorProp
var side := 0.0
var phase := ""
var mark := Vector3.ZERO
var revision := -1
var suppressed: WeakRef
var last_position := Vector3.INF
var blocked_seconds := 0.0
var holder: WeakRef

func reset() -> void:
	if is_instance_valid(door) and holder != null and is_instance_valid(holder.get_ref()):
		door.release_passage(holder.get_ref())
	door = null; phase = ""; revision = -1
	holder = null
	last_position = Vector3.INF; blocked_seconds = 0.0

func active() -> bool:
	return is_instance_valid(door)

func _cancel_manual() -> void:
	if is_instance_valid(door): suppressed = weakref(door)
	reset()

func steer(player: CharacterBody3D, intent: Vector3, delta: float, speed: float) -> Vector3:
	intent.y = 0.0
	var radius: float = player.get("_capsule").radius
	if intent.length_squared() < 0.01:
		reset(); suppressed = null; return intent
	if not active():
		_find_door(player, intent, radius)
	if not active(): return intent
	var local_intent := door.global_basis.inverse() * intent
	# Reversing or deliberately walking along the opening immediately hands
	# movement back. Camera look is never redirected or captured by this owner.
	if local_intent.z * side >= -0.12:
		reset(); suppressed = null; return intent
	if not door.passage_allowed() or not door.is_inside_tree():
		_cancel_manual(); return intent
	if revision != door.motion_revision:
		_cancel_manual(); return intent
	holder = weakref(player)
	door.hold_passage(player)
	if last_position != Vector3.INF and phase != "opening":
		if player.global_position.distance_to(last_position) < 0.001:
			blocked_seconds += delta
		else: blocked_seconds = 0.0
		if blocked_seconds > 1.0:
			_cancel_manual(); return intent
	last_position = player.global_position
	var local := door.to_local(player.global_position)
	if phase == "align":
		if Vector2(local.x - mark.x, local.z - mark.z).length() > 0.055:
			return _toward(player, intent, delta, speed)
		phase = "opening"
	if phase == "opening":
		if not door.request_passage(player): return Vector3.ZERO
		revision = door.motion_revision
		if not door.is_ready_for_passage() or absf(door._body.rotation.y - door.motion_target_angle(true)) > 0.03:
			return Vector3.ZERO
		phase = "crossing"; blocked_seconds = 0.0
		mark = Vector3(door.width * 0.5, local.y, -side * _clear_depth(door, -side, radius))
	if phase == "crossing":
		if local.z * side <= -absf(mark.z) + 0.06:
			reset(); return intent
		return _toward(player, intent, delta, speed)
	return intent

func _find_door(player: CharacterBody3D, intent: Vector3, radius: float) -> void:
	var best := INF
	for item: Node in player.get_tree().get_nodes_in_group("passage_doors"):
		var candidate := item as DoorProp
		if candidate == null or candidate.get_world_3d() != player.get_world_3d() or not candidate.is_visible_in_tree(): continue
		if suppressed != null and suppressed.get_ref() == candidate: continue
		if candidate.width < radius * 2.0 + 0.04: continue
		if candidate.height < float(player.get("_capsule").height) + 0.02: continue
		var at := candidate.to_local(player.global_position)
		if absf(at.y) > 0.35 or absf(at.z) > candidate.width + radius + 0.6: continue
		if at.x < -0.25 or at.x > candidate.width + 0.25: continue
		var wish := candidate.global_basis.inverse() * intent
		var incoming := signf(at.z) if absf(at.z) > 0.04 else -signf(wish.z)
		if is_zero_approx(incoming) or wish.z * incoming >= -0.35: continue
		# Movement must actually aim through this aperture, not along a nearby wall.
		var crossing_x := at.x - at.z * wish.x / wish.z
		if crossing_x < -0.1 or crossing_x > candidate.width + 0.1: continue
		if not candidate.passage_allowed(): continue
		var distance := Vector2(at.x - candidate.width * 0.5, at.z).length_squared()
		if distance >= best: continue
		var wait_mark := Vector3(candidate.width * 0.5, at.y, incoming * _clear_depth(candidate, incoming, radius))
		var exit_mark := Vector3(candidate.width * 0.5, at.y, -incoming * _clear_depth(candidate, -incoming, radius))
		if not _supported(player, candidate.to_global(exit_mark)): continue
		if not candidate.is_ready_for_passage() and not _supported(player, candidate.to_global(wait_mark)): continue
		best = distance; door = candidate; side = incoming
		phase = "align"; revision = candidate.motion_revision
		mark = wait_mark
		# An already open leaf needs no retreat to make room for its swing.
		if candidate.is_ready_for_passage() and absf(candidate._body.rotation.y - candidate.motion_target_angle(true)) < 0.03:
			phase = "opening"

func _clear_depth(leaf: DoorProp, incoming: float, radius: float) -> float:
	# Positive Y rotation swings the leaf into negative local Z. Stand beyond
	# its full radius on that side; retain a capsule margin on the other side.
	var swing_side := -signf(sin(leaf.motion_target_angle(true)))
	return radius + 0.16 + (leaf.width if incoming == swing_side else 0.0)

func _toward(player: CharacterBody3D, intent: Vector3, delta: float, speed: float) -> Vector3:
	var offset := door.to_global(mark) - player.global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.001: return Vector3.ZERO
	var next := player.global_position + offset / distance * minf(distance, speed * delta)
	if not _supported(player, next):
		_cancel_manual(); return intent
	return offset / distance * minf(intent.length(), distance / maxf(speed * delta, 0.001))

func _supported(player: CharacterBody3D, point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .3, point - Vector3.UP * .45, 1)
	ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP) > .7
