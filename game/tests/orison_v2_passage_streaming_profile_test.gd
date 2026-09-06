extends "res://tests/orison_v2_vertical_route_test.gd"

func _init() -> void:
	route_label = "PASSAGE STREAMING PROFILE"

func _route() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	for cycle in 2:
		for point in [Vector3(2.3, 0, -6.5), Vector3(0, 0, -8.5), Vector3(0, 0, -10.2)]:
			if not await _walk(point): return
		var started := Time.get_ticks_msec()
		while world.passage_region.residency.state == "LOADING" and Time.get_ticks_msec()-started < 10000:
			await get_tree().process_frame
		if world.passage_region.residency.state != "RESIDENT":
			failures.append("resident after prefetch")
			return
		for point in [Vector3(0, 0, -8.5), Vector3(2.3, 0, -6.5), Vector3(2.3, 0, -3.5)]:
			if not await _walk(point): return
		await get_tree().physics_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var report: Dictionary = world.passage_region.residency.snapshot()
		print("STREAMING_PROFILE ", JSON.stringify(report))
		if report.state != "DORMANT" or report.retired_geometry_roots_alive != 0 or report.retired_mesh_resources_alive != 0:
			failures.append("retired geometry resources")
