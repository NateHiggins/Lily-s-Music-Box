extends "res://tests/orison_v2_domestic_native_test.gd"
## Retained sign identities, original state owners and assembled frontage QA.
var retained: Array[WeakRef]=[]
var bearings: Array=[]
var contract_started := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started=Time.get_ticks_msec()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_signage.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"native signage export bound")
	var factory: RefCounted=world.adapter.root.get_meta("v2_native_signage")
	check(factory.errors.is_empty() and factory.installed.size()==3,"exactly three original sign owners fitted")
	for identity: String in factory.installed:
		var entry: Dictionary=factory.installed[identity]
		var source: Dictionary=factory.retained[identity]
		var actor: Node3D=entry.actor.get_ref();retained.append(weakref(actor))
		check(actor.global_transform.is_equal_approx(source.pose),"sign span anchor and pose retained")
		check(actor.get_script().resource_path==entry.script,"original sign authority retained")
		check(actor.find_children("*","Area3D",true,false).map(func(n):return n.get_instance_id())==entry.areas,"original sign inspection areas retained")
		actor.set_process(false)
		var changed := []
		for original: Dictionary in entry.source:
			var draw: MeshInstance3D=original.draw.get_ref();changed.append(draw)
			check(draw.get_parent().get_instance_id()==original.parent and draw.transform.is_equal_approx(original.transform),"source node and moving parent retained")
			if original.preserve_material:check(draw.material_override==original.material,"original emissive/material owner retained")
			check(draw.mesh is ArrayMesh,"native fabricated payload mounted")
			_check_cap_mapping(draw.mesh,true)
		for draw: Dictionary in source.draws:
			var node: MeshInstance3D=draw.node.get_ref()
			if node not in changed:check(node.mesh==draw.mesh and node.transform.is_equal_approx(draw.pose),"retained glyph, tube, bulb or hardware payload is exact")
		for label: Dictionary in source.labels:
			var node: Label3D=label.node.get_ref()
			check(node.text==label.text and node.transform.is_equal_approx(label.pose),"all original scene wording and text placement retained")
		for light: Dictionary in source.lights:
			var node: Light3D=light.node.get_ref()
			check(node.transform.is_equal_approx(light.pose) and node.light_color==light.color,"original practical-light owner, position and colour retained")
	world.first_shift_director.ritual_phase()
	var saved := var_to_bytes(RealityState.data)
	var bar := factory.installed.F01_BAR_SIGNAGE.actor.get_ref() as HarukiyaSignageProp
	var previous := bar._bar_state
	var lantern_material := bar._lantern_mat
	for state in [0,1,2]:
		bar.set_bar_state(state)
		check(bar._lantern_mat==lantern_material and is_equal_approx(lantern_material.emission_energy_multiplier,1.7 if state==0 else 0.),"original lantern material responds to bar hours")
		check(bar._lantern_pivot.visible==(state!=2),"closed bar takes in the entire native lantern")
		check(bar._spots.all(func(n):return n.visible==(state==0)),"original board lamps follow original hours")
		check(bar.service_wire_card()==bar.interact(world.player),"original frontage observation remains authoritative")
		if capture_enabled:await _front_view(world,bar,Vector2(.0,1.7),Vector3(0,-.2,0),"harukiya_state_"+str(state))
	bar.set_bar_state(previous)
	for at: Vector3 in [Vector3(-1.075,0,-.04),Vector3(1.075,0,-.04),Vector3(1.42,.32,-.06)]:_bearing(world,bar,at)
	var bodega := factory.installed.FittedBodegaSignage.actor.get_ref() as BodegaSignageProp
	var service: Dictionary=fixture.bodega_service
	var power := world.get_node("BodegaPower") as Node3D
	var offset := _v(service.sign_offset)
	var supply := _v(service.existing_front_junction)
	var port_y: float=float(fixture.bodega_service_port.center[1])-offset.y
	check(bodega.global_basis.is_equal_approx(power.global_basis) and bodega.global_position.distance_to(power.to_global(offset))<.0001,"new branch uses existing independent bodega supply frame")
	check(power.get("startup_failed")==false,"existing independent bodega electrical fabric remains valid")
	var clear := true
	for dx in [-.009,.009]:
		for dy in [-.009,.009]:
			var from := bodega.to_global(Vector3(supply.x+dx,port_y+dy,-.30))
			var to := bodega.to_global(Vector3(supply.x+dx,port_y+dy,.12))
			clear=clear and world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1)).is_empty()
	check(clear,"sign conduit passes through fabricated timber-header aperture below retained masonry")
	for z in [-1.5,-.7]:
		var at := bodega.to_global(Vector3(supply.x,.53,z))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at-Vector3.UP*.10,at+Vector3.UP*.10,1))
		check(not hit.is_empty() and at.distance_to(hit.position)<.001,"internal conduit hangers bear on existing shop ceiling")
	var previous_time := bodega._time
	var saw_drop := false
	for time in range(1000):
		bodega._time=float(time)*.1;bodega._process(0.)
		if bodega._cabinet_dropped:saw_drop=true;break
	check(saw_drop and bodega._cabinet_mats.all(func(m):return is_equal_approx(m.emission_energy_multiplier,.2625)),"both original blade faces retain source dropout")
	if capture_enabled:await _front_view(world,bodega,Vector2(1.,4.5),Vector3(0,-.32,.6),"bodega_dropout")
	bodega._time=100.;bodega._process(0.)
	check(not bodega._cabinet_dropped,"original bodega cabinet recovers")
	if capture_enabled:await _front_view(world,bodega,Vector2(-2.,4.5),Vector3(-.7,.05,.6),"bodega_lit")
	bodega._time=previous_time;bodega._process(0.)
	if capture_enabled:await _front_view(world,bodega,Vector2(1.5,-1.4),Vector3(1.6875,.20,-.10),"bodega_inside_service")
	if capture_enabled:await _front_view(world,bar,Vector2(0.,-1.5),Vector3(.85,-.3,.1),"harukiya_inside_approach")
	for at: Vector3 in [Vector3(-2.05,.88,.07),Vector3(-2.175,-.32,.06),Vector3(2.175,-.32,.06)]:_bearing(world,bodega,at)
	var neon := factory.installed.F01_NEON_BLADE.actor.get_ref() as NeonSignProp
	var was_lit := neon._lit
	var tube_material := neon._tube_mat
	for lit: bool in [false,true]:
		neon.set_lit(lit)
		for tick in 20:neon._process(.1)
		check(neon._tube_mat==tube_material and (tube_material.emission_energy_multiplier>.8 if lit else tube_material.emission_energy_multiplier<.04),"original neon circuit controls original tubes")
		if capture_enabled:await _front_view(world,neon,Vector2(3.,6.),Vector3(0,-.7,.4),"orison_"+("lit" if lit else "dark"))
	neon.set_lit(was_lit)
	for y in [-2.4825,2.4825,-1.9325,1.9325]:_bearing(world,neon,Vector3(0,y,.0005))
	check(var_to_bytes(RealityState.data)==saved,"signage state exercise creates no persistent facts")
	var path := OS.get_environment("SHOT_DIR")
	FileAccess.open(path.path_join("bearings.json"),FileAccess.WRITE).store_string(JSON.stringify(bearings,"\t"))
	return {"checks":checks,"failures":failures,"views":discovery.duplicate(true)}

func _bearing(world: OrisonV2RuntimeRoot,actor: Node3D,at: Vector3) -> void:
	var from := actor.to_global(at+Vector3(0,0,.30));var to := actor.to_global(at-Vector3(0,0,2.))
	var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
	var actual: Vector3=actor.to_local(hit.position) if not hit.is_empty() else Vector3.INF
	bearings.append({"actor":str(actor.name),"requested":[at.x,at.y,at.z],"actual":[actual.x,actual.y,actual.z]})
	check(not hit.is_empty() and actual.distance_to(at)<.001,"sign backing bears on assembled frontage: "+str(actor.name)+" "+str(at))

func _front_view(world: OrisonV2RuntimeRoot,actor: Node3D,offset: Vector2,target: Vector3,label: String) -> void:
	var found := false
	for dx in [0.,.6,-.6,1.2,-1.2]:
		var column := actor.to_global(Vector3(offset.x+dx,0,offset.y))
		var top := Vector3(column.x,world.adapter.root.global_position.y+1.8,column.z)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*6.,1,[world.player.get_rid()]))
		if hit.is_empty():continue
		var feet: Vector3=hit.position+Vector3.UP*.03
		if not _city_clear_station(world,feet):continue
		world.player.global_position=feet;world.player.velocity=Vector3.ZERO;world.player.face_world_point(actor.to_global(target))
		await _settled_optics();await shot(label)
		discovery.append({"id":label,"feet":[feet.x,feet.y,feet.z],"image":label+".png","status":"standing_station_pending_visual_review"});found=true;break
	check(found,"clear pavement standing station: "+label)

func validate_after_teardown() -> Dictionary:
	for ref in retained:check(ref.get_ref()==null,"sign owners retire with production world")
	var root := ProjectSettings.globalize_path("res://..").simplify_path();var head: Array=[];var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"contract records repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"contract records runtime digest")
	var passed := failures.is_empty();var status := "PASS" if passed else "FAIL";var path: String=get_script().resource_path
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Three original sign owners, fabricated payloads, retained lettering/areas/material and practical-light owners, original hours/dropout/neon states, persistent-fact stability, physical bearings, independent bodega branch route and teardown. Captures use real player standing stations. No disk-save reconstruction, keyboard route or residency proof.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-contract_started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},"premature_action_denial":{"executed":false,"status":"NOT_EXECUTED"},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained.filter(func(r):return r.get_ref()!=null).size()}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("signage/runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	return {"checks":checks,"failures":failures}

func _v(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
