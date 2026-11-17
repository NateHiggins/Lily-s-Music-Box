extends "res://tests/harukiya_physical_contact_math.gd"
## Separate adapter: current Lily source datums, no Stacy grip records.
var targets: Dictionary = {}
var tips: Dictionary = {}
var palms: Dictionary = {}
var supports: Dictionary = {}
func solve_bass(driver: Node) -> void:
	for side: String in ["Left", "Right"]:
		_foot(driver, side, supports[side], Vector3.FORWARD)
		var body: Skeleton3D = driver.skeleton
		var hand: int = body.find_bone(side+"Hand")
		var terminal: int = body.find_bone(side+"HandIndex3")
		var basis: Basis = _hand_basis(body, side, Vector3.FORWARD)
		var fingers: Dictionary = _finger_map(body, side, basis, 0.0)
		if not fingers.has(terminal):
			driver.faults.append("source terminal absent "+side); return
		var offset: Vector3 = fingers[terminal]*tips[side].bone_local_point
		var wrist: Vector3 = targets[side]-body.global_basis*offset
		_limb(driver, side+"Arm", side+"ForeArm", side+"Hand", wrist,
			_arm_pole(body, side), basis, "bass_wrist_"+side)
		_fingers(driver, side, fingers)
		var actual: Vector3 = body.global_transform*(body.get_bone_global_pose(terminal)*tips[side].bone_local_point)
		_measure("bass_tip_"+side, actual.distance_to(targets[side]), {"actual":actual,"target":targets[side],"source":tips[side]})
		# Report palm facet independently; it is never substituted for the fingertip.
		latest["bass_palm_"+side] = {"actual":body.global_transform*(body.get_bone_global_pose(hand)*palms[side].bone_local_point),"source":palms[side]}

func current_palm(driver: Node, side: String) -> Dictionary:
	var body: Skeleton3D = driver.skeleton
	var hand: int = body.find_bone(side+"Hand")
	var rest: Transform3D = body.get_bone_global_rest(hand)
	var middle: Vector3 = body.get_bone_global_rest(body.find_bone(side+"HandMiddle1")).origin
	var seed: Vector3 = rest.origin.lerp(middle, 0.5)
	var index: Vector3=body.get_bone_global_rest(body.find_bone(side+"HandIndex1")).origin
	var pinky: Vector3=body.get_bone_global_rest(body.find_bone(side+"HandPinky1")).origin
	var palmar: Vector3=(middle-rest.origin).normalized().cross((index-pinky).normalized()*(1.0 if side=="Left" else -1.0)).normalized()
	var best := INF
	var result: Dictionary = {}
	for draw: MeshInstance3D in driver.model.find_children("Skin_hands", "MeshInstance3D", true, false):
		if draw.mesh==null or draw.skin==null: continue
		var joints: Array[int] = []
		var bind_rest: Array[Transform3D] = []
		for slot: int in draw.skin.get_bind_count():
			var name: StringName = draw.skin.get_bind_name(slot)
			var joint: int = body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(slot)
			if joint<0:return {}
			joints.append(joint);bind_rest.append(body.get_bone_global_rest(joint)*draw.skin.get_bind_pose(slot))
		for surface: int in draw.mesh.get_surface_count():
			var arrays: Array = draw.mesh.surface_get_arrays(surface)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			if vs.is_empty() or bs.is_empty():continue
			if indices.is_empty():
				for i: int in vs.size():indices.append(i)
			var slots := int(bs.size()/vs.size())
			for triangle: int in int(indices.size()/3):
				var points: Array[Vector3] = []
				var ids: Array[int] = []
				var normal_sum := Vector3.ZERO
				for corner: int in 3:
					var vertex: int = indices[triangle*3+corner]
					var p := Vector3.ZERO
					var weight := 0.0
					for slot: int in slots:
						var k: int = vertex*slots+slot
						if bs[k]<0 or bs[k]>=joints.size():return {}
						if joints[bs[k]]==hand:weight+=ws[k]
						p+=(bind_rest[bs[k]]*vs[vertex])*ws[k]
						if normals.size()==vs.size():normal_sum+=(bind_rest[bs[k]].basis.inverse().transposed()*normals[vertex])*ws[k]
					if weight<0.9999:break
					points.append(p);ids.append(vertex)
				if points.size()!=3 or normal_sum.normalized().dot(palmar)<0.5:continue
				var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0])
				if normal.length_squared()<1e-14:continue
				var centre: Vector3 = (points[0]+points[1]+points[2])/3.0
				var distance: float = centre.distance_squared_to(seed)
				if distance>=best:continue
				best=distance
				result={"mesh":str(draw.name),"surface":surface,"triangle":triangle,"vertices":ids,
					"bone":side+"Hand","bone_local_point":rest.affine_inverse()*centre,
					"rest_normal":normal_sum.normalized(),"source_palmar_axis":palmar,"selection":"nearest fully-Hand-weighted source facet to Hand/Middle1 midpoint with actual loaded normals facing helper-derived palmar axis"}
	return result
