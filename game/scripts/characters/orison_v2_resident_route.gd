extends Node3D
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
		"nadia_quell": "res://data/orison_v2/nadia_quell_routine.json"}
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
var outside := false
var _sample := 0.0
var _capsule := CapsuleShape3D.new()
var _doors: Array[DoorProp] = []
var _door_passages: Dictionary = {}
var _closing_door: DoorProp
var _closing_phase := ""
var _closing_revision := -1
var route_speed := 1.05

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
	mail_point.y = world.adapter.root.to_global(Vector3.ZERO).y
	graph.connect_points(identities.mail_approach,_point("mail",mail_point))
	var previous: int = identities.street
	var outbound: Dictionary = world.exterior_cell.route("ROUTE_ORISON_TO_SHOP_BODEGA")
	for i in outbound.nodes.size():
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
	_capsule.radius = .28
	_capsule.height = 1.40 # 25 cm step clearance, 1.65 m total standing height.
	# The agenda may bend the timetable, but only to places the route reaches.
	if world.get("resident_agenda") != null: world.resident_agenda.restrict(resident,places.keys())
	_select_destination()
	if desired_id < 0: return false
	current_id = desired_id
	# The V2 presentation adapter: the resident's own rig, moves and atlas.
	actor = preload("res://scripts/characters/orison_v2_resident_presentation.gd").new()
	actor.setup(str(source.name),resident,str(source.unit),"res://assets/characters/%s/%s.gltf" % [resident, resident])
	actor.externally_driven = true
	actor.face_interacting_player = true
	add_child(actor)
	actor.global_position = graph.get_point_position(current_id)
	if _leaves_unseen(): _set_outside(true)
	return actor._model != null

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
		desired_id = int(identities.get(_node_for(destination),-1))
		route_speed = _speed()
		return
	var block: Dictionary = world.resident_whereabouts(resident) if world.has_method("resident_whereabouts") else {}
	if block.is_empty():
		block = world.resident_presence.resolve(resident,str(info.day),
				world.campaign_clock.minute_of_day(),int(info.doy),bool(info.first_sat))
	destination = str(block.get("place","unit"))
	desired_id = int(identities.get(_node_for(destination),-1))
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

func _physics_process(delta: float) -> void:
	if actor == null or not is_instance_valid(world): return
	_close_passed_doors()
	if _talking() or is_instance_valid(_closing_door):
		actor._set_walking(false)
		return
	_sample -= delta
	if _sample <= 0:
		_sample = .5
		_select_destination()
	if world.player.call_locked or desired_id < 0:
		actor._set_walking(false)
		return
	# The off-map weekly walk shares the established exterior abstraction:
	# cross the actual threshold, then remove/reintroduce the body only unseen.
	if _leaves_unseen() and current_id == desired_id:
		actor._set_walking(false)
		if not outside and not _observed(): _set_outside(true)
		return
	if outside:
		if _observed(): return
		_set_outside(false)
	if path.is_empty() and current_id == desired_id:
		actor._set_walking(false)
		return
	if path.is_empty() or planned_id != desired_id:
		# Finish the current edge before replanning, avoiding a wall-cutting
		# nearest-node shortcut when a clock jump arrives mid-flight.
		if path.size() <= 1:
			planned_id = desired_id
			path = graph.get_id_path(current_id,desired_id)
			if not path.is_empty(): path.remove_at(0)
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
	var next := at + flat.limit_length(delta*route_speed)
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
		blocked_reason = "capsule blocked by %s at %v" % [obstacles[0].collider.get_path(),next]
		_blocked(delta)
		return
	actor.global_position = next
	travelled_metres += at.distance_to(next)
	blocked_seconds = 0
	# Use the authored edge slope, rather than a single tread sample, so a
	# flat tread doesn't alternate ordinary and stair clips every frame.
	var edge := target - graph.get_point_position(current_id)
	actor.set_route_motion(true, edge.y / maxf(Vector2(edge.x, edge.z).length(), .01), route_speed)
	if flat.length_squared() > .00001:
		actor.global_rotation.y = lerp_angle(actor.global_rotation.y,atan2(flat.x,flat.z),minf(1,delta*7))

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
			# stance inside it): it is not this step's door yet.
			if not path.is_empty() and graph.get_point_position(path[0]).distance_to(door.global_position) \
					> actor.global_position.distance_to(door.global_position) + .05: continue
			_door_passages[door] = {"side": signf(door.to_local(actor.global_position).z), "opened": false, "revision": -1, "gesture": false}
		var passage: Dictionary = _door_passages[door]
		# A crossed door belongs to the close queue, not the next approach.
		if door.to_local(actor.global_position).z * float(passage.side) < -.3: continue
		if not door.is_ready_for_passage():
			if not door.open and not door._moving \
					and _door_motion_clear(door, true):
				if actor.mina_animation == null:
					door.npc_set_open(true,actor.resident_id)
					passage.opened = door.open
					passage.revision = door.motion_revision
					ready = false
					continue
				if door.leaf_state == "locked" and not DoorKeyring.resident_has_key(actor.resident_id, door):
					ready = false
					continue
				# Approach within reach while the capsule still clears the closed
				# leaf. The gesture cues the owner's real opening at its reach beat.
				var pushing := sin(door.motion_target_angle(true)) * float(passage.side) > 0
				var reach := .85 if pushing else door.width + .5
				if absf(door.to_local(actor.global_position).z) > reach: continue
				if not actor.mina_animation.route_busy:
					passage.gesture = actor.mina_animation.route_action("push" if pushing else "pull")
					if passage.gesture: _face_door(door)
				elif bool(passage.gesture) and actor.mina_animation.action_contact_ready():
					door.npc_set_open(true,actor.resident_id)
					passage.opened = door.open
					passage.revision = door.motion_revision
			blocked_reason = "waiting for door: " + str(door.name)
			ready = false
	return ready

func _close_passed_doors() -> void:
	if is_instance_valid(_closing_door):
		if _talking() or _closing_door.motion_revision != _closing_revision:
			actor.mina_animation.cancel_route_action()
			_closing_door = null
			return
		if _closing_phase == "close" and _closing_door.open \
				and actor.mina_animation.action_contact_ready() and _door_motion_clear(_closing_door, false):
			_closing_door.npc_set_open(false,actor.resident_id)
			if not _closing_door.open:
				_closing_revision = _closing_door.motion_revision
				_door_passages.erase(_closing_door)
		if not actor.mina_animation.route_busy:
			if _closing_phase == "close" and not _closing_door.open and _closing_door.leaf_state == "locked":
				actor.mina_animation.route_action("lock")
				_closing_phase = "lock"
			else:
				_closing_door = null
		return
	for door: DoorProp in _door_passages.keys():
		if not is_instance_valid(door):
			_door_passages.erase(door)
			continue
		var passage: Dictionary = _door_passages[door]
		# A later accepted operation supersedes our opening, even if it ends
		# open again. Rejected/locked interactions do not change the revision.
		if bool(passage.opened) and int(passage.revision) != door.motion_revision:
			_door_passages.erase(door)
			continue
		var passed := door.to_local(actor.global_position).z * float(passage.side) < -.3
		var abandoned := not _route_crosses_door(door) and actor.global_position.distance_to(door.global_position) > door.width + .5
		if not passed and not abandoned: continue
		# Leave a previously propped-open door alone. Only finish our own request.
		if not bool(passage.opened):
			_door_passages.erase(door)
		elif not door._moving and _door_motion_clear(door, false):
			if actor.mina_animation == null:
				door.npc_set_open(false,actor.resident_id)
				if not door.open: _door_passages.erase(door)
			elif actor.mina_animation.route_action("close"):
				_closing_door = door
				_closing_phase = "close"
				_closing_revision = door.motion_revision
				_face_door(door)
				return

## In conversation: Mina's own behaviour knows; anyone else is held by the
## dialogue that locks the player.
func _talking() -> bool:
	if actor.mina_animation != null:
		return actor.mina_animation.conversation_active
	return world.player.call_locked and actor.global_position.distance_to(world.player.global_position) < 3.0

func _face_door(door: DoorProp) -> void:
	var toward := door.to_global(Vector3(door.width * .75, 0, 0)) - actor.global_position
	if Vector2(toward.x, toward.z).length_squared() < .001: return
	var yaw := actor.global_rotation.y + wrapf(atan2(toward.x, toward.z) - actor.global_rotation.y, -PI, PI)
	actor.create_tween().tween_property(actor, "global_rotation:y", yaw, .3)

## Conservative swept-box clearance for people, including the player. This
## never excludes the leaf from movement queries or modifies its collision.
## DoorProp still owns all locks, tweens, sounds and interaction state.
func _door_motion_clear(door: DoorProp, opening: bool) -> bool:
	var people: Array[Node] = get_tree().get_nodes_in_group("animated_residents")
	people.append_array(get_tree().get_nodes_in_group("player_controller"))
	var target := door.motion_target_angle(opening)
	var angle := target - door._body.rotation.y
	var steps := maxi(1, ceili(absf(angle) / deg_to_rad(2.0)))
	var margin := .03 + 2.0 * (door.width + .1) * sin(absf(angle) / steps * .25)
	var occupants: Array[Dictionary] = []
	for person in people:
		var body := person as Node3D
		if body == null or not body.visible or body.get_world_3d() != door.get_world_3d(): continue
		var radius := PlayerController.BODY_RADIUS if body is PlayerController else .28
		var body_height := PlayerController.STANDING_HEIGHT if body is PlayerController else 1.55
		var foot := body.global_position
		var relative := door.to_local(foot)
		if relative.y > door.height + margin or relative.y + body_height < -margin: continue
		if Vector2(relative.x, relative.z).length() > door.width + radius + margin + .1: continue
		occupants.append({"foot": foot, "radius": radius, "height": body_height})
	if occupants.is_empty(): return true
	for child in door._body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled: continue
		if not collision.shape is BoxShape3D: return false
		var box := collision.shape as BoxShape3D
		for i in range(steps + 1):
			var pose := door._body.transform
			pose.basis = Basis(Vector3.UP, angle * float(i) / steps) * pose.basis
			var transform := door.global_transform * pose * collision.transform
			var half := box.size * .5
			for occupant in occupants:
				var foot: Vector3 = occupant.foot
				var radius: float = occupant.radius
				var body_height: float = occupant.height
				if foot.y >= transform.origin.y + half.y + margin \
						or foot.y + body_height <= transform.origin.y - half.y - margin: continue
				var local := transform.affine_inverse() * foot
				var dx := maxf(absf(local.x) - half.x, 0.0)
				var dz := maxf(absf(local.z) - half.z, 0.0)
				if dx * dx + dz * dz <= (radius + margin) * (radius + margin): return false
	return true

func _blocked(delta: float) -> void:
	blocked_seconds += delta
	actor._set_walking(false)

func _set_outside(value: bool) -> void:
	outside = value
	actor.visible = not value
	var interaction: Area3D = actor.get_node("Interaction")
	interaction.collision_layer = 0 if value else 1

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
