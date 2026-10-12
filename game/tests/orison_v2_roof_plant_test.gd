extends "res://tests/orison_v2_roof_route_test.gd"
## Existing played circuit plus two new physical, independently switched lamps.
var public_checked := false
var service_checked := false

func _init() -> void:
	route_label = "ROOF PLANT"

func _prepare_player_start() -> void:
	super._prepare_player_start()
	player.set_lamp_enabled(false)
	var supply: RefCounted = world.adapter.root.get_meta("v2_native_roof_lighting_supply", null)
	if not _require(supply != null and supply.errors.is_empty() and supply.installed.size() == 53,
		"complete native roof supply is installed"): return
	var electrical: RefCounted = world.adapter.root.get_meta("v2_native_electrical_service", null)
	var caps := 0
	for draw: MeshInstance3D in electrical.installed:
		if draw.get_meta("native_electrical_part", "") == "ConduitCap": caps += 1
	_require(caps == 1, "superseded upper cap retired; original lower cap retained")
	for x in [5.4, 9.5]:
		var ray := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(Vector3(x-.09,21.9,1)), world.adapter.root.to_global(Vector3(x+.09,21.9,1)),1)
		for draw: MeshInstance3D in supply.installed:
			for child in draw.get_children():
				if child is StaticBody3D: ray.exclude.append(child.get_rid())
		_require(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "actual bulkhead bore is clear at " + str(x))

func _open_door(identity: String) -> bool:
	if identity=="ROOF_PUBLIC_DOOR" and not public_checked:
		if not await _walk(Vector3(-1.1,19.2,.8)):return false
		if not await _switch_lamp("ROOF_PUBLIC_PLANT_SWITCH","ROOF_PUBLIC_PLANT_LT","ROOF_SERVICE_PLANT_LT","public"):return false
		if not await _walk(Vector3(-1.35,19.2,0)):return false
		public_checked=true
	return await super._open_door(identity)

func _close_door(identity: String) -> bool:
	if identity=="ROOF_SERVICE_DOOR" and not service_checked:
		for point in [Vector3(10.3,19.2,3),Vector3(10.3,19.2,4)]:
			if not await _walk(point):return false
		if not await _switch_lamp("ROOF_SERVICE_PLANT_SWITCH","ROOF_SERVICE_PLANT_LT","ROOF_PUBLIC_PLANT_LT","service"):return false
		for point in [Vector3(10.3,19.2,3),Vector3(8.1,19.2,3)]:
			if not await _walk(point):return false
		await _roof_capture("roof_supply_bridge", Vector3(7.45,21.9,1))
		service_checked=true
	return await super._close_door(identity)

func _switch_lamp(switch_id: String,lamp_id: String,other_id: String,label: String) -> bool:
	var plate := world.adapter.resolve(switch_id) as StaticBody3D
	var lamp := world.adapter.resolve(lamp_id) as LightFixtureProp
	var other := world.adapter.resolve(other_id) as LightFixtureProp
	if not _require(plate!=null and lamp!=null and other!=null,"source-owned roof lamps and switch exist"):return false
	if not _require(lamp.get_meta("v2_native_fixed_light_variant","")=="cage_bulb_rise300","accepted native cage stock is installed"):return false
	var initial: bool=lamp.powered
	var other_initial: bool=other.powered
	var light_identity: int=lamp.light.get_instance_id()
	for iteration in 2:
		if not await _use(plate,plate.global_position,"roof_"+label+"_switch"+str(iteration)):return false
		if not _require(lamp.powered== (not initial if iteration==0 else initial) and other.powered==other_initial,
			"ordinary E toggles only its own roof circuit"):return false
		await get_tree().create_timer(.6).timeout
		if lamp.powered:
			if not _require(lamp.light.light_energy>.01 and lamp.light.get_instance_id()==light_identity,
				"original light owner supplies the visible task illumination"):return false
			await _roof_capture("roof_"+label+"_task_lamp",world.adapter.root.to_local(lamp.global_position))
	return true
