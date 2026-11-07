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
	var sleeper_top := crown_y + 0.08
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
		_append_box(rails, Vector3(0.066, 0.03, length), Vector3(rail_x, sleeper_top + 0.135, mid_z))

	# Fixed stops mark the staggered rail ends as deliberately closed scenic stock.
	for z: float in [z_start + 1.35, z_end - 1.35]:
		for side: float in [-1.0, 1.0]:
			var support_x := x + side * TRACK_GAUGE_M * 0.5
			_append_box(rails, Vector3(0.18, 0.56, 0.48),
				Vector3(support_x, crown_y + 0.25, z))
		_append_box(timber, Vector3(2.18, 0.25, 0.28),
			Vector3(x, crown_y + 0.655, z))


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
