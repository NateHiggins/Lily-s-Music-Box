extends "res://tests/orison_v2_roof_route_test.gd"
## Six explicit hall starts; every subsequent leg uses ordinary controller input.
## Preserve the Bible's awake/unlocked start. No quest progression claim.
var observations: Array[Dictionary] = []
var privacy_hits: Array[Dictionary] = []
var completed_units: Array[String] = []
var owned_refs: Array[WeakRef] = []
var started := 0
var surface_checks := 0

func _init() -> void:
	route_label = "UPPER ENTRY STORAGE"

func _require(ok: bool, label: String) -> bool:
	observations.append({"label":label,"ok":ok})
	return super._require(ok,label)

func _run() -> void:
	started = Time.get_ticks_msec()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	if _require(not world.startup_failed,"full production composition starts"):
		player = world.player
		player.camera.make_current()
		var carrier := player.carried_device as ServiceSetCarrier
		if carrier != null: carrier.set_capture_hidden(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await _route()
		_qualify_moved_surfaces()
	Input.action_release("move_forward")
	Input.action_release("interact")
	owned_refs.append(weakref(world))
	if player != null: owned_refs.append(weakref(player))
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().process_frame
	var retained := 0
	for ref: WeakRef in owned_refs:
		if ref.get_ref()!=null:retained+=1
	_require(retained==0,"world, player and exercised leaves/storage retire")
	_write_contract(retained)
	print("UPPER ENTRY STORAGE: %d checks / %d waypoints / %d units / %d failures" % [observations.size(),trace.size(),completed_units.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() and completed_units.size()==6 else 1)

func _route() -> void:
	for unit: String in ["5A","5B","5C","6A","6B","6C"]:
		await _unit(unit)

func _unit(unit: String) -> bool:
	var y := float(int(unit[0])-1)*3.2
	var prefix := "F0"+unit[0]+"_"+unit[1]+"_"
	var entry_id := "F0"+unit[0]+"_DOOR_"+ ("02" if unit[1]=="A" else "03" if unit[1]=="B" else "06")
	var entry := _leaf(entry_id)
	if not _require(entry!=null and entry.unit==unit and entry.door_kind=="apartment_entry","original apartment threshold: "+unit):return false
	owned_refs.append(weakref(entry))
	var original_state := entry.leaf_state
	var start := Vector3(-.85,y+.02,2.65) if unit[1]=="C" else Vector3(-7.1,y+.02,0)
	player.global_position=world.adapter.root.to_global(start)
	player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	if not _require(not entry.open and original_state=="closed","Bible awake entry starts closed and unlocked: "+unit):return false
	if not await _open_door(entry_id):return false
	if not _privacy(unit,start,entry):return false
	var points: Array[Vector3]
	if unit[1]=="A":points=[Vector3(-7.1,y,-1.65),Vector3(-7.1,y,-2.2),Vector3(-9.1,y,-2.2),Vector3(-9.1,y,-5),Vector3(-7.1,y,-5),Vector3(-9.1,y,-5),Vector3(-9.1,y,-2.2),Vector3(-7.1,y,-2.2),Vector3(-7.1,y,-1.65)]
	elif unit[1]=="B":points=[Vector3(-7.1,y,2.0),Vector3(-7.9,y,2.0),Vector3(-7.9,y,1.85),Vector3(-8.4,y,1.85),Vector3(-10.1,y,1.85),Vector3(-8.4,y,1.85),Vector3(-7.9,y,1.85)]
	else:points=[Vector3(-.85,y,5.2),Vector3(-.85,y,7.1),Vector3(2.1,y,7.1),Vector3(-.85,y,7.1)]
	for point: Vector3 in points:
		if not await _walk(point):return false
		if unit[1]=="A" and point.is_equal_approx(Vector3(-9.1,y,-2.2)):
			await _roof_capture(unit+"_vestibule_distribution",Vector3(-6.1,y+1.25,-1.85))
		elif unit[1]=="B" and point.is_equal_approx(Vector3(-10.1,y,1.85)):
			await _roof_capture(unit+"_vestibule_distribution",Vector3(-6.72,y+1.1,2.65))
	if unit[1]=="C":await _roof_capture(unit+"_vestibule_distribution",Vector3(-.85,y+1.25,5.2))
	if unit[1]=="B":
		var bath_id:=prefix+"VESTIBULE_BATH_DOOR"
		if not await _open_door(bath_id):return false
		if not await _walk(Vector3(-7.9,y,4.2)):return false
		if not await _walk(Vector3(-7.9,y,1.85)):return false
		if not await _close_door(bath_id):return false
	elif unit=="5C":
		if not await _walk(Vector3(2.1,y,7.1)):return false
		if not await _open_door(prefix+"PRIVATE_HALL_BED1_DOOR"):return false
		for point in [Vector3(2.1,y,8.6),Vector3(2.5,y,8.6),Vector3(2.5,y,10.1)]:
			if not await _walk(point):return false
			if point.is_equal_approx(Vector3(2.5,y,8.6)):
				await _roof_capture("5C_bedroom_storage",Vector3(1.7,y+.75,10.1))
		if not await _wardrobe("5C_w0_wardrobe"):return false
		for point in [Vector3(2.5,y,8.6),Vector3(2.1,y,8.6),Vector3(2.1,y,7.1)]:
			if not await _walk(point):return false
		if not await _close_door(prefix+"PRIVATE_HALL_BED1_DOOR"):return false
		if not await _walk(Vector3(-.85,y,7.1)):return false
	elif unit=="6C":
		for point in [Vector3(-4,y,7.1),Vector3(-4,y,5.65),Vector3(-4.7,y,5.65)]:
			if not await _walk(point):return false
		if not await _wardrobe("6C_w0_wardrobe"):return false
		for point in [Vector3(-4,y,5.65),Vector3(-3.05,y,5.65)]:
			if not await _walk(point):return false
		if not await _wardrobe("6C_w1_wardrobe"):return false
		for point in [Vector3(-4,y,5.65),Vector3(-4,y,7.1),Vector3(-.85,y,7.1)]:
			if not await _walk(point):return false
	if unit[1]=="A":
		if not await _walk(Vector3(-7.1,y,0)):return false
	elif unit[1]=="B":
		for point in [Vector3(-7.9,y,2.0),Vector3(-7.1,y,2.0),Vector3(-7.1,y,0)]:
			if not await _walk(point):return false
	else:
		for point in [Vector3(-.85,y,5.2),Vector3(-.85,y,2.65)]:
			if not await _walk(point):return false
	if not await _close_door(entry_id):return false
	entry.leaf_state=original_state
	if not _require(not entry.open and entry.leaf_state==original_state,"awake entry state restored: "+unit):return false
	completed_units.append(unit)
	return true

func _privacy(unit: String, hall: Vector3, entry: DoorProp) -> bool:
	var prefix := "F0"+unit[0]+"_"+unit[1]+"_"
	var targets: Array[Dictionary] = []
	for space: Dictionary in world.layout.spaces:
		if str(space.id) in [prefix+"BATH",prefix+"BED",prefix+"ALCOVE",prefix+"BED1"]:targets.append(space)
	var ok := _require(targets.size()==2,"bed and sanitary privacy targets: "+unit)
	for target: Dictionary in targets:
		var rect: Array=target.rect
		for hallway_shift: float in [-.35,0,.35]:
			for room_shift: float in [-.5,0,.5]:
				var from:=hall+Vector3(hallway_shift,1.41,0)
				var to:=Vector3((float(rect[0])+float(rect[2]))*.5+room_shift,hall.y+1.41,(float(rect[1])+float(rect[3]))*.5)
				var query:=PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(from),world.adapter.root.to_global(to),1,[player.get_rid(),entry._body.get_rid()])
				var hit: Dictionary = {}
				var architecture:=false
				var ignored_props: Array[String] = []
				# Props may obscure the first hit, but cannot supply architectural privacy.
				# Continue the same ray through their RIDs without altering the world.
				for layer in 64:
					hit=world.get_world_3d().direct_space_state.intersect_ray(query)
					if hit.is_empty():break
					var collider:=hit.get("collider") as CollisionObject3D
					var node: Node=collider
					while node!=null and node!=world:
						if node is DoorProp and node!=entry:architecture=true
						if node is MeshInstance3D and str(node.name).begins_with("Wall"):architecture=true
						node=node.get_parent()
					if architecture or collider==null:break
					ignored_props.append(str(collider.get_path()))
					var exclusions:=query.exclude;exclusions.append(collider.get_rid());query.exclude=exclusions
				privacy_hits.append({"unit":unit,"target":target.id,"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z],"collider":str(hit.get("collider").get_path()) if not hit.is_empty() else "","architecture":architecture,"ignored_prop_colliders":ignored_props})
				ok=_require(architecture,"open entry retains actual wall/door privacy: "+unit+"/"+str(target.id)+"/"+str(hallway_shift)+"/"+str(room_shift)) and ok
	return ok

func _wardrobe(identity: String) -> bool:
	var body := world.adapter.resolve(identity) as BakedFurnitureInteraction
	if not _require(body!=null and bool(body.get("native_ready")) and not body._wardrobe_open,"native clothing storage starts closed: "+identity):return false
	owned_refs.append(weakref(body))
	if not await _use(body,body.to_global(Vector3(0,1.1,-.30)),identity+"_open"):return false
	await get_tree().create_timer(.55).timeout
	if not _require(body._wardrobe_open,"player E opens native storage: "+identity):return false
	await _roof_capture(identity+"_open_storage",body.position+Vector3(0,1.0,0))
	if not await _use(body,body.to_global(Vector3(0,1.1,.28)),identity+"_close"):return false
	await get_tree().create_timer(.55).timeout
	return _require(not body._wardrobe_open,"player E restores storage leaves: "+identity)

func _qualify_moved_surfaces() -> void:
	var qualifier := preload("res://tests/orison_v2_apartment_batch_test.gd").new()
	# Do not add this helper to the tree: its standalone _ready builds another world.
	for identity: String in ["5B_hallstand","6B_hallstand"]:
		var body := world.adapter.resolve(identity) as Node3D
		_require(body!=null,"moved native installation resolves: "+identity)
		if body==null:continue
		var visible := 0
		for draw: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			if draw.mesh==null:continue
			visible+=1
			qualifier._check_draw_finish(draw,identity+"/"+str(draw.name))
		_require(visible>0,"moved installation retains visible native partitions: "+identity)
	surface_checks=qualifier.checks
	for failure: String in qualifier.failures:_require(false,"moved finish: "+failure)
	_require(qualifier.failures.is_empty(),"moved native UV/PBR/loaded-mip checks: "+str(surface_checks))
	qualifier.free()

func _write_contract(retained: int) -> void:
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[];var digest: Array=[]
	_require(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository identity")
	_require(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"record runtime input digest")
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_string(get_script().resource_path).replace("\r\n","\n").to_utf8_buffer())
	var dependencies := {}
	for path: String in ["game/tests/orison_v2_roof_route_test.gd","game/tests/orison_v2_4b_door_route_test.gd","game/tests/orison_v2_connected_exterior_route_test.gd","game/tests/orison_v2_vertical_route_test.gd","game/tests/orison_v2_apartment_batch_test.gd"]:
		var binding:=HashingContext.new();binding.start(HashingContext.HASH_SHA256);binding.update(FileAccess.get_file_as_string("res://"+path.trim_prefix("game/")).replace("\r\n","\n").to_utf8_buffer());dependencies[path]=binding.finish().hex_encode()
	var passed:=failures.is_empty() and completed_units.size()==6
	var status:="PASS" if passed else "FAIL"
	var receipt:={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Six explicitly placed upper hall starts; subsequent entry/distribution/storage legs use production movement and E input. Canonical awake entry states restored. Architectural sightlines with interior privacy leaves closed and entry open. No quest unlocking, NPC behavior, whole-building navigation or extra capsule margin acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/tests/orison_v2_upper_entry_storage_test.gd","test_sha256":hash.finish().hex_encode(),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else "","test_dependency_sha256":dependencies,"test_dependency_normalization":"LF"},
		"contracts":{"upper_entry_distribution":{"executed":true,"status":status,"identities":completed_units},"architectural_privacy":{"executed":not privacy_hits.is_empty(),"status":status},"clothing_storage":{"executed":completed_units.has("5C") and completed_units.has("6C"),"status":status},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","tracked_nodes":owned_refs.size(),"retained_nodes":retained}},
		"moved_surface_checks":surface_checks,"checks":observations,"failures":failures,"trace":trace,"privacy_hits":privacy_hits}
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty():directory=root.path_join("tmp/v2-upper-entry-storage-20261011/runtime")
	DirAccess.make_dir_recursive_absolute(directory)
	var file:=FileAccess.open(directory.path_join("upper_entry_storage_contract.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(receipt,"\t"));file.flush()
