extends Node
## Autoload "AcousticGraphData": loads art/data's acoustic_graph.json (the
## same coordinate-driven model Blender built the geometry from) and offers
## lookups plus a debug line overlay of the transmission networks.

const NETWORK_COLORS := {
	"heating": Color(0.95, 0.5, 0.2), "water": Color(0.3, 0.6, 0.95),
	"electrical": Color(0.95, 0.9, 0.3), "structural": Color(0.7, 0.7, 0.7),
	"ventilation": Color(0.5, 0.9, 0.6), "flue": Color(0.9, 0.35, 0.5),
}

## Emitted when a propagated motif event arrives at a graph node. Strength
## is the product of (1 - damping) along the path; delay is accumulated
## per-node transmission delay — a knock in the basement reaches Floor 4
## audibly later than Floor 2.
signal network_event(node_id: String, event_index: int, accent: float,
		pitch: float, strength: float)
## Case manifestations use the same physical transmission paths, but carry
## narrative identity and recurrence instead of musical pitch.
signal reality_event(case_id: String, node_id: String, strength: float,
		recurrence: int)

var nodes: Dictionary = {}  # id -> node dict
var _overlay: MeshInstance3D
var _plans: Dictionary = {}  # origin id -> Array[{id, delay, strength}]


func _ready() -> void:
	var f := FileAccess.open("res://data/acoustic_graph.json", FileAccess.READ)
	if f == null:
		push_warning("acoustic_graph.json missing")
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for n in data.get("nodes", []):
		nodes[n.id] = n
	print("[ACOUSTIC] %d nodes loaded" % nodes.size())


func node_pos(id: String) -> Vector3:
	if not nodes.has(id):
		return Vector3.ZERO
	return GameBoot.b2g(nodes[id]["pos"])


func neighbors(id: String) -> Array:
	return nodes.get(id, {}).get("connections", [])


## Inject one motif event at a node; it spreads over the graph with the
## network's real delays and damping and arrives via network_event.
func propagate(origin: String, event_index: int, accent: float,
		pitch: float) -> void:
	if not nodes.has(origin):
		return
	for entry in _plan_for(origin):
		_deliver(entry, event_index, accent, pitch)


func _deliver(entry: Dictionary, event_index: int, accent: float,
		pitch: float) -> void:
	if entry.delay > 0.0:
		await get_tree().create_timer(entry.delay, false).timeout
	network_event.emit(entry.id, event_index, accent, pitch, entry.strength)


func propagate_reality(origin: String, case_id: String, intensity: float,
		recurrence: int) -> void:
	if not nodes.has(origin):
		push_warning("reality origin missing from acoustic graph: %s" % origin)
		return
	var grammar := PoltergeistLibrary.propagation(case_id)
	var plan := _reality_plan(origin, grammar)
	for entry in plan:
		_deliver_reality(entry, case_id, intensity, recurrence)


func _deliver_reality(entry: Dictionary, case_id: String, intensity: float,
		recurrence: int) -> void:
	var authored_delay := float(entry.get("reality_delay", entry.delay))
	if authored_delay > 0.0:
		await get_tree().create_timer(authored_delay, false).timeout
	reality_event.emit(case_id, entry.id,
			float(entry.strength) * intensity, recurrence)


## Turns the common physical graph into a resident-specific infection route.
## It never invents geometry: every delivery still follows a reachable graph
## node, but selection and ordering express the resident's repeatable rule.
func _reality_plan(origin: String, grammar: Dictionary) -> Array:
	var base := _plan_for(origin).duplicate(true)
	if grammar.is_empty():
		return base
	var selected: Array = []
	var carrier := str(grammar.get("carrier", "all"))
	var origin_node: Dictionary = nodes.get(origin, {})
	for entry in base:
		var node: Dictionary = nodes.get(entry.id, {})
		var keep := false
		match carrier:
			"network": keep = str(node.get("network", "")) in grammar.get("networks", [])
			"tokens": keep = _id_has_any(entry.id, grammar.get("tokens", []))
			"unit_stack": keep = _unit_letter(entry.id) == str(grammar.get("stack", ""))
			"same_type": keep = _device_type(entry.id) == _device_type(origin)
			"unit_mirror": keep = _unit_letter(entry.id) in _mirror_letters(_unit_letter(origin))
			_: keep = true
		if keep or entry.id == origin:
			selected.append(entry)
	# Sparse carriers are still legible; an empty one is not. Fall back to
	# reachable nodes rather than silently swallowing the manifestation.
	if selected.size() < 2:
		selected = base
	var pattern := str(grammar.get("pattern", "distance"))
	selected.sort_custom(func(a, b):
		return _route_key(a, pattern, origin_node) < _route_key(b, pattern, origin_node))
	var limit := int(grammar.get("limit", 0))
	if limit > 0 and selected.size() > limit:
		selected.resize(limit)
	var step := float(grammar.get("step", 0.2))
	var output: Array = []
	for index in selected.size():
		if pattern == "missing_word" and (index + 1) % int(grammar.get("skip_every", 4)) == 0:
			continue
		var entry: Dictionary = selected[index].duplicate()
		entry.reality_delay = float(grammar.get("base_delay", 0.0)) + index * step
		if pattern == "triage":
			entry.strength *= 1.0 + minf(0.25, index * 0.015)
		output.append(entry)
	# Echoes are real second traversals, not simultaneous extra volume.
	var echoes := int(grammar.get("echoes", 1))
	if pattern in ["return_wave", "round_trip", "contradiction"]:
		echoes = maxi(echoes, 2)
	for echo_index in range(1, echoes):
		var echo_pass := selected.duplicate(true)
		echo_pass.reverse()
		for index in echo_pass.size():
			var entry: Dictionary = echo_pass[index].duplicate()
			entry.reality_delay = output.size() * step + index * step
			entry.strength *= pow(0.72, echo_index)
			output.append(entry)
	return output


func _route_key(entry: Dictionary, pattern: String, origin_node: Dictionary) -> float:
	var pos := node_pos(entry.id)
	match pattern:
		"ascending", "gravity_wave", "accession": return pos.y * 100.0 + float(entry.delay)
		"egress", "round_trip": return -pos.y * 100.0 + absf(pos.x) + absf(pos.z)
		"delayed_floor": return pos.y * 120.0 + float(entry.delay)
		"spiral": return atan2(pos.z, pos.x) * 100.0 + pos.y
		"frequency_hop": return float(abs(hash(_device_type(entry.id))) % 17) * 100.0 + pos.y
		"seam": return pos.distance_to(GameBoot.b2g(origin_node.get("pos", [0, 0, 0])))
		"graft": return float(abs(hash(str(nodes[entry.id].get("network", "")))) % 7) * 100.0 + float(entry.delay)
		"contradiction": return pos.y * 100.0 + (-pos.x if _unit_letter(entry.id) in ["A", "B"] else pos.x)
	return float(entry.delay)


func _id_has_any(id: String, tokens: Array) -> bool:
	for token in tokens:
		if str(token) in id:
			return true
	return false


func _unit_letter(id: String) -> String:
	var parts := id.split("_")
	if parts.size() > 1 and parts[1] in ["A", "B", "C", "D"]:
		return parts[1]
	return ""


func _device_type(id: String) -> String:
	var parts := id.split("_")
	if parts.size() < 2:
		return id
	return "_".join(parts.slice(2)) if parts[0].begins_with("F0") else "_".join(parts.slice(1))


func _mirror_letters(letter: String) -> Array:
	match letter:
		"A": return ["A", "D"]
		"D": return ["D", "A"]
		"B": return ["B", "C"]
		"C": return ["C", "B"]
	return ["A", "D"]


## Test/debug inspection without emitting events or starting timers.
func debug_reality_plan(origin: String, case_id: String) -> Array:
	if not nodes.has(origin):
		return []
	return _reality_plan(origin, PoltergeistLibrary.propagation(case_id))


## Dijkstra by accumulated delay; strength decays with each node's damping.
## Arrivals below 5% strength are dropped — the building absorbs them.
func _plan_for(origin: String) -> Array:
	if _plans.has(origin):
		return _plans[origin]
	var best := {origin: {"delay": 0.0, "strength": 1.0}}
	var frontier := [origin]
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return best[a].delay < best[b].delay)
		var cur: String = frontier.pop_front()
		for nb in neighbors(cur):
			if not nodes.has(nb):
				continue
			var hop: Dictionary = nodes[nb]
			var d: float = best[cur].delay + float(hop.get("delay_ms", 30)) / 1000.0
			var s: float = best[cur].strength * (1.0 - float(hop.get("damping", 0.2)))
			if s < 0.05:
				continue
			if not best.has(nb) or d < best[nb].delay:
				best[nb] = {"delay": d, "strength": s}
				frontier.append(nb)
	var plan: Array = []
	for id in best:
		plan.append({"id": id, "delay": best[id].delay,
				"strength": best[id].strength})
	_plans[origin] = plan
	return plan


func set_overlay_visible(on: bool, parent: Node3D) -> void:
	if _overlay == null:
		_overlay = MeshInstance3D.new()
		var im := ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var drawn := {}
		for id in nodes:
			var n: Dictionary = nodes[id]
			var col: Color = NETWORK_COLORS.get(n.get("network", ""), Color.WHITE)
			for other in n.get("connections", []):
				var key: String = id + "|" + other if id < other else other + "|" + id
				if drawn.has(key) or not nodes.has(other):
					continue
				drawn[key] = true
				im.surface_set_color(col)
				im.surface_add_vertex(node_pos(id))
				im.surface_set_color(col)
				im.surface_add_vertex(node_pos(other))
		im.surface_end()
		_overlay.mesh = im
		_overlay.material_override = mat
		parent.add_child(_overlay)
	_overlay.visible = on
