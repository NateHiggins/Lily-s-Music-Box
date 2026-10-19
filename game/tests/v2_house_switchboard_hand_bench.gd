extends Node3D
## Actual native plug/key input and transient line authority; not room proof.
const Hand=preload("res://tests/orison_v2_first_slice_contract_test.gd")
var checks: int=0
var failures: Array[String]=[]
var board: HouseSwitchboardProp
var line: HouseTelephoneNetwork
var player: PlayerController
var externally_managed: bool=false

func _ready() -> void:
	if not externally_managed:_run.call_deferred()
func check(ok: bool,label: String) -> bool:
	checks+=1;print("PHONE HAND CHECK: ",label," = ",ok)
	if not ok:failures.append(label)
	return ok
func click() -> void:
	var event: InputEventMouseButton=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
func aim(point: Vector3) -> void:
	player.camera.look_at(point);await get_tree().physics_frame;await get_tree().physics_frame;player.camera.look_at(point)
func shot(name: String) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func carry_to(goal: Vector3,port_id: String="",steps: int=900) -> bool:
	for step in steps:
		if not player._grab.active():return false
		var descriptor: Dictionary=player._grab.target
		if not port_id.is_empty():
			var index: int=board._hand_controls.plugs.find(descriptor.part)
			if index>=0 and board._hand_controls._seat(index)==port_id:return true
		var current: Vector3=descriptor.read.call()
		var difference: Vector3=board.global_basis*(goal-current)
		if difference.length()<.00005:return true
		var from: Vector3=descriptor.part.to_global(player._grab.contact)
		var ray: Vector3=(from-player.camera.global_position).normalized()
		# Free mouse motion lies in the camera plane; the wheel follows the
		# contact ray. Resolve those actual input axes rather than projecting
		# twice along the ray. Fine insertion must fit the real 1 mm clearance.
		var fraction: float=minf(1.,(.0005 if not port_id.is_empty() else .006)/difference.length())
		var forward: Vector3=-player.camera.global_basis.z
		var depth: float=difference.dot(forward)/ray.dot(forward)*fraction
		if absf(depth)>.000001:
			var wheel: InputEventMouseButton=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if depth>0 else MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.factor=absf(depth)/.025;player._unhandled_input(wheel)
		from=descriptor.part.to_global(player._grab.contact)
		var target: Vector3=from+board.global_basis*(goal-descriptor.read.call())*fraction
		var motion: InputEventMouseMotion=InputEventMouseMotion.new();motion.relative=player.camera.unproject_position(target)-player.camera.unproject_position(from);player._unhandled_input(motion)
		await get_tree().physics_frame
	print("PHONE CARRY STOP goal=",goal," actual=",player._grab.target.read.call() if player._grab.active() else "released")
	return false

func connect_plug(index: int,port_id: String) -> bool:
	var controls: RefCounted=board._hand_controls
	var part: Node3D=controls.plugs[index]
	await aim(part.to_global(Vector3(0,0,-.025)))
	var candidate: Dictionary=player._grab.find_target()
	if not check(candidate.get("part")==part,"actual cursor selects native plug "+str(index)):
		print("PHONE PICK DIAGNOSTIC ",candidate);return false
	var before: Vector3=part.position
	click()
	if not check(player._grab.active() and part.position.is_equal_approx(before),"click grabs plug without displacement"):return false
	var port: Dictionary={}
	for row: Dictionary in controls.source.ports:
		if str(row.id)==port_id:port=row;break
	if not check(not port.is_empty(),"authored physical port exists: "+port_id):return false
	var center: Vector3=Vector3(port.center[0],port.center[1],port.center[2])
	var goal: Vector3=Vector3(center.x,center.y,center.z-float(controls.source.plug.collar_z)-float(controls.source.plug.skin_m))
	for waypoint: Vector3 in [Vector3(before.x,before.y,-.235),Vector3(goal.x,goal.y,-.235),goal]:
		if not check(await carry_to(waypoint,port_id if waypoint==goal else ""),"mouse moves plug through clear approach: "+str(waypoint)):return false
	click()
	return check(not player._grab.active() and controls._seat(index)==port_id,"second click releases a physically seated plug")

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();CampaignTime.set_frozen_for_tests(true)
	var floor: StaticBody3D=StaticBody3D.new();add_child(floor)
	var body: CollisionShape3D=CollisionShape3D.new();var shape: BoxShape3D=BoxShape3D.new();shape.size=Vector3(4,.2,4);body.shape=shape;body.position.y=-.1;floor.add_child(body)
	var sun: DirectionalLight3D=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,145,0);sun.light_energy=1.3;add_child(sun)
	var environment: WorldEnvironment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.15,.15,.15);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.5;add_child(environment)
	line=HouseTelephoneNetwork.new();add_child(line);line.register_endpoint({"id":"F02_A_TELEPHONE","extension":"2A"})
	board=HouseSwitchboardProp.new();board.position=Vector3(0,1.42,0);board.set_meta("v2_house_switchboard",true);board.bind_line(line);add_child(board)
	player=PlayerController.new();player.position=Vector3(0,.025,-1.05);add_child(player);player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame;await get_tree().physics_frame
	var save: String=JSON.stringify(RealityState.data)
	var hand: Node=Hand.PatrolHand.new();hand.player=player;add_child(hand)
	if check(board.get_meta("v2_native_house_switchboard",false) and board.get_meta("v2_switchboard_physical",false),"native cabinet and real physical controls bind"):
		var key: Vector3=board._key.to_global(Vector3(0,.108,0))
		check(line.request("F02_A_TELEPHONE"),"declared existing caller stimulus asks for a line")
		await aim(board.to_global(Vector3(0,.39,-.11)))
		check(player._grab.find_target().get("blocked",false),"fixed cabinet blocks legacy click-state interaction")
		click();check(str(line.snapshot().state)=="ASKING" and not player.call_locked,"clicking fixed cabinet cannot answer or open a modal")
		check(board.interact_prompt().is_empty(),"native cabinet offers no old click-cycle instructions")
		await aim(key);click();check(player._grab.active() and str(line.snapshot().state)=="ASKING","grabbing key alone does not answer");click()
		await aim(key);click()
		var space: InputEventKey=InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=true;player._unhandled_input(space)
		check(player.inspecting() and player.inspect_owner==board,"grab and Space inspect the physical board")
		if player.inspecting():
			var pose: Transform3D=player.camera.global_transform
			var motion: InputEventMouseMotion=InputEventMouseMotion.new();motion.relative=Vector2(30,10);player._unhandled_input(motion)
			await get_tree().physics_frame;await get_tree().physics_frame
			check(player.camera.global_transform.is_equal_approx(pose) and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"board inspection retains static camera and movable cursor")
			await shot("board_inspection")
			space.pressed=false;player._unhandled_input(space);space.pressed=true;player._unhandled_input(space)
			check(not player.inspecting() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Space leaves board inspection")
		check(await hand.operate(key,-.42,board),"actual mouse movement closes listening key")
		check(str(line.snapshot().state)=="ASKING","key without a caller plug cannot answer")
		await shot("asking_board")
		if await connect_plug(0,"0_1"):
			check(str(line.snapshot().state)=="ASKING","a physically seated wrong jack does not answer the asking caller")
		if await connect_plug(0,"0_0"):
			check(str(line.snapshot().state)=="ANSWERED" and str(line.snapshot().answered_by)=="house_board","actual caller plug plus key answers through retained network")
			await shot("answered_board")
			if await connect_plug(1,"2_5"):
				check(str(line.snapshot().state)=="CARRYING" and str(line.snapshot().carried_by)=="outside_trunk","actual trunk plug carries the same line")
				await shot("carried_board")
				var part: Node3D=board._hand_controls.plugs[0]
				await aim(part.to_global(Vector3(0,0,-.025)));click()
				check(await carry_to(Vector3(part.position.x,part.position.y,-.235)),"mouse physically withdraws caller plug")
				click();check(str(line.snapshot().state)=="IDLE","physical disconnection releases the existing line")
				await shot("released_board")
				if await connect_plug(0,"2_2"):
					await _occupied_plug_denial()
	check(JSON.stringify(RealityState.data)==save,"ordinary telephone use creates no durable save or case facts")
	check(not player.call_locked,"physical telephone never opens a modal interaction")
	hand.free();player.cancel_manipulation();player.free();board.free();line.free();floor.free();sun.free();environment.free()
	print("V2 PHONE HAND BENCH: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _occupied_plug_denial() -> void:
	var controls: RefCounted=board._hand_controls
	var part: Node3D=controls.plugs[1]
	await aim(part.to_global(Vector3(0,0,-.025)));click()
	if not check(player._grab.active(),"second plug can be grabbed for occupied-stock denial"):return
	# Withdraw the former trunk before approaching the occupied lower jack.
	if not check(await carry_to(Vector3(part.position.x,part.position.y,-.30)),"actual hand clears the former trunk bore"):click();return
	if not check(await carry_to(Vector3(-.05,.26,-.30)),"actual hand approaches occupied jack within cord reach"):click();return
	var goal: Vector3=controls.plugs[0].position
	check(controls.cords[1].can_reach(controls.anchors[1],goal+Vector3(0,0,float(controls.source.plug.cord_outlet_z))),"occupied placement would fit the cord length")
	var blocked: bool=not await carry_to(goal,"",60)
	check(blocked and part.position.distance_to(goal)>.02,"actual mouse cannot push the second plug through occupied native stock")
	var query: PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new();query.transform=board.global_transform*Transform3D(Basis(),goal);query.exclude=[controls.plug_bodies[1].get_rid(),player.get_rid()];query.margin=.00001
	var occupied: bool=false
	for shape: Shape3D in controls.collision_stock:
		query.shape=shape
		for hit: Dictionary in board.get_world_3d().direct_space_state.intersect_shape(query,32):
			if hit.collider==controls.plug_bodies[0]:occupied=true
	check(occupied,"independent query identifies the other actual plug as blocking stock")
	click();check(not player._grab.active() and str(line.snapshot().state)=="IDLE","blocked plug releases without changing line authority")
