extends Node
## Focused real-owner contract. No building, ecology tick, timing or human claim.
const EncroachmentScript := preload("res://scripts/reality/apartment_encroachment.gd")
const LivingScript := preload("res://scripts/reality/living_field.gd")
const SurfaceScript := preload("res://scripts/building/surface_pass.gd")
const FunctionalScript := preload("res://scripts/props/functional_prop.gd")
const MINA := "mina_caption_crisis"
const PETER := "peter_form_corridor"
var checks := 0
var failures := 0
var callbacks := 0
var enc: ApartmentEncroachment
var owned: Node3D


func _ready() -> void:
	RealityState.persistence_enabled = false
	call_deferred("_run")


func _run() -> void:
	owned = Node3D.new()
	owned.name = "BindingFixture"
	add_child(owned)
	enc = EncroachmentScript.new()
	owned.add_child(enc)
	# Do not invoke build(): this fixture owns material registration, not the
	# ecology or a substitute building. Production binding/state methods run.
	enc.set_process(false)
	enc.set_physics_process(false)
	var f02 := Node3D.new()
	f02.name = "F02"
	owned.add_child(f02)
	var f04 := Node3D.new()
	f04.name = "F04"
	f04.position.y = 8.0
	owned.add_child(f04)
	var field2 = _field(0.0, 2)
	var field4 = _field(8.0, 4)
	enc.fields = {"F02": field2, "F04": field4}
	enc.units = {
		MINA: {"rect": Vector4(-2, -2, 2, 2), "floor_y": 0.0, "floor_node": f02},
		PETER: {"rect": Vector4(-2, -2, 2, 2), "floor_y": 8.0, "floor_node": f04},
	}
	enc._forced = {MINA: 0.2, PETER: 0.0}
	var standard := _standard()
	var surface = SurfaceScript.new()
	var cached := SurfaceScript.surface_for(standard, {"uv_mode": 1}, "fixture_override", surface._cache)
	var hall_a := _mesh(f02, "HallA", Vector3(4, 0.5, 0), cached)
	var hall_b := _mesh(f02, "HallB", Vector3(5, 0.5, 0), cached)
	var hall4 := _mesh(f04, "Hall4", Vector3(4, 0.5, 0), cached)
	var shared_owned := _layered()
	shared_owned.set_meta("living_storey", "F02")
	var same_a := _mesh(f02, "SameA", Vector3(4, 0.5, 1), shared_owned)
	var same_b := _mesh(f02, "SameB", Vector3(5, 0.5, 1), shared_owned)
	var cached_surface := SurfaceScript.surface_for(standard, {"uv_mode": 0}, "fixture_surface", surface._cache)
	var finish2 := _mesh(f02, "Surface2", Vector3(6, 0.5, 0), null)
	finish2.set_surface_override_material(0, cached_surface)
	var finish4 := _mesh(f04, "Surface4", Vector3(6, 0.5, 0), null)
	finish4.set_surface_override_material(0, cached_surface)
	var foreign := _layered()
	foreign.set_meta("living_storey", "F04")
	foreign.set_shader_parameter("living_origin", field4.origin)
	var foreign_draw := _mesh(f02, "ForeignOwner", Vector3(6, 0.5, 1), foreign)
	var hidden_surface := _layered()
	var opaque_override := StandardMaterial3D.new()
	var overridden := _mesh(f02, "HiddenSurface", Vector3(7, 0.5, 1), opaque_override)
	overridden.set_surface_override_material(0, hidden_surface)
	var private_world := SubViewport.new()
	private_world.name = "CabinetWorld"
	private_world.own_world_3d = true
	private_world.size = Vector2i(32, 32)
	f02.add_child(private_world)
	var private_material := _layered()
	var private_draw := _mesh(private_world, "CabinetMesh", Vector3(0, 0.5, 0), private_material)
	var resident := Node3D.new()
	resident.name = "ResidentBranch"
	resident.add_to_group("resident_placeholders")
	f02.add_child(resident)
	var resident_material := _layered()
	var resident_draw := _mesh(resident, "ResidentMesh", Vector3(0, 0.5, 0), resident_material)
	var player := CharacterBody3D.new()
	f02.add_child(player)
	var player_material := _layered()
	var player_draw := _mesh(player, "PlayerMesh", Vector3(0, 0.5, 0), player_material)
	enc._bind_storey(f02, "F02", field2)
	enc._bind_storey(f04, "F04", field4)
	_check("initial registration is nonempty and unique", _unique("F02") and enc.storey_materials.F02.size() > 0)
	_check("same installed material on two draws registers once", same_a.material_override == same_b.material_override
			and _occurrences("F02", shared_owned) == 1)
	_check("same cached full override reuses a floor copy", hall_a.material_override == hall_b.material_override)
	_check("full override cache source remains unbound", not cached.has_meta("living_storey")
			and not bool(cached.get_shader_parameter("has_living")))
	_check("different storeys have different installed full overrides", hall_a.material_override != hall4.material_override)
	_check("foreign storey full override is copied, not rebound", foreign_draw.material_override != foreign
			and foreign.get_meta("living_storey") == "F04"
			and foreign.get_shader_parameter("living_origin") == field4.origin)
	_check("surface cache first-owner reference remains live", finish2.get_surface_override_material(0) == cached_surface)
	_check("foreign storey surface copy is separate", finish2.get_surface_override_material(0) != finish4.get_surface_override_material(0))
	_check("both storeys sample their own field", _bound_to(hall_a.material_override, field2)
			and _bound_to(hall4.material_override, field4)
			and _bound_to(finish4.get_surface_override_material(0), field4))
	_check("inactive surface beneath a full override is not registered", not bool(hidden_surface.get_shader_parameter("has_living"))
			and not enc.storey_materials.F02.has(hidden_surface))
	_check("storey scan excludes cabinet world", private_draw.material_override == private_material
			and not bool(private_material.get_shader_parameter("has_living")))
	_check("storey scan excludes residents and player", resident_draw.material_override == resident_material
			and player_draw.material_override == player_material
			and not bool(resident_material.get_shader_parameter("has_living")))
	var initial_ids := _ids("F02")
	var live_registry: Array = enc.storey_materials.F02
	for _i in 12:
		enc._bind_storey(f02, "F02", field2)
	_check("twelve repeated storey sweeps preserve unique exact registry", _unique("F02") and _ids("F02") == initial_ids)
	var late_hall := _mesh(f02, "LateHall", Vector3(7, 0.5, 0), cached)
	enc._bind_storey(f02, "F02", field2)
	_check("late draw reuses the existing non-case floor copy", late_hall.material_override == hall_a.material_override
			and _ids("F02") == initial_ids)
	var mechanism := FunctionalScript.new()
	mechanism.name = "FunctionalCaseProp"
	f02.add_child(mechanism)
	var case_draw := _mesh(mechanism, "CaseProp", Vector3(0, 0.5, 0), standard)
	var root_draw := _mesh(owned, "RootCaseProp", Vector3(1, 0.5, 0), standard)
	var case4 := _mesh(f04, "OtherCaseProp", Vector3(0, 0.5, 0), standard)
	# A unique finish row follows the same ownership marker emitted by build.
	var case_finish := _layered()
	case_finish.set_meta("living_storey", "F02")
	var finish_draw := _mesh(f02, "Case_finish_quad", Vector3(0, 0.5, -1), null)
	finish_draw.set_surface_override_material(0, case_finish)
	enc.surfaces = {MINA: [{"mesh": finish_draw, "surface": 0, "material": case_finish}]}
	surface.on_props_applied = _on_props_applied
	surface._props_root = owned
	# Execute the real queued tier-on path and its real callback. No fake
	# result rows or alternate material owner stand in for SurfacePass.
	surface._queue_apply_props(owned)
	surface._drain_lever()
	_check("real tier queue invokes one reach callback", callbacks == 1 and surface._lever_queue.is_empty())
	_check("case rows include floor and root-level draws only", enc.prop_rows[MINA].size() == 2
			and enc.prop_rows[PETER].size() == 1)
	_check("first reach retains exact installed floor prop row", _row_is_live(MINA, case_draw))
	_check("first reach retains exact installed root prop row", _row_is_live(MINA, root_draw))
	_check("first reach retains exact installed finish row", finish_draw.get_surface_override_material(0) == case_finish
			and enc.surfaces[MINA][0].material == case_finish)
	_check("root-level case draw remains in the floor registry", _occurrences("F02", root_draw.material_override) == 1)
	_check("existing array consumers observe current registry", live_registry.size() == enc.storey_materials.F02.size()
			and live_registry.has(root_draw.material_override))
	_check("global reach still excludes private and dynamic draws", private_draw.material_override == private_material
			and resident_draw.material_override == resident_material and player_draw.material_override == player_material)
	# Change the value after first binding; observing its existing value
	# would falsely pass if the refresh row points to a detached old copy.
	enc._forced[MINA] = 0.8
	enc.refresh()
	_check("first refresh immediately reaches installed floor prop", _has_state(case_draw, 0.8))
	_check("first refresh immediately reaches installed root prop", _has_state(root_draw, 0.8))
	_check("finish refresh reaches installed case material", is_equal_approx(float(case_finish.get_shader_parameter("intensity")), 0.8))
	_check("neighbor case intensity remains zero", _has_state(case4, 0.0))
	(case_draw.material_override as ShaderMaterial).set_shader_parameter("living_lifecycle_stage", -77.0)
	(root_draw.material_override as ShaderMaterial).set_shader_parameter("living_lifecycle_stage", -77.0)
	enc._push_living_lifecycle("F02", field2)
	_check("lifecycle immediately reaches both installed prop owners", _has_lifecycle(case_draw, field2)
			and _has_lifecycle(root_draw, field2))
	var stable_ids := _ids("F02")
	var stable_material := case_draw.material_override
	for _i in 8:
		enc.reach_props(owned)
	_check("repeated reach preserves registry and installed identity", _unique("F02") and _ids("F02") == stable_ids
			and case_draw.material_override == stable_material and _row_is_live(MINA, case_draw))
	var late_case := _mesh(owned, "LateCaseProp", Vector3(-1, 0.5, 0), standard)
	surface._queue_apply_props(owned)
	surface._drain_lever()
	_check("late case prop gets an immediate live row and state", _row_is_live(MINA, late_case) and _has_state(late_case, 0.8)
			and _occurrences("F02", late_case.material_override) == 1)
	var replaced := case_draw.material_override
	var steady_count: int = enc.storey_materials.F02.size()
	var cache_count: int = surface._cache.size()
	var governed_ok := true
	for _cycle in 4:
		surface.budget = 0.0
		surface._over_streak = 2
		surface._govern_clock = 0.0
		surface.govern(SurfaceScript.GOVERN_INTERVAL, 30.0)
		surface._drain_lever()
		governed_ok = governed_ok and case_draw.material_override == standard and not surface.props_tier_on
		surface.budget = 1.0
		surface._under_streak = 5
		surface._govern_clock = 0.0
		surface.govern(SurfaceScript.GOVERN_INTERVAL, 1.0)
		surface._drain_lever()
		governed_ok = governed_ok and surface.props_tier_on and _row_is_live(MINA, case_draw)
		governed_ok = governed_ok and _has_state(case_draw, 0.8) and _unique("F02")
		governed_ok = governed_ok and enc.storey_materials.F02.size() == steady_count
	_check("four real governor off/on cycles preserve live ownership and bound registry", governed_ok)
	_check("replaced material no longer receives floor updates", not enc.storey_materials.F02.has(replaced)
			and case_draw.material_override != replaced)
	_check("SurfacePass cache cardinality remains stable", surface._cache.size() == cache_count)
	var detached_material := late_case.material_override
	owned.remove_child(late_case)
	late_case.free()
	enc.reach_props(owned)
	_check("retired root prop is removed from registry and case rows", not enc.storey_materials.F02.has(detached_material)
			and enc.prop_rows[MINA].size() == 2)
	var before_rebind := _ids("F02")
	var replacement_field = _field(0.0, 22)
	enc.fields.F02 = replacement_field
	enc._bind_storey(f02, "F02", replacement_field)
	_check("field rebind keeps material identities while updating textures", _ids("F02") == before_rebind
			and _bound_to(case_draw.material_override, replacement_field)
			and _bound_to(root_draw.material_override, replacement_field))
	_check("field rebind leaves neighbor field intact", _bound_to(hall4.material_override, field4)
			and _bound_to(case4.material_override, field4))
	_check("registration remains presentation-only", not RealityState.data.has("encroachment"))
	surface.on_props_applied = Callable()
	surface._prop_swaps.clear()
	surface._lever_queue.clear()
	owned.free()
	owned = null
	enc = null
	# Returning releases this function's material/field locals before teardown.
	call_deferred("_finish")


func _on_props_applied() -> void:
	callbacks += 1
	enc.reach_props(owned)


func _field(y: float, seed_value: int):
	var field = LivingScript.new()
	field.configure(Vector4(-8, -2, 8, 2), y, seed_value)
	return field


func _standard() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.3, 0.2))
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_triplanar = true
	return material


func _layered() -> ShaderMaterial:
	return SurfaceScript.surface_for(_standard(), {"uv_mode": 1})


func _mesh(parent: Node, label: String, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = BoxMesh.new()
	mesh.position = at
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func _ids(floor_id: String) -> Array:
	var ids: Array = []
	for material in enc.storey_materials.get(floor_id, []):
		ids.append(material.get_instance_id())
	ids.sort()
	return ids


func _unique(floor_id: String) -> bool:
	var seen: Dictionary = {}
	for material in enc.storey_materials.get(floor_id, []):
		if material == null or seen.has(material):
			return false
		seen[material] = true
	return true


func _occurrences(floor_id: String, material: Material) -> int:
	return (enc.storey_materials.get(floor_id, []) as Array).count(material)


func _bound_to(material: Material, field) -> bool:
	var layered := material as ShaderMaterial
	return layered != null and layered.get_shader_parameter("living_tex") == field.texture() \
			and layered.get_shader_parameter("living_origin") == field.origin


func _row_is_live(case_id: String, draw: MeshInstance3D) -> bool:
	for row in enc.prop_rows.get(case_id, []):
		if row.mesh == draw:
			return row.material == draw.material_override
	return false


func _has_state(draw: MeshInstance3D, intensity: float) -> bool:
	var material := draw.material_override as ShaderMaterial
	if material == null:
		return false
	var amount: Vector4 = material.get_shader_parameter("mask_amount")
	return amount.is_equal_approx(Vector4(0.0, 0.35 * intensity, 0.25 * intensity, 0.0))


func _has_lifecycle(draw: MeshInstance3D, field) -> bool:
	return is_equal_approx(float((draw.material_override as ShaderMaterial).get_shader_parameter("living_lifecycle_stage")),
			float(field.lifecycle_stage()))


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[BIND PASS] " + label)
	else:
		failures += 1
		printerr("[BIND FAIL] " + label)


func _finish() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("APARTMENT MATERIAL BINDING: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
