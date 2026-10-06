extends "res://tests/orison_v2_arcade_shop_route_test.gd"
## Existing east threshold tour plus continuous Radio Service work-bay access.
func _init() -> void:
	side="east";route_label="V2 RADIO ACCESS"

func _visit_shop(identity: String, door: DoorProp) -> bool:
	if not await super._visit_shop(identity,door):return false
	if identity!="SITE_SHOP_DOOR_RADIO_SERVICE":return true
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_battery.json"))
	if not _require(["RadioBench","RadioApparatus","RadioStock","RadioBattery","RadioWire","RadioDisplay"].all(func(name):return cell.has_node(name)),"all native Radio Service fittings survive the actual exterior round"):return false
	var battery: Node3D=cell.get_node("RadioBattery")
	var retired: Dictionary=battery.get_meta("removed_triangles")
	if not _require(retired.values().reduce(func(total,value):return total+int(value),0)==132 and battery.find_children("*","MeshInstance3D",true,false).size()==fixture.parts.size(),"reloaded charging display retains exact replacement and native partitions"):return false
	var rack: Dictionary=fixture.fitted_records.filter(func(row):return row.id=="storm_shop_radio_service_battery_rack")[0]
	var source_rows: Array=world.passage_region.source_layout.floors.filter(func(row):return row.id=="F01")[0].furniture
	var bench: Dictionary=source_rows.filter(func(row):return row.id=="storm_shop_radio_service_bench_top")[0]
	var counter: Dictionary=source_rows.filter(func(row):return row.id=="storm_shop_radio_service_counter_top")[0]
	var centre:=door.to_global(Vector3(door.width*.5,.01,0));var front:=Vector3(15.6,.01,centre.z)
	var lane_z: float=-float(bench.rect[1])+.36;var lane_x: float=float(rack.rect[2])+.41
	var corridor:=cell.to_global(Vector3(lane_x,.01,lane_z))
	var charging:=cell.to_global(Vector3(lane_x,.01,-(float(rack.rect[1])+float(rack.rect[3]))*.5))
	# Follow the counter's front corner before crossing behind the bench.
	# The inherited inside-door stance is beside the ledger, not a work aisle.
	var approach_z: float=-float(counter.rect[3])-.36
	var turn_x: float=(float(counter.rect[2])+float(bench.rect[0]))*.5
	var path: Array[Vector3]=[front,Vector3(17.2,.01,centre.z),
		cell.to_global(Vector3(17.2,.01,approach_z)),cell.to_global(Vector3(turn_x,.01,approach_z)),
		cell.to_global(Vector3(turn_x,.01,lane_z)),corridor,charging]
	for point: Vector3 in path:
		if not await _walk_world(point):return false
	await _clean_capture("radio_charging_work_bay",cell.to_global(Vector3((float(rack.rect[0])+float(rack.rect[2]))*.5,1.15,-(float(rack.rect[1])+float(rack.rect[3]))*.5)))
	path.reverse()
	for point: Vector3 in path:
		if not await _walk_world(point):return false
	return await _walk_world(Vector3(14,.01,centre.z))
