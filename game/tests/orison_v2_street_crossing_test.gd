extends "res://tests/orison_v2_vertical_route_test.gd"
## Continuous production-controller crossing of the authored full-width road.

func _init() -> void:
	route_label = "V2 STREET CROSSING"

func _route() -> void:
	for point in [Vector3(2.3, 0, -6.5), Vector3(0, 0, -8.5),
			Vector3(0, 0, -10.2), Vector3(0, 0, -12.2)]:
		if not await _walk(point): return
	var crossing := [Vector3(0, 0, 3), Vector3(14, 0, 3), Vector3(14, 0, 4.2),
		Vector3(14, -0.1, 8), Vector3(14, -0.1, 13.6), Vector3(14, 0, 15),
		Vector3(14, 0, 18.2)]
	for point: Vector3 in crossing:
		if not await _walk(world.adapter.root.to_local(point)): return
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		player.camera.look_at(Vector3(0, 1.5, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("street_from_arcade_line.png"))
	crossing.reverse()
	for point: Vector3 in crossing:
		if not await _walk(world.adapter.root.to_local(point)): return
	for point in [Vector3(0, 0, -10.2), Vector3(0, 0, -8.5), Vector3(2.3, 0, -6.5)]:
		if not await _walk(point): return
