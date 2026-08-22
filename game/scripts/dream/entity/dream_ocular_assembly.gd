class_name DreamOcularAssembly
extends RefCounted
## THE OCULAR ORGAN (DIRECTION_2 §C, DIRECTION_3 §H–§J).
##
## Not an eyeball on a hose. An organ the organism had to evolve substantial
## anatomy to support, sited at 42 % of the limb — so the distal end is
## tactile and the intelligence sits back in the mass. Its parts:
##
##   SOCKET      a real depression in the flesh (the limb's own shader cuts
##               it, with an overhanging brow, a cushioning fold below and
##               lateral folds); the globe is sunk so the complete sphere is
##               never inferable, and from oblique angles tissue eats it.
##   GLOBE       layered geometry: the eyeball body, an iris recessed under
##               a separate corneal bulge, a pupil deeper than the eye can
##               hold, and a tear film.
##   ORBIT       an asymmetric gold skeleton — one heavy brow, branching
##               supports, cilia follicle rings — that cradles the globe,
##               anchors the lids and tenses when the eye tracks.
##   LIDS        three, on three vectors: A sweeps obliquely, B twists round
##               the orbital circumference, C is a nictitating membrane on
##               another axis entirely. They overlap for a fraction of a
##               second and no two share timing.
##   CILIA       eighteen hero filaments in three classes from visible
##               follicles, with spring secondary motion; they detect and
##               orient BEFORE the eye turns.
##   CRYSTAL     one transition organ in the orbit's gold, rooted in tissue.
##
## The order of a reaction is the point (§I): cilia notice → orbital gold
## tenses → lids make a minute anticipatory adjustment → the globe moves →
## the surrounding flesh catches up.

const EyeShader := preload("res://shaders/dream_eye.gdshader")
const LidShader := preload("res://shaders/dream_eyelid.gdshader")
const CiliaShader := preload("res://shaders/dream_cilia.gdshader")
const CrystalShader := preload("res://shaders/dream_crystal.gdshader")
const GoldShader := preload("res://shaders/dream_gold.gdshader")

## Where the organ sits on the limb, and how big it is.
const EYE_V := 0.42
const EYE_U := 0.18
## The globe is an ORGAN IN the limb, so it must be well under the limb's
## own radius there (~41 mm at v = 0.42, and the profile now swells to carry
## it). A 36 mm eye in a 100 mm orbital mass.
const GLOBE_R := 0.018
## How deep the globe sits BELOW the flesh surface, as a fraction of its own
## radius. At 0.55 a little under half the sphere is above the rim before the
## socket's brow and folds take more of it — the complete sphere is never
## inferable. (The first pass seated it at the limb's AXIS, so a 46 mm globe
## swallowed a 41 mm limb.)
const SINK := 0.55
const CILIA_N := 18
## The three lids, as (kind, sweep axis in the socket's frame (radians),
## arc, reach, rest, seed).
const LIDS := [
	[0, -0.55, 2.5, 1.22, 0.10, 0.0],
	[1, 2.30, 2.1, 1.10, 0.08, 1.0],
	[2, 1.05, 2.8, 1.05, 0.00, 2.0],
]

var root: Node3D
var globe: MeshInstance3D
var cornea: MeshInstance3D
var lids: Array[MeshInstance3D] = []
var lid_materials: Array[ShaderMaterial] = []
var orbit: MultiMeshInstance3D
var cilia: MultiMeshInstance3D
var crystal: MeshInstance3D
var eye_material: ShaderMaterial
var cornea_material: ShaderMaterial
var cilia_material: ShaderMaterial
var crystal_material: ShaderMaterial
var orbit_material: ShaderMaterial

## State the controller reads and writes.
var mode := "closed"
var openness := 0.0
var pupil := 0.30
var interior := 0.0
var gaze := Vector3.FORWARD
var position := Vector3.ZERO
var normal := Vector3.UP
var socket_side := Vector3.RIGHT
var socket_up := Vector3.UP
var viewer_pos := Vector3.ZERO
var attention := 0.3
var orbit_tension := 0.0
var last_events: Array[String] = []

## Per-lid closure, each with its own timing (§I).
var _closure := PackedFloat32Array()
var _blink_seq := -1.0
## Per-cilium spring state: current direction, velocity, and its alert.
var _cilia_dir := PackedVector3Array()
var _cilia_vel := PackedVector3Array()
var _cilia_alert := PackedFloat32Array()
var _cilia_spec: Array = []
var _rng := RandomNumberGenerator.new()
var _next_blink := 7.0
var _blink_clock := 0.0
var _explore_clock := 0.0
var _explore_dir := Vector3.FORWARD
var _interior_event := 0.0
var _clock := 0.0
var _stimulus := Vector3.ZERO
var _stimulus_strength := 0.0


func build(parent: Node3D, seed_v: int) -> void:
	root = parent
	_rng.seed = seed_v
	var s := float(seed_v % 977) * 0.01
	_build_globe(s)
	_build_lids(s)
	_build_orbit(s)
	_build_cilia(s)
	_build_crystal(s)
	_next_blink = _rng.randf_range(5.0, 11.0)


# ---------------------------------------------------------------- geometry


func _build_globe(s: float) -> void:
	# The globe: a sphere, most of which will be under the socket's rim.
	var sphere := SphereMesh.new()
	sphere.radius = GLOBE_R
	sphere.height = GLOBE_R * 2.0
	sphere.radial_segments = 56
	sphere.rings = 36
	eye_material = ShaderMaterial.new()
	eye_material.shader = EyeShader
	eye_material.set_shader_parameter("seed", s)
	globe = MeshInstance3D.new()
	globe.name = "Eye"
	globe.mesh = sphere
	globe.material_override = eye_material
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	globe.visible = false
	root.add_child(globe)
	# The corneal bulge: a separate convex cap over the iris, its own
	# surface, with the tear film on it (§C3).
	var cap := SphereMesh.new()
	cap.radius = GLOBE_R * 0.62
	cap.height = GLOBE_R * 1.24
	cap.radial_segments = 40
	cap.rings = 24
	cornea_material = ShaderMaterial.new()
	cornea_material.shader = EyeShader
	cornea_material.set_shader_parameter("seed", s)
	cornea_material.set_shader_parameter("is_cornea", true)
	cornea = MeshInstance3D.new()
	cornea.name = "Cornea"
	cornea.mesh = cap
	cornea.material_override = cornea_material
	cornea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cornea.visible = false
	root.add_child(cornea)


## A lid is a curved shell: an annular sector swept about the socket's axis,
## bowed to the globe's curvature, with real thickness at its margin.
static func _lid_mesh(arc: float, reach: float, thickness: float) -> ArrayMesh:
	var cols := 22
	var rows := 9
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for r in rows:
		var t := float(r) / float(rows - 1)
		# From the socket rim (t = 0) toward the centre (t = 1).
		var polar := lerpf(1.15, 1.15 - reach, t)
		for c in cols:
			var a := (float(c) / float(cols - 1) - 0.5) * arc
			# On a sphere of radius 1, then flattened a little so the lid
			# stands off the globe rather than shrink-wrapping it.
			var sp := sin(clampf(polar, 0.0, PI * 0.5))
			var cp := cos(clampf(polar, 0.0, PI * 0.5))
			var p := Vector3(sin(a) * sp, cp * 1.02, cos(a) * sp)
			verts.append(p)
			normals.append(p.normalized())
			uvs.append(Vector2(float(c) / float(cols - 1), t))
	for r in rows - 1:
		for c in cols - 1:
			var a := r * cols + c
			var b := a + 1
			var d := a + cols
			var e := d + 1
			indices.append(a); indices.append(d); indices.append(b)
			indices.append(b); indices.append(d); indices.append(e)
	# The inner face, offset inward: the lid has thickness and a margin.
	var base := verts.size()
	for i in base:
		var v := verts[i]
		var inset := 1.0 - thickness * (0.35 + 0.65 * uvs[i].y)
		verts.append(v * inset)
		normals.append(-v.normalized())
		uvs.append(uvs[i])
	for r in rows - 1:
		for c in cols - 1:
			var a := base + r * cols + c
			var b := a + 1
			var d := a + cols
			var e := d + 1
			indices.append(a); indices.append(b); indices.append(d)
			indices.append(b); indices.append(e); indices.append(d)
	# The free margin: a rim joining the two faces, which is what the player
	# actually sees when the lid is closed.
	var last := (rows - 1) * cols
	for c in cols - 1:
		var a := last + c
		var b := a + 1
		var d := base + last + c
		var e := d + 1
		indices.append(a); indices.append(b); indices.append(d)
		indices.append(b); indices.append(e); indices.append(d)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_lids(s: float) -> void:
	_closure.resize(LIDS.size())
	for i in LIDS.size():
		var row: Array = LIDS[i]
		var kind := int(row[0])
		var mesh := _lid_mesh(float(row[2]), float(row[3]), 0.16 if kind < 2 else 0.05)
		var m := ShaderMaterial.new()
		m.shader = LidShader
		m.set_shader_parameter("lid_kind", kind)
		m.set_shader_parameter("seed", s + float(row[5]))
		var mi := MeshInstance3D.new()
		mi.name = "Lid%d" % i
		mi.mesh = mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.visible = false
		root.add_child(mi)
		lids.append(mi)
		lid_materials.append(m)


## The orbital skeleton: one heavy brow and a set of asymmetric supports and
## follicle rings, each an irregular gold shell. Not a circular frame.
const ORBIT_PIECES := [
	# angle about the socket, polar reach, width, length, thickness, seed.
	# One heavy brow and a scatter of smaller supports at uneven angles;
	# nothing is repeated and nothing closes a circle.
	[-0.42, 1.28, 0.86, 0.34, 0.30, 0.0],   # the heavy brow
	[-0.05, 1.36, 0.40, 0.19, 0.16, 1.0],
	[0.62, 1.26, 0.30, 0.15, 0.12, 2.0],
	[1.48, 1.34, 0.22, 0.11, 0.09, 3.0],
	[2.42, 1.38, 0.46, 0.22, 0.17, 4.0],
	[2.95, 1.30, 0.26, 0.13, 0.10, 5.0],
	[3.70, 1.36, 0.19, 0.10, 0.08, 6.0],
	[4.38, 1.40, 0.36, 0.17, 0.13, 7.0],
	[5.10, 1.28, 0.24, 0.12, 0.10, 8.0],
	[5.62, 1.34, 0.44, 0.20, 0.16, 9.0],
]


func _build_orbit(s: float) -> void:
	orbit_material = ShaderMaterial.new()
	orbit_material.shader = GoldShader
	orbit_material.set_shader_parameter("seed", s + 7.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = DreamGoldSkeleton.orbit_piece_mesh()
	mm.instance_count = ORBIT_PIECES.size()
	orbit = MultiMeshInstance3D.new()
	orbit.name = "OrbitalGold"
	orbit.multimesh = mm
	orbit.material_override = orbit_material
	orbit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	orbit.visible = false
	root.add_child(orbit)


## Eighteen hero cilia: length, curvature, stiffness, thickness, class and
## orientation all varied, arranged asymmetrically round the orbital folds.
func _build_cilia(s: float) -> void:
	cilia_material = ShaderMaterial.new()
	cilia_material.shader = CiliaShader
	cilia_material.set_shader_parameter("seed", s + 11.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _cilium_mesh()
	mm.instance_count = CILIA_N
	cilia = MultiMeshInstance3D.new()
	cilia.name = "OrbitalCilia"
	cilia.multimesh = mm
	cilia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cilia.material_override = cilia_material
	cilia.visible = false
	root.add_child(cilia)
	_cilia_dir.resize(CILIA_N)
	_cilia_vel.resize(CILIA_N)
	_cilia_alert.resize(CILIA_N)
	_cilia_spec.clear()
	for i in CILIA_N:
		# Class: mostly flesh, a few gold, two crystal — sparse, as ruled.
		var kind := 0
		if i % 5 == 2:
			kind = 1
		if i == 4 or i == 13:
			kind = 2
		# Asymmetric: denser above the eye, sparse below, none on the side
		# the heavy brow occupies.
		var a := _rng.randf_range(0.0, TAU)
		if i < 10:
			a = lerpf(-1.15, 1.35, float(i) / 9.0) + _rng.randf_range(-0.12, 0.12)
		else:
			a = lerpf(2.0, 5.1, float(i - 10) / 7.0) + _rng.randf_range(-0.2, 0.2)
		_cilia_spec.append({
			"kind": kind,
			"angle": a,
			"polar": _rng.randf_range(1.02, 1.34),
			# Scaled to the ORGAN, not to the room: half to one and a half
			# globe-radii, thick enough to be more than a pixel. At three
			# radii they read as urchin spines, which is what the first two
			# passes produced.
			"length": GLOBE_R * _rng.randf_range(0.55, 1.45) * (1.15 if kind == 0 else 0.8),
			"thick": GLOBE_R * _rng.randf_range(0.055, 0.115) * (1.0 if kind != 2 else 1.3),
			"stiff": _rng.randf_range(5.0, 16.0),
			"curve": _rng.randf_range(-0.5, 0.5),
			"phase": _rng.randf_range(0.0, 1.0),
		})
		_cilia_dir[i] = Vector3.UP
		_cilia_vel[i] = Vector3.ZERO
		_cilia_alert[i] = 0.0


## A cilium: a tapered tube along +y with a slight natural curve, ending in
## a bulb for the crystal class. Its follicle is a small flare at y = 0.
static func _cilium_mesh() -> ArrayMesh:
	var rings := 10
	var segs := 5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for r in rings:
		var t := float(r) / float(rings - 1)
		# Flared follicle, long taper, small terminal bulb.
		var rad := lerpf(1.6, 0.22, smoothstep(0.0, 0.18, t))
		rad = lerpf(rad, 0.10, smoothstep(0.18, 0.88, t))
		rad = lerpf(rad, 0.42, smoothstep(0.90, 1.0, t) * (1.0 - smoothstep(0.99, 1.0, t)))
		var bend := Vector3(t * t * 0.35, 0.0, 0.0)
		for c in segs:
			var a := float(c) / float(segs - 1) * TAU
			verts.append(Vector3(cos(a) * rad, t, sin(a) * rad) + bend)
			normals.append(Vector3(cos(a), 0.15, sin(a)).normalized())
			uvs.append(Vector2(float(c) / float(segs - 1), t))
	for r in rings - 1:
		for c in segs - 1:
			var a := r * segs + c
			var b := a + 1
			var d := a + segs
			var e := d + 1
			indices.append(a); indices.append(d); indices.append(b)
			indices.append(b); indices.append(d); indices.append(e)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One transition organ: deep tissue → mineral root → gold socket → crystal.
func _build_crystal(s: float) -> void:
	crystal_material = ShaderMaterial.new()
	crystal_material.shader = CrystalShader
	crystal_material.set_shader_parameter("seed", s + 17.0)
	crystal = MeshInstance3D.new()
	crystal.name = "CrystalOrgan"
	crystal.mesh = _crystal_mesh()
	crystal.material_override = crystal_material
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crystal.visible = false
	root.add_child(crystal)


## An asymmetric faceted growth: a few large faces, a couple of secondary
## growths off one flank, its base buried.
static func _crystal_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# A prism with irregular section, tapering and leaning.
	var sides := 7
	var levels := 5
	for l in levels:
		var t := float(l) / float(levels - 1)
		var r := lerpf(1.0, 0.35, t) * lerpf(1.0, 0.8, t * t)
		var lean := Vector3(t * t * 0.30, 0.0, t * 0.12)
		for sdx in sides:
			var a := float(sdx) / float(sides) * TAU
			var jag := 0.72 + 0.4 * fmod(float(sdx * 7 + l * 3), 5.0) / 5.0
			verts.append(Vector3(cos(a) * r * jag, t * 2.0 - 0.5, sin(a) * r * jag) + lean)
	for l in levels - 1:
		for sdx in sides:
			var a := l * sides + sdx
			var b := l * sides + (sdx + 1) % sides
			var c := (l + 1) * sides + sdx
			var d := (l + 1) * sides + (sdx + 1) % sides
			indices.append(a); indices.append(c); indices.append(b)
			indices.append(b); indices.append(c); indices.append(d)
	# Cap it with a point, off-centre.
	var tip := verts.size()
	verts.append(Vector3(0.34, 1.72, 0.14))
	for sdx in sides:
		indices.append((levels - 1) * sides + sdx)
		indices.append(tip)
		indices.append((levels - 1) * sides + (sdx + 1) % sides)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Flat facets: recompute per-face normals by leaving them out and letting
	# Godot generate them from the surface tool.
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	return st.commit()


# ------------------------------------------------------------------ update


func glimpse_interior(seconds := 2.4) -> void:
	_interior_event = seconds
	last_events.append("impossible_space")


## A stimulus the cilia can feel before the eye knows: the player moving,
## a light, a contact. The controller feeds it.
func notice(at: Vector3, strength: float) -> void:
	_stimulus = at
	_stimulus_strength = maxf(_stimulus_strength, clampf(strength, 0.0, 1.0))


func set_mode(m: String) -> void:
	if m != mode:
		mode = m
		if m == "partial":
			last_events.append("eye_opening")


func update(rig: DreamTentacleRig, contact: Vector3, player_pos: Vector3, has_player: bool,
		interest: float, grow: float, pulse_phase: float, delta: float) -> void:
	last_events.clear()
	_clock += delta
	attention = interest
	# --- the socket's frame on the limb ---------------------------------
	var sp := rig.surface_point(EYE_U, EYE_V, -GLOBE_R * SINK)
	position = sp.pos
	normal = sp.normal
	var f := rig.frame_at(EYE_V)
	socket_up = (f.tangent as Vector3)
	socket_side = normal.cross(socket_up).normalized()
	var shown := grow > EYE_V + 0.06
	# --- what is worth looking at ----------------------------------------
	var look_to := contact
	match mode:
		"explore_room":
			_explore_clock -= delta
			if _explore_clock <= 0.0:
				_explore_clock = _rng.randf_range(1.8, 3.6)
				_explore_dir = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.6),
						_rng.randf_range(-1.0, 1.0)).normalized()
			look_to = position + _explore_dir * 3.0
		"lock_player":
			if has_player:
				look_to = player_pos
	if has_player and player_pos.distance_to(position) < 2.0 \
			and mode in ["watch_object", "watch_contact", "explore_room"]:
		look_to = look_to.lerp(player_pos, 0.6)
	elif viewer_pos.distance_to(position) < 3.0 \
			and mode in ["watch_object", "watch_contact", "explore_room"]:
		look_to = look_to.lerp(viewer_pos, 0.7)
	# Anything that just moved near the organ is a stimulus for the cilia.
	if has_player:
		notice(player_pos, clampf(1.6 / maxf(0.2, player_pos.distance_to(position)), 0.0, 1.0))
	_update_cilia(look_to, delta)
	_update_orbit(look_to, delta)
	_update_lids(delta)
	_update_globe(look_to, shown, delta, pulse_phase)
	_stimulus_strength = maxf(0.0, _stimulus_strength - delta * 0.6)
	_place(shown, pulse_phase, delta)


## The cilia feel it first (§D5, §J): those pointing toward a stimulus bend
## toward it, with spring secondary motion and their own phase.
func _update_cilia(look_to: Vector3, delta: float) -> void:
	var mm := cilia.multimesh
	var to_stim := (_stimulus - position)
	var stim_dir := to_stim.normalized() if to_stim.length() > 0.01 else normal
	for i in CILIA_N:
		var spec: Dictionary = _cilia_spec[i]
		var a := float(spec.angle)
		# The follicle's outward direction, in the socket's frame.
		var polar := float(spec.polar)
		var rest := (normal * cos(polar) + (socket_side * cos(a) + socket_up * sin(a)) * sin(polar)).normalized()
		# A cilium that already faces the stimulus feels it most.
		var facing := maxf(0.0, rest.dot(stim_dir))
		var want_alert := _stimulus_strength * pow(facing, 1.5)
		_cilia_alert[i] = lerpf(_cilia_alert[i], want_alert, clampf(delta * 3.0, 0.0, 1.0))
		# Fascination fans them out; a startle would snap them in — both are
		# carried by `attention` through the controller.
		var fan := lerpf(0.86, 1.12, attention)
		var target := (rest * fan + stim_dir * _cilia_alert[i] * 0.7).normalized()
		# Spring: stiffness varies per cilium, so they never move as a set.
		var stiff := float(spec.stiff)
		var acc := (target - _cilia_dir[i]) * stiff - _cilia_vel[i] * (2.0 * sqrt(stiff) * 0.55)
		_cilia_vel[i] += acc * clampf(delta, 0.0, 1.0 / 30.0)
		_cilia_dir[i] = (_cilia_dir[i] + _cilia_vel[i] * delta).normalized()
		# A slow idle drift, so they are never still.
		var idle := sin(_clock * (0.5 + float(spec.phase)) + float(spec.phase) * 6.0) * 0.02
		var dir := (_cilia_dir[i] + socket_side * idle + socket_up * idle * 0.6).normalized()
		# The follicles sit in the orbital folds, just outside the rim.
		var origin := position + rest * (GLOBE_R * 1.55)
		var length := float(spec.length) * (1.0 + 0.08 * _cilia_alert[i])
		var thick := float(spec.thick)
		var any := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
		var x := any.cross(dir).normalized()
		var z := dir.cross(x).normalized()
		# The natural curve is baked into the mesh; the basis carries the
		# scale and where it points.
		var basis := Basis(x * thick, dir * length, z * thick)
		mm.set_instance_transform(i, Transform3D(basis, origin))
		mm.set_instance_custom_data(i, Color(float(spec.kind), length, float(spec.phase),
				thick))


## The orbital gold tenses when the eye is about to move (§F, §I).
func _update_orbit(look_to: Vector3, delta: float) -> void:
	var want := (look_to - position).normalized()
	var swing := clampf(1.0 - want.dot(gaze), 0.0, 1.0)
	orbit_tension = lerpf(orbit_tension, clampf(swing * 3.0 + attention * 0.4, 0.0, 1.0),
			clampf(delta * 4.0, 0.0, 1.0))
	var mm := orbit.multimesh
	for i in ORBIT_PIECES.size():
		var row: Array = ORBIT_PIECES[i]
		var a := float(row[0])
		var polar := float(row[1])
		var width := float(row[2])
		var length := float(row[3])
		var thick := float(row[4])
		var pseed := float(row[5])
		# Tension pulls each piece in by a fraction of a millimetre, and the
		# brow leads.
		var pull := orbit_tension * (0.0016 if i == 0 else 0.0008)
		var out := (normal * cos(polar) + (socket_side * cos(a) + socket_up * sin(a)) * sin(polar)).normalized()
		# The skeleton RINGS the socket: it sits out at the rim, in the
		# orbital swelling, and never crosses the front of the globe. At
		# 1.34 radii it capped the eye like a gold acorn.
		var origin := position + out * (GLOBE_R * 2.05 - pull)
		var along := normal.cross(out).normalized()
		if along.length() < 0.1:
			along = socket_side
		var basis := Basis(along * (GLOBE_R * width * 1.5), out * (GLOBE_R * thick * 1.2),
				out.cross(along).normalized() * (GLOBE_R * length * 1.6))
		mm.set_instance_transform(i, Transform3D(basis, origin))
		mm.set_instance_custom_data(i, Color(orbit_tension, pseed * 0.1, 1.0, 0.0))


## Three lids, three timings (§C6, §I). A full blink overlaps them; a
## membrane-only blink runs the third alone; and they never start together.
func _update_lids(delta: float) -> void:
	var want_open := 0.0
	match mode:
		"closed", "closing":
			want_open = 0.0
		"partial":
			want_open = 0.45
		_:
			want_open = 1.0
	_blink_clock += delta
	if _blink_seq < 0.0 and want_open > 0.5 and _blink_clock > _next_blink:
		_blink_clock = 0.0
		_next_blink = _rng.randf_range(6.0, 15.0)
		_blink_seq = 0.0
		last_events.append("blink")
	var seq := _blink_seq
	if seq >= 0.0:
		_blink_seq += delta
		if _blink_seq > 1.5:
			_blink_seq = -1.0
	for i in LIDS.size():
		var row: Array = LIDS[i]
		var kind := int(row[0])
		var rest := float(row[4])
		# Base closure from the mode.
		var want := 1.0 - want_open
		want = maxf(want, rest)
		# The blink, offset per lid: the membrane leads, the dorsal lid
		# follows, the ventral lid arrives last and they overlap briefly.
		if seq >= 0.0:
			var starts: Array[float] = [0.16, 0.26, 0.0]
			var spans: Array[float] = [0.40, 0.42, 0.34]
			var start: float = starts[kind]
			var span: float = spans[kind]
			var t: float = (seq - start) / span
			if t > 0.0 and t < 2.0:
				want = maxf(want, sin(clampf(t, 0.0, 1.0) * PI))
		var rate := 9.0 if want > _closure[i] else 5.0
		_closure[i] = lerpf(_closure[i], clampf(want, 0.0, 1.0), clampf(delta * rate, 0.0, 1.0))
		lid_materials[i].set_shader_parameter("closure", _closure[i])
	openness = clampf(1.0 - maxf(_closure[0], _closure[1]), 0.0, 1.0)


func _update_globe(look_to: Vector3, shown: bool, delta: float, pulse_phase: float) -> void:
	var want_gaze := (look_to - position).normalized()
	# The socket bounds the gaze: 62° from its axis, and the heavy brow
	# takes a little more off the upward side.
	var limit := deg_to_rad(62.0)
	if want_gaze.dot(socket_up) > 0.0:
		limit = deg_to_rad(48.0)
	if want_gaze.dot(normal) < cos(limit):
		var axis := normal.cross(want_gaze)
		want_gaze = normal.rotated(axis.normalized(), limit) if axis.length() > 1e-4 else normal
	# The globe follows AFTER the cilia and the orbit have moved (§I).
	var lead := clampf(orbit_tension, 0.0, 1.0)
	gaze = gaze.slerp(want_gaze, clampf(delta * (1.1 + 2.2 * lead), 0.0, 1.0)).normalized()
	var want_pupil := lerpf(0.20, 0.46, clampf(attention, 0.0, 1.0))
	if _interior_event > 0.0:
		_interior_event -= delta
		want_pupil = 0.80
	# The pupil breathes a little with the vascular clock.
	want_pupil += 0.012 * sin(pulse_phase * TAU)
	pupil = lerpf(pupil, want_pupil, clampf(delta * 1.5, 0.0, 1.0))
	interior = lerpf(interior, 1.0 if _interior_event > 0.0 else 0.0, clampf(delta * 2.0, 0.0, 1.0))
	eye_material.set_shader_parameter("pupil", pupil)
	eye_material.set_shader_parameter("interior", interior)
	cornea_material.set_shader_parameter("pupil", pupil)


func _place(shown: bool, pulse_phase: float, delta: float) -> void:
	var z := gaze
	var any := Vector3.UP if absf(z.y) < 0.9 else Vector3.RIGHT
	var x := any.cross(z).normalized()
	var y := z.cross(x).normalized()
	globe.transform = Transform3D(Basis(x, y, z), position)
	globe.visible = shown
	# The cornea sits on the globe's front, along the gaze.
	cornea.transform = Transform3D(Basis(x, y, z), position + gaze * (GLOBE_R * 0.52))
	cornea.visible = shown
	# The lids: each on its own axis about the socket, and each swings from
	# its rim toward the centre as it closes.
	for i in LIDS.size():
		var row: Array = LIDS[i]
		var a := float(row[1])
		var lid_out := (socket_side * cos(a) + socket_up * sin(a)).normalized()
		var lid_z := normal
		var lid_x := lid_out
		var lid_y := lid_z.cross(lid_x).normalized()
		# The lid's own +y is the socket's axis; it sweeps about `lid_out`.
		var swing := _closure[i] * (0.75 if int(row[0]) < 2 else 0.92)
		var basis := Basis(lid_x, lid_z, lid_y).scaled(Vector3(GLOBE_R * 1.30, GLOBE_R * 1.30, GLOBE_R * 1.30))
		basis = Basis(lid_out, -swing * 1.55) * basis
		lids[i].transform = Transform3D(basis, position)
		lids[i].visible = shown and (_closure[i] > 0.02 or int(row[0]) < 2)
	orbit.visible = shown
	cilia.visible = shown
	cilia_material.set_shader_parameter("attention", attention)
	# The crystal: in the orbit's gold on the brow's flank, rooted inward.
	var ca := 0.95
	var cout := (normal * cos(1.22) + (socket_side * cos(ca) + socket_up * sin(ca)) * sin(1.22)).normalized()
	var cpos := position + cout * (GLOBE_R * 2.15)
	var cany := Vector3.UP if absf(cout.y) < 0.9 else Vector3.RIGHT
	var cx := cany.cross(cout).normalized()
	var cz := cout.cross(cx).normalized()
	var cs := GLOBE_R * 0.52
	crystal.transform = Transform3D(Basis(cx * cs, cout * cs, cz * cs), cpos)
	crystal.visible = shown
	crystal_material.set_shader_parameter("attention", attention)
	crystal_material.set_shader_parameter("pulse_phase", pulse_phase)
	crystal_material.set_shader_parameter("excitation", clampf(interior + orbit_tension * 0.5, 0.0, 1.0))


func set_debug_gray(on: bool) -> void:
	eye_material.set_shader_parameter("debug_gray", on)
	cornea_material.set_shader_parameter("debug_gray", on)
	cilia_material.set_shader_parameter("debug_gray", on)
	crystal_material.set_shader_parameter("debug_gray", on)
	orbit_material.set_shader_parameter("debug_gray", on)
	for m in lid_materials:
		m.set_shader_parameter("debug_gray", on)


func census() -> Dictionary:
	return {"openness": openness, "pupil": pupil, "tension": orbit_tension,
			"cilia": CILIA_N, "lids": lids.size(), "interior": interior,
			"closure": [_closure[0], _closure[1], _closure[2]]}
