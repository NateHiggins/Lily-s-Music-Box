extends Node
## INERT bounded installed-world diagnostic. No runtime_contract is emitted.
const Selector := preload("res://scripts/building/building_root_selector.gd")
const Helpers := preload("res://tests/orison_v2_first_slice_contract_test.gd")
const SOURCES := ["res://tests/installed_camera_probe.gd","res://tests/InstalledCameraProbe.tscn","res://tests/orison_v2_first_slice_contract_test.gd","res://tests/orison_v2_first_slice_contract_test.tscn","res://tests/native_debug_window.gd"]
var world: OrisonV2RuntimeRoot
var helpers: Helpers
var output := ""
var terminal := false
var saved_persistence := false
var saved_mouse := Input.MOUSE_MODE_VISIBLE
var service_trace_phase := "outgoing"
var report: Dictionary = {"evidence_class":"INERT","scope":"Nearby installed-world camera admission diagnosis only; no patrol, disk, whole-authority or artistic acceptance.","frames":[],"checks":[],"sources":{}}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	saved_persistence=RealityState.persistence_enabled
	saved_mouse=Input.mouse_mode
	output=OS.get_environment("SHOT_DIR")
	if output.is_empty() or (DirAccess.dir_exists_absolute(output) and (not DirAccess.get_files_at(output).is_empty() or not DirAccess.get_directories_at(output).is_empty())):
		push_error("INSTALLED CAMERA: requires fresh SHOT_DIR; existing results are never overwritten")
		get_tree().quit(2);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		get_tree().quit(2);return
	for path: String in ["res://tests/installed_camera_probe.gd","res://tests/InstalledCameraProbe.tscn","res://tests/orison_v2_first_slice_contract_test.gd","res://scripts/player/player_controller.gd","res://scripts/props/radiator_prop.gd","res://scripts/props/radiator_vent_stock.gd","res://scripts/props/radiator_vent_insert.gd","res://scripts/building/building_root_selector.gd","res://scripts/building/orison_v2_runtime_root.gd"]:
		report.sources[path]=FileAccess.get_sha256(path)
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete=true
	Selector.reset_for_tests("v2")
	helpers=Helpers.new()
	helpers.service_bench_only=true
	add_child(helpers)
	helpers._prepare_ritual()
	var packed: PackedScene=load(Selector.scene_path()) as PackedScene
	world=packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	if not _check(not world.startup_failed,"actual Selector/RuntimeRoot composition starts"):
		await _finish("startup_refused",1);return
	# Original _exercise_ritual also drains deferred arrival before placement.
	await get_tree().process_frame
	await get_tree().process_frame
	var player: PlayerController=world.player
	var radiator: RadiatorProp=world.find_child("F02_B_RADIATOR_01",true,false) as RadiatorProp
	if not _check(radiator!=null and radiator.native_orifices!=null,"installed2B radiator and finite stock exist"):
		await _finish("missing_installed_owner",1);return
	report.phase_attempts=[]
	helpers.service_inspection_observer=_observe_service_admission.bind(radiator)
	# The only player-placement override: original round's2B service point.
	# No walks, camera-path admission bypass, stock poses or descriptors are fabricated.
	player.set_physics_process(false)
	player.global_position=world.adapter.root.to_global(Vector3(14.5,3.2,-3.))
	player.velocity=Vector3.ZERO
	player.camera.make_current()
	report.initial_campaign=_campaign_context()
	report.initial_npc_colliders=_npc_colliders()
	report.initial={"fixture":"one explicit nearby placement; original helper close-work cameras reused","building_point":[14.5,3.2,-3.],"frame":_node(world.adapter.root),"world":_node(world),"radiator":_node(radiator),"rig":_node(radiator.native_rig),"player":_node(player),"viewport":_safe(get_viewport().get_visible_rect().size),"root_window":_safe(get_tree().root.get_visible_rect().size),"capsule_mask":player.collision_mask,"capsule_layer":player.collision_layer,"noclip":player.noclip}
	if not _check(get_viewport() is SubViewport and get_viewport().get_visible_rect().size==Vector2(3440,1440),"detached native3440x1440 diagnostic viewport"):
		await _finish("viewport_refused",1);return
	await _shot("initial_service_fixture")
	if not await helpers._service_supply(player,radiator,0.):
		await _finish("supply_refused",1);return
	var stock: Node3D=radiator.native_orifices
	var original: Dictionary=stock.active(radiator)
	if not _check(not original.is_empty(),"original installed finite insert found"):
		await _finish("missing_insert",1);return
	var part: Node3D=original.body
	report.original_identity=str(part.get("identity"))
	if not await helpers._service_move_new(player,radiator,part,Vector3(0,.004,0),Vector3(.03,.10,-.08),stock.THREAD_END):
		await _finish("unthread_refused",1);return
	if not _check(stock.active(radiator).is_empty(),"real mouse unthread clears original seat"):
		await _finish("unthread_incomplete",1);return
	if not await helpers._pick_service_part(player,part,radiator,Vector3(.03,.10,-.08)):
		await _finish("pick_refused",1);return
	if not _check(player._grab.holding_pickup() and player._grab.target.part==part,"actual captured pickup is the same finite insert"):
		await _finish("wrong_pickup",1);return
	# Mirror begin_inspection's owner resolution and exact admission query.
	# inspection_view_for may prepare the owner's pending borrow, as production does.
	# No await occurs between these diagnostic rays and actual Space delivery.
	var owner: Node3D=player._grab.target.owner
	var grabbed_owner: Node3D=owner
	if owner.has_method("inspection_owner_for"):
		owner=owner.inspection_owner_for(part)
	if not _check(owner!=null and owner.has_method("inspection_view"),"real inspection owner resolves"):
		await _finish("owner_refused",1);return
	var view: Dictionary=owner.inspection_view_for(part) if owner.has_method("inspection_view_for") else owner.inspection_view()
	var from: Vector3=view.from
	var at: Vector3=view.at
	var unfiltered:=PhysicsRayQueryParameters3D.create(player.camera.global_position,from)
	var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,from)
	query.exclude=[player.get_rid()]
	var exclusion_paths: Array=[str(player.get_path())]
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):
		query.exclude.append(body.get_rid());exclusion_paths.append(str(body.get_path()))
	if owner is CollisionObject3D:
		query.exclude.append(owner.get_rid());exclusion_paths.append(str(owner.get_path()))
	var space: PhysicsDirectSpaceState3D=player.get_world_3d().direct_space_state
	var raw_hit: Dictionary=space.intersect_ray(unfiltered)
	var production_hit: Dictionary=space.intersect_ray(query)
	var stationary: bool=player.camera.global_position.distance_squared_to(from)<=.000001
	report.admission_campaign=_campaign_context()
	report.admission_npc_colliders=_npc_colliders()
	report.admission={"grabbed_owner":_node(grabbed_owner),"resolved_owner":_node(owner),"part":_node(part),"stock":_node(stock),"camera":_node(player.camera),"player":_node(player),"rig":_node(radiator.native_rig),"radiator":_node(radiator),"frame":_node(world.adapter.root),"proposed_from":_safe(from),"proposed_at":_safe(at),"fov":view.get("fov",player.camera.fov),"from_in_owner":_safe(owner.to_local(from)),"from_in_rig":_safe(radiator.native_rig.to_local(from)),"part_in_rig":_safe(radiator.native_rig.to_local(part.global_position)),"park_target":_safe(radiator.native_rig.to_global(Vector3(-.30,.12,-.55))),"receiving_seat":_safe(stock._thread_pose(radiator,stock.THREAD_END).origin),"unfiltered_first_hit":_hit(raw_hit),"production_first_hit":_hit(production_hit),"production_exclusion_paths":exclusion_paths,"query_mask":query.collision_mask,"collide_with_bodies":query.collide_with_bodies,"collide_with_areas":query.collide_with_areas,"hit_from_inside":query.hit_from_inside,"stationary_guard":stationary,"ray_predicts_admitted":stationary or production_hit.is_empty(),"call_locked":player.call_locked,"mouse_released":player.mouse_released,"held_freeze":part.get("freeze")}
	helpers._service_space(player)
	report.space_result={"entered":player.inspecting(),"owner":str(player.inspect_owner.get_path()) if is_instance_valid(player.inspect_owner) else "","camera":_node(player.camera),"part":_node(part),"held_freeze":part.get("freeze"),"grab_active":player._grab.active()}
	_check(player.inspecting()==bool(report.admission.ray_predicts_admitted),"actual Space result agrees with same-frame admission ray")
	await _shot("after_real_space")
	# Read-only render of the EXISTING proposed view, never a player-camera fix.
	# It is explicitly not evidence the eye was admitted or could travel there.
	var preview:=Camera3D.new()
	preview.cull_mask=player.camera.cull_mask
	add_child(preview)
	preview.global_position=from;preview.look_at(at)
	preview.fov=clampf(float(view.get("fov",player.camera.fov)),40.,100.)
	preview.make_current()
	await _shot("existing_proposed_view_DIAGNOSTIC_ONLY")
	player.camera.make_current();preview.free()
	# Opt-in repair preflight keeps the diagnostic's original refusal record
	# and then exercises the same finite insert through the original driver.
	if OS.get_environment("ORISON_INSTALLED_CAMERA_TRANSFER")=="1":
		if not _check(player.inspecting(),"repair preflight admits the actual installed Space handoff"):
			await _finish("transfer_admission_refused",1);return
		helpers._service_space(player)
		if not _check(player._grab.holding_pickup() and player._grab.target.part==part,"inspection returns the original installed insert to pickup"):
			await _finish("transfer_pickup_refused",1);return
		var park: Vector3=radiator.native_rig.to_global(Vector3(-.30,.12,-.55))
		var parked: bool=await helpers._deliver_service_part(player,part,park)
		report.transfer={"parked":parked,"park_position":_safe(part.global_position),"identity":str(part.get("identity"))}
		if not _check(parked,"original controller parks the installed outgoing insert"):
			await _finish("transfer_parking_refused",1);return
		await _shot("actual_installed_insert_parked")
		helpers._service_space(player)
		var receiving: Transform3D=stock._thread_pose(radiator,stock.THREAD_END)
		player.camera.global_position=receiving.origin+radiator.global_basis*Vector3(.02,.15,-.35)
		player.camera.look_at(receiving.origin)
		service_trace_phase="receiving"
		var delivered: bool=await helpers._deliver_service_part(player,part,receiving.origin)
		report.transfer.delivered=delivered
		if not _check(delivered,"original controller returns the same installed insert to the receiving thread"):
			report.return_failure={"camera":_node(player.camera),"part":_node(part),"inspect_owner":_node(player.inspect_owner),"inspecting":player.inspecting(),"holding_pickup":player._grab.holding_pickup(),"frozen":part.get("freeze"),"campaign":_campaign_context()}
			await _shot("actual_installed_return_failure")
			await _finish("transfer_receiving_refused",1);return
		await _shot("actual_installed_insert_receiving")
		var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=true
		player._unhandled_input(release)
		report.transfer.caught=stock.active(radiator).get("body")==part
		_check(report.transfer.caught,"normal release catches the original installed receiving thread")
		report.transfer.passed=parked and delivered and report.transfer.caught and helpers.failures==0
	await _finish("admitted" if player.inspecting() else "admission_refused",0 if int(helpers.failures)==0 else 1)

func _check(ok: bool,label: String) -> bool:
	report.checks.append({"ok":ok,"label":label})
	print("INSTALLED CAMERA: ","PASS " if ok else "FAIL ",label)
	return ok

func _observe_service_admission(player: PlayerController,part: Node3D,radiator: RadiatorProp) -> void:
	# Synchronous observation immediately before the ORIGINAL helper's Space.
	# No awaits, controller writes, exclusion changes or replacement descriptors.
	var grabbed_owner: Node3D=player._grab.target.owner
	var owner: Node3D=grabbed_owner
	if owner.has_method("inspection_owner_for"):owner=owner.inspection_owner_for(part)
	var bank: Node3D=part.bank
	var nearest: Node3D=bank.inspection_owner_for(part)
	var record: Dictionary={"phase":service_trace_phase,"index":report.phase_attempts.size(),"observed_before_real_space":true,"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"ticks_usec":Time.get_ticks_usec(),"grabbed_owner":_node(grabbed_owner),"resolved_owner":_node(owner),"nearest_owner":_node(nearest),"part":_node(part),"stock":_node(bank),"camera":_node(player.camera),"player":_node(player),"radiator":_node(radiator),"rig":_node(radiator.native_rig),"frame":_node(world.adapter.root),"call_locked":player.call_locked,"mouse_released":player.mouse_released,"grab_active":player._grab.active(),"holding_pickup":player._grab.holding_pickup(),"inspecting_before_space":player.inspecting(),"held_freeze":part.get("freeze"),"campaign":_campaign_context(),"npc_colliders":_npc_colliders(),"nearest_seat_distances":[]}
	for candidate: Node3D in bank.radiators.values():
		var seat: Vector3=bank._thread_pose(candidate,0).origin
		record.nearest_seat_distances.append({"owner":str(candidate.get_path()),"seat":_safe(seat),"distance":part.global_position.distance_to(seat)})
	if owner==null or not owner.has_method("inspection_view"):
		record.query_skipped="resolved owner has no inspection view"
		report.phase_attempts.append(record);return
	# This may prepare the existing pending borrow, as production does again
	# immediately afterwards. It does not move/freeze the part or admit an eye.
	var view: Dictionary=owner.inspection_view_for(part) if owner.has_method("inspection_view_for") else owner.inspection_view()
	var from: Vector3=view.from
	var at: Vector3=view.at
	var raw:=PhysicsRayQueryParameters3D.create(player.camera.global_position,from)
	var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,from)
	query.exclude=[player.get_rid()]
	var paths: Array=[str(player.get_path())]
	for body: CollisionObject3D in owner.find_children("*","CollisionObject3D",true,false):
		query.exclude.append(body.get_rid());paths.append(str(body.get_path()))
	if owner is CollisionObject3D:
		query.exclude.append(owner.get_rid());paths.append(str(owner.get_path()))
	var space: PhysicsDirectSpaceState3D=player.get_world_3d().direct_space_state
	var raw_hit: Dictionary=space.intersect_ray(raw)
	var production_hit: Dictionary=space.intersect_ray(query)
	var stationary: bool=player.camera.global_position.distance_squared_to(from)<=.000001
	record.merge({"proposed_from":_safe(from),"proposed_at":_safe(at),"fov":view.get("fov",player.camera.fov),"from_in_owner":_safe(owner.to_local(from)),"from_in_rig":_safe(radiator.native_rig.to_local(from)),"unfiltered_first_hit":_hit(raw_hit),"production_first_hit":_hit(production_hit),"production_exclusion_paths":paths,"query_mask":query.collision_mask,"collide_with_bodies":query.collide_with_bodies,"collide_with_areas":query.collide_with_areas,"hit_from_inside":query.hit_from_inside,"hit_back_faces":query.hit_back_faces,"stationary_guard":stationary,"ray_predicts_admitted":stationary or production_hit.is_empty(),"production_state_guards_open":not player.call_locked and not player.mouse_released and player._grab!=null})
	report.phase_attempts.append(record)
	print("[SERVICE ADMISSION OBSERVER] phase=",service_trace_phase," eye=",player.camera.global_position," part=",part.global_position," owner=",owner.get_path()," predicted=",record.ray_predicts_admitted," hit=",record.production_first_hit)

func _safe(value: Variant) -> Variant:
	if value is Vector3:return [value.x,value.y,value.z]
	if value is Vector2:return [value.x,value.y]
	return value

func _pose(t: Transform3D) -> Dictionary:
	return {"origin":_safe(t.origin),"basis_x":_safe(t.basis.x),"basis_y":_safe(t.basis.y),"basis_z":_safe(t.basis.z)}

func _node(node: Node3D) -> Dictionary:
	if not is_instance_valid(node):return {}
	return {"path":str(node.get_path()),"class":node.get_class(),"local":_pose(node.transform),"global":_pose(node.global_transform)}

func _campaign_context() -> Dictionary:
	return {"campaign_clock":RealityState.data.get("campaign_clock",{}).duplicate(true),"first_shift":RealityState.data.get("first_shift",{}).duplicate(true),"campaign_time_frozen_for_tests":CampaignTime._frozen_for_tests,"campaign_time_freeze_environment":OS.get_environment("CAMPAIGN_TIME_FREEZE"),"daynight_force_environment":OS.get_environment("DAYNIGHT_FORCE"),"ticks_msec":Time.get_ticks_msec()}

func _npc_colliders() -> Array:
	var result: Array=[]
	for body: CharacterBody3D in world.find_children("*","CharacterBody3D",true,false):
		if body==world.player:continue
		var record: Dictionary=_node(body)
		record.collision_layer=body.collision_layer;record.collision_mask=body.collision_mask
		record.groups=body.get_groups()
		record.script=body.get_script().resource_path if body.get_script()!=null else ""
		record.ancestors=[]
		var ancestor: Node=body.get_parent()
		while ancestor!=null and ancestor!=world:
			record.ancestors.append({"path":str(ancestor.get_path()),"script":ancestor.get_script().resource_path if ancestor.get_script()!=null else ""})
			ancestor=ancestor.get_parent()
		result.append(record)
	return result

func _hit(hit: Dictionary) -> Dictionary:
	if hit.is_empty():return {}
	var result: Dictionary={"position":_safe(hit.position),"normal":_safe(hit.normal),"shape_index":hit.shape,"face_index":hit.get("face_index",-1)}
	var collider: Object=hit.collider
	result.collider_path=str(collider.get_path()) if collider is Node else str(collider)
	if collider is Node3D:result.collider=_node(collider)
	if collider is CollisionObject3D:
		result.collision_layer=collider.collision_layer;result.collision_mask=collider.collision_mask
		var shape_owner_id: int=collider.shape_find_owner(int(hit.shape))
		var shape_owner: Object=collider.shape_owner_get_owner(shape_owner_id)
		result.shape_owner_path=str(shape_owner.get_path()) if shape_owner is Node else str(shape_owner)
		result.shape_owner_transform=_pose(collider.shape_owner_get_transform(shape_owner_id))
		if shape_owner is Node3D:result.shape_owner=_node(shape_owner)
	return result

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image=get_viewport().get_texture().get_image()
	var path: String=output.path_join(label+".png")
	var error: Error=image.save_png(path)
	report.frames.append({"path":path,"width":image.get_width(),"height":image.get_height(),"save_error":error})
	_check(error==OK and image.get_size()==Vector2i(3440,1440),"native frame saved: "+label)

func _finish(reason: String,code: int) -> void:
	if terminal:return
	terminal=true
	report.result=reason
	if is_instance_valid(helpers):
		report.helper_observations=helpers.observations.duplicate(true)
		report.helper_failures=helpers.failures
	if is_instance_valid(world):
		if is_instance_valid(world.player):world.player.cancel_manipulation()
		world.shutdown_for_tests();remove_child(world);world.free()
	if is_instance_valid(helpers):helpers.free()
	await get_tree().process_frame
	await get_tree().process_frame
	PropAudio.clear_cache()
	RealityState.persistence_enabled=saved_persistence
	Input.mouse_mode=saved_mouse
	report.teardown={"runtime_freed":not is_instance_valid(world),"helpers_freed":not is_instance_valid(helpers),"persistence_restored":RealityState.persistence_enabled==saved_persistence,"no_disk_save_called":true}
	for check: Dictionary in report.checks:
		if not bool(check.ok):code=1
	var file:=FileAccess.open(output.path_join("installed_camera_probe.json"),FileAccess.WRITE)
	if file==null:
		push_error("INSTALLED CAMERA: report write failed");get_tree().quit(2);return
	file.store_string(JSON.stringify(report,"\t",true,true));file.close()
	print("INSTALLED CAMERA DIAGNOSTIC: ",reason," exit=",code,"; INERT, no runtime_contract")
	get_tree().quit(code)
