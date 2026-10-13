extends Node3D
## Actual-player installed washer controls; diagnostic, not navigation acceptance.
var failures: Array[String]=[]
var checks:=0
var player: PlayerController
var world: OrisonV2RuntimeRoot
func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label)
 print("WASHER CHECK: ",label," = ",ok)
func click() -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
func drag(relative: Vector2) -> void:
 var event:=InputEventMouseMotion.new();event.relative=relative;player._unhandled_input(event)
func shot(name: String) -> void:
 var folder:=OS.get_environment("SHOT_DIR")
 if folder.is_empty():return
 DirAccess.make_dir_recursive_absolute(folder)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(folder+"/"+name+".png")
func move_part(actor: WasherProp, part: Node3D, contact: Vector3, eye: Vector3, goal: float) -> void:
 player._grab.release()
 var at:=part.to_global(contact)
 player.global_position=actor.to_global(eye)-Vector3(0,player.camera.position.y,0)
 await get_tree().physics_frame;await get_tree().physics_frame
 player.camera.look_at(at)
 var candidate: Dictionary=player._grab.find_target()
 # Standing side approaches for a valve behind the swung wringer cheek.
 if part==actor._fill_handles[1] and candidate.get("part")!=part:
  for alternative:Vector3 in [Vector3(-.75,1.60,.15),Vector3(-.75,1.60,.30),Vector3(0,1.75,-.65)]:
   player.global_position=actor.to_global(alternative)-Vector3(0,player.camera.position.y,0)
   await get_tree().physics_frame;await get_tree().physics_frame
   player.camera.look_at(at);candidate=player._grab.find_target()
   if candidate.get("part")==part:break
 check(candidate.get("part")==part,"installed ray selects "+str(actor.name)+"/"+str(part.name))
 if candidate.get("part")!=part:
  print("WASHER MISS ",part.name," candidate=",candidate," eye=",player.camera.global_position," at=",at)
  return
 var before: float=candidate.read.call()
 click()
 check(player._grab.active() and is_equal_approx(float(candidate.read.call()),before),"acquire leaves "+str(part.name)+" unmoved")
 if not player._grab.active():return
 for i in 160:
  var grip: Dictionary=player._grab.target
  if grip.is_empty(): break
  var remaining:=goal-float(grip.read.call())
  if absf(remaining)<.001:break
  var point: Vector3=part.to_global(player._grab.contact)
  var axis: Vector3=grip.frame.global_basis*grip.axis
  var tangent:=axis.cross(point-part.global_position)
  if tangent.length()<.025:
   tangent=axis.cross(player.camera.global_basis.x)*.06
   if tangent.length()<.01:tangent=axis.cross(player.camera.global_basis.y)*.06
  var gesture: Vector2=(player.camera.unproject_position(point+tangent*.01)-player.camera.unproject_position(point))/.01
  if gesture.length()<24 and absf(tangent.dot(player.camera.global_basis.z))>tangent.length()*.5:
   gesture=Vector2(0,tangent.dot(player.camera.global_basis.z)*180)
  drag(gesture*signf(remaining)*minf(.12,absf(remaining)))
  await get_tree().physics_frame
  if not player._grab.active():
   var query:=PhysicsRayQueryParameters3D.create(player.camera.global_position,part.to_global(contact))
   query.collide_with_areas=true;query.exclude=[player.get_rid()]
   var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
   print("WASHER LOST ",part.name," value=",candidate.read.call()," hand=",actor._hand_control," hit=",hit.get("collider")," eye=",player.camera.global_position," target=",part.to_global(contact))
 check(absf(float(candidate.read.call())-goal)<.002,"mouse moves "+str(part.name)+" to requested travel")
 if player._grab.active():click()
 check(not player._grab.active(),"second click releases "+str(part.name))
func _run() -> void:
 RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
 var selector:=preload("res://scripts/building/building_root_selector.gd");selector.reset_for_tests("v2")
 world=(load(selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot;add_child(world)
 await get_tree().physics_frame;await get_tree().physics_frame
 check(not world.startup_failed,"V2 starts with native washer controls")
 if world.startup_failed:world.free();get_tree().quit(1);return
 player=world.player;player.set_physics_process(false);player.call_locked=false;player.set_mouse_released(false);player.set_lamp_enabled(true)
 var household: Node=get_tree().get_first_node_in_group("v2_household_state")
 var expected: Dictionary={}
 for identity: String in ["B1_WASHER_01","B1_WASHER_02"]:
  var actor: WasherProp=world.adapter.resolve(identity)
  check(actor!=null,"durable installed washer "+identity)
  if actor==null:continue
  actor.set_agitating(false)
  actor.set_lid_open(true,0)
  check(actor._lid.rotation.x<deg_to_rad(20),"wringer stops lid before physical intersection")
  actor.set_lid_open(false,0);actor.set_wringer_swing(90,0);actor.set_lid_open(true,0)
  check(is_equal_approx(actor._lid.rotation.x,deg_to_rad(82)),"swung-aside wringer permits full lid opening")
  actor.set_wringer_swing(0,0)
  check(actor._yoke.rotation.y>deg_to_rad(80),"open lid stops wringer returning through cover")
  actor.set_lid_open(false,0)
  var lower_before:=actor._lower_spin.position;var upper_before:=actor._upper_spin.position
  actor.set_wringer_running(true);actor._process(.1);actor.set_wringer_running(false)
  check(actor._lower_spin.position==lower_before and actor._upper_spin.position==upper_before,"rollers rotate about their own shafts without orbiting")
  var untouched:=actor.mechanism_snapshot()
  actor.interact_control("fill",player);actor.interact_control("drain",player);actor.interact_control("wringer",player)
  check(actor.mechanism_snapshot()==untouched,"legacy clicks cannot toggle washer controls")
  await move_part(actor,actor._fill_handles[0],Vector3(.043,0,0),Vector3(-.35,1.60,-.65),PI)
  check(is_equal_approx(actor._fill_openings.x,.25) and is_zero_approx(actor._fill_openings.y),"hot cock independent quarter opening")
  await move_part(actor,actor._fill_handles[1],Vector3(-.043,0,0),Vector3(-.35,1.60,-.65),PI*2)
  check(is_equal_approx(actor._fill_openings.y,.5),"cold cock retains independent half opening")
  actor.set_wringer_swing(0,0)
  await move_part(actor,actor._drain_handle,Vector3(.01,.065,0),Vector3(.85,.38,-.10),PI*.25)
  check(is_equal_approx(actor._drain_opening,.5),"drain retains half opening")
  if OS.get_environment("WASHER_DIAG")=="1":
   world.shutdown_for_tests();world.free();get_tree().quit(0 if failures.is_empty() else 1);return
  await move_part(actor,actor._agitator_drive,Vector3(0,.11,-.015),Vector3(.70,.60,-.90),actor.DRIVE_STOP)
  check(actor.state==FunctionalProp.PState.OPERATING,"drive lever engages original gyrator owner")
  await move_part(actor,actor._agitator_drive,Vector3(0,.11,-.015),Vector3(.70,.60,-.90),0)
  check(actor.state==FunctionalProp.PState.IDLE,"drive lever disengages agitation")
  await move_part(actor,actor._wringer_drive,Vector3(0,.11,-.015),Vector3(.70,.60,-.90),actor.DRIVE_STOP)
  check(actor._wringer_running,"second drive lever engages wringer")
  await move_part(actor,actor._release_bar,Vector3(.15,0,-.09),Vector3(.05,1.45,-.75),deg_to_rad(8))
  check(actor._safety_released and not actor._wringer_running,"safety bar releases pressure and disengages drive")
  actor._set_pressure_turn(0)
  await move_part(actor,actor._wringer_drive,Vector3(0,.11,-.015),Vector3(.70,.60,-.90),0)
  var guarded:=actor._drive_grip("wringer_drive");guarded.begin.call();guarded.write.call(actor.DRIVE_STOP);guarded.end.call()
  check(not actor._wringer_running and actor._roller_gap>=.04,"held drive cannot defeat safety release")
  await get_tree().create_timer(.75).timeout
  await move_part(actor,actor._reset_handle,Vector3(0,0,-.075),Vector3(.85,1.35,-.50),deg_to_rad(30))
  check(not actor._safety_released and is_zero_approx(actor._roller_gap),"reset lever re-latches original pressure mechanism")
  check(is_zero_approx(actor._reset_handle.rotation.x),"reset spring returns on release")
  actor._water_quantity=.6
  var before:=actor._water_quantity
  actor._process(1.0)
  check(actor._water_quantity<before and actor._water.visible,"simultaneous partial fill and drain change water quantity")
  actor._set_fill_opening(0,0);actor._set_fill_opening(1,0);actor._set_drain_opening(0)
  var invalid:=actor.mechanism_snapshot();invalid.fill=[NAN,0.0]
  check(not actor.valid_mechanism(invalid),"nonfinite cock save refused")
  invalid=actor.mechanism_snapshot();invalid.drive=actor.DRIVE_STOP;invalid.gap=.04
  check(not actor.valid_mechanism(invalid),"running-with-released-pressure save refused")
  actor.restore_mechanism({"lid":0.0,"swing":0.0,"gap":0.0})
  check(actor.valid_mechanism(actor.mechanism_snapshot()),"legacy three-field saves remain readable")
  var saved:=actor.mechanism_snapshot();saved.fill=[.23,.61];saved.drain=.37;saved.agitator=.14;saved.drive=.18;saved.water=.72
  actor.restore_mechanism(saved);actor.set_process(false)
  expected[identity]=actor.mechanism_snapshot()
  check(actor.valid_mechanism(expected[identity]),"all fractional controls form valid durable save")
  player.global_position=actor.to_global(Vector3(.8,.5,-1.3));player.camera.look_at(actor.to_global(Vector3(0,.68,0)))
  await shot(identity)
 household.capture_now()
 # Stop both fluxes in the reconstructed frame before time can advance.
 world.shutdown_for_tests();world.free();await get_tree().process_frame
 world=(load(selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot;add_child(world)
 for identity: String in expected:
  var actor: WasherProp=world.adapter.resolve(identity);actor.set_process(false)
 await get_tree().physics_frame
 check(not world.startup_failed,"fresh V2 root accepts expanded washer save")
 for identity: String in expected:
  var actor: WasherProp=world.adapter.resolve(identity)
  var saved: Dictionary=actor.mechanism_snapshot()
  for key: String in expected[identity]:
   var a: Variant=saved[key];var b: Variant=expected[identity][key]
   var equal:=true
   if a is Array:
    for i in a.size():equal=equal and is_equal_approx(float(a[i]),float(b[i]))
   else:equal=is_equal_approx(float(a),float(b))
   check(equal,"fresh root retains "+identity+"/"+key)
 world.shutdown_for_tests();world.free();await get_tree().process_frame
 print("WASHER CONTROLS: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures.size()," failures")
 get_tree().quit(0 if failures.is_empty() else 1)
