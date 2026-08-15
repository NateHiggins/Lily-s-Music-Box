class_name FurnitureInteractionPass
extends Node
## Restores individual mechanism ownership to selected furniture records whose
## static bodies are intentionally merged into the per-floor glTF. A generator
## may omit the moving part itself, as the wardrobe source does for its leaves.

const ACTIVE_KINDS := {
	"toilet": true,
	"radio": true,
	"wardrobe": true,
	"jukebox": true,
}

var owners: Array[BakedFurnitureInteraction] = []


func build(layout: Dictionary, floor_nodes: Dictionary) -> int:
	owners.clear()
	for floor_data in layout.get("floors", []):
		var floor_id := str(floor_data.get("id", ""))
		if not floor_nodes.has(floor_id):
			continue
		for record in floor_data.get("furniture", []):
			var kind := str(record.get("asm", ""))
			if not ACTIVE_KINDS.has(kind):
				continue
			var at: Array = record.get("at", [])
			if at.size() != 2:
				push_error("Furniture interaction lacks an at[] record: %s" %
						str(record.get("id", "?")))
				continue
			var owner := BakedFurnitureInteraction.new()
			owner.setup(record)
			owner.position = GameBoot.b2g([float(at[0]), float(at[1]),
					float(floor_data.get("z", 0.0))
					+ float(record.get("z0", 0.0))])
			# Generated furniture and switch overlays use Blender's positive yaw
			# in Godot; the glTF conversion already performs the axis handedness.
			owner.rotation.y = deg_to_rad(float(record.get("yaw", 0.0)))
			floor_nodes[floor_id].add_child(owner)
			owners.append(owner)
	print("[FURNITURE INTERACTION] %d baked mechanisms restored" % owners.size())
	return owners.size()
