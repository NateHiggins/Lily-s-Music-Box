extends RefCounted
## V2-native topology and bounded physical validation.
## Source rooms/openings/doors own connectivity; actual support/obstacles own
## permission to walk. This contains no attendance, save or case authority.
var graph := AStar3D.new()
var point_info: Dictionary = {}
var room_points: Dictionary = {}
var rooms: Dictionary = {}
var levels: Dictionary = {}
var frame: Node3D
var space: PhysicsDirectSpaceState3D
var planning_exclusions: Array[RID] = []
var edge_jobs: Dictionary = {}
var edge_valid: Dictionary = {}
var errors: Array[String] = []
var capsule := CapsuleShape3D.new()
var next_id := 0
const STEP_CLEARANCE := .25
const STANDING_HEIGHT := 1.72
const RADIUS := .28

func configure(blueprint: Dictionary, owner_frame: Node3D, physics: PhysicsDirectSpaceState3D) -> bool:
 frame = owner_frame; space = physics
 capsule.radius = RADIUS; capsule.height = STANDING_HEIGHT - STEP_CLEARANCE
 for level: Dictionary in blueprint.levels: levels[str(level.id)] = float(level.y)
 for room: Dictionary in blueprint.spaces:
  if room.has("rect") and room.has("level"):
   rooms[str(room.id)] = room; room_points[str(room.id)] = []
 for identity: String in rooms: _room_candidates(identity)
 for portal: Dictionary in blueprint.doors: _portal(portal, true)
 for portal: Dictionary in blueprint.openings: _portal(portal, false)
 # Primary flights use the already authored and played Mina route template,
 # translated by storey only. Refuse an altered stair recipe; never assume a
 # diagonal through the open core is a staircase.
 _primary_stairs(blueprint)
 for identity: String in room_points:
  var points: Array = room_points[identity]
  for i in points.size():
   for j in range(i + 1, points.size()):
    if not graph.are_points_connected(points[i], points[j]): graph.connect_points(points[i], points[j])
 return errors.is_empty()

func _add(label: String, local: Vector3, room: String = "", door: String = "") -> int:
 var identity := next_id; next_id += 1
 graph.add_point(identity, frame.to_global(local))
 point_info[identity] = {"label": label, "room": room, "door": door}
 if not room.is_empty(): room_points[room].append(identity)
 return identity

func _inside(identity: String, point: Vector2) -> bool:
 if not rooms.has(identity): return false
 var rect: Array = rooms[identity].rect
 return point.x >= float(rect[0]) - .001 and point.x <= float(rect[2]) + .001 \
   and point.y >= float(rect[1]) - .001 and point.y <= float(rect[3]) + .001

func _room_candidates(identity: String) -> void:
 var room: Dictionary = rooms[identity]; var rect: Array = room.rect
 var width := float(rect[2]) - float(rect[0]); var depth := float(rect[3]) - float(rect[1])
 if width < RADIUS * 2 or depth < RADIUS * 2: return
 var inset_x := minf(.42, width * .5); var inset_z := minf(.42, depth * .5)
 var xs := [float(rect[0]) + inset_x, (float(rect[0]) + float(rect[2])) * .5, float(rect[2]) - inset_x]
 var zs := [float(rect[1]) + inset_z, (float(rect[1]) + float(rect[3])) * .5, float(rect[3]) - inset_z]
 for x: float in xs:
  for z: float in zs: _add(identity + ":candidate", Vector3(x, levels[str(room.level)], z), identity)

func _portal(record: Dictionary, movable: bool) -> void:
 var adjacent: Array = record.get("connects", [])
 if adjacent.size() != 2 or not rooms.has(str(adjacent[0])) or not rooms.has(str(adjacent[1])): return
 if float(record.height) < STANDING_HEIGHT or float(record.width) < RADIUS * 2: return
 var at := Vector2(record.center[0], record.center[1])
 var normal := Vector2(sin(float(record.yaw)), cos(float(record.yaw))) if movable else (Vector2(0, 1) if str(record.axis) == "x" else Vector2(1, 0))
 var first := at + normal * .55; var second := at - normal * .55
 if not _inside(str(adjacent[0]), first):
  var swap := first; first = second; second = swap
 if not _inside(str(adjacent[0]), first) or not _inside(str(adjacent[1]), second):
  errors.append("portal approach does not match source rooms: " + str(record.id)); return
 var height: float = levels[str(record.level)]
 var door := str(record.id) if movable else ""
 var a := _add(str(record.id) + ":a", Vector3(first.x, height, first.y), str(adjacent[0]))
 var middle := _add(str(record.id), Vector3(at.x, height, at.y), "", door)
 var b := _add(str(record.id) + ":b", Vector3(second.x, height, second.y), str(adjacent[1]))
 graph.connect_points(a, middle); graph.connect_points(middle, b)

func _primary_stairs(blueprint: Dictionary) -> void:
 var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/mina_routine.json"))
 var template := {}
 for path: Array in source.paths:
  for record: Array in path: template[str(record[0])] = Vector3(record[1], record[2], record[3])
 var names := ["stair_bottom", "half_west", "half_east", "stair_top", "stair_top_clear"]
 for stairs: Dictionary in blueprint.stairs:
  if not str(stairs.id).begins_with("PRIMARY_"): continue
  if stairs.origin != [1.4, -3.1] or absf(float(stairs.width) - 1.05) > .00001 or absf(float(stairs.gap) - 1.0) > .00001 \
    or absf(float(stairs.rise) - .16) > .00001 or int(stairs.risers_per_flight) != 10:
   errors.append("primary flight changed; authored route needs review: " + str(stairs.id)); continue
  var lower := str(stairs.from) + "_PUBLIC_CORE"; var upper := str(stairs.to) + "_PUBLIC_CORE"
  if not rooms.has(lower) or not rooms.has(upper):
   errors.append("primary flight endpoint room needs explicit mapping: " + str(stairs.id)); continue
  var previous := -1
  for i in names.size():
   var local: Vector3 = template[names[i]] + Vector3.UP * float(levels[str(stairs.from)])
   var room := lower if i == 0 else upper if i == names.size() - 1 else ""
   var point := _add(str(stairs.id) + ":" + str(names[i]), local, room)
   if previous >= 0: graph.connect_points(previous, point)
   previous = point

func support(point: Vector3) -> Dictionary:
 var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * .34, point - Vector3.UP * .45, 1, planning_exclusions)
 var hit := space.intersect_ray(query)
 if hit.is_empty() or hit.normal.y < .45 or absf(float(hit.position.y) - point.y) > .30: return {}
 var shape := PhysicsShapeQueryParameters3D.new(); shape.shape = capsule; shape.collision_mask = 1; shape.exclude = planning_exclusions; shape.margin = 0
 shape.transform.origin = hit.position + Vector3.UP * (STEP_CLEARANCE + capsule.height * .5)
 if not space.intersect_shape(shape, 1).is_empty(): return {}
 return hit

func choose_stance(room: String, preferred: Vector3) -> int:
 if not room_points.has(room): return -1
 var points: Array = room_points[room].duplicate()
 points.sort_custom(func(a, b): return graph.get_point_position(a).distance_squared_to(preferred) < graph.get_point_position(b).distance_squared_to(preferred))
 for point: int in points:
  if not support(graph.get_point_position(point)).is_empty(): return point
 return -1

func _edge_key(a: int, b: int) -> String: return "%d:%d" % [mini(a,b), maxi(a,b)]

func validate_edge(a: int, b: int) -> int:
 # One bounded support/capsule sample per call. The director budgets calls
 # across actors; no all-world physics survey and no full scan per frame.
 var key := _edge_key(a, b)
 if edge_valid.has(key): return 1
 if not edge_jobs.has(key):
  var start := graph.get_point_position(a); var finish := graph.get_point_position(b)
  edge_jobs[key] = {"from": start, "to": finish, "cursor": 0,
   "steps": maxi(1, ceili(start.distance_to(finish) / .25)), "last_floor": INF}
 var job: Dictionary = edge_jobs[key]
 var point: Vector3 = job.from.lerp(job.to, float(job.cursor) / float(job.steps))
 var hit := support(point)
 if hit.is_empty() or (is_finite(float(job.last_floor)) and absf(float(hit.position.y) - float(job.last_floor)) > .25):
  graph.disconnect_points(a, b); edge_jobs.erase(key); return -1
 job.last_floor = float(hit.position.y); job.cursor += 1
 if int(job.cursor) > int(job.steps):
  edge_valid[key] = true; edge_jobs.erase(key); return 1
 return 0

func path(from: int, to: int, may_use_door: Callable) -> PackedInt64Array:
 var disabled: Array[int] = []
 for identity: int in point_info:
  var door := str(point_info[identity].door)
  if not door.is_empty() and not bool(may_use_door.call(door)) and not graph.is_point_disabled(identity):
   graph.set_point_disabled(identity, true); disabled.append(identity)
 var result := graph.get_id_path(from, to)
 for identity in disabled: graph.set_point_disabled(identity, false)
 return result

func add_world_point(label: String, world_position: Vector3, room: String = "", door: String = "") -> int:
 return _add(label, frame.to_local(world_position), room, door)

func connect_room_point(label: String, position: Vector3, room: String, door: String = "") -> int:
 if not room_points.has(room): room_points[room] = []
 var previous: Array = room_points[room].duplicate()
 var point := add_world_point(label, position, room, door)
 for other: int in previous: graph.connect_points(point, other)
 return point

func mount_bar(region: OrisonV2BarRegion) -> bool:
 if region.startup_failed or region.resident_places == null: return false
 var furniture := {}
 for floor: Dictionary in region.source_layout.floors:
  if floor.id == "F01":
   for row: Dictionary in floor.furniture: furniture[str(row.id)] = row
 var previous := -1
 var top: DoorProp = region.doors.get("F01_BAR_DOOR")
 var lower: DoorProp = region.doors.get("F01_BAR_RED_DOOR")
 if top == null or lower == null: return false
 var apron := choose_stance("F01_STREET_APRON", top.global_position)
 if apron < 0: return false
 # The actual street surface is checked sample by sample. No V1 corridor
 # coordinates or hidden venue transfer is used for this basement entrance.
 var hinge_middle := top.to_global(Vector3(top.width * .5, 0, 0))
 var street := add_world_point("bar_street", hinge_middle + Vector3(0,0,-.8))
 graph.connect_points(apron,street)
 previous = add_world_point("bar_entry", hinge_middle, "", "F01_BAR_DOOR")
 graph.connect_points(street,previous)
 for i in 15:
  var key := "retail_bar_tread%d" % i
  if not furniture.has(key): return false
  var tread: Dictionary = furniture[key]; var rect: Array = tread.rect
  var local := GameBoot.b2g([(rect[0]+rect[2])*.5,(rect[1]+rect[3])*.5,float(tread.z0)+float(tread.h)])
  var point := add_world_point(key,region.to_global(local))
  graph.connect_points(previous,point); previous = point
 var foot := lower.to_global(Vector3(lower.width*.5,0,.8))
 var at_foot := add_world_point("bar_foot",foot)
 graph.connect_points(previous,at_foot)
 var threshold := add_world_point("bar_red_threshold",lower.to_global(Vector3(lower.width*.5,0,0)),"","F01_BAR_RED_DOOR")
 graph.connect_points(at_foot,threshold)
 room_points["BAR"] = []
 var inside := connect_room_point("bar_inside",lower.to_global(Vector3(lower.width*.5,0,-.8)),"BAR")
 graph.connect_points(threshold,inside)
 # Candidate grid is semantic only. A bounded support/capsule survey prunes
 # blocked edges before any visible person is permitted to walk them.
 if not furniture.has("retail_bar_floor"): return false
 var floor_source: Dictionary = furniture["retail_bar_floor"]
 var bounds: Array = floor_source.rect
 var floor_y := float(floor_source.z0) + float(floor_source.h)
 for x in range(ceili(float(bounds[0])+RADIUS),floori(float(bounds[2])-RADIUS)+1):
  for source_y in range(ceili(float(bounds[1])+RADIUS),floori(float(bounds[3])-RADIUS)+1):
   connect_room_point("bar_candidate",region.to_global(GameBoot.b2g([x,source_y,floor_y])),"BAR")
 for identity: String in region.resident_places.places:
  var place: Dictionary = region.resident_places.preferred(identity)
  connect_room_point("bar_preferred_"+identity,region.resident_places.to_global(place.approach),"BAR")
 return true
