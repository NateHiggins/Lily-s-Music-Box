extends "res://tests/v2_golden_repair_profile.gd"
## INERT: ordinary standing approach/carry and real disk reconstruction.
## Repaired-line assembly is an explicit staged precondition, not acceptance.
var helper: Node3D
var driver: Node
var hose_checks: Array=[]
var hose_motion: Array=[]
var aim_errors: Array=[]

func _init() -> void:route_label="V2 INSTALLED HOSE WORLD"
func _prepare_player_start() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	player.global_position=world.adapter.root.to_global(Vector3(1.925,.02,-3.5));player.velocity=Vector3.ZERO

func _check(ok: bool,label: String) -> bool:
	hose_checks.append({"label":label,"ok":ok});return _require(ok,label)

func _play_route() -> void:
	player.profile_physics=true
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	if not _check(native.stations.size()==8,"all eight production hose cabinets mount in the occupied world"):return
	for reference: WeakRef in native.stations.values():
		var cabinet: Node3D=reference.get_ref()
		if not _check(is_instance_valid(cabinet._live_hose) and not cabinet._live_hose.contact.ready and not cabinet._live_hose.is_processing() and not cabinet._live_hose.is_physics_processing(),"stored installed hose has no contact/cloth/fluid loop: "+str(cabinet.name)):return
	for point in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.65,3.2,-3.),Vector3(4.5,3.2,-2.95)]:
		if not await _walk(point):return
	profile_phase="cabinet_approach_stationary"
	var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
	var hose: Node3D=actor._live_hose
	var joint: Node3D=actor._nozzle_joint
	helper=preload("res://tests/v2_hose_production_hand_bench.gd").new();helper.set_meta("shared_world_validation",true);helper.player=player;add_child(helper)
	driver=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new();driver.player=player;add_child(driver)
	for frame in 60:await get_tree().process_frame
	profile_phase="actual_cabinet_open"
	if not _check(await driver.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual grab/motion/release opens the installed cabinet"):return
	# Stage the retained repair owners coherently. This diagnostic does not
	# claim procurement, gasket handoff, dressing or coupling assembly input.
	actor.gasket_seated=true;actor.coupling_made_up=true;actor.nozzle_coupled=true
	actor._union_angle=TAU*float(actor._joint_stock.data.dimensions.gasket_thickness_m)/float(actor._joint_stock.data.dimensions.pitch_m)
	actor._loose_union.active=false;actor._apply_hand_pose()
	var union_at:=Vector3(.17,actor._joint_stock.union_pose(actor._union_angle).origin.y,.098)
	actor._gasket_body.restore({"position":[union_at.x,union_at.y+.020,union_at.z],"rotation":[0.,0.,0.,1.]})
	joint.restore_legacy(true)
	if not _check(actor.valid_mechanism(actor.mechanism_snapshot()),"explicit assembled-line fixture is a valid physical household state"):return
	if not _check(await helper._aim_nozzle_surface(actor,joint,false),"walked stance reaches the specific installed nozzle surface"):return
	profile_phase="actual_extract"
	helper.click()
	for step in 50:
		if hose.deployed or not player._grab.active():break
		var point: Vector3=player._grab.target.part.to_global(player._grab.contact)
		var axis: Vector3=actor.global_basis*Vector3.BACK
		var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
		if screen.length()<24.:screen=Vector2(0,axis.dot(player.camera.global_basis.z)*180.)
		var event:=InputEventMouseMotion.new();event.relative=screen*.008
		player._unhandled_input(event);await get_tree().physics_frame
	print("INSTALLED HOSE EXTRACTION: ",JSON.stringify({"deployed":hose.deployed,"extraction":hose.extraction,"active":player._grab.active(),"kind":player._grab.target.get("kind",""),"hand":actor._hand,"error":hose.error,"registered_body":player.held_stock_body()==joint.body}))
	if not _check(hose.deployed and player._grab.holding_pickup() and player.held_stock_body()==joint.body,"actual installed pull continues directly into FPS carry"):return
	hose.profile_motion=true
	profile_phase="empty_held_turn"
	for step in 60:
		var event:=InputEventMouseMotion.new();event.relative=Vector2(1.5 if step<30 else -1.5,.2)
		player._unhandled_input(event);await RenderingServer.frame_post_draw
		aim_errors.append(rad_to_deg(acos(clampf(joint.body.global_basis.y.normalized().dot(-player.camera.global_basis.z),-1.,1.))))
		if not player._grab.active():break
	if not _check(player._grab.holding_pickup(),"ordinary turning retains the deployed hose"):return
	var aligned: bool=_check(aim_errors.max()<1.,"presented installed nozzle remains within one degree of reticle aim while turning")
	_write_checks()
	if not aligned:return
	await _picture("installed_held_nozzle")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("held_projection.json"),FileAccess.WRITE).store_string(JSON.stringify(helper.hand_projection(actor,hose),"\t"))
	if OS.get_environment("V2_HOSE_HAND_REVIEW_ONLY")=="1":
		hose_motion=hose.motion_profile_records.duplicate(true);_write_checks();return
	profile_phase="close_held_nozzle_input"
	helper.key(KEY_SPACE)
	if not _check(player.inspecting(),"held nozzle enters static free-cursor inspection before release"):return
	if not _check(await helper.inspect_operate(driver,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),0.),"actual held nozzle lever closes before floor placement"):return
	helper.key(KEY_ESCAPE)
	profile_phase="release_to_floor"
	helper.click()
	if not _check(hose.release_support.last_result.get("placed",false),"ordinary release places the installed nozzle on real floor support"):return
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("release_support.json"),FileAccess.WRITE).store_string(JSON.stringify(hose.release_support.last_result,"\t"))
	profile_phase="charge_control_input"
	await helper.aim(actor._tag.to_global(Vector3(0,0,.0035)));helper.click();helper.key(KEY_SPACE)
	if not _check(player.inspecting(),"actual tag grab enters the supported mechanism view"):return
	if not _check(await helper.inspect_operate(driver,actor._valve_wheel,actor._valve_wheel.to_global(Vector3(.04,0,0)),TAU*2.),"actual supply-wheel input charges the installed hose"):return
	profile_phase="first_fill"
	await get_tree().create_timer(4.).timeout
	if not _check(hose.water.pressure>.99 and hose.water.spray==0.,"installed closed nozzle holds full charge without spraying"):return
	helper.key(KEY_ESCAPE)
	if not _check(await helper._aim_nozzle_surface(actor,joint,false),"charged floor nozzle remains within reach from standing"):return
	helper.click()
	for frame in 3:await get_tree().process_frame
	helper.key(KEY_SPACE)
	if not _check(player.inspecting(),"charged nozzle returns to static inspection for its separate lever"):return
	profile_phase="first_spray_input"
	if not _check(await helper.inspect_operate(driver,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),-.95),"actual separate lever input starts first installed spray"):return
	profile_phase="steady_spray"
	await get_tree().create_timer(6.).timeout
	if not _check(hose.water.fill>.99 and hose.water.pressure>.79 and hose.water.spray>.7 and hose._spray!=null and hose._spray.emitting,"open installed supply sustains charge and spray without draining"):return
	await _picture("installed_spray")
	if not _check(await helper.inspect_operate(driver,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),0.),"actual nozzle lever stops spray"):return
	await get_tree().create_timer(.7).timeout
	helper.key(KEY_ESCAPE);helper.click()
	if not _check(hose.release_support.last_result.get("placed",false),"charged nozzle can be set down again before closing supply"):return
	await helper.aim(actor._tag.to_global(Vector3(0,0,.0035)));helper.click();helper.key(KEY_SPACE)
	if not _check(player.inspecting(),"cabinet valve remains independently accessible after nozzle placement"):return
	if not _check(await helper.inspect_operate(driver,actor._valve_wheel,actor._valve_wheel.to_global(Vector3(.04,0,0)),0.),"actual supply-wheel closure traps charge independently"):return
	helper.key(KEY_ESCAPE)
	if not _check(await helper._aim_nozzle_surface(actor,joint,false),"released deployed nozzle can be selected again at the unchanged standing stance"):return
	helper.click()
	for point in [Vector3(3.65,3.2,-3.),Vector3(3.975,3.2,-2.4),Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
		if not await _walk(point):return
	if not _check(player._grab.holding_pickup() and not player.noclip and player.is_on_floor(),"charged hose follows ordinary standing walking and stair descent"):return
	helper.click()
	if not _check(hose.release_support.last_result.get("placed",false),"remote stair-carried nozzle rests on real floor support"):return
	var wanted: Dictionary=actor.mechanism_snapshot()
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("remote_state.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","cabinet":wanted,"valid":actor.valid_mechanism(wanted),"nozzle_valid":joint.valid(wanted.nozzle,wanted.facts.nozzle_coupled),"hose_valid":hose.valid_deployment(wanted.hose)},"\t"))
	if not _check(actor.valid_mechanism(wanted) and wanted.hose.deployed and wanted.hose.water.pressure>.99,"released remote charged hose has a valid household payload"):return
	if not _check(await helper._aim_nozzle_surface(actor,joint,false),"remote released nozzle remains targetable away from its cabinet"):return
	helper.click();helper.key(KEY_SPACE)
	if not _check(player.inspecting() and player.inspect_owner==actor,"remote nozzle enters supported inspection without returning to cabinet"):return
	await _picture("remote_nozzle_inspection")
	helper.key(KEY_ESCAPE);player.cancel_manipulation()
	wanted=actor.mechanism_snapshot();hose_motion=hose.motion_profile_records.duplicate(true)
	if not _check(hose.contact.broad_queries==0 and hose.contact.shell_queries==0 and not hose.is_processing() and not hose.is_physics_processing(),"installed stable hose has no environment-query, cloth or fluid tick"):return
	await _save_reload(wanted)
	_write_checks()

func _picture(name: String) -> void:
	var old:=profile_phase;profile_phase="capture_excluded_"+name
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name+".png"))
	await get_tree().process_frame;profile_phase=old

func _save_reload(wanted: Dictionary) -> void:
	profile_active=false
	_write_checks();_write_profile("before_world_rebuild")
	var previous_path: String=RealityState.save_path
	var test_path: String="user://v2_hose_world_%d.json"%Time.get_ticks_usec()
	RealityState.save_path=test_path
	var saved: bool=RealityState.save_game()
	_check(saved,"real disk save captures deployed charged hose through the sole household owner")
	if saved:
		world.shutdown_for_tests();world.free();RealityState.reset_campaign_for_tests();RealityState.load_game()
		world=Runtime.instantiate();add_child(world)
		if _check(not world.startup_failed,"production world reconstructs from deployed charged hose save"):
			player=world.player;helper.player=player;driver.player=player;player.camera.make_current()
			var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
			var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
			var actual: Dictionary=actor.mechanism_snapshot()
			var comparison: Dictionary=preload("res://tests/hose_saved_pose_comparison.gd").compare(actual,wanted)
			FileAccess.open(OS.get_environment("SHOT_DIR").path_join("rebuild_comparison.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","actual":actual,"wanted":wanted,"comparison":comparison},"\t",true,true))
			_check(actor.valid_mechanism(actual) and comparison.equal,"disk rebuild restores physical poses within10um, wheel within1e-12rad and identical water and maintenance facts")
			_check(actor._live_hose.deployed and actor._live_hose.model.visible and not actor._folds.visible,"reconstructed world shows the extended native skin and hides stored stock")
	RealityState.save_path=previous_path
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var path:=ProjectSettings.globalize_path(test_path+suffix)
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)

func _write_checks() -> void:
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("hose_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual installed approach, operation, stair carrying and disk rebuild; repaired assembly staged. No full payout, all-area coverage, runtime_contract or human acceptance.","checks":hose_checks,"motion_calls":hose_motion,"aim_errors_degrees":aim_errors,"failures":failures},"\t"))
