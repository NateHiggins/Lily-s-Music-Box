extends "res://tests/v2_fire_hand_bench.gd"
## Native-family diagnostic. Actual input, loaded surfaces and saved stock;
## this isolated fixture does not qualify the installed shop or played route.
const Counter := preload("res://scripts/building/fire_maintenance_counter.gd")
var radio_on := true
class ResidencyFixture extends Node3D:
	const CELLS := ["shop_hardware_paint"]
	var source_layout: Dictionary={"floors":[{"id":"F01","furniture":[
		{"id":"fixture_floor","batch":"shop_hardware_paint","rect":[-2.,-2.,2.,2.],"z0":-.20,"h":.20}]}]}
	func register_residency_client(_client: Node) -> bool:return true

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var orders:=WorkOrders.new();orders.setup(null);orders.bind_job_library(MaintenanceJobLibrary.load_default());add_child(orders)
	var items:=MaintenanceInventory.new();items.setup();add_child(items)
	var economy:=preload("res://scripts/game/caretaker_economy.gd").new();add_child(economy)
	check(economy.setup(orders),"existing economy binds")
	var merchant:=preload("res://scripts/game/v2_maintenance_shop_service.gd").new();add_child(merchant);merchant.setup(items,orders)
	var clearing:=preload("res://scripts/game/radio_clearing_network.gd").new()
	check(clearing.configure(economy,func():return radio_on,func(id: String):return id=="hardware_paint"),"existing radio state gates settlement")
	merchant.clearing=clearing
	var counter:=Counter.new();counter.name="FireMaintenanceCounter";add_child(counter);counter.position.y=1.12
	if not check(counter.configure(merchant),"native counter and two service products mount"):
		get_tree().quit(1);return
	var table:=StaticBody3D.new();add_child(table);table.position=Vector3(0,1.07,0)
	var table_shape:=CollisionShape3D.new();var table_box:=BoxShape3D.new();table_box.size=Vector3(1.5,.1,.65);table_shape.shape=table_box;table.add_child(table_shape)
	var table_draw:=MeshInstance3D.new();var table_mesh:=BoxMesh.new();table_mesh.size=table_box.size;table_draw.mesh=table_mesh;table.add_child(table_draw)
	var ground:=StaticBody3D.new();add_child(ground);ground.position.y=-.10
	var ground_shape:=CollisionShape3D.new();var ground_box:=BoxShape3D.new();ground_box.size=Vector3(4.,.20,4.);ground_shape.shape=ground_box;ground.add_child(ground_shape)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.5;add_child(light)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.11,.12,.13)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.65
	player=PlayerController.new();add_child(player);player.set_physics_process(false);player.position=Vector3(0,0,-.85);player.camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for frame in 5:await get_tree().physics_frame
	var metric: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for key: String in counter.stock.meshes:metric._check_cap_mapping(counter.stock.meshes[key],true)
	for failure: String in metric.failures:check(false,failure)
	check(metric.failures.is_empty(),"all nine imported stocks retain finite metric UVs and tangent frames")
	metric.free()
	for key: String in counter.stock.finishes:
		var finish: StandardMaterial3D=counter.stock.finishes[key]
		check(not finish.uv1_triplanar and finish.normal_enabled,"native UV and normal map: "+key)
		for texture: Texture2D in [finish.albedo_texture,finish.roughness_texture,finish.normal_texture]:
			check(texture!=null and texture.get_image().get_mipmap_count()>0,"loaded custom-map mips: "+key)
	var bottle: Node3D=counter.pickups.fire_hose_rubber_protectant
	await aim(bottle.to_global(Vector3(0,.08,-.034)))
	click();check(not player._grab.active(),"unpaid bottle cannot be carried and inspection does not bill it")
	var terminal: Node3D=counter.terminals.fire_hose_rubber_protectant
	radio_on=false
	check(await _stroke(terminal,.04),"actual click mouse travel release reaches the radio-off lever stop")
	check(not items.has_item("fire_hose_rubber_protectant") and int(economy.book().cash)==100,"radio-off stroke charges and delivers nothing")
	for frame in 30:await get_tree().physics_frame
	radio_on=true
	check(await _stroke(terminal,.02),"partial actual lever stroke")
	check(not items.has_item("fire_hose_rubber_protectant"),"partial pull does not buy")
	for frame in 20:await get_tree().physics_frame
	check(await _stroke(terminal,.04),"full actual lever stroke")
	check(items.has_item("fire_hose_rubber_protectant") and int(economy.book().cash)==75,"exact purchase owns bottle and debits25c")
	await aim(bottle.to_global(Vector3(0,.08,-.034)))
	click();check(player._grab.active() and player._grab.target.part==bottle,"paid bottle primary click grabs actual stock")
	for frame in 90:player._grab.follow_holder();await get_tree().physics_frame
	check(bottle._held and bottle.freeze,"bottle follows held stock without free rigid-body simulation")
	check(not bottle._hold_blocked and player.camera.to_local(bottle.to_global(bottle.pickup_centre())).distance_to(Vector3(.17,-.16,-.48))<.035,"bottle physically reaches the FPS hand pose")
	key(KEY_SPACE)
	check(player.inspecting() and player.inspect_owner==counter,"Space enters supported static inspection")
	for frame in 125:await get_tree().physics_frame
	var fixed_pose:=bottle.global_transform
	for frame in 10:await get_tree().physics_frame
	check(bottle.global_transform.is_equal_approx(fixed_pose),"floating inspection settles to a fixed pose")
	var cap_point: Vector3=bottle.cap.to_global(Vector3(0,.006,-.016))
	check(await acquire_surface(bottle.cap,cap_point),"free cursor identifies the captive cap")
	click()
	check(player._grab.active() and player._grab.target.part==bottle.cap,"primary click grabs cap instead of parent bottle")
	if player._grab.active():
		await _gesture_to(1.9)
		click()
	check(is_equal_approx(bottle.cap_turn,1.9) and not player._grab.active(),"actual mouse motion opens cap to its physical stop and next click releases")
	var saved: Dictionary=counter.mechanism_snapshot()
	check(counter.valid_mechanism(saved),"physical stock and cap have a valid household-save contract")
	check(not saved.fire_hose_rubber_protectant.parked,"static inspection freeze is transient in saved stock")
	check(not saved.fire_hose_rubber_protectant.stock.sleeping,"loaded inspection stock resumes gravity instead of sleeping in midair")
	key(KEY_SPACE)
	check(not player.inspecting() and player._grab.holding_pickup(),"leaving inspection returns the bottle to the held-stock path")
	if player._grab.active():click()
	check(not player._grab.active(),"next click releases held bottle")
	counter.restore_mechanism(saved)
	if not _same_saved_stock(counter.mechanism_snapshot(),saved):
		print("STOCK SAVE BEFORE ",JSON.stringify(saved))
		print("STOCK SAVE AFTER ",JSON.stringify(counter.mechanism_snapshot()))
	check(_same_saved_stock(counter.mechanism_snapshot(),saved),"stock and cap restore with float32 quaternion precision")
	var changed: Dictionary=saved.duplicate(true)
	changed.fire_hose_rubber_protectant.stock.position[0]+=.001
	check(not _same_saved_stock(counter.mechanism_snapshot(),changed),"save comparison rejects a millimetre of physical drift")
	# Separate policy/physics negative controls; these are not additional hand
	# gestures or a claim that the production streaming route has been walked.
	var region:=ResidencyFixture.new();add_child(region)
	check(counter.bind_residency(region),"stock residency derives bounds from the original floor record")
	bottle.freeze=false;bottle.sleeping=false
	bottle.contact_monitor=true;bottle.max_contacts_reported=8
	check(counter.wants_passage_geometry(),"moving unheld stock retains its physical region")
	for frame in 600:
		if bottle.sleeping:break
		if frame%120==0:print("STOCK FALL DIAGNOSTIC ",JSON.stringify({"frame":frame,"position":str(bottle.global_position),"velocity":str(bottle.linear_velocity),"spin":str(bottle.angular_velocity),"freeze":bottle.freeze,"colliders":str(bottle.get_colliding_bodies())}))
		await get_tree().physics_frame
	print("STOCK FALL END ",JSON.stringify({"position":str(bottle.global_position),"velocity":str(bottle.linear_velocity),"spin":str(bottle.angular_velocity),"freeze":bottle.freeze,"sleeping":bottle.sleeping,"colliders":str(bottle.get_colliding_bodies())}))
	check(bottle.sleeping,"released stock settles on a real physical support")
	if bottle.sleeping:
		var supported_pose: Dictionary=bottle.stock_snapshot()
		var supported_height: float=bottle.global_position.y
		remove_child(ground)
		for frame in 20:await get_tree().physics_frame
		check(not bottle.sleeping and bottle.global_position.y<supported_height-.05,"removing real support wakes stock and resumes falling")
		add_child(ground);bottle.restore_stock(supported_pose)
		for frame in 3:await get_tree().physics_frame
	var before_suspend: Dictionary=counter.mechanism_snapshot()
	counter.passage_geometry_dormant()
	check(bottle.freeze and counter.mechanism_snapshot()==before_suspend,"quiet suspension preserves durable pose, velocity and parked state")
	remove_child(table)
	remove_child(ground)
	var before_floor_removal:=bottle.global_transform
	for frame in 20:await get_tree().physics_frame
	check(bottle.global_transform==before_floor_removal,"suspended stock does not fall through a retired floor")
	add_child(table)
	add_child(ground)
	await counter.passage_geometry_active()
	check(not bottle.freeze and bottle.sleeping,"restored floor resumes the original sleeping body")
	bottle.freeze=true
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("counter.png"))
	print("FIRE MAINTENANCE HAND: %d checks, %d failures" % [observations.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _stroke(terminal: Node3D, goal: float) -> bool:
	await aim(terminal.lever.to_global(Vector3(0,.094,-.025)))
	click()
	if not player._grab.active() or player._grab.target.part!=terminal.lever:
		if player._grab.active():click()
		return false
	var moved: bool=await _gesture_to(goal)
	if player._grab.active():click()
	return moved and not player._grab.active()

func _same_saved_stock(left: Dictionary,right: Dictionary) -> bool:
	# Basis -> Quaternion -> Basis incurs float32 rounding. All other fields
	# remain exact; only equivalent rotation representations get this tolerance.
	if left.keys()!=right.keys():return false
	var a: Dictionary=left.duplicate(true);var b: Dictionary=right.duplicate(true)
	for identity: String in a:
		var qa: Array=a[identity].stock.rotation;var qb: Array=b[identity].stock.rotation
		var delta:=0.;var flipped:=0.
		for index in 4:
			delta+=pow(float(qa[index])-float(qb[index]),2.)
			flipped+=pow(float(qa[index])+float(qb[index]),2.)
		if minf(delta,flipped)>1e-12:return false
		a[identity].stock.erase("rotation");b[identity].stock.erase("rotation")
	return a==b

func _gesture_to(goal: float) -> bool:
	for step in 100:
		if not player._grab.active():return false
		var target: Dictionary=player._grab.target
		var remaining: float=goal-float(target.read.call())
		if absf(remaining)<.000001:return true
		var pixels: float=remaining/(float(target.maximum)-float(target.minimum))*float(target.gesture_travel_px)
		var event:=InputEventMouseMotion.new();event.relative=target.gesture_screen_axis*clampf(pixels,-12.,12.)
		player._unhandled_input(event);await get_tree().physics_frame
	return false
