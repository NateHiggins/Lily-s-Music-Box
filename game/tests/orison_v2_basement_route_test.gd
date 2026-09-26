extends "res://tests/orison_v2_roof_route_test.gd"
## One initial placement; all service-room and stair travel uses live collision.
func _init() -> void:
	route_label = "BASEMENT ROUTE"

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(2.3,.02,-3.5))
	player.velocity = Vector3.ZERO

func _route() -> void:
	for point in [Vector3(3.8,0,-3.4),Vector3(3.8,-1.6,1.3),Vector3(2.3,-1.6,1.3),Vector3(2.3,-3.2,-3.5),Vector3(5,-3.2,-3.5),Vector3(5,-3.2,2.8),Vector3(4.4,-3.2,2.8)]:
		if not await _walk(point): return
	if not await _open_door("B1_STORAGE_DOOR"): return
	for point in [Vector3(4.4,-3.2,5),Vector3(4.4,-3.2,6.675)]:
		if not await _walk(point): return
	for column in 9:
		var starts := [0.0,1.6,4.25,5.55,6.85,8.15,9.45,10.75,12.05]
		var x: float = -9.85+starts[column]+(.8 if column < 2 else .65)+.025
		for point in [Vector3(x,-3.2,6.675),Vector3(x,-3.2,4.9),Vector3(x,-3.2,6.675),Vector3(x,-3.2,8.45),Vector3(x,-3.2,6.675)]:
			if not await _walk(point): return
	await _roof_capture("resident_storage",Vector3(-7,-1.8,6.675))
	for point in [Vector3(4.4,-3.2,6.675),Vector3(4.4,-3.2,2.8),Vector3(5.0,-3.2,2.8),Vector3(5.0,-3.2,-.4),Vector3(7.4,-3.2,-.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_ELECTRICAL_DOOR"): return
	for point in [Vector3(7.4,-3.2,-2.3),Vector3(7.6,-3.2,-4.9)]:
		if not await _walk(point): return
	var panel := world.adapter.resolve("B1_FUSE_PANEL") as FusePanelProp
	if not _require(panel != null,"production fuse panel mounted"): return
	var reach := panel.get_node("PanelReach") as Area3D
	if not await _use(reach,reach.to_global(Vector3(0,.52,.14)),"fuse_service"): return
	if not _require(panel._service_panel != null and player.call_locked,"fuse maintenance opens through E"): return
	panel._service_panel._director.abort()
	await get_tree().process_frame
	if not _require(not player.call_locked,"aborting returns movement"): return
	if not await _use(reach,reach.to_global(Vector3(0,.52,.14)),"fuse_service_reopen"): return
	var activity := panel._service_panel
	var run: MaintenanceActivityRun = activity._director.active_run
	for step: Dictionary in run.profile.steps:
		panel.preview_maintenance_step(step,float(step.target))
		if not _require(activity._director.submit(str(step.verb),float(step.target),float(step.get("hold_min_seconds",0))+.4),"fuse service step "+str(step.id)): return
	await get_tree().create_timer(1.0).timeout
	if not _require(panel.panel_safe and panel.protects_conductor() and not player.call_locked,"completed panel service returns movement"): return
	for point in [Vector3(7.4,-3.2,-2.3),Vector3(7.4,-3.2,-.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_SHOP_DOOR"): return
	for point in [Vector3(7.4,-3.2,1.5),Vector3(8.3,-3.2,3.8)]:
		if not await _walk(point): return
	await _roof_capture("maintenance_shop",Vector3(6.8,-2.1,5.5))
	if not await _walk(Vector3(8.4,-3.2,4.55)): return
	if not await _open_door("B1_SHOP_STAIR_DOOR"): return
	for point in [Vector3(11.075,-3.2,4.55),Vector3(11.075,-1.6,9.15),Vector3(12.425,-1.6,9.15),Vector3(12.425,0,5.65),Vector3(12.425,0,3.5),Vector3(12.425,0,5.65),Vector3(12.425,-1.6,9.15),Vector3(11.075,-1.6,9.15),Vector3(11.075,-3.2,4.55)]:
		if not await _walk(point): return
	if not await _open_door("B1_BOILER_STAIR_DOOR"): return
	for point in [Vector3(11.075,-3.2,3.1),Vector3(11.075,-3.2,2.4),Vector3(10.6,-3.2,2.4),Vector3(10.6,-3.2,-3.8),Vector3(14.2,-3.2,-3.8),Vector3(14.2,-3.2,-4.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_COAL_DOOR"): return
	for point in [Vector3(14.2,-3.2,-6.8),Vector3(12.8,-3.2,-7.4)]:
		if not await _walk(point): return
	await _roof_capture("coal_room",Vector3(14.2,-2.8,-9))
	for point in [Vector3(14.2,-3.2,-6.8),Vector3(14.2,-3.2,-3.8),Vector3(10.6,-3.2,-3.8),Vector3(10.6,-3.2,-.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_BOILER_FIRE_DOOR"): return
	if not await _walk(Vector3(8.3,-3.2,-.4)): return
	_require(not player.noclip and player.collision_mask == 1,"service circuit retains actual collision")
