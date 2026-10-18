extends Node
## Composed imported geometry checks and optical views; no navigation grant.
func run(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var passage := world.passage_region
	suite.check(passage != null and not passage.startup_failed, "arcade fabric exists in the composed production region")
	if passage == null or passage.startup_failed: return
	suite.check(passage.cell_nodes.has("passage"), "arcade geometry is resident for composed material review")
	if not passage.cell_nodes.has("passage"): return
	var diagnosis := preload("res://tests/arcade_fabric_bench.gd").new()
	diagnosis.externally_managed = true
	diagnosis.review_suite = suite
	add_child(diagnosis)
	await diagnosis.validate_cell(passage.cell_nodes.passage, passage.source_layout)
	diagnosis.free()
	var clock_diagnosis:=preload("res://tests/arcade_clock_bench.gd").new()
	clock_diagnosis.externally_managed=true;clock_diagnosis.review_suite=suite
	add_child(clock_diagnosis)
	await clock_diagnosis.validate_cell(passage.cell_nodes.passage)
	clock_diagnosis.free()
	var directory := OS.get_environment("SHOT_DIR")
	var camera := world.player.camera
	var prior_pose := camera.global_transform
	var prior_physics := world.player.is_physics_processing()
	var prior_lamp := world.player.lamp_is_enabled()
	world.player.set_physics_process(false)
	var stations: Array[Dictionary] = [
		{"name":"arcade_clock_player", "eye":Vector3(14,1.65,46), "target":Vector3(14,6.21,51.6), "lamp":false},
		{"name":"arcade_clock_detail", "eye":Vector3(14.85,6.45,50.5), "target":Vector3(14,6.21,51.6), "lamp":false},
		{"name":"arcade_clock_carried", "eye":Vector3(14,1.65,49), "target":Vector3(14,6.21,51.6), "lamp":true},
		{"name":"arcade_clock_underside", "eye":Vector3(14.65,5.5,50.8), "target":Vector3(14,6.21,51.6), "lamp":false},
		{"name":"arcade_floor_diffuse", "eye":Vector3(14, 1.65, 33), "target":Vector3(13.4, .02, 34.4), "lamp":false},
		{"name":"arcade_floor_carried", "eye":Vector3(14, 1.65, 33), "target":Vector3(13.4, .02, 34.4), "lamp":true},
		{"name":"arcade_clay_joint", "eye":Vector3(11.45, 1.65, 23.8), "target":Vector3(11, 2.6, 24.4), "lamp":false},
		{"name":"arcade_clay_carried", "eye":Vector3(11.45, 1.65, 23.8), "target":Vector3(11, 2.6, 24.4), "lamp":true},
		{"name":"arcade_barrel_underside", "eye":Vector3(14, 1.65, 32), "target":Vector3(14, 8.3, 41), "lamp":false},
		{"name":"arcade_lantern_shoulders", "eye":Vector3(14, 1.65, 38), "target":Vector3(11.3, 9.1, 39.1), "lamp":false},
		{"name":"arcade_south_gable", "eye":Vector3(14, 1.65, 48), "target":Vector3(14, 7.8, 54.7), "lamp":false},
		{"name":"arcade_lantern_well", "eye":Vector3(14, 1.65, 46), "target":Vector3(14, 11.2, 51.6), "lamp":false},
	]
	var records: Array[Dictionary] = []
	for station: Dictionary in stations:
		camera.global_position = station.eye
		camera.look_at(station.target)
		world.player.set_lamp_enabled(bool(station.lamp))
		var deadline := Time.get_ticks_msec() + 6000
		while world.player.flashlight.visible != bool(station.lamp) and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(.05).timeout
		suite.check(world.player.flashlight.visible == bool(station.lamp), "real carried light settles for " + str(station.name))
		await get_tree().create_timer(.4).timeout
		for frame in 5: await RenderingServer.frame_post_draw
		var file := str(station.name) + ".png"
		suite.check(get_viewport().get_texture().get_image().save_png(directory.path_join(file)) == OK, "composed arcade view saved: " + file)
		var eye: Vector3 = station.eye
		var target: Vector3 = station.target
		records.append({"file":file, "eye":[eye.x, eye.y, eye.z], "target":[target.x, target.y, target.z], "carried_lamp":bool(station.lamp)})
	var record := FileAccess.open(directory.path_join("arcade_fabric_views.json"), FileAccess.WRITE)
	record.store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Composed optical views and imported source-owner checks; not played access or visual acceptance.", "stations":records}, "\t")); record.close()
	camera.global_transform = prior_pose
	world.player.set_physics_process(prior_physics)
	world.player.set_lamp_enabled(prior_lamp)
