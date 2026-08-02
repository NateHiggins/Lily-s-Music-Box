class_name DomesticWitnessSystem
extends Node
## Builds one character-specific clock per apartment profile and routes each
## sanity intrusion to the resident's own domestic witness.

const CATALOG := "res://data/domestic_witness_clocks.json"
const ANOMALY_CATALOG := "res://data/domestic_anomaly_props.json"

var clocks: Dictionary = {}
var anomalies: Dictionary = {}
var player: Node3D


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
		var rect: Array = room.rect
		var x := lerpf(float(rect[0]) + 0.35, float(rect[2]) - 0.35,
				float(spec.get("u", 0.3)))
		# North wall, 4 cm into the room, at a believable eye-level position.
		var plan_y := float(rect[1]) + 0.055
		var clock := DomesticWitnessClock.new()
		clock.configure(spec)
		clock.position = GameBoot.b2g([x, plan_y, floor_z + 1.78])
		floor_nodes.get(floor_id, self).add_child(clock)
		clocks[str(spec.case_id)] = clock
	var anomaly_count := _build_anomalies(layout, floor_nodes)
	print("[WITNESS] %d clocks and %d other domestic anomalies placed and rigged"
			% [clocks.size(), anomaly_count])
	return clocks.size() + anomaly_count


func bind_director(director: SanityDirector, body: Node3D) -> void:
	player = body
	if not director.intruded.is_connected(_on_intruded):
		director.intruded.connect(_on_intruded)


func _on_intruded(case_id: String, tier: int) -> void:
	var clock: DomesticWitnessClock = clocks.get(case_id)
	if is_instance_valid(clock):
		clock.stage_haunt(tier, player)
	var anomaly: PossessedDomesticProp = anomalies.get(case_id)
	if is_instance_valid(anomaly):
		anomaly.stage_haunt(case_id, tier, player)


func force(case_id: String, tier := 2) -> bool:
	var clock: DomesticWitnessClock = clocks.get(case_id)
	var anomaly: PossessedDomesticProp = anomalies.get(case_id)
	var did := is_instance_valid(clock) and clock.stage_haunt(tier, player)
	if is_instance_valid(anomaly):
		did = anomaly.stage_haunt(case_id, tier, player) or did
	return did


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
