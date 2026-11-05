extends "res://tests/v2_golden_repair_profile.gd"
## INERT: ordinary standing approach/carry and real disk reconstruction.
## Repaired-line assembly is an explicit staged precondition, not acceptance.
var helper: Node3D
var driver: Node
var hose_checks: Array=[]
var hose_motion: Array=[]
var aim_errors: Array=[]
var _completed_hose_route := false
var _b1_hold_deadline := 0
const PAYOUT_ACTIONS: Array[StringName] = [&"move_left",&"move_right",&"move_forward",&"move_back"]

func _payout_mode() -> String:
	return OS.get_environment("V2_B1_OCCUPIED_PAYOUT")

func _init() -> void:route_label="V2 INSTALLED HOSE WORLD"
func _prepare_player_start() -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	if _payout_mode() in ["preflight","full"]:
		route_label = "V2 B1 OCCUPIED HOSE PAYOUT"
		player.global_position = world.adapter.root.to_global(Vector3(4.95,-3.18,-2.35))
		player.velocity = Vector3.ZERO
		return
	player.global_position=world.adapter.root.to_global(Vector3(1.925,.02,-3.5));player.velocity=Vector3.ZERO

func _check(ok: bool,label: String) -> bool:
	hose_checks.append({"label":label,"ok":ok});return _require(ok,label)

func _route() -> void:
	await super._route()
	if _payout_mode() in ["preflight","full"]:
		return
	if OS.get_environment("V2_INSTALLED_REPAIR_CHAIN") == "1" and OS.get_environment("V2_HOSE_HAND_REVIEW_ONLY") != "1":
		_check(_completed_hose_route, "installed hose route reaches disk reconstruction and records its checks")
	_write_checks()

func _play_route() -> void:
	player.profile_physics=true
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	if not _check(native.stations.size()==8,"all eight production hose cabinets mount in the occupied world"):return
	for reference: WeakRef in native.stations.values():
		var cabinet: Node3D=reference.get_ref()
		if not _check(is_instance_valid(cabinet._live_hose) and not cabinet._live_hose.contact.ready and not cabinet._live_hose.is_processing() and not cabinet._live_hose.is_physics_processing(),"stored installed hose has no contact/cloth/fluid loop: "+str(cabinet.name)):return
	if not _payout_mode().is_empty():
		if _check(_payout_mode() in ["preflight","full"],"B1 payout mode is preflight or full"):
			await _b1_payout(native)
		return
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
	if not await _prepare_repaired_line(actor,joint):return
	if not await _extract_installed_nozzle(actor,hose,joint):return
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
	if not _check(hose._wet_timer == null and hose._swept_jet == null and not hose._spray.emitting, "installed closed charge keeps both transient pools unallocated"):return
	profile_phase="first_spray_input"
	if not _check(await helper.inspect_operate(driver,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),-.95),"actual separate lever input starts first installed spray"):return
	profile_phase="steady_spray"
	await get_tree().create_timer(6.).timeout
	var jet_slots: int = hose._swept_jet.multimesh.visible_instance_count if hose._swept_jet != null else 0
	var splash_slots: int = hose._swept_splash_draw.multimesh.visible_instance_count if hose._swept_splash_draw != null else 0
	var spray_report := {
		"water": hose.water.snapshot(),
		"flow": hose.water.spray,
		"muzzle": var_to_str(hose._spray.global_transform),
		"nozzle": var_to_str(joint.body.global_transform),
		"player": var_to_str(player.global_transform),
		"jet_slots": jet_slots,
		"splash_slots": splash_slots,
		"gpu_emitting": hose._spray.emitting,
		"stats": hose.swept_stats,
		"first_solid": hose.last_swept_impact,
		"inspection_origin": hose.inspection_origin_witness,
		"film": var_to_str(hose.last_spray_impact),
	}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("installed_spray.json"), FileAccess.WRITE).store_string(JSON.stringify(spray_report, "\t"))
	_check(jet_slots > 0 and not hose._spray.emitting, "open installed nozzle draws the swept jet")
	if OS.get_environment("V2_INSTALLED_REPAIR_CHAIN") == "1":
		var first_path: String = hose.last_swept_impact.get("path", "")
		var witness: Dictionary = hose.inspection_origin_witness
		var inspector_rid: String = str(player.get_rid())
		var retries_bounded: bool = hose.swept_stats.inspection_origin_retries <= hose.swept_stats.visual_rays + hose.swept_stats.wet_rays
		_check(witness.get("inspector_rid", "") == inspector_rid and witness.get("retry_rid", inspector_rid) != inspector_rid and retries_bounded,
			"installed outbound launch retries its exact inspector overlap once per ray")
		_check(not first_path.is_empty() and first_path != str(player.get_path()),
			"installed swept jet reaches a different first solid")
		var film: Dictionary = hose.last_spray_impact
		var normal: Vector3 = film.get("normal", Vector3.ZERO)
		var velocity: Vector3 = film.get("velocity", Vector3.ZERO)
		_check(film.get("accepted", false) and normal.y >= .99 and velocity.y < 0. and splash_slots > 0
			and str(film.get("rid", RID())) == hose.last_swept_impact.get("rid", ""),
			"installed descending jet splashes and wets the exact first floor receiver")
	await _picture("installed_spray")
	if not _check(hose.water.fill > .99 and hose.water.pressure > .79 and hose.water.spray > .7, "open installed supply sustains charge and spray without draining"):return
	if not _check(await helper.inspect_operate(driver,actor._lever,actor._lever.to_global(Vector3(.07,0,0)),0.),"actual nozzle lever stops spray"):return
	await get_tree().create_timer(.7).timeout
	if not _check(hose.water.spray == 0. and hose._swept_jet.multimesh.visible_instance_count == 0, "installed lever closure retires the jet after its final flight"):return
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
	_completed_hose_route = true

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
			_check(actor.valid_mechanism(actual) and comparison.equal,"disk rebuild restores physical poses within10um, control and nozzle angles within1e-12rad and identical water and maintenance facts")
			var restored_hose: Node3D = actor._live_hose
			_check(restored_hose._wet_timer == null and restored_hose._swept_jet == null and not restored_hose._spray.emitting, "closed charged hose rebuild has no transient water effects")
			_check(actor._live_hose.deployed and actor._live_hose.model.visible and not actor._folds.visible,"reconstructed world shows the extended native skin and hides stored stock")
	RealityState.save_path=previous_path
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var path:=ProjectSettings.globalize_path(test_path+suffix)
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)

func _write_checks() -> void:
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("hose_checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual installed approach, operation, stair carrying and disk rebuild. Repaired-line preparation defaults to a staged fixture; overrides record their assembly input separately. No full payout, all-area coverage, runtime_contract or human acceptance.","checks":hose_checks,"motion_calls":hose_motion,"aim_errors_degrees":aim_errors,"failures":failures},"\t"))

func _prepare_repaired_line(actor: Node3D,joint: Node3D) -> bool:
	# Stage the retained repair owners coherently. This diagnostic does not
	# claim procurement, gasket handoff, dressing or coupling assembly input.
	actor.gasket_seated=true;actor.coupling_made_up=true;actor.nozzle_coupled=true
	actor._union_angle=TAU*float(actor._joint_stock.data.dimensions.gasket_thickness_m)/float(actor._joint_stock.data.dimensions.pitch_m)
	actor._loose_union.active=false;actor._apply_hand_pose()
	var union_at:=Vector3(.17,actor._joint_stock.union_pose(actor._union_angle).origin.y,.098)
	actor._gasket_body.restore({"position":[union_at.x,union_at.y+.020,union_at.z],"rotation":[0.,0.,0.,1.]})
	joint.restore_legacy(true)
	return _check(actor.valid_mechanism(actor.mechanism_snapshot()),"explicit assembled-line fixture is a valid physical household state")

func _extract_installed_nozzle(actor: Node3D, hose: Node3D, joint: Node3D) -> bool:
	if not _check(await helper._aim_nozzle_surface(actor,joint,false),"walked stance reaches the specific installed nozzle surface"):return false
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
	if not _check(hose.deployed and player._grab.holding_pickup() and player.held_stock_body()==joint.body,"actual installed pull continues directly into FPS carry"):return false
	return true

# B1 is an opt-in diagnostic in the same occupied runtime. Keep the native
# storage closer active and include its leaf in independent geometry queries.
func _b1_payout(native: RefCounted) -> void:
	var actor: Node3D = native.stations.B1_FIRE_LINE_STAIR.get_ref()
	var hose: Node3D = actor._live_hose
	var joint: Node3D = actor._nozzle_joint
	var anchor: Node3D = world.adapter.resolve("B1_STORAGE_DOOR")
	var door: DoorProp = anchor.get_node_or_null("B1_STORAGE_DOOR_Leaf") as DoorProp if anchor != null else null
	for frame in 8:
		await get_tree().physics_frame
	var mask := player.collision_mask
	var rows: Array[Dictionary] = []
	var outcome := {"evidence_class":"INERT", "mode":_payout_mode(), "samples":rows, "geometry":"unmeasured", "reach":"unmeasured", "support":"unmeasured"}
	await _b1_payout_attempt(actor, hose, joint, door, mask, outcome, rows)
	for action: StringName in PAYOUT_ACTIONS:
		Input.action_release(action)
	if not _check(get_viewport().get_visible_rect().size == Vector2(3440, 1440), "B1 native viewport is 3440x1440"):
		outcome.capture_size = str(get_viewport().get_visible_rect().size)
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	var png: int = get_viewport().get_texture().get_image().save_png(directory.path_join("b1_payout_final.png"))
	_check(png == OK, "B1 final native frame written")
	var file := FileAccess.open(directory.path_join("b1_payout.json"), FileAccess.WRITE)
	if _check(file != null, "B1 payout output is writable"):
		outcome.failures = failures
		outcome.checks = hose_checks
		file.store_string(JSON.stringify(outcome, "\t", true, true))

func _b1_payout_attempt(actor: Node3D, hose: Node3D, joint: Node3D, door: DoorProp, mask: int, outcome: Dictionary, rows: Array[Dictionary]) -> void:
	if not _check(door != null and is_instance_valid(door._body) and door._easy != null, "B1 storage uses the mounted physical leaf and ordinary closer"):
		return
	var from := Vector3(4.95,-3.2,-2.35)
	var stair_exit := Vector3(4.95,-3.2,1.95)
	var near_door := Vector3(4.46,-3.2,3.05)
	var far_door := Vector3(4.46,-3.2,4.55)
	var pickup := Vector3(4.5,-3.2,-2.95)
	var northeast := Vector3(.766,0,.643)
	var intermediate_heading := Vector3(.423,0,.906)
	# First resolve the live walking strip and traverse the actual open leaf.
	for point: Vector3 in [from,stair_exit,near_door]:
		if not await _payout_walk(point,Vector3.BACK,actor,hose,joint,door,mask,rows,false):
			return
	helper=preload("res://tests/v2_hose_production_hand_bench.gd").new();helper.set_meta("shared_world_validation",true);helper.player=player;add_child(helper)
	driver=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new();driver.player=player;add_child(driver)
	if not await _payout_open_leaf(door):
		return
	if not await _payout_walk(far_door,northeast,actor,hose,joint,door,mask,rows,false):
		return
	if not await _payout_open_leaf(door):
		return
	for point: Vector3 in [near_door,stair_exit,from,pickup]:
		if not await _payout_walk(point,Vector3.BACK,actor,hose,joint,door,mask,rows,false):
			return
	if not _check(await driver.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual input opens B1 cabinet"):
		return
	if not _prepare_repaired_line(actor,joint) or not await _extract_installed_nozzle(actor,hose,joint):
		return
	var water: Dictionary = hose.water.snapshot()
	if not _check(hose.water.fill == 0. and hose.water.pressure == 0. and hose.water.spray == 0.,"B1 payout starts dry with supply untouched"):
		return
	var aux: Array = hose._auxiliary_contacts.duplicate(true)
	var owner_contacts: Array = hose._contact_exclusions.duplicate()
	outcome.anchor_world = str(hose.model.to_global(hose.rig.strand.anchor))
	var owner_source: Vector3 = hose.model.to_global(hose.rig.strand.anchor)
	_b1_hold_deadline = Time.get_ticks_msec()+90000
	# Move inward across the north landing as the nozzle turns. From the
	# edge of the stair strip, the full turn puts the barrel in the shop wall.
	for leg: Array in [[from,Vector3.BACK],[stair_exit,Vector3.BACK],
			[Vector3(4.80,-3.2,2.25),Vector3.BACK],
			[Vector3(4.62,-3.2,2.65),intermediate_heading],
			[near_door,northeast],[far_door,northeast]]:
		if not await _payout_walk(leg[0],leg[1],actor,hose,joint,door,mask,rows,true):
			outcome.geometry = _payout_result(rows)
			return
	outcome.geometry = "clear_at_sampled_positions_through_storage_threshold"
	if _payout_mode() == "preflight":
		for tick in 8:
			await get_tree().create_timer(.5).timeout
			var closure := _payout_sample(actor,hose,joint,door,mask,true)
			closure.target = "stationary_after_storage_threshold"
			rows.append(closure)
			if not _check(closure.held and closure.crossing.is_empty() and closure.envelope.is_empty(),"ordinary storage closer leaves sampled held line clear"):
				outcome.geometry = _payout_result(rows)
				return
	if _payout_mode() == "full":
		for leg: Array in [[Vector3(4.95,-3.2,4.9),Vector3.BACK],[Vector3(4.95,-3.2,8.6),Vector3.BACK],[Vector3(4.52,-3.2,9.0),northeast],[Vector3(4.52,-3.2,11.23),northeast]]:
			if not await _payout_walk(leg[0],leg[1],actor,hose,joint,door,mask,rows,true,leg[0].z>11.):
				outcome.geometry = _payout_result(rows)
				return
		var final: Dictionary = rows.back()
		var at_limit: bool = final.span_m >= 15.089 and final.span_m <= 15.091 and final.receiver_span_m >= 15.089 and final.receiver_span_m <= 15.091
		var fixed_source: bool = hose.model.to_global(hose.rig.strand.anchor).is_equal_approx(owner_source) and hose.rig.strand.points[-1] == hose.rig.strand.anchor
		var aim: float = rad_to_deg(acos(clampf(joint.body.global_basis.y.normalized().dot(-player.camera.global_basis.z),-1.,1.)))
		outcome.geometry = "clear_at_sampled_positions_to_terminal"
		outcome.reach = "at_bound" if at_limit else "missed_bound"
		if not _check(at_limit and absf(hose.rig.strand.total_length-15.24)<.00002 and fixed_source and aim<1. and hose.visual_route.limited and player._grab.feedback({}).state=="limit","B1 actual FPS movement reaches the original fixed-source stock bound and reticle limit"):
			return
		await _picture("b1_at_limit")
		var rest_foot: Vector3 = world.adapter.root.to_local(player.global_position)-Vector3.BACK*.25
		if not await _payout_walk(rest_foot,northeast,actor,hose,joint,door,mask,rows,true):
			outcome.geometry = _payout_result(rows)
			return
	if not _check(hose.water.snapshot()==water and actor.valid_mechanism(actor.mechanism_snapshot()),"B1 route preserves dry water authority and validates deployed mechanism"):
		return
	helper.click()
	var resting: PackedVector3Array = hose.rig.strand.points.duplicate()
	for frame in 12:
		await get_tree().physics_frame
	outcome.support = hose.release_support.last_result.duplicate(true)
	var restored := true
	for row: Dictionary in aux:
		restored = restored and (not row.holder_added or not player.get_collision_exceptions().has(row.body)) and (not row.part_added or not row.body.get_collision_exceptions().has(player))
	_check(outcome.support.get("placed",false) and not player._grab.active() and hose.rig.strand.points==resting and not hose.is_processing() and not hose.is_physics_processing() and hose.contact.exclusions==owner_contacts and restored,"actual primary releases to real support and restores hose-owned exclusions")

func _payout_open_leaf(door: DoorProp) -> bool:
	var goal := door.motion_target_angle(true)
	if door.is_ready_for_passage() and absf(door._body.rotation.y-goal)<.03 and not door._easy.closing:
		return true
	# Open or reopen through the actual leaf. Leave the closer and its
	# ordinary temporary player/stock collision accommodations intact.
	var handle: Vector3 = door._body.to_global(Vector3(door.width*.5,1.1,0.))
	if not _check(await driver.operate(handle,goal,door),"actual B1 storage leaf grab, motion and release"):
		return false
	await get_tree().physics_frame
	return _check(door.is_ready_for_passage() and absf(door._body.rotation.y-goal)<.03,"actual B1 storage opening settles")

func _payout_turn(local_direction: Vector3) -> bool:
	var aim: Vector3 = world.adapter.root.global_basis * local_direction
	var yaw := atan2(-aim.x,-aim.z)
	var sensitivity := clampf(float(GameBoot.settings.get("look_sensitivity",1.)),.25,2.)
	for step in 100:
		# Acquisition helpers aim the real camera locally. Steer from its
		# actual world ray, including that relative yaw, through mouse events.
		var forward := -player.camera.global_basis.z.normalized()
		var turn := wrapf(yaw-atan2(-forward.x,-forward.z),-PI,PI)
		var pitch: float = asin(clampf(forward.y,-1.,1.))
		if absf(turn)<.01 and absf(pitch)<.01:
			return true
		var local_forward := player.global_basis.inverse()*forward
		var pitch_control := -local_forward.z
		var pitch_input := pitch/pitch_control if absf(pitch_control)>.10 else 0.
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(-clampf(turn,-.08,.08),clampf(pitch_input,-.08,.08))/(player.MOUSE_SENS*sensitivity)
		player._unhandled_input(event)
		await get_tree().physics_frame
	return false

func _payout_walk(target: Vector3, heading: Vector3, actor: Node3D, hose: Node3D, joint: Node3D, door: DoorProp, mask: int, rows: Array[Dictionary], held: bool, stop_at_limit := false) -> bool:
	profile_phase = "b1_held_walk" if held else "b1_empty_walk"
	var aimed := await _payout_turn(heading)
	var goal: Vector3 = world.adapter.root.to_global(target)
	var started := Time.get_ticks_msec()
	var last_sample := Vector3.INF
	var wall_contacts := {}
	var deadzone := 0.
	for action: StringName in PAYOUT_ACTIONS:
		deadzone += InputMap.action_get_deadzone(action)*.25
	var arrived := false
	while aimed and Time.get_ticks_msec()-started < 13000 and (not held or Time.get_ticks_msec()<_b1_hold_deadline):
		var at := player.global_position
		var delta := goal-at
		delta.y=0.
		var receiver: Vector3 = actor.to_global(joint.receiver.origin)
		var span: float = receiver.distance_to(hose.model.to_global(hose.rig.strand.anchor))
		var grip_ok: bool = not held or (player._grab.holding_pickup() and player.held_stock_body()==joint.body and hose.error.is_empty())
		arrived = delta.length()<.045 or (stop_at_limit and span>=15.089)
		if arrived or not grip_ok or last_sample.distance_to(at)>.28:
			var sample := _payout_sample(actor,hose,joint,door,mask,held)
			sample.target = str(target)
			sample.wall_contacts = wall_contacts.duplicate(true)
			rows.append(sample)
			if not _check(grip_ok and sample.player_ok and not sample.floor.is_empty() and sample.crossing.is_empty() and sample.envelope.is_empty(),"B1 sample retains standing support and clear measured hose route: "+str(target)):
				return false
			last_sample=at
		if arrived:
			break
		var direction := player.global_basis.inverse()*delta.normalized()
		var strength := lerpf(deadzone,1.,clampf(delta.length()/.35,.12,.65))
		var axes := Vector4(-direction.x,direction.x,-direction.z,direction.z)*strength
		for i in PAYOUT_ACTIONS.size():
			if axes[i]>0.:
				Input.action_press(PAYOUT_ACTIONS[i],axes[i])
			else:
				Input.action_release(PAYOUT_ACTIONS[i])
		await get_tree().physics_frame
		for i in player.get_slide_collision_count():
			var collision := player.get_slide_collision(i)
			if absf(collision.get_normal().y)<.7:
				var collider := collision.get_collider() as Node
				if collider != null:
					wall_contacts[str(collider.get_path())]={"point":str(collision.get_position()),"normal":str(collision.get_normal()),"rid":str(collision.get_collider_rid())}
	for action: StringName in PAYOUT_ACTIONS:
		Input.action_release(action)
	for frame in 4:
		await get_tree().physics_frame
	var final := _payout_sample(actor,hose,joint,door,mask,held)
	final.target = str(target)
	final.wall_contacts = wall_contacts
	final.steered = aimed
	final.elapsed_ms = Time.get_ticks_msec()-started
	rows.append(final)
	return _check(aimed and arrived and final.player_ok and not final.floor.is_empty() and final.crossing.is_empty() and final.envelope.is_empty() and (not held or final.held),"B1 waypoint settles with the same grip and clear line: "+str(target))

func _payout_hit(hit: Dictionary) -> Dictionary:
	if hit.is_empty():
		return {}
	var collider := hit.get("collider") as Node
	return {"path":str(collider.get_path()) if collider != null else "", "rid":str(hit.rid), "shape":hit.shape, "point":str(hit.get("position",Vector3.ZERO)), "normal":str(hit.get("normal",Vector3.ZERO))}

func _payout_sample(actor: Node3D, hose: Node3D, joint: Node3D, door: DoorProp, mask: int, held: bool) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var floor_ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.20,player.global_position-Vector3.UP*.18,1,[player.get_rid()])
	var floor := space.intersect_ray(floor_ray)
	if not floor.is_empty() and floor.normal.y<.95:
		floor = {}
	var points: PackedVector3Array = hose.rig.strand.points
	var source: Vector3 = hose.model.to_global(hose.rig.strand.anchor)
	var receiver: Vector3 = actor.to_global(joint.receiver.origin)
	var sample := {"foot":str(world.adapter.root.to_local(player.global_position)), "floor":_payout_hit(floor), "player_ok":not player.noclip and not player.crouched and player.is_on_floor() and player.is_physics_processing() and player.collision_mask==mask and (mask&1)==1, "holder":var_to_str(player.global_transform), "nozzle":var_to_str(joint.body.global_transform), "door_angle":door._body.rotation.y, "door_closing":door._easy.closing, "door_delay":door._easy.remaining, "door_path":str(door._body.get_path()), "door_rid":str(door._body.get_rid()), "door_exception_holder":player.get_collision_exceptions().has(door._body), "door_exception_nozzle":joint.body.get_collision_exceptions().has(door._body), "held":held and player._grab.holding_pickup() and player.held_stock_body()==joint.body, "receiver_span_m":receiver.distance_to(source), "span_m":0., "crossing":{}, "envelope":{}, "feedback":player._grab.feedback({}).state if held else "", "fitting_blocker":hose.last_fitting_blocker}
	if not held:
		return sample
	if not hose.error.is_empty():
		sample.receiver_error = hose.error
		sample.rejected_pose = _payout_receiver_probe(hose)
	if points.size()!=hose.rig.rest.size() or not Array(points).all(func(point: Vector3):return point.is_finite()):
		sample.envelope = {"kind":"invalid_skin"}
		return sample
	sample.span_m = points[0].distance_to(hose.rig.strand.anchor)
	var excluded: Array[RID] = [player.get_rid(),joint.body.get_rid()]
	for row: Dictionary in hose._auxiliary_contacts:
		excluded.append(row.body.get_rid())
	var frames: Array[Transform3D] = hose.rig.model_frames(points)
	if frames.size()!=points.size():
		sample.envelope = {"kind":"invalid_frames"}
		return sample
	# Omit the last 23 fixed rings of intentional steel fairlead. Keep the
	# real door leaf in queries even when it has a temporary holder exception.
	var envelope_shape := ConvexPolygonShape3D.new()
	envelope_shape.margin = .00001
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=envelope_shape;query.collision_mask=1;query.exclude=excluded
	for i in range(points.size()-24):
		var a: Vector3 = hose.model.to_global(points[i])
		var b: Vector3 = hose.model.to_global(points[i+1])
		if a.distance_squared_to(b)<.00000001:
			continue
		for pair: Array in [[a,b],[b,a]]:
			var ray := PhysicsRayQueryParameters3D.create(pair[0],pair[1],1,excluded)
			ray.hit_from_inside=true
			var hit := space.intersect_ray(ray)
			if not hit.is_empty():
				sample.crossing = _payout_hit(hit)
				sample.crossing.merge({"segment":i,"a":str(a),"b":str(b),"inside":hit.normal.is_zero_approx()})
				return sample
		if not sample.envelope.is_empty():
			continue
		var hull := PackedVector3Array()
		var skin_bottom := INF
		for ring: int in [i,i+1]:
			var frame: Transform3D = hose.model.global_transform * frames[ring]
			var flat := clampf(float(mini(ring,points.size()-1-ring)-2)/3.,0.,1.)
			var radius_x := .021 * lerpf(1., .10, flat)
			var radius_z := .021 * lerpf(1., PI * .5, flat)
			var vertical_extent := Vector2(frame.basis.x.y * radius_x, frame.basis.z.y * radius_z).length()
			skin_bottom = minf(skin_bottom, frame.origin.y - vertical_extent)
			for side in 8:
				var angle := TAU*float(side)/8.
				var radial := Vector3(cos(angle)*radius_x,0,sin(angle)*radius_z)/cos(PI/8.)
				hull.append(frame*radial-a)
		envelope_shape.points=hull
		query.transform=Transform3D(Basis.IDENTITY,a)
		for overlap: Dictionary in space.intersect_shape(query,8):
			# A circumscribed octagon can touch the horizontal support even
			# when the nominal elliptical skin clears it.
			if not floor.is_empty() and _payout_clears_support(overlap, floor.position.y, skin_bottom):
				continue
			sample.envelope = _payout_hit(overlap)
			sample.envelope.merge({"kind":"conservative_ring_overlap","segment":i,"a":str(a),"b":str(b),"skin_bottom_y":skin_bottom})
			break
	if sample.envelope.is_empty():
		for child: Node in joint.body.get_children():
			var stock := child as CollisionShape3D
			if stock==null or stock.disabled or stock.shape==null:
				continue
			query.shape=stock.shape
			query.transform=stock.global_transform
			var overlaps := space.intersect_shape(query,1)
			if not overlaps.is_empty():
				sample.envelope = _payout_hit(overlaps[0])
				sample.envelope.merge({"kind":"native_nozzle_overlap","stock":str(stock.get_path())})
				break
	return sample

func _payout_clears_support(hit: Dictionary, floor_y: float, skin_bottom: float) -> bool:
	var body := hit.collider as StaticBody3D
	if body == null:
		return false
	var shape := body.shape_owner_get_owner(body.shape_find_owner(int(hit.shape))) as CollisionShape3D
	var box := shape.shape as BoxShape3D if shape != null else null
	if box == null or absf(shape.global_basis.y.normalized().dot(Vector3.UP)) < .9999:
		return false
	var top := shape.global_position.y + absf(shape.global_basis.y.y) * box.size.y * .5
	return absf(top - floor_y) < .001 and skin_bottom >= top

func _payout_receiver_probe(hose: Node3D) -> Dictionary:
	var view := player.camera.global_transform
	var anchor: Vector3 = hose.model.to_global(hose.rig.strand.anchor)
	var wanted: Vector3 = view * Vector3(.17, -.16, -.48)
	wanted = anchor + (wanted - anchor).limit_length(hose.rig.strand.total_length - .15)
	var tip: Vector3 = hose.model.to_local(wanted)
	var back: Vector3 = (hose.model.global_basis.inverse() * view.basis.z).normalized()
	var up: Vector3 = (hose.model.global_basis.inverse() * Vector3.UP).normalized()
	var probe := preload("res://scripts/props/hose_cabinet_route.gd").new()
	probe.model_to_actor = hose.model.transform
	var points := probe.build(tip, back, hose.rig.strand.anchor, hose.rig.rest.size(), hose.rig.strand.total_length, up, hose._guide_floor)
	var bad_tangent := -1
	for index in points.size():
		var tangent := points[mini(index + 1, points.size() - 1)] - points[maxi(index - 1, 0)]
		if not tangent.is_finite() or tangent.length_squared() < 1e-14:
			bad_tangent = index
			break
	var side: Vector3 = hose.rig.sides[0]
	return {"tip":str(tip), "back":str(back), "head_side":str(side),
		"head_projection_squared":side.slide(back).length_squared(),
		"points":points.size(), "frames":hose.rig.model_frames(points).size(),
		"bad_tangent":bad_tangent, "roundness":hose.water.pressure}

func _payout_result(rows: Array[Dictionary]) -> String:
	for row: Dictionary in rows:
		if not row.crossing.is_empty():
			return "native_segment_crossing"
		if not row.envelope.is_empty():
			return "envelope_blocked_or_invalid"
	return "player_path_or_grip_failed"
