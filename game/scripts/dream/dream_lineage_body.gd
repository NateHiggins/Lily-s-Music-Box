class_name DreamLineageBody
extends MeshInstance3D
## ONE ROOM'S VISIBLE DESCENT.
##
## The fractal atlas has always been an ancestry: a room is the ordered set of
## doors that produced it. This is that fact made bodily. A brood knot hangs
## above the room, an umbilical reaches back through the parent aperture, and
## paired helices run to every possible child. Open doors carry a thin nested
## birth-frame; sealed possibilities terminate in a closed bud.
##
## Everything is one ArrayMesh surface and has no collision. The maze is
## submission-bound and its navigation contract is already proven, so the
## organism costs one draw per live room and cannot turn ornament into a trap.

const TUBE_SIDES := 5
const BRANCH_STEPS := 8
const KNOT_STEPS := 14
const FRAME_INSET := 0.055

var pulse_phase := 0.0
var pulse_hz := 0.08
var pulse_amount := 0.015
var _age_s := 0.0


func _process(delta: float) -> void:
	_age_s += delta
	var wave := sin((_age_s * pulse_hz) * TAU + pulse_phase)
	# Surface motion only, and ONLY VERTICAL. Scaling or rotating XZ moved a
	# long room's filament ends centimetres off the apertures they are meant to
	# explain. A shallow hanging stretch keeps every doorway contact registered
	# while the knot rises and falls by about 16 mm. There is no collision to
	# disagree with it and no topology changes in view.
	var stretch := 1.0 + wave * pulse_amount * 0.45
	scale = Vector3(1.0, stretch, 1.0)
	rotation.y = 0.0


## Construct the complete room-organ as one surface. `branches` is prepared by
## DreamRoomBuilder because only the pocket knows whether door zero still
## reaches its remembered parent or has become a new child after forgetting.
func configure(room: Dictionary, branches: Array, clear_ceiling: float) -> void:
	name = "LineageBody"
	var lineage: Dictionary = room.get("lineage", {})
	pulse_phase = float(lineage.get("phase", 0.0))
	pulse_hz = float(lineage.get("pulse_hz", 0.08))
	var rect: Array = room.rect
	var world_center := Vector3(
			(float(rect[0]) + float(rect[2])) * 0.5, 0.0,
			(float(rect[1]) + float(rect[3])) * 0.5)
	position = world_center

	# Below the ceiling plane, not painted onto it. The first render placed the
	# knot high enough that the lamp found the plaster behind it and reduced
	# the organism to a black fork. This hangs in the room as a volume.
	var knot := Vector3(0.0, clear_ceiling - 0.68, 0.0)
	var knot_radius := clampf(float(lineage.get("girth", 0.04)) * 6.4,
			0.20, 0.38)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_knot(tool, knot, knot_radius, lineage)

	var sealed := 0
	var parents := 0
	var branch_genomes: Array[int] = []
	var branch_roles: Array[String] = []
	for record in branches:
		var door: Dictionary = record.door
		var branch_gene: Dictionary = record.lineage
		var aperture: Array = door.aperture
		var end := Vector3(
				(float(aperture[0]) + float(aperture[2])) * 0.5
						- world_center.x,
				minf(clear_ceiling - 0.61, float(door.height) + 0.10),
				(float(aperture[1]) + float(aperture[3])) * 0.5
						- world_center.z)
		var is_parent := bool(record.get("is_parent", false))
		branch_genomes.append(int(branch_gene.get("genome_id", 0)))
		branch_roles.append("parent" if is_parent else
				("sealed" if bool(door.sealed) else "child"))
		if is_parent:
			parents += 1
		var strands := 3 if is_parent else 2
		if int(branch_gene.get("mutation", 0)) \
				== DreamAtlas.LineageMutation.DUPLICATE:
			strands += 1
		_append_branch(tool, knot, end, branch_gene, strands,
				1.22 if is_parent else 1.0)
		if bool(door.sealed):
			sealed += 1
			_append_bud(tool, end, knot, branch_gene)
		else:
			_append_birth_frame(tool, door, world_center, branch_gene)

	mesh = tool.commit()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	extra_cull_margin = 0.15
	set_meta("generation", int(lineage.get("generation", 0)))
	set_meta("room_key", str(room.get("key", "")))
	set_meta("genome_id", int(lineage.get("genome_id", 0)))
	set_meta("parent_room_id", int(lineage.get("parent_room_id", 0)))
	set_meta("birth_door", int(lineage.get("birth_door", -1)))
	set_meta("branch_count", branches.size())
	set_meta("sealed_buds", sealed)
	set_meta("parent_branches", parents)
	set_meta("branch_genomes", branch_genomes)
	set_meta("branch_roles", branch_roles)
	set_meta("pulse_hz", pulse_hz)
	set_meta("collision_free", true)
	if mesh != null and mesh.get_surface_count() > 0:
		set_meta("vertices", mesh.surface_get_array_len(0))
		set_meta("surfaces", mesh.get_surface_count())


func _append_branch(tool: SurfaceTool, start: Vector3, finish: Vector3,
		gene: Dictionary, strands: int, radius_gain: float) -> void:
	var axis := finish - start
	var flat := Vector3(axis.x, 0.0, axis.z)
	var side := Vector3.RIGHT
	if flat.length() > 0.001:
		side = Vector3(-flat.z, 0.0, flat.x).normalized()
	var curl := float(gene.get("curl", 0.5))
	var handedness := float(int(gene.get("handedness", 1)))
	var phase := float(gene.get("phase", 0.0))
	var girth := float(gene.get("girth", 0.04)) * radius_gain * 1.28
	var amplitude := minf(0.22, axis.length() * 0.064) \
			* lerpf(0.72, 1.18, curl)
	for strand in strands:
		var points: Array[Vector3] = []
		var strand_phase := phase + TAU * float(strand) / float(strands)
		for step in BRANCH_STEPS + 1:
			var t := float(step) / float(BRANCH_STEPS)
			var envelope := sin(t * PI)
			var turn := strand_phase + handedness * t * TAU \
					* lerpf(0.72, 1.55, curl)
			var point := start.lerp(finish, t)
			point += side * cos(turn) * amplitude * envelope
			point.y += sin(turn) * amplitude * envelope
			points.append(point)
		_append_tube(tool, points, girth * (1.0 - float(strand) * 0.09))


func _append_knot(tool: SurfaceTool, center: Vector3, radius: float,
		gene: Dictionary) -> void:
	var phase := float(gene.get("phase", 0.0))
	var handedness := float(int(gene.get("handedness", 1)))
	for ring in 5:
		var points: Array[Vector3] = []
		for step in KNOT_STEPS + 1:
			var t := float(step) / float(KNOT_STEPS)
			var a := t * TAU
			var p := Vector3.ZERO
			match ring % 3:
				0:
					p = Vector3(cos(a), sin(a), sin(a * 2.0 + phase) * 0.24)
				1:
					p = Vector3(sin(a * 2.0 - phase) * 0.24,
							cos(a), sin(a))
				_:
					p = Vector3(sin(a), sin(a * 2.0 + phase) * 0.24,
							cos(a))
			p.z *= handedness
			var ring_scale := 0.76 + float(ring) * 0.085
			points.append(center + p * radius * ring_scale)
		_append_tube(tool, points, maxf(0.022, radius * 0.145))


func _append_birth_frame(tool: SurfaceTool, door: Dictionary,
		world_center: Vector3, gene: Dictionary) -> void:
	var aperture: Array = door.aperture
	var x0 := float(aperture[0]) - world_center.x
	var x1 := float(aperture[2]) - world_center.x
	var z0 := float(aperture[1]) - world_center.z
	var z1 := float(aperture[3]) - world_center.z
	var radius := maxf(0.018, float(gene.get("girth", 0.04)) * 0.52)
	var axis_z := str(door.axis) == "z"
	for layer in 2:
		var inset := FRAME_INSET * float(layer)
		var y0 := 0.12 + inset
		var y1 := float(door.height) - inset
		var points: Array[Vector3] = []
		if axis_z:
			var x := (x0 + x1) * 0.5
			var za := z0 + inset
			var zb := z1 - inset
			points = [Vector3(x, y0, za), Vector3(x, y1, za),
					Vector3(x, y1, zb), Vector3(x, y0, zb)]
		else:
			var z := (z0 + z1) * 0.5
			var xa := x0 + inset
			var xb := x1 - inset
			points = [Vector3(xa, y0, z), Vector3(xa, y1, z),
					Vector3(xb, y1, z), Vector3(xb, y0, z)]
		for edge in 3:
			_append_tube(tool, [points[edge], points[edge + 1]], radius)


func _append_bud(tool: SurfaceTool, end: Vector3, toward: Vector3,
		gene: Dictionary) -> void:
	var forward := (toward - end).normalized()
	if forward.length() < 0.001:
		forward = Vector3.FORWARD
	var side := forward.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var radius := clampf(float(gene.get("girth", 0.04)) * 2.6, 0.08, 0.16)
	var rings := 5
	var sides := 7
	for ring in rings:
		var t0 := float(ring) / float(rings)
		var t1 := float(ring + 1) / float(rings)
		var r0 := sin(t0 * PI) * radius
		var r1 := sin(t1 * PI) * radius
		var c0 := end + forward * ((t0 - 0.5) * radius * 2.8)
		var c1 := end + forward * ((t1 - 0.5) * radius * 2.8)
		for side_index in sides:
			var a0 := TAU * float(side_index) / float(sides)
			var a1 := TAU * float(side_index + 1) / float(sides)
			var n0 := side * cos(a0) + up * sin(a0)
			var n1 := side * cos(a1) + up * sin(a1)
			_quad(tool, c0 + n0 * r0, c1 + n0 * r1,
					c1 + n1 * r1, c0 + n1 * r0,
					(n0 + n1).normalized())


func _append_tube(tool: SurfaceTool, points: Array[Vector3],
		radius: float) -> void:
	if points.size() < 2:
		return
	for ring in points.size() - 1:
		var a := points[ring]
		var b := points[ring + 1]
		var tangent := (b - a).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length() < 0.001:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		for side_index in TUBE_SIDES:
			var angle0 := TAU * float(side_index) / float(TUBE_SIDES)
			var angle1 := TAU * float(side_index + 1) / float(TUBE_SIDES)
			var n0 := side * cos(angle0) + up * sin(angle0)
			var n1 := side * cos(angle1) + up * sin(angle1)
			_quad(tool, a + n0 * radius, b + n0 * radius,
					b + n1 * radius, a + n1 * radius,
					(n0 + n1).normalized())


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		d: Vector3, normal: Vector3) -> void:
	for point in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		# The shared body shader uses vertex colour as anatomy metadata.
		# Lineage joins stay structurally still; the separate hazard-growth
		# surface authors flex and eye channels explicitly.
		tool.set_color(Color(0.0, 0.0, 0.0, 1.0))
		tool.add_vertex(point)
