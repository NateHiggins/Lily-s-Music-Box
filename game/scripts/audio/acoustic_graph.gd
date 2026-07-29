extends Node
## Autoload "AcousticGraphData": loads art/data's acoustic_graph.json (the
## same coordinate-driven model Blender built the geometry from) and offers
## lookups plus a debug line overlay of the transmission networks.

const NETWORK_COLORS := {
	"heating": Color(0.95, 0.5, 0.2), "water": Color(0.3, 0.6, 0.95),
	"electrical": Color(0.95, 0.9, 0.3), "structural": Color(0.7, 0.7, 0.7),
	"ventilation": Color(0.5, 0.9, 0.6),
}

## Emitted when a propagated motif event arrives at a graph node. Strength
## is the product of (1 - damping) along the path; delay is accumulated
## per-node transmission delay — a knock in the basement reaches Floor 4
## audibly later than Floor 2.
signal network_event(node_id: String, event_index: int, accent: float,
		pitch: float, strength: float)

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
