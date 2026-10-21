extends Node3D
const Grid=preload("res://tests/native_triangle_grid.gd")
var failures: Array[String]=[]
var records: Array=[]
func _ready() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("NATIVE TRIANGLE GRID CHECK: ",label," = ",ok)
 if not ok:failures.append(label)
func _body(shapes: Array[Shape3D],layer: int) -> StaticBody3D:
 var body:=StaticBody3D.new();body.collision_layer=layer;body.collision_mask=0
 for stock: Shape3D in shapes:
  var child:=CollisionShape3D.new();child.shape=stock;body.add_child(child)
 add_child(body);return body
func _triangles(shapes: Array[Shape3D]) -> Dictionary:
 var result: Dictionary={}
 for shape: ConcavePolygonShape3D in shapes:
  var faces: PackedVector3Array=shape.get_faces()
  for index in range(0,faces.size(),3):
   var key: String=faces.slice(index,index+3).to_byte_array().hex_encode()
   result[key]=int(result.get(key,0))+1
 return result
func _run() -> void:
 var skin:=preload("res://scripts/building/orison_v2_fire_cabinet_skin.gd").new()
 if not skin.load_stock():get_tree().quit(1);return
 for identity: String in ["SafetyWire","GlazingSeal","F065","F069"]:
  var mesh: Mesh=skin.meshes[identity]
  var original: ConcavePolygonShape3D=mesh.create_trimesh_shape()
  var parts: Array[Shape3D]=Grid.build(original)
  check(parts.size()>1 if identity!="F069" else parts.size()==1,identity+" expected acceleration or unchanged small-stock fallback")
  check(_triangles([original])==_triangles(parts),identity+" every original triangle and winding remains byte-exact")
  var properties_ok:=true
  for part: ConcavePolygonShape3D in parts:properties_ok=properties_ok and part.margin==original.margin and part.backface_collision==original.backface_collision
  check(properties_ok,identity+" original margin and backface state retained")
  var source:=_body([original],1);var candidate:=_body(parts,2)
  await RenderingServer.frame_post_draw;await get_tree().physics_frame;await get_tree().physics_frame
  var bounds:=mesh.get_aabb();var mismatches:=0;var error:=0.;var queries:=0
  for axis in 3:
   for side: float in [-1.,1.]:
    for u in 12:
     for v in 12:
      var at: Vector3=bounds.get_center()
      var a: int=(axis+1)%3;var b: int=(axis+2)%3
      at[a]=lerpf(bounds.position[a],bounds.end[a],(u+.5)/12.)
      at[b]=lerpf(bounds.position[b],bounds.end[b],(v+.5)/12.)
      var direction:=Vector3.ZERO;direction[axis]=1.05*side
      var query:=PhysicsRayQueryParameters3D.create(at+direction,at-direction,1)
      var before: Dictionary=get_world_3d().direct_space_state.intersect_ray(query);query.collision_mask=2
      var after: Dictionary=get_world_3d().direct_space_state.intersect_ray(query);queries+=1
      if before.is_empty()!=after.is_empty():mismatches+=1
      elif not before.is_empty():error=maxf(error,before.position.distance_to(after.position))
  check(mismatches==0 and error<.000001,identity+" three-axis paired original-engine ray footprints/contacts within1um")
  var capsule:=CapsuleShape3D.new();capsule.radius=.22;capsule.height=1.72
  var source_player:=CharacterBody3D.new();source_player.collision_layer=0;source_player.collision_mask=1;add_child(source_player)
  var candidate_player:=CharacterBody3D.new();candidate_player.collision_layer=0;candidate_player.collision_mask=2;add_child(candidate_player)
  for body: CharacterBody3D in [source_player,candidate_player]:
   var collision:=CollisionShape3D.new();collision.shape=capsule;body.add_child(collision)
  await RenderingServer.frame_post_draw;await get_tree().physics_frame;await get_tree().physics_frame
  var motions: Array=[];var capsule_ok:=true;var travel_error:=0.
  for repeat in 3:
   for side: float in [-1.,1.]:
    for x: float in [.1,.5,.9]:
     var at:=Vector3(lerpf(bounds.position.x,bounds.end.x,x),bounds.get_center().y-.45,bounds.get_center().z+side*.40)
     var query:=PhysicsTestMotionParameters3D.new();query.from=Transform3D(Basis.IDENTITY,at);query.motion=Vector3(0,0,-side*.2);query.margin=.001
     var before:=PhysicsTestMotionResult3D.new();var after:=PhysicsTestMotionResult3D.new()
     var old_blocked:=false;var new_blocked:=false;var old_us:=0;var new_us:=0
     for order in 2:
      var old_first: bool=(order==0)==(repeat%2==0)
      var start:=Time.get_ticks_usec()
      if old_first:old_blocked=PhysicsServer3D.body_test_motion(source_player.get_rid(),query,before);old_us=Time.get_ticks_usec()-start
      else:new_blocked=PhysicsServer3D.body_test_motion(candidate_player.get_rid(),query,after);new_us=Time.get_ticks_usec()-start
     var distance: float=before.get_travel().distance_to(after.get_travel());travel_error=maxf(travel_error,distance)
     capsule_ok=capsule_ok and old_blocked==new_blocked and distance<.0001
     motions.append({"repeat":repeat,"source_first":repeat%2==0,"source_us":old_us,"candidate_us":new_us,"blocked":old_blocked,"candidate_blocked":new_blocked,"travel_error_m":distance,"source_contacts":before.get_collision_count(),"candidate_contacts":after.get_collision_count()})
  check(capsule_ok,identity+" alternating-order actual capsule contact/travel within100um")
  records.append({"id":identity,"triangles":original.get_faces().size()/3,"parts":parts.size(),"rays":queries,"ray_mismatches":mismatches,"max_ray_error_m":error,"max_capsule_travel_error_m":travel_error,"capsule_casts":motions})
  source_player.free();candidate_player.free();source.free();candidate.free()
 var out:=OS.get_environment("SHOT_DIR")
 if not out.is_empty():
  DirAccess.make_dir_recursive_absolute(out)
  FileAccess.open(out.path_join("contacts.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Paired original-engine contact equivalence and byte-exact triangles only. No hulls/caps or changed vertices; open source stock stays open. Does not establish absolute native1um engine accuracy or whole-world/runtime qualification.","records":records,"failures":failures},"\t"))
 print("NATIVE TRIANGLE GRID BENCH: failures=",failures.size());get_tree().quit(0 if failures.is_empty() else 1)
