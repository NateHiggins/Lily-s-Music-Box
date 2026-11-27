extends RefCounted
## Lena's stationary fabric-handling patch, not a needle/stitch simulation.
## Actual machine-local oak top: y=.775, x +/- .43, z +/- .23.
## The needle (-.175,.808,0) stays outside the entire near-corner work patch.
## Navigation and the machine never move. Existing clip fingers remain untouched.
var surface: Node3D
var _allowed: Callable
var _arms: Array[Dictionary] = []
## Only an explicit seated work owner opts in; the standing lease is unchanged.
var seated := false
var _skin_bones: Array[int] = []
var _skin_poses: Array[Transform3D] = []
## Explicit proof-only telemetry; ordinary gameplay allocates no per-frame rows.
var diagnostics := false
var last: Dictionary = {}
var last_cost_usec := 0
var measured_cost_usec := 0
var measured_frames := 0
## Calibrated from all 193 native working/resumed frames in lena_contact_rig01/
## attempt06; independent whole-skin qualification must accompany any update.
const SEATED_MODEL := "res://assets/characters/cast/lena_ortiz/lena_ortiz.gltf"
const SEATED_SOURCES := {
	SEATED_MODEL:"002aad74ff7aee5a790b1ef388c6c3e07af8e3383ac2e6a885c173038fee7c41",
	"res://assets/characters/cast/lena_ortiz/lena_ortiz.bin":"dd004e2cc8d21f865f0eacc43cb74f78953baecd217947b4bcc00574665dd953",
	"res://assets/characters/cast/shared/cast_moves.glb":"0ff8d9d63988d1d3f34969ccdd2a0126a2de2110aed59046443e90f857298bf1"}
const SEATED_REBASE_SHA := "3f9f72afb14f7e198616c8cc42235c05181e691bd9542c8f4d1c5dbf5b382b6b"
var _clip_player: AnimationPlayer

func bind(body: Skeleton3D, work_surface: Node3D, allowed: Callable, model: Node = null) -> bool:
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
			"rest_basis":hand.basis,"reference":Vector3.INF,"skin":[]})
	if not seated: return _arms.size()==2
	_skin_poses.resize(body.get_bone_count())
	var source := model if model != null else body.get_parent()
	if source.scene_file_path!=SEATED_MODEL: return false
	for path: String in SEATED_SOURCES:
		if FileAccess.get_sha256(path)!=SEATED_SOURCES[path]: return false
	if FileAccess.get_file_as_string("res://scripts/characters/resident_moves_library.gd").replace("\r\n","\n").sha256_text()!=SEATED_REBASE_SHA: return false
	var players := source.find_children("*","AnimationPlayer",true,false)
	if players.size()!=1: return false
	_clip_player=players[0] as AnimationPlayer
	for draw: MeshInstance3D in source.find_children("Skin_hands","MeshInstance3D",true,false):
		if draw.mesh == null or draw.skin == null: continue
		if draw.mesh.get_blend_shape_count()!=0: return false
		var mesh := draw.bake_mesh_from_current_blend_shape_mix()
		if mesh == null: continue
		for index in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.size()%vertices.size()!=0: continue
			var stride := int(bones.size()/vertices.size())
			for vertex in vertices.size():
				var influences: Array = []
				var left := 0.0; var right := 0.0
				for slot in stride:
					var at := vertex*stride+slot
					if weights[at]<=0.0: continue
					var joint := bones[at]
					var name := draw.skin.get_bind_name(joint)
					var bone := body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(joint)
					if bone<0: return false
					name = str(body.get_bone_name(bone))
					if name.begins_with("LeftHand"): left+=weights[at]
					if name.begins_with("RightHand"): right+=weights[at]
					influences.append([bone,draw.skin.get_bind_pose(joint)*vertices[vertex],weights[at]])
					if not _skin_bones.has(bone): _skin_bones.append(bone)
				# Exclude the forearm seam: these vertices must follow only
				# the wrist/finger subtree when its frame is turned palm-down.
				if left>.999: _arms[0].skin.append(influences)
				if right>.999: _arms[1].skin.append(influences)
	# Keep only the measured source support point per hand, not 3492 vertices.
	# Count, original asset/clip/rebase hashes, zero morphs and actual native
	# rest-point checks reject an incompatible import/shape instead of guessing.
	var counts := [1749,1743];var indices := [135,134]
	var rests := [Vector3(.443860382,.919424355,.300042570),Vector3(-.438045233,.917733967,.300315678)]
	_skin_bones.clear()
	for side_index in 2:
		var arm: Dictionary=_arms[side_index]
		if arm.skin.size()!=counts[side_index]: return false
		var point: Array=arm.skin[indices[side_index]]
		var rest := Vector3.ZERO
		for part: Array in point:
			rest+=(body.get_bone_global_rest(int(part[0]))*(part[1] as Vector3))*float(part[2])
			if not _skin_bones.has(int(part[0])):_skin_bones.append(int(part[0]))
		if rest.distance_to(rests[side_index])>.001: return false
		arm["calibrated_source_index"]=indices[side_index]
		arm.skin=[point]
	return true

func _live() -> bool:
	return is_instance_valid(surface) and surface.is_inside_tree() and _allowed.is_valid() and _allowed.call() \
			and (not seated or (is_instance_valid(_clip_player) and str(_clip_player.current_animation)=="clip_06"))

## Composed once by PosePipeline's existing lower-spine writer, before gaze.
## No hips/root/feet translation, no second writer and no work after release.
func posture_turn(body: Skeleton3D) -> Quaternion:
	if not seated or not _live():
		return Quaternion.IDENTITY
	var axis := (body.global_basis.inverse()*surface.global_basis.x).normalized()
	return Quaternion(axis,deg_to_rad(25.0))

func _hand_lowest(arm: Dictionary, wrist: Transform3D, orientation: Basis, body: Skeleton3D) -> float:
	var low := INF
	var inverse := wrist.affine_inverse()
	var frame := surface.global_basis.inverse()*body.global_basis*orientation
	arm["support_index"]=-1
	for index in arm.skin.size():
		var influences: Array=arm.skin[index]
		var point := Vector3.ZERO
		for part: Array in influences: point+=(_skin_poses[int(part[0])]*(part[1] as Vector3))*float(part[2])
		var height: float=(frame*(inverse*point)).y
		if height<low: low=height;arm.support_index=index
	return low

func apply(body: Skeleton3D, write: Callable) -> void:
	last.clear()
	if not _live(): return
	var begun := Time.get_ticks_usec() if diagnostics else 0
	var inverse := body.global_transform.affine_inverse()
	var up := (inverse.basis * surface.global_basis.y).normalized()
	if seated:
		for bone: int in _skin_bones: _skin_poses[bone]=body.get_bone_global_pose(bone)
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
		if seated: anchor=Vector3(.10,.815,-.195) if arm.side=="Left" else Vector3(-.12,.815,-.195)
		var local_target := anchor + motion
		var towards := surface.to_global(Vector3(0,.815,0))-surface.to_global(local_target)
		var forward := (inverse.basis*towards).normalized()
		forward = (forward - up*forward.dot(up)).normalized()
		var normal := -up
		var across := normal.cross(forward).normalized()
		var orientation: Basis = Basis(across,normal,forward)*(arm.hand_frame as Basis).inverse()*(arm.rest_basis as Basis)
		if seated:
			var low := _hand_lowest(arm,wrist,orientation,body)
			if not is_finite(low): continue
			local_target.y=.776-low # Actual deformed source hand, 1mm above real oak.
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
		if not write.call(ids[2],Transform3D(orientation,wrist.origin),"contact"): continue
		if diagnostics:
			last[arm.side] = {"reachable":true,"target":body.to_global(target),"wrist":body.to_global(wrist.origin),
				"asked":asked,"maximum":upper+lower,"reserve":upper+lower-asked,
				"skin_vertices":arm.skin.size(),"support_index":arm.get("support_index",-1),
				"calibrated_source_index":arm.get("calibrated_source_index",-1),
				"tracking_error":wrist.origin.distance_to(target),"table_local":surface.to_local(body.to_global(wrist.origin)),
				"needle_gap":local_target.distance_to(Vector3(-.175,.808,0)),"observation":"wrist tracking, not skin/fabric contact"}
	if diagnostics:
		last_cost_usec=Time.get_ticks_usec()-begun
		measured_cost_usec+=last_cost_usec
		measured_frames+=1
