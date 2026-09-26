extends "res://tests/orison_v2_roof_route_test.gd"
## Installation, automatic operation, physical guard access and sealed homes.

func _init() -> void:
	route_label = "V2 SHARED VENTILATION"

func _route() -> void:
	var total := 0
	var running := 0
	await get_tree().create_timer(26).timeout
	for stack: String in ["A","B","C","D"]:
		var fan := world.adapter.resolve("ROOF_VENT_FAN_"+stack) as ExhaustFanProp
		if not _require(fan != null and fan.riser == "V-"+stack, "production roof motor " + stack): return
		if fan.is_running(): running += 1
		for emitter: AudioStreamPlayer3D in fan._duct_emitters:
			var identity := str(emitter.name).trim_prefix("Duct_")
			var register := world.adapter.resolve(identity) as Node3D
			if not _require(register != null and emitter.global_position.distance_to(register.global_position) < .01,
					"motor sound terminates at actual register " + identity): return
			total += 1
		player.global_position = fan.global_position + world.adapter.root.global_basis * Vector3(.31,.02,-1.25)
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if not await _use(fan, fan.to_global(Vector3(.31,.42,-.36)), "guarded ventilator " + stack): return
		var card := fan.service_wire_card()
		if not _require(card.get("card_id") == "exhaust_fan" and "SERVICE ISOLATION REQUIRED" in str(card.get("condition", "")), "guard presents the production service refusal"): return
		await _roof_capture("roof_fan_"+stack, world.adapter.root.to_local(fan.global_position)+Vector3(0,.5,0))
		var forward: Vector3 = world.adapter.root.global_basis * Vector3.BACK
		player.rotation.y = atan2(-forward.x,-forward.z)
		Input.action_press("move_forward")
		await get_tree().create_timer(.6).timeout
		Input.action_release("move_forward")
		if not _require(fan.to_local(player.global_position).z < -.5, "fan curb stops real player " + stack): return
	if not _require(total == 23 and running > 0, "23 passive registers and automatic roof operation"): return
	for identity: String in ["F02_D_ENTRY_DOOR","F03_C_ENTRY_DOOR"]:
		var leaf := _leaf(identity)
		if not _require(leaf != null and leaf.leaf_state == "locked", "restricted apartment remains locked " + identity): return
		var ray := PhysicsRayQueryParameters3D.create(leaf.to_global(Vector3(leaf.width*.5,1.1,-.6)),leaf.to_global(Vector3(leaf.width*.5,1.1,.6)),1)
		ray.exclude = [player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not _require(hit.get("collider") == leaf.get_node("HingedLeaf"), "restricted apartment has real barrier " + identity): return
