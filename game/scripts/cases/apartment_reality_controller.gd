class_name ApartmentRealityController
extends Node3D
## Owns the canonical state of an apartment manifestation. Anything explicitly
## registered can be restored deterministically after a case stabilizes.

var case_id := ""
var unit := ""
var room_min := Vector3.ZERO
var room_max := Vector3.ZERO
var _snapshots: Dictionary = {}
var _intensity := 0.0
var _thresholds: Array[RealityThreshold] = []
var _threshold_labels: Array[Label3D] = []


func setup(owner_case: String, unit_id: String, bounds_min: Vector3,
		bounds_max: Vector3) -> void:
	case_id = owner_case
	unit = unit_id
	room_min = bounds_min
	room_max = bounds_max


func _ready() -> void:
	name = "RealityController_" + unit
	add_to_group("apartment_reality_controllers")
	RealityRules.rule_changed.connect(_on_rule_changed)
	if "topology" in RealityRules.effect_for(case_id).get("rule_types", []):
		_build_loop_thresholds()
	_on_rule_changed(case_id, RealityRules.effect_for(case_id))


func register_node(node: Node3D) -> void:
	if not is_instance_valid(node) or _snapshots.has(node):
		return
	_snapshots[node] = {
		"transform": node.transform,
		"visible": node.visible
	}


func restore_now() -> void:
	for node in _snapshots:
		if is_instance_valid(node):
			node.transform = _snapshots[node].transform
			node.visible = _snapshots[node].visible
	_intensity = 0.0


func contains_point(point: Vector3) -> bool:
	return point.x >= room_min.x and point.x <= room_max.x \
			and point.y >= room_min.y and point.y <= room_max.y \
			and point.z >= room_min.z and point.z <= room_max.z


func gravity_at(point: Vector3) -> Vector3:
	if not contains_point(point) or _intensity <= 0.01:
		return Vector3.DOWN
	return Vector3.DOWN.lerp(
			RealityRules.local_gravity(case_id), _intensity).normalized()


func _on_rule_changed(changed_case: String, effect: Dictionary) -> void:
	if changed_case != case_id:
		return
	_intensity = float(effect.get("intensity", 0.0))
	var topology_live: bool = effect.get("active", false) \
			and "topology" in effect.get("rule_types", [])
	for threshold in _thresholds:
		threshold.enabled = topology_live
		threshold.monitoring = topology_live
	for label in _threshold_labels:
		label.visible = topology_live
	if not effect.get("active", false):
		restore_now()


func _build_loop_thresholds() -> void:
	var center := (room_min + room_max) * 0.5
	var first := _make_threshold(Vector3(
			center.x, room_min.y + 1.15, room_min.z + 0.65), 0.0)
	var second := _make_threshold(Vector3(
			center.x, room_min.y + 1.15, room_max.z - 0.65), 180.0)
	first.pair_with(second)
	_thresholds.assign([first, second])


func _make_threshold(at: Vector3, yaw: float) -> RealityThreshold:
	var threshold := RealityThreshold.new()
	threshold.position = at
	threshold.rotation_degrees.y = yaw
	threshold.enabled = false
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 2.25, 0.18)
	shape_node.shape = shape
	threshold.add_child(shape_node)
	var label := Label3D.new()
	label.text = "FORM CORRIDOR CONTINUES"
	label.position = Vector3(0, 1.0, 0)
	label.font_size = 34
	label.pixel_size = 0.002
	label.modulate = Color(0.76, 0.83, 0.68, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.visible = false
	threshold.add_child(label)
	_threshold_labels.append(label)
	add_child(threshold)
	return threshold
