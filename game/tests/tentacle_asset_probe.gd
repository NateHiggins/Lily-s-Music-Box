extends Node
## What of the Blender hero actually survives into Godot? (§22)
func _ready() -> void:
	var scene: PackedScene = load("res://assets/dream/tentacle/dream_tentacle.glb")
	if scene == null:
		printerr("[asset] the glTF did not load")
		get_tree().quit(1); return
	var root := scene.instantiate()
	add_child(root)
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes.append(n)
		for c in n.get_children():
			stack.append(c)
	print("[asset] %d mesh instances" % meshes.size())
	var skinned := 0
	for m in meshes:
		if m.skin != null:
			skinned += 1
	print("[asset] %d carry a skin" % skinned)
	var probe: MeshInstance3D = null
	for m in meshes:
		if m.mesh != null and m.mesh.get_surface_count() > 0 \
				and m.mesh.surface_get_array_len(0) > 2000:
			probe = m
			break
	if probe == null:
		probe = meshes[0]
	var fmt: int = probe.mesh.surface_get_format(0)
	print("[asset] probing '%s'" % probe.name)
	for pair in [["VERTEX", Mesh.ARRAY_FORMAT_VERTEX], ["NORMAL", Mesh.ARRAY_FORMAT_NORMAL],
			["TANGENT", Mesh.ARRAY_FORMAT_TANGENT], ["COLOR", Mesh.ARRAY_FORMAT_COLOR],
			["TEX_UV", Mesh.ARRAY_FORMAT_TEX_UV], ["TEX_UV2", Mesh.ARRAY_FORMAT_TEX_UV2],
			["BONES", Mesh.ARRAY_FORMAT_BONES], ["WEIGHTS", Mesh.ARRAY_FORMAT_WEIGHTS],
			["CUSTOM0", Mesh.ARRAY_FORMAT_CUSTOM0], ["CUSTOM1", Mesh.ARRAY_FORMAT_CUSTOM1],
			["CUSTOM2", Mesh.ARRAY_FORMAT_CUSTOM2], ["CUSTOM3", Mesh.ARRAY_FORMAT_CUSTOM3]]:
		print("[asset]   %-8s %s" % [pair[0], "yes" if (fmt & int(pair[1])) != 0 else "NO"])
	# PRESENT IS NOT THE SAME AS MEANINGFUL. Read the masks back and report
	# their ranges: a channel that is constant carries no anatomy.
	var arrays: Array = probe.mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var lo := Color(9, 9, 9, 9)
	var hi := Color(-9, -9, -9, -9)
	for c in cols:
		lo = Color(minf(lo.r, c.r), minf(lo.g, c.g), minf(lo.b, c.b), minf(lo.a, c.a))
		hi = Color(maxf(hi.r, c.r), maxf(hi.g, c.g), maxf(hi.b, c.b), maxf(hi.a, c.a))
	print("[asset] %d verts" % cols.size())
	for pair in [["thickness", lo.r, hi.r], ["wetness", lo.g, hi.g],
			["gold_root", lo.b, hi.b], ["sucker", lo.a, hi.a]]:
		var span: float = float(pair[2]) - float(pair[1])
		print("[asset]   COLOR %-10s %.3f .. %.3f  %s"
				% [pair[0], pair[1], pair[2], "OK" if span > 0.05 else "FLAT - carries nothing"])
	var u2lo := Vector2(9, 9)
	var u2hi := Vector2(-9, -9)
	for u in uv2s:
		u2lo = u2lo.min(u); u2hi = u2hi.max(u)
	print("[asset]   UV2 ocular %.3f .. %.3f, distal %.3f .. %.3f"
			% [u2lo.x, u2hi.x, u2lo.y, u2hi.y])
	var ulo := Vector2(9, 9)
	var uhi := Vector2(-9, -9)
	for u in uvs:
		ulo = ulo.min(u); uhi = uhi.max(u)
	print("[asset]   UV strip u %.2f .. %.2f, v %.2f .. %.2f"
			% [ulo.x, uhi.x, ulo.y, uhi.y])
	get_tree().quit(0)
