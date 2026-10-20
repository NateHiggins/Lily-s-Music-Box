extends Node3D
## Native installer and actual input; scoped bench, not played-room acceptance.
const Native=preload("res://scripts/building/orison_v2_native_fire_service.gd")
const Hand=preload("res://tests/orison_v2_first_slice_contract_test.gd")
class FixtureAdapter extends RefCounted:
	var root: Node3D
	var count := 0
	func mount_consumer(identity: String, actor: Node3D) -> bool:
		actor.name=identity;actor.position=Vector3(count*2.5,1.2,0)
		count+=1;root.add_child(actor);return true
var failures: Array[String]=[]
var observations: Array[Dictionary]=[]
var player: PlayerController
func check(ok: bool,label: String) -> bool:
	observations.append({"ok":ok,"label":label})
	print("FIRE HAND CHECK: ",label," = ",ok)
	if not ok: failures.append(label)
	return ok
func _ready() -> void:
	if not bool(get_meta("shared_world_validation",false)):_run.call_deferred()
func click() -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;player._unhandled_input(e)
func key(code: Key) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;player._unhandled_input(e)
func aim(point: Vector3) -> void:
	player.camera.look_at(point);await get_tree().physics_frame;await get_tree().physics_frame;player.camera.look_at(point)
func cursor_to(pixel: Vector2) -> bool:
	# Input-mode changes and the inspection's initial centering can still be
	# queued at the native window. Publish a rendered frame before requesting
	# the pick position, and retry only until its real viewport delivery.
	pixel=pixel.round()
	var window_id: int=get_window().get_window_id()
	var initial_focus: bool=DisplayServer.window_is_focused(window_id)
	var initial_mode: int=Input.mouse_mode
	var before: Vector2=get_viewport().get_mouse_position()
	for frame in 8:
		if not DisplayServer.window_is_focused(window_id):
			DisplayServer.window_move_to_foreground(window_id)
		await RenderingServer.frame_post_draw
		Input.warp_mouse(pixel)
		await get_tree().process_frame
		if get_viewport().get_mouse_position().distance_to(pixel)<=.5:
			if frame>0 or not initial_focus:
				print("INSPECTION CURSOR READY: frames=",frame+1," focused=",DisplayServer.window_is_focused(window_id)," initial_focus=",initial_focus," mode=",Input.mouse_mode," initial_mode=",initial_mode)
			return true
	print("INSPECTION CURSOR DELIVERY FAILED: wanted=",pixel," before=",before," actual=",get_viewport().get_mouse_position()," focused=",DisplayServer.window_is_focused(window_id)," initial_focus=",initial_focus," mode=",Input.mouse_mode," initial_mode=",initial_mode," viewport=",get_viewport().get_visible_rect())
	return false
func acquire_surface(part: Node3D, preferred: Vector3=Vector3.INF) -> bool:
	# Track the part's own coordinates while native cursor delivery awaits a
	# frame. A newly loose union can fall between projection and acquisition.
	if preferred.is_finite():
		var local: Vector3=part.to_local(preferred)
		for attempt in 4:
			await cursor_to(player.camera.unproject_position(part.to_global(local)))
			if player._grab.find_target().get("part")==part:return true
	if part is MeshInstance3D and part.mesh!=null:
		var faces: PackedVector3Array=part.mesh.get_faces()
		var candidates: Array[Dictionary]=[]
		for index in range(0,faces.size(),3):
			var a: Vector3=part.to_global(faces[index]);var b: Vector3=part.to_global(faces[index+1]);var c: Vector3=part.to_global(faces[index+2])
			if player.camera.is_position_behind(a) or player.camera.is_position_behind(b) or player.camera.is_position_behind(c):continue
			var pa: Vector2=player.camera.unproject_position(a);var pb: Vector2=player.camera.unproject_position(b);var pc: Vector2=player.camera.unproject_position(c)
			var area: float=absf((pb-pa).cross(pc-pa))
			if area<2.:continue
			candidates.append({"point":(faces[index]+faces[index+1]+faces[index+2])/3.,"area":area})
		candidates.sort_custom(func(a: Dictionary,b: Dictionary):return float(a.area)>float(b.area))
		var visited: Dictionary={}
		for candidate: Dictionary in candidates:
			var pixel: Vector2=player.camera.unproject_position(part.to_global(candidate.point)).round()
			if not get_viewport().get_visible_rect().has_point(pixel) or visited.has(pixel):continue
			visited[pixel]=true
			await cursor_to(pixel)
			if player._grab.find_target().get("part")==part:
				print("ACTUAL SURFACE PICK: part=",part.name," samples=",visited.size())
				return true
			if visited.size()>=64:break
	var pixel: Vector2=get_viewport().get_mouse_position();var origin: Vector3=player.camera.project_ray_origin(pixel)
	var ray:=PhysicsRayQueryParameters3D.create(origin,origin+player.camera.project_ray_normal(pixel)*2.1);ray.collide_with_areas=true;ray.exclude=[player.get_rid()]
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
	print("SURFACE ACQUISITION BLOCKED: part=",part.name," collider=",hit.collider.get_path() if not hit.is_empty() else "none"," target=",player._grab.find_target())
	return false
func surface_pick_controls(part: Node3D) -> void:
	check(await acquire_surface(part),"actual native triangles supply a visible cursor patch without a guessed point")
	var wall:=StaticBody3D.new();add_child(wall);wall.name="PickObstructionControl"
	wall.global_transform=player.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,0,-.12))
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2.,2.,.01);shape.shape=box;wall.add_child(shape)
	await RenderingServer.frame_post_draw;await get_tree().physics_frame;await get_tree().physics_frame
	check(not await acquire_surface(part),"opaque physical obstruction prevents all sampled part acquisitions")
	wall.free();await RenderingServer.frame_post_draw;await get_tree().physics_frame;await get_tree().physics_frame
	check(await acquire_surface(part),"removing the obstruction restores actual surface acquisition")
func stock_ray(draw: MeshInstance3D, origin: Vector3, direction: Vector3) -> float:
	var local: Vector3=draw.to_local(origin)*1000.
	var axis: Vector3=draw.global_basis.inverse()*direction
	var faces: PackedVector3Array=draw.mesh.get_faces()
	var distance: float=INF
	for i in range(0,faces.size(),3):
		var hit: Variant=Geometry3D.ray_intersects_triangle(local,axis,faces[i]*1000.,faces[i+1]*1000.,faces[i+2]*1000.)
		if hit is Vector3:distance=minf(distance,origin.distance_to(draw.to_global(hit/1000.)))
	return distance
func inspect_operate(hand: Node, part: Node3D, point: Vector3, goal: float) -> bool:
	if not await acquire_surface(part,point):
		print("CARRY PICK FAILURE: wanted=",part," actual=",player._grab.find_target().get("part")," point=",point," mouse=",get_viewport().get_mouse_position()," wanted_pixel=",player.camera.unproject_position(point)," target=",player._grab.find_target())
		return false
	click()
	if not player._grab.active() or player._grab.target.part!=part:
		if player._grab.active():click()
		return false
	var moved: bool=await hand.move_to(goal)
	if player._grab.active():click()
	return moved
func diagnose_joint(actor: Node3D) -> void:
	print("JOINT DIAGNOSTIC: nut=",actor._joint_nut.global_transform," bounds=",actor._joint_nut.mesh.get_aabb()," paper=",actor._tag.global_transform," eye=",player.camera.global_position)
	for y: float in [-.02,-.012,.01]:
		for angle: float in [-.8,0.,.8]:
			var point: Vector3=actor._coupling.to_global(Vector3(sin(angle)*.032,y,cos(angle)*.032))
			var pixel: Vector2=player.camera.unproject_position(point)
			var origin: Vector3=player.camera.project_ray_origin(pixel)
			var query:=PhysicsRayQueryParameters3D.create(origin,origin+player.camera.project_ray_normal(pixel)*2.1)
			query.collide_with_areas=true;query.exclude=[player.get_rid()]
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
			print("JOINT PROBE: y=",y," angle=",angle," collider=",hit.collider.get_path() if not hit.is_empty() else "none"," position=",hit.get("position"))
	var dir: String=OS.get_environment("SHOT_DIR")
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir);await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join("inspection_joint_occlusion.png"))
func carry_union(actor: Node3D,goal: Vector3) -> bool:
	return await carry_part(actor,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),goal,.00001)
func carry_part(actor: Node3D,part: Node3D,point: Vector3,goal: Vector3,tolerance: float) -> bool:
	return await carry_path(actor,part,point,[goal],tolerance)
func carry_path(actor: Node3D,part: Node3D,point: Vector3,goals: Array,tolerance: float,contact_stop: Callable=Callable()) -> bool:
	if not await acquire_surface(part,point):
		print("CARRY PICK FAILURE: wanted=",part," actual=",player._grab.find_target().get("part")," point=",point," mouse=",get_viewport().get_mouse_position()," wanted_pixel=",player.camera.unproject_position(point)," target=",player._grab.find_target())
		return false
	click()
	if not player._grab.active() or player._grab.target.kind!="free":
		if player._grab.active():click()
		return false
	var reached: bool=true
	for goal: Vector3 in goals:
		var arrived: bool=false;var stagnant: int=0
		for i in range(160):
			if not player._grab.active():break
			var before: Vector3=player._grab.target.read.call()
			if before.distance_to(goal)<tolerance:arrived=true;break
			# Wheel and screen motions are separate physical events. For the
			# nozzle's narrow entry, millimetre waypoints keep the intermediate
			# path out of its rim. Retain longer carrying gestures elsewhere.
			var step_goal: Vector3=goal
			if part==actor._play_pipe:step_goal=before+(goal-before).limit_length(.001)
			point=part.to_global(player._grab.contact)
			var delta: Vector3=actor.global_basis*(step_goal-before)
			var depth: float=delta.dot((point-player.camera.global_position).normalized())
			if absf(depth)>.000002:
				var wheel:=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if depth>0. else MOUSE_BUTTON_WHEEL_UP;wheel.factor=minf(.025,absf(depth))/.025;player._unhandled_input(wheel)
			point=part.to_global(player._grab.contact)
			delta=actor.global_basis*(step_goal-player._grab.target.read.call())
			var motion:=InputEventMouseMotion.new();motion.relative=(player.camera.unproject_position(point+delta)-player.camera.unproject_position(point)).limit_length(30.)
			player._unhandled_input(motion);await get_tree().physics_frame
			if contact_stop.is_valid() and contact_stop.call():arrived=true;break
			stagnant=stagnant+1 if before.distance_to(player._grab.target.read.call())<.0000001 else 0
			if stagnant>8:break
		if not arrived:reached=false;break
	var before_release: Transform3D=part.global_transform
	if not reached:
		var at: Variant=player._grab.target.read.call() if player._grab.active() else null
		var joint: Node3D=actor._nozzle_joint
		print("CARRY STOP: actor=",actor.name," part=",part.name," at=",at," goals=",goals," contact=",joint._last_contact.get_path() if part==actor._play_pipe and is_instance_valid(joint._last_contact) else "none")
		if part==actor._play_pipe and is_instance_valid(joint._last_contact):print("CARRY STOCK: ",joint._last_contact.get_parent().get_meta("native_fire_part","none"))
	if contact_stop.is_valid():print("GUIDED CARRY RESULT: reached=",reached," body=",player._grab.target.read.call() if player._grab.active() else Vector3.INF," global=",before_release)
	if player._grab.active():click()
	return reached and (not contact_stop.is_valid() or part.global_transform==before_release)
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var ground:=StaticBody3D.new();add_child(ground)
	var col:=CollisionShape3D.new();var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(8,.2,8);col.shape=floor_shape;col.position.y=-.1;ground.add_child(col)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-30,0);sun.light_energy=1.4;add_child(sun)
	var fill:=OmniLight3D.new();fill.position=Vector3(-.3,2.,1.7);fill.omni_range=4.;fill.light_energy=2.;add_child(fill)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.12,.12);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;add_child(env)
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.0}]}),"production native installer accepts retained source stock"):
		print(native.errors);get_tree().quit(1);return
	var actor: FireLineCabinetProp=native.stations.values()[0].get_ref()
	print("GASKET STOCK: bounds=",actor._spare_gasket.mesh.get_aabb()," body_shapes=",actor._gasket_body.get_child_count()," pose=",actor._gasket_body.global_transform)
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part","")) in ["F062","F063"]:print("GASKET TIN: ",draw.global_transform," bounds=",draw.mesh.get_aabb())
	var nozzle_socket: MeshInstance3D
	for draw: MeshInstance3D in actor._play_pipe.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part",""))=="F060":nozzle_socket=draw
	check(nozzle_socket!=null,"right-facing nozzle retains its actual source socket node")
	var nozzle_facts: Dictionary=actor.maintenance_snapshot()
	for fresh: bool in [false,true]:
		for coupled: bool in [false,true]:
			var facts: Dictionary=nozzle_facts.duplicate(true);facts.folds_fresh=fresh;facts.nozzle_coupled=coupled;actor.restore_maintenance_snapshot(facts)
			await get_tree().process_frame;await get_tree().process_frame
			var pose_coupled: bool=coupled if actor._nozzle_joint==null else false
			var old_angle: float=2.42 if pose_coupled else 1.5708
			var old_at:=Vector3(.045,.205,.120) if pose_coupled else Vector3(-.060,.068,.112)
			var expected: Vector3=actor.to_global(old_at+Basis(Vector3.BACK,old_angle)*Vector3(0,-.012,0))
			check(actor._play_pipe.global_basis.y.dot(actor.global_basis*Vector3.RIGHT)>.65,"nozzle points right in source pose: "+str([fresh,coupled]))
			check(nozzle_socket.global_position.distance_to(expected)<.000001,"physical nozzle joint preserves its hose inlet datum independently of repair facts: "+str([fresh,coupled]))
			var hose: MeshInstance3D=actor.get_node("NativeHoseRuns").tail
			check(hose.mesh==native.meshes["HoseTail%d%d"%[int(fresh),int(pose_coupled)]],"hose stays on its real receiving end while nozzle repair state changes")
			var bearing: bool=true
			for i in range(8):
				var angle: float=TAU*i/8.;var point:=Vector3(.020*cos(angle),-.001,.020*sin(angle))
				var origin: Vector3=nozzle_socket.to_global(point);var direction: Vector3=nozzle_socket.global_basis.y
				bearing=bearing and absf(stock_ray(nozzle_socket,origin,direction)-.001)<.0001 and absf(stock_ray(hose,origin,direction)-.001)<.0001
			check(bearing,"imported hose end bears on the actual receiving shoulder within100um: "+str([fresh,coupled]))
	for draw: MeshInstance3D in [nozzle_socket,actor.get_node("NativeHoseRuns").tail]:
		var finish: StandardMaterial3D=draw.get_active_material(0)
		check(finish.normal_enabled and not finish.uv1_triplanar,"actual right-facing stock uses authored charts and normal mapping")
		for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:check(texture!=null and texture.get_image().get_mipmap_count()>0,"right-facing stock retains its actual loaded PBR mip chain")
	actor.restore_maintenance_snapshot(nozzle_facts)
	var stem: MeshInstance3D
	var paper: MeshInstance3D
	for draw: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part",""))=="F021":stem=draw
		elif str(draw.get_meta("native_fire_part",""))=="F033":paper=draw
	var wire: MeshInstance3D=actor._tag_wire
	var wire_bounds: AABB=wire.mesh.get_aabb()
	var wire_bottom: Vector3=wire.to_global(Vector3(0,wire_bounds.position.y,0))
	var wire_faces: PackedVector3Array=wire.mesh.get_faces()
	var contact: Vector3=actor.to_local(wire.to_global(wire_faces[0]))
	for vertex: Vector3 in wire_faces:
		var point: Vector3=actor.to_local(wire.to_global(vertex))
		if point.z<contact.z:contact=point
	check(stem!=null and absf(stock_ray(stem,actor.to_global(contact+Vector3.BACK*.001),actor.global_basis*Vector3.FORWARD)-.001)<.0001,"actual imported wire cap meets spindle triangles at retained bearing tolerance")
	check(paper!=null and absf(stock_ray(paper,wire_bottom+Vector3.UP*.001,Vector3.DOWN)-.001)<.0001,"imported wire lower end meets actual paper top edge")
	var retained_parents: bool=true
	for original: Dictionary in native.source_records[actor.station_id]:
		var draw: MeshInstance3D=original.draw.get_ref()
		retained_parents=retained_parents and draw!=null and draw.get_parent().get_instance_id()==original.parent
	check(retained_parents,"native mesh parents survive rigid wire refitting and control installation")
	player=PlayerController.new();player.position=Vector3(-.1,.025,1.15);add_child(player);player.set_lamp_enabled(false);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	var at: Vector3=actor._door_pivot.to_global(Vector3(-.4,.1,.015))
	await aim(at)
	check(player._grab.find_target().get("part")==actor._door_pivot,"actual native door surface supplies the cursor target")
	click();check(player._grab.active() and is_zero_approx(actor._door_pivot.rotation.y),"click grabs without toggling the door");click()
	check(await hand.operate(at,.5,actor),"actual mouse motion leaves a partial door angle")
	check(not actor.door_open and is_equal_approx(actor._door_pivot.rotation.y,.5),"partial opening does not grant maintenance access")
	await aim(actor._door_pivot.to_global(Vector3(-.4,.1,.015)))
	check(player._grab.find_target().get("part")==actor._door_pivot,"partly open leaf retains its exact moving cursor collision")
	check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual mouse opens native leaf to its physical stop")
	check(actor.door_open and not actor.line_made_up(),"door access does not repair any joint")
	var lever_at: Vector3=actor._lever.to_global(Vector3(.07,0,0))
	await aim(lever_at)
	check(player._grab.find_target().get("part")==actor._lever,"actual separate play-pipe lever is ray selected")
	check(await hand.operate(lever_at,-.4,actor),"actual mouse leaves a partial nozzle valve angle")
	check(not actor.nozzle_shut,"partly closed nozzle remains a line fault")
	var partial_state: Dictionary=actor.mechanism_snapshot()
	check(await hand.operate(actor._lever.to_global(Vector3(.07,0,0)),0.0,actor),"actual mouse shuts the nozzle valve")
	check(actor.nozzle_shut and not actor.line_made_up(),"shut nozzle does not counterfeit coupling or gasket work")
	var saved: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(saved),"partial physical settings have a valid existing-household snapshot")
	var bad: Dictionary=saved.duplicate(true);bad.door=99.
	check(not actor.valid_mechanism(bad),"out-of-range saved travel is refused")
	actor.restore_mechanism(bad)
	check(actor.mechanism_snapshot()==saved,"invalid restoration changes no physical or maintenance fact")
	actor.restore_mechanism(partial_state)
	check(actor._lever.basis.is_equal_approx(Basis(Vector3.BACK,PI-.4)) and not actor.nozzle_shut,"actual saved partial nozzle travel restores without rounding to a toggle")
	check(not actor.interact_control("joint",player) and actor.coupling_made_up,"old click-to-toggle joint verb is retired in V2")
	var joint_at: Vector3=actor._coupling.to_global(Vector3(0,-.012,.032))
	await aim(actor._tag.to_global(Vector3(0,0,.0035)));click();key(KEY_SPACE)
	check(player.inspecting(),"actual Space enters the close service view before reaching past the tag")
	var joint_eye: Transform3D=player.camera.global_transform
	await diagnose_joint(actor)
	await cursor_to(player.camera.unproject_position(joint_at))
	check(player._grab.find_target().get("part")==actor._joint_nut,"actual native swivel nut supplies the joint cursor")
	click();check(player._grab.active() and actor.coupling_made_up and is_zero_approx(actor._union_angle),"joint click grabs without breaking the connection");click()
	check(await inspect_operate(hand,actor._joint_nut,joint_at,.9),"actual mouse partially unscrews the native swivel union")
	check(absf(actor._coupling.position.y-(.513-.0028*.9/TAU))<.000001 and not actor.coupling_made_up,"union withdrawal follows the source thread pitch continuously")
	check(actor._coupling.get_node("SwivelTail").basis.is_equal_approx(Basis.IDENTITY) and actor._coupling.get_node("HoseRetainer").basis.is_equal_approx(Basis.IDENTITY),"nut rotation leaves the hose tail and cuff untwisted")
	check(not actor.gasket_seen and not actor.gasket_seated and not actor.tag_signed,"turning the union cannot counterfeit gasket inspection or certification")
	var saved_joint: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(saved_joint),"partial screw travel has a valid existing household snapshot")
	var unknown: Dictionary=saved_joint.duplicate(true);unknown.erase("joint");unknown.unrecognized=0.
	check(not actor.valid_mechanism(unknown),"an unknown saved field cannot replace the joint setting")
	var inconsistent: Dictionary=saved_joint.duplicate(true);inconsistent.facts.coupling_made_up=true
	check(not actor.valid_mechanism(inconsistent),"saved made-up fact cannot contradict partial screw travel")
	check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),0.),"actual mouse retightens the empty union to its physical stop")
	check(actor.coupling_made_up and not actor.line_made_up() and not actor.gasket_seen,"tightening over an empty seat retains the original gasket fault")
	actor.restore_mechanism(saved_joint)
	check(absf(actor._union_angle-.9)<.000001 and not actor.coupling_made_up,"partial joint travel restores without a toggle")
	check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),0.),"restored joint can be retightened through actual input")
	check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),actor._maximum("joint")),"actual mouse follows the full native threaded withdrawal stroke")
	check(absf(actor._coupling.position.y-.505)<.000001 and not actor.coupling_made_up and not actor.gasket_seen,"full screw travel clears the male tip without inventing an inspection")
	check(actor._loose_union.active and actor._grip("joint").kind=="free","releasing the fully unthreaded union exposes constrained loose-part movement")
	var loose_goal: Vector3=actor._loose_union.receiving()+Vector3(0,-.015,.015)
	check(await carry_union(actor,loose_goal),"actual mouse and depth wheel carry the loose union away from the male outlet")
	check(actor._loose_union.location.distance_to(loose_goal)<.00001 and not actor.coupling_made_up and not actor.gasket_seen,"carrying the hose end does not invent a sealed or inspected joint")
	var loose_saved: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(loose_saved),"loose union position survives the household mechanism schema")
	var overreach: Dictionary=loose_saved.duplicate(true);overreach.loose.position=[2.,2.,2.]
	check(not actor.valid_mechanism(overreach),"saved loose positions cannot exceed the authored hose length")
	check(await carry_union(actor,actor._loose_union.receiving()),"actual carry returns the loose union to the real receiving axis")
	check(not actor._loose_union.active and not actor.coupling_made_up,"catching the thread does not tighten the union")
	check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),0.),"returned loose union can be tightened through actual screw input")
	check(player.camera.global_transform.is_equal_approx(joint_eye),"screw manipulation keeps the inspection camera static")
	key(KEY_ESCAPE)
	var obstruction:=StaticBody3D.new();obstruction.name="DoorSweepObstruction";add_child(obstruction)
	var stop_shape:=CollisionShape3D.new();var stop_box:=BoxShape3D.new();stop_box.size=Vector3(.06,.3,.06);stop_shape.shape=stop_box;obstruction.add_child(stop_shape)
	obstruction.global_position=actor.to_global(Vector3(.305-.4*cos(.9),.39,.206+.4*sin(.9)))
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),0.0,actor) and actor._door_pivot.rotation.y>.5,"actual closing mouse motion stops against surrounding solid stock")
	obstruction.free();await get_tree().physics_frame;await get_tree().physics_frame
	check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),0.0,actor),"door closes after the physical obstruction is removed")
	check(not actor.door_open and not actor.line_made_up(),"closing does not grant access or repair the dry line")
	check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"closed leaf can be reopened through input")
	var condition_before: Dictionary=actor.maintenance_snapshot()
	check(await hand.operate(actor._valve_wheel.to_global(Vector3(.035,0,.025)),.025,actor),"actual mouse takes up locked supply-wheel play")
	check(actor.maintenance_snapshot()==condition_before,"locked spindle play changes no dry-line or certification fact")
	var tag_at: Vector3=actor._tag.to_global(Vector3(0,0,.0035))
	await aim(tag_at);click()
	check(player._grab.active() and player._grab.target.part==actor._tag_hinge,"actual paper stock can be grabbed at its wire hinge")
	key(KEY_SPACE)
	if check(player.inspecting() and player.inspect_owner==actor and not player._grab.active(),"Space inspection releases the hand and fixes the cabinet camera"):
		var eye: Transform3D=player.camera.global_transform
		await cursor_to(player.camera.unproject_position(tag_at))
		check(player._grab.find_target().get("part")==actor._tag_hinge,"free inspection cursor selects actual hanging paper")
		click()
		check(player._grab.active() and await hand.move_to(.6),"inspection mouse lifts the paper about its upper wire attachment")
		check(player.camera.global_transform.is_equal_approx(eye),"part manipulation keeps inspection camera static")
		if player._grab.active():click()
		key(KEY_ESCAPE)
		check(not player.inspecting(),"Escape backs out of inspection")
	await get_tree().create_timer(.65).timeout
	check(actor._tag_angle<.001 and actor._wheel_angle<.001,"released paper settles and spindle play returns without a toggle")
	check(actor.maintenance_snapshot()==condition_before and not actor.tag_signed,"touching or inspecting the tag does not certify unexamined joints")
	await exercise_gasket(actor,hand)
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory);await aim(actor.to_global(Vector3(0,.4,.1)));await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("native_door_and_nozzle.png"))
		player.set_lamp_enabled(false)
		var close:=Camera3D.new();close.fov=38.;add_child(close);close.global_position=actor.to_global(Vector3(-.04,.24,.58));close.look_at(actor.to_global(Vector3(-.04,.07,.112)));close.make_current()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("right_facing_nozzle.png"))
	print("V2 FIRE HAND BENCH: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func exercise_gasket(actor: Node3D,hand: Node) -> void:
	# Physical loose washer: no direct writes to maintenance facts or transforms.
	await aim(actor._tag.to_global(Vector3(0,0,.0035)));click();key(KEY_SPACE)
	check(player.inspecting() and player.inspect_owner==actor,"actual grabbed tag opens the fixed gasket inspection view")
	check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),actor._maximum("joint")),"gasket work starts by actually unthreading the union")
	check(await carry_union(actor,actor._loose_union.receiving()+Vector3(0,-.025,.060)),"actual carry exposes the receiving washer seat")
	for frame in range(30):await get_tree().physics_frame
	var gasket: RigidBody3D=actor._gasket_body
	var gasket_home: Dictionary=actor.mechanism_snapshot()
	# Select a real rasterized annulus pixel. One fixed3D rim point can
	# project between pixels after a micrometre-level supported-pose change.
	var ring_point: Vector3=await pick_washer(gasket)
	if not check(ring_point.is_finite(),"actual visible washer has an operable screen pixel"):return
	var ring_pixel: Vector2=player.camera.unproject_position(ring_point)
	var ring_ray:=PhysicsRayQueryParameters3D.create(player.camera.project_ray_origin(ring_pixel),player.camera.project_ray_origin(ring_pixel)+player.camera.project_ray_normal(ring_pixel)*2.1)
	ring_ray.exclude=[player.get_rid()]
	print("GASKET PICK RAY: ",get_world_3d().direct_space_state.intersect_ray(ring_ray)," inspecting=",player.inspecting()," mouse=",get_viewport().get_mouse_position()," desired=",ring_pixel)
	await cursor_to(player.camera.unproject_position(ring_point))
	check(player._grab.find_target().get("part")==gasket,"actual washer annulus is individually selectable in the relocated tin")
	var lift_goal: Vector3=gasket.position+Vector3(0,.040,0)
	check(await carry_part(actor,gasket,ring_point,lift_goal,.00009),"actual mouse and depth wheel lift the original washer out of its tin")
	check(not actor.gasket_seated and not actor.gasket_seen,"carrying the spare washer does not counterfeit fitting or inspection")
	var lifted: Dictionary=actor.mechanism_snapshot()
	check(actor.valid_mechanism(lifted),"loose washer position and orientation pass the household save schema")
	var invalid_ring: Dictionary=lifted.duplicate(true);invalid_ring.gasket.rotation=[0.,0.,0.,0.]
	check(not actor.valid_mechanism(invalid_ring),"invalid washer orientation is rejected")
	actor.restore_mechanism(gasket_home)
	check(gasket.position.distance_to(Vector3(gasket_home.gasket.position[0],gasket_home.gasket.position[1],gasket_home.gasket.position[2]))<.000001,"actual loose washer pose restores without duplicating its draw")
	var seat_target: Dictionary={}
	var visited: Dictionary={}
	for sample in range(96):
		var angle: float=TAU*(sample%32)/32.
		var radius: float=.020+float(sample/32)*.001
		var empty_seat: Vector3=actor._coupling.to_global(Vector3(radius*cos(angle),.020,radius*sin(angle)))
		var pixel: Vector2=player.camera.unproject_position(empty_seat).round()
		if visited.has(pixel):continue
		visited[pixel]=true;await cursor_to(pixel)
		seat_target=player._grab.find_target()
		if actor.gasket_seen:break
	print("GASKET DIAGNOSTIC: ring=",gasket.position," seat=",actor._coupling.position," target=",seat_target.get("part")," seen=",actor.gasket_seen," sampled_pixels=",visited.size())
	check(actor.gasket_seen,"actual inspection cursor observes the exposed receiving annulus")
	var seat: Vector3=gasket.seat_position()
	var path: Array=[Vector3(gasket.position.x,seat.y+.050,gasket.position.z),seat+Vector3.UP*.050,seat+Vector3.UP*.00007]
	ring_point=await pick_washer(gasket)
	check(ring_point.is_finite() and await carry_path(actor,gasket,ring_point,path,.00009),"actual continuous grab carries the washer into the receiving seat")
	check(actor.gasket_seated and not actor.coupling_made_up,"releasing the physically fitted washer seats it without tightening the nut")
	var exclusions: Array[RID]=[]
	for body: PhysicsBody3D in get_tree().root.find_children("*","PhysicsBody3D",true,false):
		if body!=gasket:exclusions.append(body.get_rid())
	var probe:=PhysicsShapeQueryParameters3D.new();var ball:=SphereShape3D.new();ball.radius=.0004
	probe.shape=ball;probe.exclude=exclusions;probe.collision_mask=1;probe.margin=0.
	probe.transform=Transform3D(Basis.IDENTITY,gasket.to_global(Vector3(.0209,.00075,0)))
	check(not get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(),"actual washer collision has a positive solid-annulus control")
	ball.radius=.0188;probe.transform=Transform3D(Basis.IDENTITY,gasket.to_global(Vector3(0,.00075,0)))
	check(get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(),"actual annular collision leaves an18.8mm bore gauge unobstructed")
	if actor.gasket_seated:
		check(actor.valid_mechanism(actor.mechanism_snapshot()),"seated washer and loose union have a consistent household snapshot")
		check(await carry_union(actor,actor._loose_union.receiving()),"actual carry returns the washer-bearing hose end to the male outlet")
		check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),actor._minimum("joint")),"actual screw motion tightens against the real washer thickness")
		check(actor.coupling_made_up and absf(actor._coupling.position.y-.5115)<.000001,"fitted washer moves the union stop by its actual1.5mm thickness")
		var seated_saved: Dictionary=actor.mechanism_snapshot()
		check(actor.valid_mechanism(seated_saved),"tightened gasket-bearing union passes the existing household schema")
		var impossible: Dictionary=seated_saved.duplicate(true);impossible.gasket.position[1]+=.010
		check(not actor.valid_mechanism(impossible),"saved seated washer cannot float10mm above its actual support")
		check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),actor._maximum("joint")),"actual mouse can unthread the repaired union again")
		check(await carry_union(actor,actor._loose_union.receiving()+Vector3(0,-.025,.060)),"actual carry exposes the installed washer for removal")
		for frame in range(30):await get_tree().physics_frame
		var removal_point: Vector3=await pick_washer(gasket)
		check(removal_point.is_finite() and await carry_part(actor,gasket,removal_point,gasket.position+Vector3.UP*.035,.00009),"actual grab removes the same installed washer from the opened union")
		check(not actor.gasket_seated and not actor.coupling_made_up,"physical washer removal restores the gasket fault without changing inspection history")
		actor.restore_mechanism(seated_saved)
		check(actor.gasket_seated and actor.coupling_made_up and gasket.position.distance_to(gasket.seat_position())<.000001,"actual seated washer pose and union stop restore together")
	var directory: String=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("physical_gasket_work.png"))==OK,"actual gasket inspection frame is saved")
	key(KEY_ESCAPE)

func pick_washer(gasket: Node3D) -> Vector3:
	var visited: Dictionary={}
	for sample in range(96):
		var angle: float=TAU*(sample%32)/32.
		var radius: float=.020+float(sample/32)*.001
		var point: Vector3=gasket.to_global(Vector3(radius*cos(angle),.0015,radius*sin(angle)))
		var pixel: Vector2=player.camera.unproject_position(point).round()
		if visited.has(pixel):continue
		visited[pixel]=true;await cursor_to(pixel)
		var candidate: Dictionary=player._grab.find_target()
		if candidate.get("part")==gasket:return candidate.hit_position
	return Vector3.INF
