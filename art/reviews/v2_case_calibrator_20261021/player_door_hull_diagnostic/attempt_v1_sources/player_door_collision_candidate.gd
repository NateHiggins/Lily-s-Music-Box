extends RefCounted
## Uninstalled diagnostic: a separate player-only conservative convex lane.
## All original layer1 stock remains for hands, parts, rays and world queries.
const PLAYER_LANE:=1<<21
var layers: Array=[]
var proxies: Array[StaticBody3D]=[]
var original_bodies: Array[CollisionObject3D]=[]
var errors: Array=[]
var shape_records: Array=[]
var bounds: Array[AABB]=[]
var precision: Array=[]
var _cache: Dictionary={}

static func _root(parents: PackedInt32Array,index: int) -> int:
 while parents[index]!=index:
  parents[index]=parents[parents[index]];index=parents[index]
 return index

func _closed_hulls(source: ConcavePolygonShape3D) -> Array[Shape3D]:
 if _cache.has(source):return _cache[source]
 var faces:=source.get_faces();var count: int=faces.size()/3
 var parents:=PackedInt32Array();parents.resize(count)
 for index in count:parents[index]=index
 var vertices: Dictionary={};var ids:=PackedInt32Array()
 for point: Vector3 in faces:
  if not point.is_finite():return []
  if not vertices.has(point):vertices[point]=vertices.size()
  ids.append(vertices[point])
 var edges: Dictionary={}
 for index in count:
  for corner in 3:
   var a: int=ids[index*3+corner];var b: int=ids[index*3+(corner+1)%3]
   if a==b:return []
   var key:=Vector2i(mini(a,b),maxi(a,b))
   if not edges.has(key):edges[key]=[index,a,b]
   else:
    var old: Array=edges[key]
    if old.size()!=3 or old[1]!=b or old[2]!=a:return []
    parents[_root(parents,index)]=_root(parents,int(old[0]));old.append(index)
 for edge: Array in edges.values():
  if edge.size()!=4:return []
 var groups: Dictionary={}
 for index in count:
  var key:=_root(parents,index)
  if not groups.has(key):groups[key]={}
  for corner in 3:groups[key][faces[index*3+corner]]=true
 var result: Array[Shape3D]=[]
 for points: Dictionary in groups.values():
  if points.size()<4:return []
  var shape:=ConvexPolygonShape3D.new();shape.points=PackedVector3Array(points.keys());shape.margin=.00001;result.append(shape)
 _cache[source]=result
 return result

func configure(root: Node3D,native: RefCounted) -> bool:
 var doors: Array[CollisionObject3D]=[]
 for reference: WeakRef in native.stations.values():doors.append(reference.get_ref()._bodies.door)
 for body: CollisionObject3D in root.find_children("*","CollisionObject3D",true,false):
  layers.append([body,body.collision_layer])
  if body.collision_layer&1 and body not in doors:body.collision_layer|=PLAYER_LANE
 for door: CollisionObject3D in doors:
  var proxy:=StaticBody3D.new();proxy.name="DiagnosticPlayerDoorHull";proxy.collision_layer=PLAYER_LANE;proxy.collision_mask=0;door.add_child(proxy);proxies.append(proxy);original_bodies.append(door)
  var have_bounds:=false;var envelope:=AABB()
  for node: Node in door.get_children():
   if node is not CollisionShape3D or node.disabled:continue
   var shapes: Array[Shape3D]=[]
   if node.shape is ConcavePolygonShape3D:shapes=_closed_hulls(node.shape)
   else:shapes.append(node.shape)
   if shapes.is_empty():errors.append(str(node.get_path()));return false
   for shape: Shape3D in shapes:
    if shape is not ConvexPolygonShape3D:return false
    for point: Vector3 in shape.points:
     var at: Vector3=node.transform*point
     if not have_bounds:envelope=AABB(at,Vector3.ZERO);have_bounds=true
     else:envelope=envelope.expand(at)
   for shape: Shape3D in shapes:
    var collider:=CollisionShape3D.new();collider.transform=node.transform;collider.shape=shape;proxy.add_child(collider)
   shape_records.append({"original":str(node.get_path()),"original_type":node.shape.get_class(),"proxy_components":shapes.size()})
  bounds.append(envelope)
 return doors.size()==8 and errors.is_empty()

func compare_player_envelopes(player: PlayerController) -> bool:
 # Dry casts only: other bodies are excluded identically in both queries.
 # Every original layer1 body remains enabled throughout the played route.
 var all_bodies: Array=player.get_tree().root.find_children("*","PhysicsBody3D",true,false)
 var capsule: CapsuleShape3D=player._capsule.duplicate()
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.margin=.001;query.collide_with_areas=false
 for index in original_bodies.size():
  var door: CollisionObject3D=original_bodies[index];var proxy: StaticBody3D=proxies[index]
  var excluded: Array[RID]=[]
  for body: PhysicsBody3D in all_bodies:
   if body!=door and body!=proxy:excluded.append(body.get_rid())
  query.exclude=excluded
  var envelope: AABB=bounds[index];var centre:=envelope.get_center()
  var maximum:=0.;var original_misses:=0;var extra_contacts:=0;var samples:=0
  var observations: Array=[]
  for y: float in [-.70,-.40,-.10,.20,.50,.80]:
   for x: float in [-.66,-.50,-.33,-.15,0.,.15,.33,.50,.66]:
    for side: float in [-1.,1.]:
     var at: Vector3=door.to_global(centre+Vector3(x,y,side*(envelope.size.z*.5+.7)))
     query.transform=Transform3D(Basis.IDENTITY,at);query.motion=door.global_basis*Vector3(0,0,-side*(envelope.size.z+1.4))
     query.collision_mask=1;var original: PackedFloat32Array=player.get_world_3d().direct_space_state.cast_motion(query)
     query.collision_mask=PLAYER_LANE;var candidate: PackedFloat32Array=player.get_world_3d().direct_space_state.cast_motion(query)
     samples+=1
     if original[0]<1. and candidate[0]>=1.:original_misses+=1
     if original[0]>=1. and candidate[0]<1.:extra_contacts+=1
     var error: float=absf(original[0]-candidate[0])*query.motion.length()
     maximum=maxf(maximum,error);observations.append([x,y,side,original[0],candidate[0],error])
  precision.append({"door":str(door.get_path()),"samples":samples,"maximum_cast_difference_m":maximum,"original_contacts_lost":original_misses,"extra_contacts":extra_contacts,"observations":observations})
  if original_misses>0 or extra_contacts>0 or maximum>.0005:return false
 return precision.size()==8

func restore() -> void:
 for entry: Array in layers:
  if is_instance_valid(entry[0]):entry[0].collision_layer=entry[1]
 for proxy: StaticBody3D in proxies:
  if is_instance_valid(proxy):proxy.free()
 layers.clear();proxies.clear()
