class_name DreamContactSensor
extends RefCounted
## Where the limb touches (DREAM_TENTACLE_DIRECTION §13, §14, §17): the
## contact point and normal on the chosen object. An object with a
## DreamTargetProfile gives its preferred contact, the edge to trace and its
## normal; otherwise the nearest face of its bounds. The contact slides: a
## slow figure-eight while caressing, a traverse along the edge while
## tracing; a physics ray lands it on the real surface when one is there.

var target_aabb := AABB()
var target_name := ""
var target_node: Node3D = null
var target_profile: DreamTargetProfile = null
var contact := Vector3.ZERO
var contact_normal := Vector3.UP
var base := Vector3.ZERO
var tangent_a := Vector3.RIGHT
var tangent_b := Vector3.FORWARD
var trace_half := 0.0
var has_target := false
var _space: PhysicsDirectSpaceState3D = null


func configure(space: PhysicsDirectSpaceState3D) -> void:
	_space = space


## Choose among candidates ({aabb, name, node}) the best object in reach of
## the anchor: interesting objects (a profile) first, then the nearest.
func choose(anchor: Vector3, anchor_normal: Vector3, reach_m: float, candidates: Array) -> bool:
	var origin := anchor + anchor_normal * 0.4
	var best_d := INF
	var best_score := -INF
	has_target = false
	target_name = ""
	target_node = null
	target_profile = null
	for entry in candidates:
		var aabb: AABB = entry.aabb
		if aabb.has_point(anchor):
			continue
		var size := aabb.size
		if size.x > 2.6 or size.y > 2.6 or size.z > 2.6 or size.length() < 0.12:
			continue
		var closest := _closest_on(aabb, origin)
		var d := closest.distance_to(anchor)
		if d > reach_m or d < 0.12:
			continue
		# Out in the room, not hanging on the wall it came out of.
		if (closest - anchor).dot(anchor_normal) < 0.15:
			continue
		var node: Node3D = entry.get("node")
		var prof: DreamTargetProfile = null
		if node != null and node.has_method("dream_target_profile"):
			prof = node.dream_target_profile()
		var score := -d + (2.0 if prof != null else 0.0)
		if score > best_score:
			best_score = score
			best_d = d
			target_aabb = aabb
			target_name = str(entry.name)
			target_node = node
			target_profile = prof
			has_target = true
	if not has_target:
		target_aabb = AABB(anchor + anchor_normal * 0.9 - Vector3(0.25, 0.25, 0.25), Vector3(0.5, 0.5, 0.5))
	if OS.get_environment("ENCROACH_DEBUG") == "1":
		var listed := 0
		for entry in candidates:
			var aabb: AABB = entry.aabb
			var d := _closest_on(aabb, origin).distance_to(anchor)
			if d < reach_m + 0.5 and listed < 12:
				listed += 1
				var node: Node3D = entry.get("node")
				print("[TENTACLE]   candidate %s d=%.2f size=%s node=%s" % [str(entry.name), d, aabb.size,
						node.name if node != null else "-"])
		print("[TENTACLE]   chose %s (profile %s)" % [target_name, target_profile != null])
	_frame(anchor, anchor_normal)
	return has_target


static func _closest_on(aabb: AABB, p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, aabb.position.x, aabb.end.x),
			clampf(p.y, aabb.position.y, aabb.end.y),
			clampf(p.z, aabb.position.z, aabb.end.z))


## The contact frame: base point, normal, the two tangents, the trace length.
func _frame(anchor: Vector3, anchor_normal: Vector3) -> void:
	if target_profile != null and target_node != null:
		var xf := target_node.global_transform
		base = xf * target_profile.contact_local
		contact_normal = (xf.basis * target_profile.contact_normal_local).normalized()
		tangent_a = (xf.basis * target_profile.trace_axis_local).normalized()
		tangent_b = contact_normal.cross(tangent_a).normalized()
		trace_half = target_profile.trace_half_length
		contact = base + contact_normal * 0.012
		return
	var probe := anchor + anchor_normal * 0.6
	base = _closest_on(target_aabb, probe)
	var n := probe - base
	if n.length() < 1e-3:
		n = anchor_normal
	n = n.normalized()
	var ax := Vector3(absf(n.x), absf(n.y), absf(n.z))
	if ax.x >= ax.y and ax.x >= ax.z:
		contact_normal = Vector3(signf(n.x), 0.0, 0.0)
	elif ax.y >= ax.z:
		contact_normal = Vector3(0.0, signf(n.y), 0.0)
	else:
		contact_normal = Vector3(0.0, 0.0, signf(n.z))
	tangent_a = (contact_normal.cross(Vector3.UP) if absf(contact_normal.y) < 0.9 else Vector3.RIGHT).normalized()
	tangent_b = contact_normal.cross(tangent_a).normalized()
	# Trace the longer face axis.
	var ext_a := absf(target_aabb.size.dot(Vector3(absf(tangent_a.x), absf(tangent_a.y), absf(tangent_a.z))))
	trace_half = clampf(ext_a * 0.45, 0.0, 0.35)
	contact = base + contact_normal * 0.012


## The caress: figure-eights about the base; the trace: a traverse along
## the edge. `t` is the behaviour's clock; `mode` "hover" | "caress" |
## "trace". Lands on the real surface with a short ray when there is one.
func update(t: float, mode: String, seed_phase: float) -> void:
	var slide := Vector3.ZERO
	match mode:
		"caress":
			var w := 0.42
			slide = tangent_a * 0.14 * sin(t * w + seed_phase) + tangent_b * 0.09 * sin(t * w * 2.0 + seed_phase)
		"trace":
			slide = tangent_a * trace_half * sin(t * 0.25 + seed_phase)
		_:
			slide = tangent_a * 0.03 * sin(t * 0.6) + tangent_b * 0.02 * sin(t * 0.8 + 1.0)
	var p := base + slide
	if target_profile == null:
		p = _closest_on(target_aabb, p)
	# Land on the real surface: a ray from 6 cm out, along the normal.
	if _space != null:
		var from := p + contact_normal * 0.06
		var query := PhysicsRayQueryParameters3D.create(from, p - contact_normal * 0.08)
		var hit: Dictionary = _space.intersect_ray(query)
		if not hit.is_empty():
			var hn: Vector3 = hit.normal
			if hn.dot(contact_normal) > 0.3:
				p = hit.position
				contact_normal = contact_normal.lerp(hn, 0.5).normalized()
	contact = p + contact_normal * 0.010
