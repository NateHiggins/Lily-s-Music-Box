extends "res://tests/v2_triangle_partition_stair_profile.gd"
## Separate diagnostic of exact spatial buckets, not closed-shell/hull proxies.
const Grid=preload("res://tests/native_triangle_grid.gd")
func _init() -> void:route_label="V2 EXACT TRIANGLE GRID STAIR CONTROL"
func _prepare_partitions() -> bool:
 var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
 var bank: Dictionary={}
 for reference: WeakRef in native.stations.values():
  var actor: Node3D=reference.get_ref()
  for body: CollisionObject3D in actor._bodies.values():
   for source: Node in body.get_children():
    if source is not CollisionShape3D or source.disabled or source.shape is not ConcavePolygonShape3D:continue
    var faces: PackedVector3Array=source.shape.get_faces()
    var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(faces.to_byte_array())
    hash.update(JSON.stringify([source.shape.margin,source.shape.backface_collision]).to_utf8_buffer())
    var key: String=hash.finish().hex_encode()
    if not bank.has(key):bank[key]=Grid.build(source.shape)
    var shapes: Array=bank[key]
    if shapes.size()<2:continue
    var children: Array[CollisionShape3D]=[]
    for shape: Shape3D in shapes:
     var node:=CollisionShape3D.new();node.name="ExactTriangleGrid";node.shape=shape;node.transform=source.transform;node.disabled=true;body.add_child(node);children.append(node)
    entries.append({"original":source,"parts":children})
    partition_records.append({"body":str(body.get_path()),"source_shape":str(source.get_path()),"triangles":faces.size()/3,"parts":shapes.size(),"geometry_and_shape_state_sha256":key,"transform":str(source.transform),"layer":body.collision_layer,"mask":body.collision_mask,"margin":source.shape.margin,"backface":source.shape.backface_collision})
 return not entries.is_empty()
func _finish_partitions() -> void:
 await _swap(false)
 for entry: Dictionary in entries:
  for node: CollisionShape3D in entry.parts:node.free()
 entries.clear()
func _play_route() -> void:
 player.profile_physics=true;player._profile_disable_step_guard=false
 profile_phase="grid_prepare_excluded"
 if not _require(_prepare_partitions(),"installed native high-triangle stock receives exact spatial buckets"):return
 for cycle in 3:
  profile_cycle=["original_a_","grid_b_","restored_a_"][cycle]
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
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out)
  FileAccess.open(out.path_join("partitions.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"48 actual movement waypoints plus three installed inspection/grab programmes. Original / exact spatial triangle grid / restored original, all original geometry vertices, masks, transforms and movement rules retained. Inspection end restores the original saved mechanism fixture outside compared windows. No hull/cap/simplification or runtime qualification.","records":partition_records,"failures":failures},"\t"))
func _inspection_route() -> bool:
 var inspection_prefix: String=profile_cycle
 profile_cycle=inspection_prefix+"inspection_approach_"
 for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4)]:
  if not await _walk(target):return false
 var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
 var actor: Node3D=native.stations["F02_FIRE_LINE_STAIR"].get_ref()
 var saved: Dictionary=actor.mechanism_snapshot()
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
