extends "res://tests/orison_v2_radio_battery_test.gd"
## Receiving-owner transfer and ordinary cabinet input in the composed world.
## Chassis fit, power capacity and save/reconstruction are separate obligations.
var receiver_checks: Array[Dictionary] = []
var owned_nodes: Array[WeakRef] = []
var owned_resources: Array[WeakRef] = []
var owned_playbacks: Array[WeakRef] = []
var exercised := false
var original_graph: Dictionary = {}

func check(ok: bool, label: String) -> void:
	receiver_checks.append({"label":label,"ok":ok})
	super.check(ok,label)

func _run() -> void:
	var started := Time.get_ticks_msec()
	original_graph=AcousticGraphData.nodes.duplicate(true)
	await super._run()
	var nodes := _retained(owned_nodes)
	var resources := _retained(owned_resources)
	var playbacks := _retained(owned_playbacks)
	check(nodes==0 and resources==0 and playbacks==0,"teardown releases receiving owners, board worlds, owned screen/interaction resources and captured audio playbacks")
	check(AcousticGraphData.nodes==original_graph,"world teardown restores every original acoustic record without moving shared mouths twice")
	_write_receiving_contract(started,nodes,resources,playbacks)
	get_tree().quit(0 if failures.is_empty() else 1)

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var passage := world.passage_region
	var row: ArcadeRow = passage.receiving_row
	var catalog := ArcadeCatalog.load_catalog()
	var order := catalog.spread()
	var expected := {}
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/floor_01_cell_registry.json"))
	var source_order := 0
	for floor: Dictionary in passage.source_layout.floors:
		for record: Dictionary in floor.get("furniture",[]):
			if str(record.get("asm",""))!=ArcadeRow.ASM:continue
			if str(floor.id)=="F01" and str(record.get("batch","")) in passage.CELLS:
				expected[str(record.id)]={"record":record,"card":order[source_order%order.size()],
					"order":source_order,"floor_z":float(floor.z)}
			source_order+=1
	check(expected.size()==7 and row.cabinets.size()==expected.size(),"exactly the seven source passage chassis receive owners; bar and basement stay separate")
	var identities := {}
	for prop: ArcadeCabinetProp in row.cabinets:
		owned_nodes.append(weakref(prop));owned_nodes.append(weakref(prop.machine))
		owned_resources.append(weakref(prop._screen.mesh));owned_resources.append(weakref(prop._screen_mat))
		var identity := str(prop.get_meta("receiving_source_id",""))
		check(expected.has(identity) and not identities.has(identity),"unique source identity: "+identity)
		if not expected.has(identity):continue
		identities[identity]=true
		var spec: Dictionary=expected[identity];var record: Dictionary=spec.record;var at: Array=record.at
		check(prop.get_parent()==passage._actors and prop.name=="Arcade_"+identity,
			"persistent actor parent retains original receiver name: "+identity)
		check(prop.cabinet==spec.card and int(prop.get_meta("receiving_source_order"))==int(spec.order),
			"complete original catalogue order retains its programme: "+identity)
		check(prop.variant==int(record.get("variant",0))
			and prop.position.is_equal_approx(GameBoot.b2g([float(at[0]),float(at[1]),spec.floor_z+float(record.get("z0",0.))]))
			and is_equal_approx(prop.rotation.y,deg_to_rad(float(record.get("yaw",0)))+PI),
			"original variant, chassis datum and yaw are retained: "+identity)
		var source_cell: Dictionary=registry.cells.filter(func(cell):return str(cell.resource_path).get_file()==str(record.batch)+".gltf")[0]
		var nearest := "";var nearest_distance := 14.
		for marker_id: String in source_cell.semantic_owners:
			var marker_owner := passage._actors.get_node_or_null(marker_id) as FunctionalProp
			if marker_owner==null or not original_graph.has(marker_id):continue
			check(AcousticGraphData.node_pos(marker_id).is_equal_approx(marker_owner.global_position),
				"authored shop graph mouth occupies its actual registered fixture: "+marker_id)
			var original_record: Dictionary=original_graph[marker_id].duplicate(true)
			var registered_record: Dictionary=AcousticGraphData.nodes[marker_id].duplicate(true)
			original_record.erase("pos");registered_record.erase("pos")
			check(registered_record==original_record,
				"registered mouth retains original connections, delays, network and every non-placement field: "+marker_id)
			var distance := marker_owner.global_position.distance_to(prop.global_position)
			if distance<nearest_distance:nearest=marker_id;nearest_distance=distance
		check(not nearest.is_empty() and prop.graph_node_id==nearest,
			"receiver answers to its own authored shop's nearest actual fixture: "+identity)
		var areas := prop.find_children("PrimaryInteraction","Area3D",true,false)
		check(areas.size()==1 and areas[0].collision_layer==1 and areas[0].collision_mask==0,
			"ordinary interaction has one nonblocking physics area: "+identity)
		if areas.size()==1:owned_resources.append(weakref(areas[0].get_child(0).shape))
	var count_before := row.cabinets.size()
	check(not passage.receiving_row.mount(passage.source_layout,passage._actors,passage.CELLS)
		and row.cabinets.size()==count_before,"repeat mounting refuses duplicate receiving actors")
	var observations: Array=[]
	for receiver: ArcadeCabinetProp in row.cabinets:
		var feet := Vector3.ZERO;var found := false
		for distance: float in [1.35,1.60,1.90]:
			for side: float in [0.,-.28,.28,-.55,.55,-1.2,1.2]:
				var sample := receiver.to_global(Vector3(side,.03,-distance))
				if _city_clear_station(world,sample):feet=sample;found=true;break
			if found:break
		check(found,"source-derived standing observation exists in front of receiver: "+str(receiver.name))
		if not found:continue
		world.player.global_position=feet;world.player.velocity=Vector3.ZERO
		world.player.face_world_point(receiver._screen.global_position);world.player.set_lamp_enabled(true)
		await _settled_optics();await shot("receiver_"+str(receiver.name))
		observations.append({"id":str(receiver.name),"feet_world":[feet.x,feet.y,feet.z],
			"title":str(receiver.cabinet.title),"source_order":receiver.get_meta("receiving_source_order")})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("receiver_views.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","views":observations,"scope":"Source-derived floor/capsule observations of the seven receiving actors. No continuous entry route, sightline, chassis fit or human acceptance."},"\t"))
	var prop := passage._actors.get_node_or_null("Arcade_storm_shopcab_radio_service0") as ArcadeCabinetProp
	check(prop!=null,"Radio Service repair cabinet has one stateful receiving owner")
	if prop==null:return
	var cell: Node3D=passage.cell_nodes.shop_radio_service
	world.player.global_position=cell.to_global(Vector3(19.45,.03,57.5));world.player.velocity=Vector3.ZERO
	check(_city_clear_station(world,world.player.global_position),"retained floor and standing capsule face Radio Service receiver")
	world.player.face_world_point(prop._screen.global_position);world.player.set_lamp_enabled(true)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await _settled_optics()
	check(prop.machine.is_booted() and prop.machine.package!=null and not prop.machine._entities.is_empty()
		and prop.machine.own_world_3d,"nearby receiver boots its existing compiled programme in a separate physics world")
	check(prop._screen_mat.get_shader_parameter("feed")==prop.machine.scope_texture()
		and prop.machine._phosphor!=null and prop.machine.render_target_update_mode==SubViewport.UPDATE_ALWAYS,
		"visible circular scope uses the live accumulated phosphor feed")
	_track_board(prop)
	await shot("radio_receiving_scope")
	world.player._update_prompt()
	var ray := PhysicsRayQueryParameters3D.create(world.player.camera.global_position,
		world.player.camera.global_position-world.player.camera.global_basis.z*2.1,1,[world.player.get_rid()])
	ray.collide_with_areas=true
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	var hit_node: Node=hit.get("collider");var reached:=false
	while hit_node!=null:
		reached=reached or hit_node==prop;hit_node=hit_node.get_parent()
	check(reached and world.player._prompt.text.contains(str(prop.cabinet.title)),
		"actual standing player ray and prompt reach the assigned receiver")
	if not reached:return
	await _key_event(KEY_E)
	check(prop._playing() and world.player.call_locked and prop.machine.state==ArcadeMachine.State.PLAYING,
		"ordinary keyboard E enters the existing programme and locks the outer player")
	if not prop._playing():return
	_track_board(prop)
	await shot("radio_receiving_play")
	passage.residency._update_wanted(world.adapter.root.to_global(Vector3(1.925,0,-3.5)))
	check(passage.residency._wanted,"focused programme prevents retiring its playing parent under another camera")
	await _key_event(KEY_ESCAPE)
	check(not prop._playing() and not world.player.call_locked
		and prop.machine.state==ArcadeMachine.State.ATTRACT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,
		"ordinary Escape returns the same machine to attract and releases outer movement")
	await shot("radio_receiving_step_away")
	# Leave a second genuine keyboard session open. Normal world shutdown must
	# close the root-owned modal panel and release its board and player lock.
	await _key_event(KEY_E)
	check(prop._playing() and world.player.call_locked,"second keyboard session opens before teardown")
	var panel_ref: WeakRef = weakref(prop._panel_ui);owned_nodes.append(panel_ref)
	passage.receiving_row.shutdown()
	await get_tree().process_frame;await get_tree().process_frame
	check(panel_ref.get_ref()==null and not world.player.call_locked and not prop.machine.is_booted(),
		"receiving shutdown closes the root-owned panel, releases movement and unloads its programme")
	exercised=true

func _track_board(prop: ArcadeCabinetProp) -> void:
	for node in [prop.machine._world,prop.machine._enemy_container,prop.machine._environment,
		prop.machine._overlay,prop.machine._phosphor,prop.machine.player]:
		if node!=null:owned_nodes.append(weakref(node))
	for node in prop.machine.find_children("*","Node",true,false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			owned_nodes.append(weakref(node))
			if node.has_stream_playback():owned_playbacks.append(weakref(node.get_stream_playback()))

func _key_event(code: Key) -> void:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event)
	await get_tree().process_frame;await get_tree().process_frame
	event=InputEventKey.new();event.keycode=code;event.physical_keycode=code
	Input.parse_input_event(event)
	await get_tree().process_frame;await get_tree().process_frame

func _retained(refs: Array[WeakRef]) -> int:
	var count:=0
	for ref in refs:
		if ref.get_ref()!=null:count+=1
	return count

func _write_receiving_contract(started: int, nodes: int, resources: int, playbacks: int) -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head_output: Array=[];var digest_output: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head_output)==0,"contract records actual repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest_output)==0,
		"contract records the existing runtime-input digest")
	var path: String=get_script().resource_path
	var hash := HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(FileAccess.get_file_as_bytes(path))
	var passed := failures.is_empty() and exercised;var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Seven passage receiving owners, original catalogue/pose/graph, Radio Service keyboard play/exit, focused-parent protection and owned teardown. No chassis fit, power capacity, continuous entry route, save/reconstruction or broader completion acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":hash.finish().hex_encode(),
			"repository_head":str(head_output[0]).strip_edges() if not head_output.is_empty() else "",
			"runtime_inputs_sha256":str(digest_output[0]).strip_edges() if not digest_output.is_empty() else ""},
		"contracts":{"production_composition":{"executed":exercised,"status":status,"identities":["storm_shopcab_model_laundry0","storm_shopcab_photo_supplies0","storm_shopcab_radio_service0","storm_shopcab_pawnbroker0","storm_shopcab_news_cigars0","storm_shopcab_luncheonette0","storm_shopcab_luncheonette1"]},
			"premature_action_denial":{"executed":exercised,"status":status,"scope":"Duplicate mounting and focused-parent retirement"},
			"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},
			"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":nodes,
				"retained_resources":resources,"retained_playbacks":playbacks,"resource_scope":"Receiving-owned screen meshes/materials, primary interaction shapes and captured board audio playbacks; imported caches excluded"}},
		"checks":receiver_checks,"failures":failures}
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("PASSAGE RECEIVING CONTRACT: ",status," checks=",receiver_checks.size()," retained_nodes=",nodes," retained_resources=",resources," retained_playbacks=",playbacks)
