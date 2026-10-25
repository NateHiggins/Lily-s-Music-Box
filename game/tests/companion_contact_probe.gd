extends Node3D
## INERT comparison of physics queries and conditioned imported-mesh arithmetic.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var model := (load("res://assets/props/service_companion_v2.glb") as PackedScene).instantiate() as Node3D
	add_child(model)
	var draws: Array[MeshInstance3D] = [model.find_child("ShellStudy__ShellSteel", true, false), model.find_child("ShellStudy__ShellBrass", true, false)]
	var bodies: Array[StaticBody3D] = []
	var shapes: Array[ConcavePolygonShape3D] = []
	for draw in draws:
		var body := StaticBody3D.new()
		body.collision_layer = 1 << 30
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = draw.mesh.create_trimesh_shape()
		draw.add_child(body)
		body.add_child(collision)
		bodies.append(body)
		shapes.append(collision.shape)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var records: Array = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for point: Vector2 in [Vector2(sx * .1025, sy * .066), Vector2(sx * .063, sy * .093)]:
				for offset: Vector2 in [Vector2(.002, 0), Vector2(-.002, 0), Vector2(0, .002), Vector2(0, -.002)]:
					var at := point + offset
					for index in 2:
						var draw := draws[index]
						var start := Vector3(at.x, at.y, .5 if index == 0 else -.5)
						var end := Vector3(at.x, at.y, -.5 if index == 0 else .5)
						var query := PhysicsRayQueryParameters3D.create(model.to_global(start), model.to_global(end), 1 << 30)
						query.exclude = [bodies[1 - index].get_rid()]
						var hit := get_world_3d().direct_space_state.intersect_ray(query)
						var first: Variant = _mesh_ray(draw, model, start, end, 1.0)
						var conditioned: Variant = _mesh_ray(draw, model, start, end, 1000.0)
						records.append({"point":[at.x, at.y], "stock":index, "physics_z":model.to_local(hit.position).z if not hit.is_empty() else null, "metre_mesh_z":first, "conditioned_mesh_z":conditioned, "draw_transform":str(draw.transform)})
	var out := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join("contact_probe.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Diagnostic only; no pass/qualification claim. Identical imported faces queried in physics, metre and millimetre-conditioned arithmetic.", "physics_engine":ProjectSettings.get_setting("physics/3d/physics_engine"), "records":records}, "\t"))
	print("COMPANION CONTACT PROBE records=", records.size())
	get_tree().quit(0)

func _mesh_ray(draw: MeshInstance3D, model: Node3D, start: Vector3, end: Vector3, scale_factor: float) -> Variant:
	var local_start := draw.to_local(model.to_global(start)) * scale_factor
	var local_end := draw.to_local(model.to_global(end)) * scale_factor
	var faces := draw.mesh.get_faces()
	var best := INF
	var answer: Variant = null
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(local_start, local_end, faces[index] * scale_factor, faces[index + 1] * scale_factor, faces[index + 2] * scale_factor)
		if hit is not Vector3: continue
		var distance := local_start.distance_squared_to(hit)
		if distance < best:
			best = distance
			answer = model.to_local(draw.to_global(hit / scale_factor)).z
	return answer
