extends "res://tests/orison_v2_floor_surface_test.gd"
## Dossier inspection probe: every V2 light switch plate against the wall it is mounted on.
## Copy beside game/tests to run it through the lane (it is not a suite).
## Per plate it prints the plate model's rear extent along the into-wall axis, the distance to the first
## physics surface and to the first visible mesh surface behind it, the resulting gaps (positive = standing
## off the wall, negative = sunk into it), and every other drawn mesh within 0.6 m that is not the plate's
## own model or signal outlet (candidates for an older switch the plate replaced).
## SHOT_DIR plus SWITCH_SHOTS="id,id,..." also captures those plates from 0.9 m in front, lamp on.
const NEAR := 0.6
const FlushProbe := preload("res://tests/switch_flush_probe.gd")

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var root: Node3D = world.adapter.root
	var plates: Array = []
	for body: StaticBody3D in world.find_children("*", "StaticBody3D", true, false):
		if body.get_node_or_null("SwitchModel") != null: plates.append(body)
	var meshes: Array = world.find_children("*", "GeometryInstance3D", true, false)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var flush := FlushProbe.new(world)
	var off := 0
	var floating := 0
	var sunk := 0
	var crowded := 0
	for plate: StaticBody3D in plates:
		var model: Node3D = plate.get_node("SwitchModel")
		var into := plate.global_transform.basis.z.normalized()
		# Rear extent of the model along +Z (into the wall) in plate space.
		var rear := -INF
		var front := INF
		for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var local: AABB = plate.global_transform.affine_inverse() * draw.global_transform * draw.mesh.get_aabb()
			rear = maxf(rear, local.end.z)
			front = minf(front, local.position.z)
		var origin := plate.global_position
		var query := PhysicsRayQueryParameters3D.create(origin - into * 0.05, origin + into * 0.4, 1, [plate.get_rid()])
		var hit := space.intersect_ray(query)
		var physics: float = INF
		if not hit.is_empty(): physics = ((hit.position as Vector3) - origin).dot(into)
		# First visible surface behind the plate, from every drawn mesh near it (finishes may carry no collision).
		var visual := INF
		var visual_owner := ""
		var nearby: Array = []
		for node: GeometryInstance3D in meshes:
			if not node.is_visible_in_tree() or plate.is_ancestor_of(node): continue
			var box: AABB = node.global_transform * node.get_aabb()
			if box.grow(NEAR).has_point(origin) == false: continue
			var distance := _aabb_distance(box, origin)
			if distance > NEAR: continue
			if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
				var mi := node as MeshInstance3D
				var inv := mi.global_transform.affine_inverse()
				var a := inv * (origin - into * 0.05)
				var b := inv * (origin + into * 0.4)
				var faces := mi.mesh.get_faces()
				for i in range(0, faces.size(), 3):
					var at: Variant = Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i + 1], faces[i + 2])
					if at != null:
						var d: float = (mi.global_transform * (at as Vector3) - origin).dot(into)
						if d < visual: visual = d; visual_owner = str(world.get_path_to(mi))
			if distance <= 0.35 and box.size.x < 0.4 and box.size.y < 0.4 and box.size.z < 0.4:
				var keys: Array = []
				if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
					var mi := node as MeshInstance3D
					for s in mi.mesh.get_surface_count():
						var m: Material = mi.get_surface_override_material(s) if mi.get_surface_override_material(s) != null else mi.mesh.surface_get_material(s)
						keys.append(m.resource_name if m != null else "")
				nearby.append("%s size=%s at=%.3f mats=%s" % [str(world.get_path_to(node)), str(box.size), distance, str(keys)])
		var footprint: Array = flush.measure(plate)
		var worst := 0.0
		for g: float in footprint: worst = maxf(worst, absf(g))
		if worst > 0.0015: off += 1
		var gap_physics := physics - rear
		var gap_visual := visual - rear
		if gap_visual > 0.001: floating += 1
		if gap_visual < -0.001: sunk += 1
		if not nearby.is_empty(): crowded += 1
		var at_root: Vector3 = root.to_local(origin)
		print("SWITCH %s room=%s at=(%.3f, %.3f, %.3f) rear=%.4f front=%.4f gap_physics=%.4f gap_visual=%.4f visual=%s footprint_worst=%.4f nearby=%d" % [
			str(plate.name), str(plate.get_meta("room_id", "")), at_root.x, at_root.y, at_root.z, rear, front,
			gap_physics, gap_visual, visual_owner, worst, nearby.size()])
		for line: String in nearby: print("  NEAR ", line)
	print("SWITCH CENSUS: %d plates; %d standing off their visible wall; %d sunk into it; %d with small geometry within 0.35 m; %d not flush over the whole footprint (meshes and multimesh finishes)" % [plates.size(), floating, sunk, crowded, off])
	var shots := OS.get_environment("SWITCH_SHOTS")
	var directory := OS.get_environment("SHOT_DIR")
	if not shots.is_empty() and not directory.is_empty() and world.player != null:
		DirAccess.make_dir_recursive_absolute(directory)
		for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false): layer.hide()
		world.player.set_physics_process(false)
		world.player.set_lamp_enabled(true)
		for plate: StaticBody3D in plates:
			if str(plate.name) not in shots.split(",", false): continue
			var into := plate.global_transform.basis.z.normalized()
			# Oblique, from along the wall, so the frame shows whether the plate's edge meets the wall.
			var along := plate.global_transform.basis.x.normalized()
			var eye := plate.global_position - into * 0.32 + along * 0.42
			world.player.global_position = eye - Vector3(0, 1.45, 0)
			world.player.velocity = Vector3.ZERO
			for i in 12: await get_tree().physics_frame
			await get_tree().create_timer(1.2).timeout
			var look := plate.global_position - eye
			var flat := Vector2(look.x, look.z).normalized()
			world.player.rotation.y = atan2(-flat.x, -flat.y)
			var cam_eye: Vector3 = world.player.camera.global_position
			var target := plate.global_position
			world.player.camera.rotation = Vector3(atan2(target.y - cam_eye.y, Vector2(target.x - cam_eye.x, target.z - cam_eye.z).length()), 0, 0)
			for i in 12: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join(str(plate.name) + ".png"))
			print("SWITCH shot ", plate.name)
	world.free()
	get_tree().quit(0)

func _aabb_distance(box: AABB, point: Vector3) -> float:
	var clamped := Vector3(clampf(point.x, box.position.x, box.end.x), clampf(point.y, box.position.y, box.end.y), clampf(point.z, box.position.z, box.end.z))
	return clamped.distance_to(point)
