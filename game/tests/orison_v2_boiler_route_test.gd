extends "res://tests/orison_v2_roof_route_test.gd"
## Reach the actual basement plant through production stairs and a fire door.
func _init() -> void:
	route_label = "V2 BOILER SERVICE"

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(2.3,.02,-3.5))
	player.velocity = Vector3.ZERO

func _use(owner_node: Node3D, target: Vector3, label: String) -> bool:
	# The interaction ray turns instantly in this scripted route; let the real
	# carried lamp catch up before judging the rendered control surface.
	player.camera.look_at(target)
	await get_tree().create_timer(.6).timeout
	var lamp := player.flashlight
	var incidence := rad_to_deg((-lamp.global_basis.z).angle_to(target-lamp.global_position))
	if not _require(incidence < lamp.spot_angle*.5,
			"settled physical lamp centers interaction target: " + label): return false
	return await super._use(owner_node,target,label)

func _route() -> void:
	for point in [Vector3(3.8,0,-3.4),Vector3(3.8,-1.6,1.3),Vector3(2.3,-1.6,1.3),
			Vector3(2.3,-3.2,-3.5),Vector3(5,-3.2,-3.5),Vector3(5,-3.2,-.4),Vector3(8.3,-3.2,-.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_BOILER_FIRE_DOOR"): return
	for point in [Vector3(11.1,-3.2,-.4),Vector3(10.9,-3.2,-.5)]:
		if not await _walk(point): return
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	if not _require(boiler != null and world.boiler_tend.boiler == boiler, "one physical plant supplies the building"): return
	if not _require(is_equal_approx(world.adapter.root.to_local(boiler.global_position).y, -3.2),"boiler feet meet the authored basement floor"): return
	var floor_probe := PhysicsRayQueryParameters3D.create(boiler.to_global(Vector3(0,.01,0)),boiler.to_global(Vector3(0,-.08,0)),1)
	floor_probe.exclude = [boiler.get_node("BoilerCollision").get_rid()]
	if not _require(not world.get_world_3d().direct_space_state.intersect_ray(floor_probe).is_empty(),"actual solid floor supports the plant"): return
	var reservation: Node3D = world._blockout.find_child("B1_BOILER_BODY_MASS",true,false)
	var shapes := reservation.find_children("*","CollisionShape3D",true,false)
	if not _require(not reservation.visible and not shapes.is_empty()
			and shapes.all(func(shape): return shape.disabled),"retired placeholder cannot hide or block the live plant"): return
	for record in [["FireDoorReach","firing door",Vector3(0,1.03,-.72)],
			["AshDoorReach","ash door",Vector3(0,.43,-.70)]]:
		var area: Area3D = boiler.get_node(record[0])
		if not _require(area.interact_prompt().contains("Open " + record[1]), "closed control names its own door"): return
		if not await _use(area,boiler.to_global(record[2]),str(record[0])+"_open"): return
		if not _require(area.interact_prompt().contains("Close " + record[1]), "opened control offers to close its own door"): return
		if not await _use(area,boiler.to_global(record[2]),str(record[0])+"_close"): return
		if not _require(not boiler._fire_open and not boiler._ash_open,"door controls do not toggle their neighbour"): return
	for point in [Vector3(11.1,-3.2,-2.5),Vector3(14.1,-3.2,-2.5),Vector3(14.1,-3.2,-.3)]:
		if not await _walk(point): return
	var draft: Area3D = boiler.get_node("DraftReach")
	var previous := boiler.draft
	var temperature: float = world.boiler_tend.taps[0]._boiler_temperature
	var serial := player.telegram_hud.serial
	if not _require(draft.interact_prompt().contains("draft"),"damper advertises draft rather than a firing door"): return
	if not await _use(draft,boiler._draft_damper.global_position,"draft_adjust"): return
	if not _require(boiler.draft > previous and world.boiler_tend.taps[0]._boiler_temperature > temperature
			and is_equal_approx(world.heat_balance._boiler_output,boiler.boiler_output()),
			"physical draft control changes the existing hot-water and radiator supply"): return
	if not _require(player.telegram_hud.serial > serial,"boiler control retains its service-wire response"): return
	for point in [Vector3(14.1,-3.2,-2.5),Vector3(11.1,-3.2,-2.5),Vector3(10.9,-3.2,-.5)]:
		if not await _walk(point): return
	var glass: Area3D = boiler.get_node("WaterGlassReach")
	if not await _use(glass,boiler.to_global(Vector3(.54,1.05,-.55)),"water_column_service"): return
	if not _require(boiler._service_panel != null and player.call_locked,"water-column activity opens through actual E"): return
	boiler._service_panel._director.abort()
	await get_tree().process_frame
	if not _require(not player.call_locked and not boiler.column_proved,"abort releases movement without proving the column"): return
	if not await _use(glass,boiler.to_global(Vector3(.54,1.05,-.55)),"water_column_reopen"): return
	var activity := boiler._service_panel
	for step: Dictionary in activity._director.active_run.profile.steps:
		boiler.preview_maintenance_step(step,float(step.target))
		if not _require(activity._director.submit(str(step.verb),float(step.target),float(step.get("hold_min_seconds",0))+.4),"water-column step " + str(step.id)): return
	await get_tree().create_timer(1.0).timeout
	if not _require(boiler.column_proved and not boiler.column_isolated and not player.call_locked,"proved water column returns to service and releases movement"): return
	for point in [Vector3(11.1,-3.2,-.4),Vector3(8.3,-3.2,-.4)]:
		if not await _walk(point): return
