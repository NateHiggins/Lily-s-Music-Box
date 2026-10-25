extends RefCounted
## Composed current stock and real hand input. Refolding/certification remain separate work.
const InputFixture=preload("res://tests/v2_fire_nozzle_coupling_bench.gd")
const InputHand=preload("res://tests/orison_v2_first_slice_contract_test.gd")
const StockProbe=preload("res://tests/v2_fire_rack_bench.gd")
var retired: Array[WeakRef]=[]
var failures: Array[String]=[]
var checks:=0
func check(suite: Node,ok: bool,label: String) -> void:
	checks+=1;suite.check(ok,"fire: "+label)
	if not ok:failures.append(label)
func _inherits_source(actor: Node,source_path: String) -> bool:
	var script: Script=actor.get_script()
	while script!=null:
		if script.resource_path==source_path:return true
		script=script.get_base_script()
	return false
func _place_player(world: OrisonV2RuntimeRoot,actor: Node3D) -> bool:
	var player: PlayerController=world.player
	player.set_physics_process(false);player.velocity=Vector3.ZERO;player.camera.make_current()
	var capsule:=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
	for depth: float in [1.15,.95,1.30,.80]:
		for lateral: float in [-.10,0.,.15,-.25,.30]:
			var feet: Vector3=actor.to_global(Vector3(lateral,-1.175,depth))
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.exclude=[player.get_rid()]
			query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*capsule.height*.5)
			if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
			var floor_query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.03,feet-Vector3.UP*.08,1,[player.get_rid()])
			var support: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(floor_query)
			if support.is_empty() or support.normal.dot(Vector3.UP)<.9:continue
			player.global_position=feet;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			await world.get_tree().physics_frame;await world.get_tree().physics_frame
			# An actual short capsule move, not just a clear endpoint.
			var motion: Vector3=actor.global_basis*Vector3(.03,0,0)
			if player.move_and_collide(motion)!=null:continue
			return true
	return false
func _flush(suite: Node,helper: Node,identity: String,first: int) -> void:
	for index in range(first,helper.observations.size()):
		var result: Dictionary=helper.observations[index]
		check(suite,bool(result.ok),identity+" "+str(result.label))
func _stock(suite: Node,actor: Node3D,native: RefCounted,probe: Node) -> void:
	var identity: String=str(actor.name)
	var saved: Dictionary=actor.mechanism_snapshot()
	var folds: Node=actor.get_node("NativeContinuousFolds")
	var rack: Node=actor.get_node("NativeHoseRack")
	check(suite,folds.returns.size()==9 and rack.arms.size()==10,identity+" continuous returns and individual carrier arms present")
	# Explicit visual fixtures, not a claim that the player refolded the hose.
	for fresh: bool in [false,true]:
		var pose: Dictionary=saved.facts.duplicate(true);pose.folds_fresh=fresh
		actor.restore_maintenance_snapshot(pose)
		await actor.get_tree().process_frame;await actor.get_tree().process_frame
		var hoses: Node=actor.get_node("NativeHoseRuns")
		check(suite,hoses.lead.mesh==native.meshes["HoseLead%d%d"%[int(fresh),int(not actor.coupling_made_up)]] and hoses.tail.mesh==native.meshes["HoseTail%d%d"%[int(fresh),actor.nozzle_hose_pose()]],identity+" source-selected hose poses follow current fixed receiving end")
		check(suite,hoses._live_lead!=null and hoses._live_lead.visible and not hoses._failed_pose,identity+" continuous outlet reaches its actual endpoints")
		for index in actor._fold_leaves.size():
			var leaf: MeshInstance3D=actor._fold_leaves[index]
			var crown: MeshInstance3D=leaf.get_node("NativeFoldCrown")
			var expected: Mesh=folds.meshes.LastLeg if index==9 else (folds.meshes.FirstPair if index==0 else folds.meshes.FoldPair)
			check(suite,leaf.mesh==expected and crown.mesh==(folds.meshes.OutletThroat if index==9 else folds.meshes.Crown),identity+" current native leaf/crown identity "+str([fresh,index]))
			var arm: MeshInstance3D=rack.arms[index]
			var tip:=Vector3(rack.data.tip_local_m[0],rack.data.tip_local_m[1],rack.data.tip_local_m[2])
			var bearing:=true
			for offset: float in [-.002,-.001,0.,.001,.002]:
				var point: Vector3=arm.to_global(tip)+actor.global_basis*Vector3.RIGHT*offset
				var direction: Vector3=actor.global_basis*Vector3.UP
				var measurement: Dictionary=probe.bearing_measure(arm,crown,point,direction)
				if not measurement.ok:print("COMPOSED RACK GAP: ",identity," ",fresh," ",index," ",offset," ",measurement)
				bearing=bearing and measurement.ok
			check(suite,bearing,identity+" five actual rack/cloth bearing rays within100um "+str([fresh,index]))
	actor.restore_mechanism(saved)
func run(world: OrisonV2RuntimeRoot,suite: Node) -> void:
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service",null)
	check(suite,native!=null and native.errors.is_empty(),"native installation completed")
	if native==null:return
	check(suite,native.stations.size()==8,"one source station at all eight landings")
	var player: PlayerController=world.player
	var player_pose: Transform3D=player.global_transform;var camera_pose: Transform3D=player.camera.transform
	var velocity: Vector3=player.velocity;var ticking: bool=player.is_physics_processing()
	var lamp_on: bool=player.lamp_is_enabled();var hidden: bool=player.carried_device.is_capture_hidden()
	var mouse_mode: Input.MouseMode=Input.mouse_mode
	var helper: Node=InputFixture.new();helper.set_meta("shared_world_validation",true);helper.player=player;world.add_child(helper)
	var hand: Node=InputHand.PatrolHand.new();hand.player=player;world.add_child(hand)
	var probe: Node=StockProbe.new()
	player.carried_device.set_capture_hidden(true);player.set_lamp_enabled(true)
	for identity: String in native.stations:
		var actor: Node3D=native.stations[identity].get_ref()
		retired.append(weakref(actor));retired.append(weakref(actor._gasket_body));retired.append(weakref(actor._nozzle_joint.body))
		var snapshot: Dictionary=actor.mechanism_snapshot();var record: Dictionary=actor._last_record.duplicate(true)
		var first_observation: int=helper.observations.size()
		check(suite,_inherits_source(actor,str(native.data.source_script)),identity+" retains original maintenance authority through inheritance")
		check(suite,actor.find_children("*","Area3D",true,false).is_empty(),identity+" retired legacy reaches absent")
		for id: String in ["door","joint","gasket","nozzle","lever","folds","tag"]:
			check(suite,not actor.interact_control(id,null),identity+" legacy toggle cannot operate "+id)
		await _stock(suite,actor,native,probe)
		var placed: bool=await _place_player(world,actor)
		check(suite,placed,identity+" supported real-player stance and capsule movement")
		if placed and failures.is_empty():
			check(suite,await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),identity+" actual mouse opens source leaf")
			check(suite,await hand.operate(actor._lever.to_global(Vector3(.07,0,0)),-.4,actor),identity+" actual mouse sets partial nozzle valve")
			check(suite,not actor.nozzle_shut and not actor.tag_signed,identity+" partial valve retains separate certification authority")
			check(suite,await hand.operate(actor._lever.to_global(Vector3(.07,0,0)),0.,actor),identity+" actual mouse closes nozzle valve")
			if failures.is_empty():await helper.exercise_nozzle(actor,hand)
			if helper.failures.is_empty():await helper.exercise_gasket(actor,hand)
			_flush(suite,helper,identity,first_observation)
		player.cancel_manipulation()
		if player.inspecting():helper.key(KEY_ESCAPE)
		actor.restore_mechanism(snapshot);actor._last_record=record
		var immediate: Dictionary=actor.mechanism_snapshot()
		# A composed render may contain several catch-up physics ticks.
		# Publish the restored child transforms through a real rendered frame
		# before querying the next physics space, rather than counting ticks
		# that can all precede the transform/broadphase flush.
		await RenderingServer.frame_post_draw
		await world.get_tree().physics_frame;await world.get_tree().physics_frame
		var restored: Dictionary=actor.mechanism_snapshot()
		if restored!=snapshot:
			for key: String in snapshot:
				if snapshot[key]!=restored[key]:print("COMPOSED RESTORE DIFFERENCE: ",identity," field=",key," expected=",JSON.stringify(snapshot[key])," immediate=",JSON.stringify(immediate[key])," settled=",JSON.stringify(restored[key]))
		check(suite,restored==snapshot,identity+" all physical fields and source facts restore")
		for original: Dictionary in native.source_records[identity]:
			var draw: MeshInstance3D=original.draw.get_ref()
			check(suite,draw!=null and draw.get_parent().get_instance_id()==original.parent,identity+" original mesh node/pivot survives")
		var from: Vector3=actor.to_global(Vector3(0,.390,.60));var to: Vector3=actor.to_global(Vector3(0,.390,0))
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
		if not snapshot.facts.door_open:
			print("FIRE CENTRE RAY DIAGNOSTIC: ",identity," collider=",hit.collider.get_path() if not hit.is_empty() else "none"," at=",hit.get("position")," door=",actor._bodies.door.get_path()," player=",player.global_position)
			check(suite,not hit.is_empty() and hit.collider==actor._bodies.door,identity+" actual closed moving leaf collision across assembly centre")
			# Probe the same exposed leaf patch used for actual acquisition,
			# in the leaf's frame. A long assembly-centre ray can hit other
			# installed architecture and does not identify the moving leaf.
			var leaf_query:=PhysicsRayQueryParameters3D.create(actor._door_pivot.to_global(Vector3(-.4,.1,.035)),actor._door_pivot.to_global(Vector3(-.4,.1,-.035)),1,[player.get_rid()])
			var leaf_hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(leaf_query)
			var door_body: Node3D=actor._bodies.door
			var disabled: Array=[]
			# Contact proxies are sibling bodies beneath the leaf. Inspect its
			# actual shapes without casting unrelated children to CollisionShape3D.
			for child: Node in door_body.get_children():
				if child is CollisionShape3D:disabled.append(child.disabled)
			print("COMPOSED DOOR PHYSICS: ",identity," leaf=",actor._door_pivot.global_transform," body=",door_body.global_transform," server=",PhysicsServer3D.body_get_state(door_body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)," layer=",door_body.collision_layer," disabled=",disabled," hit=",leaf_hit.collider.get_path() if not leaf_hit.is_empty() else "none"," at=",leaf_hit.get("position"))
			check(suite,not leaf_hit.is_empty() and leaf_hit.collider==actor._bodies.door,identity+" actual closed moving leaf collision at its exposed operable face")
		if identity in ["F01_FIRE_LINE_STAIR","ROOF_FIRE_LINE_STAIR"] and failures.is_empty():
			player.camera.look_at(actor.to_global(Vector3(0,.35,.10)))
			for frame in 10:await RenderingServer.frame_post_draw
			await suite.shot("fire_"+identity+"_closed")
			check(suite,await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),identity+" capture leaf opens through actual input")
			for frame in 10:await RenderingServer.frame_post_draw
			await suite.shot("fire_"+identity+"_open")
			actor.restore_mechanism(snapshot);actor._last_record=record
		print("COMPOSED FIRE STATION: ",identity," checks=",checks," failures=",failures.size())
		if not failures.is_empty():break
	# Preserve native riser bore and wall-bearing checks independently of controls.
	var faces: PackedVector3Array=native.meshes.StationTee.get_faces();var start:=Vector3(-.08,0,-.042);var first:=INF
	for i in range(0,faces.size(),3):
		var hit: Variant=Geometry3D.ray_intersects_triangle(start,Vector3.RIGHT,faces[i],faces[i+1],faces[i+2])
		if hit!=null:first=minf(first,hit.x-start.x)
	check(suite,is_finite(first) and first>.10,"station branch retains actual open riser bore")
	for identity: String in native.stations:
		var actor: Node3D=native.stations[identity].get_ref();var at:=Vector3(4.89,actor.position.y-.9,-3.64)
		var query:=PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(at),world.adapter.root.to_global(at+Vector3(0,0,-.145)),1)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(suite,not hit.is_empty() and hit.normal.dot(world.adapter.root.global_basis*Vector3.BACK)>.9,identity+" actual outward wall bearing")
	player.cancel_manipulation();player.global_transform=player_pose;player.camera.transform=camera_pose;player.velocity=velocity
	player.set_physics_process(ticking);player.set_lamp_enabled(lamp_on);player.carried_device.set_capture_hidden(hidden);Input.mouse_mode=mouse_mode
	helper.free();hand.free();probe.free()
	for draw: MeshInstance3D in native.pipe_parts:retired.append(weakref(draw))
	print("COMPOSED FIRE REVIEW: checks=",checks," failures=",failures.size())

func after_teardown(suite: Node) -> void:
	var alive := 0
	for ref: WeakRef in retired:
		if ref.get_ref() != null: alive += 1
	check(suite,alive == 0,"all installed apparatus and native line nodes retire")
	var root := ProjectSettings.globalize_path("res://..").simplify_path();var digest: Array = []
	OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)
	var status := "PASS" if failures.is_empty() else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},"scope":"Eight current native stations, actual input for doors/valves/nozzle/washer, measured stock and supported stances, preserved authorities and owned retirement. No refolding/deployment, certification, water-flow, capacity or statutory proof.","source":{"test_path":"game/tests/v2_fire_service_review.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},"contracts":{"production_composition":{"executed":true,"status":status},"fire_service":{"executed":true,"status":status},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":alive}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("fire_service_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
