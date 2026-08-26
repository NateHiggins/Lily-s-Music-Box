class_name DomesticRadioPass
extends Node
## Resolves every authored receiver against an existing furniture surface.
## Furniture owns spatial truth; this pass adds no free-floating coordinates.

const CATALOG := "res://data/domestic_radios.json"
const RadioScript := preload("res://scripts/props/domestic_radio_prop.gd")

var radios: Array[Node3D] = []
var failures: Array[String] = []


func build(layout: Dictionary, floor_nodes: Dictionary) -> Dictionary:
	radios.clear()
	failures.clear()
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	if file == null:
		push_error("Domestic radio catalog missing")
		return {"radios":0, "failures":["catalog_missing"]}
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var anchors := _anchors(layout)
	for profile in catalog.get("profiles", []):
		var unit := str(profile.get("unit", ""))
		var anchor_id := str(profile.get("anchor", ""))
		var found: Dictionary = anchors.get(anchor_id, {})
		if found.is_empty():
			failures.append("%s:%s" % [unit, anchor_id])
			continue
		var floor_id := str(found.floor_id)
		if not floor_nodes.has(floor_id):
			failures.append("%s:%s_floor" % [unit, floor_id])
			continue
		var record: Dictionary = found.record
		var at: Array = record.get("at", [])
		if at.size() != 2:
			var rect: Array = record.get("rect", [])
			if rect.size() == 4:
				at = [(float(rect[0]) + float(rect[2])) * 0.5,
						(float(rect[1]) + float(rect[3])) * 0.5]
		if at.size() != 2:
			failures.append("%s:%s_position" % [unit, anchor_id])
			continue
		var radio: Node3D = RadioScript.new()
		radio.configure(profile)
		var floor_z := float(found.floor_z)
		radio.position = GameBoot.b2g([float(at[0]), float(at[1]),
				floor_z + float(profile.get("surface_y", 0.77))])
		radio.rotation.y = deg_to_rad(float(record.get("yaw", 0.0)) + 180.0)
		floor_nodes[floor_id].add_child(radio)
		radios.append(radio)
	if not failures.is_empty():
		push_error("Domestic radio anchors unresolved: %s" % str(failures))
	print("[DOMESTIC RADIO] %d receivers across %d occupied units; %d unresolved"
			% [radios.size(), _units(radios).size(), failures.size()])
	return {"radios":radios.size(), "units":_units(radios).size(),
			"failures":failures.duplicate()}


func _anchors(layout: Dictionary) -> Dictionary:
	var out := {}
	for floor in layout.get("floors", []):
		for record in floor.get("furniture", []):
			var ident := str(record.get("id", ""))
			if ident != "":
				out[ident] = {"record":record, "floor_id":str(floor.id),
						"floor_z":float(floor.z)}
	return out


func _units(items: Array) -> Dictionary:
	var out := {}
	for radio in items:
		out[str(radio.unit)] = true
	return out
