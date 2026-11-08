extends RefCounted
## Passive rail-yard stock in the existing building-local cut, beyond travel.
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

const GRADE_Y_M := -3.5
const SHOULDER_BASE_M := 3.9
const SHOULDER_CROWN_M := 3.0
const SHOULDER_DEPTH_M := 0.25
const TRACK_GAUGE_M := 1.435
const SLEEPER_PITCH_M := 0.66
const SLEEPER_DEPTH_M := 0.12
const SLEEPER_RAIL_SEAT_M := 0.08
const RAIL_HEIGHT_M := 0.15
const SWITCHER_ANCHOR_Z_M := -27.0
# Centre X and the two Z ends. Stagger the termini while keeping every
# footprint on the dry plateau and beyond the original travel boundary.
const SIDINGS: Array[Vector3] = [
	Vector3(-462.0, -85.0, 40.0),
	Vector3(-469.0, -79.0, 34.0),
	Vector3(-476.0, -71.0, 30.0),
]


static func mount(parent: Node3D) -> void:
	var shoulders := SurfaceTool.new()
	var timber := SurfaceTool.new()
	var rails := SurfaceTool.new()
	shoulders.begin(Mesh.PRIMITIVE_TRIANGLES)
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	for siding in SIDINGS:
		_append_siding(siding, shoulders, timber, rails)
	var engine := SurfaceTool.new()
	engine.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_steam_switcher(engine, rails)

	# Existing catalogue soil represents the weathered aggregate and fines.
	# The raised shoulder carries the bed profile without a new texture set.
	var shoulder_material := _mapped_material("soil", Color(0.81, 0.78, 0.71))
	var sleeper_material := _mapped_material("timber", Color(0.57, 0.51, 0.42))
	var rail_material := _mapped_material("iron_neutral", Color(0.67, 0.65, 0.60))
	rail_material.metallic = 1.0
	rail_material.roughness *= 0.85

	var mesh := ArrayMesh.new()
	shoulders.generate_tangents()
	shoulders.set_material(shoulder_material)
	shoulders.commit(mesh)
	timber.set_material(sleeper_material)
	timber.commit(mesh)
	rails.set_material(rail_material)
	rails.commit(mesh)
	var painted_iron := _mapped_material("iron_neutral", Color(0.90, 0.96, 0.94))
	painted_iron.metallic = 0.0
	engine.set_material(painted_iron)
	engine.commit(mesh)

	var yard := MeshInstance3D.new()
	yard.name = "IndustrialCutSidings"
	yard.mesh = mesh
	yard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(yard)


static func _append_siding(siding: Vector3, shoulders: SurfaceTool,
		timber: SurfaceTool, rails: SurfaceTool) -> void:
	var x := siding.x
	var z_start := siding.y
	var z_end := siding.z
	var length := z_end - z_start
	var mid_z := (z_start + z_end) * 0.5
	var crown_y := GRADE_Y_M + SHOULDER_DEPTH_M
	var sleeper_top := crown_y + SLEEPER_RAIL_SEAT_M
	_append_shoulder(shoulders, x, z_start, z_end, crown_y)

	var sleeper_count := int(ceil(length / SLEEPER_PITCH_M))
	var pitch := length / float(sleeper_count)
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(2.60, SLEEPER_DEPTH_M, 0.24)
	var sleeper_mesh := MetreUV.chart(sleeper)
	for index in sleeper_count:
		var z := z_start + (float(index) + 0.5) * pitch
		var center := Vector3(x, sleeper_top - SLEEPER_DEPTH_M * 0.5, z)
		timber.append_from(sleeper_mesh, 0, Transform3D(Basis.IDENTITY, center))

	# The foot, web and head retain the installed station's rail height and gauge.
	for side: float in [-1.0, 1.0]:
		var rail_x := x + side * TRACK_GAUGE_M * 0.5
		_append_box(rails, Vector3(0.14, 0.035, length), Vector3(rail_x, sleeper_top + 0.0175, mid_z))
		_append_box(rails, Vector3(0.018, 0.087, length), Vector3(rail_x, sleeper_top + 0.0775, mid_z))
		_append_box(rails, Vector3(0.066, 0.03, length), Vector3(rail_x, sleeper_top + RAIL_HEIGHT_M - 0.015, mid_z))

	# Fixed stops mark the staggered rail ends as deliberately closed scenic stock.
	for z: float in [z_start + 1.35, z_end - 1.35]:
		for side: float in [-1.0, 1.0]:
			var support_x := x + side * TRACK_GAUGE_M * 0.5
			_append_box(rails, Vector3(0.18, 0.56, 0.48),
				Vector3(support_x, crown_y + 0.25, z))
		_append_box(timber, Vector3(2.18, 0.25, 0.28),
			Vector3(x, crown_y + 0.655, z))



static func _append_steam_switcher(paint: SurfaceTool, steel: SurfaceTool) -> void:
	# A parked, generic six-coupled yard switcher with a short tender. Its tyres
	# share the nearest siding's installed rail-head height, gauge and axis.
	var rail_head_y := GRADE_Y_M + SHOULDER_DEPTH_M + SLEEPER_RAIL_SEAT_M + RAIL_HEIGHT_M
	var anchor := Vector3(SIDINGS[0].x, rail_head_y, SWITCHER_ANCHOR_Z_M)
	var longitudinal := Basis(Vector3.RIGHT, PI * 0.5)
	var transverse := Basis(Vector3.FORWARD, PI * 0.5)

	for stock: Array in [
		[Vector3(2.90, 0.24, 9.40), Vector3(0.0, 1.31, 1.05)], # Running plate.
		[Vector3(1.72, 0.31, 1.10), Vector3(0.0, 1.55, 4.05)], # Boiler saddle.
		[Vector3(2.90, 0.38, 0.30), Vector3(0.0, 1.16, 5.68)], # Front beam.
		[Vector3(2.66, 0.77, 0.22), Vector3(0.0, 1.80, -3.28)], # Cab back.
		[Vector3(2.66, 0.76, 0.23), Vector3(0.0, 1.81, -0.55)], # Firebox wall.
		[Vector3(3.12, 0.14, 3.12), Vector3(0.0, 3.66, -1.92)], # Cab eaves.
		[Vector3(2.46, 0.13, 3.00), Vector3(0.0, 3.77, -1.92)], # Raised roof crown.
		[Vector3(2.80, 0.23, 4.70), Vector3(0.0, 1.00, -6.36)], # Tender frame.
		[Vector3(2.65, 1.33, 3.88), Vector3(0.0, 1.75, -6.32)], # Tender tank.
		[Vector3(2.74, 0.17, 3.95), Vector3(0.0, 2.47, -6.32)], # Tender top.
	]:
		var size: Vector3 = stock[0]
		var center: Vector3 = stock[1]
		_append_box(paint, size, anchor + center)

	for side: float in [-1.0, 1.0]:
		var x := side * 1.35
		# Four solid pieces frame a real side-window opening.
		_append_box(paint, Vector3(0.16, 0.84, 2.80), anchor + Vector3(x, 1.84, -1.92))
		_append_box(paint, Vector3(0.16, 0.21, 2.80), anchor + Vector3(x, 3.51, -1.92))
		for z: float in [-3.10, -0.73]:
			_append_box(paint, Vector3(0.16, 1.18, 0.36), anchor + Vector3(x, 2.83, z))

		var wheel_x := side * TRACK_GAUGE_M * 0.5
		for z: float in [-0.65, 1.05, 2.75]:
			_append_round(steel, 0.63, 0.24, anchor + Vector3(wheel_x, 0.63, z), transverse)
		for z: float in [-7.61, -5.10]:
			_append_round(steel, 0.44, 0.19, anchor + Vector3(wheel_x, 0.44, z), transverse)
			_append_box(steel, Vector3(0.31, 0.24, 0.28), anchor + Vector3(wheel_x, 0.86, z))
		_append_box(steel, Vector3(0.09, 0.16, 3.74),
			anchor + Vector3(side * (TRACK_GAUGE_M * 0.5 + 0.15), 0.70, 1.05))
		_append_round(steel, 0.28, 0.77, anchor + Vector3(side * 1.10, 0.99, 3.81), longitudinal)

	_append_box(steel, Vector3(0.28, 0.16, 0.51), anchor + Vector3(0.0, 1.12, -3.83))
	_append_round(paint, 0.86, 5.50, anchor + Vector3(0.0, 2.42, 1.95), longitudinal)
	_append_round(steel, 0.82, 0.72, anchor + Vector3(0.0, 2.42, 4.87), longitudinal)
	_append_round(paint, 0.30, 0.36, anchor + Vector3(0.0, 3.42, 1.57), Basis.IDENTITY)
	_append_round(paint, 0.19, 0.84, anchor + Vector3(0.0, 3.64, 4.43), Basis.IDENTITY)
	_append_round(paint, 0.30, 0.14, anchor + Vector3(0.0, 4.08, 4.43), Basis.IDENTITY)


static func _append_round(surface: SurfaceTool, radius: float, length: float,
		center: Vector3, axis: Basis) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 16
	cylinder.rings = 0
	var arrays := cylinder.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	# Godot's cylinder sides occupy the upper half of UV and the cap circles
	# have radius .25 in the lower half. Preserve their seam and metre scale.
	for index in uv.size():
		if absf(normals[index].y) < 0.5:
			uv[index] *= Vector2(TAU * radius, 2.0 * length)
		else:
			uv[index] *= 4.0 * radius
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mapped := ArrayMesh.new()
	mapped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.append_from(mapped, 0, Transform3D(axis, center))


static func _append_shoulder(surface: SurfaceTool, x: float, z_start: float,
		z_end: float, crown_y: float) -> void:
	var bottom_y := GRADE_Y_M - 0.02
	var base := SHOULDER_BASE_M * 0.5
	var crown := SHOULDER_CROWN_M * 0.5
	var a := Vector3(x - base, bottom_y, z_start)
	var b := Vector3(x + base, bottom_y, z_start)
	var c := Vector3(x + crown, crown_y, z_start)
	var d := Vector3(x - crown, crown_y, z_start)
	var reach := Vector3(0.0, 0.0, z_end - z_start)
	_append_quad(surface, a, b, c, d)
	_append_quad(surface, d + reach, c + reach, b + reach, a + reach)
	_append_quad(surface, d, c, c + reach, d + reach)
	_append_quad(surface, b, b + reach, c + reach, c)
	_append_quad(surface, a, d, d + reach, a + reach)
	_append_quad(surface, a, a + reach, b + reach, b)


static func _append_quad(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3) -> void:
	var tangent := (b - a).normalized()
	var normal := (d - a).cross(tangent).normalized()
	var bitangent := normal.cross(tangent)
	for point: Vector3 in [a, b, c, a, c, d]:
		var local := point - a
		surface.set_normal(normal)
		surface.set_uv(Vector2(local.dot(tangent), local.dot(bitangent)))
		surface.add_vertex(point)


static func _append_box(surface: SurfaceTool, size: Vector3, center: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	surface.append_from(MetreUV.chart(box), 0, Transform3D(Basis.IDENTITY, center))


static func _mapped_material(key: String, tint: Color) -> StandardMaterial3D:
	var material := MatLib.get_mat(key, tint).duplicate() as StandardMaterial3D
	material.uv1_triplanar = false
	material.uv2_triplanar = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
