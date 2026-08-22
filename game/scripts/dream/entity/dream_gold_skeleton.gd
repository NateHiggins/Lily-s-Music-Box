class_name DreamGoldSkeleton
extends RefCounted
## Living biomineralization (DIRECTION_2 §B, DIRECTION_3 §E–§F): the gold is
## not jewellery on a tube. It is a skeleton the organism precipitated —
## irregular structural plates that ENTER AND EXIT the flesh, dendritic
## struts branching from them into tissue, and (near the orbit) sockets that
## carry the eye and the crystal.
##
## Three classes, per the ruling:
##   1. STRUCTURAL — real geometry, 3–20 cm, affects silhouette. Each plate
##      is an asymmetric shell wrapped to the body's cross-section over a
##      short span, sunk so its ends are under the skin.
##   2. DENDRITIC — branching struts of millimetre-to-centimetre scale
##      growing from a plate's root out into the flesh, so the plate is
##      visibly anchored rather than resting on the surface.
##   3. MICROSCOPIC — the shader's mineral grain around every root.
##
## Every piece has its own tiny autonomous motion (§F): plates separate by
## fractions of a millimetre on the muscular beat, slide under a neighbour,
## tighten on attention, lock together on a startle. The amplitudes are
## deliberately at the edge of perception — the horror is noticing it moved.

const SHADER := preload("res://shaders/dream_gold.gdshader")

## Where the plates grow, as (v along the limb, u around, span, breadth,
## rise, tilt, seed). Asymmetric on purpose: no two at the same u, no
## regular spacing, and a gap where the eye's orbit will be.
## v along the limb, u around, span (m), breadth (x the body's radius),
## rise, tilt, seed. Anatomical scale: 4–16 cm, none the same size, none
## evenly spaced, and a deliberate bare stretch where the orbit will sit.
## A plate is a PIECE OF SKELETON on one side of the body, never a strap
## that wraps it: breadth well under the circumference, span short enough
## that the limb's own curve carries its ends under the skin.
const PLATES := [
	[0.055, 0.62, 0.075, 0.62, 1.05, 0.20, 0.0],
	[0.150, 0.16, 0.052, 0.46, 0.85, -0.42, 1.0],
	[0.240, 0.86, 0.062, 0.54, 0.95, 0.12, 2.0],
	[0.335, 0.04, 0.044, 0.38, 0.75, 0.48, 3.0],
	[0.610, 0.50, 0.050, 0.46, 0.88, -0.26, 4.0],
	[0.705, 0.22, 0.036, 0.34, 0.72, 0.34, 5.0],
	[0.795, 0.74, 0.030, 0.30, 0.68, -0.18, 6.0],
	[0.885, 0.31, 0.022, 0.26, 0.62, 0.28, 7.0],
]
const DENDRITES_PER_PLATE := 5
const RINGS_PER_PLATE := 7
const SEGS_PER_PLATE := 9

var plates: MultiMeshInstance3D
var dendrites: MultiMeshInstance3D
var material: ShaderMaterial
var dendrite_material: ShaderMaterial
## Per-plate mechanical state (§F): lift, slide, tighten, each eased.
var _lift := PackedFloat32Array()
var _slide := PackedFloat32Array()
var _seam := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var count := 0
var seam_energy := 0.0


func build(parent: Node3D, seed_v: int) -> void:
	_rng.seed = seed_v
	count = PLATES.size()
	_lift.resize(count)
	_slide.resize(count)
	_seam.resize(count)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("seed", float(seed_v % 911) * 0.01)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _plate_mesh()
	mm.instance_count = count
	plates = MultiMeshInstance3D.new()
	plates.name = "GoldPlates"
	plates.multimesh = mm
	plates.material_override = material
	plates.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(plates)
	# Dendrites: thin tapered struts, one multimesh for all plates.
	dendrite_material = ShaderMaterial.new()
	dendrite_material.shader = SHADER
	dendrite_material.set_shader_parameter("seed", float(seed_v % 911) * 0.01 + 3.0)
	dendrite_material.set_shader_parameter("is_dendrite", true)
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_3D
	dm.use_custom_data = true
	dm.mesh = _dendrite_mesh()
	dm.instance_count = count * DENDRITES_PER_PLATE
	dendrites = MultiMeshInstance3D.new()
	dendrites.name = "GoldDendrites"
	dendrites.multimesh = dm
	dendrites.material_override = dendrite_material
	dendrites.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dendrites)


## A plate: a curved shell in unit space (x across the body, y out from it,
## z along the limb), thicker at its crown and thinning to nothing at its
## edges, with an irregular outline so it never reads as a band segment.
## Its ends dip BELOW y = 0 so the geometry visibly enters the flesh.
func _plate_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 40503
	# Outline irregularity per ring, so the silhouette is grown, not milled.
	var jag := PackedFloat32Array()
	jag.resize(RINGS_PER_PLATE)
	for r in RINGS_PER_PLATE:
		jag[r] = rng.randf_range(0.72, 1.0)
	for r in RINGS_PER_PLATE:
		var t := float(r) / float(RINGS_PER_PLATE - 1)
		# Along the limb: -1 .. 1
		var z := t * 2.0 - 1.0
		for s in SEGS_PER_PLATE:
			var u := float(s) / float(SEGS_PER_PLATE - 1)
			# Around the body: -1 .. 1 of the plate's breadth, jagged.
			var x := (u * 2.0 - 1.0) * jag[r]
			# The shell: crowned in the middle, sinking under the skin at
			# both ends of both axes.
			var crown := (1.0 - x * x) * (1.0 - z * z * z * z)
			var y := crown * 1.0 - 0.35
			verts.append(Vector3(x, y, z))
			normals.append(Vector3(x * 0.5, 1.0, z * 0.3).normalized())
			uvs.append(Vector2(u, t))
	for r in RINGS_PER_PLATE - 1:
		for s in SEGS_PER_PLATE - 1:
			var a := r * SEGS_PER_PLATE + s
			var b := a + 1
			var c := a + SEGS_PER_PLATE
			var d := c + 1
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)
	# The underside, so the plate has thickness where it lifts.
	var base := verts.size()
	for i in base:
		var v := verts[i]
		verts.append(Vector3(v.x, v.y - 0.16 - 0.1 * (1.0 - absf(v.x)), v.z))
		normals.append(Vector3(v.x * 0.4, -1.0, v.z * 0.3).normalized())
		uvs.append(uvs[i])
	for r in RINGS_PER_PLATE - 1:
		for s in SEGS_PER_PLATE - 1:
			var a := base + r * SEGS_PER_PLATE + s
			var b := a + 1
			var c := a + SEGS_PER_PLATE
			var d := c + 1
			indices.append(a); indices.append(b); indices.append(c)
			indices.append(b); indices.append(d); indices.append(c)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A dendrite: a tapered, slightly kinked spike along +y, that starts inside
## the flesh and breaks the surface — a mineral root, not a spine.
func _dendrite_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rings := 6
	var segs := 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	for r in rings:
		var t := float(r) / float(rings - 1)
		var rad := (1.0 - t) * (1.0 - t) * 0.5 + 0.02
		# A kink, so it looks precipitated rather than extruded.
		var bend := Vector3(sin(t * 3.4) * 0.22, 0.0, cos(t * 2.1) * 0.16) * t
		for s in segs:
			var a := float(s) / float(segs - 1) * TAU
			verts.append(Vector3(cos(a) * rad, t * 2.0 - 0.5, sin(a) * rad) + bend)
			normals.append(Vector3(cos(a), 0.35, sin(a)).normalized())
			uvs.append(Vector2(float(s) / float(segs - 1), t))
	for r in rings - 1:
		for s in segs - 1:
			var a := r * segs + s
			var b := a + 1
			var c := a + segs
			var d := c + 1
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Place every plate and dendrite on the rig, and give the plates their
## minute mechanical life (§F).
func update(rig: DreamTentacleRig, grow: float, pulse_phase: float, breath_phase: float,
		attention: float, startle: float, delta: float) -> void:
	var mm := plates.multimesh
	var dm := dendrites.multimesh
	seam_energy = 0.0
	for i in count:
		var row: Array = PLATES[i]
		var v := float(row[0])
		var u := float(row[1])
		var span := float(row[2])
		var breadth := float(row[3])
		var rise := float(row[4])
		var tilt := float(row[5])
		var pseed := float(row[6])
		var hidden := v > grow
		# --- the mechanics (§F) ------------------------------------------
		# The beat travels along the body: each plate answers a little later
		# than the one before it, so the motion reads as a wave in a skeleton
		# rather than a pulse in a machine.
		var beat := sin((pulse_phase - v * 0.35) * TAU)
		var breathe := sin((breath_phase - v * 0.12) * TAU)
		var want_lift := 0.00022 * maxf(0.0, beat) + 0.00016 * breathe \
				+ 0.00030 * attention * (1.0 - v) - 0.00045 * startle
		var want_slide := 0.0012 * sin(pulse_phase * TAU + pseed) * (0.3 + 0.7 * attention) \
				- 0.0020 * startle
		_lift[i] = lerpf(_lift[i], want_lift, clampf(delta * 3.0, 0.0, 1.0))
		_slide[i] = lerpf(_slide[i], want_slide, clampf(delta * 2.2, 0.0, 1.0))
		# The seam under a plate brightens as it moves and dims as it seats (§B8).
		var motion: float = absf(want_lift - _lift[i]) * 3000.0 + absf(_slide[i]) * 220.0
		_seam[i] = lerpf(_seam[i], clampf(motion, 0.0, 1.0), clampf(delta * 4.0, 0.0, 1.0))
		seam_energy = maxf(seam_energy, _seam[i])
		# --- placement ----------------------------------------------------
		var f := rig.frame_at(clampf(v + _slide[i], 0.0, 0.99))
		var a := u * TAU + float(f.twist) + rig.roll_at(v)
		var sd: Vector3 = f.side
		var bn: Vector3 = f.binormal
		var tng: Vector3 = f.tangent
		var radial := (sd * cos(a) + bn * sin(a)).normalized()
		var r := float(f.radius)
		# The plate sits AT the flesh's radius, not above it: the mesh's own
		# form carries its ends under the skin.
		var origin: Vector3 = (f.pos as Vector3) + radial * (r * 0.86 + _lift[i])
		var across := radial.cross(tng).normalized()
		# Tilt: the plate is not square to the limb.
		var along := tng.rotated(radial, tilt).normalized()
		across = radial.cross(along).normalized()
		# The plate mesh spans -1..1 in z, so `span` is its HALF length.
		var basis := Basis(across * (r * breadth), radial * (r * 0.55 * rise), along * (span * 0.5))
		var xf := Transform3D(basis, origin)
		if hidden:
			xf = Transform3D(Basis().scaled(Vector3(0.0001, 0.0001, 0.0001)), origin)
		mm.set_instance_transform(i, xf)
		mm.set_instance_custom_data(i, Color(_seam[i], pseed * 0.1, 1.0, 0.0))
		# --- dendrites: from this plate's edge, out into the flesh --------
		for k in DENDRITES_PER_PLATE:
			var idx := i * DENDRITES_PER_PLATE + k
			var kf := (float(k) + 0.5) / float(DENDRITES_PER_PLATE)
			# Around the plate's rim, alternating sides, at varied lengths.
			var edge_a := a + (kf - 0.5) * breadth * 3.4 * (1.0 if k % 2 == 0 else -1.0)
			var edge_v := clampf(v + (kf - 0.5) * span * 2.6, 0.0, 0.99)
			var ef := rig.frame_at(edge_v)
			var ea := edge_a + float(ef.twist) + rig.roll_at(edge_v)
			var erad := ((ef.side as Vector3) * cos(ea) + (ef.binormal as Vector3) * sin(ea)).normalized()
			var er := float(ef.radius)
			var length := er * (0.30 + 0.45 * kf) * (0.7 + 0.5 * sin(pseed + kf * 7.0))
			var thick := er * 0.055 * (1.0 - 0.4 * kf)
			var d_origin: Vector3 = (ef.pos as Vector3) + erad * (er * 0.72)
			# Splay: dendrites lean away from the plate as they grow.
			var lean := (erad + (ef.tangent as Vector3) * (kf - 0.5) * 0.9).normalized()
			var any := Vector3.UP if absf(lean.y) < 0.9 else Vector3.RIGHT
			var dx := any.cross(lean).normalized()
			var dz := lean.cross(dx).normalized()
			var dxf := Transform3D(Basis(dx * thick, lean * length, dz * thick), d_origin)
			if edge_v > grow:
				dxf = Transform3D(Basis().scaled(Vector3(0.0001, 0.0001, 0.0001)), d_origin)
			dm.set_instance_transform(idx, dxf)
			dm.set_instance_custom_data(idx, Color(_seam[i] * 0.4, pseed * 0.1 + kf, 0.0, 0.0))
	plates.visible = grow > 0.03
	dendrites.visible = grow > 0.03


## The roots the flesh shader needs, so the tissue scars and compresses
## where metal comes through (§B2). Returns (v, u, strength) per plate.
static func roots() -> Array:
	var out: Array = []
	for row in PLATES:
		out.append(Vector3(float(row[0]), float(row[1]), float(row[3])))
	return out


func set_debug_gray(on: bool) -> void:
	material.set_shader_parameter("debug_gray", on)
	dendrite_material.set_shader_parameter("debug_gray", on)


func set_visible(on: bool) -> void:
	plates.visible = on
	dendrites.visible = on
