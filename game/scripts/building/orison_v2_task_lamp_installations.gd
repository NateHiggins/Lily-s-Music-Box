extends RefCounted
## Fit the four missing source lamps to their furniture, retaining the bench actor.
const PATH := "res://data/orison_v2/task_lamp_installations.json"
const NativeLamp := preload("res://scripts/props/native_task_lamp.gd")
var errors: Array[String] = []

static func fit_terminal(adapter: OrisonV2AnchorAdapter, terminal: SignalTerminalProp) -> bool:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var fit: Dictionary = source.terminal_fit
	var support := adapter.resolve(str(fit.support)) as Node3D
	if terminal.name != str(fit.id) or support == null: return false
	var offset := Vector3(fit.offset[0], fit.offset[1], fit.offset[2])
	terminal.global_position += support.global_basis * offset
	return adapter.install_acoustic_overrides([str(fit.id)])

func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not validate(source, adapter): return false
	var identities: Array[String] = []
	for row: Dictionary in source.lamps:
		var lamp := adapter.resolve(str(row.id)) as LampProp if row.existing else NativeLamp.new()
		if not row.existing:
			lamp.name = str(row.id)
			lamp.prop_type = "lamp"
			lamp.variant = str(row.variant)
			lamp.position = Vector3(row.position[0], row.position[1], row.position[2])
			lamp.rotation.y = float(row.yaw)
			adapter.resolve(str(row.support)).add_child(lamp)
		lamp.graph_node_id = str(row.id)
		lamp.set_meta("source_unit", str(row.unit))
		lamp.set_meta("v2_lamp_support", str(row.support))
		identities.append(str(row.id))
	if not adapter.install_acoustic_overrides(identities):
		errors.append("original lamp graph positions could not be rebound")
		return false
	return true

func validate(source: Variant, adapter: OrisonV2AnchorAdapter) -> bool:
	if source is not Dictionary or source.get("schema_version") != 1 or source.get("lamps") is not Array:
		errors.append("malformed fitted lamp projection")
		return false
	var seen := {}
	for row: Dictionary in source.lamps:
		var identity := str(row.get("id", ""))
		var existing: Node = adapter.resolve(identity)
		if seen.has(identity) or not AcousticGraphData.nodes.has(identity) or not adapter.resolve(str(row.get("support", ""))) is StaticBody3D:
			errors.append("duplicate lamp or missing source graph/support: " + identity)
		seen[identity] = true
		if row.get("existing", false):
			if not existing is LampProp or existing.get("variant") != row.get("variant"):
				errors.append("existing lamp identity or variant differs: " + identity)
		elif existing != null:
			errors.append("new lamp identity already occupied: " + identity)
		var point: Variant = row.get("position")
		if point is not Array or point.size() != 3:
			errors.append("invalid lamp support position: " + identity)
		else:
			for component: Variant in point:
				if typeof(component) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(component)):
					errors.append("nonfinite lamp position: " + identity)
		if typeof(row.get("yaw")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(row.yaw)):
			errors.append("invalid lamp yaw: " + identity)
	if seen.size() != 5: errors.append("incomplete original lamp roster")
	return errors.is_empty()
