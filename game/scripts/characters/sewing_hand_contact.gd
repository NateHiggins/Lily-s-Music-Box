extends RefCounted
## Lena's stationary fabric-handling patch, not a needle/stitch simulation.
## Actual machine-local oak top: y=.775, x +/- .43, z +/- .23.
## The needle (-.175,.808,0) stays outside the entire near-corner work patch.
## Navigation and the machine never move. Existing clip fingers remain untouched.
var surface: Node3D
var _allowed: Callable
var _arms: Array[Dictionary] = []
## Explicit proof-only telemetry; ordinary gameplay allocates no per-frame rows.
var diagnostics := false
var last: Dictionary = {}

func bind(body: Skeleton3D, work_surface: Node3D, allowed: Callable) -> bool:
	if body == null or not is_instance_valid(work_surface) or not allowed.is_valid(): return false
	surface = work_surface
	_allowed = allowed
	for side: String in ["Left", "Right"]:
		var ids: Array[int] = []
		for suffix: String in ["Arm", "ForeArm", "Hand", "HandMiddle1", "HandIndex1", "HandPinky1"]:
			ids.append(body.find_bone(side + suffix))
		if ids.has(-1): return false
		if body.get_bone_parent(ids[1]) != ids[0] or body.get_bone_parent(ids[2]) != ids[1]: return false
		var hand := body.get_bone_global_rest(ids[2])
		var forward := (body.get_bone_global_rest(ids[3]).origin - hand.origin).normalized()
		var across := (body.get_bone_global_rest(ids[4]).origin - body.get_bone_global_rest(ids[5]).origin).normalized()
		across *= 1.0 if side == "Left" else -1.0
		var normal := forward.cross(across).normalized()
		if normal.length_squared() < .9: return false
		across = normal.cross(forward).normalized()
		_arms.append({"side":side,"ids":ids,"hand_frame":Basis(across,normal,forward),
			"rest_basis":hand.basis,"reference":Vector3.INF})
	return _arms.size() == 2

func apply(body: Skeleton3D, write: Callable) -> void:
	last.clear()
	if not is_instance_valid(surface) or not surface.is_inside_tree() or not _allowed.is_valid() or not _allowed.call(): return
	var inverse := body.global_transform.affine_inverse()
	var up := (inverse.basis * surface.global_basis.y).normalized()
	for arm: Dictionary in _arms:
		var ids: Array = arm.ids
		var shoulder := body.get_bone_global_pose(ids[0])
		var elbow := body.get_bone_global_pose(ids[1])
		var wrist := body.get_bone_global_pose(ids[2])
		var clip_local := surface.to_local(body.to_global(wrist.origin))
		if not (arm.reference as Vector3).is_finite(): arm.reference = clip_local
		# Preserve subtle source motion, bounded to 12mm horizontally/4mm vertically.
		var motion: Vector3 = (clip_local - (arm.reference as Vector3)) * .15
		motion = motion.clamp(Vector3(-.012,-.004,-.012),Vector3(.012,.004,.012))
		# Both wrists stay at the actor's near +x/-z corner. The fingers aim
		# inwards over the timber; neither hand reaches across the machine.
		var anchor := Vector3(.32,.815,-.105) if arm.side == "Left" else Vector3(.23,.815,-.165)
		var local_target := anchor + motion
		var target := inverse * surface.to_global(local_target)
		var upper := shoulder.origin.distance_to(elbow.origin)
		var lower := elbow.origin.distance_to(wrist.origin)
		var reach := target - shoulder.origin
		var asked := reach.length()
		if upper < .001 or lower < .001 or asked < .001: continue
		# Never stretch or disguise a missed contact by clamping the endpoint.
		if asked > upper + lower - .002 or asked < absf(upper-lower) + .002:
			if diagnostics:
				last[arm.side] = {"reachable":false,"asked":asked,"maximum":upper+lower,"target":body.to_global(target)}
			continue
		var direction := reach / asked
		# Reuse the clip's own elbow plane, rather than guessing left/right
		# world poles. Project it into the new shoulder-target plane.
		var clip_line := (wrist.origin - shoulder.origin).normalized()
		var bend := elbow.origin - shoulder.origin
		bend -= clip_line * bend.dot(clip_line)
		bend -= direction * bend.dot(direction)
		if bend.length_squared() < .000001: bend = up.cross(direction)
		if bend.length_squared() < .000001: continue
		bend = bend.normalized()
		var along := (upper*upper - lower*lower + asked*asked)/(2.0*asked)
		var wanted_elbow := shoulder.origin + direction*along + bend*sqrt(maxf(0.0,upper*upper-along*along))
		var turn := Basis(Quaternion((elbow.origin-shoulder.origin).normalized(),(wanted_elbow-shoulder.origin).normalized()))
		if not write.call(ids[0],Transform3D(turn*shoulder.basis,shoulder.origin),"contact"): continue
		elbow = body.get_bone_global_pose(ids[1])
		wrist = body.get_bone_global_pose(ids[2])
		turn = Basis(Quaternion((wrist.origin-elbow.origin).normalized(),(target-elbow.origin).normalized()))
		if not write.call(ids[1],Transform3D(turn*elbow.basis,elbow.origin),"contact"): continue
		wrist = body.get_bone_global_pose(ids[2])
		var towards := surface.to_global(Vector3(0,.815,0))-surface.to_global(local_target)
		var forward := (inverse.basis*towards).normalized()
		forward = (forward - up*forward.dot(up)).normalized()
		var normal := -up # Rest-derived hand normal is palm-out; face it down.
		var across := normal.cross(forward).normalized()
		var orientation: Basis = Basis(across,normal,forward)*(arm.hand_frame as Basis).inverse()*(arm.rest_basis as Basis)
		if not write.call(ids[2],Transform3D(orientation,wrist.origin),"contact"): continue
		if diagnostics:
			last[arm.side] = {"reachable":true,"target":body.to_global(target),"wrist":body.to_global(wrist.origin),
				"tracking_error":wrist.origin.distance_to(target),"table_local":surface.to_local(body.to_global(wrist.origin)),
				"needle_gap":local_target.distance_to(Vector3(-.175,.808,0)),"observation":"wrist tracking, not skin/fabric contact"}
