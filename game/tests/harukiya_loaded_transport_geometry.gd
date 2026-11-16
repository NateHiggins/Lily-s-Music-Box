extends Node3D
## Read-only loaded-world intake for exact offline transport checks. INERT;
## no carrier, navigation, continuous clearance or performance acceptance.
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var output := ""
var bar: OrisonV2BarRegion
var preview := false
var prior_data: Dictionary
var prior_text := ""
var prior_mode: int
var sources: Dictionary
var logger
var binary: FileAccess
var draws: Array[Dictionary] = []
var shapes: Array[Dictionary] = []
var door_states: Array[Dictionary] = []

func _ready() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
	return ok

func _run() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		get_tree().quit(2); return
	if FileAccess.file_exists(output.path_join("geometry.bin")):
		get_tree().quit(2); return
	logger = preload("res://tests/guide_bell_error_capture.gd").new()
	OS.add_logger(logger)
	sources = _sources()
	prior_data = RealityState.data
	prior_text = JSON.stringify(prior_data,"",true,true)
	prior_mode = GameBoot.launch_mode
	preview = RealityState.begin_preview_campaign(self)
	if not check(preview,"exclusive nonpersistent preview"): await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	bar = OrisonV2BarRegion.new(); add_child(bar)
	if not check(not bar.startup_failed and bar.destination != null,"actual complete bar-only region mounts"):
		await _finish(); return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var door := bar.doors.get("F01_BAR_RED_DOOR") as DoorProp
	if not check(door != null,"actual red entry owner exists"): await _finish(); return
	door_states.append(_door_state(door,"initial"))
	check(not door.open,"initial real red leaf is closed for the negative control")
	# Keep the real complete closed state for the negative control. Nothing is
	# removed from the world to clear a route or to duplicate a transported part.
	binary = FileAccess.open(output.path_join("geometry.bin"),FileAccess.WRITE)
	if not check(binary != null,"fresh binary destination"): await _finish(); return
	_capture(door,"initial_entry")
	var requester := Node3D.new(); requester.name = "AuthorizedPassageRequester"; add_child(requester)
	requester.global_position = bar.to_global(Vector3(4.95,-2.8,33.5))
	check(door.passage_allowed("stacy"),"current staff key policy permits Stacy")
	if check(door.request_passage(requester,"stacy"),"normal authorized passage request accepted"):
		for step in 180:
			door.hold_passage(requester)
			await get_tree().physics_frame
			if door.is_ready_for_passage(): break
		check(door.is_ready_for_passage(),"real entry leaf reaches its authored open stop")
	door_states.append(_door_state(door,"requested_open"))
	_capture(bar,"open_loaded_bar")
	door.release_passage(requester); requester.free()
	binary.close(); binary = null
	await _finish()

func _door_state(door: DoorProp, state: String) -> Dictionary:
	return {"state":state,"path":str(door.get_path()),"leaf_state":door.leaf_state,
		"open":door.open,"ready":door.is_ready_for_passage(),
		"angle_rad":door._body.rotation.y,"target_rad":door.motion_target_angle(true),
		"frame_world":_matrix(door.global_transform),"body_world":_matrix(door._body.global_transform)}

func _matrix(pose: Transform3D) -> Array:
	return [[pose.basis.x.x,pose.basis.y.x,pose.basis.z.x,pose.origin.x],
		[pose.basis.x.y,pose.basis.y.y,pose.basis.z.y,pose.origin.y],
		[pose.basis.x.z,pose.basis.y.z,pose.basis.z.z,pose.origin.z],[0,0,0,1]]

func _triangles(points: PackedVector3Array, indices: PackedInt32Array, pose: Transform3D) -> Dictionary:
	var world := PackedVector3Array()
	for point: Vector3 in points: world.append(pose * point)
	var vertex_bytes := world.to_byte_array()
	var index_bytes := indices.to_byte_array()
	var offset := binary.get_position(); binary.store_buffer(vertex_bytes)
	var index_offset := binary.get_position(); binary.store_buffer(index_bytes)
	var local_bytes := points.to_byte_array()
	var local_offset := binary.get_position(); binary.store_buffer(local_bytes)
	return {"vertex_offset":offset,"vertex_bytes":vertex_bytes.size(),"vertices":world.size(),
		"index_offset":index_offset,"index_bytes":index_bytes.size(),"indices":indices.size(),
		"local_vertex_offset":local_offset,"local_vertex_bytes":local_bytes.size()}

func _capture(root: Node, state: String) -> void:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*","Node",true,false))
	for node: Node in nodes:
		if node is MeshInstance3D:
			var draw := node as MeshInstance3D
			if draw.mesh == null: continue
			_capture_mesh(draw.mesh,draw.global_transform,str(draw.get_path()),draw.is_visible_in_tree(),draw.layers,_metadata(draw),state)
		elif node is MultiMeshInstance3D:
			var draw := node as MultiMeshInstance3D
			if draw.multimesh == null or draw.multimesh.mesh == null: continue
			if not check(draw.multimesh.transform_format==MultiMesh.TRANSFORM_3D,"3D physical multimesh "+str(node.get_path())): continue
			for instance in draw.multimesh.instance_count:
				var metadata := _metadata(draw)
				metadata.merge({"multimesh_instance":instance,"visible_instance_count":draw.multimesh.visible_instance_count})
				var visible := draw.is_visible_in_tree() and (draw.multimesh.visible_instance_count<0 or instance<draw.multimesh.visible_instance_count)
				_capture_mesh(draw.multimesh.mesh,draw.global_transform*draw.multimesh.get_instance_transform(instance),str(draw.get_path()),visible,draw.layers,metadata,state)
		elif node is CollisionShape3D:
			var shape_node := node as CollisionShape3D
			if shape_node.shape == null: continue
			var owner := shape_node.get_parent() as CollisionObject3D
			var shape := shape_node.shape
			var row: Dictionary = {"state":state,"path":str(node.get_path()),"shape_class":shape.get_class(),
				"disabled":shape_node.disabled,"world_transform":_matrix(shape_node.global_transform),
				"owner":str(owner.get_path()) if owner != null else "",
				"owner_class":owner.get_class() if owner != null else "",
				"collision_layer":owner.collision_layer if owner != null else 0,
				"collision_mask":owner.collision_mask if owner != null else 0}
			if shape is ConcavePolygonShape3D:
				var points: PackedVector3Array = shape.get_faces(); var indices := PackedInt32Array()
				for index in points.size(): indices.append(index)
				row["triangles"] = _triangles(points,indices,shape_node.global_transform)
			elif shape is ConvexPolygonShape3D:
				var points: Array = []
				for point: Vector3 in shape.points: points.append([point.x,point.y,point.z])
				row["convex_points_local"] = points
			elif shape is BoxShape3D: row["size"] = [shape.size.x,shape.size.y,shape.size.z]
			elif shape is CylinderShape3D: row.merge({"radius":shape.radius,"height":shape.height})
			elif shape is CapsuleShape3D: row.merge({"radius":shape.radius,"height":shape.height})
			elif shape is SphereShape3D: row["radius"] = shape.radius
			else: check(false,"unhandled collision shape "+shape.get_class()+" "+str(node.get_path()))
			shapes.append(row)

func _capture_mesh(mesh: Mesh, pose: Transform3D, path: String, visible: bool, layers: int, metadata: Dictionary, state: String) -> void:
	for surface in mesh.get_surface_count():
		var triangular: bool = mesh is PrimitiveMesh or (mesh is ArrayMesh and mesh.surface_get_primitive_type(surface)==Mesh.PRIMITIVE_TRIANGLES)
		if not check(triangular,"triangle surface "+path): continue
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if indices.is_empty():
			for index in points.size(): indices.append(index)
		var row := _triangles(points,indices,pose)
		row.merge({"state":state,"path":path,"surface":surface,"visible":visible,
			"layers":layers,"world_transform":_matrix(pose),"metadata":metadata})
		draws.append(row)

func _metadata(node: Node) -> Dictionary:
	var result := {}
	for key: StringName in node.get_meta_list():
		var value: Variant = node.get_meta(key)
		if typeof(value) in [TYPE_STRING,TYPE_STRING_NAME,TYPE_INT,TYPE_FLOAT,TYPE_BOOL]: result[str(key)] = value
	return result

func _sources() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array = []; var physical: Array = []
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime)==0,"runtime source digest")
	check(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical)==0,"physical source digest")
	return {"runtime":str(runtime),"physical":str(physical),
		"helper_sha256_lf":FileAccess.get_file_as_string(get_script().resource_path).replace("\r\n","\n").sha256_text()}

func _finish() -> void:
	var frame := _matrix(bar.global_transform) if is_instance_valid(bar) else []
	if binary != null: binary.close(); binary = null
	if is_instance_valid(bar): bar.free()
	if preview: check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data) and JSON.stringify(prior_data,"",true,true)==prior_text,"exact preview/campaign restoration")
	GameBoot.launch_mode = prior_mode
	await get_tree().process_frame
	check(_sources()==sources,"runtime/physical/helper inputs unchanged")
	await get_tree().process_frame
	var errors: Array = logger.errors.duplicate()
	check(errors.is_empty(),"no engine errors including teardown")
	OS.remove_logger(logger)
	var result := {"evidence_class":"INERT","status":"EXPORTED" if failures.is_empty() else "FAIL",
		"scope":"Full loaded bar render surfaces and exact collision-owner intake, actual authorized entry motion. No carrier, walk, continuous/volume or physical/art acceptance.",
		"coordinate_frame":"world Godot metres; native and bar transforms already applied once",
		"encoding":"little endian float32 XYZ plus int32 indices with explicit byte offsets",
		"bar_world_transform":frame,"source_inputs":sources,"door_states":door_states,
		"binary_sha256":FileAccess.get_sha256(output.path_join("geometry.bin")),
		"draws":draws,"shapes":shapes,"checks":checks,"failures":failures,"engine_errors":errors}
	FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("LOADED TRANSPORT GEOMETRY: ",result.status," draws=",draws.size()," shapes=",shapes.size()," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
