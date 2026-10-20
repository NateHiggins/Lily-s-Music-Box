extends RefCounted
## Shared production-world checks; no fire, fluid capacity, or legal compliance claim.
var retired: Array[WeakRef] = []
var failures: Array[String] = []
var checks := 0
func check(suite: Node,ok: bool,label: String) -> void:
	checks += 1; suite.check(ok,"fire: " + label)
	if not ok: failures.append(label)
func run(world: OrisonV2RuntimeRoot,suite: Node) -> void:
	var native: RefCounted = world.adapter.root.get_meta("v2_native_fire_service",null)
	check(suite,native != null and native.errors.is_empty(),"native installation completed")
	if native == null: return
	check(suite,native.stations.size() == 8,"one source station at all eight landings")
	var camera := Camera3D.new(); camera.fov = 52; world.add_child(camera)
	world.player.carried_device.set_capture_hidden(true)
	var inspection := OmniLight3D.new();inspection.light_energy = 2.; inspection.omni_range = 2.8; camera.add_child(inspection)
	var mover := CharacterBody3D.new(); mover.collision_layer = 0; mover.collision_mask = 1
	var collider := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.radius = PlayerController.BODY_RADIUS; capsule.height = PlayerController.STANDING_HEIGHT
	collider.shape = capsule; collider.position.y = capsule.height*.5; mover.add_child(collider); world.add_child(mover)
	for identity: String in native.stations:
		var actor: FireLineCabinetProp = native.stations[identity].get_ref()
		retired.append(weakref(actor))
		var snapshot := actor.maintenance_snapshot(); var record: Dictionary = actor._last_record.duplicate(true)
		check(suite,actor.get_script().resource_path == native.data.source_script,identity + " retains maintenance owner")
		check(suite,actor.find_children("*","Area3D",true,false).size() == 7,identity + " retains seven source reaches")
		check(suite,not actor.interact_control("joint",null),identity + " closed door refuses joint")
		actor.restore_maintenance_snapshot(snapshot)
		check(suite,actor.interact_control("door",null) and is_equal_approx(actor._door_pivot.rotation.y,1.78),identity + " original door opens")
		check(suite,not actor.interact_control("tag",null),identity + " uninspected tag refused")
		check(suite,actor.interact_control("joint",null) and actor.gasket_seen,identity + " actual joint reveals pocket")
		check(suite,actor.interact_control("gasket",null) and actor.gasket_seated,identity + " source gasket seats")
		check(suite,actor.interact_control("joint",null) and actor.coupling_made_up,identity + " coupling remade")
		check(suite,actor.interact_control("nozzle",null) and actor.interact_control("lever",null) and actor.line_made_up(),identity + " nozzle and shut lever complete four joints")
		check(suite,actor.interact_control("folds",null) and actor.folds_fresh,identity + " fresh crease refolds")
		actor._balk_left = 0; actor._refresh_cabinet()
		await world.get_tree().process_frame
		await world.get_tree().process_frame
		var hoses: Node = actor.get_node("NativeHoseRuns")
		check(suite,hoses.lead.mesh == native.meshes.HoseLead10 and hoses.tail.mesh == native.meshes.HoseTail11,identity + " native flexible runs follow source poses")
		for leaf: MeshInstance3D in actor._fold_leaves:
			var crown := leaf.get_node("NativeFoldCrown") as MeshInstance3D
			check(suite,crown.mesh == native.meshes.FoldCrown and crown.position == Vector3(0,.131,0),identity + " crown follows its moving fold")
		for original: Dictionary in native.source_records[identity]:
			var draw: MeshInstance3D = original.draw.get_ref()
			check(suite,draw != null and draw.get_parent().get_instance_id() == original.parent,identity + " source mesh node/pivot survives")
		# Move the real standing capsule through the north landing, with the door open.
		var reached := false
		for x: float in [4.25,4.0,4.55,3.75]:
			for z: float in [-3.20,-2.95,-2.70,-2.45]:
				var feet: Vector3 = world.adapter.root.to_global(Vector3(x,actor.position.y-1.18,z))
				var query := PhysicsShapeQueryParameters3D.new(); query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*capsule.height*.5)
				query.collision_mask = 1; query.exclude = [mover.get_rid(),world.player.get_rid()]
				if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
				var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.03,feet-Vector3.UP*.10,1,[mover.get_rid(),world.player.get_rid()]))
				if floor_hit.is_empty(): continue
				mover.global_position = feet
				var collision := mover.move_and_collide(world.adapter.root.global_basis*Vector3(.10,0,0))
				if collision == null: reached = true; break
			if reached: break
		check(suite,reached,identity + " supported standing approach with open leaf and actual capsule movement")
		var from := actor.to_global(Vector3(0,.390,.60)); var to := actor.to_global(Vector3(0,.390,0))
		# The closed leaf must have physical substance and follow the original hinge.
		actor.restore_maintenance_snapshot(snapshot)
		await world.get_tree().physics_frame
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
		check(suite,not hit.is_empty() and actor.is_ancestor_of(hit.collider),identity + " actual closed leaf collision")
		if identity in ["F01_FIRE_LINE_STAIR","ROOF_FIRE_LINE_STAIR"]:
			camera.global_position = actor.to_global(Vector3(-.25,.47,1.30)); camera.look_at(actor.to_global(Vector3(.1,.4,.1)),Vector3.UP); camera.make_current()
			await suite.shot("fire_" + identity + "_closed")
			actor.open_door();actor._balk_left = 0;actor._refresh_cabinet()
			camera.global_position = actor.to_global(Vector3(-.32,.47,.98));camera.look_at(actor.to_global(Vector3(.02,.38,.1)),Vector3.UP)
			await suite.shot("fire_" + identity + "_open")
			actor.restore_maintenance_snapshot(snapshot)
		check(suite,actor.maintenance_snapshot() == snapshot,identity + " all source facts restored")
		actor._last_record = record
	# Branch bore must stay open into the actual riser, using native triangles.
	var tee: Mesh = native.meshes.StationTee
	var faces := tee.get_faces(); var start := Vector3(-.08,0,-.042);var first := INF
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(start,Vector3.RIGHT,faces[i],faces[i+1],faces[i+2])
		if hit != null: first = minf(first,hit.x-start.x)
	check(suite,is_finite(first) and first > .10,"station branch enters the riser bore without a solid blocker")
	# A real support ray hits the owning wall face, rather than an invented datum.
	for identity: String in native.stations:
		var actor: Node3D = native.stations[identity].get_ref()
		var at := Vector3(4.89,actor.position.y-.9,-3.64)
		var query := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(at),world.adapter.root.to_global(at+Vector3(0,0,-.145)),1)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(suite,not hit.is_empty() and hit.normal.dot(world.adapter.root.global_basis*Vector3.BACK) > .9,identity + " saddle seats on actual outward wall face " + str(hit) + " source=" + str(at))
	camera.free();mover.free();world.player.camera.make_current()
	for draw: MeshInstance3D in native.pipe_parts: retired.append(weakref(draw))
func after_teardown(suite: Node) -> void:
	var alive := 0
	for ref: WeakRef in retired:
		if ref.get_ref() != null: alive += 1
	check(suite,alive == 0,"all installed apparatus and native line nodes retire")
	var root := ProjectSettings.globalize_path("res://..").simplify_path();var digest: Array = []
	OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)
	var status := "PASS" if failures.is_empty() else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},"scope":"Eight native original maintenance stations, line geometry, landing approaches, wall contacts and owned retirement; no water-flow, capacity or statutory acceptance.","source":{"test_path":"game/tests/v2_fire_service_review.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},"contracts":{"production_composition":{"executed":true,"status":status},"fire_service":{"executed":true,"status":status},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":alive}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("fire_service_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
