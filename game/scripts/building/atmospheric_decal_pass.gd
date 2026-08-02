class_name AtmosphericDecalPass
extends Node
## Cheap, deterministic surface evidence. Ordinary wear is common; uncanny
## evidence is deliberately rare enough that the player can doubt seeing it.

const ROOT := "res://assets/building/textures/atmospheric_decals/"
const DOMESTIC := ROOT + "domestic_residue_atlas.png"
const INSTITUTIONAL := ROOT + "institutional_wear_atlas.png"
const UNCANNY := ROOT + "uncanny_trace_atlas.png"

var decal_count := 0


func build(layout: Dictionary, floor_nodes: Dictionary) -> int:
	name = "AtmosphericDecalPass"
	for floor in layout.floors:
		var floor_id: String = floor.id
		if not floor_nodes.has(floor_id):
			continue
		var parent: Node3D = floor_nodes[floor_id]
		var z := float(floor.z)
		_add_institutional_layer(parent, floor_id, z)
		for room in floor.get("rooms", []):
			if room.get("kind", "") == "living" and room.get("unit", "") != "":
				_add_domestic_mark(parent, room, z)
		_add_uncanny_mark(parent, floor_id, z)
	return decal_count


func _add_domestic_mark(parent: Node3D, room: Dictionary, z: float) -> void:
	var rect: Array = room.rect
	var unit: String = room.unit
	var seed := absi(unit.hash())
	var west := seed % 2 == 0
	var x := float(rect[0]) + 0.102 if west else float(rect[2]) - 0.102
	var y := lerpf(float(rect[1]), float(rect[3]),
			0.27 + float(seed % 37) / 100.0)
	var tile := seed % 4
	# Mostly mundane: moved-picture ghosts, hand grease, water tide marks.
	_add(parent, DOMESTIC, tile % 2, tile / 2,
			[x, y, z + 1.10 + float(seed % 5) * 0.12],
			PI * 0.5 if west else -PI * 0.5,
			Vector2(0.38 + float(seed % 4) * 0.07, 0.34 + float(seed % 3) * 0.08))


func _add_institutional_layer(parent: Node3D, floor_id: String, z: float) -> void:
	if floor_id == "ROOF":
		return
	var seed := absi(floor_id.hash())
	# Shoulder rub / old notice on the corridor wall.
	_add(parent, INSTITUTIONAL, seed % 2, 0,
			[-5.225, -1.2 + float(seed % 25) * 0.10, z + 1.22],
			PI * 0.5, Vector2(0.55, 0.47))
	# Elevator-footfall fan or radiator plume near the core.
	_add(parent, INSTITUTIONAL, seed % 2, 1,
			[3.14, -2.25 + float(seed % 8) * 0.16, z + 0.72],
			-PI * 0.5, Vector2(0.52, 0.68))


func _add_uncanny_mark(parent: Node3D, floor_id: String, z: float) -> void:
	var placements := {
		"B1": [UNCANNY, 1, 1, [-3.14, 4.72, z + 0.72], -PI * 0.5],
		"F02": [UNCANNY, 0, 0, [5.225, 1.55, z + 1.38], -PI * 0.5],
		"F03": [UNCANNY, 0, 1, [-5.225, 0.82, z + 0.86], PI * 0.5],
		"F04": [UNCANNY, 1, 0, [5.225, -0.30, z + 1.52], -PI * 0.5],
		"F05": [UNCANNY, 1, 1, [-5.225, 2.08, z + 0.92], PI * 0.5],
		"F06": [UNCANNY, 0, 0, [5.225, 4.65, z + 1.42], -PI * 0.5],
	}
	if not placements.has(floor_id):
		return
	var p: Array = placements[floor_id]
	_add(parent, p[0], p[1], p[2], p[3], p[4], Vector2(0.48, 0.58))


func _add(parent: Node3D, atlas: String, col: int, row: int,
		position_b: Array, yaw: float, size: Vector2) -> void:
	var decal := StoryDecal.new()
	decal.setup(atlas, col, row, size)
	decal.position = GameBoot.b2g(position_b)
	decal.rotation.y = yaw
	parent.add_child(decal)
	decal_count += 1
