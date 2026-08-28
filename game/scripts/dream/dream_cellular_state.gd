class_name DreamCellularState
extends RefCounted
## Compact, presentation-only physiology packet. Renderers copy ecological
## facts into this value; it has no reference to, and cannot mutate, authority.

const KEYS := [&"ether", &"information", &"novelty", &"contact", &"reporting",
		&"breathing", &"disturbance", &"recall", &"senescence", &"death", &"cleanup"]

var values := PackedFloat32Array()


func _init(source: Dictionary = {}) -> void:
	values.resize(KEYS.size())
	for i in KEYS.size():
		values[i] = clampf(float(source.get(KEYS[i], 0.0)), 0.0, 1.0)


func get_value(key: StringName) -> float:
	var at := KEYS.find(key)
	return values[at] if at >= 0 else 0.0


func to_vector_a() -> Vector4:
	return Vector4(values[0], values[1], values[2], values[3])


func to_vector_b() -> Vector4:
	return Vector4(values[4], values[5], values[6], values[7])


func to_vector_c() -> Vector4:
	return Vector4(values[8], values[9], values[10], 0.0)


func signature() -> String:
	return "%s|%s|%s" % [to_vector_a(), to_vector_b(), to_vector_c()]
