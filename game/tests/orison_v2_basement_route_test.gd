extends "res://tests/orison_v2_roof_route_test.gd"
## One initial placement; all service-room and stair travel uses live collision.
func _init() -> void:
	route_label = "BASEMENT ROUTE"

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(1.925,.02,-3.5))
	player.velocity = Vector3.ZERO

func _route() -> void:
	for point in [Vector3(3.975,0,-3.4),Vector3(3.975,-1.6,1.3),Vector3(1.925,-1.6,1.3),Vector3(1.925,-3.2,-3.5),Vector3(1.925,-3.2,-3.1),Vector3(5,-3.2,-3.1),Vector3(5,-3.2,2.8),Vector3(4.4,-3.2,2.8)]:
		if not await _walk(point): return
	if not await _open_door("B1_STORAGE_DOOR"): return
	for point in [Vector3(4.4,-3.2,5),Vector3(4.4,-3.2,6.675)]:
		if not await _walk(point): return
	var storage: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/resident_storage.json"))
	for bay: Dictionary in storage.labels:
		var x:=float(bay.position[0]);var front:=float(bay.position[2])-(.06 if is_zero_approx(float(bay.yaw)) else -.06)
		var inside:=front-1.05 if is_zero_approx(float(bay.yaw)) else front+1.05
		if front>9:
			for point in [Vector3(4.78,-3.2,6.675),Vector3(4.78,-3.2,8.9),Vector3(4.6,-3.2,9.1),Vector3(4.6,-3.2,9.9),Vector3(x,-3.2,inside),Vector3(4.6,-3.2,9.9),Vector3(4.6,-3.2,9.1),Vector3(4.78,-3.2,8.9),Vector3(4.78,-3.2,6.675)]:
				if not await _walk(point):return
		else:
			for point in [Vector3(x,-3.2,6.675),Vector3(x,-3.2,inside),Vector3(x,-3.2,6.675)]:
				if not await _walk(point):return
	await _roof_capture("resident_storage",Vector3(-7,-1.8,6.675))
	for point in [Vector3(4.4,-3.2,6.675),Vector3(4.4,-3.2,2.8),Vector3(5.0,-3.2,2.8),Vector3(5.0,-3.2,-.4),Vector3(7.4,-3.2,-.4)]:
		if not await _walk(point): return
	if not await _open_door("B1_ELECTRICAL_DOOR"): return
	for point in [Vector3(7.4,-3.2,-2.3),Vector3(7.6,-3.2,-4.9)]:
		if not await _walk(point): return
	var panel := world.adapter.resolve("B1_FUSE_PANEL") as FusePanelProp
	if not _require(panel != null,"production fuse panel mounted"): return
	var repair := preload("res://tests/fuse_panel_hand_test.gd").new()
	repair.batch_mode=true;repair.player=player;repair.panel=panel
	repair.out=OS.get_environment("SHOT_DIR")
	if repair.out.is_empty(): repair.out="user://basement_fuse_route"
	DirAccess.make_dir_recursive_absolute(repair.out)
	add_child(repair)
	await repair._repair_by_hand(false)
	var repair_failed := false
	for row: Dictionary in repair.checks:
		if not _require(row.ok,"fuse service: "+str(row.label)): repair_failed=true
	repair.free()
	if repair_failed: return
	if not _require(panel.panel_safe and panel.protects_conductor() and not player.call_locked and panel._service_panel==null,"physical panel service returns ordinary movement without overlay"): return
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
	# The fire leaf opens toward this approach. Leave room for the actual player
	# capsule as well as its one-metre leaf; the closer stance blocks at .9 rad.
	if not await _walk(Vector3(10.95,-3.2,-.4)): return
	if not await _open_door("B1_BOILER_FIRE_DOOR"): return
	if not await _walk(Vector3(8.3,-3.2,-.4)): return
	_require(not player.noclip and player.collision_mask == 1,"service circuit retains actual collision")
