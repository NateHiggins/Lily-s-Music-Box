extends "res://tests/orison_v2_radio_display_test.gd"
func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var observations: Array=[]
	var capture_door: DoorProp=world.passage_region.doors["SITE_SHOP_DOOR_RADIO_SERVICE"]
	capture_door.npc_set_open(false);await get_tree().create_timer(.8).timeout
	check(not capture_door.open and absf(capture_door._body.rotation.y)<.000001,"diagnostic leaf reaches existing closed owner pose")
	for view: Dictionary in BEFORE_RADIO_WINDOW_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"retained window/counter standing floor and capsule sample: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(bool(view.lamp))
		await _settled_optics();await shot(view.id);observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"capture_leaf_pose":{"id":"SITE_SHOP_DOOR_RADIO_SERVICE","open":capture_door.open,"angle_radians":capture_door._body.rotation.y,"method":"existing npc_set_open closed diagnostic pose; no ordinary-input route claim"},"scope":"Matched floor/capsule observations of window speaker placement and fitted counter. Original glazing/backboard and physical collision remain. Exterior lamp off avoids direct torch reflection. No continuous route, sightline, signal, operation or engineering capacity."}))

const BEFORE_RADIO_WINDOW_VIEWS: Array=[{"id":"passive_window_stock","image":"passive_window_stock.png","feet":[15.6,0.03,57.95],"target":[17.24,0.74,57.95],"lamp":false},{"id":"window_horn_mouth","image":"window_horn_mouth.png","feet":[15.6,0.03,58.25],"target":[17.24,0.72,58.27],"lamp":false},{"id":"window_cone_speaker","image":"window_cone_speaker.png","feet":[15.6,0.03,57.6],"target":[17.24,0.75,57.63],"lamp":false},{"id":"window_plinth_bearings","image":"window_plinth_bearings.png","feet":[15.6,0.03,57.95],"target":[17.35,0.44,57.95],"lamp":false},{"id":"counter_floor_posts","image":"counter_floor_posts.png","feet":[17.5,0.03,56.8],"target":[17.98,0.1,57.36],"lamp":true},{"id":"seated_counter_ledger","image":"seated_counter_ledger.png","feet":[17.5,0.03,56.8],"target":[18.1,1.16,57.35],"lamp":true}]
