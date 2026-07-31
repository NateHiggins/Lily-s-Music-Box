class_name OrisonRailingPolish
extends Node3D
## Decorative overlay for the exported stair balustrade: turned-newel
## silhouettes, brass collars and a fine brass inlay following each rake.

var detail_count := 0
var _wood: StandardMaterial3D
var _brass: StandardMaterial3D


func build(layout: Dictionary) -> int:
	name = "RailingPolish"
	_wood = MatLib.get_mat("wood_dark", Color(0.62, 0.46, 0.32), 0.55)
	_brass = MatLib.get_mat("brass", Color(0.72, 0.60, 0.38), 0.45)
	for stair in layout.get("stairs", []):
		for part in stair.get("parts", []):
			if part.kind == "flight":
				_decorate_flight(part)
			elif part.kind == "landing" and part.has("guard_span"):
				_decorate_landing(part)
	return detail_count


func _decorate_flight(part: Dictionary) -> void:
	var n := int(part.n)
	var start := float(part.start)
	var direction := float(part.dir)
	var tread := float(part.tread)
	var z0 := float(part.z0)
	var xr := float(part.b1) - 0.045 if part.rail_side == "hi" \
			else float(part.b0) + 0.045
	var finish := start + direction * (n - 1) * tread
	var top_a := Vector3(xr, start, z0 + 0.955)
	var top_b := Vector3(xr, finish, z0 + n * float(part.rise) + 0.955)
	_add_rod(top_a, top_b, 0.010, _brass)
	_add_newel(Vector3(xr, start + direction * 0.02, z0))
	_add_newel(Vector3(xr, finish, z0 + (n - 1) * float(part.rise)))
	# Alternating collars catch warm stair light without turning the whole
	# rail into polished brass.
	for i in range(1, n, 2):
		var y := start + direction * (i - 0.5) * tread
		var z := z0 + i * float(part.rise) + 0.46
		_add_collar(Vector3(xr, y, z))


func _decorate_landing(part: Dictionary) -> void:
	var rect: Array = part.rect
	var y := float(rect[1]) + 0.055 if part.guard_edge == "s" \
			else float(rect[3]) - 0.055
	var span: Array = part.guard_span
	for x in [float(span[0]) - 0.075, float(span[1]) + 0.075]:
		_add_newel(Vector3(x, y, float(part.z)))


func _add_newel(at: Vector3) -> void:
	# Layered base, tapered body, brass neck and turned finial.
	_add_box(Vector3(0.16, 0.13, 0.16),
			at + Vector3(0, 0, 0.08), _wood)
	_add_cylinder(0.052, 0.052, 0.76,
			at + Vector3(0, 0, 0.49), _wood)
	_add_cylinder(0.072, 0.060, 0.075,
			at + Vector3(0, 0, 0.885), _brass)
	_add_sphere(0.095, at + Vector3(0, 0, 1.005), _wood)
	_add_sphere(0.024, at + Vector3(0, 0, 1.105), _brass)


func _add_collar(at: Vector3) -> void:
	_add_cylinder(0.034, 0.034, 0.022, at, _brass)


func _add_box(size_b: Vector3, at_b: Vector3,
		material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = GameBoot.b2g([size_b.x, size_b.y, size_b.z]).abs()
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = GameBoot.b2g([at_b.x, at_b.y, at_b.z])
	item.material_override = material
	add_child(item)
	detail_count += 1


func _add_cylinder(top: float, bottom: float, height: float,
		at_b: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = GameBoot.b2g([at_b.x, at_b.y, at_b.z])
	item.material_override = material
	add_child(item)
	detail_count += 1


func _add_sphere(radius: float, at_b: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = GameBoot.b2g([at_b.x, at_b.y, at_b.z])
	item.material_override = material
	add_child(item)
	detail_count += 1


func _add_rod(a_b: Vector3, b_b: Vector3, radius: float,
		material: Material) -> void:
	var a := GameBoot.b2g([a_b.x, a_b.y, a_b.z])
	var b := GameBoot.b2g([b_b.x, b_b.y, b_b.z])
	var direction := b - a
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 10
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = (a + b) * 0.5
	item.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	item.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	item.material_override = material
	add_child(item)
	detail_count += 1
