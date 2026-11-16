extends RefCounted
## Current completed-opening fixture; actual producer/save/title/bedside access.
const Opening := preload("res://scripts/game/prologue_state.gd")
const TARGET := {"utc_unix_seconds":1876183200,"local_bias_minutes":-300,"local_zone":"Fixed EST fixture"}
const Motor := preload("res://tests/orison_v2_first_slice_contract_test.gd")
const TEST := "game/tests/title_continue_actual_launch_test.gd"
const SCENE := "res://tests/TitleContinueActualLaunchTest.tscn"
const SOURCE_CODE := """import json,sys
from pathlib import Path
root=Path(sys.argv[1]);sys.path.insert(0,str(root/'tools'))
from v2_surface_evidence import file_hash,test_dependency_paths
from run_receipt import runtime_inputs_sha256
paths=test_dependency_paths(root,[root/'game/tests/title_continue_actual_launch_test.gd',root/'game/tests/TitleContinueActualLaunchTest.tscn',root/'game/tests/harukiya_continue_witness.gd'])
print(json.dumps({'runtime_inputs_sha256':runtime_inputs_sha256(root),'test_dependencies':{p.relative_to(root).as_posix():file_hash(p) for p in sorted(paths)}}))
"""
var source: Dictionary = {}
var checks: Dictionary = {}
var details: Dictionary = {"legs":[],"fixture_facts":"Current skipped completed opening from PrologueState ordered builder, existing complete first-shift/core-loop fixture and minutes_read flag. None earned here."}
var started := Time.get_ticks_msec()
var producer_id := 0
var producer_player_id := 0
var producer_shell_ref: WeakRef
var producer_ref: WeakRef
var producer_player_ref: WeakRef
var expected_knowledge: Array = []
var attempted := false
var executed := false
var logger

func check(ok: bool, label: String) -> bool:
	checks[label]=ok
	if not ok: push_error("HARUKIYA CONTINUE: "+label)
	return ok

func snapshot() -> Dictionary:
	var output: Array=[]
	var status:=OS.execute("python",["-B","-c",SOURCE_CODE,ProjectSettings.globalize_path("res://..").simplify_path()],output)
	if status!=0 or output.is_empty(): return {}
	var parsed: Variant=JSON.parse_string(str(output[0]))
	return parsed if parsed is Dictionary else {}

func prepare(host: Node) -> bool:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK: return false
	if FileAccess.file_exists(directory.path_join("harukiya_continue.runtime.json")): return false
	logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(logger)
	source=snapshot()
	if not check(not source.is_empty(),"source_bound_before_producer"): return false
	for key: String in ["SCHEDULE","SCHEDULE_DAY","SCHEDULE_DOY","SCHEDULE_FIRST_SAT","SCHEDULE_MINUTE","AGENDA","CAMPAIGN_TIME_FREEZE"]:
		if not check(OS.get_environment(key).is_empty(),"no_inherited_override_"+key): return false
	RealityState.save_path="user://tests/harukiya_continue_%s/campaign.json"%Crypto.new().generate_random_bytes(8).hex_encode()
	RealityState.persistence_enabled=true;RealityState.load_game()
	if not check(RealityState.load_status().status=="missing" and RealityState.start_new_campaign(),"isolated_new_disk_campaign"): return false
	# Accepted skipped-opening builder from prologue_state_test: sequential
	# transitions with actual CampaignClock acknowledgement at synchronization.
	RealityState.data.intro_complete=true
	RealityState.data.first_shift={"phase":FirstShiftDirector.PHASE_COMPLETE,"report_id":ChirpHunt.JOB_ID,"filing":"fault_corrected"}
	RealityState.data.core_loop={"safe_return_anchor":"F04_B_BED","boundary":"wake_complete","active_job_id":"","conversation_requested":false,"conversation_complete":false,"dream_pending":false}
	var clock:=CampaignClock.new()
	var opening:=Opening.request_skip(Opening.initial())
	for index in Opening.PHASES.size()-1:
		var phase: String=Opening.PHASES[index]
		if phase=="companion_crossing":opening=Opening.applied(opening,"companion_materialized")
		if phase=="temporal_command":opening=Opening.with_target(opening,TARGET)
		if phase=="temporal_synchronization":
			RealityState.data.prologue=opening
			if not check(clock.bind_state() and clock.apply_prologue_destination(),"real_clock_acknowledges_opening_destination"):return false
			opening=Opening.restore(RealityState.data.prologue)
		opening=Opening.advance(opening,Opening.PHASES[index+1])
	RealityState.data.prologue=opening
	if not check(Opening.valid(opening) and opening.phase=="prologue_complete" and opening.skipped and opening.effects.clock_applied and clock.loop_calendar_active(),"valid_current_completed_opening_fixture"):return false
	var info:=clock.day_info()
	if not check(int(info.year)==1929 and int(info.month)==6 and int(info.day_of_month)==14 and absf(clock.minute_of_day()-1260.)<.00001,"owner_selected_predeath_friday_2100"):return false
	details.opening=JSON.parse_string(JSON.stringify(opening,"",true,true))
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	# Root-owned CampaignShell is required for the CURRENT entry contract.
	var producer_shell:=CampaignShell.new()
	producer_shell_ref=weakref(producer_shell)
	var deadline:=Time.get_ticks_msec()+240000
	host.get_tree().root.add_child(producer_shell)
	while Time.get_ticks_msec()<deadline:
		var active:=producer_shell.active_world as OrisonV2RuntimeRoot
		if active!=null and (active.startup_failed or current_ready(producer_shell,active)):break
		await host.get_tree().process_frame
	var producer:=producer_shell.active_world as OrisonV2RuntimeRoot
	if not check(Time.get_ticks_msec()<=deadline and producer!=null and current_ready(producer_shell,producer),"current_producer_completed_startup_and_bedside_handoff"):
		producer_shell.teardown_active_world();producer_shell.queue_free();return false
	producer_id=producer.get_instance_id();producer_player_id=producer.player.get_instance_id()
	producer_ref=weakref(producer);producer_player_ref=weakref(producer.player)
	details.producer={"world":producer_id,"player":producer_player_id,"at":producer.player.global_position}
	# Authored existing durable fact through existing owner; acquisition is fixture.
	check(RealityState.has_knowledge("minutes_read") or RealityState.grant_knowledge("minutes_read"),"producer_existing_knowledge_owner")
	expected_knowledge=JSON.parse_string(JSON.stringify(RealityState.data.knowledge_flags))
	var saved:=RealityState.save_game()
	var disk: Variant=JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
	check(saved and disk is Dictionary and disk.get("knowledge_flags")==expected_knowledge and disk.get("prologue")==details.opening and disk.get("first_shift",{}).get("phase")==FirstShiftDirector.PHASE_COMPLETE,"actual_disk_contains_current_opening_first_shift_and_fact")
	details.primary={"path":RealityState.save_path,"sha256":FileAccess.get_sha256(RealityState.save_path),"knowledge_flags":expected_knowledge}
	RealityState.flush_background_saves()
	var teardown: Dictionary=producer_shell.teardown_active_world()
	check(bool(teardown.get("ok",false)),"producer_shell_teardown_accepted")
	producer_shell.queue_free()
	await host.get_tree().process_frame;await host.get_tree().physics_frame
	check(producer_shell_ref.get_ref()==null and producer_ref.get_ref()==null and producer_player_ref.get_ref()==null,"producer_shell_world_and_player_destroyed")
	check(FileAccess.get_sha256(RealityState.save_path)==details.primary.sha256,"producer_retirement_keeps_saved_primary")
	RealityState.reset_campaign_for_tests();RealityState.load_game()
	check(RealityState.can_continue() and RealityState.load_status().status=="loaded" and RealityState.has_knowledge("minutes_read") and RealityState.data.knowledge_flags==expected_knowledge and RealityState.data.prologue==details.opening and RealityState.data.first_shift.phase==FirstShiftDirector.PHASE_COMPLETE,"validated_load_after_destroyed_context")
	return not checks.values().has(false)

func current_ready(shell: CampaignShell,world: OrisonV2RuntimeRoot) -> bool:
	if world.startup_ms<=0 or world.startup_failed or not is_instance_valid(world.player) or not is_instance_valid(world.prologue_director):return false
	var player:=world.player
	return shell.uses_prologue_entry() and shell.active_world==world and shell.world_child_count()==1 \
		and world.prologue_director.state.phase=="prologue_complete" and not world.prologue_director.is_processing() \
		and not shell.owns_opening_veil(world) and shell.get_node_or_null("OpeningLoadingVeil")==null \
		and not shell.get_tree().paused and player.camera.is_current() and not player.mouse_released \
		and not player.call_locked and player.text_input_owner==null and not player.protected_input_active() \
		and not player.inspecting() and not player._grab.active() and player.is_on_floor() \
		and player.is_physics_processing() and Motor._service_collision_valid(player)

func observe(observer: Node,shell: CampaignShell,world: OrisonV2RuntimeRoot) -> Dictionary:
	executed=true
	if not check(world.startup_ms>0 and not world.startup_failed and shell.active_world==world and shell.world_child_count()==1,"fresh_published_v2_complete"): return checks
	check(world.get_instance_id()!=producer_id and world.player.get_instance_id()!=producer_player_id and producer_ref.get_ref()==null and producer_player_ref.get_ref()==null,"distinct_world_and_player")
	check(RealityState.has_knowledge("minutes_read") and RealityState.data.knowledge_flags==expected_knowledge,"durable_fact_after_real_title_continue")
	check(RealityState.load_status().status=="loaded" and RealityState.can_continue(),"consumer_keeps_validated_continue_status")
	var deadline:=Time.get_ticks_msec()+30000
	while not current_ready(shell,world) and not world.startup_failed and Time.get_ticks_msec()<deadline:
		await observer.get_tree().physics_frame
	if not check(current_ready(shell,world),"current_completed_opening_releases_real_bedside_control"):return checks
	var player:=world.player
	details.consumer={"world":world.get_instance_id(),"player":player.get_instance_id(),"actual_resumed_spawn":player.global_position,"startup_ms":world.startup_ms,"opening":world.prologue_director.state.duplicate(true)}
	var anchor: Dictionary=world.core_loop.resolve_return_anchor()
	if not check(not anchor.is_empty() and player.global_position.distance_to(anchor.position)<.20,"resumed_spawn_is_production_bedside_not_curb"):return checks
	var recoveries: int=world.safety_net.recoveries
	# Existing prologue bed-to-hall and 4B outward legs, all REAL directional
	# input here. Reversed/joined legs are candidates, not prior route proof.
	var exits: Array[Vector3]=[Vector3(-11.95,9.6,7.25),Vector3(-9.8,9.6,7.25),
		Vector3(-10.05,9.6,5.5),Vector3(-10.05,9.6,2.25),Vector3(-10.8,9.6,2.25),
		Vector3(-10.8,9.6,0),Vector3(-8.3,9.6,0),Vector3(-6.65,9.6,0),Vector3(-4.65,9.6,0),
		Vector3(-1.8,9.6,0),Vector3(-1.8,9.6,-3.45)]
	for at: Vector3 in exits:
		if not await walk(observer,player,world.adapter.root.to_global(at)):return checks
	# Mae's EXISTING full staircase/front-threshold/bar graph is read only.
	# No route owner/actor/destination is altered to lend the player a path.
	var route: Node3D=world.resident_routes.get("mae_kessler")
	if not check(is_instance_valid(route) and route.force_destination.is_empty() and world.resident_agenda.enabled,"existing_unforced_graph_and_live_agenda"):return checks
	var from: int=int(route.identities.get("f04_stair_foot",-1))
	var target: int=int(route.identities.get("bar_pool_interaction",-1))
	if not check(from>=0 and target>=0,"existing_fourth_floor_and_pool_endpoints"):return checks
	var path: PackedInt64Array=route.graph.get_id_path(from,target)
	if not check(not path.is_empty(),"authored_connected_access_path"): return checks
	details.graph_path=[]
	for point: int in path: details.graph_path.append({"id":point,"goal":route.graph.get_point_position(point)})
	var door: DoorProp=world.bar_region.doors.get("F01_BAR_RED_DOOR")
	if not check(is_instance_valid(door),"original_red_leaf_exists"): return checks
	var door_id:=door.get_instance_id()
	details.door_before=door.mechanism_snapshot()
	# Still no placement: join the public stair graph from the actual 4B
	# exit and continue down its real stair/front-threshold/bar path.
	for point: int in path:
		if not await walk(observer,player,route.graph.get_point_position(point)): return checks
	check(world.safety_net.recoveries==recoveries,"access_without_safety_recovery")
	check(door.get_instance_id()==door_id and Motor._service_collision_valid(player) and player.is_physics_processing(),"original_leaf_and_collision_retained")
	check(RealityState.has_knowledge("minutes_read") and RealityState.data.knowledge_flags==expected_knowledge,"durable_fact_after_access")
	details.door_after=door.mechanism_snapshot();details.consumer.after=player.global_position
	return checks

func walk(host: Node,player: PlayerController,goal: Vector3) -> bool:
	# Existing mass-return driver, without its forced-attendance fixture.
	var initial:=player.global_position
	var deadline:=Time.get_ticks_msec()+int(minf(30.,initial.distance_to(goal)/player.WALK+10.)*1000)
	while Time.get_ticks_msec()<deadline:
		var offset:=goal-player.global_position;offset.y=0
		if offset.length()<.075 and absf(player.global_position.y-goal.y)<.24:break
		var turn:=wrapf(atan2(-offset.x,-offset.z)-player.rotation.y,-PI,PI)
		player.rotation.y+=clampf(turn,-.06,.06);player.camera.rotation=Vector3.ZERO
		if absf(turn)>.18:Input.action_release("move_forward")
		else:Input.action_press("move_forward",clampf(offset.length()/.3,.20,1.))
		await host.get_tree().physics_frame
	Input.action_release("move_forward")
	var gap:=goal-player.global_position
	var ok:=Vector2(gap.x,gap.z).length()<.10 and absf(gap.y)<.24 and Motor._service_collision_valid(player) and player.is_physics_processing()
	var contacts: Array=[]
	for index in player.get_slide_collision_count():
		var hit:=player.get_slide_collision(index)
		var collider:=hit.get_collider() as Node
		contacts.append({"collider":str(collider.get_path()) if is_instance_valid(collider) else "", "normal":hit.get_normal(),"position":hit.get_position()})
	details.legs.append({"from":initial,"goal":goal,"actual":player.global_position,"ok":ok,"contacts":contacts})
	return check(ok,"directional_access_leg_%d"%details.legs.size())

func write_contract(observer: Node,inherited: Dictionary,failures: int,timed_out:=false) -> bool:
	var directory:=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or FileAccess.file_exists(directory.path_join("harukiya_continue.runtime.json")): return false
	Input.action_release("move_forward")
	check(not source.is_empty() and source==snapshot(),"consumed_sources_stay_fixed")
	var errors: Array=logger.errors.duplicate(true) if logger!=null else []
	check(errors.is_empty(),"no_engine_errors")
	var passed:=attempted and executed and failures==0 and not timed_out and not checks.values().has(false) and not inherited.values().has(false)
	var deps: Dictionary=source.get("test_dependencies",{})
	var record: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Current prologue-bearing completed-opening/first-shift fixture: real CampaignShell producer and disk save, destroyed context, validated load and actual title Continue into fresh V2, actual production bedside spawn and directional 4B exit/stair/front-threshold/Harukiya pool access. Joined/reversed route legs qualify only if actually completed. No arbitrary position persistence, earned prologue/first-shift/knowledge, forced attendance, all21 occupancy, player-only door opening, counter/game input, cost, art or play acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":timed_out,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":TEST,"test_sha256":deps.get(TEST,""),"scene_path":SCENE,"scene_sha256":deps.get("game/"+SCENE.trim_prefix("res://"),""),"script_node_path":str(observer.get_path()),"test_dependencies":deps,"runtime_inputs_sha256":source.get("runtime_inputs_sha256","")},
		"contracts":{"harukiya_post_continue_access":{"attempted":attempted,"executed":executed,"status":"PASS" if passed else "FAIL"}},"checks":checks,"inherited_checks":inherited,"engine_errors":errors,"details":details}
	var file:=FileAccess.open(OS.get_environment("SHOT_DIR").path_join("harukiya_continue.runtime.json"),FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(record,"\t",true,true));var written:=file.get_error()==OK;file.close()
	if logger!=null:OS.remove_logger(logger);logger=null
	return written and passed
