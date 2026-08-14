extends Node
## Regression proof for the retired utility-excavation set piece.  The final
## street uses architecture and weather at its two ends; nothing inside those
## controls should still fence, trench or litter the live carriageway.

const LAYOUT_PATH := "res://data/building_layout.json"
const ROAD_Y := [-15.9, -18.0, -20.1, -22.2]
const OLD_BARRIER_X := [-19.55, -6.15, 12.85, 19.55]

var _fails := 0
var _space: PhysicsDirectSpaceState3D
var _capsule := CapsuleShape3D.new()


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	await get_tree().physics_frame
	_space = root.get_viewport().find_world_3d().direct_space_state
	_capsule.radius = 0.33
	_capsule.height = 1.524

	var layout_file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	_check("the authored layout is readable", layout_file != null)
	var obsolete: Array[String] = []
	var zebra_count := 0
	if layout_file != null:
		var parsed = JSON.parse_string(layout_file.get_as_text())
		if parsed is Dictionary:
			for floor in parsed.get("floors", []):
				if String(floor.get("id", "")) != "F01":
					continue
				for record in floor.get("furniture", []):
					var record_id := String(record.get("id", ""))
					if record_id.begins_with("retail_dig_") \
							or record_id == "retail_street_papers":
						obsolete.append(record_id)
					if record_id.begins_with("retail_zebra"):
						zebra_count += 1
	_check("no retired excavation or loose road-paper records remain",
			obsolete.is_empty())
	if not obsolete.is_empty():
		print("    obsolete records: %s" % [", ".join(obsolete)])
	_check("the authored zebra survives the cleanup", zebra_count == 11)

	var blocked: Array[String] = []
	for bx in OLD_BARRIER_X:
		for by in ROAD_Y:
			if not _is_clear(float(bx), float(by)):
				blocked.append("(%.2f, %.2f)" % [bx, by])
	_check("all sixteen former barricade stations are capsule-clear",
			blocked.is_empty())
	if not blocked.is_empty():
		print("    blocked stations: %s" % [", ".join(blocked)])

	var boundary := root.find_child("StreetEndWeatherBoundary", true, false)
	_check("the visible street-end boundary remains authoritative",
			boundary is StaticBody3D and boundary.get_child_count() == 6)

	print("[ROAD CLEARANCE] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)


func _is_clear(blender_x: float, blender_y: float) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _capsule
	params.transform = Transform3D(Basis(),
			GameBoot.b2g([blender_x, blender_y, 0.9]))
	params.collide_with_areas = false
	params.collision_mask = 1
	return _space.intersect_shape(params, 8).is_empty()
