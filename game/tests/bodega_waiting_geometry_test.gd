extends "res://tests/bodega_initial_placement_test.gd"
## Candidate measurement only; these are not installed authored route markers.
var surveyed := false
const CANDIDATES := {"wait_front": Vector3(.85,.04,-3.42), "wait_rear": Vector3(.85,.04,-4.12),
 "access_front": Vector3(1.55,.04,-3.42), "access_rear": Vector3(1.55,.04,-4.12),
 "service_turn": Vector3(1.55,.04,-2.72), "entry_turn": Vector3(1.55,.04,-1.12),
 "overflow": Vector3(1.35,.04,.95), "overflow_approach": Vector3(1.35,.04,3.4)}

func _snapshot() -> Dictionary:
 var result := super._snapshot()
 for path: String in [get_script().resource_path, scene_file_path]:
  result[path] = {"sha256": FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()}
 return result

func _finish() -> void:
 if failures.is_empty() and not surveyed:
  surveyed = true
  _survey()
 await super._finish()

func _survey() -> void:
 var shop: Node3D = exterior.instance_node("SHOP_BODEGA")
 var space := get_world_3d().direct_space_state
 var leaf := exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF")
 _check(leaf.is_ready_for_passage(), "candidate path survey uses actual opened leaf")
 var points := {}; var findings: Array = []
 var shape := CapsuleShape3D.new(); shape.radius=.28; shape.height=1.40
 var query := PhysicsShapeQueryParameters3D.new(); query.shape=shape; query.collision_mask=1; query.exclude=[player.get_rid()]
 var raw := CANDIDATES.duplicate()
 raw.service = shop.to_local(exterior.spatial_resolver.resolve_placement("SHOP_BODEGA", "service_stance").position)
 raw.interior = shop.to_local(exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[4].placement.position)
 raw.exterior = shop.to_local(exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[3].placement.position)
 raw.alignment = shop.to_local(exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[2].placement.position)
 for id: String in raw:
  var at: Vector3 = shop.to_global(raw[id])
  var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.34, at-Vector3.UP*.5, 1))
  _check(not hit.is_empty(), "candidate has actual support " + id)
  if hit.is_empty(): continue
  var authored := at; at.y=hit.position.y; points[id]=at
  query.transform.origin=at+Vector3.UP*.95; query.motion=Vector3.ZERO
  var hits := space.intersect_shape(query,8)
  _check(hits.is_empty(), "candidate full NPC clears native stock " + id)
  var safe := leaf.standing_position_clear(at,.28,1.65)
  if id not in ["interior","service"]: _check(safe,"candidate standing clears full leaf arc " + id)
  findings.append({"id":id,"local":raw[id],"authored":authored,"feet":at,"floor":str(hit.collider.get_path()),"leaf_arc_clear":safe,"hits":_hit_paths(hits)})
 var routes_to_check := {"inbound_front":["exterior","interior","entry_turn","access_front","wait_front"],
 "rear_head":["wait_rear","access_rear","access_front","service_turn","service"],
 "front_head":["wait_front","access_front","service_turn","service"],
 "departure":["service","interior","exterior","alignment"],
 "overflow":["alignment","overflow_approach","overflow","exterior"]}
 var sweeps: Array=[]
 for id: String in routes_to_check:
  var ids: Array=routes_to_check[id]
  for reverse: bool in [false,true]:
   var sequence:=ids.duplicate()
   if reverse: sequence.reverse()
   for edge in sequence.size()-1:
    if not points.has(sequence[edge]) or not points.has(sequence[edge+1]): continue
    var a: Vector3=points[sequence[edge]]; var b: Vector3=points[sequence[edge+1]]
    var previous:=a
    for step in range(ceili(a.distance_to(b)/.01)+1):
     var at:=a.lerp(b, minf(1.0,float(step)/maxi(1,ceili(a.distance_to(b)/.01))))
     var floor_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.34,at-Vector3.UP*.5,1))
     if floor_hit.is_empty(): _check(false,"path missing floor "+id);break
     at.y=floor_hit.position.y
     if absf(at.y-previous.y)>.25: _check(false,"candidate exceeds motor support step "+id);break
     query.transform.origin=at+Vector3.UP*.95;query.motion=Vector3.ZERO
     var hits:=space.intersect_shape(query,8)
     if not hits.is_empty(): sweeps.append({"route":id,"reverse":reverse,"at":at,"hits":_hit_paths(hits)});_check(false,"candidate path native collision "+id);break
     query.transform.origin=previous+Vector3.UP*.95;query.motion=at-previous
     var cast:=space.cast_motion(query)
     if cast.size()!=2 or cast[0]<1.0: sweeps.append({"route":id,"reverse":reverse,"at":at,"cast":Array(cast)});_check(false,"candidate continuous sweep "+id);break
     previous=at
 details.candidate_standing=findings;details.candidate_path_failures=sweeps
 details.candidate_scope="Measured native NPC standing/sweep candidates only; no authored adoption, peer clearance, motor corner or queue liveness proof"

func _hit_paths(hits: Array) -> Array:
 var paths: Array=[]
 for hit: Dictionary in hits: paths.append(str(hit.collider.get_path()))
 return paths
