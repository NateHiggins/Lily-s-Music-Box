extends Node3D
const Bell = preload("res://scripts/dream/critters/guide_bell.gd")
const Route = preload("res://scripts/dream/critters/guide_bell_route.gd")
const ErrorCapture = preload("res://tests/guide_bell_error_capture.gd")
var failures: Array[String]=[]
var checks: Array[Dictionary]=[]
var directory := ""
var started := Time.get_ticks_msec()
var history: Array=[]
var measurements: Dictionary={}
var player: PlayerController
var bell: Node3D
var lamp_driver: Node

func _ready() -> void: _run.call_deferred()
func _process(delta: float) -> void:
	if is_instance_valid(lamp_driver): lamp_driver.advance_frame(delta)
func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
	print("GUIDE BELL: ",label," = ",ok)
func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
func operate_supply(radiator: RadiatorProp,value: float) -> bool:
	var pose:=player.camera.global_transform
	var hand:=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new()
	add_child(hand); hand.player=player
	var point: Vector3=radiator._wheel.global_position+radiator.global_basis*Vector3(0,0,-.045)
	var moved: bool=await hand.operate(point,value*TAU*3.5,radiator)
	hand.queue_free(); player.camera.global_transform=pose
	return moved and absf(radiator.supply_position-value)<.00001
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	var at := player.camera.unproject_position(bell.global_position+Vector3.UP*.36)
	var energy:=0.0; var count:=0
	for y in range(maxi(0,int(at.y)-90),mini(image.get_height(),int(at.y)+90),4):
		for x in range(maxi(0,int(at.x)-65),mini(image.get_width(),int(at.x)+65),4):
			var c:=image.get_pixel(x,y); energy+=(c.r+c.g+c.b)/3.0; count+=1
	measurements[label]=energy/maxi(count,1)

func body(at: Vector3,size: Vector3) -> StaticBody3D:
	var owner:=StaticBody3D.new(); owner.position=at
	var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape
	owner.add_child(collision); add_child(owner)
	var draw:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; draw.mesh=mesh
	var material:=StandardMaterial3D.new(); material.albedo_color=Color(.22,.24,.23); material.roughness=.9
	draw.material_override=material; owner.add_child(draw)
	return owner

func _run() -> void:
	var logger:=ErrorCapture.new(); OS.add_logger(logger)
	check(load("res://scripts/dream/critters/guide_bell_director.gd")!=null,"production director script compiles")
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory="user://guide_bell"
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false; RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.launch_mode=GameBoot.LaunchMode.DEBUG
	var saved: String
	var environment:=WorldEnvironment.new(); var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR; settings.background_color=Color(.015,.02,.025)
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color=Color(.15,.16,.2); settings.ambient_light_energy=.08
	environment.environment=settings; add_child(environment)
	var floor_owner:=body(Vector3(0,-.1,0),Vector3(16,.2,16))
	var wall:=body(Vector3(2,1.5,0),Vector3(.2,3,7))
	player=PlayerController.new(); add_child(player); player.set_physics_process(false); player.set_process(false)
	player.set_process_input(false); player.set_process_unhandled_input(false)
	player.position=Vector3(-.8,.035,-1.5); player.camera.position.y=.85; player.camera.fov=42
	player.camera.look_at(Vector3(0,.34,0)); player.camera.make_current(); player.mouse_released=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for canvas in player.find_children("*","CanvasLayer",true,false): canvas.visible=false
	var atmosphere:=preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new(); atmosphere.name="LampAtmosphere"; add_child(atmosphere)
	check(atmosphere.setup(player,settings),"shared carried lamp optical field")
	lamp_driver=atmosphere.driver
	player.flashlight.global_position=player.camera.global_position-player.camera.global_basis.z*.65-Vector3.UP*.15
	player.flashlight.look_at(Vector3(0,.35,0))
	player.set_lamp_enabled(true)
	for i in 240: atmosphere.driver.advance_frame(1.0/120.0)
	await get_tree().physics_frame
	var baseline: int=atmosphere.field._materials.size() if atmosphere.field!=null else 0
	var radiator:=RadiatorProp.new(); radiator.use_native_v2=true; radiator.position=Vector3(.35,0,.6); add_child(radiator)
	await get_tree().physics_frame
	saved=JSON.stringify(RealityState.data)
	bell=Bell.new(); add_child(bell)
	check(bell.start({"owner":floor_owner,"position":Vector3.ZERO,"coordinate":Vector3.ZERO},10.0,Vector3(1,0,0),61025,1.0,atmosphere.field),"native Vorticella starts on stable attachment")
	await wait_seconds(1.5)
	check(bell.state==Bell.State.INDICATING,"germination enters indicating")
	check(bell.symbionts.size()==3,"three private Euplotes at mature holdfast")
	check(bell.global_position==Vector3.ZERO,"holdfast remains sessile")
	check(bell.find_children("*","CollisionObject3D",true,false).is_empty(),"guide anatomy owns no blocking or grabbing collision")
	var refs: Array[WeakRef]=[]
	for material in bell.materials:
		refs.append(weakref(material))
		for channel in ["albedo","normal","roughness"]:
			var texture: Texture2D=material.get_shader_parameter(channel+"_map")
			check(texture!=null and texture.get_image().has_mipmaps(),"loaded custom "+channel+" mip chain")
	await capture("01_front_anatomy")
	player.set_lamp_enabled(false); await wait_seconds(.8); await capture("02_lamp_off")
	check(float(measurements["01_front_anatomy"])>float(measurements["02_lamp_off"])+.005,"lamp off removes optical response")
	player.set_lamp_enabled(true); await wait_seconds(.8)
	var lamp_pose:=player.flashlight.transform
	player.flashlight.global_position=Vector3(-1.0,.65,0); player.flashlight.look_at(Vector3(0,.35,0))
	await wait_seconds(.3); await capture("03_side_stalk")
	player.flashlight.global_position=Vector3(-.7,.65,1.1); player.flashlight.look_at(Vector3(0,.35,0))
	await wait_seconds(.3); await capture("04_backlit_anatomy")
	player.flashlight.transform=lamp_pose
	bell.update_progress(true,11.0,.1); check(bell.state==Bell.State.INDICATING,"farther route distance stays alive")
	bell.update_progress(true,10.0,.1); check(bell.state==Bell.State.INDICATING,"equal distance stays alive")
	bell.update_progress(true,9.46,.1); check(bell.state==Bell.State.INDICATING,"strict pass margin")
	bell.update_progress(true,9.4,.1); check(bell.state==Bell.State.PASSED_PENDING,"closer route distance starts pending")
	bell.update_progress(true,10.0,.1); check(bell.state==Bell.State.INDICATING,"jitter cancels pending")
	bell.update_progress(true,9.0,.1); await wait_seconds(.42); bell.update_progress(true,9.0,.01)
	check(bell.state==Bell.State.WILTING,"sustained pass commits irreversible wilt")
	await capture("05_wilt_begin")
	bell.update_progress(true,20.0,.1); check(bell.state==Bell.State.WILTING,"backtracking cannot revive")
	await wait_seconds(.8); await capture("06_mid_wilt")
	await wait_seconds(.95); await capture("07_retraction")
	await wait_seconds(1.0)
	check(bell.state==Bell.State.CLEARED and bell.get_child_count()==0,"anatomical retraction releases all geometry")
	check(bell.materials.is_empty() and bell.symbionts.is_empty() and bell.optical_field==null and bell.surface==null,"no retained per-cell owners")
	for reference in refs: check(reference.get_ref()==null,"material allocation released")
	if atmosphere.field!=null: check(atmosphere.field._materials.size()==baseline,"receiver census restored")
	history.append(bell.census()); await capture("08_clean")
	check(JSON.stringify(RealityState.data)==saved,"maintenance inventory case and save bytes unchanged by presentation")
	player.position=Vector3(-.18,0,-.75); player.camera.position.y=.85
	var valve_before:=radiator.supply_position
	check(await operate_supply(radiator,.95),"actual grab motion and release operates maintenance valve after cleanup")
	check(await operate_supply(radiator,valve_before),"actual input restores original valve state")
	radiator.free(); await get_tree().physics_frame
	# Real collision-negative controls exercise the same provider as production.
	var route:=Route.new(); route.world=self; route.exclude=[player.get_rid()]; route.capsule.radius=.29; route.capsule.height=1.25
	check(not route.supported(Vector3(0,.035,0),Vector3(4,.035,0)),"wall rejects Euclidean shortcut")
	check(route.supported(Vector3(0,.035,0),Vector3(0,.035,4)),"loaded supported corridor admitted")
	check(not route.supported(Vector3(0,.035,0),Vector3(0,.035,10)),"missing floor fails closed")
	var path:=PackedVector3Array([Vector3(0,.035,0),Vector3(0,.035,4),Vector3(4,.035,4),Vector3(4,.035,0)])
	for i in path.size(): route.graph.add_point(i,path[i])
	for i in range(path.size()-1): route.graph.connect_points(i,i+1); route.edges.append(Vector2i(i,i+1))
	var proven: PackedVector3Array=route.request(path[0],path[-1])
	check(proven.size()>2 and Route.length(proven)>10,"provider routes around physical wall")
	check(is_equal_approx(float(Route.project(path,Vector3(0,.035,3)).remaining),9.0),"route progress sums traversal distance")
	check(Route.project(path,Vector3(4,3.235,0)).gap>3,"upper floor does not project as passed")
	var closure:=body(Vector3(2,1.5,4),Vector3(10,3,.2)); await get_tree().physics_frame
	check(route.request(path[0],path[-1]).is_empty(),"closed traversal invalidates supported path")
	closure.free()
	# A physical supported slope is the stair transition control. A parallel
	# vertical shortcut has no continuous support and must be refused.
	var ramp:=body(Vector3(-4,.8,0),Vector3(1.3,.12,sqrt(18.56)))
	ramp.rotation.x=-atan(.4)
	var landing:=body(Vector3(-4,1.55,2.8),Vector3(1.3,.1,1.6))
	await get_tree().physics_frame
	var bottom:=Vector3(-4,.10,-2); var top:=Vector3(-4,1.70,2)
	check(route.supported(bottom,top),"continuous physical stair-slope support accepted")
	check(not route.supported(bottom,Vector3(-4,1.70,-2)),"vertical shortcut between floors rejected")
	landing.free(); ramp.free()
	# Immediate teardown must not wait for an animation.
	var cancel:=Bell.new(); add_child(cancel)
	cancel.start({"owner":floor_owner,"position":Vector3.ZERO,"coordinate":Vector3.ZERO},5,Vector3.RIGHT,1,.5,atmosphere.field)
	cancel.clear_immediately("task_cancelled")
	check(cancel.state==Bell.State.CLEARED and cancel.get_child_count()==0,"task cancellation clears synchronously")
	cancel.free()
	check(logger.errors.is_empty(),"no engine script shader errors")
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":false,
		"scope":"Production guide-bell lifecycle and shared lamp in isolated collision fixture; not composed-world route acceptance",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/tests/guide_bell_contract.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
		"contracts":{"guide_bells":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},
		"checks":checks,"failures":failures,"engine_errors":logger.errors,"crumbs":history,"optical_roi":measurements,"retained_resource_result":bell.materials.size()}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	OS.remove_logger(logger); get_tree().quit(0 if failures.is_empty() else 1)
