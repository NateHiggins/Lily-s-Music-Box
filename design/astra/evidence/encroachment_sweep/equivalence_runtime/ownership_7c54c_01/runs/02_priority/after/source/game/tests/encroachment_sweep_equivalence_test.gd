extends Node
## Two exact production-method copies, one deterministic specimen recipe.
## Installed draws and real state/field consumers are exercised, not build().
const BASE := preload("res://tests/fixtures/encroachment_sweep/baseline.gd")
const SURFACE := preload("res://scripts/building/surface_pass.gd")
const FIELD := preload("res://scripts/reality/living_field.gd")
const FUNCTIONAL := preload("res://scripts/props/functional_prop.gd")
const MINA := "mina_caption_crisis"
const JUNO := "juno_feedback_tetris"
const PETER := "peter_form_corridor"
const VARIANTS := ["candidate", "priority", "drop_late"]
var checks := 0
var failures := 0
var results: Array = []
var comparisons: Array = []
var retired: Array[WeakRef] = []
var mode := ""


func _ready() -> void:
	RealityState.persistence_enabled = false
	call_deferred("_run")


func _run() -> void:
	mode = OS.get_environment("ENCROACH_SWEEP_VARIANT")
	if mode.is_empty():
		mode = "candidate"
	_check("setup", "declared variant", VARIANTS.has(mode))
	if not VARIANTS.has(mode):
		call_deferred("_finish")
		return
	var selected: Script = load("res://tests/fixtures/encroachment_sweep/" + mode + ".gd")
	_check("setup", "selected production copy loads", selected != null and selected.can_instantiate())
	if selected == null or not selected.can_instantiate():
		call_deferred("_finish")
		return
	var facts_before: Dictionary = RealityState.data.duplicate(true)
	for reverse_order in [false, true]:
		var baseline := _exercise(BASE, "baseline", reverse_order)
		var candidate := _exercise(selected, mode, reverse_order)
		for phase in baseline:
			var same: bool = candidate.has(phase) and baseline[phase] == candidate[phase]
			_check("equivalence", "%s order=%s installed graph" % [phase, reverse_order], same)
			comparisons.append({"phase": phase, "reverse_order": reverse_order, "equal": same,
					"baseline": baseline[phase], "selected": candidate.get(phase, {})})
	_check("scope", "material seam leaves persisted facts unchanged", RealityState.data == facts_before)
	call_deferred("_finish")


func _exercise(script: Script, label: String, reverse_order: bool) -> Dictionary:
	var context := "%s/reversed=%s" % [label, reverse_order]
	var root := Node3D.new()
	root.name = "Specimen"
	add_child(root)
	var enc = script.new()
	root.add_child(enc)
	enc.set_process(false)
	enc.set_physics_process(false)
	var f02 := Node3D.new()
	f02.name = "F02"
	root.add_child(f02)
	var f04 := Node3D.new()
	f04.name = "F04"
	f04.position.y = 8.0
	root.add_child(f04)
	var field2 = FIELD.new()
	field2.configure(Vector4(-4, -3, 4, 3), 0.0, 202)
	var field4 = FIELD.new()
	field4.configure(Vector4(-4, -3, 4, 3), 8.0, 204)
	enc.fields = {"F02": field2, "F04": field4}
	var descriptions := {
		MINA: {"rect": Vector4(-3, -2, 1, 2), "floor_y": 0.0, "floor_node": f02},
		JUNO: {"rect": Vector4(-1, -2, 3, 2), "floor_y": 0.0, "floor_node": f02},
		PETER: {"rect": Vector4(-3, -2, 3, 2), "floor_y": 8.0, "floor_node": f04},
	}
	var order: Array = [JUNO, MINA, PETER] if reverse_order else [MINA, JUNO, PETER]
	for case_id in order:
		enc.units[case_id] = descriptions[case_id]
	enc.intensities = {MINA: 0.25, JUNO: 0.8, PETER: 0.0}
	enc._forced = enc.intensities.duplicate()
	var shared := _layered("shared")
	var only_a := _mesh(root, "OnlyA", Vector3(-2, 0.5, 0), shared)
	var only_b := _mesh(root, "OnlyB", Vector3(2, 0.5, 0), shared)
	var overlap := _mesh(root, "Overlap", Vector3(0, 0.5, 0), shared)
	var held := _mesh(root, "ClaimThenMove", Vector3(-2, 0.5, 1), shared)
	var unclaimed := _mesh(root, "MoveIntoCase", Vector3(20, 0.5, 0), shared)
	var floor4 := _mesh(f04, "UpperCase", Vector3(0, 0.5, 0), shared)
	var high := _mesh(root, "OutsideVerticalSlab", Vector3(0, 5, 0), shared)
	var edge := _mesh(root, "RotatedBoundary", Vector3(-3.45, 0.5, 0), shared)
	(edge.mesh as BoxMesh).size = Vector3(0.2, 0.4, 1.6)
	edge.rotation.y = PI / 4.0
	var empty := _mesh(root, "NoMesh", Vector3(0, 0.5, 0), shared)
	empty.mesh = null
	var standard := StandardMaterial3D.new()
	var ordinary := _mesh(root, "NonLayered", Vector3(0, 0.5, 0), standard)
	var unknown_source := _layered("unknown_source")
	var unknown := unknown_source.duplicate() as ShaderMaterial
	# Explicit input-boundary specimen, not a claimed production creator:
	# imported/retired case metadata is authoritative inside a live case.
	unknown.set_meta("encroachment_case", "retired_fixture_case")
	unknown.set_meta("encroachment_shared", unknown_source)
	var unknown_draw := _mesh(root, "UnknownOwner", Vector3(0, 0.5, 1), unknown)
	var functional = FUNCTIONAL.new()
	functional.name = "OrdinaryFunctionalProp"
	root.add_child(functional)
	var functional_draw := _mesh(functional, "FunctionalDraw", Vector3(-2, 0.5, -1), shared)
	var private_view := SubViewport.new()
	private_view.name = "PrivateWorld"
	private_view.own_world_3d = true
	private_view.size = Vector2i(16, 16)
	private_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(private_view)
	var private_material := _layered("private")
	var private_draw := _mesh(private_view, "PrivateDraw", Vector3(0, 0.5, 0), private_material)
	var excluded: Array = [private_draw]
	for kind in ["character", "resident_placeholders", "animated_residents", "NPC_Resident", "queued"]:
		var boundary: Node3D = CharacterBody3D.new() if kind == "character" else Node3D.new()
		boundary.name = kind
		root.add_child(boundary)
		if kind in ["resident_placeholders", "animated_residents"]:
			boundary.add_to_group(kind)
		var draw := _mesh(boundary, "ExcludedDraw", Vector3(0, 0.5, 0), _layered(kind))
		excluded.append(draw)
		if kind == "queued":
			boundary.queue_free()
	# This finish is an actual SurfacePass-produced material installed in a
	# mesh surface. No living_storey or case finish metadata is manufactured.
	var finish_source := _layered("surface_finish")
	var finish := _mesh(f02, "SurfaceFinish", Vector3(6, 0.5, 0), null)
	finish.set_surface_override_material(0, finish_source)
	var before_disabled := _snapshot(root, enc)
	enc.enabled = false
	_check(context, "disabled seam returns zero", enc.reach_props(root) == 0)
	_check(context, "disabled seam leaves installed graph unchanged", before_disabled == _snapshot(root, enc))
	enc.enabled = true
	enc._tentacle_candidates["stale"] = [1]
	var phases := {}
	var count: int = enc.reach_props(root)
	_check(context, "initial analytic membership count is seven", count == 7)
	_check(context, "nonoverlapping cases claim independently", _case(only_a) == MINA and _case(only_b) == JUNO)
	_check(context, "overlap obeys authored priority", _case(overlap) == (JUNO if reverse_order else MINA))
	_check(context, "eight-corner extent reaches beyond outside center", _case(edge) == MINA)
	_check(context, "vertical slabs separate floors", _case(floor4) == PETER and _case(high).is_empty())
	_check(context, "ordinary FunctionalProp remains eligible", _case(functional_draw) == MINA)
	_check(context, "unknown owner remains exact installed input", unknown_draw.material_override == unknown and _case(unknown_draw) == "retired_fixture_case")
	_check(context, "unclaimed and ineligible draws retain sources", unclaimed.material_override == shared
			and high.material_override == shared and ordinary.material_override == standard and empty.material_override == shared)
	_check(context, "case copies preserve source while separating installed owners", only_a.material_override != shared
			and only_b.material_override != shared and only_a.material_override != only_b.material_override
			and only_a.material_override.get_meta("encroachment_shared") == shared
			and (only_a.material_override as ShaderMaterial).get_shader_parameter("albedo_tex") == shared.get_shader_parameter("albedo_tex")
			and (only_a.material_override as ShaderMaterial).get_shader_parameter("roughness_mul") == shared.get_shader_parameter("roughness_mul"))
	_check(context, "initial installed A state", _amounts(only_a, Vector4(0, 0.0875, 0.0625, 0), Vector4(0, 0, 0.2125, 0)))
	_check(context, "initial installed B state", _amounts(only_b, Vector4(0, 0.28, 0.2, 0), Vector4(0, 0.324, 0.68, 0)))
	_check(context, "prop readiness and candidate refresh complete", enc._props_ready and enc._tentacle_candidates.is_empty())
	_check(context, "actual installed surface cache remains the lifecycle consumer", finish.get_surface_override_material(0) == finish_source
			and enc.storey_materials.F02.has(finish_source) and finish_source.get_shader_parameter("living_tex") == field2.texture())
	_check(context, "private world really differs from ordinary world", private_draw.get_world_3d() != only_a.get_world_3d())
	_check(context, "private and actor materials stay outside living state", _excluded_clean(excluded))
	_check(context, "all active case rows target installed draws", _rows_live(enc))
	_check(context, "registry has no duplicate entries", _unique_registry(enc))
	phases.initial = _snapshot(root, enc)
	var stable_ids := _installed_ids(root)
	for _repeat in 3:
		enc.reach_props(root)
	_check(context, "three no-op sweeps preserve every installed identity", _installed_ids(root) == stable_ids)
	_check(context, "three no-op sweeps preserve exact observable graph", _snapshot(root, enc) == phases.initial)
	phases.repeated = _snapshot(root, enc)
	var held_material := held.material_override
	held.position = Vector3(2, 0.5, 1)
	unclaimed.position = Vector3(-2, 0.5, 1.5)
	var late := _mesh(root, "LateArrival", Vector3(-2, 0.5, -1.5), shared)
	var alias := _mesh(root, "KnownOwnerAlias", Vector3(2, 0.5, -1), held_material)
	var old_a := only_a.material_override
	var replacement := _layered("replacement")
	only_a.material_override = replacement
	enc.intensities[MINA] = 0.6
	enc.intensities[JUNO] = 0.1
	enc._forced = enc.intensities.duplicate()
	count = enc.reach_props(root)
	_check(context, "late and moved census membership count is ten", count == 10)
	_check(context, "new draw is discovered on the next sweep", _case(late) == MINA and _row_is_live(enc, MINA, late))
	_check(context, "previously unclaimed moved draw is reconsidered", _case(unclaimed) == MINA)
	_check(context, "known metadata survives moved bounds and live sharing", _case(held) == MINA and held.material_override == held_material
			and alias.material_override == held_material and _row_is_live(enc, MINA, alias))
	_check(context, "replacement gets a fresh installed row and original link", only_a.material_override != replacement
			and only_a.material_override != old_a and only_a.material_override.get_meta("encroachment_shared", null) == replacement
			and _row_is_live(enc, MINA, only_a) and not enc.storey_materials.F02.has(old_a))
	_check(context, "updated A state reaches current draw immediately", _amounts(only_a, Vector4(0, 0.21, 0.15, 0), Vector4(0, 0.052, 0.51, 0)))
	_check(context, "updated B state stays independent", _amounts(only_b, Vector4(0, 0.035, 0.025, 0), Vector4(0, 0, 0.085, 0)))
	_check(context, "new case draws receive the same immediate state", _amounts(late, Vector4(0, 0.21, 0.15, 0), Vector4(0, 0.052, 0.51, 0)))
	_check(context, "boundary exclusions survive subsequent sweep", _excluded_clean(excluded))
	phases.late_moved_replaced = _snapshot(root, enc)
	var consumer_ids := _installed_ids(root)
	field2.stain[0] = 0.9
	_check(context, "real field classifier reports STAIN", field2.lifecycle_stage_name() == "stain")
	enc._push_living_lifecycle("F02", field2)
	_check(context, "actual STAIN reaches installed case and surface finish", _stage(only_a.material_override, field2.lifecycle_stage())
			and _stage(finish.get_surface_override_material(0), field2.lifecycle_stage()))
	_check(context, "field texture identity remains exact", (only_a.material_override as ShaderMaterial).get_shader_parameter("living_tex") == field2.texture()
			and (floor4.material_override as ShaderMaterial).get_shader_parameter("living_tex") == field4.texture())
	phases.stain = _snapshot(root, enc)
	field2.sources = [{"intensity": 0.8}]
	field2.vascular_relays.append({"fixture_classifier_input": true})
	_check(context, "real field classifier reports EXCHANGE", field2.lifecycle_stage_name() == "exchange")
	enc._push_living_lifecycle("F02", field2)
	_check(context, "actual EXCHANGE reaches current live rows and finish", _stage(only_a.material_override, field2.lifecycle_stage())
			and _stage(finish.get_surface_override_material(0), field2.lifecycle_stage())
			and _stage(floor4.material_override, field4.lifecycle_stage()))
	_check(context, "state and lifecycle updates retain installed identities", _installed_ids(root) == consumer_ids)
	phases.exchange = _snapshot(root, enc)
	# Keep the detached node alive until all synchronous calls complete so a
	# cached-census negative does not introduce a freed-instance diagnostic.
	var retired_material := late.material_override
	root.remove_child(late)
	enc.reach_props(root)
	_check(context, "detached draw leaves current rows and registry", not _row_is_live(enc, MINA, late)
			and not enc.storey_materials.F02.has(retired_material))
	_check(context, "final registry stays unique and installed", _unique_registry(enc) and _rows_live(enc))
	phases.detached = _snapshot(root, enc)
	late.free()
	retired.append(weakref(root))
	retired.append(weakref(enc))
	root.free()
	return phases


func _layered(tag: String) -> ShaderMaterial:
	var standard := StandardMaterial3D.new()
	standard.albedo_color = Color(0.4, 0.3, 0.2, 1)
	standard.roughness = 0.63
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.6, 0.4, 0.2, 1))
	standard.albedo_texture = ImageTexture.create_from_image(image)
	var cache := {}
	var material: ShaderMaterial = SURFACE.surface_for(standard, {"uv_mode": 1}, tag, cache)
	material.set_meta("fixture_source", tag)
	return material


func _mesh(parent: Node, label: String, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func _case(draw: MeshInstance3D) -> String:
	return str(draw.material_override.get_meta("encroachment_case", "")) if draw.material_override != null else ""


func _amounts(draw: MeshInstance3D, first: Vector4, second: Vector4) -> bool:
	var material := draw.material_override as ShaderMaterial
	if material == null:
		return false
	var amount = material.get_shader_parameter("mask_amount")
	var amount2 = material.get_shader_parameter("mask2_amount")
	return amount is Vector4 and amount2 is Vector4 and amount.is_equal_approx(first) and amount2.is_equal_approx(second)


func _stage(material: Material, stage: int) -> bool:
	return material is ShaderMaterial and is_equal_approx(float(material.get_shader_parameter("living_lifecycle_stage")), float(stage))


func _excluded_clean(draws: Array) -> bool:
	for draw in draws:
		var material := draw.material_override as ShaderMaterial
		if material == null or material.has_meta("encroachment_case") or material.get_shader_parameter("has_living") == true:
			return false
	return true


func _row_is_live(enc, case_id: String, draw: MeshInstance3D) -> bool:
	for row in enc.prop_rows.get(case_id, []):
		if row.mesh == draw:
			return row.material == draw.material_override
	return false


func _rows_live(enc) -> bool:
	for case_id in enc.prop_rows:
		for row in enc.prop_rows[case_id]:
			if not is_instance_valid(row.mesh) or row.mesh.material_override != row.material:
				return false
	return true


func _unique_registry(enc) -> bool:
	for floor_id in enc.storey_materials:
		var found := {}
		for material in enc.storey_materials[floor_id]:
			if material == null or found.has(material):
				return false
			found[material] = true
	return true


func _installed_ids(root: Node) -> Dictionary:
	var out := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var draw := node as MeshInstance3D
		out[str(root.get_path_to(draw))] = draw.material_override.get_instance_id() if draw.material_override != null else 0
	return out


func _snapshot(root: Node, enc) -> Dictionary:
	var draws := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		draws[str(root.get_path_to(node))] = node
	var paths: Array = draws.keys()
	paths.sort()
	var labels := {}
	for path in paths:
		var draw: MeshInstance3D = draws[path]
		if draw.material_override != null and not labels.has(draw.material_override):
			labels[draw.material_override] = path + ":override"
		if draw.mesh != null:
			for index in draw.mesh.get_surface_count():
				var material := draw.get_surface_override_material(index)
				if material != null and not labels.has(material):
					labels[material] = path + ":surface_" + str(index)
	var mesh_rows := {}
	for path in paths:
		var draw: MeshInstance3D = draws[path]
		var surfaces: Array = []
		if draw.mesh != null:
			for index in draw.mesh.get_surface_count():
				surfaces.append(_material_snapshot(draw.get_surface_override_material(index), labels, enc))
		mesh_rows[path] = {"override": _material_snapshot(draw.material_override, labels, enc), "surfaces": surfaces}
	var cases := {}
	for case_id in enc.prop_rows:
		var rows: Array = []
		for row in enc.prop_rows[case_id]:
			var relative_path := str(root.get_path_to(row.mesh)) if root.is_ancestor_of(row.mesh) else "detached:" + str(row.mesh.name)
			rows.append({"path": relative_path, "installed": row.mesh.material_override == row.material,
					"material": _material_label(row.material, labels), "shared": _material_label(row.shared, labels)})
		cases[case_id] = rows
	var registry := {}
	for floor_id in enc.storey_materials:
		var rows: Array = []
		for material in enc.storey_materials[floor_id]:
			rows.append(_material_label(material, labels))
		rows.sort()
		registry[floor_id] = rows
	return {"draws": mesh_rows, "case_rows": cases, "registry": registry, "props_reached": enc.props_reached,
			"props_ready": enc._props_ready, "tentacle_candidates": enc._tentacle_candidates.size()}


func _material_label(material: Material, labels: Dictionary) -> String:
	if material == null:
		return "null"
	return str(labels.get(material, "source:" + str(material.get_meta("fixture_source", material.get_class()))))


func _material_snapshot(material: Material, labels: Dictionary, enc) -> Dictionary:
	if material == null:
		return {}
	var out := {"sharing_group": _material_label(material, labels), "class": material.get_class(),
			"case": str(material.get_meta("encroachment_case", "")), "storey": str(material.get_meta("living_storey", ""))}
	if material.has_meta("encroachment_shared"):
		out.shared = _material_label(material.get_meta("encroachment_shared"), labels)
	if material is ShaderMaterial and material.shader != null:
		out.shader = material.shader.resource_path
		var parameters := {}
		for descriptor in material.shader.get_shader_uniform_list():
			parameters[str(descriptor.name)] = _canonical(material.get_shader_parameter(descriptor.name), enc)
		out.parameters = parameters
	return out


func _canonical(value, enc):
	match typeof(value):
		TYPE_FLOAT:
			return snappedf(value, 0.000001)
		TYPE_VECTOR2:
			return [snappedf(value.x, 0.000001), snappedf(value.y, 0.000001)]
		TYPE_VECTOR3:
			return [snappedf(value.x, 0.000001), snappedf(value.y, 0.000001), snappedf(value.z, 0.000001)]
		TYPE_VECTOR4:
			return [snappedf(value.x, 0.000001), snappedf(value.y, 0.000001), snappedf(value.z, 0.000001), snappedf(value.w, 0.000001)]
		TYPE_COLOR:
			return [snappedf(value.r, 0.000001), snappedf(value.g, 0.000001), snappedf(value.b, 0.000001), snappedf(value.a, 0.000001)]
		TYPE_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var out: Array = []
			for item in value:
				out.append(_canonical(item, enc))
			return out
		TYPE_OBJECT:
			if value == null:
				return null
			for floor_id in enc.fields:
				if value == enc.fields[floor_id].texture():
					return "field_texture:" + str(floor_id)
			if value is Resource:
				var resource_info := {"class": value.get_class(), "path": value.resource_path}
				if value is Texture2D:
					resource_info.size = [value.get_width(), value.get_height()]
				return resource_info
			return value.get_class()
	return value


func _check(context: String, label: String, ok: bool) -> void:
	checks += 1
	results.append({"context": context, "label": label, "ok": ok})
	if ok:
		print("[SWEEP PASS] %s %s" % [context, label])
	else:
		failures += 1
		printerr("[SWEEP FAIL] %s %s" % [context, label])


func _finish() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var all_gone := true
	for reference in retired:
		all_gone = all_gone and reference.get_ref() == null
	_check("retirement", "all four specimen roots and owners are released", retired.size() == 8 and all_gone)
	var output_dir := OS.get_environment("SHOT_DIR")
	_check("receipt", "explicit receipt directory supplied", not output_dir.is_empty())
	if not output_dir.is_empty():
		var directory_ok := DirAccess.make_dir_recursive_absolute(output_dir) == OK
		_check("receipt", "receipt directory available", directory_ok)
		if directory_ok:
			var file := FileAccess.open(output_dir.path_join("equivalence.json"), FileAccess.WRITE)
			_check("receipt", "receipt writable", file != null)
			if file != null:
				file.store_string(JSON.stringify({"scope": "actual reach_props methods and material consumers; fixture-authored bounds, no production build or rendering/performance claim",
						"variant": mode, "checks": checks, "failures": failures, "results": results, "comparisons": comparisons,
						"retired": all_gone and retired.size() == 8}, "\t"))
				file.close()
	print("ENCROACHMENT SWEEP EQUIVALENCE: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)
