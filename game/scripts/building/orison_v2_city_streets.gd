extends RefCounted
## Fixed native street stock; existing traffic, lamp and access owners remain.
const NEAR := preload("res://assets/props/city_streets.glb")
const FAR := preload("res://assets/props/city_streets_lod1.glb")
const FINISHES := "res://data/orison_v2/exterior/city_streets.json"
static var _grade_profile: Array = []

static func surface_height(x: float) -> float:
	if _grade_profile.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
		_grade_profile = data.grade_profile_m
	assert(_grade_profile.size() >= 2)
	var index := _grade_profile.size() - 2
	for i in _grade_profile.size() - 1:
		if x <= float(_grade_profile[i + 1][0]):
			index = i
			break
	var a: Array = _grade_profile[index]
	var b: Array = _grade_profile[index + 1]
	return lerpf(float(a[1]), float(b[1]), (x-float(a[0]))/(float(b[0])-float(a[0])))

static func road_basis(x: float, yaw: float) -> Basis:
	var slope := (surface_height(x + 0.01) - surface_height(x - 0.01)) / 0.02
	var up := Vector3(-slope, 1., 0.).normalized()
	var forward := Basis(Vector3.UP, yaw).x
	forward.y = slope * forward.x
	forward = forward.normalized()
	return Basis(forward, up, forward.cross(up).normalized())

static func mount(city: Node3D) -> Node3D:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
	assert(int(data.schema) == 1 and float(data.lod_error_m) > 0.)
	var model := NEAR.instantiate() as Node3D
	var low := FAR.instantiate() as Node3D
	model.name = "ContinuousStreetBlock"
	city.add_child(model)
	var far_parts: Dictionary = {}
	for draw: MeshInstance3D in low.find_children("*", "MeshInstance3D", true, false):
		far_parts[str(draw.name).replace("_L1__", "_L0__")] = draw
	var materials: Dictionary = {}
	for spec: Dictionary in data.finishes:
		var key := str(spec.catalog_key)
		assert(MatLib.SETS.has(key) and is_equal_approx(float(spec.pigment), 1.))
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var tint: Array = spec.tint
		material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		material.normal_scale = float(spec.normal)
		material.roughness *= float(spec.roughness)
		materials[str(spec.alias)] = SurfacePass.weather_surface(material, {})
	var seen: Array[String] = []
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		assert(identity in data.parts and far_parts.has(identity))
		var far_draw: MeshInstance3D = far_parts[identity]
		assert(draw.transform.is_equal_approx(far_draw.transform))
		assert(draw.mesh.get_surface_count() == 1 and far_draw.mesh.get_surface_count() == 1)
		var near_mesh := draw.mesh
		draw.mesh = preload("res://scripts/building/orison_v2_city_transport.gd")._with_lod(near_mesh, far_draw.mesh, float(data.lod_error_m))
		draw.material_override = materials[identity.split("__")[-1]]
		draw.set_meta("v2_city_streets", true)
		var body := StaticBody3D.new()
		body.name = "SourceCollision"
		var shape := CollisionShape3D.new()
		shape.name = "NearSurface"
		shape.shape = near_mesh.create_trimesh_shape()
		body.add_child(shape)
		draw.add_child(body)
		seen.append(identity)
	assert(seen.size() == data.parts.size() and seen.size() == far_parts.size())
	low.free()
	return model
