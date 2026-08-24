class_name DreamPalpRenderer
extends Node3D
## Draws the whole margin population in ONE mesh and ONE draw.
##
## The frame is submission-bound (`design/DT4_PERFORMANCE_REAUDIT.md`): four
## times the pixels costs 2-7%, and draw calls are the entire problem. So
## forty independently shaped organs cost one call, and their differences
## live in uniform arrays rather than in forty meshes.
##
## Nothing allocates while it runs. The mesh is built once; every frame writes
## spines, sections and material parameters into flat arrays.

const SHADER := preload("res://shaders/dream_palp.gdshader")
const MAX_PALPS := 40
const JOINTS := 6
const RINGS := 13
const SEGS := 11

## §12 STEP 8 — THE FINE CILIA, IN THE SAME BUFFER.
##
## `palp_matter.w` has carried an individual's cilia fraction since the
## morphology existed, and until now it drove a four-millimetre tremor in
## GDScript and nothing else: there was no cilia GEOMETRY anywhere on a palp.
## That is why step 8 was the unbuilt one.
##
## They go in the SAME mesh. The frame is submission-bound, so the answer to
## "where does new anatomy live" is never "another draw call" -- it is more
## vertices in the buffer already being drawn, tagged so the vertex program
## knows which anatomy it is building. `dream_critter.gdshader` builds bodies,
## limbs and feelers out of one program tagged by UV2.y, and this is the same
## move: UV2.y 0 is the shaft, 1 is a cilium.
##
## Ten per palp, four rings of five, is 200 vertices an individual. Every slot
## carries them whether or not it is a branch, because slots are assigned by
## distance every frame and any of them may hold a branch next frame. A slot
## that is not using them collapses them to a point in the vertex stage.
const CILIA := 10
const CIL_RINGS := 4
const CIL_SEGS := 5

var controller: DreamMarginController = null
var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var drawn := 0
## Which individuals currently have geometry, so the contract can check that
## the ones nearest the player are the ones being drawn.
var drawn_ids: Array = []

var _spine := PackedVector3Array()
var _section := PackedVector4Array()
var _params := PackedVector4Array()
var _matter := PackedVector4Array()
var _branch := PackedVector4Array()
var _cilia := PackedVector4Array()
var _clock := 0.0


func setup(margin: DreamMarginController) -> void:
	name = "DreamPalpRenderer"
	controller = margin
	_spine.resize(MAX_PALPS * JOINTS)
	_section.resize(MAX_PALPS * 4)
	_params.resize(MAX_PALPS)
	_matter.resize(MAX_PALPS)
	_branch.resize(MAX_PALPS)
	_cilia.resize(MAX_PALPS)
	material = ShaderMaterial.new()
	material.shader = SHADER
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Palps"
	mesh_instance.mesh = _build_mesh()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.extra_cull_margin = 20.0
	add_child(mesh_instance)


func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for p in MAX_PALPS:
		var base := verts.size()
		for r in RINGS:
			# Rings bunch toward the root, where the flare and the section
			# change fastest — evenly spaced rings made the hero's gold read
			# as a stepped boot, and the same mistake applies here.
			var v := pow(float(r) / float(RINGS - 1), 1.5)
			for s in SEGS:
				var u := float(s) / float(SEGS - 1)
				var a := u * TAU
				verts.append(Vector3(cos(a), sin(a), v))
				normals.append(Vector3(cos(a), sin(a), 0.0))
				uvs.append(Vector2(u, v))
				uv2.append(Vector2(float(p), 0.0))
		for r in RINGS - 1:
			for s in SEGS - 1:
				var a0 := base + r * SEGS + s
				indices.append(a0); indices.append(a0 + SEGS); indices.append(a0 + 1)
				indices.append(a0 + 1); indices.append(a0 + SEGS); indices.append(a0 + SEGS + 1)
		# ---- THIS PALP'S CILIA, IN THE SAME SLICE OF THE SAME BUFFER ---
		# UV2.y tags which anatomy a vertex belongs to; UV.x says which cilium
		# and UV.y where along it. The ring's angle rides in NORMAL, exactly as
		# a critter limb's does, because UV is spent on the other two.
		for ci in CILIA:
			var cbase := verts.size()
			for r in CIL_RINGS:
				var along := float(r) / float(CIL_RINGS - 1)
				for s in CIL_SEGS:
					var ca := float(s) / float(CIL_SEGS - 1) * TAU
					verts.append(Vector3(cos(ca), sin(ca), along))
					normals.append(Vector3(cos(ca), sin(ca), 0.0))
					uvs.append(Vector2(float(ci), along))
					uv2.append(Vector2(float(p), 1.0))
			for r in CIL_RINGS - 1:
				for s in CIL_SEGS - 1:
					var b0 := cbase + r * CIL_SEGS + s
					indices.append(b0)
					indices.append(b0 + CIL_SEGS)
					indices.append(b0 + 1)
					indices.append(b0 + 1)
					indices.append(b0 + CIL_SEGS)
					indices.append(b0 + CIL_SEGS + 1)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	return mesh


func _process(delta: float) -> void:
	if controller == null:
		return
	_clock += delta
	drawn = 0
	# §29/§30 — DRAW THE NEAREST, NOT THE FIRST.
	#
	# This took whichever forty appendages happened to sit earliest in the
	# array, which has nothing to do with where the player is: a margin of
	# eighty-odd could put its geometry on the far side of the flat while the
	# wall in front of you carried nothing. Choosing by distance is the whole
	# of the LOD system for the margin, and it costs one sort.
	#
	# Identity is untouched by it. Each appendage keeps its own seed,
	# personality, morphology and current act whether or not it is currently
	# being drawn, so one that leaves the drawn set and returns is the same
	# individual -- §30's "no obvious identity replacement".
	var eye := _eye_position()
	var order: Array = []
	for i in controller.palps.size():
		var p: Dictionary = controller.palps[i]
		order.append({"i": i, "d": eye.distance_squared_to(p.tip)})
	order.sort_custom(func(a, b): return float(a.d) < float(b.d))
	drawn_ids.clear()
	for entry in order:
		if drawn >= MAX_PALPS:
			break
		var p2: Dictionary = controller.palps[int(entry.i)]
		_lay(drawn, p2)
		drawn_ids.append(int(p2.id))
		drawn += 1
	# Anything past the live population is collapsed rather than left stale.
	# The fine anatomy goes with it: a slot whose last tenant was a branch
	# with its cilia out must not keep publishing them.
	for i in range(drawn, MAX_PALPS):
		_params[i] = Vector4.ZERO
		_cilia[i] = Vector4.ZERO
	material.set_shader_parameter("palp_spine", _spine)
	material.set_shader_parameter("palp_section", _section)
	material.set_shader_parameter("palp_params", _params)
	material.set_shader_parameter("palp_matter", _matter)
	material.set_shader_parameter("palp_branch", _branch)
	material.set_shader_parameter("palp_cilia", _cilia)
	material.set_shader_parameter("palp_count", drawn)
	if controller.field != null:
		controller.field.apply_to(material)
	mesh_instance.visible = drawn > 0


## One appendage's spine and its authored cross-sections.
func _lay(slot: int, p: Dictionary) -> void:
	var morph = p.morph
	var a: Vector3 = p.anchor
	var n: Vector3 = p.normal
	var aim: Vector3 = p.aim
	var side: Vector3 = p.side
	var up := n.cross(side)
	# The behaviour layer decides how far out the tip wants to be; the
	# morphology decides how long the organ is at full extension.
	var extend: float = float(p.extend) if p.has("extend") else 1.0
	var ln: float = float(morph.length) * float(p.grow) * clampf(extend, 0.05, 1.4)
	var sd: float = float(morph.seed_value)
	# Stiff organs hold a straighter line; soft ones curl. §6 makes stiffness
	# per-individual anatomy, so a gold finger and a whisker move differently
	# before any behavior code exists.
	var curl: float = (1.0 - float(morph.stiffness)) * float(morph.curvature)
	for j in JOINTS:
		var t := float(j) / float(JOINTS - 1)
		var point := a + n * (ln * (0.75 * t - 0.28 * t * t)) \
				+ aim * (ln * t * t * 0.9)
		point += (side * cos(sd * 2.1) + up * sin(sd * 2.1)) \
				* (ln * sin(t * PI * 0.7) * 0.45 * curl)
		# A whisker's own idle tremor. The BEHAVIOUR now supplies intent —
		# probing, tracing, bracing — and this is only the fine motion that
		# rides on top of it.
		var tremor: float = float(morph.cilia) * 0.004 * t
		point += side * sin(_clock * 5.5 + sd * 4.0) * tremor
		_spine[slot * JOINTS + j] = point
	for k in 4:
		_section[slot * 4 + k] = morph.sections[k]
	_params[slot] = Vector4(float(p.grow), float(morph.base_radius),
			float(morph.tip_ratio), sd)
	_matter[slot] = Vector4(float(morph.gold), float(morph.crystal),
			float(morph.suckers), float(morph.cilia))
	# §12 steps 2-4: how far the swelling has got, and where along the organ.
	_branch[slot] = Vector4(float(p.get("swell", 0.0)),
			float(p.get("swell_v", 0.6)), 0.0, 0.0)
	# §12 STEPS 8-9: THE FINE ANATOMY, AND THE MOMENT THE JOB IS DONE.
	#
	# `cilia_out` is an ANGLE the shader turns the hairs through, never a
	# length: at 0 they lie curled inside the shaft and at 1 they stand off
	# it, the same size throughout. The beat is published as a rise and fall
	# rather than as seconds remaining, because what the surface has to show
	# is a beat and not a countdown.
	#
	# `.get` rather than a bare read: §37's arrangement row is built by a
	# third birth and the renderer draws whatever the controller hands it.
	var left: float = float(p.get("task_left", 0.0))
	var beat: float = 0.0
	if left > 0.0:
		beat = sin(PI * clampf(1.0 - left / DreamMarginController.TASK_S,
				0.0, 1.0))
	_cilia[slot] = Vector4(float(p.get("cilia_out", 0.0)),
			float(p.get("cilia_band", 0.62)), beat, float(morph.cilia))


func census() -> Dictionary:
	# The vertex count is here because §12's cilia are the first anatomy
	# added to this buffer since it was written, and the claim being made
	# about them is that they cost geometry and not SUBMISSIONS. That is a
	# measurable claim and this is the number it rests on.
	var verts := 0
	var idx := 0
	if mesh_instance != null and mesh_instance.mesh != null:
		var arr: Array = mesh_instance.mesh.surface_get_arrays(0)
		verts = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		idx = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	return {"drawn": drawn, "max": MAX_PALPS, "ids": drawn_ids.size(),
			"surfaces": 1, "vertices": verts, "indices": idx,
			"cilia_per_palp": CILIA}


## Where the player is looking from. Falls back to the origin in headless
## runs, where there is no camera and nothing is being looked at anyway.
func _eye_position() -> Vector3:
	var vp := get_viewport()
	if vp != null:
		var camera := vp.get_camera_3d()
		if camera != null:
			return camera.global_position
	return global_position
