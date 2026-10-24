extends "res://tests/v2_low_step_stair_profile.gd"
## Uninstalled player-only convex diagnostic; original hands/contact stay layer1.
const Candidate=preload("res://tests/player_door_collision_candidate.gd")
var candidate:=Candidate.new()
func _init() -> void:route_label="V2 PLAYER DOOR HULL DIAGNOSTIC"
func _play_route() -> void:
 player.profile_physics=true;player._profile_disable_step_guard=false;player._low_step_probe_enabled=true
 profile_phase="prepare_excluded"
 if not _require(_prepare_control(),"shipping V2 controller and inert step query present"):return
 var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
 if not _require(candidate.configure(world,native),"eight player-only door query bodies retain open shells and convert only closed components; layer1 stock unchanged"):
  await _finish_control();return
 for frame in 2:await get_tree().physics_frame
 if not _require(candidate.compare_player_envelopes(player),"all864 real player capsule casts retain contacts within0.5mm"):
  await _finish_control();return
 for cycle in 3:
  profile_cycle=["original_a_","player_hulls_b_","restored_a_"][cycle]
  profile_phase=profile_cycle+"shape_switch_excluded"
  if not _require(candidate.set_enabled(player,cycle==1) and (player.collision_mask&1)==1,"original world collision layer stays enabled; validated door proxies substitute only player-door pairs"):
   await _finish_control();return
  for frame in 30:await get_tree().process_frame
  for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4),Vector3(1.925,3.2,-3.4)]:
   if not await _walk(target):await _finish_control();return
  profile_phase=profile_cycle+"upper_turn"
  for frame in 120:
   var motion:=InputEventMouseMotion.new();motion.relative=Vector2(6,0);player._unhandled_input(motion);await get_tree().process_frame
  for target: Vector3 in [Vector3(3.975,3.2,-3.4),Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
   if not await _walk(target):await _finish_control();return
  if not await _inspection_route():await _finish_control();return
  for target: Vector3 in [Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
   if not await _walk(target):await _finish_control();return
 profile_phase="restore_excluded";await _finish_control()
func _finish_control() -> void:
 player.collision_mask=1;candidate.restore()
 await super._finish_control()
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():FileAccess.open(out.path_join("player_hulls.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Uninstalled diagnostic. A/B/A player-only conservative component hulls; lower-cap step always enabled. Original layer1 native stock retained for hands, rays, carried stock, constraints and persistence. No runtime grant or1um native-surface accuracy claim.","shapes":candidate.shape_records,"precision":candidate.precision,"errors":candidate.errors,"failures":failures},"\t"))
