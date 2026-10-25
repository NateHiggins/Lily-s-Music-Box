extends RefCounted
## Loaded family/crowd review only. No timetable, arrival or played-world proof.
const ChairRepair := preload("res://scripts/building/orison_v2_bar_cafe_seating.gd")

static func digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

static func alcove_contacts(region: OrisonV2BarRegion, failures: Array[String]) -> Array:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_bar_resident_alcove.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bar_resident_places.json"))
	var records: Array = []
	if FileAccess.get_sha256(str(data.asset)) != str(fixture.asset_sha256): failures.append("alcove bearing fixture does not bind native binary"); return records
	var excluded: Array[RID] = []
	for body: StaticBody3D in region.find_children("*", "StaticBody3D", true, false):
		if body.get_parent() is MeshInstance3D and body.get_parent().has_meta("bar_resident_assembly"): excluded.append(body.get_rid())
	var supports := {}
	for floor: Dictionary in region.source_layout.floors:
		if floor.id == "F01":
			for row: Dictionary in floor.furniture: supports[str(row.id)] = row
	for kind: String in ["floor_contacts", "shelf_wall_contacts"]:
		for contact: Dictionary in fixture[kind]:
			var frame: Dictionary = fixture.frames[str(contact.assembly)]
			var local: Array = contact.foot_local if kind == "floor_contacts" else contact.point
			var flat := Vector2(local[0], local[1]).rotated(deg_to_rad(float(frame.yaw)))
			var source_point := [float(frame.at[0]) + flat.x, float(frame.at[1]) + flat.y, float(frame.at[2]) + float(local[2])]
			var at := region.to_global(GameBoot.b2g(source_point))
			var normal := region.global_basis * (Vector3.UP if kind == "floor_contacts" else Vector3.LEFT)
			if kind == "floor_contacts":
				if not supports.has(str(contact.support)): failures.append("native foot support id missing"); continue
				var support: Dictionary = supports[str(contact.support)]
				var rect: Array = support.rect
				if source_point[0] < rect[0] or source_point[0] > rect[2] or source_point[1] < rect[1] or source_point[1] > rect[3]: failures.append("native foot is outside its declared deck")
			var query := PhysicsRayQueryParameters3D.create(at + normal * .15, at - normal * .15, 1, excluded)
			var hit := region.get_world_3d().direct_space_state.intersect_ray(query)
			var distance: float = INF if hit.is_empty() else hit.position.distance_to(at)
			if hit.is_empty() or distance > .0002 or hit.normal.dot(normal) < .99:
				failures.append("native alcove bearing gap: " + str(contact.assembly) + " " + str(source_point) + " " + str(hit))
			records.append({"assembly": contact.assembly, "kind": kind, "source_point": source_point,
				"gap_m": distance, "hit": str(hit)})
	if records.size() != 12: failures.append("all eight feet and four wall bearings must be sampled")
	return records

static func run(root: Node3D, actors: Array[AnimatedResident], camera: Camera3D, directory: String) -> Dictionary:
	var failures: Array[String] = []
	var report := {"evidence_class": "INERT", "scope": "Loaded native bar and eighteen-actor crowd; no arrivals, schedules, saves, played access or world performance qualification."}
	var raw := (load(OrisonV2BarRegion.CELL) as PackedScene).instantiate() as Node3D
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OrisonV2BarRegion.LAYOUT))
	var originals := {}
	for draw: MeshInstance3D in raw.find_children("*", "MeshInstance3D", true, false):
		originals[draw] = {"mesh": draw.mesh, "buffers": digest(draw.mesh.get("_surfaces")), "visible": draw.visible}
	var repair_ok := ChairRepair.mount(raw, layout)
	if not repair_ok: failures.append("source-bound eight-chair repair refused")
	if repair_ok:
		for draw: MeshInstance3D in originals:
			var before: Dictionary = originals[draw]
			if draw.mesh != before.mesh or digest(draw.mesh.get("_surfaces")) != str(before.buffers):
				failures.append("original mesh owner or array changed: " + str(draw.name))
			var expected_visible := false if str(draw.name) == "F01_OWN_SHOP_BAR_furnish_oak_quartered" else bool(before.visible)
			if draw.visible != expected_visible: failures.append("unrelated source visibility changed: " + str(draw.name))
	report["original_draw_count"] = originals.size()
	report["original_buffers_and_mesh_owners_preserved"] = repair_ok and failures.is_empty()
	raw.free()
	if not failures.is_empty(): report["failures"] = failures; return report
	var region := OrisonV2BarRegion.new()
	region.name = "ResidentBarReview"
	root.add_child(region)
	if region.startup_failed:
		failures.append("composed retained bar startup refused")
		report["failures"] = failures; return report
	var registry := region.resident_places
	if registry == null:
		failures.append("resident registry missing")
		report["failures"] = failures; return report
	var native_metrics: Array = []
	for draw: MeshInstance3D in region.find_children("*", "MeshInstance3D", true, false):
		if not draw.has_meta("bar_resident_assembly") and not draw.has_meta("bar_cafe_seating"): continue
		var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
		var key := str(draw.get_meta("material_key", ""))
		if material == null or not MatLib.SETS.has(key): failures.append("native finish missing: " + str(draw.name)); continue
		var library := MatLib.get_mat(key)
		if material == library or material.uv1_triplanar or not material.normal_enabled \
				or not material.uv1_scale.is_equal_approx(Vector3.ONE / float(MatLib.SETS[key][3])):
			failures.append("native loaded material ABI: " + str(draw.name))
		if material.albedo_texture != library.albedo_texture or material.roughness_texture != library.roughness_texture or material.normal_texture != library.normal_texture:
			failures.append("native registered texture owner: " + str(draw.name))
		for texture: Texture2D in [material.albedo_texture, material.roughness_texture, material.normal_texture]:
			if texture == null or texture.get_image() == null or not texture.get_image().has_mipmaps(): failures.append("native loaded mip chain: " + str(draw.name))
		var arrays := draw.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for v in vertices.size(): indices.append(v)
		var degenerate := 0
		var minimum := INF; var maximum := 0.0
		var maximum_edge_stretch := 0.0
		if uv.size() != vertices.size() or tangents.size() != vertices.size() * 4:
			failures.append("native imported UV/tangent streams: " + str(draw.name)); continue
		for face in range(0, indices.size(), 3):
			var a := indices[face]; var b := indices[face + 1]; var c := indices[face + 2]
			var uv_area := absf((uv[b] - uv[a]).cross(uv[c] - uv[a]))
			var area := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length()
			if uv_area < 1e-12 or area < 1e-12: degenerate += 1
			elif area > 0: minimum = minf(minimum, uv_area / area); maximum = maxf(maximum, uv_area / area)
			for edge: Array in [[a,b], [b,c], [c,a]]:
				var span := vertices[edge[0]].distance_to(vertices[edge[1]])
				if span > 0: maximum_edge_stretch = maxf(maximum_edge_stretch, absf(uv[edge[0]].distance_to(uv[edge[1]]) / span - 1.0))
		if degenerate != 0: failures.append("native imported degenerate UV/geometry triangles: " + str(draw.name) + " " + str(degenerate))
		if maximum_edge_stretch > .005: failures.append("native imported metre chart stretch above 0.5 percent: " + str(draw.name) + " " + str(maximum_edge_stretch))
		native_metrics.append({"draw": str(draw.name), "key": key, "triangles": indices.size() / 3,
			"degenerate": degenerate, "maximum_edge_stretch": maximum_edge_stretch,
			"surface_layered": draw.get_surface_override_material(0) is ShaderMaterial,
			"metre_chart_area_ratio_min": minimum, "metre_chart_area_ratio_max": maximum})
	if native_metrics.size() != 9: failures.append("expected all nine new native material partitions")
	report["native_import_metrics"] = native_metrics
	var poses: Array = []
	var identities := {}
	for actor: AnimatedResident in actors:
		actor.show()
		if identities.has(actor.resident_id): failures.append("duplicate resident: " + actor.resident_id)
		identities[actor.resident_id] = true
		var place: Dictionary = registry.call("preferred", actor.resident_id)
		if place.is_empty() or not bool(registry.call("claim", actor.resident_id, actor)):
			failures.append("preferred place unavailable: " + actor.resident_id); continue
		var marker: Marker3D = place.marker
		actor.global_transform = marker.global_transform
		if actor.mina_animation != null:
			actor.global_position = registry.to_global(place.approach)
			actor.mina_animation.set_motion(false)
		else:
			actor.global_position.y -= .478
			if not bool(actor.call("play_seated")): failures.append("personal seated clip missing: " + actor.resident_id)
		poses.append({"resident": actor.resident_id, "furniture": str(place.furniture), "reason": str(place.reason),
			"actor": str(actor.global_transform), "seat": str(marker.global_transform), "standing": actor.mina_animation != null})
	if identities.size() != 18 or (registry.get("claims") as Dictionary).size() != 18: failures.append("eighteen simultaneous distinct claims required")
	for i in actors.size():
		for j in range(i + 1, actors.size()):
			var a := actors[i].global_position; var b := actors[j].global_position
			if Vector2(a.x - b.x, a.z - b.z).length() < .60:
				failures.append("preferred body centres overlap: " + actors[i].resident_id + "/" + actors[j].resident_id)
	await root.get_tree().physics_frame
	await root.get_tree().physics_frame
	report["native_bearings"] = alcove_contacts(region, failures)
	for actor: AnimatedResident in actors:
		if actor.mina_animation == null: continue
		var capsule := CapsuleShape3D.new(); capsule.radius = .28; capsule.height = 1.65
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule; query.collision_mask = 1; query.margin = 0
		query.transform.origin = actor.global_position + Vector3.UP * .835
		var hits := root.get_world_3d().direct_space_state.intersect_shape(query, 8)
		if not hits.is_empty(): failures.append("Mina standing place blocked: " + str(hits))
	# A useful access preflight: the real standing player's dimensions, not a
	# shrunken review capsule, must fit along the occupied quiet alcove.
	var deck: Dictionary = {}
	for floor: Dictionary in region.source_layout.floors:
		if floor.id == "F01":
			for item: Dictionary in floor.furniture:
				if item.id == "retail_bar_deck_s": deck = item
	var aisle_points: Array = []
	if deck.is_empty(): failures.append("quiet alcove support owner missing")
	else:
		var rect: Array = deck.rect
		var radius := PlayerController.BODY_RADIUS
		var floor_y := float(deck.z0) + float(deck.h)
		var capsule := CapsuleShape3D.new(); capsule.radius = radius; capsule.height = PlayerController.STANDING_HEIGHT
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = capsule; query.collision_mask = 1; query.margin = 0
		# Stop at the actual last chair's approach, rather than walking past it
		# into the retained jukebox. Keep that original overrun failure archived.
		var last_place: Dictionary=registry.call("preferred","transient_guests")
		if last_place.is_empty():
			failures.append("last alcove resident has no registered approach")
			report["failures"]=failures;return report
		var target: Vector3=region.to_local(registry.to_global(last_place.approach))
		var entrance:=Vector2(float(rect[0])+radius+.025,float(rect[3])-radius-.07)
		var destination:=Vector2(target.x,-target.z)
		var turn_y:=destination.y+radius+.04
		var route: Array[Vector2]=[entrance,Vector2(entrance.x,turn_y),Vector2(destination.x,turn_y),destination]
		var samples: Array[Vector2]=[]
		for segment in route.size()-1:
			var count:=maxi(1,ceili(route[segment].distance_to(route[segment+1])/.08))
			for step in count:samples.append(route[segment].lerp(route[segment+1],float(step)/count))
		samples.append(destination)
		for sample: Vector2 in samples:
			var source_point := [sample.x, sample.y, floor_y]
			var point := region.to_global(GameBoot.b2g(source_point))
			query.transform.origin = point + Vector3.UP * (PlayerController.STANDING_HEIGHT * .5 + .015)
			var hits := root.get_world_3d().direct_space_state.intersect_shape(query, 8)
			if not hits.is_empty(): failures.append("full player alcove aisle blocked: " + str(source_point) + " " + str(hits))
			for actor: AnimatedResident in actors:
				if actor.mina_animation == null: continue
				var delta := actor.global_position - point
				if Vector2(delta.x, delta.z).length() < radius + .28: failures.append("alcove aisle overlaps standing resident")
			var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * .15, point - Vector3.UP * .15, 1))
			if hit.is_empty() or hit.position.distance_to(point) > .001: failures.append("alcove aisle lacks actual deck support")
			aisle_points.append(source_point)
	report["full_size_player_aisle_preflight"] = {"radius": PlayerController.BODY_RADIUS, "height": PlayerController.STANDING_HEIGHT, "source_points": aisle_points,
		"limit": "Static family access preflight only; actual controller input and composed-world access still require testing."}
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE; camera.fov = 72
	var views := [
		["west_tables", [-9.3,-33.9,-1.2], [-3.4,-35.4,-1.65]],
		["counter_and_lounge", [1.5,-31.35,-1.2], [-3.8,-33.7,-1.65]],
		["quiet_alcove", [1.9,-34.8,-1.15], [3.1,-36.1,-1.65]]]
	for view: Array in views:
		camera.global_position = region.to_global(GameBoot.b2g(view[1]))
		camera.look_at(region.to_global(GameBoot.b2g(view[2])))
		await root.get_tree().create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(directory.path_join("bar_" + str(view[0]) + ".png"))
	report["poses"] = poses
	report["failures"] = failures
	for failure: String in failures: print("[BAR RESIDENT REVIEW] FAIL ", failure)
	print("BAR RESIDENT REVIEW: ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	return report
