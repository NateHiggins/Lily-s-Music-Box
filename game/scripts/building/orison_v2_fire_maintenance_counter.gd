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
	# The original raised ledger occupies the middle of the worktop. Derive a
	# clear length from its retained furniture record instead of spawning stock
	# through it or disabling its collision. Start at the counter's south end;
	# the native bell and night-service card occupy the opposite end.
	var obstacles: Array[Vector2]=[]
	for floor: Dictionary in passage.source_layout.floors:
		if str(floor.id)!="F01":continue
		for row: Dictionary in floor.furniture:
			if not row.has("z0") or not row.has("rect"):continue
			if float(row.z0)<top or float(row.z0)>top+.30:continue
			var bounds: Array=row.rect
			if float(bounds[2])<=float(rect[0]) or float(bounds[0])>=float(rect[2]):continue
			if float(bounds[3])<=float(rect[1]) or float(bounds[1])>=float(rect[3]):continue
			obstacles.append(Vector2(maxf(float(bounds[1]),float(rect[1])),minf(float(bounds[3]),float(rect[3]))))
	obstacles.sort_custom(func(a: Vector2,b: Vector2):return a.x<b.x)
	var required: float=preload("res://scripts/building/fire_maintenance_counter.gd").COUNTER_LENGTH_M
	var start: float=float(rect[1])
	var length_at: float=INF
	for obstacle: Vector2 in obstacles:
		if obstacle.x-start>=required:length_at=(start+obstacle.x)*.5;break
		start=maxf(start,obstacle.y)
	if not is_finite(length_at) and float(rect[3])-start>=required:length_at=(start+float(rect[3]))*.5
	if not is_finite(length_at):return null
	var local:=Transform3D(Basis(Vector3.UP,PI*.5),GameBoot.b2g([
		(float(rect[0])+float(rect[2]))*.5,length_at,top]))
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
