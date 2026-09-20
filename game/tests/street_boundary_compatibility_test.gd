extends Node
const Detail := preload("res://scripts/building/exterior_detail_pass.gd")
var failures: Array[String] = []
var checks := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
	print("BOUNDARY COMPATIBILITY: ", label, " = ", ok)

func _ready() -> void:
	var original := Detail.new()
	var candidate := Detail.new()
	add_child(original)
	add_child(candidate)
	original.build_boundaries_only(original)
	candidate.build_boundaries_only(candidate, true)
	_check(original.boundary_count == 6 and candidate.boundary_count == 5, "only east north span removed")
	var names := ["WestNorthWorks", "WestStormCore", "WestSouthWorks"]
	var centers := [Vector3(-20.1,1.2,12.1), Vector3(-20.1,1.2,19.322), Vector3(-20.1,1.2,26.105)]
	var sizes := [Vector3(.36,2.4,5.3),Vector3(.36,2.4,9.144),Vector3(.36,2.4,4.422)]
	for i in 3:
		var a: CollisionShape3D = original.get_node("StreetEndWeatherBoundary/"+names[i])
		var b: CollisionShape3D = candidate.get_node("StreetEndWeatherBoundary/"+names[i])
		_check(a.position.is_equal_approx(centers[i]) and b.position.is_equal_approx(centers[i])
				and a.shape.size.is_equal_approx(sizes[i]) and b.shape.size.is_equal_approx(sizes[i]),names[i])
	for entry in [["StreetEndHoardingFaces",4],["StreetEndWorkBeacons",2]]:
		var a: MultiMeshInstance3D = original.get_node(entry[0])
		var b: MultiMeshInstance3D = candidate.get_node(entry[0])
		for i in int(entry[1]):
			_check(a.multimesh.get_instance_transform(i) == b.multimesh.get_instance_transform(i),
					"west visual transform %s/%d" % [entry[0],i])
	for i in 3:
		var path := "StreetEndWeatherWest/StormCurtain_West_%02d" % i
		var a: MeshInstance3D = original.get_node(path)
		var b: MeshInstance3D = candidate.get_node(path)
		_check(a.transform == b.transform and a.mesh.size == b.mesh.size
				and a.material_override.shader.code == b.material_override.shader.code,
				"west storm curtain %d" % i)
	original.free()
	candidate.free()
	print("STREET BOUNDARY COMPATIBILITY: %d checks; %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
