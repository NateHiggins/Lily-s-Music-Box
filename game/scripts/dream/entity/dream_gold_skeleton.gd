class_name DreamGoldSkeleton
extends RefCounted
## LIVING BIOMINERALIZATION (DIRECTION_2 §B, DIRECTION_3 §E–§F,
## HERO_PASS §2–§3).
##
## The gold is not jewellery on a tube and it is emphatically NOT a set of
## clean circumferential bands — that read was the largest departure from
## canon. Every structural piece is an INDIVIDUAL irregular mesh with its
## own class, so nothing repeats and nothing closes a ring:
##
##   CRESCENT   a broken skeletal arc that thins to nothing at both ends
##   PLATE      an asymmetric load-bearing shell, lobed on one flank
##   KNUCKLE    an articulated mineral joint: two masses and a waist
##   BRANCH     a strut that splits into two and buries one fork
##   SPUR       a short mineral outcrop that emerges from under the skin
##
## Each carries dendritic roots into the tissue, and the flesh answers with
## a raised lip, a pressed hollow, scarring and redirected veins (§B2). The
## mechanics are small enough to stay plausible and large enough to SEE
## (§3): plates shift against each other, a strut slides 1–3 mm, a knuckle
## rotates, a plate settles as the flesh contracts under it — all driven by
## the shared biological state, never random.

const SHADER := preload("res://shaders/dream_gold.gdshader")

enum Kind { CRESCENT, PLATE, KNUCKLE, BRANCH, SPUR }

## v along the limb, u around, span (m, half-length), breadth (× the body's
## radius — deliberately well under a wrap), rise, tilt, kind, seed.
## Uneven spacing, no two alike, and a clear gap at the ocular station.
const PIECES := [
	[0.045, 0.60, 0.075, 0.62, 1.30, 0.22, Kind.PLATE, 0.0],
	[0.088, 0.22, 0.030, 0.22, 0.80, -0.50, Kind.SPUR, 1.0],
	[0.155, 0.86, 0.048, 0.30, 0.95, 0.14, Kind.CRESCENT, 2.0],
	[0.205, 0.05, 0.036, 0.24, 0.85, 0.55, Kind.BRANCH, 3.0],
	[0.275, 0.52, 0.052, 0.44, 1.10, -0.28, Kind.KNUCKLE, 4.0],
	[0.320, 0.72, 0.024, 0.18, 0.72, 0.36, Kind.SPUR, 5.0],
	# — the ocular station's own gold belongs to the ocular assembly —
	[0.585, 0.44, 0.058, 0.52, 1.15, -0.20, Kind.PLATE, 6.0],
	[0.640, 0.12, 0.030, 0.20, 0.80, 0.44, Kind.CRESCENT, 7.0],
	[0.690, 0.78, 0.026, 0.22, 0.85, -0.34, Kind.BRANCH, 8.0],
	[0.745, 0.30, 0.042, 0.38, 1.05, 0.18, Kind.KNUCKLE, 9.0],
	[0.812, 0.62, 0.022, 0.18, 0.78, -0.12, Kind.SPUR, 10.0],
	[0.868, 0.16, 0.018, 0.15, 0.72, 0.30, Kind.CRESCENT, 11.0],
]
const DENDRITES_PER_PIECE := 5

var pieces: Array[MeshInstance3D] = []
var dendrites: MultiMeshInstance3D
var materials: Array[ShaderMaterial] = []
var dendrite_material: ShaderMaterial
var _lift := PackedFloat32Array()
var _slide := PackedFloat32Array()
var _roll := PackedFloat32Array()
var _seam := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var count := 0
var seam_energy := 0.0
var articulation := 0.0


func build(parent: Node3D, seed_v: int) -> void:
	_rng.seed = seed_v
	count = PIECES.size()
	_lift.resize(count)
	_slide.resize(count)
	_roll.resize(count)
	_seam.resize(count)
	# Individual meshes: a MultiMesh forces one shape on every piece, which
	# is exactly how the clean-band read happened.
	for i in count:
		var row: Array = PIECES[i]
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("seed", float(seed_v % 911) * 0.01 + float(row[7]))
		var mi := MeshInstance3D.new()
		mi.name = "GoldPiece%d" % i
		mi.mesh = _piece_mesh(int(row[6]), int(row[7]) * 977 + seed_v)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.visible = false
		parent.add_child(mi)
		pieces.append(mi)
		materials.append(m)
	dendrite_material = ShaderMaterial.new()
	dendrite_material.shader = SHADER
	dendrite_material.set_shader_parameter("seed", float(seed_v % 911) * 0.01 + 3.0)
	dendrite_material.set_shader_parameter("is_dendrite", true)
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_3D
	dm.use_custom_data = true
	dm.mesh = _dendrite_mesh()
	dm.instance_count = count * DENDRITES_PER_PIECE
	dendrites = MultiMeshInstance3D.new()
	dendrites.name = "GoldDendrites"
	dendrites.multimesh = dm
	dendrites.material_override = dendrite_material
	dendrites.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dendrites)


## Each class builds a genuinely different shell in unit space (x across the
## body, y out of it, z along the limb). Ends dip below y = 0 so the mesh
## visibly enters the flesh.
static func _piece_mesh(kind: int, seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var rings := 9
	var segs := 11
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var width := PackedFloat32Array()
	var lift := PackedFloat32Array()
	var shift := PackedFloat32Array()
	width.resize(rings)
	lift.resize(rings)
	shift.resize(rings)
	for r in rings:
		var t := float(r) / float(rings - 1)
		var w := 1.0
		var l := 1.0
		var sx := 0.0
		if kind == Kind.CRESCENT:
			# Thins to nothing at both ends and bows off-centre: an arc that
			# broke, not a segment of a ring.
			w = pow(sin(clampf(t, 0.0, 1.0) * PI), 0.65) * (0.55 + 0.45 * rng.randf())
			l = 0.55 + 0.75 * sin(t * PI)
			sx = sin(t * PI) * 0.35
		elif kind == Kind.PLATE:
			# Load-bearing: broad and high in the middle, one lobed flank,
			# an asymmetric termination.
			w = (0.35 + 0.9 * sin(clampf(t * 1.15, 0.0, 1.0) * PI)) * (0.7 + 0.5 * rng.randf())
			l = 0.7 + 0.6 * sin(t * PI * 0.9)
			sx = (t - 0.4) * 0.5
		elif kind == Kind.KNUCKLE:
			# Two masses with a waist between them: an articulation.
			var lobe := absf(sin(t * PI * 2.0))
			w = 0.35 + 0.85 * lobe
			l = 0.5 + 0.9 * lobe
			sx = cos(t * PI * 2.0) * 0.18
		elif kind == Kind.BRANCH:
			# Splits: full width to the fork, then two prongs, one diving
			# under the skin.
			if t < 0.5:
				w = 0.8 + 0.4 * t
				l = 0.8 + 0.4 * t
				sx = 0.0
			else:
				w = maxf(0.05, 1.25 - 1.6 * (t - 0.5))
				l = 1.0 - 1.3 * (t - 0.5)
				sx = (t - 0.5) * 1.1
		else:
			# SPUR: emerges from under the skin, short, and rises.
			w = 0.35 + 0.6 * (1.0 - t)
			l = -0.35 + 2.0 * t
			sx = t * 0.5
		width[r] = maxf(0.03, w * rng.randf_range(0.82, 1.0))
		lift[r] = l
		shift[r] = sx
	for r in rings:
		var t := float(r) / float(rings - 1)
		var z := t * 2.0 - 1.0
		for s in segs:
			var u := float(s) / float(segs - 1)
			var x := (u * 2.0 - 1.0) * width[r] + shift[r]
			var crown := maxf(0.0, 1.0 - pow(absf(u * 2.0 - 1.0), 1.6))
			var y := crown * lift[r] - 0.42
			verts.append(Vector3(x, y, z))
			normals.append(Vector3(x * 0.5, 1.0, z * 0.3).normalized())
			uvs.append(Vector2(u, t))
	for r in rings - 1:
		for s in segs - 1:
			var a := r * segs + s
			var b := a + 1
			var c := a + segs
			var d := c + 1
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)
	var base := verts.size()
	for i in base:
		var v := verts[i]
		verts.append(Vector3(v.x, v.y - 0.22 - 0.12 * (1.0 - absf(v.x)), v.z))
		normals.append(Vector3(v.x * 0.4, -1.0, v.z * 0.3).normalized())
		uvs.append(uvs[i])
	for r in rings - 1:
		for s in segs - 1:
			var a := base + r * segs + s
			var b := a + 1
			var c := a + segs
			var d := c + 1
			indices.append(a); indices.append(b); indices.append(c)
			indices.append(b); indices.append(d); indices.append(c)
	# The rim, so the piece has a visible edge where it leaves the flesh.
	for r in rings - 1:
		for e in 2:
			var s := 0 if e == 0 else segs - 1
			var a := r * segs + s
			var b := (r + 1) * segs + s
			var c := base + a
			var d := base + b
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


static func _dendrite_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var rings := 7
	var segs := 5
	for r in rings:
		var t := float(r) / float(rings - 1)
		var rad := (1.0 - t) * (1.0 - t) * 0.55 + 0.02
		var bend := Vector3(sin(t * 3.4) * 0.26, 0.0, cos(t * 2.1) * 0.18) * t
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


## Place every piece and its dendrites, and give the skeleton its visible
## mechanics (HERO_PASS §3).
func update(rig: DreamTentacleRig, grow: float, pulse_phase: float, breath_phase: float,
		attention: float, startle: float, delta: float) -> void:
	var dm := dendrites.multimesh
	seam_energy = 0.0
	articulation = 0.0
	for i in count:
		var row: Array = PIECES[i]
		var v := float(row[0])
		var u := float(row[1])
		var span := float(row[2])
		var breadth := float(row[3])
		var rise := float(row[4])
		var tilt := float(row[5])
		var kind := int(row[6])
		var pseed := float(row[7])
		var hidden := v > grow
		# --- mechanics ----------------------------------------------------
		# The beat travels: each piece answers later than the one before, so
		# the motion reads as a wave in a skeleton, not a machine's pulse.
		var beat := sin((pulse_phase - v * 0.4) * TAU)
		var breathe := sin((breath_phase - v * 0.15) * TAU)
		# At the top of the plausible range so it can be SEEN under a moving
		# flashlight (§3, §18): ~1.5 mm of lift, ~3 mm of slide.
		var scale_up := 1.0 if (kind == Kind.PLATE or kind == Kind.KNUCKLE) else 0.6
		var want_lift := (0.0011 * maxf(0.0, beat) + 0.0008 * breathe
				+ 0.0013 * attention * (1.0 - v) - 0.0016 * startle) * scale_up
		var want_slide := (0.0030 * sin(pulse_phase * TAU + pseed) * (0.35 + 0.65 * attention)
				- 0.0040 * startle) * scale_up
		var want_roll := 0.0
		if kind == Kind.KNUCKLE:
			want_roll = 0.055 * sin(pulse_phase * TAU + pseed * 0.7) + 0.09 * attention - 0.12 * startle
		elif kind == Kind.BRANCH:
			want_roll = 0.028 * breathe
		var prev_lift := _lift[i]
		_lift[i] = lerpf(_lift[i], want_lift, clampf(delta * 3.2, 0.0, 1.0))
		_slide[i] = lerpf(_slide[i], want_slide, clampf(delta * 2.4, 0.0, 1.0))
		_roll[i] = lerpf(_roll[i], want_roll, clampf(delta * 2.6, 0.0, 1.0))
		var motion: float = absf(_lift[i] - prev_lift) * 2600.0 + absf(_slide[i]) * 180.0 \
				+ absf(_roll[i]) * 6.0
		_seam[i] = lerpf(_seam[i], clampf(motion, 0.0, 1.0), clampf(delta * 4.0, 0.0, 1.0))
		seam_energy = maxf(seam_energy, _seam[i])
		articulation = maxf(articulation, absf(_slide[i]) * 300.0 + absf(_roll[i]) * 8.0)
		# --- placement -----------------------------------------------------
		var vv := clampf(v + _slide[i], 0.0, 0.99)
		var f := rig.frame_at(vv)
		var a := u * TAU + float(f.twist) + rig.roll_at(vv) + _roll[i]
		var sd: Vector3 = f.side
		var bn: Vector3 = f.binormal
		var tng: Vector3 = f.tangent
		var radial := (sd * cos(a) + bn * sin(a)).normalized()
		var r := float(f.radius)
		var origin: Vector3 = (f.pos as Vector3) + radial * (r * 0.84 + _lift[i])
		var along := tng.rotated(radial, tilt).normalized()
		var across := radial.cross(along).normalized()
		var basis := Basis(across * (r * breadth), radial * (r * 0.50 * rise), along * span)
		var xf := Transform3D(basis, origin)
		if hidden:
			xf = Transform3D(Basis().scaled(Vector3(0.0001, 0.0001, 0.0001)), origin)
		pieces[i].transform = xf
		pieces[i].visible = not hidden and grow > 0.03
		materials[i].set_shader_parameter("motion", _seam[i])
		# --- dendrites ------------------------------------------------------
		for k in DENDRITES_PER_PIECE:
			var idx := i * DENDRITES_PER_PIECE + k
			var kf := (float(k) + 0.5) / float(DENDRITES_PER_PIECE)
			var edge_a := a + (kf - 0.5) * breadth * 3.8 * (1.0 if k % 2 == 0 else -1.0)
			var edge_v := clampf(vv + (kf - 0.5) * span * 2.8, 0.0, 0.99)
			var ef := rig.frame_at(edge_v)
			var ea := edge_a + float(ef.twist) + rig.roll_at(edge_v)
			var erad := ((ef.side as Vector3) * cos(ea) + (ef.binormal as Vector3) * sin(ea)).normalized()
			var er := float(ef.radius)
			var length := er * (0.26 + 0.42 * kf) * (0.7 + 0.5 * sin(pseed + kf * 7.0))
			var thick := er * 0.05 * (1.0 - 0.4 * kf)
			var d_origin: Vector3 = (ef.pos as Vector3) + erad * (er * 0.70)
			var lean := (erad + (ef.tangent as Vector3) * (kf - 0.5) * 0.9).normalized()
			var any := Vector3.UP if absf(lean.y) < 0.9 else Vector3.RIGHT
			var dx := any.cross(lean).normalized()
			var dz := lean.cross(dx).normalized()
			var dxf := Transform3D(Basis(dx * thick, lean * length, dz * thick), d_origin)
			if edge_v > grow:
				dxf = Transform3D(Basis().scaled(Vector3(0.0001, 0.0001, 0.0001)), d_origin)
			dm.set_instance_transform(idx, dxf)
			dm.set_instance_custom_data(idx, Color(_seam[i] * 0.4, pseed * 0.1 + kf, 0.0, 0.0))
	dendrites.visible = grow > 0.03


## An orbital piece for the ocular assembly: the same grown shell, shorter
## and heavier.
static func orbit_piece_mesh() -> ArrayMesh:
	return _piece_mesh(Kind.CRESCENT, 5150)


## The roots the flesh shader needs, so the tissue scars and compresses
## where metal comes through (§B2). (v, u, breadth) per piece.
static func roots() -> Array:
	var out: Array = []
	for row in PIECES:
		out.append(Vector3(float(row[0]), float(row[1]), float(row[3])))
	return out


func set_debug_gray(on: bool) -> void:
	for m in materials:
		m.set_shader_parameter("debug_gray", on)
	dendrite_material.set_shader_parameter("debug_gray", on)


func set_visible(on: bool) -> void:
	for mi in pieces:
		mi.visible = on
	dendrites.visible = on
