extends "res://tests/orison_v2_roof_route_test.gd"
## Installation, automatic operation, physical guard access and sealed homes.

func _init() -> void:
	route_label = "V2 SHARED VENTILATION"

func _route() -> void:
	failures.append("ventilation checks interrupted before completion")
	var total := 0
	var running := 0
	var ducts := world.adapter.root.get_node("VentilationDucts") as Node3D
	var expected := {"A":5,"B":6,"C":5,"D":7}
	# Exterior risers must occupy solid fabric, not cover a window's glazing.
	for window: Dictionary in world.adapter.root.layout.windows:
		var floor_y: float = world.adapter.root.level_y[str(window.level)]
		var center := Vector3(float(window.center[0]),floor_y+float(window.sill)+float(window.height)*.5,float(window.center[1]))
		var shape := BoxShape3D.new()
		shape.size = Vector3(float(window.width),float(window.height),.4) if str(window.axis)=="x" else Vector3(.4,float(window.height),float(window.width))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1
		query.transform = Transform3D(world.adapter.root.global_basis,world.adapter.root.to_global(center))
		for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,128):
			if not _require(not ducts.is_ancestor_of(hit.collider),"ducts preserve window opening " + str(window.id)): return
	await get_tree().create_timer(26).timeout
	for stack: String in ["A","B","C","D"]:
		var fan := world.adapter.resolve("ROOF_VENT_FAN_"+stack) as ExhaustFanProp
		if not _require(fan != null and fan.riser == "V-"+stack, "production roof motor " + stack): return
		var body := ducts.get_node("Stack_"+stack) as StaticBody3D
		var roster: Array = body.get_meta("registers")
		if not _require(roster.size()==int(expected[stack]) and fan._duct_emitters.size()==roster.size(),
				"physical stack and production motor share the complete geographic roster " + stack): return
		if fan.is_running(): running += 1
		for emitter: AudioStreamPlayer3D in fan._duct_emitters:
			var identity := str(emitter.name).trim_prefix("Duct_")
			var register := world.adapter.resolve(identity) as Node3D
			if not _require(register != null and emitter.global_position.distance_to(register.global_position) < .01,
					"motor sound terminates at actual register " + identity): return
			var local: Vector3 = world.adapter.root.to_local(register.global_position)
			var geographic := ("A" if local.z>0 else "B") if local.x<0 else ("C" if local.z>0 else "D")
			if not _require(roster.has(identity) and geographic==stack,"bearing tone follows physical bathroom stack " + identity): return
			var query := PhysicsShapeQueryParameters3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = .22
			capsule.height = 1.524
			query.shape = capsule
			query.collision_mask = 1
			var floor_y := (float(identity.substr(1,2))-1.0)*float(world.adapter.root.layout.dimensions.floor_to_floor)
			query.transform = Transform3D(Basis.IDENTITY,world.adapter.root.to_global(Vector3(local.x,floor_y+.762,local.z)))
			query.exclude = [player.get_rid()]
			for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,64):
				if not _require(not ducts.is_ancestor_of(hit.collider),"standing capsule clears ductwork at " + identity): return
			# A real overhead ray must hit this stack's plenum, not a visual-only mesh.
			var ray := PhysicsRayQueryParameters3D.create(register.global_position-Vector3.UP*.2,register.global_position+Vector3.UP*.08,1)
			if not _require(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==body,
					"register terminates at a solid duct plenum " + identity): return
			total += 1
		player.global_position = fan.to_global(Vector3(.31,.02,-1.25))
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if not await _use(fan, fan.to_global(Vector3(.31,.42,-.36)), "guarded ventilator " + stack): return
		var card := fan.service_wire_card()
		if not _require(card.get("card_id") == "exhaust_fan" and "SERVICE ISOLATION REQUIRED" in str(card.get("condition", "")), "guard presents the production service refusal"): return
		await _roof_capture("roof_fan_"+stack, world.adapter.root.to_local(fan.global_position)+Vector3(0,.5,0))
		var forward: Vector3 = fan.global_basis * Vector3.BACK
		player.rotation.y = atan2(-forward.x,-forward.z)
		Input.action_press("move_forward")
		await get_tree().create_timer(.6).timeout
		Input.action_release("move_forward")
		if not _require(fan.to_local(player.global_position).z < -.5, "fan curb stops real player " + stack): return
	if not _require(total == 23 and running > 0, "23 passive registers and automatic roof operation"): return
	player.telegram_hud.dismiss()
	var capture_stances := {
		"F01_A_BATH_VENT_REGISTER":Vector3(-7.35,.02,-10.9),
		"F02_C_BATH_VENT_REGISTER":Vector3(1.05,3.22,5.1),
		"F03_B_BATH_VENT_REGISTER":Vector3(13.8,6.42,-10.5),
		"F04_B_BATH_VENT_REGISTER":Vector3(-7.9,9.62,4.75)}
	for identity: String in capture_stances:
		var register := world.adapter.resolve(identity) as Node3D
		if not _require(register!=null,"inspection register exists " + identity): return
		var at: Vector3 = world.adapter.root.to_local(register.global_position)
		player.global_position = world.adapter.root.to_global(capture_stances[identity])
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		await _roof_capture(identity+"_duct",at+Vector3(0,.03,0))
	for identity: String in ["F02_D_ENTRY_DOOR","F03_C_ENTRY_DOOR"]:
		var leaf := _leaf(identity)
		if not _require(leaf != null and leaf.leaf_state == "locked", "restricted apartment remains locked " + identity): return
		var ray := PhysicsRayQueryParameters3D.create(leaf.to_global(Vector3(leaf.width*.5,1.1,-.6)),leaf.to_global(Vector3(leaf.width*.5,1.1,.6)),1)
		ray.exclude = [player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not _require(hit.get("collider") == leaf.get_node("HingedLeaf"), "restricted apartment has real barrier " + identity): return
	failures.erase("ventilation checks interrupted before completion")
