extends Node
## Geometry residency follows named interior spaces. Physical actors retain
## identity while dormant; imported geometry and transaction surfaces retire.

var region
var player: PlayerController
var frame: Node3D
var _dormant_box: AABB
var _prefetch_box: AABB
var state := "RESIDENT"
var _wanted := true
var _pending: Dictionary = {}
var _staging: Node3D
var _staged_cells: Dictionary = {}
var _staged_surface: RefCounted
var _retired: Array[WeakRef] = []
var _retired_meshes: Array[WeakRef] = []
var _guard: StaticBody3D
var load_cycles := 0
var unload_cycles := 0
var peak_stage_ms := 0.0
var peak_activation_ms := 0.0
var stage_records: Array[Dictionary] = []
var _stopped := false
var _material_statistics: Dictionary = {}
var _height_paths: Dictionary = {}
var _height_pending: Dictionary = {}
var _height_resources: Array[Resource] = []

func configure(owner_region: Node3D, owner_player: PlayerController,
		owner_frame: Node3D, layout: Dictionary) -> bool:
	region = owner_region
	player = owner_player
	frame = owner_frame
	var boxes := {}
	for identity in ["F01_PUBLIC_CORE", "F01_VESTIBULE"]:
		var matches: Array[Dictionary] = []
		for record: Dictionary in layout.get("spaces", []):
			if record.id == identity and record.level == "F01": matches.append(record)
		if matches.size() != 1: return false
		var rect: Array = matches[0].rect
		boxes[identity] = AABB(Vector3(float(rect[0])+0.25, -0.1, float(rect[1])+0.25),
			Vector3(float(rect[2])-float(rect[0])-0.5, 3.1, float(rect[3])-float(rect[1])-0.5))
	_dormant_box = boxes.F01_PUBLIC_CORE
	_prefetch_box = boxes.F01_VESTIBULE
	for identity: String in region.CELLS:
		var cell: Node3D = region.cell_nodes[identity]
		for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
			for surface_index in draw.mesh.get_surface_count():
				var original := draw.mesh.surface_get_material(surface_index) as BaseMaterial3D
				var layered := draw.get_surface_override_material(surface_index) as ShaderMaterial
				if original == null or layered == null: continue
				var key: String = region.Surface.texture_source_key(original)
				if key.is_empty(): continue
				_material_statistics[key] = {"albedo_mean": layered.get_shader_parameter("albedo_mean"),
					"rough_mean": layered.get_shader_parameter("rough_mean")}
				var height_texture := layered.get_shader_parameter("height_tex") as Texture2D
				if height_texture != null and not height_texture.resource_path.is_empty():
					_height_paths[height_texture.resource_path] = true
	return player != null and frame != null

func _ready() -> void:
	name = "PassageResidency"
	# The gate keeps an incomplete load physically closed. Normal prefetch
	# begins inside the vestibule, well before the street crossing.
	var section: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/street_section_source.json"))
	_guard = StaticBody3D.new()
	_guard.name = "PassageLoadingBarrier"
	_guard.position = region.to_local(Vector3(14, 1.05, float(section.arcade_building_line_z)-0.3))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 2.1, 0.12)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	_guard.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	visual.material_override = MatLib.get_mat("oak_quartered")
	_guard.add_child(visual)
	region.add_child(_guard)
	_gate(false)

func _physics_process(_delta: float) -> void:
	if _stopped or not is_instance_valid(player): return
	var local := frame.to_local(player.global_position)
	if _dormant_box.has_point(local):
		_wanted = false
	elif _prefetch_box.has_point(local) or player.global_position.z > 0.0:
		_wanted = true

func _process(_delta: float) -> void:
	if _stopped or not is_instance_valid(player): return
	if state == "RESIDENT" and not _wanted:
		_retired_meshes.clear()
		for identity: String in region.CELLS:
			var cell: Node3D = region.cell_nodes[identity]
			for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
				_retired_meshes.append(weakref(draw.mesh))
		_retired.append(region.suspend_geometry())
		if _retired.size() > 8: _retired.pop_front()
		unload_cycles += 1
		state = "DORMANT"
		_gate(true)
	if state == "DORMANT" and _wanted:
		_begin_load()
	if state == "LOADING":
		_stage_one()

func _begin_load() -> void:
	_staging = Node3D.new()
	_staged_cells.clear()
	_staged_surface = region.Surface.new()
	_staged_surface.texture_statistics = _material_statistics
	for path: String in _height_paths:
		if ResourceLoader.load_threaded_request(path, "Texture2D") != OK:
			_fail("threaded material dependency request failed: " + path)
			return
		_height_pending[path] = true
	for identity: String in region.CELLS:
		var path: String = region.cell_path(identity)
		var error := ResourceLoader.load_threaded_request(path, "PackedScene")
		if error != OK:
			_fail("threaded cell request failed: " + identity)
			return
		_pending[identity] = path
	state = "LOADING"

func _stage_one() -> void:
	# SurfacePass adds calibrated height maps after glTF import. Prefetch
	# those dependencies too, so material setup cannot synchronously read them.
	for path: String in _height_pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("threaded material dependency failed: " + path)
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(path) as Resource
			if resource == null:
				_fail("empty material dependency: " + path)
				return
			_height_resources.append(resource)
			_height_pending.erase(path)
	if not _height_pending.is_empty(): return
	for identity: String in _pending.keys():
		var path: String = _pending[identity]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("threaded cell load failed: " + identity)
			return
		if status != ResourceLoader.THREAD_LOAD_LOADED: continue
		var started := Time.get_ticks_usec()
		var packed := ResourceLoader.load_threaded_get(path) as PackedScene
		var fetched := Time.get_ticks_usec()
		_pending.erase(identity)
		if packed == null:
			_fail("threaded result is not a PackedScene: " + identity)
			return
		var cell := packed.instantiate() as Node3D
		var instantiated := Time.get_ticks_usec()
		if cell == null:
			_fail("threaded cell is not spatial: " + identity)
			return
		cell.name = identity
		_staging.add_child(cell)
		_staged_cells[identity] = cell
		_staged_surface.apply({identity: cell})
		var finished := Time.get_ticks_usec()
		peak_stage_ms = maxf(peak_stage_ms, float(finished-started)/1000.0)
		stage_records.append({"cell": identity, "fetch_ms": float(fetched-started)/1000.0,
			"instantiate_ms": float(instantiated-fetched)/1000.0,
			"surface_ms": float(finished-instantiated)/1000.0})
		if stage_records.size() > 36: stage_records.pop_front()
		break
	if not _pending.is_empty(): return
	if not _wanted:
		_staging.free()
		_staging = null
		_staged_cells.clear()
		_staged_surface = null
		_height_resources.clear()
		state = "DORMANT"
		return
	var activation_start := Time.get_ticks_usec()
	region.activate_geometry(_staging, _staged_cells, _staged_surface)
	peak_activation_ms = maxf(peak_activation_ms, float(Time.get_ticks_usec()-activation_start)/1000.0)
	_staging = null
	_staged_cells = {}
	_staged_surface = null
	_height_resources.clear()
	if region.startup_failed:
		state = "FAILED"
		_gate(true)
		return
	load_cycles += 1
	state = "RESIDENT"
	_gate(false)

func snapshot() -> Dictionary:
	var retained_roots := 0
	var retained_meshes := 0
	for reference: WeakRef in _retired:
		if reference.get_ref() != null: retained_roots += 1
	for reference: WeakRef in _retired_meshes:
		if reference.get_ref() != null: retained_meshes += 1
	return {"state": state, "pending_requests": _pending.size()+_height_pending.size(), "load_cycles": load_cycles,
		"unload_cycles": unload_cycles, "retired_geometry_roots_alive": retained_roots,
		"retired_mesh_resources_alive": retained_meshes, "peak_stage_ms": peak_stage_ms,
		"peak_activation_ms": peak_activation_ms, "stage_records": stage_records.duplicate(true),
		"physical_actors_retained": true, "cell_count": region.cell_nodes.size()}

func shutdown() -> void:
	if _stopped: return
	_stopped = true
	# Godot has no cancellation API for these requests. Drain each issued
	# result on teardown so an abandoned world cannot retain a load handle.
	for path: String in _pending.values():
		ResourceLoader.load_threaded_get(path)
	for path: String in _height_pending:
		ResourceLoader.load_threaded_get(path)
	_pending.clear()
	_height_pending.clear()
	_height_resources.clear()
	_height_paths.clear()
	if is_instance_valid(_staging): _staging.free()
	_staging = null
	_staged_cells.clear()
	_staged_surface = null
	_material_statistics.clear()
	_retired.clear()
	_retired_meshes.clear()
	player = null
	frame = null

func _exit_tree() -> void:
	shutdown()

func _gate(closed: bool) -> void:
	_guard.visible = closed
	_guard.process_mode = Node.PROCESS_MODE_INHERIT if closed else Node.PROCESS_MODE_DISABLED

func _fail(reason: String) -> void:
	state = "FAILED"
	region._fail(reason)
