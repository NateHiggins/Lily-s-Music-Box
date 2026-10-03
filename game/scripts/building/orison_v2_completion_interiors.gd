extends RefCounted
## Authored remaining homes use the same tested furniture and fitting owners.
const PATH := "res://data/orison_v2/completion_interiors.json"
const Furniture := preload("res://scripts/building/orison_v2_domestic_furniture.gd")
const Fittings := preload("res://scripts/building/orison_v2_domestic_fittings.gd")
const Lighting := preload("res://scripts/building/orison_v2_room_lighting.gd")
const Doors := preload("res://scripts/building/orison_v2_domestic_doors.gd")
var errors: Array[String] = []

func mount(adapter: OrisonV2AnchorAdapter, layout: Dictionary, parent: Node3D) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if source is not Dictionary or source.get("schema_version")!=1 \
			or source.get("doors") is not Array or source.get("furniture") is not Array \
			or source.get("fittings") is not Array or source.get("lighting") is not Dictionary:
		errors.append("completion interior source is malformed")
		return false
	var templates: Dictionary = {}
	var library: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Furniture.PATH))
	for record: Dictionary in library.furniture: templates[record.id] = record
	var furniture: Array = []
	for record: Dictionary in source.furniture:
		if not templates.has(record.template): return false
		var copy: Dictionary = templates[record.template].duplicate(true)
		copy.id = record.id
		if copy.has("mechanism"):
			if copy.mechanism.has("id"): copy.mechanism.id = record.id
			if copy.mechanism.has("unit"): copy.mechanism.unit = record.unit
		furniture.append(copy)
	var fittings := Fittings.new()
	var bodies := Furniture.new()
	var lights := Lighting.new()
	if not fittings.mount_completion(adapter):
		errors.append_array(fittings.errors)
		return false
	if not bodies.mount_source(adapter,{"schema_version":1,"furniture":furniture}):
		errors.append_array(bodies.errors)
		return false
	var specs := {}
	for spec: Dictionary in source.doors:
		if specs.has(spec.id) or spec.get("kind") not in ["service","apartment_entry","apartment_interior"] \
				or spec.get("unit") is not String or spec.get("swing_out") is not bool \
				or spec.get("leaf_state","closed") not in ["closed","locked"]: return false
		if absf(float(spec.get("mount_offset",0))) > .15 or float(spec.get("jamb_depth",.22)) <= 0: return false
		specs[spec.id] = spec
	if not Doors.new().mount_specs(adapter,layout,specs): return false
	for identity: String in specs:
		var anchor := adapter.resolve(identity) as Node3D
		for part: String in ["FrameLeft","FrameRight","FrameHead"]:
			var frame := anchor.get_node(part) as MeshInstance3D
			(frame.mesh as BoxMesh).size.z = float(specs[identity].get("jamb_depth",.22))
	if not lights.mount_completion(adapter,parent):
		errors.append_array(lights.errors)
		return false
	return true
