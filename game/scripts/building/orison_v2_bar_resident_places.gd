extends Node3D
## Stable, resident-specific places. This registry never chooses attendance,
## spawns a second resident, changes a timetable, or adds a blocking seat box.
const DATA := "res://data/orison_v2/bar_resident_places.json"
const DESTINATION_PLACES := {
	"juno_kells": "counter_01", "cal_dwyer": "counter_02", "omar_bell": "counter_03",
	"noel_price": "counter_04", "teresa_vale": "counter_05", "mina_vale": "mina_reserved",
	"lena_ortiz": "balcony_north_01", "sacha_reed": "balcony_north_02", "rhea_sato": "balcony_north_03",
	"iris_bell": "balcony_north_04", "jonah_price": "balcony_north_05", "mae_kessler": "balcony_north_06",
	"transient_guests": "balcony_north_07", "evelyn_marsh": "floor_bench_01", "cam_ortiz": "floor_bench_02",
	"peter_wren": "lounge_01", "malcolm_reed": "lounge_02", "nadia_quell": "lounge_03"}
var places: Dictionary = {}
# resident -> {owner: WeakRef, phase: String}; never retain a retired body.
var claims: Dictionary = {}
var errors: Array[String] = []
var _passages: Dictionary = {}
var _cleanup_due := .5
var _seat_gestures: WeakRef

func setup(region: OrisonV2BarRegion) -> bool:
	var destination := region.get("destination") as Node3D
	if destination != null: return _setup_destination(destination)
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if source is not Dictionary or source.get("schema_version") != 1: return false
	var rows := {}
	var geometry := region.get_node_or_null("RetainedBarGeometry")
	if geometry == null or not geometry.has_meta("bar_cafe_yaw_correction"): return false
	var chair_correction := float(geometry.get_meta("bar_cafe_yaw_correction"))
	for floor: Dictionary in region.source_layout.floors:
		if floor.id == "F01":
			for row: Dictionary in floor.furniture: rows[str(row.id)] = row
	if not rows.has("retail_bar_floor"): return false
	var floor_source: Dictionary = rows["retail_bar_floor"]
	var main_floor := float(floor_source.z0) + float(floor_source.h)
	var additions := {}
	for row: Dictionary in source.alcove:
		if additions.has(str(row.id)): return false
		additions[str(row.id)] = row
	var owners := {}
	var roster := preload("res://scripts/characters/orison_v2_resident_presentation.gd").roster()
	for resident: Dictionary in roster: owners[str(resident.id)] = true
	for row: Dictionary in source.places:
		var identity := str(row.resident)
		var furniture := str(row.furniture)
		if not owners.has(identity) or places.has(identity) or str(row.reason).is_empty(): return false
		var at: Vector3
		var yaw := 0.0
		var standing_height := -2.8
		if additions.has(furniture):
			var chair: Dictionary = additions[furniture]
			var p: Array = chair.at
			standing_height = float(p[2])
			at = GameBoot.b2g([p[0], p[1], standing_height + .49])
			yaw = deg_to_rad(float(chair.yaw)) + PI
		elif rows.has(furniture):
			var item: Dictionary = rows[furniture]
			if furniture.begins_with("retail_bar_stool"):
				# Pipe seats own p0/p1, not an assembly's z0. Their support is
				# the actual retained room floor, not the raised seat endpoint.
				standing_height = main_floor
				at = GameBoot.b2g(item.p1)
				yaw = PI # counter is north of the stools in source XY.
			else:
				standing_height = float(item.z0)
				var p: Array = item.at
				var seat_height := .475 if item.asm == "couch" else .478
				at = GameBoot.b2g([p[0], p[1], standing_height + seat_height])
				yaw = deg_to_rad(float(item.yaw)) + (PI if item.asm == "chair" else 0.0)
				if item.asm == "chair": yaw += chair_correction
		else: return false
		var marker := Marker3D.new()
		marker.name = "Preferred_" + identity
		add_child(marker); marker.position = at; marker.rotation.y = yaw
		var forward := marker.basis.z
		# Approach café chairs and stools from the aisle behind them, rather
		# than placing a standing body inside the table or counter footrail.
		var behind := furniture.begins_with("retail_bar_ch") or furniture.begins_with("retail_bar_stool")
		# Mina's standing place stays close to her chair, leaving the actual
		# 660 mm player capsule an aisle beside the retained deck handrail.
		var distance := .6 if identity == "mina_vale" else .8
		var approach := at + forward * (-distance if behind else distance)
		approach.y = standing_height
		places[identity] = {"marker": marker, "furniture": furniture, "reason": str(row.reason),
			"approach": approach, "floor_y": standing_height}
	if places.size() != 18 or owners.size() != 18: return false
	if not _mount_native(source, region): return false
	# Refit the existing three player sockets to their actual banquettes.
	# Keep their existing seated/occupied authority; no extra collision boxes.
	for i in 3:
		var seat := region.actors.get_node_or_null("BAR_SEAT_%d" % i) as BarSeatZone
		if seat == null: return false
		var owner_id := ""
		for resident: String in places:
			if str(places[resident].furniture) == "retail_bar_banq%d" % i: owner_id = resident
		if owner_id.is_empty(): return false
		var marker: Marker3D = places[owner_id].marker
		seat.global_transform = marker.global_transform
		places[owner_id]["player_socket"] = seat
	return true

func _setup_destination(destination: Node3D) -> bool:
	var sockets := destination.get_node_or_null("SeatSockets")
	if sockets == null or sockets.get_child_count() != 24: return false
	var roster := preload("res://scripts/characters/orison_v2_resident_presentation.gd").roster()
	if roster.size() != DESTINATION_PLACES.size(): return false
	for resident: Dictionary in roster:
		var identity := str(resident.id)
		if not DESTINATION_PLACES.has(identity): return false
		var seat_id := str(DESTINATION_PLACES[identity])
		var socket := sockets.get_node_or_null(seat_id) as Marker3D
		if socket == null or not socket.has_meta("seat"): return false
		var row: Dictionary = socket.get_meta("seat")
		var approach: Vector3 = to_local(destination.to_global(GameBoot.b2g(row.approach)))
		places[identity] = {"marker": socket, "furniture": str(row.support), "seat_id": seat_id,
			"reason": "existing counter company, quiet niche and audience groups",
			"approach": approach, "approach_node": str(row.get("approach_node", "")),
			"floor_y": approach.y, "npc_yaw": socket.global_rotation.y + PI}
	return true

func bind_seat_gestures(owner: Node3D) -> bool:
	if not is_instance_valid(owner) or not owner.has_method("can_reserve"): return false
	if _gesture_owner() != null and _gesture_owner() != owner: return false
	for resident: String in places:
		if places[resident].has("seat_id") and not (owner.get("seats") as Dictionary).has(str(places[resident].seat_id)): return false
	_seat_gestures = weakref(owner)
	return true

func _mount_native(source: Dictionary, region: OrisonV2BarRegion) -> bool:
	var packed := load(str(source.asset)) as PackedScene
	if packed == null: return false
	var model := packed.instantiate() as Node3D
	var parts := {}
	for part: Dictionary in source.parts:
		if parts.has(str(part.name)) or not MatLib.SETS.has(str(part.catalog_key)): model.free(); return false
		parts[str(part.name)] = part
	var mounted := 0
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not parts.has(str(draw.name)): model.free(); return false
		var part: Dictionary = parts[str(draw.name)]
		if draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != int(part.triangles) * 3:
			model.free(); return false
		var key := str(part.catalog_key)
		if absf(float(MatLib.SETS[key][3]) - float(part.tile)) > .000001: model.free(); return false
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false; material.uv1_scale = Vector3.ONE / float(part.tile)
		var tint: Array = part.tint
		material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		draw.mesh.surface_set_material(0, material)
		draw.name = "F01_retail_bar_native_alcove_" + str(part.name)
		draw.set_meta("material_key", key)
		draw.set_meta("bar_resident_assembly", str(part.assembly))
		# Static native furniture retains real support and obstacle faces.
		# There is no collision or sweep simulation on the NPC place markers.
		draw.create_trimesh_collision()
		mounted += 1
	if mounted != parts.size(): model.free(); return false
	add_child(model)
	# Preserve the same material-state and cache owner as the other bar stock.
	region.surface_pass.apply({"bar_resident_alcove": model})
	return true

func preferred(resident: String) -> Dictionary:
	return places.get(resident, {})

func claim(resident: String, actor: Node3D) -> bool:
	# Retain the immediate claim used by the inert presentation bench.
	return reserve(resident, actor) and occupy(resident, actor)

func reserve(resident: String, actor: Node3D) -> bool:
	prune_stale()
	if not _can_bind(resident, actor) or not _socket_available(resident, actor): return false
	if claims.has(resident):
		return str(claims[resident].phase) in ["reserved", "occupied"]
	# No yield between checking the player's authority and reserving its socket.
	if not _reserve_gesture_seat(resident, actor): return false
	var socket := _socket(resident)
	if socket != null: socket.occupied_by = resident
	claims[resident] = {"owner": weakref(actor), "phase": "reserved"}
	return true

func occupy(resident: String, actor: Node3D) -> bool:
	if phase(resident, actor) not in ["reserved", "occupied"] or not _socket_available(resident, actor): return false
	if not _reserve_gesture_seat(resident, actor): return false
	var socket := _socket(resident)
	if socket != null: socket.occupied_by = resident
	claims[resident].phase = "occupied"
	return true

func begin_departure(resident: String, actor: Node3D) -> bool:
	if phase(resident, actor).is_empty(): return false
	# Keep the seat excluded until the route owner has cleared its approach.
	claims[resident].phase = "departing"
	return true

func release(resident: String, actor: Node3D) -> bool:
	if phase(resident, actor).is_empty(): return false
	_drop_claim(resident)
	return true

func phase(resident: String, actor: Node3D) -> String:
	prune_stale()
	if not _live(actor) or _owner(claims.get(resident, {})) != actor: return ""
	return str(claims[resident].phase)

## Layout owns the clearance of these holding nodes. State alone cannot prove
## that a stair, door sweep or player route is clear. Reconfiguration is refused
## while anyone is queued or crossing, and slots do not move when a peer leaves.
func configure_passage(identity: String, holding_nodes: Array[Node3D]) -> bool:
	prune_stale()
	if identity.is_empty() or holding_nodes.is_empty(): return false
	if _passages.has(identity):
		var previous: Dictionary = _passages[identity]
		if not previous.queue.is_empty() or not previous.active.is_empty(): return false
	var nodes: Array[WeakRef] = []
	var seen := {}
	for node: Node3D in holding_nodes:
		if not _live(node) or seen.has(node.get_instance_id()): return false
		for other_id: String in _passages:
			if other_id == identity: continue
			for other: WeakRef in _passages[other_id].holding:
				if other.get_ref() == node: return false
		seen[node.get_instance_id()] = true
		nodes.append(weakref(node))
	_passages[identity] = {"holding": nodes, "queue": [], "active": {}}
	return true

func matches_passage(identity: String, holding_nodes: Array[Node3D]) -> bool:
	if not _passages.has(identity) or _passages[identity].holding.size() != holding_nodes.size(): return false
	for index in holding_nodes.size():
		if (_passages[identity].holding[index] as WeakRef).get_ref() != holding_nodes[index]: return false
	return true

## Returns the same slot on retries; null means refused/full, never permission
## to wait on the entrance itself. One body can request one passage at a time.
func enqueue_passage(identity: String, resident: String, actor: Node3D, allowed_slots: Array[int] = []) -> Node3D:
	prune_stale()
	if not _passages.has(identity) or not _can_bind(resident, actor): return null
	for other_id: String in _passages:
		for entry: Dictionary in _passage_entries(_passages[other_id]):
			if _owner(entry) == actor:
				return _holding(_passages[identity], entry) if other_id == identity \
					and (allowed_slots.is_empty() or allowed_slots.has(int(entry.slot))) else null
	var passage: Dictionary = _passages[identity]
	var used := {}
	for entry: Dictionary in _passage_entries(passage): used[int(entry.slot)] = true
	for slot in passage.holding.size():
		if used.has(slot) or (not allowed_slots.is_empty() and not allowed_slots.has(slot)): continue
		var node := (passage.holding[slot] as WeakRef).get_ref() as Node3D
		if not _live(node): continue
		passage.queue.append({"resident": resident, "owner": weakref(actor), "slot": slot})
		return node
	return null

## The route owner supplies current physical/player clearance. A false check
## never revokes an existing token or promotes another body into its passage.
func try_admit(identity: String, resident: String, actor: Node3D, clear: bool) -> bool:
	prune_stale()
	if not clear or not _live(actor) or not _passages.has(identity): return false
	var passage: Dictionary = _passages[identity]
	if not passage.active.is_empty(): return _matches(passage.active, resident, actor)
	if passage.queue.is_empty() or not _matches(passage.queue[0], resident, actor): return false
	passage.active = passage.queue.pop_front()
	return true

func has_admission(identity: String, resident: String, actor: Node3D) -> bool:
	prune_stale()
	return _passages.has(identity) and _matches(_passages[identity].active, resident, actor)

## The same exact-owner operation cancels a waiter or releases a crossing.
func leave_passage(identity: String, resident: String, actor: Node3D) -> bool:
	prune_stale()
	if not _passages.has(identity) or not _live(actor): return false
	var passage: Dictionary = _passages[identity]
	if _matches(passage.active, resident, actor):
		passage.active = {}
		return true
	for index in passage.queue.size():
		if _matches(passage.queue[index], resident, actor):
			passage.queue.remove_at(index)
			return true
	return false

func cancel_visit(resident: String, actor: Node3D) -> void:
	release(resident, actor)
	for identity: String in _passages: leave_passage(identity, resident, actor)

func prune_stale() -> void:
	for resident: String in claims.keys():
		if _owner(claims[resident]) == null: _drop_claim(resident)
	for identity: String in _passages:
		var passage: Dictionary = _passages[identity]
		if _owner(passage.active) == null: passage.active = {}
		for index in range(passage.queue.size() - 1, -1, -1):
			var entry: Dictionary = passage.queue[index]
			if _owner(entry) == null or _holding(passage, entry) == null:
				passage.queue.remove_at(index)

func _process(delta: float) -> void:
	_cleanup_due -= delta
	if _cleanup_due <= 0:
		_cleanup_due = .5
		prune_stale()

func _exit_tree() -> void:
	for resident: String in claims.keys(): _drop_claim(resident)
	_passages.clear()

func _drop_claim(resident: String) -> void:
	var owner := _gesture_owner()
	if owner != null and places.get(resident, {}).has("seat_id"):
		owner.call("release", str(places[resident].seat_id), resident, _owner(claims.get(resident, {})))
	var socket := _socket(resident)
	if socket != null and socket.occupied_by == resident: socket.occupied_by = ""
	claims.erase(resident)

func _socket(resident: String) -> BarSeatZone:
	var candidate: Variant = places.get(resident, {}).get("player_socket")
	return candidate as BarSeatZone if is_instance_valid(candidate) else null

func _socket_available(resident: String, actor: Node3D) -> bool:
	var place: Dictionary = places.get(resident, {})
	if place.has("seat_id"):
		var owner := _gesture_owner()
		return owner != null and bool(owner.call("can_reserve", str(place.seat_id), resident, actor))
	if not place.has("player_socket"): return true
	var socket := _socket(resident)
	return socket != null and not socket.seated and (socket.occupied_by.is_empty() or socket.occupied_by == resident)

func _reserve_gesture_seat(resident: String, actor: Node3D) -> bool:
	var place: Dictionary = places.get(resident, {})
	if not place.has("seat_id"): return true
	var owner := _gesture_owner()
	return owner != null and bool(owner.call("reserve", str(place.seat_id), resident, actor))

func _gesture_owner() -> Node3D:
	if _seat_gestures == null: return null
	var owner := _seat_gestures.get_ref() as Node3D
	return owner if _live(owner) else null

func _can_bind(resident: String, actor: Node3D) -> bool:
	if not places.has(resident) or not _live(actor): return false
	for identity: String in claims:
		if _conflicts(identity, _owner(claims[identity]), resident, actor): return false
	for identity: String in _passages:
		for entry: Dictionary in _passage_entries(_passages[identity]):
			if _conflicts(str(entry.resident), _owner(entry), resident, actor): return false
	return true

func _conflicts(bound_id: String, bound_actor: Node3D, resident: String, actor: Node3D) -> bool:
	return bound_actor != null and ((bound_id == resident and bound_actor != actor) or (bound_actor == actor and bound_id != resident))

func _passage_entries(passage: Dictionary) -> Array:
	var entries: Array = passage.queue.duplicate()
	if not passage.active.is_empty(): entries.append(passage.active)
	return entries

func _holding(passage: Dictionary, entry: Dictionary) -> Node3D:
	var node := (passage.holding[int(entry.slot)] as WeakRef).get_ref() as Node3D
	return node if _live(node) else null

func _matches(entry: Dictionary, resident: String, actor: Node3D) -> bool:
	return _live(actor) and str(entry.get("resident", "")) == resident and _owner(entry) == actor

func _owner(entry: Dictionary) -> Node3D:
	var reference := entry.get("owner") as WeakRef
	if reference == null: return null
	var node := reference.get_ref() as Node3D
	return node if _live(node) else null

func _live(node: Node3D) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()
