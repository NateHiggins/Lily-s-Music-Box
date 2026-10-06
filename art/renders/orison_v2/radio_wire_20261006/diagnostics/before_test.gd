extends "res://tests/orison_v2_radio_apparatus_test.gd"
func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var observations: Array=[]
	for view: Dictionary in RADIO_WIRE_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"same retained floor/capsule radio wire/ring observation: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Same retained standing floor/capsule samples before and after passive wire/ring fitting. No continuous route, sightline, alignment procedure, instrument operation or engineering capacity."},"\t"))

const RADIO_WIRE_VIEWS: Array=[{"id":"radio_wire_room","image":"radio_wire_room.png","feet":[19.45,0.03,57.8],"target":[20.65,0.31,57.2]},{"id":"two_fixed_reels","image":"two_fixed_reels.png","feet":[19.45,0.03,57.8],"target":[20.77,0.4,57.2]},{"id":"passive_copper_winding","image":"passive_copper_winding.png","feet":[19.45,0.03,57.5],"target":[20.77,0.47,57.4]},{"id":"fixed_spindle_bearing","image":"fixed_spindle_bearing.png","feet":[19.45,0.03,57.8],"target":[20.77,0.38,57.4]},{"id":"finite_open_iron_ring","image":"finite_open_iron_ring.png","feet":[19.4,0.03,57.5],"target":[20.27,0.24,57.2]},{"id":"wire_and_ring_floor_feet","image":"wire_and_ring_floor_feet.png","feet":[19.4,0.03,57.85],"target":[20.3,0.04,57.2]}]
