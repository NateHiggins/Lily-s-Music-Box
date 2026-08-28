class_name DreamSurfaceHeroPresenter
extends Node3D
## Presentation-only bridge for the accepted S2 hero meshes. It reads the
## existing cellular packet and owns only LOD visibility and cargo interpolation.

enum HeroKind { PLASMODIUM, TRANSPORT, INTERIOR }

const PATHS := {
	HeroKind.PLASMODIUM: [
		"res://art/dream/surface_hero/plasmodial_tissue_lod0.glb",
		"res://art/dream/surface_hero/plasmodial_tissue_lod1.glb",
		"res://art/dream/surface_hero/plasmodial_tissue_lod2.glb"],
	HeroKind.TRANSPORT: [
		"res://art/dream/surface_hero/transmembrane_complex_lod0.glb",
		"res://art/dream/surface_hero/transmembrane_complex_lod1.glb",
		"res://art/dream/surface_hero/transmembrane_complex_lod2.glb",
		"res://art/dream/surface_hero/transmembrane_complex_lod3.glb"],
	HeroKind.INTERIOR: [
		"res://art/dream/surface_hero/cellular_interior_lod0.glb",
		"res://art/dream/surface_hero/cellular_interior_lod1.glb",
		"res://art/dream/surface_hero/cellular_interior_lod2.glb"]}
const PLASMODIUM_MATERIAL := preload("res://materials/dream_surface_plasmodium.tres")
const MEMBRANE_MATERIAL := preload("res://materials/dream_surface_membrane.tres")
const PROTEIN_MATERIAL := preload("res://materials/dream_surface_protein.tres")
const CARGO_MATERIAL := preload("res://materials/dream_surface_cargo.tres")
const INTERNAL_MATERIAL := preload("res://materials/dream_surface_internal.tres")

var kind := HeroKind.PLASMODIUM
var state_source: Node = null
var lod_roots: Array[Node3D] = []
var lod_triangles: Array[int] = []
var cargo_nodes: Array[MeshInstance3D] = []
var cargo_origins: Array[Vector3] = []
var presentation_usec := 0
var _clock := 0.0
var _active_lod := 0
var _forced_lod := -1
var _examination_mode := false
var _lod_meshes: Array[Array] = []
var _last_presentation_state := Vector4(-99.0, -99.0, -99.0, -99.0)
var _last_examination_mode := false
var _shader_clock := 0.0
const LOD_HYSTERESIS := 0.65
const SHADER_UPDATE_INTERVAL := 1.0 / 15.0


func setup(hero_kind: int, existing_state_source: Node = null) -> void:
	kind = hero_kind
	state_source = existing_state_source
	var t0 := Time.get_ticks_usec()
	for i in (PATHS[kind] as Array).size():
		var packed := load(PATHS[kind][i]) as PackedScene
		var root := packed.instantiate() as Node3D
		root.name = "LOD%d" % i
		add_child(root)
		lod_roots.append(root)
		_configure_lod(root, i)
		root.visible = i == 0
	presentation_usec = Time.get_ticks_usec() - t0
	if kind == HeroKind.TRANSPORT:
		_cache_cargo()


func _configure_lod(root: Node3D, index: int) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	meshes.sort_custom(func(a, b): return _mesh_volume(a) > _mesh_volume(b))
	_lod_meshes.append(meshes)
	var triangles := 0
	for mesh_instance in meshes:
		triangles += _triangle_count(mesh_instance.mesh)
		_assign_role_material(mesh_instance, meshes.find(mesh_instance))
	lod_triangles.append(triangles)


func _lod_ranges() -> Array[Vector2]:
	if kind == HeroKind.TRANSPORT:
		return [Vector2(0, 4.5), Vector2(3.7, 10.0), Vector2(9.2, 19.0), Vector2(18.2, 55.0)]
	return [Vector2(0, 6.0), Vector2(5.2, 15.0), Vector2(14.2, 55.0)]


func _assign_role_material(mesh_instance: MeshInstance3D, rank: int) -> void:
	match kind:
		HeroKind.PLASMODIUM:
			mesh_instance.material_override = PLASMODIUM_MATERIAL
		HeroKind.TRANSPORT:
			mesh_instance.material_override = MEMBRANE_MATERIAL if rank == 0 else (PROTEIN_MATERIAL if rank == 1 else CARGO_MATERIAL)
		HeroKind.INTERIOR:
			mesh_instance.material_override = MEMBRANE_MATERIAL if rank == 0 else (PROTEIN_MATERIAL if rank == 1 else INTERNAL_MATERIAL)


func _process(delta: float) -> void:
	_clock += delta
	_shader_clock += delta
	_update_lod()
	var state := Vector4(.55, .45, .60, 0.0)
	var packet = state_source.get("_state_packet") if state_source != null else null
	if packet != null:
		state = packet.to_vector_a()
	var state_changed := not state.is_equal_approx(_last_presentation_state)
	var mode_changed := _examination_mode != _last_examination_mode
	var update_time := _shader_clock >= SHADER_UPDATE_INTERVAL
	if not state_changed and not mode_changed and not update_time and kind != HeroKind.TRANSPORT:
		return
	var t0 := Time.get_ticks_usec()
	for mesh_instance in _lod_meshes[_active_lod]:
		if state_changed:
			mesh_instance.set_instance_shader_parameter("presentation_state", state)
		if update_time:
			mesh_instance.set_instance_shader_parameter("presentation_time", _clock)
		if mode_changed:
			mesh_instance.set_instance_shader_parameter("examination_mode", 1.0 if _examination_mode else 0.0)
		mesh_instance.set_instance_shader_parameter("low_lod_response", float(_active_lod) / float(maxi(lod_roots.size() - 1, 1)))
	_last_presentation_state = state
	_last_examination_mode = _examination_mode
	if update_time:
		_shader_clock = 0.0
	if kind == HeroKind.TRANSPORT:
		_animate_cargo(state)
	presentation_usec = Time.get_ticks_usec() - t0


func set_examination_mode(enabled: bool) -> void:
	_examination_mode = enabled


func force_lod(index: int) -> void:
	_forced_lod = clampi(index, -1, lod_roots.size() - 1)
	if _forced_lod >= 0:
		_set_active_lod(_forced_lod)


func active_lod() -> int:
	return _active_lod


func _update_lod() -> void:
	if _forced_lod >= 0:
		_set_active_lod(_forced_lod)
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var distance := global_position.distance_to(camera.global_position)
	var thresholds := _lod_thresholds()
	while _active_lod < thresholds.size() and distance > thresholds[_active_lod] + LOD_HYSTERESIS:
		_set_active_lod(_active_lod + 1)
	while _active_lod > 0 and distance < thresholds[_active_lod - 1] - LOD_HYSTERESIS:
		_set_active_lod(_active_lod - 1)


func _set_active_lod(index: int) -> void:
	_active_lod = clampi(index, 0, lod_roots.size() - 1)
	for i in lod_roots.size():
		lod_roots[i].visible = i == _active_lod


func _lod_thresholds() -> Array:
	return [4.5, 10.0, 19.0] if kind == HeroKind.TRANSPORT else [6.0, 15.0]


func _cache_cargo() -> void:
	for meshes in _lod_meshes:
		meshes.sort_custom(func(a, b): return _mesh_volume(a) < _mesh_volume(b))
		for i in mini(4, meshes.size()):
			cargo_nodes.append(meshes[i])
			cargo_origins.append(meshes[i].position)


func _animate_cargo(state: Vector4) -> void:
	var activity := clampf(.20 + state.x * .55 + state.y * .25, .0, 1.0)
	for i in cargo_nodes.size():
		var phase := _clock * (.28 + activity * .42) + float(i % 4) * .73
		cargo_nodes[i].position = cargo_origins[i] + Vector3(0, sin(phase) * .008, cos(phase) * .006)
		cargo_nodes[i].scale = Vector3.ONE * (1.0 + sin(phase * 1.7) * .025)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _mesh_volume(mesh_instance: MeshInstance3D) -> float:
	return mesh_instance.mesh.get_aabb().size.x * mesh_instance.mesh.get_aabb().size.y * mesh_instance.mesh.get_aabb().size.z


func _triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		total += indices.size() / 3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func census() -> Dictionary:
	var mesh_instances := 0
	for root in lod_roots:
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(root, meshes)
		mesh_instances += meshes.size()
	var shared_materials := 1 if kind == HeroKind.PLASMODIUM else (3 if kind == HeroKind.TRANSPORT else 4)
	return {"kind": kind, "lod_triangles": lod_triangles.duplicate(),
		"lod_instances": lod_roots.size(), "mesh_instances": mesh_instances,
		"materials_shared": shared_materials,
		"presentation_cpu_ms": float(presentation_usec) / 1000.0,
		"owns_ecology": false, "per_frame_mesh_builds": 0,
		"lod_mode": "exclusive_hysteresis", "lod_hysteresis": LOD_HYSTERESIS,
		"lod_thresholds": _lod_thresholds(), "active_lod": _active_lod,
		"cargo_nodes": cargo_nodes.size(), "examination_mode": _examination_mode}
