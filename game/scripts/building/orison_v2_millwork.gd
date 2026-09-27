extends RefCounted
## Shallow room-side relief, clipped to the shell's actual solid wall pieces.
## One trim draw, plus backing and frame draws in public rooms; no new collision.
const PROFILE := preload("res://assets/props/millwork_profile.glb")
static var _profile: Mesh
static var _frame: Mesh

static func build(room: Node3D, record: Dictionary, floor_y: float,
		clear_height: float, wall_thickness: float, material: Material,
		panel_material: Material, doors: Array = []) -> void:
	if record.get("class", "") not in ["private", "public"]: return
	if record.get("open_shell", false): return
	var rect: Array = record.rect
	var casings := _casing_boxes(record,doors,floor_y,wall_thickness)
	var transforms: Array[Transform3D] = []
	var sources: PackedStringArray = []
	var panels: Array[Transform3D] = []
	var panel_sources: PackedStringArray = []
	var frames: Array[Transform3D] = []
	var frame_sources: PackedStringArray = []
	# Height centre, height, projection: the established Orison millwork scale.
	var profiles := [Vector3(.07, .14, .032), Vector3(.153, .026, .042),
		Vector3(2.18, .042, .042)]
	if not record.get("no_ceiling", false):
		profiles.append_array([Vector3(clear_height-.025, .05, .032),
			Vector3(clear_height-.075, .05, .046),
			Vector3(clear_height-.1125, .025, .054)])
	for child in room.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh: continue
		var label := str(child.name)
		if not (label.begins_with("WallNorth") or label.begins_with("WallSouth")
			or label.begins_with("WallWest") or label.begins_with("WallEast")): continue
		var along_x := label.begins_with("WallNorth") or label.begins_with("WallSouth")
		var size: Vector3 = child.mesh.size
		var at: Vector3 = child.position
		var wall_low := at.y-size.y*.5
		var wall_high := at.y+size.y*.5
		var fixed: float = at.z if along_x else at.x
		var centre: float = (float(rect[1])+float(rect[3]))*.5 if along_x else (float(rect[0])+float(rect[2]))*.5
		var inward := signf(centre-fixed)
		var wall_profiles: Array = profiles.duplicate()
		if record.get("class", "") == "public":
			# Backing to the established 1.32 m dado, then a projecting cap.
			# The backing is behind the frames, never coplanar with their faces.
			wall_profiles.append_array([Vector3(.743, 1.154, .016),
				Vector3(1.34, .04, .050), Vector3(.211, .030, .036),
				Vector3(1.255, .030, .036)])
		for profile_index in wall_profiles.size():
			var profile: Vector3 = wall_profiles[profile_index]
			var low := maxf(floor_y+profile.x-profile.y*.5, wall_low)
			var high := minf(floor_y+profile.x+profile.y*.5, wall_high)
			if high-low < .001: continue
			var along: float = at.x if along_x else at.z
			var length: float = size.x if along_x else size.z
			# Butt corners: X runs meet the wall face; Z runs stop at the X trim.
			var corner_pad := wall_thickness*.5 + (0.0 if along_x else profile.z)
			var start := maxf(along-length*.5, float(rect[0 if along_x else 1])+corner_pad)
			var finish := minf(along+length*.5, float(rect[2 if along_x else 3])-corner_pad)
			if finish-start < .001: continue
			var normal_a := fixed+inward*wall_thickness*.5
			var normal_b := normal_a+inward*profile.z
			for run: Vector2 in _clear_runs(start,finish,low,high,minf(normal_a,normal_b),maxf(normal_a,normal_b),along_x,casings):
				var face := fixed+inward*(wall_thickness+profile.z)*.5
				var position := Vector3((run.x+run.y)*.5, (low+high)*.5, face) if along_x else Vector3(face, (low+high)*.5, (run.x+run.y)*.5)
				var dimensions := Vector3(run.y-run.x, high-low, profile.z) if along_x else Vector3(profile.z, high-low, run.y-run.x)
				var transform := Transform3D(Basis.from_scale(dimensions), position)
				if profile_index != profiles.size():
					# The Blender section faces +Z and runs along X. Rotate its front
					# into the room, keeping the original clipped world-space bounds.
					var angle := (0.0 if inward>0 else PI) if along_x else (PI*.5 if inward>0 else -PI*.5)
					transform.basis = Basis(Vector3.UP,angle)*Basis.from_scale(Vector3(run.y-run.x,high-low,profile.z))
					if profile_index < profiles.size():
						transforms.append(transform)
						sources.append(label)
					else:
						frames.append(transform)
						frame_sources.append(label)
				else:
					panels.append(transform)
					panel_sources.append(label)
					# Vertical stiles meet (rather than overlap) the frame rails.
					# Build once, from the backing run, clipping again for low sills.
					var stile_low := maxf(floor_y+.226, wall_low)
					var stile_high := minf(floor_y+1.240, wall_high)
					if stile_high-stile_low < .001 or run.y-run.x < .15: continue
					var count := maxi(1, ceili((run.y-run.x)/.72))
					for index in count+1:
						var along_stile := lerpf(run.x+.038, run.y-.038, float(index)/count)
						var stile_face := fixed+inward*(wall_thickness+.036)*.5
						var stile_position := Vector3(along_stile, (stile_low+stile_high)*.5, stile_face) if along_x else Vector3(stile_face, (stile_low+stile_high)*.5, along_stile)
						var stile_size := Vector3(.036, stile_high-stile_low, .036)
						var angle := (0.0 if inward>0 else PI) if along_x else (PI*.5 if inward>0 else -PI*.5)
						var basis := Basis(Vector3.UP,angle)*Basis(Vector3.BACK,PI*.5)*Basis.from_scale(Vector3(stile_size.y,stile_size.x,stile_size.z))
						frames.append(Transform3D(basis, stile_position))
						frame_sources.append(label)

	_emit(room, "HistoricMillwork", transforms, sources, material)
	_emit(room, "PublicWainscot", panels, panel_sources, panel_material)
	_emit(room, "PublicWainscotFrames", frames, frame_sources, panel_material)

static func _emit(room: Node3D, label: String, transforms: Array[Transform3D],
		sources: PackedStringArray, material: Material) -> void:
	if transforms.is_empty(): return
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	var mesh: Mesh
	if label in ["HistoricMillwork", "PublicWainscotFrames"]:
		if _profile==null:
			var source := PROFILE.instantiate()
			_profile = (source.find_child("BeadedTrim",true,false) as MeshInstance3D).mesh
			_frame = (source.find_child("WainscotFrame",true,false) as MeshInstance3D).mesh
			source.free()
		mesh = _profile if label=="HistoricMillwork" else _frame
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mesh = box
	batch.material_override = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size(): multimesh.set_instance_transform(index, transforms[index])
	batch.multimesh = multimesh
	batch.set_meta("wall_sources", sources)
	room.add_child(batch)

# Derive the complete casing envelopes once per room, including the returns
# on perpendicular walls at narrow vestibule corners. Coordinates remain owned
# by the semantic aperture; these boxes are visual clipping only.
static func _casing_boxes(room: Dictionary, doors: Array, floor_y: float,
        wall_depth: float) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for door: Dictionary in doors:
		if str(room.id) not in door.connects: continue
		var width := float(door.width)
		var height := float(door.height)
		var placement := Transform3D(Basis(Vector3.UP,float(door.yaw)),Vector3(door.center[0],floor_y,door.center[1]))
		for side in [-1.0,1.0]:
			var z: float = side*(wall_depth*.5+.009)
			for x in [-width*.5-.045,width*.5+.045]:
				var size := Vector3(.09,height,.018)
				boxes.append(placement*AABB(Vector3(x,height*.5,z)-size*.5,size))
			var size := Vector3(width+.18,.09,.018)
			boxes.append(placement*AABB(Vector3(0,height+.045,z)-size*.5,size))
	return boxes

static func _clear_runs(start: float, finish: float, low: float, high: float,
        normal_low: float, normal_high: float, along_x: bool,
        casings: Array[AABB]) -> Array[Vector2]:
	var runs: Array[Vector2] = [Vector2(start,finish)]
	for casing: AABB in casings:
		if minf(high,casing.end.y)-maxf(low,casing.position.y)<.0001: continue
		var back: float = casing.position.z if along_x else casing.position.x
		var front: float = casing.end.z if along_x else casing.end.x
		if minf(normal_high,front)-maxf(normal_low,back)<.0001: continue
		var left: float = casing.position.x if along_x else casing.position.z
		var right: float = casing.end.x if along_x else casing.end.z
		var remaining: Array[Vector2] = []
		for run: Vector2 in runs:
			if right<=run.x or left>=run.y:
				remaining.append(run)
			else:
				if left-run.x>.001: remaining.append(Vector2(run.x,left))
				if run.y-right>.001: remaining.append(Vector2(right,run.y))
		runs=remaining
	return runs
