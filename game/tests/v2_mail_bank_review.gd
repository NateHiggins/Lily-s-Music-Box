extends RefCounted
## Shared production-world geometric/mechanism review; no delivery fixture grants mail.
func run(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var bank := world.find_child("LobbyMailBank", true, false) as MailBankProp
	suite.check(bank != null and bank.get_meta("v2_native_mail_bank", false), "production bank uses native stock")
	if bank == null or not bank.get_meta("v2_native_mail_bank", false): return
	suite.check(bank._fixed.find_children("*", "MeshInstance3D", true, false).size() == 6, "24 pockets keep six fixed material draws")
	var faces: Array[Vector3] = []
	for draw: MeshInstance3D in bank._fixed.find_children("*", "MeshInstance3D", true, false):
		if draw.name in [&"HeaderLettering", &"FixedNameCards"]: continue
		var pose: Transform3D = bank.global_transform.affine_inverse() * draw.global_transform
		for point: Vector3 in draw.mesh.get_faces(): faces.append(pose * point)
	for unit: String in bank.EMPTY_UNITS + [bank.PLAYER_UNIT]:
		var x := (bank.STACKS.find(unit[1]) - 1.5) * bank.DOOR_W
		var y := bank.ARRAY_BASE + (int(unit[0]) - .5) * bank.DOOR_H
		var start := Vector3(x, y, -.50)
		var depth := INF
		for index in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(start, Vector3.BACK, faces[index], faces[index+1], faces[index+2])
			if hit != null: depth = minf(depth, hit.z - start.z)
		suite.check(is_finite(depth) and absf(depth - .482) < .001,
				"actual vacant/player pocket reaches its rear lining without a solid face: " + unit)
	var body := bank.get_node("PlayerBox") as StaticBody3D
	var query := PhysicsRayQueryParameters3D.create(bank.to_global(Vector3(-.155, 1.410, -1.65)),
			bank.to_global(Vector3(-.155, 1.410, -.078)), 1, [world.player.get_rid()])
	suite.check(world.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == body,
			"production use ray still reaches original 4B mail authority")
	var custody := _custody(); var catalog := JSON.stringify(bank.deliveries)
	var camera := Camera3D.new(); camera.fov = 50; world.add_child(camera); camera.make_current()
	camera.global_position = bank.to_global(Vector3(.40, 1.42, -1.65)); camera.look_at(bank.to_global(Vector3(0, 1.24, -.09)), Vector3.UP)
	world.player.carried_device.set_capture_hidden(true)
	await suite.shot("native_mail_bank_closed")
	bank._set_door(true); await world.get_tree().create_timer(.45).timeout
	suite.check(bank.door_open and is_equal_approx(bank._hinge.rotation.y, deg_to_rad(95)), "native leaf follows original 95-degree mechanism")
	await suite.shot("native_mail_bank_open")
	camera.global_position = bank.to_global(Vector3(-.40, 1.57, -.64)); camera.look_at(bank.to_global(Vector3(-.155, 1.41, -.05)), Vector3.UP)
	await suite.shot("native_mail_bank_pocket_detail")
	bank._set_door(false); await world.get_tree().create_timer(.45).timeout
	suite.check(not bank.door_open and is_zero_approx(bank._hinge.rotation.y), "native door returns fully closed")
	suite.check(_custody() == custody and JSON.stringify(bank.deliveries) == catalog,
			"geometry review neither grants nor consumes catalog deliveries")
	# Exercise every delivery visual under its real source owner. These samples
	# are geometry QA only; they do not fabricate pending mail or change custody.
	for child: Node in bank._contents.get_children(): bank._contents.remove_child(child); child.free()
	for stock: String in bank._native_content_meshes:
		var at := Vector3(.02, .006, 0) if stock == "EnvelopeStock" else Vector3(-.055, .05, 0) if stock == "WorkOrderStock" else Vector3(.01, .045, -.015 if stock == "ParcelBand" else .014)
		bank._content_box(at, Vector3.ZERO, Color.WHITE, stock)
	for item: MeshInstance3D in bank._contents.get_children():
		suite.check(item.has_meta("native_mail_content") and item.mesh != null, "native delivery stock mounted: " + str(item.get_meta("native_mail_content", "")))
		var fits := true
		var pose: Transform3D = bank.global_transform.affine_inverse() * item.global_transform
		for corner: Vector3 in item.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = pose * corner
			if point.x < -.155-.142-.001 or point.x > -.155+.142+.001 or point.y < 1.410-.061-.001 or point.y > 1.410+.061+.001 or point.z < -.108 or point.z > -.018: fits = false
		suite.check(fits, "delivery fits lining and closed-leaf clearance: " + str(item.get_meta("native_mail_content", "")))
	camera.free(); world.player.camera.make_current()

func _custody() -> String:
	# Other production owners can update the campaign while the tween runs.
	# These are the durable fields this mailbox can actually grant or consume.
	return JSON.stringify({"mail_taken":RealityState.data.get("mail_taken", []), "upgrades":RealityState.data.get("upgrades", [])})
