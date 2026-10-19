extends "res://tests/orison_v2_4b_door_route_test.gd"
## One lobby placement; ordinary movement through the shared-room programme.
const Basement=preload("res://tests/orison_v2_basement_route_test.gd")
const Mail=preload("res://tests/v2_service_mail_operations.gd")
const Telephone=preload("res://tests/v2_service_telephone_operations.gd")
var captures: Dictionary={}
var mail_expected: Dictionary={}

func _init() -> void:route_label="SERVICE PROGRAMME WALK"

func _part_gesture(grip: Dictionary,goal: float) -> Vector2:
	# The inherited stop-to-stop driver always sends six centimetres/radians.
	# Partial mail and lid positions require a final smaller real mouse event;
	# otherwise it oscillates around the requested position indefinitely.
	var remaining: float=absf(goal-float(grip.read.call()))
	return super._part_gesture(grip,goal)*minf(1.,remaining/.06)/float(grip.get("motion_scale",1.))

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(0,.025,-3.35))
	player.velocity=Vector3.ZERO

func _walk(local_target: Vector3) -> bool:
	var target: Vector3=world.adapter.root.to_global(local_target)
	var distance: float=player.global_position.distance_to(target)
	var budget: int=ceili(maxf(6.,distance/player.WALK+2.)*Engine.physics_ticks_per_second)
	var deadline: int=Time.get_ticks_msec()+ceili(maxf(30.,distance/player.WALK*3.+15.)*1000.)
	var frames: int=0
	var contacts: Dictionary={}
	while frames<budget and Time.get_ticks_msec()<deadline:
		var delta: Vector3=target-player.global_position;delta.y=0
		if delta.length()<.1:break
		player.rotation.y=atan2(-delta.x,-delta.z);player.camera.rotation=Vector3.ZERO
		Input.action_press("move_forward",minf(1.,delta.length()/.35))
		await get_tree().physics_frame;frames+=1
		for i in player.get_slide_collision_count():
			var contact: KinematicCollision3D=player.get_slide_collision(i)
			var collider: Node=contact.get_collider() as Node
			if collider!=null and absf(contact.get_normal().y)<.7:contacts[str(collider.get_path())]=str(contact.get_position())
	Input.action_release("move_forward")
	await get_tree().physics_frame;await get_tree().physics_frame
	var at: Vector3=world.adapter.root.to_local(player.global_position)
	var ok: bool=Vector2(at.x-local_target.x,at.z-local_target.z).length()<.18 and absf(at.y-local_target.y)<.15 and not player.noclip and player.collision_mask==1 and player.is_physics_processing()
	var row: Dictionary={"actual":[at.x,at.y,at.z],"target":[local_target.x,local_target.y,local_target.z],"ok":ok,"wall_contacts":contacts,"physics_steps":frames,"on_floor":player.is_on_floor()}
	trace.append(row);print("PROGRAMME ROUTE: ",JSON.stringify(row))
	return _require(ok,"ordinary controller reaches "+str(local_target))

func _capture(label: String,look_at: Vector3) -> void:
	var directory: String=OS.get_environment("SHOT_DIR")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	player.camera.look_at(world.adapter.root.to_global(look_at))
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	var file: String=directory.path_join(label+".png")
	var error: Error=get_viewport().get_texture().get_image().save_png(file)
	var feet: Vector3=world.adapter.root.to_local(player.global_position)
	captures[label]={"actual_feet":[feet.x,feet.y,feet.z],"look_at":[look_at.x,look_at.y,look_at.z],"png_written":error==OK}
	_require(error==OK,"actual reached standing view captured: "+label)

func _route() -> void:
	for point: Vector3 in [Vector3(-1.8,0,-3.3),Vector3(-1.8,0,-1.5),Vector3(-4.6,0,-1.5),Vector3(-4.9,0,-2.4)]:
		if not await _walk(point):return
	if not await _open_door("F01_WATCH_MAIL_DOOR"):return
	for point: Vector3 in [Vector3(-6.2,0,-2.4),Vector3(-7.1,0,-2.4)]:
		if not await _walk(point):return
	await _capture("mail_telephone",Vector3(-8.3,1.25,-1.3))
	mail_expected=await Mail.new().exercise(self)
	if mail_expected.is_empty():return
	if not await Telephone.new().exercise(self):return
	if not await _walk(Vector3(-7.1,0,-2.4)):return
	if not await _walk(Vector3(-7.3,0,-.85)):return
	if not await _open_door("F01_MAIL_PACKAGE_DOOR"):return
	for point: Vector3 in [Vector3(-7.3,0,1.6),Vector3(-7.8,0,2.4)]:
		if not await _walk(point):return
	await _capture("parcel_package",Vector3(-6.4,1.15,3.3))
	if not await _open_door("F01_PACKAGE_COMMON_DOOR"):return
	for point: Vector3 in [Vector3(-10.3,0,2.4),Vector3(-10.3,0,3.7),Vector3(-12.4,0,3.7)]:
		if not await _walk(point):return
	await _capture("common_reading",Vector3(-13.2,1.2,-1.5))
	await _capture("common_return",Vector3(-9.3,1.1,2.4))
	for point: Vector3 in [Vector3(-10.3,0,3.7),Vector3(-10.3,0,2.4),Vector3(-7.8,0,2.4),Vector3(-7.3,0,1.6),Vector3(-7.3,0,-.85),Vector3(-7.1,0,-2.4),Vector3(-4.9,0,-2.4),Vector3(-4.6,0,-1.5),Vector3(-1.8,0,-1.5),Vector3(-1.8,0,-3.3),Vector3(1.925,0,-3.5)]:
		if not await _walk(point):return
	var basement: Node=Basement.new();basement.externally_managed=true;basement.world=world;basement.player=player
	add_child(basement)
	# Its route starts at our reached F01 stance; never call its placement hook.
	await basement._route()
	for row: Dictionary in basement.trace:trace.append(row.duplicate(true))
	for row: Dictionary in basement.interaction_checks:interaction_checks.append(row.duplicate(true))
	for label: String in basement.failures:failures.append(label)
	basement.free()
	if not failures.is_empty():return
	# Cross behind the lower flight's actual first tread/guard, within the
	# authored south landing. First pass west of the real fire riser at
	# (4.89,-3.64) and its cabinet's authored x=4.025..4.675 envelope.
	# x=3.5 passes west of both before crossing behind the first tread.
	for point: Vector3 in [Vector3(5,-3.2,-.4),Vector3(5,-3.2,-3.1),Vector3(3.5,-3.2,-3.1),Vector3(3.5,-3.2,-3.5),Vector3(1.925,-3.2,-3.5),Vector3(-1.75,-3.2,-3.4),Vector3(-1.75,-3.2,-1.5)]:
		if not await _walk(point):return
	if not await _open_door("B1_LAUNDRY_DOOR"):return
	for point: Vector3 in [Vector3(-3.4,-3.2,-1.5),Vector3(-3.2,-3.2,-2.4),Vector3(-7,-3.2,-2.4),Vector3(-8.35,-3.2,-.15)]:
		if not await _walk(point):return
	await _capture("laundry_washers",Vector3(-8.8,-2.2,.8))
	var washer: WasherProp=world.adapter.resolve("B1_WASHER_01") as WasherProp
	if not _require(washer!=null,"actual powered wringer washer exists"):return
	# The parked wringer physically limits lid travel. Inspect the reachable
	# lid stop before moving the wringer; never force parts through one another.
	var parked_limit: float=washer._lid_limit(washer._yoke.rotation.y)
	if not _require(parked_limit>.01,"native parked wringer retains a usable lid clearance"):return
	if not await _drag_part(washer,washer.to_global(Vector3(.30,.91,-.38)),minf(deg_to_rad(15),parked_limit),"washer_lid_partial"):return
	if not _require(washer._lid_open,"physical lid opens within parked-wringer clearance"):return
	await _capture("washer_lid_clearance",world.adapter.root.to_local(washer.global_position+Vector3.UP*.8))
	for point: Vector3 in [Vector3(-7,-3.2,-.8),Vector3(-5.3,-3.2,1.6)]:
		if not await _walk(point):return
	var airer: LaundryAirerProp=world.adapter.resolve("B1_LAUNDRY_AIRER_01") as LaundryAirerProp
	if not _require(airer!=null,"actual ceiling drying rack exists"):return
	await _capture("laundry_airer",world.adapter.root.to_local(airer.global_position+Vector3.UP*1.8))
	if not await _drag_part(airer,airer._rack.to_global(Vector3(.35,0,0)),1.38,"airer_lower"):return
	if not _require(airer.is_airer_lowered(),"ceiling rack lowered by actual hand motion"):return
	await _capture("airer_lowered",world.adapter.root.to_local(airer.global_position+Vector3.UP*1.5))
	for point: Vector3 in [Vector3(-4,-3.2,0),Vector3(-3.4,-3.2,-1.5),Vector3(-1.75,-3.2,-1.5)]:
		if not await _walk(point):return
	_require(not player.noclip and player.collision_mask==1 and player.is_physics_processing(),"all programme travel retains ordinary physics")
