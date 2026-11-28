extends "res://tests/v2_performance_matrix.gd"
## Diagnostic only (polygon pass pilot, order wfcb3aeaec6cf; INERT, not a gate).
## Asks how much of the frame triangles cost, before anyone reduces any.
##
## At each chosen station the base matrix finds the worst heading. At that
## heading the probe then changes one thing at a time, with a stock arm
## between every treatment so a slow drift in the draw count cannot pass for
## an effect:
##   lod4 / lod16 / lod64  Viewport.mesh_lod_threshold raised from 1 px.
##                         Meshes imported with LODs drop triangles; the draw
##                         count stays the same. The slope of GPU and render
##                         CPU time against primitives is the triangle cost.
##   no_shadows            every shadow-casting light off: the shadow passes'
##                         share, triangles and draws together.
## Then a census of the meshes inside the camera frustum, by mesh resource:
## instances, triangles, whether each casts shadows and has LODs, and a rough
## triangles-per-covered-pixel at this stance. Bounded by a time budget.
##
##   SHOT_DIR                where geometry_share.json is written
##   ORISON_GEO_STATIONS     comma-separated station names (default three)

const DEFAULT_STATIONS := "third_floor_crossing,lobby,second_floor_landing"
const ARM_WARMUP := 90
const ARM_FRAMES := 180
const CENSUS_BUDGET_MS := 20000
const CENSUS_TOP := 60

var _rows_out: Array = []


func _measure(station: Dictionary) -> Dictionary:
	var wanted := OS.get_environment("ORISON_GEO_STATIONS")
	if wanted.is_empty():
		wanted = DEFAULT_STATIONS
	if not (str(station.name) in wanted.split(",")):
		return {"name": str(station.name), "valid": true, "skipped": true}
	var row: Dictionary = await super._measure(station)
	if not row.get("valid", false) or not row.has("worst_heading"):
		_rows_out.append({"station": row.name, "skipped": "no valid settled stance"})
		return row
	var at := Vector3(row.position[0], row.position[1], row.position[2])
	var yaw := deg_to_rad(float(row.worst_heading.yaw_degrees))
	var arms := await _arms(at, yaw)
	var census := _census()
	_rows_out.append({"station": row.name, "room": row.room, "yaw_degrees": row.worst_heading.yaw_degrees,
		"position": row.position, "arms": arms, "census": census})
	return row


func _pose(at: Vector3, yaw: float) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = yaw
	player.camera.rotation.x = 0.0


func _arms(at: Vector3, yaw: float) -> Dictionary:
	var viewport := get_viewport()
	var stock_lod := viewport.mesh_lod_threshold
	var lights: Array[Light3D] = []
	for node: Node in world.find_children("*", "Light3D", true, false):
		if (node as Light3D).shadow_enabled:
			lights.append(node as Light3D)
	var out := {"stock_mesh_lod_threshold": stock_lod, "shadow_lights": lights.size()}
	var order := ["stock_a", "lod4", "stock_b", "lod16", "stock_c", "lod64", "stock_d", "no_shadows", "stock_e"]
	for arm: String in order:
		viewport.mesh_lod_threshold = {"lod4": 4.0, "lod16": 16.0, "lod64": 64.0}.get(arm, stock_lod)
		for light: Light3D in lights:
			if is_instance_valid(light):
				light.shadow_enabled = arm != "no_shadows"
		_pose(at, yaw)
		for i in ARM_WARMUP:
			await get_tree().process_frame
		out[arm] = await _sample(at)
		print("[GEO] %-10s wall %6.2f  cpu %5.2f  gpu %5.2f  calls %6d  prims vis %10d shadow %10d" % [arm,
			out[arm].wall_ms_median, out[arm].render_cpu_ms_median, out[arm].render_gpu_ms_median,
			int(out[arm].draw_calls_median), int(out[arm].visible_primitives_median), int(out[arm].shadow_primitives_median)])
	viewport.mesh_lod_threshold = stock_lod
	for light: Light3D in lights:
		if is_instance_valid(light):
			light.shadow_enabled = true
	return out


func _sample(at: Vector3) -> Dictionary:
	_frame_usec = PackedInt64Array()
	_cpu_ms = PackedFloat64Array()
	_gpu_ms = PackedFloat64Array()
	_last_usec = 0
	var calls := PackedFloat64Array()
	var vis_prims := PackedFloat64Array()
	var shadow_prims := PackedFloat64Array()
	var vis_calls := PackedFloat64Array()
	var shadow_calls := PackedFloat64Array()
	_sampling = true
	for i in ARM_FRAMES:
		await get_tree().process_frame
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		vis_prims.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		shadow_prims.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		vis_calls.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		shadow_calls.append(RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	_sampling = false
	var wall := _summary_usec(_frame_usec)
	return {"wall_ms_median": wall.median, "wall_ms_p95": wall.p95,
		"render_cpu_ms_median": _median(_cpu_ms), "render_gpu_ms_median": _median(_gpu_ms),
		"draw_calls_median": _median(calls),
		"visible_primitives_median": _median(vis_prims), "shadow_primitives_median": _median(shadow_prims),
		"visible_draws_median": _median(vis_calls), "shadow_draws_median": _median(shadow_calls),
		"drift_m": snappedf(player.global_position.distance_to(at), 0.001)}


func _triangles(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh:
			var array_mesh := mesh as ArrayMesh
			var indices := array_mesh.surface_get_array_index_len(s)
			total += (indices if indices > 0 else array_mesh.surface_get_array_len(s)) / 3
		else:
			var arrays := mesh.surface_get_arrays(s)
			var index: Variant = arrays[Mesh.ARRAY_INDEX]
			total += (index.size() if index != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return total


func _has_lods(mesh: Mesh) -> bool:
	# The importer stores generated LODs on the surface; a surface's LOD count
	# is not exposed, so ask the server for the surface data's lods array.
	if not (mesh is ArrayMesh) or mesh.get_surface_count() == 0:
		return false
	var data: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	return not (data.get("lods", []) as Array).is_empty()


func _census() -> Dictionary:
	var started := Time.get_ticks_msec()
	var camera: Camera3D = player.camera
	var planes := camera.get_frustum()
	var eye := camera.global_position
	var focal_px := get_viewport().get_visible_rect().size.y * 0.5 / tan(deg_to_rad(camera.fov) * 0.5)
	var by_mesh := {}
	var tri_cache := {}
	var seen := 0
	var truncated := false
	for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
		if Time.get_ticks_msec() - started > CENSUS_BUDGET_MS:
			truncated = true
			break
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var copies := 1
		if geo is MeshInstance3D:
			mesh = (geo as MeshInstance3D).mesh
		elif geo is MultiMeshInstance3D and (geo as MultiMeshInstance3D).multimesh != null:
			mesh = (geo as MultiMeshInstance3D).multimesh.mesh
			copies = (geo as MultiMeshInstance3D).multimesh.visible_instance_count
			if copies < 0:
				copies = (geo as MultiMeshInstance3D).multimesh.instance_count
		if mesh == null:
			continue
		var box := geo.global_transform * geo.get_aabb()
		var inside := true
		for plane: Plane in planes:
			# The box is outside if its most positive corner along the normal lies in front of the plane.
			var far := Vector3(box.end.x if plane.normal.x < 0 else box.position.x,
				box.end.y if plane.normal.y < 0 else box.position.y,
				box.end.z if plane.normal.z < 0 else box.position.z)
			if plane.is_point_over(far):
				inside = false
				break
		if not inside:
			continue
		seen += 1
		var key := mesh.resource_path if not mesh.resource_path.is_empty() else "%s:%s" % [str(geo.owner.scene_file_path if geo.owner != null else ""), mesh.resource_name if not mesh.resource_name.is_empty() else str(geo.name)]
		if not tri_cache.has(mesh):
			tri_cache[mesh] = _triangles(mesh)
		var tris: int = tri_cache[mesh] * copies
		var distance := maxf(0.05, eye.distance_to(box.get_center()))
		var radius_px := box.size.length() * 0.5 * focal_px / distance
		var covered := clampf(PI * radius_px * radius_px, 1.0, 2560.0 * 1440.0)
		if not by_mesh.has(key):
			by_mesh[key] = {"mesh": key, "instances": 0, "triangles": 0, "triangles_each": tri_cache[mesh],
				"shadow_casting": 0, "has_lods": _has_lods(mesh), "nearest_m": distance, "max_tris_per_px": 0.0,
				"sample_path": str(geo.get_path()).right(120)}
		var entry: Dictionary = by_mesh[key]
		entry.instances += copies
		entry.triangles += tris
		if geo.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			entry.shadow_casting += copies
		entry.nearest_m = minf(entry.nearest_m, distance)
		entry.max_tris_per_px = maxf(entry.max_tris_per_px, float(tri_cache[mesh]) / covered)
	var rows: Array = by_mesh.values()
	var total := 0
	var with_lods := 0
	for entry: Dictionary in rows:
		total += int(entry.triangles)
		if entry.has_lods:
			with_lods += int(entry.triangles)
		entry.nearest_m = snappedf(entry.nearest_m, 0.01)
		entry.max_tris_per_px = snappedf(entry.max_tris_per_px, 0.0001)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.triangles) > int(b.triangles))
	var dense := rows.duplicate()
	dense.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.max_tris_per_px) > float(b.max_tris_per_px))
	print("[GEO] census: %d instances in the frustum, %d meshes, %d triangles (%d in meshes with LODs)%s" % [
		seen, rows.size(), total, with_lods, " TRUNCATED" if truncated else ""])
	return {"instances_in_frustum": seen, "meshes": rows.size(), "triangles_in_frustum": total,
		"triangles_in_meshes_with_lods": with_lods, "truncated": truncated,
		"elapsed_ms": Time.get_ticks_msec() - started,
		"by_triangles": rows.slice(0, CENSUS_TOP), "by_density": dense.slice(0, 30),
		"limits": "Frustum test on world AABBs, no occlusion: things behind walls count. Covered pixels are a bounding-sphere estimate. Triangles are LOD 0."}


func _write(startup: Dictionary, rows: Array) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty():
		failures.append("SHOT_DIR is not set; nothing was written")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var record := {"schema": "orison.v2-geometry-share.v1", "evidence_class": "INERT",
		"order": "wfcb3aeaec6cf", "engine": Engine.get_version_info().get("string", ""),
		"adapter": RenderingServer.get_video_adapter_name(), "resolution": [2560, 1440],
		"msaa_3d": get_viewport().msaa_3d, "taa": get_viewport().use_taa,
		"arm_warmup": ARM_WARMUP, "arm_frames": ARM_FRAMES, "startup": startup,
		"stations": _rows_out, "failures": failures}
	var file := FileAccess.open(directory.path_join("geometry_share.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
