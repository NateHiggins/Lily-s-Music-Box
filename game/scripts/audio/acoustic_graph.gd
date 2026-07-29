extends Node
## Autoload "AcousticGraphData": loads art/data's acoustic_graph.json (the
## same coordinate-driven model Blender built the geometry from) and offers
## lookups plus a debug line overlay of the transmission networks.

const NETWORK_COLORS := {
	"heating": Color(0.95, 0.5, 0.2), "water": Color(0.3, 0.6, 0.95),
	"electrical": Color(0.95, 0.9, 0.3), "structural": Color(0.7, 0.7, 0.7),
	"ventilation": Color(0.5, 0.9, 0.6),
}

var nodes: Dictionary = {}  # id -> node dict
var _overlay: MeshInstance3D


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
