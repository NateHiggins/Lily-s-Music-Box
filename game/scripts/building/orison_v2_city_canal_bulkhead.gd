extends RefCounted
## Passive timber bulkhead and compact retaining infill in the building frame.
## Native ground, canal water and the surrounding walking surface remain owned
## by the existing exterior. Each visible piece shares the fixed collision mesh.
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")
const NativeFaces := preload("res://scripts/building/orison_v2_native_faces.gd")
const START_X := 34.0
const END_X := 82.0
const FACE := -343.0
const RETURN := -339.3
const TOE := -7.02
const SHEET_TOP := -4.30


static func mount(parent: Node3D) -> Node3D:
	var timber := _finish("timber", Color(0.69, 0.59, 0.47), 0.48)
	var soil := _finish("soil", Color(0.48, 0.42, 0.33), 0.55)
	var weather_cache := {}
	var wood := SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The short depth alternates the sheet faces without leaving open seams.
	# Rotate charted longitudinal stock so its grain follows the standing boards.
	var upright := Basis(Vector3.BACK, PI * 0.5)
	var sheet_board := _charted_box(Vector3(SHEET_TOP - TOE, 0.5, 0.22))
	for board: int in 96:
		var recess := 0.014 * float(board % 2)
		var center := Vector3(START_X + 0.25 + float(board) * 0.5, (TOE + SHEET_TOP) * 0.5, FACE + 0.11 + recess)
		wood.append_from(sheet_board, 0, Transform3D(upright, center))
	var pile_stock := _charted_box(Vector3(2.65, 0.30, 0.27))
	for pile: int in 25:
		var x := lerpf(START_X + 0.19, END_X - 0.19, float(pile) / 24.0)
		wood.append_from(pile_stock, 0, Transform3D(upright, Vector3(x, -5.65, FACE - 0.065)))
	# The two walers stand proud of the sheeting. The narrower top coping
	# shades their joints without turning the upper bank into a boardwalk.
	var waler := _charted_box(Vector3(END_X - START_X, 0.18, 0.16))
	wood.append_from(waler, 0, Transform3D(Basis.IDENTITY, Vector3(58.0, -4.92, FACE - 0.065)))
	wood.append_from(waler, 0, Transform3D(Basis.IDENTITY, Vector3(58.0, -5.65, FACE - 0.065)))
	var coping := _charted_box(Vector3(END_X - START_X, 0.20, 0.49))
	wood.append_from(coping, 0, Transform3D(Basis.IDENTITY, Vector3(58.0, -4.30, FACE + 0.065)))

	# Local backfill descends into the existing landward grade. Timber
	# cheek plates return through the same slope at both ends.
	var cheeks := SurfaceTool.new()
	cheeks.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wedge(cheeks, START_X, START_X + 0.22, FACE + 0.20, -4.32, -4.75)
	_wedge(cheeks, END_X - 0.22, END_X, FACE + 0.20, -4.32, -4.75)
	cheeks.generate_tangents()
	# Both inputs must be indexed before merging so all cheeks draw.
	cheeks.index()
	var all_wood := SurfaceTool.new()
	all_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	all_wood.append_from(wood.commit(), 0, Transform3D.IDENTITY)
	all_wood.append_from(cheeks.commit(), 0, Transform3D.IDENTITY)
	all_wood.set_material(SurfacePass.weather_surface(timber, weather_cache))
	var mesh := all_wood.commit()
	var backing := SurfaceTool.new()
	backing.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wedge(backing, START_X + 0.20, END_X - 0.20, FACE + 0.20, -4.39, -5.72)
	backing.generate_tangents()
	backing.set_material(SurfacePass.weather_surface(soil, weather_cache))
	backing.commit(mesh)

	var draw := MeshInstance3D.new()
	draw.name = "CanalBulkhead"
	draw.mesh = mesh
	var body := StaticBody3D.new()
	body.name = "SourceCollision"
	var shape := CollisionShape3D.new()
	shape.name = "VisibleBulkhead"
	var physical := ConcavePolygonShape3D.new()
	physical.set_faces(NativeFaces.read(mesh))
	shape.shape = physical
	body.add_child(shape)
	draw.add_child(body)
	parent.add_child(draw)
	return draw


static func _finish(key: String, tint: Color, normal_scale: float) -> StandardMaterial3D:
	var stock := MatLib.get_mat(key).duplicate() as StandardMaterial3D
	stock.uv1_triplanar = false
	stock.albedo_color = tint
	stock.normal_scale = normal_scale
	stock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return stock


static func _charted_box(size: Vector3) -> ArrayMesh:
	var stock := BoxMesh.new()
	stock.size = size
	return MetreUV.chart(stock)


static func _wedge(batch: SurfaceTool, left: float, right: float, front: float,
		front_top: float, return_top: float) -> void:
	var wet_left := Vector3(left, front_top, front)
	var wet_right := Vector3(right, front_top, front)
	var dry_left := Vector3(left, return_top, RETURN)
	var dry_right := Vector3(right, return_top, RETURN)
	var wet_left_toe := Vector3(left, TOE, front)
	var wet_right_toe := Vector3(right, TOE, front)
	var dry_left_toe := Vector3(left, TOE, RETURN)
	var dry_right_toe := Vector3(right, TOE, RETURN)
	_face(batch, wet_left, dry_left, dry_right, wet_right, Vector3.UP)
	_face(batch, wet_left_toe, wet_right_toe, dry_right_toe, dry_left_toe, Vector3.DOWN)
	_face(batch, wet_left, wet_right, wet_right_toe, wet_left_toe, Vector3.FORWARD)
	_face(batch, dry_left, dry_left_toe, dry_right_toe, dry_right, Vector3.BACK)
	_face(batch, wet_left, wet_left_toe, dry_left_toe, dry_left, Vector3.LEFT)
	_face(batch, wet_right, dry_right, dry_right_toe, wet_right_toe, Vector3.RIGHT)


static func _face(batch: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		outward: Vector3) -> void:
	# Match Godot's clockwise winding and use a physical metre chart.
	var normal := (c - a).cross(b - a).normalized()
	var forward := normal.dot(outward) > 0.0
	if not forward:
		normal = -normal
	var grain := Vector3.BACK if absf(normal.z) < 0.95 else Vector3.RIGHT
	var u := grain.slide(normal).normalized()
	var v := normal.cross(u)
	var points := [a, b, c, a, c, d] if forward else [a, c, b, a, d, c]
	for point: Vector3 in points:
		batch.set_normal(normal)
		batch.set_uv(Vector2(point.dot(u), point.dot(v)))
		batch.add_vertex(point)
