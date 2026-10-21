extends Node3D
## INERT real-input, imported-material and case-authority bench.
const PlungerFactory = preload("res://scripts/cases/orison_v2_calibrator_plunger.gd")
var checks := 0
var failures: Array[String] = []
var phases: Array[String] = []
var player: PlayerController
var item: CaseInteractable
var control: Node3D
var presses := 0
var checks_log: Array[Dictionary] = []
var native_events: Array[Dictionary]=[]
var input_phase:="setup"
func _input(event: InputEvent) -> void:
 if event is InputEventMouseMotion:native_events.append({"at":Time.get_ticks_msec(),"phase":input_phase,"relative":str(event.relative)})

func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks += 1; checks_log.append({"label":label,"ok":ok})
 if not ok: failures.append(label)
 print("CALIBRATOR CHECK: ",label," = ",ok)
func click() -> void:
 input_phase="click"
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
func aim() -> void:
 player.camera.global_position=item.to_global(Vector3(.23,.78,.62))
 player.camera.look_at(item.to_global(Vector3(0,.449,0)))
func frames(count: int) -> void:
 for i in count: await get_tree().physics_frame
func move_to(goal: float) -> void:
 input_phase="move_"+str(goal)
 if not player._grab.active():check(false,"motion requires actual acquired plunger");return
 var descriptor: Dictionary=player._grab.target
 var point: Vector3=descriptor.part.to_global(player._grab.contact)
 var axis: Vector3=descriptor.frame.global_basis*descriptor.axis
 var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
 var event:=InputEventMouseMotion.new();event.relative=screen*(goal-float(descriptor.read.call()))/.025
 player._unhandled_input(event)
 await frames(2)
func shot(label: String) -> void:
 var out:=OS.get_environment("SHOT_DIR")
 if out.is_empty():return
 DirAccess.make_dir_recursive_absolute(out)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
func press_once() -> void:
 aim();await frames(2);click();await move_to(.004);click();await frames(14)

func measure_stock_bearing(expected_gap: float) -> void:
 var fixed:=control.get_node("Fixed__brass_dull") as MeshInstance3D
 var moving:=control.plunger.get_node("Plunger__brass_dull") as MeshInstance3D
 var bodies: Array[StaticBody3D]=[]
 for draw: MeshInstance3D in [fixed,moving]:
  var body:=StaticBody3D.new();body.collision_layer=1<<(28+bodies.size());body.collision_mask=0
  draw.add_child(body);var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();body.add_child(shape);bodies.append(body)
 await frames(2)
 var stop_query:=PhysicsRayQueryParameters3D.create(item.to_global(Vector3(.011,.9,0)),item.to_global(Vector3(.011,-.1,0)),1<<28)
 var flange_query:=PhysicsRayQueryParameters3D.create(item.to_global(Vector3(.011,-.1,0)),item.to_global(Vector3(.011,.9,0)),1<<29)
 var stop_hit:=get_world_3d().direct_space_state.intersect_ray(stop_query)
 var flange_hit:=get_world_3d().direct_space_state.intersect_ray(flange_query)
 check(stop_hit.get("collider")==bodies[0] and flange_hit.get("collider")==bodies[1],"bearing probes hit original imported stop and moving shoulder")
 if not stop_hit.is_empty() and not flange_hit.is_empty():
  var gap: float=item.to_local(flange_hit.position).y-item.to_local(stop_hit.position).y
  check(absf(gap-expected_gap)<.00004 and stop_hit.normal.dot(Vector3.UP)>.999 and flange_hit.normal.dot(Vector3.DOWN)>.999,"native shoulder gap matches physical stroke within forty micrometres")
 for body: StaticBody3D in bodies:body.free()
 await frames(2)

func _run() -> void:
 RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.12,.14,.17)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.5;add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.2;add_child(light)
 player=PlayerController.new();add_child(player);player.position=Vector3(0,0,1);player.set_physics_process(false);player.set_beam_mask_enabled(false);player.set_lamp_enabled(false);player.camera.make_current()
 player.set_mouse_released(false)
 item=CaseInteractable.new();item.setup("CAPTION CALIBRATOR","Run caption calibration",func(): presses+=1;return {},Color(.16,.31,.36),Vector3(.48,.42,.26),"calibrator");add_child(item)
 aim();await frames(2);await shot("legacy_box")
 # Original click response is a retained negative control, not new compliance.
 click();check(presses==1 and not player._grab.active(),"legacy negative control dispatches on click without hand motion")
 await frames(20);presses=0
 control=PlungerFactory.new();check(control.configure(item),"native housing and independent plunger mount")
 if item.physical_control==null: _finish();return
 phases.append("native_mount")
 var fixed_events: Array=[]
 player.world_modified.connect(func(at: Vector3,identity: String):fixed_events.append([at,identity]))
 player.camera.look_at(item.to_global(Vector3(0,.21,.134)))
 await frames(2);player._update_prompt();click()
 check(item.interact_prompt().is_empty() and player._prompt.text.is_empty() and player._target_dot.state=="idle" and not player._grab.active() and presses==0,"fixed housing has no operable target, semantic prompt or activation")
 check(fixed_events.is_empty(),"fixed housing click cannot emit a world modification")
 var uv_review:=preload("res://tests/arcade_clock_bench.gd").new();uv_review.externally_managed=true;add_child(uv_review)
 var draws:=control.find_children("*","MeshInstance3D",true,false)
 check(draws.size()==5,"exactly five native material draws")
 for draw: MeshInstance3D in draws:
  draw.set_meta("arcade_clock_part",draw.get_meta("calibrator_part"));uv_review._check_surface(draw)
  var material:=draw.mesh.surface_get_material(0) as StandardMaterial3D
  check(material!=null and not material.uv1_triplanar,"physical PBR uses metre charts "+str(draw.name))
  for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
   var image:=texture.get_image() if texture!=null else null
   check(image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(float(maxi(image.get_width(),image.get_height())))/log(2.))),"complete loaded physical-map mip chain "+str(draw.name))
  check(material.normal_enabled,"custom normal map enabled "+str(draw.name))
 check(uv_review.failures.is_empty(),"all imported UV metrics and tangent derivatives pass")
 uv_review.free();phases.append("loaded_surfaces")
 await measure_stock_bearing(.004)
 aim();await frames(2);player._update_prompt()
 check(player._target_dot.state=="available","hover resolves actual plunger")
 var camera_before:=player.camera.global_transform
 click();check(player._grab.active() and player._grab.target.part==control.plunger,"primary click grabs specific moving part")
 check(presses==0 and is_zero_approx(control.stroke),"acquire does not activate or move control")
 await move_to(.002)
 check(absf(control.stroke-.002)<.00001 and presses==0,"half stroke stays partial and cannot invoke case callback")
 check(player.camera.global_transform.is_equal_approx(camera_before),"drag leaves camera stable")
 click();check(presses==0 and not player._grab.active(),"next click releases partial stroke without activation")
 await frames(14);check(control.stroke==0.0 and not control.is_physics_processing(),"spring returns exactly to rest and stops processing")
 for goal: float in [.000561,.001116,.001672,.002228]:
  aim();await frames(2);click();await move_to(goal);click();await frames(14)
  check(control.stroke==0.0 and not control.is_physics_processing() and not control.grip().is_empty(),"micrometre residual settles and rearms after actual partial stroke "+str(goal))
 phases.append("partial_release")
 aim();await frames(2);click();await move_to(.004)
 check(absf(control.stroke-.004)<.00001 and presses==1,"actual full mouse stroke dispatches callback once")
 await measure_stock_bearing(0.0)
 await move_to(.02);player._update_prompt()
 check(absf(control.stroke-.004)<.00001 and presses==1,"physical stop cannot overtravel or repeat outcome")
 check(player._target_dot.state=="limit","accepted stop supplies shared reticle limit feedback")
 await shot("depressed_stop")
 await move_to(0.0);await move_to(.004)
 check(presses==1,"same latched grab cannot duplicate activation by pumping")
 click();await frames(14);check(presses==1 and is_zero_approx(control.stroke),"release returns without another outcome")
 await press_once();check(presses==2,"new deliberate full press can activate once again")
 phases.append("full_stroke")
 var obstruction:=StaticBody3D.new();add_child(obstruction)
 var obstruction_shape:=CollisionShape3D.new();var plate:=BoxShape3D.new();plate.size=Vector3(.05,.001,.05);obstruction_shape.shape=plate;obstruction.add_child(obstruction_shape);obstruction.position=Vector3(0,.4345,0)
 await frames(2);aim();click();await move_to(.004);player._update_prompt()
 check(control.stroke>0 and control.stroke<.003 and presses==2,"foreign physical plate blocks cap before activation")
 print("OBSTRUCTION_FEEDBACK ",JSON.stringify({"visible":player._target_dot.state,"feedback":player._grab.motion_feedback,"pending":player._grab._feedback_pending,"until":player._grab._feedback_until,"now":Time.get_ticks_msec(),"active":player._grab.active(),"stroke":control.stroke,"mode":Input.mouse_mode}))
 check(player._target_dot.state=="blocked","shared accepted-motion feedback reports physical obstruction")
 click();await frames(14)
 check(is_zero_approx(control.stroke) and presses==2,"spring withdraws from obstruction without another callback")
 obstruction.free();await frames(2);await press_once()
 check(presses==3,"removing physical obstruction restores the original full stroke")
 item.interact(player);check(presses==3,"legacy direct call cannot bypass installed physical control")
 item.set_enabled(false);await frames(2);aim();click()
 check(item.visible and item.collision_layer==1,"case refusal retains installed housing and collision")
 check(not player._grab.active() and control.target_area.collision_layer==0 and presses==3,"disabled case control is neither selectable nor actionable")
 item.set_enabled(true);RealityState.save_write_blocked=true;await frames(2);aim();click()
 check(not player._grab.active() and presses==3,"save authority refuses physical acquisition")
 RealityState.save_write_blocked=false
 aim();await frames(2);click();await move_to(.002);player.camera.global_position+=Vector3(0,0,3);player._grab.validate()
 check(not player._grab.active() and presses==3,"lost reach releases partial control without case action")
 await frames(14);check(is_zero_approx(control.stroke),"lost-reach release springs back")
 aim();await frames(2);click();item.set_enabled(false);player._grab.validate()
 check(not player._grab.active() and not control.held,"case disable interrupts ownership safely")
 item.set_enabled(true);await frames(14);phases.append("guards")
 # Call the real Mina owner through the same physical mechanism. No case
 # facts are patched by this control; a forbidden calibration stays forbidden.
 var tracker:=ObjectiveTracker.new();add_child(tracker)
 var mina:=MinaCaseGameplay.new();mina.setup(tracker);add_child(mina)
 item.action=mina._use_calibrator
 RealityCases.activate_case(MinaCaseGameplay.CASE_ID)
 var state_before:=RealityState.case_state(MinaCaseGameplay.CASE_ID).duplicate(true)
 await press_once()
 check(RealityState.case_state(MinaCaseGameplay.CASE_ID)==state_before,"full stroke preserves case owner's unrepaired-transmitter refusal")
 RealityCases.stabilize_case(MinaCaseGameplay.CASE_ID);RealityCases.reopen_case(MinaCaseGameplay.CASE_ID)
 state_before=RealityState.case_state(MinaCaseGameplay.CASE_ID).duplicate(true)
 await press_once()
 check(RealityState.case_state(MinaCaseGameplay.CASE_ID)==state_before,"full stroke preserves missing-caption refusal")
 for i in MinaCaseGameplay.EVIDENCE.size():
  var spec: Dictionary=MinaCaseGameplay.EVIDENCE[i]
  for attempt in 4:
   if "caption_1_%s=%s"%[spec.id,spec.fact] in RealityState.case_state(MinaCaseGameplay.CASE_ID).apartment_changes:break
   mina._inspect(spec.id)
 await press_once()
 var state:=RealityState.case_state(MinaCaseGameplay.CASE_ID)
 check(state.stage=="stabilized" and state.repair_count==2,"full physical press delegates permitted stabilization to case authority")
 var item_before:=var_to_bytes(RealityState.data.maintenance_items)
 await press_once()
 check(RealityState.case_state(MinaCaseGameplay.CASE_ID)==state and var_to_bytes(RealityState.data.maintenance_items)==item_before,"repeat calibration cannot invent repair or inventory facts")
 phases.append("case_authority")
 aim();await shot("native_player")
 var witness: WeakRef=weakref(control);item.free();await frames(2)
 check(witness.get_ref()==null,"control and moving targets retire with original case object")
 mina.free();phases.append("teardown");_finish()

func _finish() -> void:
 var expected: Array[String]=["native_mount","loaded_surfaces","partial_release","full_stroke","guards","case_authority","teardown"]
 check(phases==expected,"all mechanical, authority and teardown phases executed")
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out)
  FileAccess.open(out.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"phases":phases,"checks_log":checks_log,"native_events":native_events},"\t"))
 print("CALIBRATOR HAND BENCH: ",checks," checks; ",failures.size()," failures")
 get_tree().quit(0 if failures.is_empty() else 1)
