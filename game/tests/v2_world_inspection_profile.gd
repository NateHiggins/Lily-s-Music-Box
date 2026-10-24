extends "res://tests/orison_v2_floor_surface_test.gd"
## Full composed-world diagnostic; fixture placement, no access/acceptance grant.
var world: OrisonV2RuntimeRoot
var phase := "startup"
var samples: Array=[]
var events: Array=[]
var sampling:=false
var previous_usec:=0
func _process(_delta: float) -> void:
 var now:=Time.get_ticks_usec()
 if sampling and previous_usec>0:
  var view:=get_viewport().get_viewport_rid()
  samples.append([phase,(now-previous_usec)/1000.,Performance.get_monitor(Performance.TIME_PROCESS)*1000.,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,RenderingServer.viewport_get_measured_render_time_cpu(view),RenderingServer.viewport_get_measured_render_time_gpu(view),world.player.inspecting()])
 previous_usec=now
func _run() -> void:
 if DisplayServer.get_name()=="headless":get_tree().quit(1);return
 RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
 CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,11,10,20*60)
 world=_world_scene().instantiate();add_child(world)
 await get_tree().physics_frame;await get_tree().physics_frame
 check(not world.startup_failed,"actual production world starts")
 if failures.is_empty():await _exercise()
 var directory:=OS.get_environment("SHOT_DIR")
 DirAccess.make_dir_recursive_absolute(directory)
 FileAccess.open(directory.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","kind":"performance_diagnostic","scope":"Actual Space entry/free cursor/hand movement/escape in the full composed world; supported fixture stance, not continuous access or human acceptance.","resolution":str(get_viewport().get_visible_rect().size),"vsync":false,"columns":["phase","wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","inspecting"],"samples":samples,"events":events,"checks":batch_checks,"failures":failures},"	"))
 world.shutdown_for_tests();world.free();await get_tree().physics_frame
 print("V2 WORLD INSPECTION PROFILE: ","PASS" if failures.is_empty() else "FAIL"," checks=",batch_checks," failures=",failures.size())
 get_tree().quit(0 if failures.is_empty() else 1)
func _exercise() -> void:
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
 var player: PlayerController=world.player
 var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
 var actor: Node3D=native.stations["F01_FIRE_LINE_STAIR"].get_ref()
 var placement:=preload("res://tests/v2_fire_service_review.gd").new()
 check(await placement._place_player(world,actor),"retained supported capsule-clear stance and actual short movement")
 if not failures.is_empty():return
 var helper: Node=preload("res://tests/v2_fire_hand_bench.gd").new();helper.set_meta("shared_world_validation",true);helper.player=player;world.add_child(helper)
 var hand: Node=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new();hand.player=player;world.add_child(hand)
 player.set_lamp_enabled(true)
 check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual input opens retained source leaf")
 if not failures.is_empty():helper.free();hand.free();return
 sampling=true;phase="approach_settled"
 for frame in 120:await get_tree().process_frame
 for cycle in 3:
  phase="target_%d"%cycle
  await helper.aim(actor._tag.to_global(Vector3(0,0,.0035)));helper.click()
  check(player._grab.active() and player._grab.target.owner==actor,"actual ray grabs installed inspection tag")
  if not failures.is_empty():break
  var eye: Transform3D=player.camera.global_transform
  phase="enter_%d"%cycle
  var started:=Time.get_ticks_usec();helper.key(KEY_SPACE)
  events.append({"cycle":cycle,"event":"space_entry","dispatch_ms":(Time.get_ticks_usec()-started)/1000.})
  check(player.inspecting() and player.inspect_owner==actor and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and not player._grab.active(),"Space enters supported camera and releases hand")
  if not failures.is_empty():break
  var fixed_eye: Transform3D=player.camera.global_transform
  for frame in 8:await get_tree().process_frame
  phase="cursor_%d"%cycle
  check(await helper.cursor_to(player.camera.unproject_position(actor._lever.to_global(Vector3(.07,0,0)))),"native free cursor delivered")
  player._update_prompt()
  check(player._grab.find_target().get("part")==actor._lever and player._target_dot.state=="available","authoritative free cursor identifies specific movable lever")
  for frame in 120:await get_tree().process_frame
  helper.click();check(player._grab.active() and player._grab.target.part==actor._lever,"inspection click grabs the same lever")
  phase="drag_%d"%cycle
  if player._grab.active():
   var value: float=player._grab.target.read.call()
   check(await hand.move_to(0. if value<-.1 else -.2),"mouse moves actual constrained lever")
   helper.click()
  check(not player._grab.active() and player.camera.global_transform.is_equal_approx(fixed_eye),"next click releases and inspection eye remains fixed")
  phase="exit_%d"%cycle
  started=Time.get_ticks_usec();helper.key(KEY_ESCAPE)
  events.append({"cycle":cycle,"event":"escape_exit","dispatch_ms":(Time.get_ticks_usec()-started)/1000.})
  check(not player.inspecting() and player.camera.global_transform.is_equal_approx(eye) and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"escape restores exact prior eye and captured look")
  for frame in 8:await get_tree().process_frame
  phase="restored_%d"%cycle
  for frame in 120:await get_tree().process_frame
  if not failures.is_empty():break
 sampling=false
 player.cancel_manipulation();helper.free();hand.free()
