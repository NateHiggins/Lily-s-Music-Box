extends Node
## Focused TL-1 contract: historical silhouette and retained production seams.

const PropScript := preload("res://scripts/device/service_set_prop.gd")

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	var prop: ServiceSetProp = PropScript.new()
	add_child(prop)
	await get_tree().process_frame

	var landmark_names := [
		"LampBezelLandmark",
		"ArchedMeterLandmark",
		"DetectorDomeLandmark",
		"BatteryMassLandmark",
		"TelegramSlotLandmark",
	]
	_check("all five ruled silhouette landmarks are physical owners",
			landmark_names.all(func(value):
				return prop.find_child(value, true, false) is Node3D))
	var chassis := prop.find_child("HistoricalChassis", true, false) as Node3D
	var chassis_bounds := _geometry_bounds(chassis)
	_check("historical chassis is 30-34 cm long",
			chassis_bounds.size.y >= 0.30 and chassis_bounds.size.y <= 0.34)
	_check("chassis stays within the ruled service-instrument envelope",
			chassis_bounds.size.x >= 0.10 and chassis_bounds.size.x <= 0.13
			and chassis_bounds.size.z >= 0.07 and chassis_bounds.size.z <= 0.10)
	var fasteners := prop.find_child("PeriodFasteners", true, false)
	_check("separate plates carry repeated slotted period fasteners",
			_count_geometry(fasteners) >= 36)
	_check("silhouette is supported by control-scale construction",
			_count_geometry(prop) >= 85)
	_check("maker and model are physically labelled",
			_labels(prop).any(func(value): return "28-R" in value))

	prop.set_radio_powered(false, false)
	_check("radio seam still pushes the physical aerial home",
			not prop.radio_powered and prop._aerial.scale.y < 0.2)
	prop.set_radio_powered(true, false)
	prop.set_lamp_enabled(false, false)
	_check("lamp seam still moves hardware and extinguishes its circuit",
			not prop.lamp_enabled and not prop._lamp_glass_material.emission_enabled
			and not prop._lamp_indicator_material.emission_enabled)
	prop.set_lamp_enabled(true, false)
	var before := prop.printed_count
	_check("existing telegram seam exits through the physical slot",
			prop.print_telegram_card("TL-1 PROOF")
			and prop.printed_count == before + 1 and prop._receipt_root.visible)

	print("[MODEL 28-R TL-1] geometry=%d chassis=%s result=%s" % [
			_count_geometry(prop), str(chassis_bounds.size),
			"PASS" if _fails == 0 else "FAIL"])
	get_tree().quit(_fails)


func _geometry_bounds(root: Node3D) -> AABB:
	var points: Array[Vector3] = []
	_collect_bounds(root, Transform3D.IDENTITY, points)
	if points.is_empty():
		return AABB()
	var out := AABB(points[0], Vector3.ZERO)
	for point in points:
		out = out.expand(point)
	return out


func _collect_bounds(node: Node, inherited: Transform3D,
		points: Array[Vector3]) -> void:
	var here := inherited
	if node is Node3D:
		here = inherited * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var box := (node as MeshInstance3D).mesh.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					points.append(here * Vector3(x, y, z))
	for child in node.get_children():
		_collect_bounds(child, here, points)


func _count_geometry(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is GeometryInstance3D else 0
	for child in node.get_children():
		count += _count_geometry(child)
	return count


func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label3D:
		out.append((node as Label3D).text)
	for child in node.get_children():
		out.append_array(_labels(child))
	return out
