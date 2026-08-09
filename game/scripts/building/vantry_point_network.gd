class_name VantryPointNetwork
extends Node3D
## The Orison's 119 ceiling ears in three draws per visible floor.
##
## One full FunctionalProp owns the current sound and service motion. The
## remaining heads are one three-surface MultiMesh per floor. Relocation hides
## the destination instance, moves the owner, then restores the old instance
## before another rendered frame can observe the exchange.

const PROP_SCRIPT := preload("res://scripts/props/vantry_point_prop.gd")

var points: Dictionary = {}       # point id -> immutable layout record
var point_order: Array[String] = []
var _slots: Dictionary = {}       # point id -> batch/index/transform
var _batches: Dictionary = {}     # floor -> MultiMeshInstance3D
var _floor_ids: Dictionary = {}   # floor -> stable point-id array
var _hidden_by_floor: Dictionary = {}  # floor -> promoted point id
var active_owner: VantryPointProp
var active_point_id := ""
var work_orders: WorkOrders
var floor_nodes: Dictionary
var player: Node3D
var _teresa_shutter: MeshInstance3D
var _teresa_tween: Tween


func build(layout: Dictionary, floors: Dictionary, spine: WorkOrders) -> int:
	floor_nodes = floors
	work_orders = spine
	for spec in layout.get("vantry_points", []):
		var point_id := str(spec.id)
		points[point_id] = spec.duplicate(true)
		point_order.append(point_id)
	point_order.sort()
	_build_batches()
	_build_teresa_shutter()
	_build_owner()
	print("[VANTRY] %d points, %d floor batches, %d static draws/floor" % [
			points.size(), _batches.size(), static_draws_per_floor()])
	return points.size()


func bind_player(body: Node3D) -> void:
	player = body


func activate(point_id: String) -> bool:
	if not points.has(point_id):
		return false
	if active_point_id == point_id:
		return true
	# Destination disappears first. The owner then takes its exact transform,
	# and only after that does the old static face return. All three mutations
	# happen synchronously; no await means no blink can reach a rendered frame.
	_set_static_visible(point_id, false)
	var old_id := active_point_id
	_move_owner(point_id)
	if old_id != "":
		_set_static_visible(old_id, true)
	active_point_id = point_id
	active_owner.point_id = point_id
	active_owner.room_id = str(points[point_id].room)
	active_owner.set_chirping(true)
	return true


func relocate_unseen(point_id: String) -> bool:
	if not points.has(point_id) or point_id == active_point_id:
		return false
	if _visible_to_player(_point_world(active_point_id)) \
			or _visible_to_player(_point_world(point_id)):
		return false
	return activate(point_id)


func cached_point_ids() -> Array[String]:
	return point_order.duplicate()


func point_spec(point_id: String) -> Dictionary:
	return points.get(point_id, {})


func nearest_cached(at: Vector3) -> String:
	# Used by tests/debug only. ChirpHunt caches its selected id and never scans
	# the graph or this list per chirp.
	var best := ""
	var best_d := INF
	for point_id in point_order:
		var distance := at.distance_squared_to(_point_world(point_id))
		if distance < best_d:
			best_d = distance
			best = point_id
	return best


func static_draws_per_floor() -> int:
	if _batches.is_empty():
		return 0
	var first: MultiMeshInstance3D = _batches.values()[0]
	return first.multimesh.mesh.get_surface_count()


func active_mesh_count() -> int:
	if active_owner == null:
		return 0
	return int(active_owner.get_service_state().mesh_count)


func static_instance_visible(point_id: String) -> bool:
	if not points.has(point_id):
		return false
	var fid := str(points[point_id].floor)
	return str(_hidden_by_floor.get(fid, "")) != point_id


func teresa_telltale_visible() -> bool:
	return _teresa_shutter != null and _teresa_shutter.visible


func stage_haunt(case_id: String, tier: int, _player: Node3D) -> bool:
	if case_id != "teresa_call_bells" or _teresa_shutter == null:
		return false
	_teresa_shutter.visible = true
	if _teresa_tween and _teresa_tween.is_valid():
		_teresa_tween.kill()
	_teresa_tween = create_tween()
	_teresa_tween.tween_interval(5.0 + tier)
	_teresa_tween.tween_callback(func(): _teresa_shutter.visible = false)
	return true


func floor_batch_count() -> int:
	return _batches.size()


func _build_batches() -> void:
	var grouped := {}
	for point_id in point_order:
		var fid := str(points[point_id].floor)
		if not grouped.has(fid):
			grouped[fid] = []
		grouped[fid].append(point_id)
	var shared_mesh := _build_static_mesh()
	for fid in grouped:
		var ids: Array = grouped[fid]
		_floor_ids[fid] = ids.duplicate()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = shared_mesh
		mm.instance_count = ids.size()
		var batch := MultiMeshInstance3D.new()
		batch.name = "%s_VantryPointBatch" % fid
		batch.add_to_group("vantry_point_batches")
		batch.multimesh = mm
		floor_nodes.get(fid, self).add_child(batch)
		_batches[fid] = batch
		for index in ids.size():
			var point_id: String = ids[index]
			var world := _point_world(point_id)
			var local := batch.to_local(world)
			var yaw := deg_to_rad(float(points[point_id].get("yaw_deg", 0.0)))
			var xf := Transform3D(Basis(Vector3.UP, yaw), local)
			mm.set_instance_transform(index, xf)
			_slots[point_id] = {"batch": batch, "index": index,
					"transform": xf}


func _build_owner() -> void:
	active_owner = PROP_SCRIPT.new()
	active_owner.name = "ActiveVantryPoint"
	active_owner.prop_type = "vantry_point"
	active_owner.bind_order_spine(work_orders)
	add_child(active_owner)
	active_owner.visible = false


func _build_teresa_shutter() -> void:
	const TERESA_POINT := "F01_D_BED_VANTRY_POINT"
	if not points.has(TERESA_POINT):
		return
	var shape := CylinderMesh.new()
	shape.top_radius = 0.012
	shape.bottom_radius = 0.012
	shape.height = 0.007
	shape.radial_segments = 10
	_teresa_shutter = MeshInstance3D.new()
	_teresa_shutter.name = "TeresaMechanicalTelltaleShutter"
	_teresa_shutter.mesh = shape
	_teresa_shutter.material_override = MatLib.get_mat("bakelite_black",
			Color(0.58, 0.52, 0.46), 0.35)
	var parent: Node3D = floor_nodes.get("F01", self)
	parent.add_child(_teresa_shutter)
	_teresa_shutter.position = parent.to_local(_point_world(TERESA_POINT)) \
			+ Vector3(0.065, -0.073, 0.010)
	_teresa_shutter.visible = false


func _move_owner(point_id: String) -> void:
	var spec: Dictionary = points[point_id]
	var parent: Node3D = floor_nodes.get(str(spec.floor), self)
	if active_owner.get_parent() != parent:
		active_owner.reparent(parent, false)
	active_owner.position = parent.to_local(_point_world(point_id))
	active_owner.rotation = Vector3(0,
			deg_to_rad(float(spec.get("yaw_deg", 0.0))), 0)
	active_owner.visible = true


func _set_static_visible(point_id: String, visible: bool) -> void:
	var slot: Dictionary = _slots.get(point_id, {})
	if slot.is_empty():
		return
	var fid := str(points[point_id].floor)
	if visible:
		if str(_hidden_by_floor.get(fid, "")) == point_id:
			_hidden_by_floor.erase(fid)
	else:
		_hidden_by_floor[fid] = point_id
	_rebuild_floor_instances(fid)


func _rebuild_floor_instances(fid: String) -> void:
	# GL Compatibility does not reliably preserve zero-scale per-instance
	# transforms. Relocation is rare, so compact this floor's 10–22 transforms
	# and use visible_instance_count. It remains the same three draw calls.
	var batch: MultiMeshInstance3D = _batches.get(fid)
	if batch == null:
		return
	var hidden := str(_hidden_by_floor.get(fid, ""))
	var write := 0
	for point_id in _floor_ids.get(fid, []):
		if point_id == hidden:
			continue
		var slot: Dictionary = _slots[point_id]
		batch.multimesh.set_instance_transform(write, slot.transform)
		write += 1
	batch.multimesh.visible_instance_count = write


func _point_world(point_id: String) -> Vector3:
	if not points.has(point_id):
		return Vector3.ZERO
	return GameBoot.b2g(points[point_id].pos)


func _visible_to_player(at: Vector3) -> bool:
	if player == null:
		return false
	var candidate = player.get("camera")
	if not (candidate is Camera3D):
		return false
	var camera: Camera3D = candidate
	if not camera.is_position_in_frustum(at):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, at)
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.position.distance_to(at) < 0.22


func _build_static_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var base := SurfaceTool.new()
	base.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_cylinder(base, 0.115, 0.115, 0.026, Vector3(0, -0.013, 0))
	_append_cylinder(base, 0.103, 0.109, 0.028, Vector3(0, -0.036, 0))
	_append_cylinder(base, 0.072, 0.072, 0.010, Vector3(0, -0.052, 0))
	base.set_material(MatLib.get_mat("bakelite_black",
			Color(0.72, 0.65, 0.58), 0.42))
	base.commit(mesh)

	var brass := SurfaceTool.new()
	brass.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_ring(brass, 0.078, 0.009, Vector3(0, -0.066, 0))
	for i in 12:
		_append_box(brass, Vector3(0.010, 0.007, 0.062),
				Vector3(0, -0.066, 0), i * TAU / 12.0)
	_append_cylinder(brass, 0.018, 0.018, 0.010,
			Vector3(0, -0.067, 0))
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		_append_cylinder(brass, 0.007, 0.007, 0.006,
				Vector3(sin(angle) * 0.092, -0.052,
						cos(angle) * 0.092))
	brass.set_material(MatLib.get_mat("brass_mesh",
			Color(0.78, 0.70, 0.52), 0.50))
	brass.commit(mesh)

	var flag := SurfaceTool.new()
	flag.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_cylinder(flag, 0.009, 0.009, 0.006,
			Vector3(0.065, -0.070, 0.010))
	flag.set_material(MatLib.get_mat("indicator_enamel",
			Color(0.72, 0.28, 0.20), 0.35))
	flag.commit(mesh)
	return mesh


func _append_cylinder(st: SurfaceTool, top: float, bottom: float,
		height: float, at: Vector3) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 14
	st.append_from(shape, 0, Transform3D(Basis(), at))


func _append_ring(st: SurfaceTool, radius: float, tube: float,
		at: Vector3) -> void:
	var shape := TorusMesh.new()
	shape.inner_radius = radius - tube
	shape.outer_radius = radius + tube
	shape.rings = 20
	st.append_from(shape, 0, Transform3D(Basis(), at))


func _append_box(st: SurfaceTool, size: Vector3, at: Vector3,
		yaw: float) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	st.append_from(shape, 0, Transform3D(Basis(Vector3.UP, yaw), at))
