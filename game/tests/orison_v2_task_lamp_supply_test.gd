extends "res://tests/orison_v2_domestic_native_test.gd"
var retained: Array[WeakRef] = []
var contract_started := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started=Time.get_ticks_msec()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_task_lamp_supply.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"supply export matches native inspection input")
	var factory: RefCounted=world.adapter.root.get_meta("v2_task_lamp_supply")
	check(factory.errors.is_empty() and factory.installed.size()==5,"five original lamps receive their authorized supply routes")
	world.first_shift_director.ritual_phase()
	var saved:=var_to_bytes(RealityState.data)
	var shared_outlet:=0
	for route: Dictionary in fixture.routes:
		var entry: Dictionary=factory.installed[str(route.id)]
		var lamp: LampProp=entry.lamp.get_ref()
		var support: StaticBody3D=entry.support.get_ref()
		var root: Node3D=entry.root.get_ref()
		var outlet: MeshInstance3D=entry.outlet.get_ref()
		retained.append(weakref(root));retained.append(weakref(lamp))
		check(root.get_parent()==support and root.find_children("*","CollisionObject3D",true,false).is_empty(),"supply remains passive stock under source furniture, with no snag collider")
		check(lamp.transform.is_equal_approx(entry.position) and lamp.graph_node_id==entry.graph and lamp.light.get_instance_id()==entry.light and lamp._switch_key.get_instance_id()==entry.switch,"original lamp transform, graph, light and switch owners retained")
		if shared_outlet==0:shared_outlet=outlet.mesh.get_instance_id()
		check(outlet.mesh.get_instance_id()==shared_outlet,"five outlets share one immutable native mesh")
		for draw: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			check(draw.mesh is ArrayMesh,"supply stock uses native geometry")
			if str(draw.name).ends_with("ClothFlex"):_check_cord(draw.mesh)
			else:_check_cap_mapping(draw.mesh,true)
		for x in [-.040,0.,.040]:
			for z in [-.026,0.,.026]:
				var at:=outlet.to_global(Vector3(x,0,z))
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.012,1))
				check(not hit.is_empty() and hit.position.distance_to(at)<.0002 and hit.normal.y>.99,"outlet flange meets actual floor or retained rug: "+str(route.id))
		var traveled:=0.
		var blocked:=false
		var blockers: Array=[]
		var sphere:=SphereShape3D.new();sphere.radius=float(route.radius)-.0004
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=sphere;query.collision_mask=1;query.exclude=[world.player.get_rid()]
		for i in range(1,route.centerline.size()):
			var a:=_point(route.centerline[i-1]);var b:=_point(route.centerline[i]);var length:=a.distance_to(b)
			var steps:=maxi(1,ceili(length/.025))
			for step in range(1,steps+1):
				var fraction:=float(step)/steps
				if traveled+length*fraction<.018:continue
				query.transform=Transform3D(Basis.IDENTITY,support.to_global(a.lerp(b,fraction)))
				var contacts:=world.get_world_3d().direct_space_state.intersect_shape(query,1)
				if not contacts.is_empty():
					blocked=true
					if blockers.size()<5:blockers.append({"point":a.lerp(b,fraction),"collider":contacts[0].collider.name})
			traveled+=length
		check(not blocked,"supply cord clears actual composed collision geometry: "+str(route.id))
		if blocked:print("SUPPLY COLLISION ",route.id," ",blockers)
		var enabled:=lamp.is_locally_enabled()
		var budget:=lamp._target_scale
		var shadow:=lamp.light.shadow_enabled
		var rig_processing:=world.light_rig.is_processing()
		world.light_rig.set_process(false)
		lamp.set_process(false)
		lamp.set_budget(1.,false,true)
		lamp.set_local_enabled(true,false)
		lamp.interact(world.player)
		await lamp._switch_tween.finished
		lamp._process(0.)
		check(not lamp.is_locally_enabled() and not lamp.light.visible and is_zero_approx(lamp.light.light_energy),"original fitted switch turns lamp off: "+str(route.id))
		lamp.set_budget(.8,false,true);lamp._process(0.)
		check(not lamp.light.visible,"power budget cannot override the local off switch")
		lamp.interact(world.player)
		await lamp._switch_tween.finished
		lamp._process(0.)
		check(lamp.is_locally_enabled() and lamp.light.visible and lamp.light.light_energy>0.,"original fitted switch restores the original light")
		lamp.set_budget(budget,false,shadow);lamp.set_local_enabled(enabled,false);lamp._process(0.)
		world.light_rig.set_process(rig_processing)
		if capture_enabled:await _capture_supply(world,lamp,support,outlet)
		lamp.set_process(true)
	check(var_to_bytes(RealityState.data)==saved,"five supply visuals and restored switches write no saved fact")
	return {"checks":checks,"failures":failures,"views":discovery.duplicate(true)}

func _point(v: Array) -> Vector3:return Vector3(v[0],v[1],v[2])

func _check_cord(mesh: Mesh) -> void:
	# A curved, continuously unwrapped tube has bounded bend distortion rather
	# than the planar one-metre chart invariant used for boards and fittings.
	var valid:=mesh.get_surface_count()==1
	var a:=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=a[Mesh.ARRAY_TEX_UV]
	var tangent: PackedFloat32Array=a[Mesh.ARRAY_TANGENT]
	valid=valid and vertices.size()==uv.size() and normals.size()==vertices.size() and tangent.size()==vertices.size()*4
	for i in vertices.size():
		var t:=Vector3(tangent[i*4],tangent[i*4+1],tangent[i*4+2])
		valid=valid and vertices[i].is_finite() and uv[i].is_finite() and absf(normals[i].length()-1.)<.001 and absf(t.length()-1.)<.001 and absf(normals[i].dot(t))<.001
	check(valid,"continuous cloth flex retains finite UVs and unit tangent basis")

func _capture_supply(world: OrisonV2RuntimeRoot,lamp: LampProp,support: Node3D,outlet: Node3D) -> void:
	var station:=Vector3.INF
	for radius in [1.15,1.55,1.95,2.35]:
		for step in 16:
			var angle:=step*TAU/16.
			var feet:=support.to_global(Vector3(sin(angle)*radius,.03,-cos(angle)*radius))
			if _city_clear_station(world,feet):station=feet;break
		if station.is_finite():break
	check(station.is_finite(),"real standing station for installed supply: "+str(lamp.name))
	if not station.is_finite():return
	await _city_capture(world,station,lamp.global_position+Vector3.UP*.12,str(lamp.name)+"_supply","task lamp supply",str(lamp.name))
	# Close inspection uses a named diagnostic camera in the same production
	# world. It introduces no lights and claims no player approach proof.
	world.player.face_world_point(outlet.global_position)
	var camera:=Camera3D.new();world.add_child(camera)
	camera.global_position=outlet.global_position+support.global_basis*Vector3(.30,.28,.38)
	camera.look_at(outlet.global_position+Vector3.UP*.04);camera.fov=45.;camera.make_current()
	await _settled_optics();await shot(str(lamp.name)+"_outlet_detail")
	world.player.camera.make_current();camera.free()

func validate_after_teardown() -> Dictionary:
	for ref in retained:check(ref.get_ref()==null,"supply and original lamp retire with production world")
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[];var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"contract records repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"contract records runtime digest")
	var status:="PASS" if failures.is_empty() else "FAIL"
	var path: String=get_script().resource_path
	var receipt:={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Five original task lamps with authorized passive supply routes: retained optical/control/graph ownership, actual outlet-floor contacts, cord collision clearance, original switch motion and restored power state, retirement. No new electrical service capacity, player approach route or save reconstruction is claimed.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-contract_started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},"premature_action_denial":{"executed":true,"status":status},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained.filter(func(r):return r.get_ref()!=null).size()}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("task_lamp_supply/runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	return {"checks":checks,"failures":failures}
