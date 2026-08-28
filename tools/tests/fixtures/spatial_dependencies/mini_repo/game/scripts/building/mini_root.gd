extends Node3D
## Synthetic building consumer exercising every scanner lane.

const FLOOR_SCENES := {
	"F01": "res://assets/building/floor_01.gltf",
}


func _ready() -> void:
	var layout := load_layout("res://data/building_layout.json")
	toggle_room("F01_LOBBY")
	toggle_room("F01_MISSING_ROOM")
	var register := find_child("F01_NIGHT_REGISTER")
	var hub_id := "MINI_HUB"
	var prefix := "F01_BAR_LT_" + str(3)
	var spawn := GameBoot.b2g([0.0, -9.0, 0.1])
	player.global_position = Vector3(1.0, 0.0, 2.0)
	var derived := GameBoot.b2g(marker["pos"])
	if register != null and hub_id != prefix:
		register.position = spawn + derived


func _build_batch(fid: String) -> void:
	var batch := Node3D.new()
	batch.name = "%s_VantryBatch" % fid
	add_child(batch)


func _lookup() -> Node:
	return get_node_or_null("F01/F01_LOBBY_CLOCK_01")
