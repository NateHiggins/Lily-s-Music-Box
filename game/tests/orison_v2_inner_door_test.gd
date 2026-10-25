extends "res://tests/orison_v2_public_doors_test.gd"
## The entry vestibule's inner doorway is unhung: no leaf and nothing in the
## aperture, finished casings and the empty jamb butts, both real approaches.
func _init() -> void: route_label="ENTRY VESTIBULE DOORWAY"

func _route() -> void:
	var anchor:=world.adapter.resolve("F01_INNER_DOOR") as Node3D
	if anchor==null or anchor.has_node("Hinge") or anchor.has_node("F01_INNER_DOOR_Leaf"):
		failures.append("vestibule doorway still hangs a leaf");return
	if not anchor.has_node("DoorCasings") or not anchor.has_node("DoorLinings") or not anchor.has_node("EmptyButts"):
		failures.append("unhung doorway lacks casings, linings or its empty butts");return
	# Nothing may stand in the declared clear aperture, through the wall depth.
	var probe:=BoxShape3D.new();probe.size=Vector3(1.0,2.0,0.4)
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=probe;query.transform=anchor.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.05,0))
	query.collision_mask=1;query.exclude=[player.get_rid()]
	var contacts:=world.get_world_3d().direct_space_state.intersect_shape(query,4)
	if not contacts.is_empty():
		failures.append("vestibule aperture is obstructed by "+str(contacts[0].collider.get_path()));return
	var vestibule: Node=world.adapter.root.get_node_or_null("EntryVestibule")
	for part in ["Directory","EstablishedPlaque","NoticeHum","NoticeHouse","SignalPoint","Radiator","CoatHooks","DoorMat","F01_ENTRANCE_GAS_LANTERN","F01_VESTIBULE_GAS_BRACKET","GasSupply"]:
		if vestibule==null or vestibule.get_node_or_null(part)==null:
			failures.append("entry vestibule lacks "+part);return
	for side: float in [1.0,-1.0]:
		if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,side*1.15)))):return
		if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,-side*1.15)))):return
		await _capture("vestibule_doorway_"+str(side))
	print("ENTRY VESTIBULE: unhung doorway clear through the wall, cased, butts retained, both approaches walked, dress present")
