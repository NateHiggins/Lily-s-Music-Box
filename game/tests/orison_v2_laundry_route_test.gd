extends "res://tests/orison_v2_connected_exterior_route_test.gd"
func _init() -> void:
	route_label = "V2 LAUNDRY INPUT"

func _route() -> void:
	for point in [Vector3(3.8,0,-3.4),Vector3(3.8,0,-2.4),Vector3(3.8,-1.6,1.3),
			Vector3(2.3,-1.6,1.3),Vector3(2.3,-3.2,-3.5),Vector3(-1.75,-3.2,-3.4),Vector3(-1.75,-3.2,-1.5)]:
		if not await _walk(point): return
	var door: DoorProp = world.find_child("B1_LAUNDRY_DOOR_Leaf",true,false)
	if not await _walk(Vector3(-1.75,-3.2,-1.5)): return
	if not await _use(door,door.to_global(Vector3(door.width*.5,1.15,0)),"laundry_door"): return
	await get_tree().create_timer(.6).timeout
	for point in [Vector3(-3.4,-3.2,-1.5),Vector3(-3.2,-3.2,-2.4)]:
		if not await _walk(point): return
	var plate: Node3D = world.adapter.resolve("B1_LAUNDRY_SWITCH")
	var fixture: LightFixtureProp = world.adapter.resolve("B1_LAUNDRY_LT_FLUSH_DOME")
	player.set_lamp_enabled(false)
	for powered in [false,true]:
		if not await _use(plate,plate.global_position-plate.global_basis.z*.05,"laundry_switch_%s"%powered): return
		_require(fixture.powered==powered,"laundry switch controls its actual fixture")
	for point in [Vector3(-7,-3.2,-2.4),Vector3(-8.35,-3.2,-.15)]:
		if not await _walk(point): return
	var washer: WasherProp = world.adapter.resolve("B1_WASHER_01")
	var lid: Node3D = washer.get_node("LidReach")
	if not await _use(lid,washer.to_global(Vector3(.30,.91,-.38)),"washer_lid"): return
	await get_tree().create_timer(.4).timeout
	_require(washer._lid_open,"physical washer lid opens")
	for point in [Vector3(-7,-3.2,-.8),Vector3(-5.3,-3.2,1.6)]:
		if not await _walk(point): return
	var airer: LaundryAirerProp = world.adapter.resolve("B1_LAUNDRY_AIRER_01")
	var rope: Node3D = airer.get_node("AirerReach")
	if not await _use(rope,rope.get_child(0).global_position,"airer_rope"): return
	await get_tree().create_timer(.6).timeout
	_require(airer.is_airer_lowered(),"physical pulley control lowers the airer")
	for point in [Vector3(-4,-3.2,0),Vector3(-3.4,-3.2,-1.5),Vector3(-1.75,-3.2,-1.5)]:
		if not await _walk(point): return
