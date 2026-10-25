extends Node3D
## The existing campaign timetable owns attendance. This owner presents the
## other seventeen approved residents and walks V2's actual connected world.
## Mina retains her dedicated routine, case and supplied animation owner.
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const Navigation := preload("res://scripts/characters/orison_v2_resident_navigation.gd")
var world: Node3D
var navigation := Navigation.new()
var residents: Dictionary = {}
var doors: Dictionary = {}
var errors: Array[String] = []
var startup_complete := false
var _cursor := 0
var _clock_sample := 0.0
var _capsule := CapsuleShape3D.new()
var _conversation := ""

func setup(owner_world: Node3D) -> bool:
 world = owner_world
 await get_tree().physics_frame
 await get_tree().physics_frame
 _capsule.radius = .28; _capsule.height = 1.47
 _collect_doors(world)
 if not navigation.configure(world.layout,world.adapter.root,get_world_3d().direct_space_state):
  errors.append_array(navigation.errors); return false
 for door: DoorProp in doors.values():
  if is_instance_valid(door._body): navigation.planning_exclusions.append(door._body.get_rid())
 if not navigation.mount_bar(world.bar_region): errors.append("bar entrance graph refused"); return false
 if world.conversations:
  world.conversations.conversation_started.connect(func(identity, _entry): _conversation = identity)
  world.conversations.conversation_ended.connect(func(_identity): _conversation = "")
 for row: Dictionary in Presentation.roster():
  if row.id == "mina_vale": continue
  var home := "F0%s_%s_MAIN" % [str(row.unit)[0], str(row.unit)[1]]
  if not navigation.rooms.has(home): errors.append("home missing: "+str(row.id)); return false
  var center: Array = navigation.rooms[home].rect
  var preferred: Vector3 = world.adapter.root.to_global(Vector3((center[0]+center[2])*.5,navigation.levels[navigation.rooms[home].level],(center[1]+center[3])*.5))
  var candidates: Array = navigation.room_points[home].duplicate()
  candidates.sort_custom(func(a,b): return navigation.graph.get_point_position(a).distance_squared_to(preferred) < navigation.graph.get_point_position(b).distance_squared_to(preferred))
  var start := -1
  for candidate: int in candidates:
   var at := navigation.graph.get_point_position(candidate)
   var occupied := false
   for existing: Dictionary in residents.values():
    if existing.actor.global_position.distance_to(at) < .65: occupied = true; break
   if not occupied and not navigation.support(at).is_empty(): start = candidate; break
  if start < 0: errors.append("no supported home stance: "+str(row.id)); return false
  var actor: AnimatedResident = Presentation.new()
  actor.setup(row.display,row.id,row.unit,row.model); actor.externally_driven = true; actor.face_interacting_player = true
  add_child(actor); actor.global_position = navigation.support(navigation.graph.get_point_position(start)).position
  var state := {"actor":actor,"home":home,"current":start,"desired":start,"path":PackedInt64Array(),
   "place":"unit","block":{},"blocked":"","retry":0.0,"seated":false,"arrived":false,"metres":0.0}
  residents[str(row.id)] = state
  _resolve(str(row.id),state,true)
  # One imported personal hero per rendered loading frame, rather than a
  # single eighteen-scene load burst on entry to the playable world.
  await get_tree().process_frame
 startup_complete = residents.size() == 17
 return startup_complete

func _collect_doors(node: Node) -> void:
 if node is DoorProp: doors[str(node.name).trim_suffix("_Leaf")] = node
 for child in node.get_children(): _collect_doors(child)

func _block(identity: String) -> Dictionary:
 var info: Dictionary = world.campaign_clock.day_info()
 if not info.get("valid",false): return {}
 return world.resident_presence.resolve(identity,str(info.day),world.campaign_clock.minute_of_day(),int(info.doy),bool(info.first_sat))

func _room_for(state: Dictionary, place: String) -> String:
 var home := str(state.home)
 if place.begins_with("unit"):
  var suffix := place.get_slice(":",1)
  var kind: String = {"bedroom":"BED","bathroom":"BATH","kitchen":"KITCHEN"}.get(suffix,"MAIN")
  var candidate := home.trim_suffix("MAIN")+str(kind)
  return candidate if navigation.rooms.has(candidate) else home
 if place.begins_with("visit:"):
  var unit := place.trim_prefix("visit:")
  return "F0%s_%s_MAIN" % [unit[0],unit[1]] if unit.length() == 2 else home
 if place == "harukiya_bar": return "BAR"
 if place in ["out","bodega","luncheonette","hand_laundry","news_cigars","photo_supplies"]: return "F01_STREET_APRON"
 if place in ["lobby","mail_bank"]: return "F01_LOBBY"
 if place == "laundry": return "B1_LAUNDRY"
 if place == "roof": return "ROOF_PUBLIC_CORE"
 return home.get_slice("_",0)+"_PUBLIC_CORE"

func _resolve(identity: String, state: Dictionary, initial := false) -> void:
 var block := _block(identity)
 var place := str(block.get("place","unit"))
 state.block = block
 if place == state.place and not initial: return
 state.place = place; state.arrived = false
 var room := _room_for(state,place)
 if not navigation.room_points.has(room):
  state.blocked = "destination has no installed room: "+place; return
 var preferred: Vector3 = state.actor.global_position
 if room == "BAR":
  var seat: Dictionary = world.bar_region.resident_places.preferred(identity)
  preferred = world.bar_region.resident_places.to_global(seat.approach)
 var point := -1
 if room == "BAR":
  for candidate: int in navigation.room_points[room]:
   if navigation.point_info[candidate].label == "bar_preferred_"+identity:
    if not navigation.support(navigation.graph.get_point_position(candidate)).is_empty(): point = candidate
    break
 else: point = navigation.choose_stance(room,preferred)
 if point < 0: state.blocked = "destination has no supported stance: "+place; return
 state.desired = point; state.blocked = ""; state.retry = 0.0
 if initial:
  # Reconstruct at a supported destination before play; live clock changes
  # below never reposition a visible resident across rooms or buildings.
  state.current = point
  state.actor.global_position = navigation.support(navigation.graph.get_point_position(point)).position
  if place == "out": state.actor.visible = false
  elif place == "harukiya_bar": _settle(identity,state)

func _may_use_door(identity: String, door_id: String) -> bool:
 if not doors.has(door_id): return false
 var door: DoorProp = doors[door_id]
 return door.leaf_state != "locked" or DoorKeyring.resident_has_key(identity,door)

func _physics_process(delta: float) -> void:
 if not startup_complete or not is_instance_valid(world.player): return
 _clock_sample -= delta
 if _clock_sample <= 0:
  _clock_sample = 1.0
  for identity: String in residents: _resolve(identity,residents[identity])
 # At most one path edge sample per actor per frame. Rendering and input
 # never wait for a synchronous all-world navigation survey.
 for identity: String in residents:
  var state: Dictionary = residents[identity]
  if identity == _conversation or world.player.call_locked:
   state.actor._set_walking(false); continue
  _step(identity,state,delta)
  _yield_and_witness(identity,state,delta)

func _step(identity: String, state: Dictionary, delta: float) -> void:
 var actor: AnimatedResident = state.actor
 if not actor.visible:
  if state.place == "out": return
  # Off-map return begins at the same threshold, only while unobserved.
  if _observed(actor): return
  actor.visible = true
 if state.seated:
  if state.place == "harukiya_bar": return
  world.bar_region.resident_places.release(identity,actor)
  state.seated = false; actor._play_named("idle")
  var approach: Vector3 = navigation.graph.get_point_position(int(state.current))
  # Leave the furniture smoothly; no cross-room teleport.
  actor.global_position = actor.global_position.move_toward(approach,delta*1.05)
  if actor.global_position.distance_to(approach) > .04: return
 if int(state.current) == int(state.desired) and state.path.is_empty():
  actor._set_walking(false)
  if not state.arrived: _settle(identity,state)
  return
 state.retry = maxf(0,float(state.retry)-delta)
 if state.path.is_empty():
  if float(state.retry) > 0: return
  state.path = navigation.path(int(state.current),int(state.desired),func(id): return _may_use_door(identity,id))
  if state.path.is_empty(): state.blocked = "no permitted supported route"; state.retry = 5.0; actor._set_walking(false); return
  state.path.remove_at(0)
 if state.path.is_empty(): return
 var next: int = state.path[0]
 # Door collision stays active during live walking. Only planning excludes
 # leaves, so a closed door is a request to its owner, never a wall bypass.
 var door_id := str(navigation.point_info[next].door)
 if door_id.is_empty(): door_id = str(navigation.point_info[int(state.current)].door)
 if not door_id.is_empty() and doors.has(door_id):
  var door: DoorProp = doors[door_id]
  if not door.is_ready_for_passage():
   door.npc_set_open(true,identity); actor._set_walking(false); state.blocked = "waiting for "+door_id; return
 var validation := navigation.validate_edge(int(state.current),next)
 if validation == 0: actor._set_walking(false); return
 if validation < 0: state.path = PackedInt64Array(); state.blocked = "route obstacle pruned"; actor._set_walking(false); return
 var target := navigation.graph.get_point_position(next)
 var flat := target-actor.global_position; flat.y = 0
 if flat.length() < .04 and absf(target.y-actor.global_position.y) < .32:
  state.current = next; state.path.remove_at(0); actor._set_walking(false); return
 var direction := flat.normalized()
 var proposed := actor.global_position+direction*minf(1.05*delta,flat.length())
 var floor := _live_support(proposed)
 if floor.is_empty(): actor._set_walking(false); state.blocked = "live path obstructed"; return
 proposed.y = floor.position.y
 state.metres += actor.global_position.distance_to(proposed)
 actor.global_position = proposed
 actor.rotation.y = lerp_angle(actor.rotation.y,atan2(direction.x,direction.z),minf(1,delta*7))
 actor._set_walking(true); state.blocked = ""

func _settle(identity: String, state: Dictionary) -> void:
 state.arrived = true
 var actor: AnimatedResident = state.actor
 if state.place == "out":
  if not _observed(actor): actor.visible = false
  else: state.arrived = false
 elif state.place == "harukiya_bar":
  if not world.bar_region.resident_places.claim(identity,actor): state.blocked = "preferred place occupied"; state.arrived = false; return
  var place: Dictionary = world.bar_region.resident_places.preferred(identity)
  var marker: Marker3D = place.marker
  actor.global_position = marker.global_position-Vector3.UP*.478
  actor.global_rotation.y = marker.global_rotation.y
  if bool(actor.call("play_seated")): state.seated = true

func _live_support(point: Vector3) -> Dictionary:
 var space := get_world_3d().direct_space_state
 var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.34,point-Vector3.UP*.45,1))
 if hit.is_empty() or hit.normal.y < .45 or absf(hit.position.y-point.y) > .30: return {}
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = _capsule; query.collision_mask = 1; query.margin = 0
 query.transform.origin = hit.position+Vector3.UP*(.25+_capsule.height*.5)
 if not space.intersect_shape(query,1).is_empty(): return {}
 return hit

func _yield_and_witness(identity: String, state: Dictionary, delta: float) -> void:
 var actor: AnimatedResident = state.actor
 if not actor.visible or not world.player.global_position.is_finite(): return
 var away: Vector3 = actor.global_position-world.player.global_position
 if absf(away.y) > 1.2: return
 away.y = 0
 var gap: float = away.length()
 if gap < ResidentRoutines.WITNESS_RADIUS:
  var flag := str(state.block.get("knowledge",""))
  if not flag.is_empty(): RealityState.grant_knowledge(flag)
 if gap >= ResidentRoutines.YIELD_RADIUS or state.seated: return
 var direction: Vector3 = away.normalized() if gap > .001 else actor.global_basis.x
 var at: Vector3 = actor.global_position+direction*minf(ResidentRoutines.YIELD_SPEED*delta,ResidentRoutines.YIELD_RADIUS-gap)
 var floor := _live_support(at)
 if not floor.is_empty(): at.y = floor.position.y; actor.global_position = at

func _observed(actor: AnimatedResident) -> bool:
 return world.player.global_position.distance_to(actor.global_position) < 8.0
