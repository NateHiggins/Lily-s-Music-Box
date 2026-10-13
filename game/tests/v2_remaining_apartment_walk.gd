extends "res://tests/orison_v2_roof_route_test.gd"
## Collision queries plan a route; only the ordinary player executes it.
var unit_id: String
var rooms := {}
var edges: Array[Dictionary] = []
var visited_rooms := {}
var floor_y := 0.0
var grid: AStarGrid2D
var origin := Vector2.ZERO
var pitch := .10
var public_regions:Array[Dictionary]=[]
var grid_cache:Dictionary={}
var entry_id:String
var capsule: CapsuleShape3D
var public_room: Dictionary

func _route() -> void:
 var layout:Dictionary=world.layout
 var prefix:="F0"+unit_id[0]+"_"+unit_id[1]+"_"
 floor_y=float(world.adapter.root.level_y["F0"+unit_id[0]])
 for room:Dictionary in layout.spaces:
  if str(room.id).begins_with(prefix):rooms[str(room.id)]=room
 var entry:Dictionary={}
 for door:Dictionary in layout.doors:
  var belongs:=int(rooms.has(str(door.connects[0])))+int(rooms.has(str(door.connects[1])))
  if belongs==1 and (str(door.connects[0]).ends_with("_VESTIBULE") or str(door.connects[1]).ends_with("_VESTIBULE")):entry=door
  elif belongs==2:edges.append(door)
 for opening:Dictionary in layout.openings:
  if rooms.has(str(opening.connects[0])) and rooms.has(str(opening.connects[1])):edges.append(opening)
 if not _require(not entry.is_empty(),"one authored public entry: "+unit_id):return
 entry_id=str(entry.id)
 var inside:=str(entry.connects[0]) if rooms.has(str(entry.connects[0])) else str(entry.connects[1])
 var outside:=str(entry.connects[1]) if inside==str(entry.connects[0]) else str(entry.connects[0])
 for room:Dictionary in layout.spaces:
  if str(room.id)==outside:public_room=room
 capsule=CapsuleShape3D.new();capsule.radius=PlayerController.BODY_RADIUS;capsule.height=PlayerController.STANDING_HEIGHT
 var public_bounds:=Rect2(Vector2(float(entry.center[0]),float(entry.center[1]))-Vector2.ONE*2.2,Vector2.ONE*4.4)
 for candidate:Dictionary in layout.spaces:
  if candidate.level!="F0"+unit_id[0] or candidate.get("class","") not in ["public","service","core"]:continue
  var r:Array=candidate.rect
  var clipped:=Rect2(Vector2(r[0],r[1]),Vector2(float(r[2])-float(r[0]),float(r[3])-float(r[1]))).intersection(public_bounds)
  if clipped.has_area():public_regions.append({"rect":[clipped.position.x,clipped.position.y,clipped.end.x,clipped.end.y]})
 var start:=_approach(entry,public_room)
 var entry_at:=Vector3(float(entry.center[0]),floor_y,float(entry.center[1]))
 start=entry_at+(start-entry_at).normalized()*.60
 player.global_position=world.adapter.root.to_global(start+Vector3.UP*.02);player.velocity=Vector3.ZERO
 await get_tree().physics_frame;await get_tree().physics_frame
 if not _require(_clear(start),"initial standing entry stance is clear: "+unit_id):return
 if not await _open_door(str(entry.id)):return
 if not await _visit(inside):return
 if not await _navigate(start):return
 if not await _close_door(str(entry.id)):return
 _require(visited_rooms.size()==rooms.size(),"all authored rooms reached: "+unit_id)
 _require(not player.noclip and player.collision_mask==1 and player.is_physics_processing(),"ordinary collision retained: "+unit_id)

func _approach(edge:Dictionary,room:Dictionary) -> Vector3:
 var r:Array=room.rect
 var center:=Vector2((float(r[0])+float(r[2]))*.5,(float(r[1])+float(r[3]))*.5)
 var at:=Vector2(edge.center[0],edge.center[1])
 var normal:=Vector2(0,1)
 if edge.has("yaw"):
  if absf(sin(float(edge.yaw)))>.5:normal=Vector2(1,0)
 elif str(edge.axis)=="z":normal=Vector2(1,0)
 var side:=signf((center-at).dot(normal))
 return Vector3(at.x+normal.x*side*.85,floor_y,at.y+normal.y*side*.85)

func _clear(point:Vector3) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1;query.exclude=[player.get_rid()];query.margin=.005
 query.transform=Transform3D(Basis.IDENTITY,world.adapter.root.to_global(point+Vector3.UP*(capsule.height*.5+.025)))
 return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _inside(point:Vector2,room:Dictionary,margin:=0.0) -> bool:
 var r:Array=room.rect
 return point.x>float(r[0])+margin and point.x<float(r[2])-margin and point.y>float(r[1])+margin and point.y<float(r[3])-margin

func _prepare_grid(resolution:float) -> void:
 pitch=resolution
 var key:=str(resolution)+"|"+str(_leaf(entry_id)._body.rotation.y)
 for edge:Dictionary in edges:
  if edge.has("hinge"):key+="|"+str(_leaf(str(edge.id))._body.rotation.y)
 if grid_cache.has(key):
  grid=grid_cache[key].grid;origin=grid_cache[key].origin
  return
 var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
 var sampled_rooms:Array=rooms.values();sampled_rooms.append_array(public_regions)
 for room:Dictionary in sampled_rooms:
  var r:Array=room.rect;minimum=minimum.min(Vector2(r[0],r[1]));maximum=maximum.max(Vector2(r[2],r[3]))
 minimum-=Vector2.ONE;maximum+=Vector2.ONE;origin=minimum
 grid=AStarGrid2D.new();grid.region=Rect2i(Vector2i.ZERO,Vector2i(ceili((maximum.x-minimum.x)/pitch)+1,ceili((maximum.y-minimum.y)/pitch)+1));grid.cell_size=Vector2.ONE*pitch;grid.offset=origin;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
 for x in grid.region.size.x:
  for z in grid.region.size.y:
   var id:=Vector2i(x,z);var at:=origin+Vector2(id)*pitch;var belongs:=false
   for room:Dictionary in public_regions:belongs=belongs or _inside(at,room,-.02)
   for room:Dictionary in rooms.values():belongs=belongs or _inside(at,room,-.02)
   grid.set_point_solid(id,not belongs or not _clear(Vector3(at.x,floor_y,at.y)))
 grid_cache[key]={"grid":grid,"origin":origin}

func _id(point:Vector3) -> Vector2i:
 return Vector2i(roundi((point.x-origin.x)/pitch),roundi((point.z-origin.y)/pitch))

func _navigate(target:Vector3,room:Dictionary={},fine:=false) -> bool:
 _prepare_grid(.05 if fine else .10)
 var here:Vector3=world.adapter.root.to_local(player.global_position);var start:=_id(here)
 if not _require(grid.is_in_boundsv(start),"route starts inside sampled grid"):return false
 var start_solid:=grid.is_point_solid(start)
 grid.set_point_solid(start,false)
 var candidates:Array[Dictionary]=[]
 for x in grid.region.size.x:
  for z in grid.region.size.y:
   var id:=Vector2i(x,z)
   if grid.is_point_solid(id):continue
   var p:=origin+Vector2(id)*pitch
   if not room.is_empty() and not _inside(p,room,.32):continue
   var distance:=p.distance_squared_to(Vector2(target.x,target.z))
   if room.is_empty() and distance>.16:continue
   candidates.append({"id":id,"distance":distance})
 candidates.sort_custom(func(a:Dictionary,b:Dictionary):return float(a.distance)<float(b.distance))
 var path:Array[Vector2i]=[]
 for candidate:Dictionary in candidates:
  path=grid.get_id_path(start,candidate.id)
  if not path.is_empty():break
 grid.set_point_solid(start,start_solid)
 if path.is_empty() and not fine:return await _navigate(target,room,true)
 if path.is_empty():
  var mask:Array[int]=[]
  for z in grid.region.size.y:
   for x in grid.region.size.x:mask.append(int(grid.is_point_solid(Vector2i(x,z))))
  var folder:=OS.get_environment("SHOT_DIR")
  FileAccess.open(folder.path_join(unit_id+"_grid.json"),FileAccess.WRITE).store_string(JSON.stringify({"unit":unit_id,"origin":[origin.x,origin.y],"pitch":pitch,"size":[grid.region.size.x,grid.region.size.y],"mask":mask,"start":[here.x,here.z],"target":[target.x,target.z],"rooms":rooms,"edges":edges}))
  for edge:Dictionary in edges:
   if not edge.has("hinge"):continue
   var door:=_leaf(str(edge.id))
   print("GRID DOOR ",unit_id," ",edge.id," open=",door.open," angle=",door._body.rotation.y)
 if not _require(not path.is_empty(),"standing collision path exists: "+str(target)):return false
 for i in range(1,path.size()):
  if i<path.size()-1 and path[i]-path[i-1]==path[i+1]-path[i]:continue
  var at:=origin+Vector2(path[i])*pitch
  if not await _walk(Vector3(at.x,floor_y,at.y)):return false
 if path.size()==1:
  var at:=origin+Vector2(path[0])*pitch
  if not await _walk(Vector3(at.x,floor_y,at.y)):return false
 return true

func _visit(identity:String) -> bool:
 var room:Dictionary=rooms[identity];var r:Array=room.rect
 if not await _navigate(Vector3((float(r[0])+float(r[2]))*.5,floor_y,(float(r[1])+float(r[3]))*.5),room):return false
 visited_rooms[identity]=true
 if identity.ends_with("_MAIN") or identity.ends_with("_BATH"):
  await _roof_capture(unit_id+"_"+identity,Vector3(float(r[2])-.5,floor_y+1.25,(float(r[1])+float(r[3]))*.5))
 for edge:Dictionary in edges:
  if identity not in edge.connects:continue
  var neighbor:=str(edge.connects[1]) if str(edge.connects[0])==identity else str(edge.connects[0])
  if visited_rooms.has(neighbor):continue
  if not await _navigate(_approach(edge,room),room):return false
  if edge.has("hinge"):
   var door:=_leaf(str(edge.id))
   if door.open and not await _close_door(str(edge.id)):return false
   if not await _open_door(str(edge.id)):return false
  if not await _visit(neighbor):return false
  if not await _navigate(_approach(edge,room),room):return false
 return true


# Precise corner arrival keeps the controller on the sampled standing path.
func _walk(local_target: Vector3) -> bool:
 var target: Vector3 = world.adapter.root.to_global(local_target)
 var started := Time.get_ticks_msec()
 var travel_budget_ms := maxi(6000, int(player.global_position.distance_to(target) / player.WALK * 1000.0) + 2000)
 var contacts := {}
 while Time.get_ticks_msec() - started < travel_budget_ms:
  var delta := target - player.global_position
  delta.y = 0
  if delta.length() < 0.025: break
  player.rotation.y = atan2(-delta.x, -delta.z)
  player.camera.rotation = Vector3.ZERO
  Input.action_press("move_forward", clampf(delta.length() / 0.35,.25,1.0))
  await get_tree().physics_frame
  for index in player.get_slide_collision_count():
   var contact := player.get_slide_collision(index)
   var collider := contact.get_collider() as Node
   if collider != null and absf(contact.get_normal().y) < .7:
    contacts[str(collider.get_path())] = str(contact.get_position())
 Input.action_release("move_forward")
 await get_tree().physics_frame
 var actual: Vector3 = world.adapter.root.to_local(player.global_position)
 var ok := Vector2(actual.x - local_target.x, actual.z - local_target.z).length() < 0.18 \
   and absf(actual.y - local_target.y) < 0.15 and not player.noclip \
   and player.collision_mask == 1 and player.is_physics_processing()
 trace.append({"target": [local_target.x, local_target.y, local_target.z],
   "actual": [actual.x, actual.y, actual.z], "ok": ok, "wall_contacts": contacts})
 if not ok:
  var label := "target %s actual %s" % [local_target, actual]
  failures.append(label)
  push_error(route_label + ": " + label)
  print("ROUTE_COLLISION_DIAGNOSTIC ", JSON.stringify(contacts))
 return ok
