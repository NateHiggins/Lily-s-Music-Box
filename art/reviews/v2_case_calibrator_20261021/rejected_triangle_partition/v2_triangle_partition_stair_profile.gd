extends "res://tests/v2_floor_transition_profile.gd"
## Diagnostic A/B/A only: original / exact disconnected triangle partitions /
## restored original. All bodies, masks, transforms and triangles are retained.
const Parts=preload("res://tests/native_component_triangles.gd")
var entries: Array[Dictionary]=[]
var partition_records: Array[Dictionary]=[]
func _init() -> void:route_label="V2 TRIANGLE PARTITION STAIR CONTROL"
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
    var key: String=hash.finish().hex_encode()
    if not bank.has(key):
     var mesh:=ArrayMesh.new();var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=faces
     mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
     bank[key]=Parts.build(mesh)
    var shapes: Array=bank[key]
    if shapes.size()<2 or shapes.size()>128:continue
    var children: Array[CollisionShape3D]=[]
    for shape: Shape3D in shapes:
     var node:=CollisionShape3D.new();node.name="ExactTrianglePartition";node.shape=shape;node.transform=source.transform;node.disabled=true;body.add_child(node);children.append(node)
    entries.append({"original":source,"parts":children})
    partition_records.append({"body":str(body.get_path()),"source_shape":str(source.get_path()),"triangles":faces.size()/3,"parts":shapes.size(),"faces_sha256":key,"transform":str(source.transform),"layer":body.collision_layer,"mask":body.collision_mask})
 return not entries.is_empty()
func _swap(enabled: bool) -> void:
 player.set_physics_process(false)
 await get_tree().process_frame
 for entry: Dictionary in entries:
  entry.original.disabled=enabled
  for node: CollisionShape3D in entry.parts:node.disabled=not enabled
 await get_tree().physics_frame;await get_tree().physics_frame
 player.set_physics_process(true)
 for frame in 30:await get_tree().process_frame
func _play_route() -> void:
 player.profile_physics=true;player._profile_disable_step_guard=false
 profile_phase="partition_prepare"
 if not _require(_prepare_partitions(),"actual installed hand bodies have disconnected triangle stocks"):return
 for cycle in 3:
  profile_cycle=["original_a_","partition_b_","restored_a_"][cycle]
  profile_phase=profile_cycle+"shape_switch"
  await _swap(cycle==1)
  var start:=player.physics_profile_records.size()
  for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.975,3.2,-3.4),Vector3(1.925,3.2,-3.4)]:
   if not await _walk(target):return
  profile_phase=profile_cycle+"upper_turn"
  for frame in 120:
   var motion:=InputEventMouseMotion.new();motion.relative=Vector2(6,0);player._unhandled_input(motion);await get_tree().process_frame
  for target: Vector3 in [Vector3(3.975,3.2,-3.4),Vector3(3.975,1.6,1.3),Vector3(1.925,1.6,1.3),Vector3(1.925,0,-3.5)]:
   if not await _walk(target):return
  for record: Dictionary in player.physics_profile_records.slice(start):record["collision_control"]=profile_cycle
 await _swap(false)
 for entry: Dictionary in entries:
  for node: CollisionShape3D in entry.parts:node.free()
 entries.clear()
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():FileAccess.open(out.path_join("partitions.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Temporary exact triangle acceleration partition, original masks/bodies/poses; actual27-waypointA/B/A, not production integration or runtime qualification.","records":partition_records,"failures":failures},"\t"))
