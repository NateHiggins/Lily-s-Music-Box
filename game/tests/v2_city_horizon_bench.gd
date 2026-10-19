extends Node
const Horizon := preload("res://scripts/building/orison_v2_city_horizon.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("CITY HORIZON BENCH: " + label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_horizon.json"))
	var horizon := Horizon.new()
	add_child(horizon)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bounds: Dictionary = {}
	var mapped: Dictionary = {}
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for model: Node3D in horizon.get_children():
		for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var identity := str(draw.get_meta("v2_city_horizon_building"))
			var box := draw.global_transform * draw.mesh.get_aabb()
			bounds[identity] = (bounds[identity] as AABB).merge(box) if bounds.has(identity) else box
			var key := str(model.name) + "/" + str(draw.name).split("__")[-1]
			if not mapped.has(key):
				mapped[key] = true
				metrics._check_cap_mapping(draw.mesh, true)
	check(metrics.failures.is_empty(), "loaded metric charts and tangents across both asset/material families")
	metrics.free()
	check(bounds.size() == fixture.buildings.size(), "all authored building identities loaded once")
	for row: Dictionary in fixture.buildings:
		var r: Array = row.rect
		var expected := AABB(Vector3(r[0],-.28,r[1]),Vector3(float(r[2])-float(r[0]),float(row.height_m)+.93,float(r[3])-float(r[1])))
		var actual: AABB = bounds.get(str(row.id), AABB())
		check(actual.position.distance_to(expected.position)<.0001 and actual.end.distance_to(expected.end)<.0001, "actual imported building/grade frame: "+str(row.id))
	for window: Dictionary in fixture.window_rows:
		var p: Array = window.point
		var n: Array = window.normal
		var point := Vector3(p[0],p[2],-p[1])
		var normal := Vector3(n[0],n[2],-n[1])
		var expected := point - normal * float(window.recess_m)
		var hit := horizon.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.03,point-normal*.25,1))
		var valid: bool = not hit.is_empty() and horizon.is_ancestor_of(hit.collider) and hit.position.distance_to(expected)<.0001
		if valid:
			var draw := hit.collider.get_parent() as MeshInstance3D
			valid = draw != null and str(draw.get_meta("v2_city_horizon_building"))==str(window.building) and str(draw.name).ends_with("__mirror_aged")
		check(valid, "actual fitted opaque pane: "+str(window.building)+" "+str(point))
	var retired: WeakRef = weakref(horizon)
	horizon.free()
	await get_tree().physics_frame
	check(retired.get_ref()==null, "production horizon node retires")
	print("CITY HORIZON BENCH: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(failures.size())
