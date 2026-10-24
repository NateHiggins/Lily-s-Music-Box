extends "res://tests/v2_floor_transition_profile.gd"
## Diagnostic A/B/A only. One original world and unchanged bodies/masks/steps.
func _init() -> void:route_label="V2 CONTACT STEP STAIR CONTROL"
var camera_motion: Array=[]
func _process(delta: float) -> void:
 super._process(delta)
 if profile_active and is_instance_valid(player) and is_instance_valid(player.camera):
  var body: Vector3=player.global_position;var eye: Vector3=player.camera.global_position
  camera_motion.append([profile_phase,Engine.get_process_frames(),Engine.get_physics_frames(),body.x,body.y,body.z,eye.x,eye.y,eye.z])
const Candidate=preload("res://tests/step_after_contact_control.gd")
func _ready() -> void:
 get_tree().node_added.connect(_install_controller)
 super._ready()
func _install_controller(node: Node) -> void:
 # Install before the controller's _ready builds cameras/callbacks; never
 # detach a live controller script or transfer initialized script state.
 if node is PlayerController and node.get_script()!=Candidate:node.set_script(Candidate)
func _play_route() -> void:
 if not _require(player.get_script()==Candidate,"test controller inherited production setup before ready"):return
 player.profile_physics=true;player._profile_disable_step_guard=false
 for cycle in 3:
  profile_cycle=["original_a_","contact_b_","restored_a_"][cycle]
  player.set("contact_step_candidate",cycle==1)
  var start:=player.physics_profile_records.size()
  for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4),Vector3(1.925,3.2,-3.4)]:
   if not await _walk(target):return
  profile_phase=profile_cycle+"upper_turn"
  for frame in 120:
   var motion:=InputEventMouseMotion.new();motion.relative=Vector2(6,0);player._unhandled_input(motion);await get_tree().process_frame
  for target: Vector3 in [Vector3(3.975,3.2,-3.4),Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
   if not await _walk(target):return
  for record: Dictionary in player.physics_profile_records.slice(start):record["step_control"]=profile_cycle
 player.set("contact_step_candidate",false)
 if not await _inspection_route():return
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out)
  var interpolation: Dictionary={}
  for row: Dictionary in ProjectSettings.get_property_list():
   if str(row.name).contains("interpolation"):interpolation[row.name]=ProjectSettings.get(row.name)
  for row: Dictionary in player.get_property_list():
   if str(row.name).contains("interpolation"):interpolation["player/"+str(row.name)]=player.get(row.name)
  for row: Dictionary in player.camera.get_property_list():
   if str(row.name).contains("interpolation"):interpolation["camera/"+str(row.name)]=player.camera.get(row.name)
  FileAccess.open(out.path_join("control.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"27-waypoint A/B/A plus four played approach waypoints and installed native inspection; final restore is an explicit original-snapshot fixture outside compared walk/inspection windows. Temporary derived player, only step-probe eligibility differs; physical slide, capsule/headroom/raised-motion probes, bodies, masks and saved authorities unchanged. Candidate can defer first riser lift by one physics tick. Not production integration or runtime qualification.","interpolation_settings":interpolation,"camera_columns":["phase","render_frame","physics_frame","body_x","body_y","body_z","eye_x","eye_y","eye_z"],"camera_motion":camera_motion,"skipped":player.get("contact_step_skipped"),"failures":failures},"\t"))

func _inspection_route() -> bool:
 profile_cycle="inspection_approach_"
 for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4)]:
  if not await _walk(target):return false
 var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
 var actor: Node3D=native.stations["F02_FIRE_LINE_STAIR"].get_ref()
 var saved: Dictionary=actor.mechanism_snapshot()
 var helper: Node=preload("res://tests/v2_fire_hand_bench.gd").new()
 helper.set_meta("shared_world_validation",true);helper.player=player;add_child(helper)
 var hand: Node=preload("res://tests/orison_v2_first_slice_contract_test.gd").PatrolHand.new()
 hand.player=player;add_child(hand)
 profile_phase="inspection_acquire_door"
 var point: Vector3=actor._door_pivot.to_global(Vector3(-.4,.1,.015))
 await helper.aim(point);helper.click()
 if not _require(player._grab.active() and player._grab.target.part==actor._door_pivot,"played approach grabs exact native cabinet leaf"):helper.free();hand.free();return false
 var original_eye: Transform3D=player.camera.transform
 profile_phase="inspection_enter"
 helper.key(KEY_SPACE)
 if not _require(player.inspecting() and not player._grab.active() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Space enters supported installed inspection and exposes free cursor"):helper.free();hand.free();return false
 var fixed_eye: Transform3D=player.camera.global_transform
 for frame in 120:await get_tree().process_frame
 profile_phase="inspection_cursor_acquisition"
 if not _require(await helper.acquire_surface(actor._door_pivot,point),"free cursor resolves original native door surface"):helper.free();hand.free();return false
 player._update_prompt()
 if not _require(player._target_dot.state=="available","inspection reticle shows authoritative selectable leaf"):helper.free();hand.free();return false
 helper.click()
 if not _require(player._grab.active() and player._grab.target.part==actor._door_pivot,"inspection primary click grabs actual leaf"):helper.free();hand.free();return false
 profile_phase="inspection_drag"
 var moved: bool=await hand.move_to(.25)
 if player._grab.active():helper.click()
 if not _require(moved and not player._grab.active() and player.camera.global_transform.is_equal_approx(fixed_eye),"inspection mouse moves constrained leaf and second click releases without rotating camera"):helper.free();hand.free();return false
 profile_phase="inspection_idle"
 for frame in 120:await get_tree().process_frame
 profile_phase="inspection_exit"
 helper.key(KEY_ESCAPE)
 if not _require(not player.inspecting() and player.camera.transform.is_equal_approx(original_eye),"inspection exit restores previous eye"):helper.free();hand.free();return false
 for frame in 30:await get_tree().process_frame
 profile_phase="inspection_restore_fixture_excluded"
 actor.restore_mechanism(saved)
 helper.free();hand.free()
 return true
