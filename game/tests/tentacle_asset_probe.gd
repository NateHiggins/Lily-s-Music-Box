extends Node
## What of the Blender hero actually survives into Godot? (§22)
func _ready() -> void:
	var failures := 0
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
		if m.name == "TENTACLE_BODY_CAGE":
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
	for pair in [["thickness", lo.r, hi.r], ["rest_y_fix", lo.g, hi.g],
			["gold_root", lo.b, hi.b], ["sucker", lo.a, hi.a]]:
		var span: float = float(pair[2]) - float(pair[1])
		print("[asset]   COLOR %-10s %.3f .. %.3f  %s"
				% [pair[0], pair[1], pair[2], "OK" if span > 0.05 else "FLAT - carries nothing"])
		if span <= 0.05:
			failures += 1
	var u2lo := Vector2(9, 9)
	var u2hi := Vector2(-9, -9)
	for u in uv2s:
		u2lo = u2lo.min(u); u2hi = u2hi.max(u)
	print("[asset]   UV2 rest X %.3f .. %.3f, encoded Z %.3f .. %.3f"
			% [u2lo.x, u2hi.x, u2lo.y, u2hi.y])
	var ulo := Vector2(9, 9)
	var uhi := Vector2(-9, -9)
	for u in uvs:
		ulo = ulo.min(u); uhi = uhi.max(u)
	print("[asset]   UV strip u %.2f .. %.2f, v %.2f .. %.2f"
			% [ulo.x, uhi.x, ulo.y, uhi.y])
	# H1 — THE DEFORMING FLESH CARRIES ITS OWN REST POSITION. Blender's +Y
	# becomes Godot's -Z and glTF flips the second component of each UV set.
	# Reconstruct what the shader will sample and compare it with the imported
	# undeformed cage, vertex by vertex. This catches a lost channel, a changed
	# pack extent, a flipped axis and a cap whose longitudinal UV was defaulted.
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if uvs.size() != verts.size() or uv2s.size() != verts.size():
		printerr("[asset] FAIL rest channel cardinality: %d verts / %d uv / %d uv2"
				% [verts.size(), uvs.size(), uv2s.size()])
		failures += 1
	else:
		var max_error := 0.0
		var worst := -1
		for i in verts.size():
			var rest_y_norm := (1.0 - uvs[i].y) + (cols[i].g - 0.5) * 0.024
			var rest := Vector3((uv2s[i].x - 0.5) * 0.32,
					(0.5 - uv2s[i].y) * 0.32,
					-rest_y_norm * 1.60)
			var error := rest.distance_to(verts[i])
			if error > max_error:
				max_error = error
				worst = i
		print("[asset] flesh rest channel max error %.4f mm at vertex %d"
				% [max_error * 1000.0, worst])
		if worst >= 0:
			var decoded_y := (1.0 - uvs[worst].y) + (cols[worst].g - 0.5) * 0.024
			var decoded := Vector3((uv2s[worst].x - 0.5) * 0.32,
					(0.5 - uv2s[worst].y) * 0.32,
					-decoded_y * 1.60)
			print("[asset]   worst imported %s decoded %s uv %s uv2 %s"
					% [verts[worst], decoded, uvs[worst], uv2s[worst]])
		if max_error > 0.0005:
			printerr("[asset] FAIL rest position is not the authored cage")
			failures += 1
	# The ocular region moved from a live vertex channel into the alpha of the
	# already-bound anatomy map. Presence is not meaning: sample its full range
	# so an RGB-only rebake cannot silently turn the whole socket off.
	var anatomy: Texture2D = load("res://assets/dream/tentacle/T_dream_hero_anatomy.png")
	var anatomy_image := anatomy.get_image()
	var alpha_lo := 1.0
	var alpha_hi := 0.0
	for y in range(0, anatomy_image.get_height(), 8):
		for x in range(0, anatomy_image.get_width(), 8):
			var a := anatomy_image.get_pixel(x, y).a
			alpha_lo = minf(alpha_lo, a)
			alpha_hi = maxf(alpha_hi, a)
	print("[asset] anatomy alpha ocular %.3f .. %.3f" % [alpha_lo, alpha_hi])
	if alpha_hi - alpha_lo <= 0.05:
		printerr("[asset] FAIL anatomy alpha carries no ocular region")
		failures += 1
	print("[asset] %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(0 if failures == 0 else 1)
