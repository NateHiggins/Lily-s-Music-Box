extends Node
## Which way a tangent's sign points, in this engine. Cast models are held to this
## by art/tools/check_cast_tangents.py; this test is where that rule comes from.
##
## A quad faces the viewer with u running right and v running DOWN the picture.
## The engine's own tangent generator gives it tangent +x and sign +1: the
## binormal, cross(normal, tangent) * sign, runs UP the picture, toward falling
## v. A model file's sign is taken as written, with no conversion on the way in.
## (Measured once under a light, 2026-11-12: with a normal map leaning toward
## the top of the picture and the light above, sign +1 read 0.82, a flat quad
## 0.65 and sign -1 read 0.27. A headless run cannot repeat that part.)

var _fails := 0
var _checks := 0

const POINTS: Array[Vector3] = [Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)]
const UVS: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _quad_file(path: String, sign: float) -> void:
	var floats := PackedFloat32Array()
	for point: Vector3 in POINTS:
		floats.append_array([point.x, point.y, point.z])
	for index in 4:
		floats.append_array([0.0, 0.0, 1.0])
	for uv: Vector2 in UVS:
		floats.append_array([uv.x, uv.y])
	for index in 4:
		floats.append_array([1.0, 0.0, 0.0, sign])
	var bytes := floats.to_byte_array()
	var first_index := bytes.size()
	bytes.append_array(PackedByteArray([0, 0, 1, 0, 2, 0, 0, 0, 2, 0, 3, 0]))
	var document := {
		"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": "Quad"}],
		"meshes": [{"name": "Quad", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2, "TANGENT": 3}, "indices": 4}]}],
		"buffers": [{"byteLength": bytes.size(), "uri": "data:application/octet-stream;base64," + Marshalls.raw_to_base64(bytes)}],
		"bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 48}, {"buffer": 0, "byteOffset": 48, "byteLength": 48}, {"buffer": 0, "byteOffset": 96, "byteLength": 32},
			{"buffer": 0, "byteOffset": 128, "byteLength": 64}, {"buffer": 0, "byteOffset": first_index, "byteLength": 12}],
		"accessors": [{"bufferView": 0, "componentType": 5126, "count": 4, "type": "VEC3", "min": [-0.5, -0.5, 0.0], "max": [0.5, 0.5, 0.0]},
			{"bufferView": 1, "componentType": 5126, "count": 4, "type": "VEC3"}, {"bufferView": 2, "componentType": 5126, "count": 4, "type": "VEC2"},
			{"bufferView": 3, "componentType": 5126, "count": 4, "type": "VEC4"}, {"bufferView": 4, "componentType": 5123, "count": 6, "type": "SCALAR"}]}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(document))
	file.close()


func _read_back(path: String) -> PackedFloat32Array:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return PackedFloat32Array()
	var scene := document.generate_scene(state)
	var tangents := PackedFloat32Array()
	for draw: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		tangents = draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_TANGENT]
	scene.free()
	return tangents


func _ready() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in [0, 2, 1, 0, 3, 2]:
		tool.set_normal(Vector3(0, 0, 1))
		tool.set_uv(UVS[index])
		tool.add_vertex(POINTS[index])
	tool.generate_tangents()
	var made: PackedFloat32Array = tool.commit_to_arrays()[Mesh.ARRAY_TANGENT]
	var tangent := Vector3(made[0], made[1], made[2])
	var binormal := Vector3(0, 0, 1).cross(tangent) * made[3]
	_check(tangent.is_equal_approx(Vector3(1, 0, 0)), "the engine's tangent runs along rising u")
	_check(is_equal_approx(made[3], 1.0), "the engine's sign on this quad is +1")
	_check(binormal.is_equal_approx(Vector3(0, 1, 0)), "the engine's binormal runs up the picture, toward falling v")
	for sign: float in [1.0, -1.0]:
		var path := "user://tangent_convention_%s.gltf" % ("plus" if sign > 0.0 else "minus")
		_quad_file(path, sign)
		var kept := _read_back(path)
		_check(kept.size() == 16, "a model file with sign %+d loads with its tangents" % int(sign))
		if kept.size() == 16:
			_check(is_equal_approx(kept[3], sign), "a model file's sign %+d is taken as written" % int(sign))
			# The engine stores tangents packed, so the direction comes back to within its packing.
			_check(Vector3(kept[0], kept[1], kept[2]).distance_to(Vector3(1, 0, 0)) < 0.001, "and its tangent direction with it")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TANGENT CONVENTION TEST: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)
