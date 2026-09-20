extends Node3D
## V2 route ownership for Mina. The existing timetable selects destinations;
## this owner walks the installed collision world between authored route nodes.
## Initial placement reconstructs from campaign time; live changes never warp.
const SOURCE := "res://data/orison_v2/mina_routine.json"
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

static func valid_source_header(source: Variant) -> bool:
	if source is not Dictionary:
		return false
	var version: Variant = source.get("schema_version")
	# This actor and its route transform have fixed owners. A different actor
	# or frame must not silently reuse Mina's timetable and adapter coordinates.
	return typeof(version) in [TYPE_INT, TYPE_FLOAT] and float(version) == 1.0 \
			and source.get("resident") == "mina_vale" \
			and source.get("frame") == "orison_v2_blockout" \
			and source.get("paths") is Array and source.get("places") is Dictionary

func setup(root: Node3D) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not valid_source_header(source): return false
	world = root
	places = source.places
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
	for identity in ["F02_DOOR_02", "F02_A_HALL_DOOR", "F02_A_BATH_DOOR", "F02_A_BED_DOOR"]:
		var door := world.find_child(identity + "_Leaf", true, false) as DoorProp
		if door == null or door.unit != "2A": return false
		_doors.append(door)
	_capsule.radius = .28
	_capsule.height = 1.40 # 25 cm step clearance, 1.65 m total standing height.
	_select_destination()
	if desired_id < 0: return false
	current_id = desired_id
	actor = AnimatedResident.new()
	actor.setup("Mina Vale","mina_vale","2A","res://assets/characters/mina_vale/mina_vale.gltf")
	actor.externally_driven = true
	actor.face_interacting_player = true
	add_child(actor)
	actor.global_position = graph.get_point_position(current_id)
	if destination == "out": _set_outside(true)
	return actor._model != null and preload("res://scripts/characters/mina_idle_animation.gd").install(actor)

func _point(identity: String, point: Vector3) -> int:
	if identities.has(identity): return int(identities[identity])
	var index := graph.get_point_count()
	identities[identity] = index
	graph.add_point(index,point)
	return index

func _select_destination() -> void:
	var info: Dictionary = world.campaign_clock.day_info()
	if not info.get("valid",false): return
	var block: Dictionary = world.resident_presence.resolve("mina_vale",str(info.day),
			world.campaign_clock.minute_of_day(),int(info.doy),bool(info.first_sat))
	destination = str(block.get("place","unit"))
	desired_id = int(identities.get(places.get(destination,""),-1))

func _physics_process(delta: float) -> void:
	if actor == null or not is_instance_valid(world): return
	_sample -= delta
	if _sample <= 0:
		_sample = .5
		_select_destination()
	if world.player.call_locked or desired_id < 0:
		actor._set_walking(false)
		return
	# The off-map weekly walk shares the established exterior abstraction:
	# cross the actual threshold, then remove/reintroduce the body only unseen.
	if destination == "out" and current_id == desired_id:
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
	for door in _doors:
		if is_instance_valid(door) and at.distance_to(door.global_position) < 1.8:
			door.npc_set_open(true)
	var next := at + flat.limit_length(delta*1.05)
	var ray := PhysicsRayQueryParameters3D.create(next+Vector3.UP*.34,next-Vector3.UP*.5,1)
	var space := actor.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(ray)
	# Ramp end caps are steeper than their walking face, but only a few
	# centimetres high. Admit a supported step, never a jump or wall climb.
	if floor_hit.is_empty() or floor_hit.normal.y < .45 \
			or absf(float(floor_hit.position.y)-at.y) > .25:
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
	actor._set_walking(true)
	if flat.length_squared() > .00001:
		actor.global_rotation.y = lerp_angle(actor.global_rotation.y,atan2(flat.x,flat.z),minf(1,delta*7))

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
