extends RefCounted
## Resolve the retained hardware counter once. Local stock layout belongs to
## the native kit; its world placement remains the original furniture anchor.
static func mount(world: Node3D, economy: Node, stations: Dictionary) -> Node3D:
	var passage: OrisonV2PassageRegion=world.passage_region
	var service: MaintenanceShopService=world.shop_service
	if passage==null or service==null or not service.has_method("transact"):return null
	var source: Dictionary={}
	var anchor:=str(service.stock_record("fire_hose_rubber_protectant").get("counter_anchor_id",""))
	for floor: Dictionary in passage.source_layout.floors:
		if str(floor.id)!="F01":continue
		for row: Dictionary in floor.furniture:
			if str(row.id)==anchor:
				if not source.is_empty():return null
				source=row
	if source.is_empty():return null
	var rect: Array=source.rect
	if float(rect[2])-float(rect[0])<.50 or float(rect[3])-float(rect[1])<1.20:return null
	var top: float=float(source.z0)+float(source.h)
	var local:=Transform3D(Basis(Vector3.UP,PI*.5),GameBoot.b2g([
		(float(rect[0])+float(rect[2]))*.5,(float(rect[1])+float(rect[3]))*.5,top]))
	var clearing:=preload("res://scripts/game/radio_clearing_network.gd").new()
	if not clearing.configure(economy,world.service_set_carrier.radio_is_powered,
		func(shop_id: String):return passage.transaction_counter_available(shop_id)):return null
	service.clearing=clearing
	var kit:=preload("res://scripts/building/fire_maintenance_counter.gd").new()
	kit.name="FireMaintenanceCounter";world.add_child(kit)
	kit.global_transform=passage.global_transform*local
	if not kit.configure(service,passage.transaction_actor_root()):kit.free();return null
	if not kit.bind_residency(passage):kit.free();return null
	for reference: WeakRef in stations.values():kit.fire_stations.append(reference)
	return kit
