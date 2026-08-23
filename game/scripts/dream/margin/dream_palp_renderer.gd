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

var controller: DreamMarginController = null
var material: ShaderMaterial
var mesh_instance: MeshInstance3D
var drawn := 0

var _spine := PackedVector3Array()
var _section := PackedVector4Array()
var _params := PackedVector4Array()
var _matter := PackedVector4Array()
var _clock := 0.0


func setup(margin: DreamMarginController) -> void:
	name = "DreamPalpRenderer"
	controller = margin
	_spine.resize(MAX_PALPS * JOINTS)
	_section.resize(MAX_PALPS * 4)
	_params.resize(MAX_PALPS)
	_matter.resize(MAX_PALPS)
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
	for i in mini(controller.palps.size(), MAX_PALPS):
		var p: Dictionary = controller.palps[i]
		_lay(drawn, p)
		drawn += 1
	# Anything past the live population is collapsed rather than left stale.
	for i in range(drawn, MAX_PALPS):
		_params[i] = Vector4.ZERO
	material.set_shader_parameter("palp_spine", _spine)
	material.set_shader_parameter("palp_section", _section)
	material.set_shader_parameter("palp_params", _params)
	material.set_shader_parameter("palp_matter", _matter)
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
	var ln: float = float(morph.length) * float(p.grow)
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
		# A slow tremor, strongest at the tip. Placeholder until the behavior
		# layer (§9) drives these from real intent rather than from time.
		var tremor: float = float(morph.cilia) * 0.006 * t
		point += side * sin(_clock * 5.5 + sd * 4.0) * tremor
		_spine[slot * JOINTS + j] = point
	for k in 4:
		_section[slot * 4 + k] = morph.sections[k]
	_params[slot] = Vector4(float(p.grow), float(morph.base_radius),
			float(morph.tip_ratio), sd)
	_matter[slot] = Vector4(float(morph.gold), float(morph.crystal),
			float(morph.suckers), float(morph.cilia))


func census() -> Dictionary:
	return {"drawn": drawn, "max": MAX_PALPS}
