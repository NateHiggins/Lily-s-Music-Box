extends RefCounted
## Shallow room-side relief, clipped to the shell's actual solid wall pieces.
## One draw per room; the existing shell remains the sole collision owner.

static func build(room: Node3D, record: Dictionary, floor_y: float,
		clear_height: float, wall_thickness: float, material: Material) -> void:
	if record.get("class", "") not in ["private", "public"]: return
	if record.get("open_shell", false): return
	var rect: Array = record.rect
	var transforms: Array[Transform3D] = []
	var sources: PackedStringArray = []
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
		for profile: Vector3 in profiles:
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
			transforms.append(Transform3D(Basis.from_scale(dimensions), position))
			sources.append(label)
	if transforms.is_empty(): return
	var batch := MultiMeshInstance3D.new()
	batch.name = "HistoricMillwork"
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
