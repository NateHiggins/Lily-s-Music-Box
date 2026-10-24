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
var _native_paths: Array[String] = []
var _native_pending: Dictionary = {}
var _native_resources: Array[Resource] = []
var _collision_shapes: Dictionary = {}
var _collision_cache := preload("res://scripts/building/orison_v2_fitting_collision_cache.gd").new()
# Bound fitting between frames and yield between validated native parts.
# Single mesh/renderer calls can still exceed this cooperative budget.
var cooperative_fitting := true
var _fit_job: RefCounted
const FIT_BUDGET_USEC := 3000
var _fit_operations: Array = []
var _fit_identity := ""
var _fit_fetch_ms := 0.0
var _fit_instantiate_ms := 0.0
var _fit_work_ms := 0.0
var fit_records: Array[Dictionary] = []

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
	_native_paths = preload("res://scripts/building/orison_v2_shop_seating.gd").fitting_assets(region.CELLS)
	if not _collision_cache.seed(region.cell_nodes): _collision_cache.dispose()
	return not _native_paths.is_empty() and player != null and frame != null and region.get_parent() is Node3D

func _ready() -> void:
	name = "PassageResidency"
	# The gate keeps an incomplete load physically closed. Normal prefetch
	# begins inside the vestibule, well before the street crossing.
	var section := preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
	if section.is_empty():
		_stopped = true
		push_error("Invalid street coordinate frame")
		return
	_guard = StaticBody3D.new()
	_guard.name = "PassageLoadingBarrier"
	# Street section coordinates belong to the common front-door parent;
	# the Passage has its own offset for the retained source geometry.
	var section_frame := region.get_parent() as Node3D
	_guard.position = region.to_local(section_frame.to_global(
			Vector3(14, 1.05, float(section.arcade_building_line_z)-0.3)))
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
	_update_wanted(player.global_position)

func _update_wanted(world_position: Vector3) -> void:
	# A focused programme owns its board even if another camera moves. Retiring
	# its parent would suspend gameplay under the panel's hands.
	if region.receiving_row != null and region.receiving_row.has_focused_panel():
		_wanted = true
		return
	var local := frame.to_local(world_position)
	var section_frame := region.get_parent() as Node3D
	if _dormant_box.has_point(local):
		_wanted = false
	elif _prefetch_box.has_point(local) or section_frame.to_local(world_position).z > 0.0:
		_wanted = true

func _process(_delta: float) -> void:
	if _stopped or not is_instance_valid(player): return
	var stock_wants: bool=region.geometry_required_by_stock()
	if state == "RESIDENT" and not _wanted and not stock_wants:
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
	if state == "DORMANT" and (_wanted or stock_wants):
		_begin_load()
	if state == "LOADING":
		_stage_one()

func _begin_load() -> void:
	_staging = Node3D.new()
	_staged_cells.clear()
	_staged_surface = region.Surface.new()
	_staged_surface.texture_statistics = _material_statistics
	_collision_shapes=_collision_cache.shapes.duplicate()

	for path: String in _native_paths:
		if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
			_fail("threaded native fitting request failed: " + path)
			return
		_native_pending[path] = true
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
	if not _fit_operations.is_empty():
		_advance_fit()
		return
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
	for path: String in _native_pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail("threaded native fitting failed: " + path)
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource := ResourceLoader.load_threaded_get(path) as Resource
			if resource == null:
				_fail("empty native fitting: " + path)
				return
			_native_resources.append(resource)
			_native_pending.erase(path)
	if not _height_pending.is_empty() or not _native_pending.is_empty(): return
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
		cell.set_meta("native_collision_paths",_collision_cache.paths)
		cell.set_meta("native_collision_shapes",_collision_shapes)
		_staging.add_child(cell)
		_staged_cells[identity] = cell
		_fit_identity = identity
		_fit_fetch_ms = float(fetched-started)/1000.0
		_fit_instantiate_ms = float(instantiated-fetched)/1000.0
		_fit_work_ms = 0.0
		_fit_operations = [
			["standard wall millwork reload refused: "+identity, func(): return preload("res://scripts/building/orison_v2_shop_millwork.gd").mount_cell(cell,region.source_layout)],
			["native seating reload fit refused: "+identity, func(): return region.Seating.mount_cell(cell,region.source_layout)],
			["native laundry reload fit refused: "+identity, func(): return region.Laundry.mount_cell(cell,region.source_layout)],
			["native laundry apparatus reload fit refused: "+identity, func(): return region.LaundryApparatus.mount_cell(cell,region.source_layout)],
			["native laundry trade furniture reload fit refused: "+identity, func(): return region.LaundryTrade.mount_cell(cell,region.source_layout)],
			["native borrowed-light reload fit refused: "+identity, func(): return region.ShopClerestories.mount_cell(cell,region.source_layout)],
			["native closed shop joinery reload fit refused: "+identity, func(): return region.ShopJoinery.mount_cell(cell,region.source_layout)],
			["native Photo/Radio reload fit refused: "+identity, func(): return region.PhotoRadioFittings.mount_cell(cell,region.source_layout)],
			["native locksmith reload fit refused: "+identity, func(): return region.LocksmithFittings.mount_cell(cell,region.source_layout)],
			["native cobbler reload fit refused: "+identity, func(): return region.CobblerFittings.mount_cell(cell,region.source_layout)],
			["native news reload fit refused: "+identity, func(): return region.NewsFittings.mount_cell(cell,region.source_layout)],
			["native hardware drawer reload fit refused: "+identity, func(): return region.HardwareDrawers.mount_cell(cell,region.source_layout), "hardware_drawers"],
			["native hardware apparatus reload fit refused: "+identity, func(): return region.HardwareApparatus.mount_cell(cell,region.source_layout)],
			["native hardware stock reload fit refused: "+identity, func(): return region.HardwareStock.mount_cell(cell,region.source_layout), "hardware_stock"],
			["native hardware tools reload fit refused: "+identity, func(): return region.HardwareTools.mount_cell(cell,region.source_layout)],
			["native photography display reload fit refused: "+identity, func(): return region.PhotoCameras.mount_cell(cell,region.source_layout)],
			["native Diner counter reload fit refused: "+identity, func(): return region.DinerCounter.mount_cell(cell,region.source_layout)],
			["native Diner register/display reload fit refused: "+identity, func(): return region.DinerTill.mount_cell(cell,region.source_layout)],
			["native Diner rear bench/shelves reload fit refused: "+identity, func(): return region.DinerBackbar.mount_cell(cell,region.source_layout)],
			["native Diner urns/pie display reload fit refused: "+identity, func(): return region.DinerUrns.mount_cell(cell,region.source_layout)],
			["native Diner apparatus/pie display reload fit refused: "+identity, func(): return region.DinerApparatus.mount_cell(cell,region.source_layout)],
			["native Diner overhead/pie display reload fit refused: "+identity, func(): return region.DinerOverhead.mount_cell(cell,region.source_layout)],
			["native photography counter reload fit refused: "+identity, func(): return region.PhotoCounter.mount_cell(cell,region.source_layout)],
			["native photography supply shelving reload fit refused: "+identity, func(): return region.PhotoStock.mount_cell(cell,region.source_layout)],
			["native photography enlarger reload fit refused: "+identity, func(): return region.PhotoEnlargers.mount_cell(cell,region.source_layout)],
			["native photography process reload fit refused: "+identity, func(): return region.PhotoProcess.mount_cell(cell,region.source_layout)],
			["native unclaimed portrait reload fit refused: "+identity, func(): return region.PhotoPortraits.mount_cell(cell,region.source_layout)],
			["native fixed photographic glazing reload refused: "+identity, func(): return region.PhotoGlazing.mount_cell(cell,region.source_layout)],
			["native druggist drawer/counter reload fit refused: "+identity, func(): return region.DruggistDrawers.mount_cell(cell,region.source_layout), "druggist_drawers"],
			["native druggist counter objects reload refused: "+identity, func(): return region.DruggistCounter.mount_cell(cell,region.source_layout)],
			["native druggist marble objects reload refused: "+identity, func(): return region.DruggistMortar.mount_cell(cell,region.source_layout)],
			["native composed dispensary reload refused: "+identity, func(): return region.DruggistDispensary.mount_cell(cell,region.source_layout)],
			["native druggist cupboard reload refused: "+identity, func(): return region.DruggistCupboard.mount_cell(cell,region.source_layout)],
			["native druggist display carboys reload refused: "+identity, func(): return region.DruggistCarboys.mount_cell(cell,region.source_layout)],
			["native unused druggist fountain reload refused: "+identity, func(): return region.DruggistFountain.mount_cell(cell,region.source_layout)],
			["native funeral furniture reload refused: "+identity, func(): return region.FuneralFittings.mount_cell(cell,region.source_layout)],
			["native funeral drapery reload refused: "+identity, func(): return region.FuneralDrapes.mount_cell(cell,region.source_layout)],
			["native funeral foliage reload refused: "+identity, func(): return region.FuneralFoliage.mount_cell(cell,region.source_layout)],
			["native radio bench reload refused: "+identity, func(): return region.RadioBench.mount_cell(cell,region.source_layout)],
			["native radio apparatus reload refused: "+identity, func(): return region.RadioApparatus.mount_cell(cell,region.source_layout)],
			["native radio valve stock reload refused: "+identity, func(): return region.RadioStock.mount_cell(cell,region.source_layout)],
			["native radio charging display reload refused: "+identity, func(): return region.RadioBattery.mount_cell(cell,region.source_layout)],
			["native passive wire/ring stock reload refused: "+identity, func(): return region.RadioWire.mount_cell(cell,region.source_layout)],
			["native fitted counter/display reload refused: "+identity, func(): return region.RadioDisplay.mount_cell(cell,region.source_layout)],
			["native period receiving chassis reload refused: "+identity, func(): return region.RadioReceiving.mount_cell(cell,region.source_layout,region.cabinets_enabled)],
			["native Laundry receiving chassis reload refused: "+identity, func(): return region.LaundryReceiving.mount_cell(cell,region.source_layout,region.cabinets_enabled)],
			["native Photo Supplies receiving chassis reload refused: "+identity, func(): return region.PhotoReceiving.mount_cell(cell,region.source_layout,region.cabinets_enabled)],
			["native News Cigars receiving chassis reload refused: "+identity, func(): return region.NewsReceiving.mount_cell(cell,region.source_layout,region.cabinets_enabled)],
			["native Pawn Shop receiving chassis reload refused: "+identity, func(): return region.PawnReceiving.mount_cell(cell,region.source_layout,region.cabinets_enabled)],
			["native Pawn Shop display reload refused: "+identity, func(): return region.PawnDisplay.mount_cell(cell,region.source_layout)],
			["native Pawn Shop clocks reload refused: "+identity, func(): return region.PawnClocks.mount_cell(cell,region.source_layout)],
			["native Pawn Shop fittings reload refused: "+identity, func(): return region.PawnFittings.mount_cell(cell,region.source_layout)],
			["native Diner receiving pair reload refused: "+identity, func(): return region.DinerReceiving.mount_cell(cell,region.source_layout,region.cabinets_enabled)],
			["source-fitted arcade canopy reload refused: " + identity, func(): return region.ArcadeFabric.mount_canopy(cell, region.source_layout), "arcade_canopy"],
			["source-fitted arcade throat reload refused: " + identity, func(): return region.ArcadeFabric.mount_throat(cell, region.source_layout), "arcade_throat"],
			["source-fitted arcade lantern reload refused: " + identity, func(): return region.ArcadeFabric.mount_lantern(cell, region.source_layout)],
			["source-fitted arcade clock reload refused: " + identity, func(): return region.ArcadeFabric.mount_clock(cell, region.source_layout)],
			["source-fitted arcade retained finishes reload refused: " + identity, func(): return region.ArcadeFabric.mount_retained_finishes(cell, region.source_layout)],
			["owner finishes", func(): preload("res://scripts/building/orison_v2_owner_finishes.gd").new().apply_shop_cell(cell); return true],
			["material stock", func(): preload("res://scripts/building/v2_legacy_material_stock.gd").apply(cell); return true],
			["surface binding", func(): _staged_surface.apply({identity: cell}); return true],
		]
		return
	if not _pending.is_empty(): return
	if not _wanted and not region.geometry_required_by_stock():
		_staging.free()
		_staging = null
		_staged_cells.clear()
		_staged_surface = null
		_height_resources.clear()
		_native_resources.clear()
		_collision_shapes.clear()
		state = "DORMANT"
		return
	var activation_start := Time.get_ticks_usec()
	region.activate_geometry(_staging, _staged_cells, _staged_surface)
	peak_activation_ms = maxf(peak_activation_ms, float(Time.get_ticks_usec()-activation_start)/1000.0)
	_staging = null
	_staged_cells = {}
	_staged_surface = null
	_height_resources.clear()
	_native_resources.clear()
	_collision_shapes.clear()
	if region.startup_failed:
		state = "FAILED"
		_gate(true)
		return
	load_cycles += 1
	state = "RESIDENT"
	_gate(false)

func _advance_fit() -> void:
	var started := Time.get_ticks_usec()
	while not _fit_operations.is_empty():
		var operation: Array = _fit_operations[0]
		var before := Time.get_ticks_usec()
		var complete := true
		var ok := true
		var cell := _staged_cells[_fit_identity] as Node3D
		if cooperative_fitting and operation.size()==3:
			if _fit_job==null:
				_fit_job=region.Seating.begin_streamed_fitting(str(operation[2]),cell,region.source_layout)
			if _fit_job==null:
				ok=false
			else:
				_fit_job.advance(maxi(1,FIT_BUDGET_USEC-int(Time.get_ticks_usec()-started)))
				complete=_fit_job.done
				ok=not complete or _fit_job.ok
				if complete and ok:
					if not _fit_job.skipped:cell.set_meta("prepared_native_fit",_fit_job)
					ok=operation[1].call()
					# A wrapper must consume the token; an early return cannot leave one.
					if cell.has_meta("prepared_native_fit"):
						cell.remove_meta("prepared_native_fit")
						ok=false
		else:
			ok=operation[1].call()
		var elapsed := float(Time.get_ticks_usec()-before)/1000.0
		_fit_work_ms += elapsed
		if elapsed >= 1.0:
			fit_records.append({"cell":_fit_identity,"operation":operation[0],"ms":elapsed,"chunk":cooperative_fitting and operation.size()==3})
			if fit_records.size()>128: fit_records.pop_front()
		if not ok:
			if _fit_job!=null:_fit_job.cancel()
			_fit_job=null
			_fit_operations.clear()
			_fail(str(operation[0]))
			return
		if complete:
			_fit_operations.pop_front()
			_fit_job=null
		if not complete or Time.get_ticks_usec()-started >= FIT_BUDGET_USEC: break
	peak_stage_ms = maxf(peak_stage_ms,float(Time.get_ticks_usec()-started)/1000.0)
	if _fit_operations.is_empty():
		(_staged_cells[_fit_identity] as Node).remove_meta("native_collision_shapes")
		stage_records.append({"cell":_fit_identity,"fetch_ms":_fit_fetch_ms,
			"instantiate_ms":_fit_instantiate_ms,"surface_ms":_fit_work_ms})
		if stage_records.size()>36: stage_records.pop_front()

func snapshot() -> Dictionary:
	var retained_roots := 0
	var retained_meshes := 0
	for reference: WeakRef in _retired:
		if reference.get_ref() != null: retained_roots += 1
	for reference: WeakRef in _retired_meshes:
		if reference.get_ref() != null: retained_meshes += 1
	return {"state": state, "pending_requests": _pending.size()+_height_pending.size()+_native_pending.size(), "load_cycles": load_cycles,
		"unload_cycles": unload_cycles, "retired_geometry_roots_alive": retained_roots,
		"retired_mesh_resources_alive": retained_meshes, "peak_stage_ms": peak_stage_ms,
		"peak_activation_ms": peak_activation_ms, "stage_records": stage_records.duplicate(true), "fit_records":fit_records.duplicate(true),
		"collision_cache_parts":_collision_cache.paths.size(),"collision_cache_bytes":_collision_cache.cache_bytes,"collision_cache_seed_ms":_collision_cache.seed_ms,"physical_actors_retained": true, "cell_count": region.cell_nodes.size()}

func shutdown() -> void:
	if _stopped: return
	_stopped = true
	if _fit_job!=null:_fit_job.cancel()
	_fit_job=null
	_fit_operations.clear()
	# Godot has no cancellation API for these requests. Drain each issued
	# result on teardown so an abandoned world cannot retain a load handle.
	for path: String in _pending.values():
		ResourceLoader.load_threaded_get(path)
	for path: String in _height_pending:
		ResourceLoader.load_threaded_get(path)
	for path: String in _native_pending:
		ResourceLoader.load_threaded_get(path)
	_native_pending.clear()
	_native_paths.clear()
	_pending.clear()
	_height_pending.clear()
	_height_resources.clear()
	_native_resources.clear()
	_collision_shapes.clear()
	_collision_cache.dispose()
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
