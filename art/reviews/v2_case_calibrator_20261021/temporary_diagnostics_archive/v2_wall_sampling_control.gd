extends "res://tests/v2_floor_transition_profile.gd"
## Diagnostic only: full instrumentation / wall-clock only / full. No gameplay,
## scene geometry, collision masks, settings outside timing measurement changed.
var wall_only:=false
func _init() -> void:route_label="V2 WALL SAMPLING OVERHEAD CONTROL"
func _process(delta: float) -> void:
 if not wall_only:
  super._process(delta);return
 var now:=Time.get_ticks_usec()
 if profile_active and previous_usec>0:
  profile_samples.append([profile_phase,(now-previous_usec)/1000.,null,null,null,null,world.passage_region.residency.state,{}])
 previous_usec=now
func _play_route() -> void:
 player._profile_disable_step_guard=false
 for cycle in 3:
  profile_cycle=["instrumented_a_","wall_only_b_","restored_a_"][cycle]
  profile_phase=profile_cycle+"sampling_switch_excluded"
  wall_only=cycle==1
  player.profile_physics=not wall_only
  RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),not wall_only)
  for frame in 30:await get_tree().process_frame
  var start:=player.physics_profile_records.size()
  for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4),Vector3(1.925,3.2,-3.4)]:
   if not await _walk(target):return
  profile_phase=profile_cycle+"upper_turn"
  for frame in 120:
   var motion:=InputEventMouseMotion.new();motion.relative=Vector2(6,0);player._unhandled_input(motion);await get_tree().process_frame
  for target: Vector3 in [Vector3(3.975,3.2,-3.4),Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
   if not await _walk(target):return
  for record: Dictionary in player.physics_profile_records.slice(start):record["sampling_control"]=profile_cycle
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out)
  FileAccess.open(out.path_join("control.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"27 actual movement waypoints; original instrumented / no render timers or GPU/CPU getters, Performance monitors or controller profiling (wall-only sampler) / restored instrumentation. Identical original gameplay/collision/render settings; timing instrumentation alone changes. Null fields mean not measured, never zero cost. Not runtime qualification or input-to-display measurement.","failures":failures},"\t"))
