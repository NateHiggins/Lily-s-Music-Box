extends RefCounted
## Shallow room-side relief, clipped to the shell's actual solid wall pieces.
## One trim draw, plus one panel draw in public rooms; no new collision owner.

static func build(room: Node3D, record: Dictionary, floor_y: float,
		clear_height: float, wall_thickness: float, material: Material,
		panel_material: Material) -> void:
	if record.get("class", "") not in ["private", "public"]: return
	if record.get("open_shell", false): return
	var rect: Array = record.rect
	var transforms: Array[Transform3D] = []
	var sources: PackedStringArray = []
	var panels: Array[Transform3D] = []
	var panel_sources: PackedStringArray = []
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
			var face := fixed+inward*(wall_thickness+profile.z)*.5
			var position := Vector3((start+finish)*.5, (low+high)*.5, face) if along_x else Vector3(face, (low+high)*.5, (start+finish)*.5)
			var dimensions := Vector3(finish-start, high-low, profile.z) if along_x else Vector3(profile.z, high-low, finish-start)
			var transform := Transform3D(Basis.from_scale(dimensions), position)
			if profile_index < profiles.size():
				transforms.append(transform)
				sources.append(label)
			else:
				panels.append(transform)
				panel_sources.append(label)
				# Vertical stiles meet (rather than overlap) the frame rails.
				# Build once, from the backing run, clipping again for low sills.
				if profile_index != profiles.size(): continue
				var stile_low := maxf(floor_y+.226, wall_low)
				var stile_high := minf(floor_y+1.240, wall_high)
				if stile_high-stile_low < .001 or finish-start < .15: continue
				var count := maxi(1, ceili((finish-start)/.72))
				for index in count+1:
					var along_stile := lerpf(start+.038, finish-.038, float(index)/count)
					var stile_face := fixed+inward*(wall_thickness+.036)*.5
					var stile_position := Vector3(along_stile, (stile_low+stile_high)*.5, stile_face) if along_x else Vector3(stile_face, (stile_low+stile_high)*.5, along_stile)
					var stile_size := Vector3(.036, stile_high-stile_low, .036)
					panels.append(Transform3D(Basis.from_scale(stile_size), stile_position))
					panel_sources.append(label)
	_emit(room, "HistoricMillwork", transforms, sources, material)
	_emit(room, "PublicWainscot", panels, panel_sources, panel_material)

static func _emit(room: Node3D, label: String, transforms: Array[Transform3D],
		sources: PackedStringArray, material: Material) -> void:
	if transforms.is_empty(): return
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size(): multimesh.set_instance_transform(index, transforms[index])
	batch.multimesh = multimesh
	batch.set_meta("wall_sources", sources)
	room.add_child(batch)
