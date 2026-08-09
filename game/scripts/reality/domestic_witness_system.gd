class_name DomesticWitnessSystem
extends Node
## Builds one character-specific clock per apartment profile and routes each
## sanity intrusion to the resident's own domestic witness.

const CATALOG := "res://data/domestic_witness_clocks.json"
const ANOMALY_CATALOG := "res://data/domestic_anomaly_props.json"

var clocks: Dictionary = {}
var placements: Dictionary = {}
var anomalies: Dictionary = {}
var home_relays: Array[PossessedDomesticProp] = []
var player: Node3D
var vantry_points: VantryPointNetwork


func build(layout: Dictionary, floor_nodes: Dictionary) -> int:
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	if file == null:
		push_warning("domestic witness clock catalog missing")
		return 0
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	for spec in catalog.get("profiles", []):
		var room := _living_room(layout, str(spec.unit))
		if room.is_empty():
			push_warning("no room for domestic witness in " + str(spec.unit))
			continue
		var floor_id := "F0" + str(spec.unit).left(1)
		var floor_z := _floor_z(layout, floor_id)
		var floor_data := _floor_data(layout, floor_id)
		var clock := DomesticWitnessClock.new()
		clock.configure(spec)
		var placed := _place_clock(floor_data, room, spec, floor_z)
		clock.mounting = String(placed.mounting)
		clock.position = GameBoot.b2g([placed.x, placed.y,
				floor_z + float(placed.height)])
		clock.rotation.y = float(placed.yaw)
		floor_nodes.get(floor_id, self).add_child(clock)
		clocks[str(spec.case_id)] = clock
		placements[str(spec.case_id)] = placed
	var anomaly_count := _build_anomalies(layout, floor_nodes)
	print("[WITNESS] %d clocks and %d other domestic anomalies placed and rigged"
			% [clocks.size(), anomaly_count])
	return clocks.size() + anomaly_count


## A mantel clock and a travelling alarm belong on furniture.  Every other
## witness earns a real hook through the same placement law as the resident's
## pictures.  This runs before the art passes, so the clock silhouette is the
## fixed fact and the frame is the thing that concedes.
func _place_clock(floor_data: Dictionary, room: Dictionary,
		spec: Dictionary, _floor_z_value: float) -> Dictionary:
	var style := String(spec.get("style", "bauhaus"))
	if style in ["mantel", "travel_alarm"]:
		var surface := _nearest_surface(floor_data, room,
				float(spec.get("u", 0.5)), style)
		if not surface.is_empty():
			WallArtLaw.reserve_surface(room, surface.x, surface.y,
					surface.height, 0.27 if style == "mantel" else 0.18)
			return {"mounting": "table", "x": surface.x, "y": surface.y,
					"height": surface.height, "yaw": surface.yaw + PI,
					"room": String(room.get("id", "")), "style": style}
	var half_w := 0.25 if style in ["split_flap", "nixie", "writer",
			"vantry_modular"] else 0.23
	var spot := WallArtLaw.legal_spot(floor_data, room, "south",
			float(spec.get("u", 0.3)), 1.58, Callable(), half_w, 0.25)
	if bool(spot.get("ok", false)):
		return {"mounting": "wall", "x": spot.x, "y": spot.y,
				"height": spot.height, "yaw": spot.yaw,
				"room": String(room.get("id", "")), "style": style,
				"wall": spot.wall}
	# A missing clock is safer than a clock over a doorway, but retaining this
	# fallback makes a damaged source layout visible in the warehouse/test log.
	push_warning("no legal witness-clock hook in " + String(room.get("id", "?")))
	var rr: Array = room.rect
	return {"mounting": "wall_fallback", "x": lerpf(float(rr[0]),
			float(rr[2]), float(spec.get("u", 0.3))), "y": float(rr[1]) + 0.105,
			"height": 1.58, "yaw": PI, "room": String(room.get("id", "")),
			"style": style}


func _nearest_surface(floor_data: Dictionary, room: Dictionary,
		want_u: float, style: String) -> Dictionary:
	var rr: Array = room.rect
	var wanted := Vector2(lerpf(float(rr[0]), float(rr[2]), want_u),
			(float(rr[1]) + float(rr[3])) * 0.5)
	var best: Dictionary = {}
	var best_distance := INF
	for fu in floor_data.get("furniture", []):
		var cx := 0.0
		var cy := 0.0
		var width := 0.0
		var depth := 0.0
		var top := 0.0
		var asm := String(fu.get("asm", ""))
		if fu.has("rect"):
			var r: Array = fu.rect
			cx = (float(r[0]) + float(r[2])) * 0.5
			cy = (float(r[1]) + float(r[3])) * 0.5
			width = absf(float(r[2]) - float(r[0]))
			depth = absf(float(r[3]) - float(r[1]))
			top = float(fu.get("z0", 0.0)) + float(fu.get("h", 0.0))
		elif fu.has("at") and asm in ["coffee", "table_round", "nightstand",
				"shelf"]:
			cx = float(fu.at[0])
			cy = float(fu.at[1])
			match asm:
				"coffee": width = 1.0; depth = 0.55; top = 0.37
				"table_round": width = 0.82; depth = 0.82; top = 0.75
				"nightstand": width = 0.50; depth = 0.42; top = 0.62
				"shelf":
					width = float(fu.get("W", 1.0)); depth = 0.30; top = 1.26
					# The middle shelf, not its inaccessible crown; stand the clock
					# proud of the books so its hands remain readable.
					cy -= 0.20
		else:
			continue
		if cx < float(rr[0]) or cx > float(rr[2]) \
				or cy < float(rr[1]) or cy > float(rr[3]):
			continue
		if top < 0.32 or top > 1.30 or width < 0.38 or depth < 0.28:
			continue
		# Two residents share 4C. The first tabletop claim must make the
		# second choose another surface rather than occupy the same mantel.
		if WallArtLaw.surface_blocks(room, cx, cy, top + 0.22, 0.19):
			continue
		var distance := wanted.distance_to(Vector2(cx, cy))
		if style == "mantel" and asm == "shelf":
			distance -= 5.0  # Noel protects it among the museum objects.
		if distance < best_distance:
			best_distance = distance
			var room_centre := Vector2((float(rr[0]) + float(rr[2])) * 0.5,
					(float(rr[1]) + float(rr[3])) * 0.5)
			var facing := room_centre - Vector2(cx, cy)
			best = {"x": cx, "y": cy, "height": top + 0.22,
					"yaw": atan2(facing.x, facing.y)}
	return best


func bind_director(director: SanityDirector, body: Node3D) -> void:
	player = body
	if not director.intruded.is_connected(_on_intruded):
		director.intruded.connect(_on_intruded)


func bind_vantry_network(network: VantryPointNetwork) -> void:
	vantry_points = network


func _on_intruded(case_id: String, tier: int) -> void:
	var clock: DomesticWitnessClock = clocks.get(case_id)
	if is_instance_valid(clock):
		clock.stage_haunt(tier, player)
	var anomaly: Node = anomalies.get(case_id)
	if is_instance_valid(anomaly):
		anomaly.stage_haunt(case_id, tier, player)
	_stage_one_home_relay(case_id, tier)


func force(case_id: String, tier := 2) -> bool:
	var clock: DomesticWitnessClock = clocks.get(case_id)
	var anomaly: Node = anomalies.get(case_id)
	var did := is_instance_valid(clock) and clock.stage_haunt(tier, player)
	if is_instance_valid(anomaly):
		did = anomaly.stage_haunt(case_id, tier, player) or did
	if not home_relays.is_empty():
		var relay := home_relays[abs((case_id + str(tier)).hash()) % home_relays.size()]
		did = relay.stage_haunt(case_id, tier, player) or did
	return did


## Apartment 4B is the receiver, not the source. Exactly one familiar object
## answers each building intrusion, chosen deterministically, so the room feels
## implicated without every appliance performing on cue.
func _stage_one_home_relay(case_id: String, tier: int) -> void:
	if home_relays.is_empty():
		return
	var relay := home_relays[abs((case_id + str(tier)).hash()) % home_relays.size()]
	relay.stage_haunt(case_id, tier, player)


func _build_anomalies(layout: Dictionary, floor_nodes: Dictionary) -> int:
	var file := FileAccess.open(ANOMALY_CATALOG, FileAccess.READ)
	if file == null:
		push_warning("domestic anomaly catalog missing")
		return 0
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var count := 0
	for spec in catalog.get("props", []):
		var room := _living_room(layout, str(spec.unit))
		if room.is_empty(): continue
		var floor_id := "F0" + str(spec.unit).left(1)
		var rect: Array = room.rect
		var x := lerpf(float(rect[0]) + 0.30, float(rect[2]) - 0.30, float(spec.u))
		var y := lerpf(float(rect[1]) + 0.30, float(rect[3]) - 0.30, float(spec.v))
		var prop := PossessedDomesticProp.new()
		prop.configure(spec)
		prop.position = GameBoot.b2g([x, y, _floor_z(layout, floor_id) + float(spec.height)])
		prop.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
		floor_nodes.get(floor_id, self).add_child(prop)
		for case_id in spec.get("cases", []): anomalies[str(case_id)] = prop
		if bool(spec.get("relay_all", false)):
			home_relays.append(prop)
		count += 1
	# Teresa's witness is not a second ceiling object. Her real bedroom point
	# owns the mechanical aperture that closes before she stops speaking.
	if vantry_points and vantry_points.points.has("F01_D_BED_VANTRY_POINT"):
		anomalies["teresa_call_bells"] = vantry_points
		count += 1
	return count


func _living_room(layout: Dictionary, unit: String) -> Dictionary:
	var floor_id := "F0" + unit.left(1)
	for floor_data in layout.get("floors", []):
		if str(floor_data.id) != floor_id:
			continue
		for room in floor_data.get("rooms", []):
			if str(room.get("unit", "")) == unit \
					and str(room.get("kind", "")) == "living":
				return room
		for room in floor_data.get("rooms", []):
			if str(room.get("unit", "")) == unit:
				return room
	return {}


func _floor_z(layout: Dictionary, floor_id: String) -> float:
	for floor_data in layout.get("floors", []):
		if str(floor_data.id) == floor_id:
			return float(floor_data.z)
	return 0.0


func _floor_data(layout: Dictionary, floor_id: String) -> Dictionary:
	for floor_data in layout.get("floors", []):
		if str(floor_data.id) == floor_id:
			return floor_data
	return {}
