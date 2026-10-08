extends "res://tests/orison_v2_domestic_native_test.gd"
## Native visual payloads exercised through the unchanged bar owners.
var retained: Array[WeakRef] = []
var contract_started := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started = Time.get_ticks_msec()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_instruments.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"native bar export bound")
	var factory: RefCounted = world.adapter.root.get_meta("v2_native_bar_instruments")
	check(factory.errors.is_empty() and factory.installed.size()==4,"four original bar actors receive native geometry")
	for identity: String in factory.installed:
		var entry: Dictionary = factory.installed[identity]
		var actor: Node3D = entry.actor.get_ref()
		retained.append(weakref(actor))
		check(actor.get_script().resource_path==entry.script,"bar actor retains original authority")
		check(actor.find_children("*","Area3D",true,false).map(func(n):return n.get_instance_id())==entry.areas,"bar actor retains exactly its original reach areas")
		actor.set_process(false)
		for original: Dictionary in entry.source:
			var draw: MeshInstance3D = original.draw.get_ref()
			check(draw.get_parent().get_instance_id()==original.parent and draw.transform.is_equal_approx(original.transform),"bar mesh owner and motion frame retained")
			if original.preserve_material: check(draw.material_override==original.material,"source material owner retained")
			check(draw.mesh is ArrayMesh,"bar primitive replaced by native stock")
			_check_cap_mapping(draw.mesh,true)
		if actor is SpeakerProp:
			var speaker := actor as SpeakerProp
			var emitter := speaker._thump
			retained.append(weakref(emitter))
			var stream := emitter.stream
			speaker._perform_synced_event(0,.7,3.)
			check(emitter.playing and emitter.stream==stream and emitter.get_parent()==speaker,"retained speaker emitter plays the original Conductor event")
			emitter.stop()
			for x in [-.115,.115]:
				var at := speaker.to_global(Vector3(x,-.05,-.54))
				var normal := speaker.global_basis.z
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.004,at-normal*.004,1))
				check(not hit.is_empty() and hit.position.distance_to(at)<.0002 and hit.normal.dot(normal)>.99,"speaker bracket meets the actual retained south wall")
	world.first_shift_director.ritual_phase()
	var saved := var_to_bytes(RealityState.data)
	var recorder := world.find_child("F01_BAR_SONGBOOK",true,false) as SongbookTerminalProp
	for x in [-.26,.26]:
		var at:=recorder.to_global(Vector3(x,-.08,-.10))
		var normal:=recorder.global_basis.z
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.004,at-normal*.004,1))
		check(not hit.is_empty() and hit.position.distance_to(at)<.0002 and hit.normal.dot(normal)>.99,"recording apparatus shelf bears on the actual west wall")
	var cylinder_pose := recorder._cylinder.transform
	var crank_pose := recorder._crank_hub.transform
	var arm_pose := recorder._crank_arm.transform
	var knob_pose := recorder._crank_knob.transform
	var clock_before := recorder._t
	var hum := recorder._hum
	var hum_stream := hum.stream
	recorder.interact(world.player)
	check(is_instance_valid(recorder._panel) and world.player.call_locked,"recording apparatus opens its original Songbook panel")
	var panel := recorder._panel
	retained.append(weakref(panel))
	recorder.interact(world.player)
	check(recorder._panel==panel,"repeated interaction retains a single Songbook panel")
	recorder._process(.25)
	check(not recorder._cylinder.transform.is_equal_approx(cylinder_pose) and not recorder._crank_hub.transform.is_equal_approx(crank_pose),"native recording cylinder and crank follow original movement axes")
	check(recorder._hum==hum and hum.stream==hum_stream,"recording horn retains its original ambience owner")
	panel.close()
	await get_tree().process_frame
	check(recorder._panel==null and not world.player.call_locked,"Songbook cancellation releases the original player lock")
	recorder._cylinder.transform=cylinder_pose
	recorder._crank_hub.transform=crank_pose
	recorder._crank_arm.transform=arm_pose
	recorder._crank_knob.transform=knob_pose
	recorder._t=clock_before
	var darts := world.find_child("F01_BAR_DARTS",true,false) as DartsProp
	darts.interact(world.player)
	check(is_instance_valid(darts._panel) and world.player.call_locked,"native darts open the original Rainbow Round")
	var darts_panel := darts._panel
	retained.append(weakref(darts_panel))
	darts.interact(world.player)
	check(darts._panel==darts_panel,"repeated darts interaction retains one scoring owner")
	darts_panel.close()
	await get_tree().process_frame
	check(darts._panel==null and not world.player.call_locked,"Rainbow Round cancellation releases the original player lock")
	check(var_to_bytes(RealityState.data)==saved,"bar visual replacement and cancelled panels write no saved fact")
	if capture_enabled:
		for identity: String in factory.installed:
			var actor: Node3D = factory.installed[identity].actor.get_ref()
			var local := world.bar_region.to_local(actor.to_global(Vector3(.25,0,1.1)))
			local.y=-2.55 if actor is SpeakerProp and identity.ends_with("1") else -2.77
			var target := world.bar_region.to_local(actor.to_global(Vector3(0,.27,0)))
			await _city_inspect(world,world.bar_region,local,target,identity+"_native","bar",identity)
	return {"checks":checks,"failures":failures,"views":discovery.duplicate(true)}

func validate_after_teardown() -> Dictionary:
	for ref in retained: check(ref.get_ref()==null,"bar actor, audio and panel retire with production world")
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[];var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"contract records repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"contract records runtime digest")
	var passed := failures.is_empty()
	var status := "PASS" if passed else "FAIL"
	var path: String=get_script().resource_path
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Four original Harukiya actors: native geometry, source motion frames, speaker Conductor event, Songbook and Rainbow Round panel cancellation, saved-state stability and retirement. No microphone capture, take publication, PA DSP change, played darts round or save reconstruction is exercised.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-contract_started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},"premature_action_denial":{"executed":false,"status":"NOT_EXECUTED"},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained.filter(func(r):return r.get_ref()!=null).size()}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("bar_instruments/runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	return {"checks":checks,"failures":failures}
