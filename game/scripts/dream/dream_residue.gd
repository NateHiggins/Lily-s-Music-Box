class_name DreamResidue
extends Node3D
## What the creature leaves behind (design/DREAM_SALIVA_DIRECTION.md).
##
##     "an iridescent holographic reflective saliva goo on everything it
##      touches that crystalizes like superchilled frost ... and decay like
##      its being eroded by an eon of time in a couple seconds"
##
## A pool of patches, all in ONE mesh and ONE draw. A contact writes a patch;
## the patch carries its own clock and the shader plays an entire geological
## history across it in a few seconds.
##
## Anything that touches a surface can feed this — the hero limb today, the
## margin's palps and the critters later — and §28 says they should not all
## leave the same amount: the hero gets the richest transformation.

const SHADER := preload("res://shaders/dream_residue.gdshader")
const MAX_PATCHES := 24
const SEGMENTS := 14
const RINGS := 4

var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var field = null

## Per patch: (centre, radius), (normal, age), (seed, intensity, life, 0)
var _pos := PackedVector4Array()
var _nrm := PackedVector4Array()
var _par := PackedVector4Array()
var _live := 0
var _next := 0
var _rng := RandomNumberGenerator.new()
var laid := 0


func setup(seed_v: int) -> void:
	name = "DreamResidue"
	_rng.seed = seed_v
	_pos.resize(MAX_PATCHES)
	_nrm.resize(MAX_PATCHES)
	_par.resize(MAX_PATCHES)
	material = ShaderMaterial.new()
	material.shader = SHADER
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Residue"
	mesh_instance.mesh = _build_mesh()
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.extra_cull_margin = 24.0
	add_child(mesh_instance)


## A unit disc per patch. The shader places it on the surface it was left on.
func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for p in MAX_PATCHES:
		var base := verts.size()
		for ring in RINGS + 1:
			var rr := float(ring) / float(RINGS)
			for seg in SEGMENTS:
				var a := float(seg) / float(SEGMENTS) * TAU
				verts.append(Vector3(cos(a) * rr, sin(a) * rr, 0.0))
				normals.append(Vector3(0, 0, 1))
				uvs.append(Vector2(rr, float(seg) / float(SEGMENTS)))
				uv2.append(Vector2(float(p), 0.0))
		for ring in RINGS:
			for seg in SEGMENTS:
				var n := (seg + 1) % SEGMENTS
				var a0 := base + ring * SEGMENTS + seg
				var a1 := base + ring * SEGMENTS + n
				var b0 := base + (ring + 1) * SEGMENTS + seg
				var b1 := base + (ring + 1) * SEGMENTS + n
				indices.append(a0); indices.append(b0); indices.append(a1)
				indices.append(a1); indices.append(b0); indices.append(b1)
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


## §28 — intensity is per-organism. The hero transforms a surface far more
## than a margin palp brushing past it does.
##
## A patch also records WHERE ALONG w THE DREAM WAS when it was left. The goo
## has extent along the fourth axis like everything else here, and what the
## wall shows is the slice; to know which slice, a patch has to remember where
## it started. `dream_w` itself only ever increases, so it cannot be used
## directly -- a patch two hours into a session would be a hundred slices past
## its own substance.
func lay(at: Vector3, nrm: Vector3, radius: float = 0.11,
		intensity: float = 1.0, life: float = 3.4) -> void:
	var slot := -1
	for i in MAX_PATCHES:
		if float(_par[i].z) <= 0.0:
			slot = i
			break
	if slot < 0:
		# Reuse the oldest rather than refusing to mark the world.
		slot = _next
		_next = (_next + 1) % MAX_PATCHES
	_pos[slot] = Vector4(at.x, at.y, at.z, radius)
	_nrm[slot] = Vector4(nrm.x, nrm.y, nrm.z, 0.0)
	var born_w := 0.0
	if field != null and field.state != null:
		born_w = field.state.dream_w
	_par[slot] = Vector4(_rng.randf_range(0.0, 10.0), intensity, life, born_w)
	laid += 1


func _process(delta: float) -> void:
	_live = 0
	for i in MAX_PATCHES:
		var par := _par[i]
		if par.z <= 0.0:
			continue
		var nrm := _nrm[i]
		nrm.w += delta
		_nrm[i] = nrm
		if nrm.w > par.z:
			_par[i] = Vector4.ZERO
			continue
		_live += 1
	material.set_shader_parameter("patch_pos", _pos)
	material.set_shader_parameter("patch_nrm", _nrm)
	material.set_shader_parameter("patch_par", _par)
	material.set_shader_parameter("patch_count", MAX_PATCHES)
	if field != null and field.state != null:
		material.set_shader_parameter("dream_w", field.state.dream_w)
	mesh_instance.visible = _live > 0


## §21 — what a scavenger can find. The nearest live patch within `radius`.
func nearest_patch(at: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for i in MAX_PATCHES:
		if float(_par[i].z) <= 0.0:
			continue
		var p := _pos[i]
		var centre := Vector3(p.x, p.y, p.z)
		var d: float = at.distance_to(centre)
		if d < best_d:
			best_d = d
			best = {"at": centre, "radius": p.w, "age": float(_nrm[i].w)}
	return best


func census() -> Dictionary:
	return {"live": _live, "laid": laid, "max": MAX_PATCHES}
