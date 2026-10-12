extends RefCounted
var failures: Array[String]=[]
var checks := 0
var retired: Array[WeakRef]=[]
func check(suite: Node,value: bool,label: String) -> void:
	checks+=1;suite.check(value,"electrical connection: "+label)
	if not value:failures.append(label)
func run(world: Node3D,suite: Node) -> void:
	var native: RefCounted=world.adapter.root.get_meta("v2_native_electrical_connections")
	check(suite,native!=null and native.errors.is_empty(),"source-connected assembly mounts")
	if native==null:return
	var actor: Node3D=native.source_actor.get_ref()
	check(suite,actor!=null and actor.get_meta("v2_furniture_id","")=="B1_fuse_conduit","original source owner retained")
	var space := world.get_world_3d().direct_space_state
	var excludes: Array[RID]=[world.player.get_rid()]
	var bore_excludes: Array[RID]=[world.player.get_rid()]
	for body: StaticBody3D in native._root.find_children("*","StaticBody3D",true,false):
		excludes.append(body.get_rid());retired.append(weakref(body))
		if body.get_parent().name!="RiserFeedTee":bore_excludes.append(body.get_rid())
	for p: Array in native.data.ceiling_bearings:
		var at: Vector3=world.adapter.root.to_global(Vector3(p[0],p[1],p[2]))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at-Vector3.UP*.03,at+Vector3.UP*.015,1,excludes))
		check(suite,not hit.is_empty() and hit.normal.dot(Vector3.DOWN)>.9,"actual ceiling face supports hanger at "+str(p))
	for z: float in [-2.,-1.,.2]:
		var a: Vector3=world.adapter.root.to_global(Vector3(7.92,-.32,z-.09))
		var b: Vector3=world.adapter.root.to_global(Vector3(7.92,-.32,z+.09))
		check(suite,space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1,excludes)).is_empty(),"clear branch port at "+str(z))
		var offset: Vector3=world.adapter.root.global_basis*Vector3(.08,0,0)
		check(suite,not space.intersect_ray(PhysicsRayQueryParameters3D.create(a+offset,b+offset,1,excludes)).is_empty(),"wall substance beside branch port at "+str(z))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(Vector3(7.69,-.6,-6.17)),world.adapter.root.to_global(Vector3(7.52,-.6,-6.17)),1,excludes))
	print("ELECTRICAL JUNCTION PROBE: ",hit," owner=",actor.get_path()," pose=",actor.global_transform)
	check(suite,not hit.is_empty() and hit.collider==actor and hit.position.distance_to(world.adapter.root.to_global(Vector3(7.69,-.6,-6.17)))>.13,"side outlet opens into actual hollow source junction")
	hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(Vector3(9.25,-.32,1)),world.adapter.root.to_global(Vector3(9.45,-.32,1)),1,bore_excludes))
	check(suite,not hit.is_empty() and native._root.is_ancestor_of(hit.collider) and hit.position.distance_to(world.adapter.root.to_global(Vector3(9.25,-.32,1)))>.15,"tee bore reaches riser cavity without an old solid blocker")
	var camera := Camera3D.new();world.add_child(camera)
	var light := OmniLight3D.new();camera.add_child(light);light.light_energy=1.3;light.omni_range=3.0
	for shot: Dictionary in [{"name":"electrical_panel_connection","at":Vector3(8.25,-.5,-5.55),"target":Vector3(7.65,-.6,-6.17)},{"name":"electrical_riser_connection","at":Vector3(8.7,-.5,1.7),"target":Vector3(9.27,-.32,1)}]:
		camera.global_position=world.adapter.root.to_global(shot.at);camera.look_at(world.adapter.root.to_global(shot.target),Vector3.UP);camera.make_current()
		await suite.shot(shot.name)
	camera.free();world.player.camera.make_current()
	for draw: MeshInstance3D in native.installed:retired.append(weakref(draw))
func after_teardown(suite: Node) -> void:
	var alive := 0
	for ref: WeakRef in retired:
		if ref.get_ref()!=null:alive+=1
	check(suite,alive==0,"all branch nodes and collision owners retire")
	var status := "PASS" if failures.is_empty() else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},"scope":"Physical panel-to-riser branch, actual port/cavity/support probes and owned teardown; no energized circuit or complete device endpoint acceptance.","source":{"test_path":"game/tests/v2_electrical_connections_review.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path)},"contracts":{"electrical_supply_fabric":{"executed":true,"status":status},"teardown":{"executed":true,"status":status,"retained_nodes":alive,"measurement_scope":"runtime_owned"}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("electrical_connections_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
