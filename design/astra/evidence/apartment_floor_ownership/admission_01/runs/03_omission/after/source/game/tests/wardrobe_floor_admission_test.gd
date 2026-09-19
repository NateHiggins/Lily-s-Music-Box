extends Node
## Actual furniture/material producers on authored records and floor-provider
## identities. Floor containers are synthetic; no glTF/physics/render claim.
const ENC := preload("res://scripts/reality/apartment_encroachment.gd")
const FURNITURE := preload("res://scripts/building/furniture_interaction_pass.gd")
const SURFACE := preload("res://scripts/building/surface_pass.gd")
const SELECTED := ["2A_w0_wardrobe", "2C_w0_wardrobe", "3A_w0_wardrobe", "3B_aw_wardrobe",
		"4A_w0_wardrobe", "5A_w0_wardrobe", "5B_aw_wardrobe", "6B_aw_wardrobe", "6C_w0_wardrobe"]
const OWNED := {"2A_w0_wardrobe": "mina_caption_crisis", "2C_w0_wardrobe": "juno_feedback_tetris",
		"3B_aw_wardrobe": "omar_unrepairable", "4A_w0_wardrobe": "peter_form_corridor",
		"5B_aw_wardrobe": "cal_memory_radio", "6C_w0_wardrobe": "mae_contradictory_antiques"}
const FOREIGN := {"3A_w0_wardrobe": "mina_caption_crisis", "5A_w0_wardrobe": "peter_form_corridor",
		"6B_aw_wardrobe": "cal_memory_radio"}
var checks: Array = []
var failures := 0
var callbacks := 0
var fixture_root: Node3D
var enc: ApartmentEncroachment
var furniture: FurnitureInteractionPass
var surface: SurfacePass
var floor_nodes: Dictionary = {}
var record_nodes: Dictionary = {}
var observations: Array = []
var environment_before: Dictionary = {}
var root_inside: MeshInstance3D
var root_outside: MeshInstance3D
var no_case_draws: Array[MeshInstance3D] = []
var facts_before: Dictionary = {}


func _ready() -> void:
	RealityState.persistence_enabled = false
	call_deferred("_run")


func _run() -> void:
	facts_before = RealityState.data.duplicate(true)
	for key in ["DREAM_FIELD", "ENCROACH", "LIVING", "ENCROACH_FORCE"]:
		environment_before[key] = OS.get_environment(key)
	OS.set_environment("DREAM_FIELD", "0")
	OS.set_environment("ENCROACH", "1")
	OS.set_environment("LIVING", "1")
	OS.set_environment("ENCROACH_FORCE", "")
	var source := FileAccess.open("res://data/building_layout.json", FileAccess.READ)
	var layout: Dictionary = JSON.parse_string(source.get_as_text())
	source.close()
	var selected_layout: Dictionary = layout.duplicate(true)
	fixture_root = Node3D.new()
	fixture_root.name = "AuthoredWardrobeProducer"
	add_child(fixture_root)
	var record_count := 0
	for floor_record in selected_layout.floors:
		var floor_node := Node3D.new()
		floor_node.name = str(floor_record.id)
		fixture_root.add_child(floor_node)
		floor_nodes[str(floor_record.id)] = floor_node
		var records: Array = []
		for record in floor_record.get("furniture", []):
			if SELECTED.has(str(record.id)):
				records.append(record)
		floor_record.furniture = records
		record_count += records.size()
	_check("all nine selected records exist in the authored layout", record_count == 9)
	furniture = FURNITURE.new()
	fixture_root.add_child(furniture)
	var built: int = furniture.build(selected_layout, floor_nodes)
	_check("real FurnitureInteractionPass builds exactly nine wardrobe mechanisms", built == 9)
	for mechanism in furniture.owners:
		record_nodes[mechanism.record_id] = mechanism
	enc = ENC.new()
	fixture_root.add_child(enc)
	enc.set_process(false)
	enc.set_physics_process(false)
	# Actual build() supplies the complete provider, including no-case storeys.
	# No finishes/glTF are fabricated; only real units/fields are required here.
	enc.build(selected_layout, floor_nodes)
	_check("actual owner build supplies six cases and five storey fields", enc.units.size() == 6 and enc.fields.size() == 5)
	surface = SURFACE.new()
	surface.on_props_applied = _on_props_applied
	var mina: Dictionary = enc.units.mina_caption_crisis
	var rect: Vector4 = mina.rect
	var centre := Vector3((rect.x + rect.z) * 0.5, float(mina.floor_y) + 0.6, (rect.y + rect.w) * 0.5)
	root_inside = _control_mesh(fixture_root, "RootInside", centre)
	root_outside = _control_mesh(fixture_root, "RootOutsideVerticalSlab", centre + Vector3(0, 50, 0))
	# Deliberate overlapping test geometry: an explicit non-case floor provider
	# must win over the very same AABB that admits the genuine root-level prop.
	for floor_id in ["B1", "F01", "ROOF"]:
		no_case_draws.append(_control_mesh(floor_nodes[floor_id], "DeclaredNonCaseFloor", centre))
	_check("four low leaves independently overlap the previous authored slab", _foreign_overlap_oracle())
	var before_callbacks := callbacks
	surface.apply_props(fixture_root)
	_check("normal real prop sweep invokes one ownership callback", callbacks == before_callbacks + 1)
	_observe("normal")
	# Exact existing queued producer path and callback; no material row injection.
	surface.restore_props()
	before_callbacks = callbacks
	surface._queue_apply_props(fixture_root)
	var chunks := 0
	while not surface._lever_queue.is_empty() and chunks < 20:
		surface._drain_lever()
		chunks += 1
	_check("real queued tier reapplies all draws and invokes one callback", surface._lever_queue.is_empty() and callbacks == before_callbacks + 1)
	_observe("queued")
	_check("producer and ownership work leave persisted facts unchanged", RealityState.data == facts_before)
	call_deferred("_finish")


func _control_mesh(parent: Node, label: String, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = MatLib.get_mat("wood_dark", Color(0.82, 0.76, 0.68), 0.82)
	parent.add_child(mesh)
	return mesh


func _on_props_applied() -> void:
	callbacks += 1
	enc.reach_props(fixture_root)


func _foreign_overlap_oracle() -> bool:
	for record_id in FOREIGN:
		var mechanism: Node = record_nodes.get(record_id)
		if mechanism == null: return false
		var unit: Dictionary = enc.units[FOREIGN[record_id]]
		var low := 0
		for node in mechanism.find_children("*", "MeshInstance3D", true, false):
			var draw := node as MeshInstance3D
			var bounds := draw.global_transform * draw.get_aabb()
			var rect: Vector4 = unit.rect
			var overlap: bool = bounds.position.y <= float(unit.floor_y) + 3.6 \
				and bounds.end.y >= float(unit.floor_y) - 0.2 \
				and bounds.end.x >= rect.x and bounds.position.x <= rect.z \
				and bounds.end.z >= rect.y and bounds.position.z <= rect.w
			if draw.name in ["FramedLeaf", "RaisedPanel"]:
				if not overlap: return false
				low += 1
			elif draw.name == "BrassKnob" and overlap: return false
		if low != 4: return false
	return true


func _observe(phase: String) -> void:
	var record := {"phase": phase, "foreign_rows": {}, "registries": {}, "current_fields": {}, "case_rows": {}}
	for record_id in FOREIGN:
		var mechanism: Node = record_nodes[record_id]
		var wrong: Array = []
		for row in enc.prop_rows.get(FOREIGN[record_id], []):
			if mechanism.is_ancestor_of(row.mesh): wrong.append(str(mechanism.get_path_to(row.mesh)))
		record.foreign_rows[record_id] = wrong
		_check(phase + ": no prior-floor case rows for " + record_id, wrong.is_empty())
	for record_id in OWNED:
		var mechanism: Node = record_nodes[record_id]
		var owned_draws := 0
		for row in enc.prop_rows.get(OWNED[record_id], []):
			if mechanism.is_ancestor_of(row.mesh) and row.mesh.material_override == row.material:
				owned_draws += 1
		record.case_rows[record_id] = owned_draws
		_check(phase + ": six actual same-floor case draws remain live for " + record_id, owned_draws == 6)
	var all_rows_live := true
	for case_id in enc.prop_rows:
		for row in enc.prop_rows[case_id]:
			all_rows_live = all_rows_live and is_instance_valid(row.mesh) and row.mesh.material_override == row.material
	_check(phase + ": every retained case row is the actual installed material", all_rows_live)
	for floor_id in enc.fields:
		var expected := {}
		var field_ok := true
		for node in floor_nodes[floor_id].find_children("*", "MeshInstance3D", true, false):
			var material := (node as MeshInstance3D).material_override as ShaderMaterial
			if material == null: continue
			expected[material.get_instance_id()] = true
			field_ok = field_ok and _field_matches(material, str(floor_id))
		if floor_id == "F02" and root_inside.material_override is ShaderMaterial:
			expected[root_inside.material_override.get_instance_id()] = true
		var registered := {}
		for material in enc.storey_materials.get(floor_id, []): registered[material.get_instance_id()] = true
		var actual_ids: Array = registered.keys()
		var expected_ids: Array = expected.keys()
		actual_ids.sort()
		expected_ids.sort()
		record.registries[floor_id] = {"actual": actual_ids, "expected": expected_ids}
		record.current_fields[floor_id] = field_ok
		_check(phase + ": unique registry exactly matches installed consumers on " + str(floor_id),
				actual_ids == expected_ids and registered.size() == enc.storey_materials[floor_id].size())
		_check(phase + ": all physical floor draws sample their own field on " + str(floor_id), field_ok)
	_check(phase + ": root-level inside draw keeps bounded spatial admission", _root_case(root_inside) == "mina_caption_crisis" and _field_matches(root_inside.material_override as ShaderMaterial, "F02"))
	_check(phase + ": root-level outside draw fails the unchanged vertical bound", _root_case(root_outside).is_empty())
	for draw in no_case_draws:
		_check(phase + ": declared no-case floor rejects overlapping geometry on " + str(draw.get_parent().name), _root_case(draw).is_empty())
	var identities := {}
	for node in fixture_root.find_children("*", "MeshInstance3D", true, false):
		var draw := node as MeshInstance3D
		identities[draw] = draw.material_override
	enc.reach_props(fixture_root)
	var same := true
	for node in identities: same = same and node.material_override == identities[node]
	_check(phase + ": repeat sweep preserves all installed identities", same)
	observations.append(record)


func _root_case(draw: MeshInstance3D) -> String:
	return str(draw.material_override.get_meta("encroachment_case", "")) if draw.material_override != null else ""


func _field_matches(material: ShaderMaterial, floor_id: String) -> bool:
	return material != null and material.get_shader_parameter("has_living") == true \
		and material.get_shader_parameter("living_tex") == enc.fields[floor_id].texture() \
		and material.get_shader_parameter("living_origin") == enc.fields[floor_id].origin \
		and str(material.get_meta("living_storey", "")) == floor_id


func _check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: failures += 1
	print("[WARDROBE FLOOR] %s %s" % ["PASS" if passed else "FAIL", label])


func _finish() -> void:
	var root_ref: WeakRef = weakref(fixture_root)
	surface.on_props_applied = Callable()
	surface._prop_swaps.clear()
	surface._cache.clear()
	surface._props_root = null
	surface = null
	floor_nodes.clear()
	record_nodes.clear()
	no_case_draws.clear()
	root_inside = null
	root_outside = null
	enc = null
	furniture = null
	fixture_root.queue_free()
	fixture_root = null
	await get_tree().process_frame
	await get_tree().process_frame
	var retired: bool = root_ref.get_ref() == null
	_check("actual producer root and owners retired", retired)
	for key in environment_before: OS.set_environment(key, environment_before[key])
	var out := OS.get_environment("SHOT_DIR")
	_check("explicit fresh receipt directory supplied", not out.is_empty())
	var directory_ok: bool = not out.is_empty() and DirAccess.make_dir_recursive_absolute(out) == OK
	_check("receipt directory available", directory_ok)
	var file: FileAccess = FileAccess.open(out.path_join("wardrobe_floor.json"), FileAccess.WRITE) if directory_ok else null
	_check("readable receipt file can be written", file != null)
	if file != null:
		file.store_string(JSON.stringify({"scope": "actual authored wardrobe producers and owner/material methods; synthetic floor containers, no glTF/physics/render/performance claim",
				"checks": checks, "failures": failures, "observations": observations, "callbacks": callbacks, "retired": retired}, "\t"))
		file.close()
	print("WARDROBE FLOOR ADMISSION: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL", checks.size() - failures, checks.size()])
	get_tree().quit(0 if failures == 0 else 1)
