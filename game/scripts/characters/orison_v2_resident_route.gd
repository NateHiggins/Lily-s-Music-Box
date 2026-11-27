extends Node3D
const StandingOccupancy := preload("res://scripts/characters/standing_occupancy.gd")
## A resident's walking body in V2 (design/ORISON_RESIDENT_BODIES_2026-10-25.md).
## The resident's agenda (timetable bent by motives) selects destinations; this
## owner walks the installed collision world between the authored route nodes
## in the resident's route file. Initial placement reconstructs from campaign
## time; live changes never warp. Destinations the route does not reach are
## walked to the file's `away` node and the body leaves unseen, as for "out".
## Mina's route file; her own owner (orison_v2_mina_routine.gd) mounts it.
const MINA_ROUTE := "res://data/orison_v2/mina_routine.json"
## Residents besides Mina who walk in V2: resident id -> route file.
const ROUTES := {"lena_ortiz": "res://data/orison_v2/lena_routine.json",
		"sacha_reed": "res://data/orison_v2/sacha_reed_routine.json",
		"evelyn_marsh": "res://data/orison_v2/evelyn_marsh_routine.json",
		"juno_kells": "res://data/orison_v2/juno_kells_routine.json",
		"nadia_quell": "res://data/orison_v2/nadia_quell_routine.json",
		"cal_dwyer": "res://data/orison_v2/cal_dwyer_routine.json",
		"cam_ortiz": "res://data/orison_v2/cam_ortiz_routine.json",
		"iris_bell": "res://data/orison_v2/iris_bell_routine.json",
		"jonah_price": "res://data/orison_v2/jonah_price_routine.json",
		"mae_kessler": "res://data/orison_v2/mae_kessler_routine.json",
		"malcolm_reed": "res://data/orison_v2/malcolm_reed_routine.json",
		"noel_price": "res://data/orison_v2/noel_price_routine.json",
		"omar_bell": "res://data/orison_v2/omar_bell_routine.json",
		"peter_wren": "res://data/orison_v2/peter_wren_routine.json",
		"rhea_sato": "res://data/orison_v2/rhea_sato_routine.json",
		"transient_guests": "res://data/orison_v2/transient_guests_routine.json",
		"teresa_vale": "res://data/orison_v2/teresa_vale_routine.json"}
var squeeze := preload("res://scripts/characters/character_squeeze_past.gd").new()
var source_path := ""
var resident := ""
## Route tests walk a fixed tour; empty follows the resident's agenda.
var force_destination := ""
var away := ""
var actor: AnimatedResident
var world: Node3D
var graph := AStar3D.new()
var identities: Dictionary = {}
var places: Dictionary = {}
var current_id := -1
var desired_id := -1
var planned_id := -1
var path := PackedInt64Array()
var blocked_seconds := 0.0
var blocked_reason := ""
var last_floor := ""
var travelled_metres := 0.0
var destination := ""
## What the resident is doing there, from the same schedule block (the wardrobe rules read it).
var activity := ""
var bodega_shelf_stop := false
var outside := false
var _sample := 0.0
var _capsule := CapsuleShape3D.new()
var _doors: Array[DoorProp] = []
var _door_passages: Dictionary = {}
var route_speed := 1.05
var _bar_route
var _bodega_route

static func valid_route_header(source: Variant, expected: String) -> bool:
	if source is not Dictionary:
		return false
	var version: Variant = source.get("schema_version")
	# Each route file has one owner and one frame. Another resident or frame
	# must not silently reuse a file's timetable and adapter coordinates.
	return typeof(version) in [TYPE_INT, TYPE_FLOAT] and float(version) == 1.0 \
			and source.get("resident") == expected \
			and source.get("frame") == "orison_v2_blockout" \
			and source.get("name") is String and source.get("unit") is String \
			and source.get("doors") is Array \
			and source.get("paths") is Array and source.get("places") is Dictionary

func setup(root: Node3D) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not valid_route_header(source, resident): return false
	world = root
	places = source.places
	away = str(source.get("away", ""))
	for route: Array in source.paths:
		var previous := -1
		for record: Array in route:
			var point: Vector3 = world.adapter.root.to_global(Vector3(record[1],record[2],record[3]))
			var index := _point(str(record[0]),point)
			if previous >= 0 and not graph.are_points_connected(previous,index): graph.connect_points(previous,index)
			previous = index
	var mail: Node3D = world.adapter.resolve("LobbyMailBank")
	var mail_point: Vector3 = mail.global_position - mail.global_basis.z * .9
	# The weekday mail-bank overlap has two readers and a player approach
	# between them. Both residents still walk their own graph to the bank.
	if resident == "evelyn_marsh" or resident == "peter_wren":
		var side := -1.0 if resident == "evelyn_marsh" else 1.0
		mail_point += mail.global_basis.x.slide(Vector3.UP).normalized() * (side * 0.70)
		# Peter reads over Evelyn's shoulder, one step back from the boxes.
		if resident == "peter_wren":
			mail_point -= mail.global_basis.z.slide(Vector3.UP).normalized() * 0.65
	mail_point.y = world.adapter.root.to_global(Vector3.ZERO).y
	graph.connect_points(identities.mail_approach,_point("mail",mail_point))
	var previous: int = identities.street
	var outbound: Dictionary = world.exterior_cell.route("ROUTE_ORISON_TO_SHOP_BODEGA")
	for i in outbound.nodes.size():
		# The route starts on the door apron, where a body touches the closed leaf.
		# The street point already stands clear of it.
		var leaf := world.find_child("F01_DOOR_06_Leaf",true,false) as Node3D
		if i == 0 and leaf != null and absf(leaf.to_local(outbound.nodes[i].placement.position).z) < .5: continue
		var index := _point("bodega_route_%d"%i,outbound.nodes[i].placement.position)
		graph.connect_points(previous,index)
		previous = index
	var service: Dictionary = world.exterior_cell.spatial_resolver.resolve_placement("SHOP_BODEGA","service_stance")
	graph.connect_points(previous,_point("bodega",service.position))
	_doors.assign([world.exterior_cell.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF"),
			world.find_child("B1_LAUNDRY_DOOR_Leaf",true,false)])
	var mail_door := world.find_child("F01_WATCH_MAIL_DOOR_Leaf",true,false) as DoorProp
	if mail_door == null: return false
	_doors.append(mail_door)
	# The one street door since the entrance was rebuilt (PR 26); a resident
	# carries the house key for it like everyone else.
	var front_door := world.find_child("F01_DOOR_06_Leaf",true,false) as DoorProp
	if front_door != null: _doors.append(front_door)
	# The flat's own doors, each belonging to the resident's unit.
	for identity: String in source.doors:
		var door := world.find_child(identity + "_Leaf", true, false) as DoorProp
		if door == null or door.unit != str(source.unit): return false
		_doors.append(door)
	# Roof access is a public connection. Apartment doors above still
	# require the route owner to match the private unit.
	if places.has("roof"):
		var opening: Node = world.adapter.resolve("ROOF_PUBLIC_DOOR")
		if opening == null: return false
		var roof_door := opening.get_node_or_null(str(opening.name) + "_Leaf") as DoorProp
		if roof_door == null: return false
		_doors.append(roof_door)
	_bar_route = preload("res://scripts/characters/orison_v2_bar_route.gd").new()
	if not _bar_route.attach(self): return false
	_bodega_route = preload("res://scripts/characters/orison_v2_bodega_route.gd").new()
	if not _bodega_route.attach(self): return false
	if resident == "nadia_quell" and not _attach_photo_window(): return false
	_capsule.radius = .28
	_capsule.height = 1.40 # 25 cm step clearance, 1.65 m total standing height.
	# The agenda may bend the timetable, but only to places the route reaches.
	if world.get("resident_agenda") != null: world.resident_agenda.restrict(resident,places.keys())
	_select_destination()
	if desired_id < 0: return false
	current_id = desired_id
	# The V2 presentation adapter: the resident's own rig, moves and atlas.
	actor = preload("res://scripts/characters/orison_v2_resident_presentation.gd").new()
	actor.setup(str(source.name),resident,str(source.unit),CastBodies.model_for(resident))
	actor.externally_driven = true
	actor.face_interacting_player = true
	add_child(actor)
	actor.global_position = graph.get_point_position(current_id)
	if not _bodega_route.bind_actor(): return false
	var initial: Dictionary = _bodega_route.initial_placement()
	if bool(initial.get("handled", false)):
		if not bool(initial.get("ok", false)):
			actor.free(); actor = null
			return false
		current_id = int(initial.point_id)
		actor.global_position = initial.feet
		if not _bodega_route.initial_arrived(): return false
	elif not _place_initial_body():
		actor.free(); actor = null
		return false
	if not _bar_route.bind_actor(): return false
	if _leaves_unseen(): _set_outside(true)
	return actor._model != null

## Nadia works at her window from the public arcade aisle. Reuse the
## street and throat programme so her body actually walks to the display.
func _attach_photo_window() -> bool:
	var programme: Dictionary = world.public_regions.route("ROUTE_STREET_TO_ARCADE")
	var previous: int = identities.street
	for row: Dictionary in programme.get("nodes", []):
		# The resident's street node already clears the building leaf.
		if str(row.id) == "STREET_ORISON_01__orison_exit":
			continue
		var point := world.to_global(row.placement.position)
		var index := _point(str(row.id), point)
		graph.connect_points(previous, index)
		previous = index
		if str(row.id) != "ARCADE_HALL_01__arrival":
			continue
		var photo := preload("res://scripts/building/orison_v2_photo_supplies.gd")
		var window := photo.window_pose(world.passage_region)
		var along := window.basis.x.slide(Vector3.UP).normalized()
		var front := window.basis.z.slide(Vector3.UP).normalized()
		var stance := window.origin + front * 1.55 + along * .75
		stance.y = point.y
		var aisle := point + along * (stance - point).dot(along)
		var approach := _point("photo_window_aisle", aisle)
		graph.connect_points(previous, approach)
		graph.connect_points(approach, _point("photo_window", stance))
		places["photo_supplies"] = "photo_window"
		_attach_photo_prints(approach, point)
		return true
	return false

## Friday 19 July, the prints branch (WR-05, AdelaDatedEncounters): one vertex just inside Photo Supplies,
## reached through the middle of the shop's own storefront leaf (its local x runs hinge 0 to width) from the
## aisle. The place stays "photo_supplies"; only a visit whose itinerary holds "photo:prints" ends at this
## vertex, as the bodega's shelf stop does. Ordinary window work keeps the window mark.
func _attach_photo_prints(aisle: int, arcade_point: Vector3) -> void:
	var leaf := world.passage_region.doors.get("SITE_SHOP_DOOR_PHOTO_SUPPLIES") as DoorProp
	if leaf == null:
		return
	var outward := signf(leaf.to_local(arcade_point).z)
	var middle := leaf.width * .5
	var door_out := _point("photo_shop_door_out", leaf.to_global(Vector3(middle, 0.0, outward * 1.55)))
	graph.connect_points(aisle, door_out)
	var door_in := _point("photo_shop_door_in", leaf.to_global(Vector3(middle, 0.0, -outward * 1.35)))
	graph.connect_points(door_out, door_in)
	graph.connect_points(door_in, _point("photo_prints", leaf.to_global(Vector3(middle, 0.0, -outward * 2.6))))
	if leaf not in _doors:
		_doors.append(leaf)

## Reconstruct at the selected endpoint unless a person already occupies it.
## Fall back only along this resident's existing home-to-goal route. Keep the
## selected destination: the ordinary motor must complete the remaining walk.
## This runs once during setup, never as a live relocation or a queue bypass.
func _place_initial_body() -> bool:
	if _initial_peer_clear(actor.global_position): return true
	var home := int(identities.get(str(places.get("unit", "")), -1))
	if home < 0: return false
	var approach := graph.get_id_path(home, desired_id)
	approach.reverse()
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule; query.collision_mask = 1
	query.exclude = [world.player.get_rid()]
	for point: int in approach:
		if point == desired_id: continue
		var at := graph.get_point_position(point)
		if not _initial_peer_clear(at): continue
		# A closed-state clear point can still obstruct the door's next swing.
		var in_sweep := false
		for door: DoorProp in _doors:
			if not is_instance_valid(door): continue
			if not door.standing_position_clear(at, _capsule.radius, .25 + _capsule.height):
				in_sweep = true; break
		if in_sweep: continue
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			at + Vector3.UP * .34, at - Vector3.UP * .5, 1))
		if floor_hit.is_empty() or floor_hit.normal.y < .45 \
				or absf(floor_hit.position.y - at.y) > .25: continue
		# Resolver stations include a small authored normal offset. Resolve feet
		# once at reconstruction; subsequent support belongs to the motor.
		at.y = floor_hit.position.y
		query.transform.origin = at + Vector3.UP * (.25 + _capsule.height * .5)
		if not space.intersect_shape(query, 1).is_empty(): continue
		current_id = point; actor.global_position = at
		return true
	return false

## Placement needs absolute clearance; the motor's move-apart allowance is
## deliberately inappropriate for a reconstructed or returning standing body.
func _initial_peer_clear(at: Vector3) -> bool:
	# A queued visible actor still occupies its endpoint until it leaves the
	# tree. Visit/capacity lists may retire it earlier; placement cannot.
	var people: Array = get_tree().get_nodes_in_group("animated_residents")
	if is_instance_valid(world.player): people.append(world.player)
	for body: Node3D in people:
		if body == actor or not body.is_visible_in_tree(): continue
		var column := StandingOccupancy.read(body)
		if column.get("invalid", false): return false
		var base: Vector3 = body.global_position if column.is_empty() else column.base
		if column.is_empty():
			if absf(base.y - at.y) > 1.6: continue
		elif at.y >= base.y + float(column.height) or at.y + 1.65 <= base.y: continue
		var separation := .65 if body is PlayerController else .60
		if not column.is_empty(): separation = maxf(separation, .28 + float(column.radius) + .04)
		if Vector2(at.x - base.x, at.z - base.z).length() < separation:
			return false
	return true

## The body has gone where the route cannot follow: off the map, or away.
func _leaves_unseen() -> bool:
	return destination == "out" or (away != "" and _node_for(destination) == away)

func _point(identity: String, point: Vector3) -> int:
	if identities.has(identity): return int(identities[identity])
	var index := graph.get_point_count()
	identities[identity] = index
	graph.add_point(index,point)
	return index

func _select_destination() -> void:
	var info: Dictionary = world.campaign_clock.day_info()
	if not info.get("valid",false): return
	if force_destination != "":
		destination = force_destination
		bodega_shelf_stop = false
		desired_id = int(identities.get(_node_for(destination),-1))
		route_speed = _speed()
		return
	var block: Dictionary = world.resident_whereabouts(resident) if world.has_method("resident_whereabouts") else {}
	if block.is_empty():
		block = world.resident_presence.resolve(resident,str(info.day),
				world.campaign_clock.minute_of_day(),int(info.doy),bool(info.first_sat))
	destination = str(block.get("place","unit"))
	activity = str(block.get("activity",""))
	var itinerary: Variant = block.get("route", [])
	bodega_shelf_stop = destination == "bodega" and itinerary is Array and itinerary.has("bodega:shelf")
	desired_id = int(identities.get(_node_for(destination),-1))
	if destination == "photo_supplies" and itinerary is Array and itinerary.has("photo:prints") and identities.has("photo_prints"):
		desired_id = int(identities.photo_prints)
	route_speed = _speed()

## The route node for a destination: the place itself, the flat for any room
## the route has no node for, else the away node (or none).
func _node_for(place: String) -> String:
	if places.has(place): return str(places[place])
	if place.begins_with("unit") and places.has("unit"): return str(places.unit)
	return away

## Walking pace for the current destination; residents may hurry.
func _speed() -> float:
	return 1.05

## Climbing pace on a stair edge, metres a second along the floor plan. A person on the house's stairs
## (rise 0.16, tread 0.285) takes under two treads a second; at the level pace the stair clip would have to
## play three times over to keep its feet on the treads (NPC repair pilot, order w3473eaaf58a9).
const STAIR_PACE := 0.55
const STAIR_SLOPE := .08

## The pace for the edge from `from` to `target`: the stair pace where it climbs or descends. A cap on the step,
## like the squeeze's; the member route_speed stays the base pace that traffic and the receipts read.
func _pace_on(from: Vector3, target: Vector3) -> float:
	var edge := target - from
	var stair := absf(edge.y) > STAIR_SLOPE * maxf(Vector2(edge.x, edge.z).length(), .01)
	return minf(_speed(), STAIR_PACE) if stair else _speed()

## A resident far from the player, or on another storey, steps every second physics tick with the two ticks' time
## (frame time, 20 Nov: the route step's floor ray and clearance query, run every tick for every resident and
## multiplied by physics catch-up, were the largest physics cost). Near the player every tick still steps.
const FAR_STEP_TICKS := 2
const FAR_STEP_METRES := 14.0
var _far_delta := 0.0
var _far_ticks := 0

func _far_from_player() -> bool:
	var player: Node3D = world.get("player")
	if player == null or actor == null:
		return false
	var offset := actor.global_position - player.global_position
	return absf(offset.y) > 2.4 or Vector2(offset.x, offset.z).length() > FAR_STEP_METRES

## A parked resident skips its route tick until the 0.5 s re-selection is due (Lily 2026-11-24, 30 fps target:
## ~18 idle residents cost ~1.5 ms a physics tick). Parked means the last full tick ended at the ordinary
## "standing at the destination" return, or hidden off-map at it, and nothing that tick read has moved since:
## same destination, no path, at the desired vertex, no held door, no managed grocery leg, not talking.
## Any external change (a retarget, a path, a reset `_sample`) runs the full tick at once. Mina is never parked:
## her animation owner resumes her idle from the per-tick `_set_walking(false)`.
var _parked := false
var _parked_outside := false
var _parked_destination := ""

func _parked_idle() -> bool:
	return _parked and actor.mina_animation == null and outside == _parked_outside \
			and destination == _parked_destination and path.is_empty() and current_id == desired_id \
			and _door_passages.is_empty() and (_bodega_route == null or not _bodega_route.manages_path()) \
			and not _talking()

func _park() -> void:
	_parked = true
	_parked_outside = outside
	_parked_destination = destination

func _physics_process(delta: float) -> void:
	if actor == null or not is_instance_valid(world): return
	if _parked_idle():
		# The skipped ticks spend only the re-selection timer, so the sample fires on the same tick as before
		# and a new destination starts walking in that tick, with that tick's own step time.
		delta += _far_delta
		_far_delta = 0.0
		_far_ticks = 0
		if _sample - delta > 0.0:
			_sample -= delta
			return
		_route_tick(delta)
		return
	# The courtesy timer requires consecutive contacts before a pass.
	if _far_from_player() and not squeeze.has_recent_contact():
		_far_delta += delta
		_far_ticks += 1
		if _far_ticks < FAR_STEP_TICKS: return
		delta = _far_delta
	_far_delta = 0.0
	_far_ticks = 0
	_route_tick(delta)

func _route_tick(delta: float) -> void:
	_parked = false
	_release_passed_doors()
	if _talking():
		actor._set_walking(false)
		return
	_sample -= delta
	if _sample <= 0:
		_sample = .5
		_select_destination()
		_dress_unseen()
	if desired_id < 0 or _player_lock_holds_route():
		actor._set_walking(false)
		return
	if _bar_route != null and _bar_route.update_place(delta):
		return
	# The off-map weekly walk shares the established exterior abstraction:
	# cross the actual threshold, then remove/reintroduce the body only unseen.
	if _leaves_unseen() and current_id == desired_id and (_bodega_route == null or _bodega_route.release_upstream_for_outside()):
		actor._set_walking(false)
		if not outside and not _observed(): _set_outside(true)
		if outside: _park()
		return
	if outside:
		# The off-map look (up to 12 rays) is taken at most every OUTSIDE_LOOK_SECONDS while the body
		# waits; a seen body simply waits for the next look.
		_outside_look_age += delta
		if _outside_look_age >= OUTSIDE_LOOK_SECONDS:
			_outside_look_age = 0.0
			_outside_seen = _observed()
		if _outside_seen: return
		# Publication is placement, not an ordinary movement step. A hidden
		# return must not appear inside a peer and borrow move-apart courtesy.
		if not _initial_peer_clear(actor.global_position):
			blocked_reason = "waiting for a clear off-map return"
			actor._set_walking(false)
			return
		# A hidden return only happens unseen: publication always rests on a look taken this tick.
		if _outside_look_age > 0.0:
			_outside_look_age = 0.0
			_outside_seen = _observed()
			if _outside_seen: return
		_set_outside(false)
	else:
		_outside_look_age = INF
	if _bodega_route != null and not _bodega_route.guide_path():
		actor._set_walking(false)
		return
	if _bodega_route == null or not _bodega_route.manages_path():
		if path.is_empty() and current_id == desired_id:
			actor._set_walking(false)
			_park()
			return
		if not path.is_empty() and planned_id != desired_id:
			# Keep the next vertex on retarget; never cut a corner mid-edge.
			path.resize(1)
		elif path.is_empty():
			planned_id = desired_id
			path = graph.get_id_path(current_id,desired_id)
			if not path.is_empty(): path.remove_at(0)
	if _bar_route != null and not _bar_route.guide_path():
		actor._set_walking(false)
		return
	if path.is_empty():
		actor._set_walking(false)
		return
	var target := graph.get_point_position(path[0])
	var at := actor.global_position
	var flat := Vector3(target.x-at.x,0,target.z-at.z)
	if flat.length() < .04 and absf(at.y-target.y) < .3:
		current_id = path[0]
		path.remove_at(0)
		if planned_id != desired_id: path.clear()
		return
	if not _route_doors_ready(delta * route_speed):
		actor._set_walking(false)
		return
	if actor.mina_animation != null and actor.mina_animation.route_busy:
		actor._set_walking(false)
		return
	var next := _proposed_step(target, delta)
	if squeeze.active(): next = at + (next-at).limit_length(delta * minf(route_speed, .65))
	# On a stair the step is capped at the climbing pace, as the squeeze caps it; route_speed stays the base pace.
	var pace := _pace_on(graph.get_point_position(current_id), target)
	if pace < route_speed: next = at + (next-at).limit_length(delta * pace)
	var proposed := next - at
	if not next.is_finite() or absf(proposed.y) > .00001 or proposed.length() > delta*route_speed+.00001:
		blocked_reason = "invalid walking velocity proposal"
		_blocked(delta)
		return
	if proposed.length_squared() < .000000001:
		actor._set_walking(false)
		return
	if not _characters_clear(next):
		blocked_reason = "yielding before squeezing past"
		_blocked(delta)
		return
	var traffic: Variant = world.get("public_traffic")
	if is_instance_valid(traffic) and not traffic.clear_step(self, next):
		blocked_reason = "yielding on the public walking surface"
		_blocked(delta)
		return
	if _bar_route != null and not _bar_route.clear_step(next):
		blocked_reason = "waiting for a person in the bar route"
		actor._set_walking(false)
		return
	if _bodega_route != null and not _bodega_route.clear_step(next):
		blocked_reason = "waiting for a person in the grocery route"
		actor._set_walking(false)
		return
	if not _route_step_allowed(next):
		blocked_reason = "yielding to a resident during the visit"
		_blocked(delta)
		return
	if squeeze.active(): next = at + (next-at).limit_length(delta * minf(route_speed, .65))
	var ray := PhysicsRayQueryParameters3D.create(next+Vector3.UP*.34,next-Vector3.UP*.5,1)
	var space := actor.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(ray)
	# Ramp end caps are steeper than their walking face, but only a few
	# centimetres high. Admit a supported step, never a jump or wall climb.
	var rise := absf(float(floor_hit.position.y)-at.y) if not floor_hit.is_empty() else INF
	if floor_hit.is_empty() or (floor_hit.normal.y < .45 and rise > .06) or rise > .25:
		blocked_reason = "floor support missing or too steep at %v; previous=%s; hit=%s" % [next,last_floor,floor_hit]
		_blocked(delta)
		return
	next.y = floor_hit.position.y
	last_floor = str(floor_hit.collider.get_path())
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.collision_mask = 1
	query.transform.origin = next + Vector3.UP*(.25+_capsule.height*.5)
	query.exclude = [world.player.get_rid()]
	var obstacles := space.intersect_shape(query,1)
	if not obstacles.is_empty():
		var obstacle: Node3D = obstacles[0].collider
		var root: Node3D = world.adapter.root
		blocked_reason = "capsule blocked by %s (%s, route %v) at %v, route %v" % [obstacle.get_path(),
				obstacle.get_class(),root.to_local(obstacle.global_position),next,root.to_local(next)]
		_blocked(delta)
		return
	actor.global_position = next
	if squeeze.active() and not world.player.call_locked: squeeze.cue(actor)
	if is_instance_valid(traffic): traffic.note_executed()
	travelled_metres += at.distance_to(next)
	blocked_seconds = 0
	# Use the authored edge slope, rather than a single tread sample, so a
	# flat tread doesn't alternate ordinary and stair clips every frame.
	var edge := target - graph.get_point_position(current_id)
	var walked := next - at
	# The animation is told the speed she actually stepped at (stair pace, squeeze or traffic slowing included),
	# so a distance-matched clip keeps its planted foot on the floor.
	actor.set_route_motion(true, edge.y / maxf(Vector2(edge.x, edge.z).length(), .01),
			Vector2(walked.x, walked.z).length() / delta if delta > 0.0 else route_speed)
	if walked.length_squared() > .00001:
		actor.global_rotation.y = lerp_angle(actor.global_rotation.y,atan2(walked.x,walked.z),minf(1,delta*7))

## A velocity proposal never moves the body or bypasses the motor's owners,
## support/capsule checks or authored waypoint completion.
func _proposed_step(target: Vector3, delta: float) -> Vector3:
	var at := actor.global_position
	var traffic: Variant = world.get("public_traffic")
	if is_instance_valid(traffic): return traffic.propose(self, target, delta)
	return at + Vector3(target.x-at.x,0,target.z-at.z).limit_length(delta*route_speed)

## Only engage an aperture crossed by the remaining authored route. Being
## nearby is not permission to open somebody's bedroom while passing it.
func _route_crosses_door(door: DoorProp) -> bool:
	var previous := door.to_local(actor.global_position)
	var side := signf(previous.z)
	var crossing := Vector3.INF
	for index in path:
		var next := door.to_local(graph.get_point_position(index))
		if absf(next.z) < .001:
			crossing = next
		elif side != 0.0 and next.z * side < 0.0:
			if crossing == Vector3.INF:
				crossing = previous.lerp(next, -previous.z / (next.z - previous.z))
			if crossing.x >= 0.0 and crossing.x <= door.width \
					and absf(crossing.y) < .3:
				return true
			crossing = Vector3.INF
			side = signf(next.z)
		elif absf(next.z) >= .001:
			side = signf(next.z)
			crossing = Vector3.INF
		previous = next
	return false

func _route_doors_ready(step: float) -> bool:
	var ready := true
	for door in _doors:
		if not is_instance_valid(door): continue
		var near := actor.global_position.distance_to(door.global_position) < door.width + .5 + step
		if not near: continue
		if not _door_passages.has(door):
			if not _route_crosses_door(door): continue
			# Stepping away from the door first (out of its sweep, from a sink
			# stance inside it) only applies while the next vertex is on the
			# same side. A farther vertex across the leaf still approaches it.
			var side := signf(door.to_local(actor.global_position).z)
			var next_point := graph.get_point_position(path[0])
			if door.to_local(next_point).z * side > 0.0 and next_point.distance_to(door.global_position) \
					> actor.global_position.distance_to(door.global_position) + .05: continue
			_door_passages[door] = {"side": side, "opened": false, "revision": door.motion_revision, "gesture": false}
		var passage: Dictionary = _door_passages[door]
		# A crossed door is released, not acquired again from the far side.
		if door.to_local(actor.global_position).z * float(passage.side) < -.3: continue
		var key_holder := actor.resident_id if not actor.resident_id.is_empty() else "__unidentified_npc__"
		if door.passage_allowed(key_holder):
			door.hold_passage(actor)
		else:
			door.release_passage(actor)
		if not door.is_ready_for_passage():
			# A restored or interrupted leaf may be open but not wide enough.
			# Complete its real sweep through the same gesture and access owner.
			if not door._moving \
					and _door_motion_clear(door, true):
				if actor.mina_animation == null:
					if door.request_passage(actor, key_holder):
						passage.opened = true
						passage.revision = door.motion_revision
					ready = false
					continue
				if door.leaf_state == "locked" and not DoorKeyring.resident_has_key(actor.resident_id, door):
					ready = false
					continue
				# Approach within reach while the capsule still clears the closed
				# leaf. The gesture cues the owner's real opening at its reach beat.
				var pushing := sin(door.motion_target_angle(true)) * float(passage.side) > 0
				var reach := .85 if pushing else door.passage_swing_radius() + .5
				if absf(door.to_local(actor.global_position).z) > reach: continue
				if not actor.mina_animation.route_busy:
					passage.gesture = actor.mina_animation.route_action("push" if pushing else "pull")
					if passage.gesture: _face_door(door)
				elif bool(passage.gesture) and actor.mina_animation.action_contact_ready():
					if door.request_passage(actor, key_holder):
						passage.opened = true
						passage.revision = door.motion_revision
			blocked_reason = "waiting for door: " + str(door.name)
			ready = false
	return ready

## Finishing a crossing releases route custody only. A door without an actual
## closer stays where it was left until an explicit operation asks it to move.
## Installed closer hardware and the leaf owner retain their own safety checks.
func _release_passed_doors() -> void:
	for key in _door_passages.keys():
		if not is_instance_valid(key):
			_door_passages.erase(key)
			continue
		var door := key as DoorProp
		var passage: Dictionary = _door_passages[door]
		# A later accepted operation supersedes our approach, even if it ends
		# open again. Rejected/locked interactions do not change the revision.
		if int(passage.revision) != door.motion_revision:
			door.release_passage(actor)
			_door_passages.erase(door)
			continue
		var passed := door.to_local(actor.global_position).z * float(passage.side) < -.3
		var abandoned := not _route_crosses_door(door) and actor.global_position.distance_to(door.global_position) > door.width + .5
		if passed or abandoned:
			door.release_passage(actor)
			_door_passages.erase(door)

## In conversation: Mina's own behaviour knows; anyone else is held by the
## dialogue that locks the player.
func _talking() -> bool:
	if actor.mina_animation != null:
		return actor.mina_animation.conversation_active
	return _player_lock_holds_route() and actor.global_position.distance_squared_to(world.player.global_position) < 9.0


func _player_lock_holds_route() -> bool:
	return world.player.call_locked and not ResidentConversations.permits_background_work(actor, world.player)

func _face_door(door: DoorProp) -> void:
	var toward := door.to_global(Vector3(door.width * .75, 0, 0)) - actor.global_position
	if Vector2(toward.x, toward.z).length_squared() < .001: return
	var yaw := actor.global_rotation.y + wrapf(atan2(toward.x, toward.z) - actor.global_rotation.y, -PI, PI)
	actor.create_tween().tween_property(actor, "global_rotation:y", yaw, .3)

## Conservative swept-box clearance for people, including the player. This
## never excludes the leaf from movement queries or modifies its collision.
## DoorProp still owns all locks, tweens, sounds and interaction state.
func _door_motion_clear(door: DoorProp, opening: bool) -> bool:
	return door.motion_clear(opening)

func _blocked(delta: float) -> void:
	blocked_seconds += delta
	actor._set_walking(false)

## The off-map look cadence: a hidden body re-checks whether it is seen at most this often.
const OUTSIDE_LOOK_SECONDS := .25
var _outside_look_age := INF
var _outside_seen := false

func _set_outside(value: bool) -> void:
	outside = value
	# Each hidden spell starts with a fresh look.
	_outside_look_age = INF
	_outside_seen = false
	actor.visible = not value
	var interaction: Area3D = actor.get_node("Interaction")
	interaction.collision_layer = 0 if value else 1

## Places as the wardrobe rules know them: the flat is home, the bar the bar, the building's halls the lobby,
## the roof the roof, and anywhere off the block the street (outdoors).
const WARDROBE_PLACE := {"unit": "home", "harukiya_bar": "bar", "lobby": "lobby", "mail_bank": "lobby",
	"corridor": "lobby", "corridor_pause": "lobby", "stairs": "lobby", "laundry": "lobby", "roof": "roof"}

## A resident on a rebuilt body changes clothes by the wardrobe rules for where it is and what it is doing,
## only while nobody can see it (Lily 2026-11-12, ruling cast_swap_clothes).
func _dress_unseen() -> void:
	if actor == null or actor.cast_body == null or not actor.visible and not outside:
		return
	var stamp: String = world.campaign_clock.datetime_string()
	if stamp.length() < 13:
		return
	var place := destination.get_slice(":", 0)
	var dressing := {"date": stamp.substr(0, 10), "hour": float(stamp.substr(11, 2)) + float(stamp.substr(14, 2)) / 60.0,
		"place": str(WARDROBE_PLACE.get(place, "street")), "activity": "sleep" if activity == "sleeping" else activity}
	# Ask the wardrobe first: the look (up to 12 rays) is only needed when the clothes would change.
	if actor.outfit_change_for(dressing).is_empty():
		return
	if not outside and _observed():
		return
	actor.dress_for(dressing)

func _observed() -> bool:
	var camera: Camera3D = world.player.camera
	var space := actor.get_world_3d().direct_space_state
	for y in [.1,1.0,1.7]:
		for offset in [Vector3(.4,y,.4),Vector3(-.4,y,.4),Vector3(.4,y,-.4),Vector3(-.4,y,-.4)]:
			var target: Vector3 = actor.global_position+offset
			if not camera.is_position_in_frustum(target): continue
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position,target,1)
			ray.exclude = [world.player.get_rid()]
			if space.intersect_ray(ray).is_empty(): return true
	return false

func _exit_tree() -> void:
	# A door can leave the tree before its route, especially on Continue.
	# Check each key before treating it as a DoorProp.
	for door in _door_passages:
		if is_instance_valid(door): door.release_passage(actor)
	_door_passages.clear()
	if _bar_route != null: _bar_route.cancel()


## Optional route-specific courtesy, evaluated at every actual motor step.
func _route_step_allowed(_next: Vector3) -> bool:
	return true

## Called only after route/admission/door owners authorize an ordinary step.
func _characters_clear(next: Vector3) -> bool:
	var people: Array = get_tree().get_nodes_in_group("animated_residents")
	if is_instance_valid(world.player): people.append(world.player)
	var clear := true
	for peer in people:
		if peer == actor or not peer is Node3D or not peer.is_visible_in_tree(): continue
		var column := StandingOccupancy.read(peer)
		if column.get("invalid", false): return false
		var base: Vector3 = peer.global_position if column.is_empty() else column.base
		if column.is_empty():
			if absf(base.y-next.y) > 1.6: continue
		elif next.y >= base.y + float(column.height) or next.y + 1.65 <= base.y: continue
		var separation := .65 if peer == world.player else .60
		if not column.is_empty(): separation = maxf(separation, .28 + float(column.radius) + .04)
		var offset: Vector3 = base-actor.global_position
		offset.y = 0
		var step := next-actor.global_position
		step.y = 0
		if (offset-step).length() < separation and (offset-step).length() <= offset.length()+.00001:
			if world.player.call_locked and (peer == world.player or not ResidentConversations.permits_background_work(peer, world.player)):
				# The locked caller/listeners cannot step aside; keep their space.
				clear = false
			elif _bar_route != null and _bar_route.blocks_capacity_courtesy(peer):
				clear = false
			elif not squeeze.permits(actor, peer): clear = false
	return clear
