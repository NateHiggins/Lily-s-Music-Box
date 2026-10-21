extends "res://tests/v2_floor_transition_profile.gd"
## Original / lower-cap eligibility / restored; all51 original played waypoints
## and installed inspection/grab assertions retained. No geometry/mask changes.
const Controller=preload("res://tests/fire_step_sphere_control.gd")
var inspection_observations: Array=[]
func _init() -> void:route_label="V2 LOWER CAP STAIR AND INSTALLED HAND CONTROL"
func _ready() -> void:
 get_tree().node_added.connect(_install_controller);super._ready()
func _install_controller(node: Node) -> void:
 if node is PlayerController and node.get_script()!=Controller:node.set_script(Controller)
func _process(delta: float) -> void:
 if is_instance_valid(player):player.set("cost_phase",profile_phase)
 super._process(delta)
func _prepare_partitions() -> bool:return player.get_script()==Controller
func _swap(enabled: bool) -> void:
 player.set("foot_step_candidate",enabled)
 for frame in 30:await get_tree().process_frame
func _finish_partitions() -> void:
 await _swap(false)
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out)
  FileAccess.open(out.path_join("inspection_observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","observations":inspection_observations,"physics_ticks":player.get("measured_ticks"),"failures":failures},"\t"))
func _play_route() -> void:
 player.profile_physics=true;player._profile_disable_step_guard=false
 profile_phase="grid_prepare_excluded"
 if not _require(_prepare_partitions(),"installed native high-triangle stock receives exact spatial buckets"):return
 for cycle in 3:
  profile_cycle=["original_a_","lower_cap_b_","restored_a_"][cycle]
  var cycle_label: String=profile_cycle
  profile_phase=profile_cycle+"shape_switch_excluded"
  await _swap(cycle==1)
  var start:=player.physics_profile_records.size()
  for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4),Vector3(1.925,3.2,-3.4)]:
   if not await _walk(target):
    await _finish_partitions();return
  profile_phase=profile_cycle+"upper_turn"
  for frame in 120:
   var motion:=InputEventMouseMotion.new();motion.relative=Vector2(6,0);player._unhandled_input(motion);await get_tree().process_frame
  for target: Vector3 in [Vector3(3.975,3.2,-3.4),Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
   if not await _walk(target):
    await _finish_partitions();return
  if not await _inspection_route():
   await _finish_partitions();return
  profile_cycle=cycle_label
  for target: Vector3 in [Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
   if not await _walk(target):
    await _finish_partitions();return
  for record: Dictionary in player.physics_profile_records.slice(start):record["collision_control"]=cycle_label
 profile_phase="grid_restore_excluded"
 await _finish_partitions()
func _inspection_route() -> bool:
 var inspection_prefix: String=profile_cycle
 profile_cycle=inspection_prefix+"inspection_approach_"
 for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4)]:
  if not await _walk(target):return false
 var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
 var actor: Node3D=native.stations["F02_FIRE_LINE_STAIR"].get_ref()
 var saved: Dictionary=actor.mechanism_snapshot()
 profile_phase=inspection_prefix+"inspection_original_stance_probe_excluded"
 var original_obstructions: Array=_door_obstructions(actor,.25)
 if not await _walk(Vector3(3.65,3.2,-3.4)):return false
 profile_phase=inspection_prefix+"inspection_side_stance_probe_excluded"
 var side_obstructions: Array=_door_obstructions(actor,.25)
 inspection_observations.append({"cycle":inspection_prefix,"initial_obstructions":original_obstructions,"side_obstructions":side_obstructions,"side_position":str(player.global_position)})
 if not _require(side_obstructions.is_empty(),"actual walked side stance clears intended leaf sweep without exclusions"):return false
 var helper: Node=preload("res://tests/v2_fire_hand_bench.gd").new()
 helper.set_meta("shared_world_validation",true);helper.player=player;add_child(helper)
 var hand: Node=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new()
 hand.player=player;add_child(hand)
 profile_phase=inspection_prefix+"inspection_acquire_door"
 var point: Vector3=actor._door_pivot.to_global(Vector3(-.4,.1,.015))
 await helper.aim(point);helper.click()
 if not _require(player._grab.active() and player._grab.target.part==actor._door_pivot,"played approach grabs exact native cabinet leaf"):helper.free();hand.free();return false
 var original_eye: Transform3D=player.camera.transform
 profile_phase=inspection_prefix+"inspection_enter"
 helper.key(KEY_SPACE)
 if not _require(player.inspecting() and not player._grab.active() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Space enters supported installed inspection and exposes free cursor"):helper.free();hand.free();return false
 var fixed_eye: Transform3D=player.camera.global_transform
 for frame in 120:await get_tree().process_frame
 profile_phase=inspection_prefix+"inspection_cursor_acquisition"
 if not _require(await helper.acquire_surface(actor._door_pivot,point),"free cursor resolves original native door surface"):helper.free();hand.free();return false
 player._update_prompt()
 if not _require(player._target_dot.state=="available","inspection reticle shows authoritative selectable leaf"):helper.free();hand.free();return false
 helper.click()
 if not _require(player._grab.active() and player._grab.target.part==actor._door_pivot,"inspection primary click grabs actual leaf"):helper.free();hand.free();return false
 profile_phase=inspection_prefix+"inspection_drag"
 var moved: bool=await hand.move_to(.25)
 if player._grab.active():helper.click()
 inspection_observations.append({"cycle":inspection_prefix,"moved":moved,"released":not player._grab.active(),"camera_fixed":player.camera.global_transform.is_equal_approx(fixed_eye),"actual_door_angle":actor._door_angle,"camera_before":str(fixed_eye),"camera_after":str(player.camera.global_transform),"body":str(player.global_position),"inspecting":player.inspecting()})
 if not _require(moved and not player._grab.active() and player.camera.global_transform.is_equal_approx(fixed_eye),"inspection mouse moves constrained leaf and second click releases without rotating camera"):helper.free();hand.free();return false
 profile_phase=inspection_prefix+"inspection_idle"
 for frame in 120:await get_tree().process_frame
 profile_phase=inspection_prefix+"inspection_exit"
 helper.key(KEY_ESCAPE)
 if not _require(not player.inspecting() and player.camera.transform.is_equal_approx(original_eye),"inspection exit restores previous eye"):helper.free();hand.free();return false
 for frame in 30:await get_tree().process_frame
 profile_phase=inspection_prefix+"inspection_restore_fixture_excluded"
 actor.restore_mechanism(saved)
 helper.free();hand.free()
 profile_cycle=inspection_prefix
 return true

func _door_obstructions(actor: Node3D,angle: float) -> Array:
 # Exact read-only mirror of the current door constraint query. Only the
 # original source exclusions apply; the player and foreign parts remain solid.
 var part: Node3D=actor._door_pivot
 var proposed: Transform3D=part.transform;proposed.basis=Basis(actor._axis("door"),angle)
 var frame: Transform3D=part.get_parent_node_3d().global_transform*proposed
 var excluded: Array[RID]=[actor._bodies.door.get_rid()]
 for body: StaticBody3D in actor.find_children("*","StaticBody3D",true,false):
  if body is not AnimatableBody3D:excluded.append(body.get_rid())
 var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=1;query.exclude=excluded;query.margin=.00001
 var hits: Array=[];var seen: Dictionary={}
 for stock: Dictionary in actor._stock.door:
  query.shape=stock.shape;query.transform=frame*stock.frame
  for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,8):
   var object: Object=hit.collider
   var key: String=str((object as Node).get_path()) if object is Node else str(object)
   if seen.has(key):continue
   seen[key]=true;hits.append({"path":key,"player":object==player,"shape":hit.shape})
 return hits
