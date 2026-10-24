extends "res://tests/orison_v2_golden_repair_route_test.gd"
## INERT installed-control review. Physical opening/arrival/2A access is played.
## Recurrence below is an explicit case-authority fixture, not an eleven-beat run.
var control_checks: Array[Dictionary]=[]
func _init() -> void: route_label="V2 INSTALLED CALIBRATOR"
func _route() -> void:
 var item: CaseInteractable=world.mina_gameplay.console
 var mechanism: Node3D=item.physical_control
 if not _require(mechanism!=null and item.visible and item.collision_layer==1,"installed guarded calibrator retains physical cabinet"):return
 if not await _open_first_shift():return
 if not await _enter_2a():return
 for point in [Vector3(-10.5,3.2,1.4),Vector3(-11.2,3.2,1.4),Vector3(-12.0,3.2,1.15)]:
  if not await _walk(point):return
 var support_query:=PhysicsRayQueryParameters3D.create(item.global_position+Vector3.UP*.02,item.global_position-Vector3.UP*.08)
 support_query.exclude=[item.get_rid()]
 var support:=world.get_world_3d().direct_space_state.intersect_ray(support_query)
 var support_node: Node=support.get("collider")
 if not _require(support_node!=null and str(support_node.name)=="F02_A_CalibratorTable" and absf((support.position as Vector3).y-item.global_position.y)<.00004,"native base seats on original caption table within forty micrometres"):return
 # Explicit authored case fixture: controls never manufacture these facts.
 RealityCases.activate_case(MinaCaseGameplay.CASE_ID)
 player.camera.look_at(item.to_global(Vector3(0,.21,.134)))
 await get_tree().physics_frame;await get_tree().physics_frame;player._update_prompt()
 if not _require(player._target_dot.state=="idle" and player._prompt.text.is_empty(),"installed fixed housing carries no false hand target or legacy instruction"):return
 var before:=RealityState.case_state(MinaCaseGameplay.CASE_ID).duplicate(true)
 if not await _stroke(item,mechanism,.002,"partial_unrepaired"):return
 if not _require(RealityState.case_state(MinaCaseGameplay.CASE_ID)==before,"installed partial stroke preserves entire unrepaired case state"):return
 if not await _stroke(item,mechanism,.004,"full_unrepaired"):return
 if not _require(RealityState.case_state(MinaCaseGameplay.CASE_ID)==before,"installed full stroke respects original transmitter prerequisite"):return
 RealityCases.stabilize_case(MinaCaseGameplay.CASE_ID);RealityCases.reopen_case(MinaCaseGameplay.CASE_ID)
 for i in MinaCaseGameplay.EVIDENCE.size():
  var spec: Dictionary=MinaCaseGameplay.EVIDENCE[i]
  for attempt in 4:
   if "caption_1_%s=%s"%[spec.id,spec.fact] in RealityState.case_state(MinaCaseGameplay.CASE_ID).apartment_changes:break
   world.mina_gameplay._inspect(spec.id)
 var jobs_before:=var_to_bytes(RealityState.data.maintenance_jobs)
 var items_before:=var_to_bytes(RealityState.data.maintenance_items)
 if not await _stroke(item,mechanism,.004,"full_prepared_recurrence"):return
 var state:=RealityState.case_state(MinaCaseGameplay.CASE_ID)
 _require(state.stage=="stabilized" and state.repair_count==2,"installed physical control delegates permitted stabilization to existing case owner")
 _require(item.visible and item.collision_layer==1 and not item.enabled and mechanism.target_area.collision_layer==0,"case completion guards only control while cabinet and collision remain")
 _require(var_to_bytes(RealityState.data.maintenance_jobs)==jobs_before and var_to_bytes(RealityState.data.maintenance_items)==items_before,"calibration neither invents nor consumes work orders or parts")
 await _photo("installed_after",item)
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  FileAccess.open(out.path_join("control_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Continuous production arrival/opening/2A walk plus installed control; explicit recurrence/evidence fixture. Not a full golden shift or human acceptance.","checks":interaction_checks,"failures":failures,"control_checks":control_checks},"\t"))
func _stroke(item: CaseInteractable,mechanism: Node3D,goal: float,label: String) -> bool:
 player.camera.look_at(item.to_global(Vector3(0,.449,0)))
 await get_tree().physics_frame;await get_tree().physics_frame
 player._update_prompt()
 if not _require(player._target_dot.state=="available","actual installed plunger available: "+label):return false
 var hand:=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new();add_child(hand);hand.player=player
 var before:=RealityState.case_state(MinaCaseGameplay.CASE_ID).duplicate(true)
 hand.click()
 if not _require(player._grab.active() and player._grab.target.part==mechanism.plunger and is_zero_approx(mechanism.stroke) and RealityState.case_state(MinaCaseGameplay.CASE_ID)==before,"installed click acquires exact part without action: "+label):hand.free();return false
 var descriptor: Dictionary=player._grab.target
 var point: Vector3=descriptor.part.to_global(player._grab.contact)
 var axis: Vector3=descriptor.frame.global_basis*descriptor.axis
 var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
 var event:=InputEventMouseMotion.new();event.relative=screen*goal/.025
 player._unhandled_input(event)
 var accepted: float=mechanism.stroke
 if player._grab.active():hand.click()
 for frame in 14:await get_tree().physics_frame
 hand.free()
 control_checks.append({"label":label,"goal":goal,"accepted":accepted,"returned":mechanism.stroke})
 if not _require(absf(accepted-goal)<.00001 and is_zero_approx(mechanism.stroke) and not player._grab.active(),"installed mouse reaches requested travel and release springs to rest: "+label):return false
 await _photo(label,item)
 return true
func _photo(label: String,item: Node3D) -> void:
 var out:=OS.get_environment("SHOT_DIR")
 if out.is_empty():return
 DirAccess.make_dir_recursive_absolute(out)
 player.camera.look_at(item.to_global(Vector3(0,.25,0)))
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
