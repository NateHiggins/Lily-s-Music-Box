extends RefCounted
## Physical enclosure inspection; no invented energized circuits or endpoint proof.
var failures: Array[String] = []
var checks := 0
var retired: Array[WeakRef] = []
func check(suite: Node,condition: bool,label: String) -> void:
	checks += 1; suite.check(condition,"electrical: " + label)
	if not condition: failures.append(label)
func run(world: Node3D,suite: Node) -> void:
	var native: RefCounted = world.adapter.root.get_meta("v2_native_electrical_service")
	check(suite,native != null and native.errors.is_empty(),"native assembly mounted")
	if native == null: return
	check(suite,native.stations.size() == 8,"eight fixed junction stations")
	var space := world.get_world_3d().direct_space_state
	var exclusions: Array[RID] = [world.player.get_rid()]
	for body: Node in native._root.find_children("*","StaticBody3D",true,false):
		exclusions.append(body.get_rid()); retired.append(weakref(body))
	for at: Vector3 in native.bearings:
		var a: Vector3 = world.adapter.root.to_global(at+Vector3(.028,0,0))
		var b: Vector3 = world.adapter.root.to_global(at+Vector3(.060,0,0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,exclusions))
		check(suite,not hit.is_empty() and hit.normal.dot(world.adapter.root.global_basis*Vector3.LEFT)>.9,"saddle contacts outward wall face at " + str(at))
	for y: float in native.data.slab_centres:
		var at := Vector3(native.data.axis[0],y,native.data.axis[1])
		var a: Vector3 = world.adapter.root.to_global(at+Vector3.UP*.125)
		var b: Vector3 = world.adapter.root.to_global(at-Vector3.UP*.125)
		check(suite,space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,exclusions)).is_empty(),"actual clear slab bore at " + str(y))
		var offset: Vector3 = world.adapter.root.global_basis*Vector3(-.065,0,0)
		check(suite,not space.intersect_ray(PhysicsRayQueryParameters3D.create(a+offset,b+offset,1,exclusions)).is_empty(),"slab substance retained beside sleeve at " + str(y))
	var capsule := CapsuleShape3D.new(); capsule.radius=.18; capsule.height=1.72
	for row: Dictionary in native.data.stations:
		var reached := false
		var floor_y := float(row.y)-1.85
		for x: float in [8.9,8.7,8.5]:
			for z: float in [.5,.8,1.,1.2,1.5]:
				var nominal: Vector3 = world.adapter.root.to_global(Vector3(x,floor_y,z))
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(nominal+Vector3.UP*.25,nominal-Vector3.UP*.10,1,[world.player.get_rid()]))
				if ground.is_empty() or ground.normal.dot(Vector3.UP)<.9:continue
				var feet: Vector3 = ground.position+Vector3.UP*.02
				var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule
				query.transform=Transform3D(world.adapter.root.global_basis,feet+Vector3.UP*.86)
				query.collision_mask=1;query.exclude=[world.player.get_rid()]
				if not space.intersect_shape(query,1).is_empty():continue
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.03,feet-Vector3.UP*.10,1,[world.player.get_rid()])).is_empty():continue
				reached=true;break
			if reached:break
		check(suite,reached,str(row.id)+" supported standing inspection stance")
	var camera := Camera3D.new();world.add_child(camera)
	var light := OmniLight3D.new();camera.add_child(light);light.light_energy=1.3;light.omni_range=3.0
	for identity: String in ["F01_ELECTRICAL_JUNCTION","ROOF_ELECTRICAL_JUNCTION"]:
		var owner: Node3D = native.stations[identity].get_ref()
		camera.global_position=owner.to_global(Vector3(.22,.08,.70));camera.look_at(owner.global_position,Vector3.UP);camera.make_current()
		await suite.shot("electrical_"+identity)
	camera.free();world.player.camera.make_current()
	for draw: MeshInstance3D in native.installed:retired.append(weakref(draw))
func after_teardown(suite: Node) -> void:
	var alive := 0
	for ref: WeakRef in retired:
		if ref.get_ref()!=null:alive+=1
	check(suite,alive==0,"all native draws and collision owners retire")
	var status := "PASS" if failures.is_empty() else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},"scope":"Fixed electrical riser, wall contacts, slab bores, local standing stances and owned teardown; no circuit energization or endpoint acceptance.","source":{"test_path":"game/tests/v2_electrical_service_review.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path)},"contracts":{"electrical_fabric":{"executed":true,"status":status},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":alive}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("electrical_service_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
