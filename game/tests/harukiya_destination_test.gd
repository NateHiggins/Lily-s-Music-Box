extends Node3D
## Nearby production-room proof. Initial placement is declared; thereafter the
## real player walks the authored graph. No full-world/crowd/save qualification.
const Motor := preload("res://tests/orison_v2_first_slice_contract_test.gd")
const Keyboard := preload("res://tests/seat_gesture_route_test.gd")
const SurfaceInventory := preload("res://tests/orison_v2_surface_inventory.gd")
const GeometryWitness := preload("res://tests/harukiya_destination_geometry.gd")
const SPEC := "res://data/orison_v2/harukiya_destination_layout.json"
const KIT := "res://data/orison_v2/harukiya_drumkit.json"
const FIXTURE_FIT := "res://tests/fixtures/orison_bar_fixture_mounts.json"
const FIXTURE_DATA := "res://data/orison_v2/bar_fixture_mounts.json"

var bar: OrisonV2BarRegion
var player: PlayerController
var destination: Node3D
var motor: Node
var keyboard: Node
var seat_gestures: Node3D
var spec: Dictionary = {}
var points: Dictionary = {}
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var contracts: Dictionary = {}
var details: Dictionary = {}
var captures: Array[Dictionary] = []
var initial_inputs: Dictionary = {}
var started := Time.get_ticks_msec()
var directory := ""
var preview_owned := false
var current_node := "entrance"
var prior_data: Dictionary
var prior_mode: int
var prior_mouse: int
var games_only := false
var stance_only := false

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"label": label, "ok": ok})
	if not ok: failures.append(label); push_error("HARUKIYA DESTINATION: " + label)
	return ok

func _begin_contract(name: String) -> int:
	contracts[name] = {"executed": true, "status": "FAIL"}
	return failures.size()

func _end_contract(name: String, before: int) -> void:
	contracts[name].status = "PASS" if failures.size() == before else "FAIL"

func _run() -> void:
	games_only = OS.get_environment("ORISON_HARUKIYA_GAMES_PREFLIGHT") == "1"
	stance_only = OS.get_environment("ORISON_HARUKIYA_ATTENDANCE_STANCE_PREFLIGHT") == "1"
	if stance_only: games_only = false
	directory = OS.get_environment("SHOT_DIR")
	if not _check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "explicit writable SHOT_DIR"):
		get_tree().quit(2); return
	initial_inputs = _input_snapshot()
	prior_data = RealityState.data
	prior_mode = GameBoot.launch_mode
	prior_mouse = Input.mouse_mode
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "save owner grants exclusive nonpersistent preview context"):
		await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(CampaignClock.new().configure_date(1929, 6, 14, 21 * 60), "private preview Friday evening clock")
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.035, .04, .05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.7, .72, .76)
	environment.environment.ambient_light_energy = .18
	add_child(environment)
	get_viewport().use_taa = true
	bar = OrisonV2BarRegion.new(); bar.name = "ProductionHarukiya"; add_child(bar)
	if not _check(not bar.startup_failed, "production bar mounts through its ordinary ready pipeline"):
		await _finish(); return
	destination = bar.get("destination") as Node3D
	if not _check(destination != null, "production destination owner exists"):
		await _finish(); return
	spec = destination.get("spec")
	if not _check(spec == JSON.parse_string(FileAccess.get_file_as_string(SPEC)), "loaded destination equals authored layout"):
		await _finish(); return
	for row: Dictionary in spec.navigation.nodes:
		_check(not points.has(str(row.id)), "unique navigation datum " + str(row.id))
		points[str(row.id)] = GameBoot.b2g(row.at)
	if not _check(points.has("entrance"), "declared nearby entrance start exists"):
		await _finish(); return
	current_node = "darts_interaction" if games_only else "entrance"
	if not _check(points.has(current_node), "declared nearby fixture start exists"): await _finish(); return
	player = PlayerController.new(); player.name = "Player"; add_child(player)
	player.global_position = bar.to_global(points[current_node]) + Vector3.UP * .02
	player.enable_low_step_probe(); player.camera.make_current(); player.set_mouse_released(false)
	motor = Motor.new(); motor.service_bench_only = true; add_child(motor)
	keyboard = Keyboard.new(); keyboard.externally_managed = true; keyboard.player = player; add_child(keyboard)
	seat_gestures = preload("res://scripts/player/seat_gestures.gd").new()
	seat_gestures.name = "SeatGestures"; add_child(seat_gestures)
	if not _check(bool(seat_gestures.call("mount_bar", bar)), "same production bar-seat gesture mount binds destination markers"):
		await _finish(); return
	player._grab.seat_lookup = Callable(seat_gestures, "aimed")
	keyboard.seats = seat_gestures
	var rig := LightRig.new(); rig.name = "LightRig"; add_child(rig)
	await get_tree().physics_frame; await get_tree().physics_frame
	player.set_physics_process(false)
	details["fixture"] = {"initial_node": current_node, "initial_bar_feet": points[current_node], "games_only": games_only,
		"real_motor": true, "low_step_probe": true, "noclip": false, "collision_mask": player.collision_mask,
		"lighting": "Production LightRig and authored practicals; neutral ambient 0.18, no exterior sky/crowd.", "taa": get_viewport().use_taa}
	_check(DisplayServer.get_name() != "headless", "actual renderer required for this destination proof")
	if stance_only:
		_attendance_stance()
		await _finish(); return
	if games_only:
		await _games()
		await _finish(); return
	_native_surfaces()
	_retirement()
	_seats()
	_kit_and_architecture()
	await _capture("front", [-2.0, -35.0, -.9])
	if failures.is_empty(): await _route()
	await _finish()

func _attendance_stance() -> void:
	var before := _begin_contract("destination_attendance_obstruction_stance")
	var place: Dictionary = bar.resident_places.preferred("juno_kells")
	if not _check(not place.is_empty(), "installed Juno counter place exists"):
		_end_contract("destination_attendance_obstruction_stance", before); return
	var approach: Vector3 = bar.resident_places.to_global(place.approach)
	var initial_positions: Array[Vector3] = [approach]
	var result: Dictionary = preload("res://tests/harukiya_attendance_test.gd").blocking_stance(bar, player, place, initial_positions)
	details.initial_stance = result
	_check(result.candidate != Vector3.INF, "installed counter has a supported nonoverlapping initial player stance that blocks the later seat approach")
	_end_contract("destination_attendance_obstruction_stance", before)

func _native_surfaces() -> void:
	var before := _begin_contract("destination_native_uv_pbr_mips")
	var inventory := SurfaceInventory.new()
	var rows: Array = []
	for draw: MeshInstance3D in destination.find_children("*", "MeshInstance3D", true, false):
		if draw.mesh == null or not draw.is_visible_in_tree(): continue
		var mesh_row: Dictionary = inventory._mesh(draw.mesh)
		for index in draw.mesh.get_surface_count():
			var streams := draw.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = streams[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = streams[Mesh.ARRAY_TEX_UV] if streams[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var tangents: PackedFloat32Array = streams[Mesh.ARRAY_TANGENT] if streams[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var indices: PackedInt32Array = streams[Mesh.ARRAY_INDEX] if streams[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for v in vertices.size(): indices.append(v)
			var row: Dictionary = mesh_row.surfaces[index]
			var label := str(draw.name) + "/" + str(index)
			var stream_ok: bool = not row.missing_uv and row.nonfinite_uv == 0 and row.degenerate_uv_triangles == 0 and tangents.size() == vertices.size() * 4
			_check(stream_ok, label + " imported UV/tangent streams")
			var stretch := 0.0
			if stream_ok:
				for face in range(0, indices.size() - 2, 3):
					for pair: Array in [[indices[face], indices[face+1]], [indices[face+1], indices[face+2]], [indices[face+2], indices[face]]]:
						var span := vertices[pair[0]].distance_to(vertices[pair[1]])
						if span > 1e-7: stretch = maxf(stretch, absf(uv[pair[0]].distance_to(uv[pair[1]]) / span - 1.0))
				_check(stretch <= .005, label + " native metre charts within 0.5 percent")
			var material := draw.mesh.surface_get_material(index) as StandardMaterial3D
			var maps_ok := material != null and not material.uv1_triplanar and material.normal_enabled
			if material != null:
				for texture: Texture2D in [material.albedo_texture, material.roughness_texture, material.normal_texture]:
					maps_ok = maps_ok and texture != null and texture.get_image() != null and texture.get_image().has_mipmaps()
				maps_ok = maps_ok and material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]
			_check(maps_ok, label + " native mapped albedo roughness normal and mip filtering")
			var active := draw.get_active_material(index)
			_check(active != null, label + " active rendered material")
			rows.append({"draw": str(draw.get_path()), "surface": index, "mesh": row, "max_edge_stretch": stretch,
				"material": inventory._material(active) if active != null else {}})
	_check(not rows.is_empty(), "new destination and kit actually submit native mesh surfaces")
	details["native_surfaces"] = rows; details["textures"] = inventory.texture_rows.duplicate(true)
	inventory.free()
	_end_contract("destination_native_uv_pbr_mips", before)

func _retirement() -> void:
	var before := _begin_contract("destination_retired_stock")
	# Production must publish source-face accounting. Absence of a mesh name
	# alone cannot demonstrate removal of a source object in a material batch.
	var audit: Variant = destination.get("retirement_audit")
	if _check(audit is Dictionary and not audit.is_empty(), "production publishes nonempty retired source-face accounting"):
		details["retirement"] = audit.duplicate(true)
		_check(bool(audit.get("verified", false)), "production removed both retired render and collision stock")
		var ids: Array = audit.get("source_ids", [])
		var required_ids: Array = spec.retire_ids.duplicate()
		for component: Dictionary in spec.get("retire_components", []):
			if str(component.id) not in required_ids: required_ids.append(str(component.id))
		_check(ids.size() == required_ids.size(), "retirement accounts for every authored source owner and partial component")
		for identity: String in required_ids:
			_check(identity in ids, "retirement source present " + identity)
		_check(int(audit.get("removed_render_triangles", 0)) > 0 and int(audit.get("removed_collision_triangles", 0)) > 0, "retirement has positive render and collision removals")
		_check(int(audit.get("remaining_retired_render_triangles", -1)) == 0 and int(audit.get("remaining_retired_collision_triangles", -1)) == 0, "live renderer and collider contain no retired source triangles")
	var witness := GeometryWitness.new()
	var independent: Dictionary = witness.retirement(bar.get_node("RetainedBarGeometry"))
	details["retirement_independent"] = independent
	_check(independent.errors.is_empty() and independent.remaining_render_triangles == 0 and independent.remaining_collision_triangles == 0,
		"independent loaded-buffer rescan detects no retired render or collision triangles: " + str(independent.errors))
	_check(int(independent.unmodified_original_negative_control_hits) > 0,
		"independent scanner rejects untouched original stock as a retirement negative control")
	var old_native: Array[Node] = []
	var cafe := bar.get_node_or_null("RetainedBarGeometry/BarCafeSeating")
	if cafe != null: old_native.append(cafe)
	for draw: MeshInstance3D in bar.find_children("*", "MeshInstance3D", true, false):
		if draw.has_meta("bar_resident_assembly"): old_native.append(draw)
	for node: Node in old_native:
		var draws := node.find_children("*", "GeometryInstance3D", true, false)
		if node is GeometryInstance3D: draws.append(node)
		for draw: GeometryInstance3D in draws:
			_check(not draw.is_visible_in_tree(), "retired native group does not render " + str(draw.get_path()))
		for shape: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
			_check(shape.disabled, "retired native group has no enabled collider " + str(shape.get_path()))
	_end_contract("destination_retired_stock", before)

func _seat_sockets() -> Dictionary:
	var result := {}
	var parent := destination.get_node_or_null("SeatSockets")
	if parent == null: return result
	for node in parent.get_children():
		if node is Marker3D:
			var identity := str(node.get_meta("destination_seat_id", node.name))
			_check(not result.has(identity), "unique loaded seat identity " + identity)
			result[identity] = node
	return result

func _seats() -> void:
	var before := _begin_contract("destination_twenty_four_supported_seats")
	var sockets := _seat_sockets()
	_check(spec.seats.size() == 24 and sockets.size() == 24, "twenty-four authored and loaded player seat sockets")
	var excluded: Array[RID] = [player.get_rid()]
	var witness := GeometryWitness.new()
	var unique := {}; var centers: Array[Vector3] = []; var rows: Array = []
	for seat: Dictionary in spec.seats:
		var identity := str(seat.id)
		_check(not unique.has(identity), "unique authored seat " + identity); unique[identity] = true
		var at := bar.to_global(GameBoot.b2g(seat.at))
		for prior: Vector3 in centers:
			_check(at.distance_to(prior) >= .45, "physical seat centers do not coincide " + identity)
		centers.append(at)
		if not _check(sockets.has(identity), "loaded socket matches " + identity): continue
		var socket: Marker3D = sockets[identity]
		_check(socket.global_position.distance_to(at) < .002, "seat socket fits authored support datum " + identity)
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * .12, at - Vector3.UP * .15, 1, excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var gap: float = INF if hit.is_empty() else absf(hit.position.y - at.y)
		_check(not hit.is_empty() and gap <= .035 and hit.normal.y > .8, "actual collision supports seat " + identity)
		var rendered: Dictionary = witness.visible_support(bar, at)
		_check(not rendered.is_empty() and float(rendered.get("gap_m", INF)) <= .035, "actual rendered geometry supports seat " + identity)
		var approach := bar.to_global(GameBoot.b2g(seat.approach))
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(approach + Vector3.UP * .15, approach - Vector3.UP * .15, 1, excluded))
		_check(not floor_hit.is_empty() and absf(floor_hit.position.y - approach.y) < .025, "seat approach has actual floor " + identity)
		var overlaps := _capsule_hits(approach, excluded)
		_check(overlaps.is_empty(), "standing player clears seat approach " + identity)
		rows.append({"id": identity, "support": seat.support, "collision_gap_m": gap,
			"seat_hit": _hit_record(hit), "rendered_support": rendered, "approach_hit": _hit_record(floor_hit),
			"approach_world": approach, "approach_overlap_count": overlaps.size(), "approach_overlaps": _overlap_records(overlaps)})
	details["seats"] = rows
	_end_contract("destination_twenty_four_supported_seats", before)

func _capsule_hits(feet: Vector3, excluded: Array[RID]) -> Array:
	var capsule := CapsuleShape3D.new(); capsule.radius = PlayerController.BODY_RADIUS; capsule.height = PlayerController.STANDING_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = capsule; query.collision_mask = 1; query.margin = 0
	query.exclude = excluded; query.transform.origin = feet + Vector3.UP * (capsule.height * .5 + .015)
	return get_world_3d().direct_space_state.intersect_shape(query, 32)

func _hit_record(hit: Dictionary) -> Dictionary:
	if hit.is_empty(): return {}
	return {"collider": str(hit.collider.get_path()), "at": hit.position, "normal": hit.normal}

func _overlap_records(hits: Array) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for hit: Dictionary in hits:
		var collider := hit.get("collider") as CollisionObject3D
		if collider == null:
			records.append({"collider_id":hit.get("collider_id"),"shape_index":hit.get("shape")}); continue
		var shape_index := int(hit.get("shape",-1))
		var row := {"collider":str(collider.get_path()),"collider_class":collider.get_class(),
			"at":collider.global_position,"transform":collider.global_transform,"shape_index":shape_index,
			"collision_layer":collider.collision_layer,"collision_mask":collider.collision_mask}
		if shape_index >= 0:
			var owner_id := collider.shape_find_owner(shape_index)
			var owner: Object = collider.shape_owner_get_owner(owner_id)
			if owner is Node: row["shape_owner"] = str(owner.get_path())
			if owner is Node3D: row["shape_at"] = owner.global_position; row["shape_transform"] = owner.global_transform
			if owner is CollisionShape3D:
				row["shape_type"] = owner.shape.get_class() if owner.shape != null else "null"
				row["disabled"] = owner.disabled
		records.append(row)
	return records

func _kit_and_architecture() -> void:
	var before := _begin_contract("destination_kit_stage_backstage_balcony")
	var kit := destination.get_node_or_null("HarukiyaDrumKit") as Node3D
	_check(kit != null, "production destination contains full native drum kit")
	for part: String in ["stage", "backstage", "balcony", "stair"]:
		_check(spec.architecture.has(part), "authored " + part + " architecture")
	_check(points.has("stage_front") and points.has("backstage") and points.has("gallery_return"), "stage backstage and far balcony have route datums")
	if kit != null:
		var kit_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT))
		_check(kit.global_position.distance_to(bar.to_global(GameBoot.b2g(spec.drumkit.at))) < .002, "full kit fitted to authored stage anchor")
		details["kit"] = {"source_sha256": FileAccess.get_sha256(KIT), "at": kit.global_position,
			"draws": kit.find_children("*", "MeshInstance3D", true, false).size(), "spec_keys": kit_spec.keys()}
		var loaded := {}; var total_triangles := 0
		for draw: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
			var identity := str(draw.get_meta("harukiya_drum_part", ""))
			_check(not identity.is_empty() and not loaded.has(identity), "unique native kit source partition " + identity)
			loaded[identity] = draw
			if draw.mesh != null: total_triangles += draw.mesh.get_faces().size() / 3
		_check(loaded.size() == kit_spec.partitions.size(), "every native kit partition is present")
		for partition: Dictionary in kit_spec.partitions:
			if not _check(loaded.has(str(partition.mesh)), "native kit partition " + str(partition.mesh)): continue
			var draw: MeshInstance3D = loaded[str(partition.mesh)]
			_check(draw.is_visible_in_tree() and draw.mesh.get_faces().size() == int(partition.triangles) * 3, "full native kit partition visible and complete " + str(partition.mesh))
		_check(total_triangles <= 35000, "loaded kit remains within its native triangle budget")
		var excluded: Array[RID] = [player.get_rid()]
		for body: PhysicsBody3D in kit.find_children("*", "PhysicsBody3D", true, false): excluded.append(body.get_rid())
		for foot: Dictionary in kit_spec.floor_supports:
			var p: Array = foot.floor_contact
			var at := kit.to_global(Vector3(p[0], p[1], p[2]))
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * .06, at - Vector3.UP * .06, 1, excluded))
			_check(not hit.is_empty() and hit.position.distance_to(at) < .005, "actual stage supports kit foot " + str(foot.id))
	_pool_light_fit()
	_end_contract("destination_kit_stage_backstage_balcony", before)

func _pool_light_fit() -> void:
	# Independently transform the original source witnesses. Do not call the
	# destination's relocation helper or accept its own successful-mount flag.
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_FIT))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_DATA))
	var move: Dictionary = spec.relocations.pool
	var turn := Basis(Vector3.UP,deg_to_rad(float(move.get("source_yaw_delta_deg",move.get("yaw_deg",0.0)))))
	var shift := Transform3D(turn,GameBoot.b2g(move.at)-turn*GameBoot.b2g(move.source_anchor))
	var original_lights := {}; var source_pool: Dictionary = {}
	for marker: Dictionary in fixture.original_markers:
		original_lights[str(marker.id)] = marker
		if str(marker.id) == "F01_BAR_LT_POOL": source_pool = marker
	var loaded_lights := {}; var light_count := 0
	for node: Node in bar.actors.get_children():
		if node is not LightFixtureProp: continue
		loaded_lights[str(node.name)] = node
		light_count += node.find_children("*","Light3D",true,false).size()
	_check(original_lights.size() == 18 and loaded_lights.size() == 18 and light_count == 36,
		"pool relocation retains eighteen original fixture owners and their thirty-six primary/bounce lights")
	for identity: String in original_lights:
		if not _check(loaded_lights.has(identity),"original light owner survives destination " + identity): continue
		var actor: LightFixtureProp = loaded_lights[identity]
		var marker: Dictionary = original_lights[identity]
		_check(actor.prop_type == str(marker.kind) and actor.range_clamp == float(marker.get("range",0.0))
			and actor.energy_scale == float(marker.get("energy",1.0)) and actor.standby_scale == float(marker.get("standby",0.0))
			and actor.navigation_light == bool(marker.get("navigation",false)),"original light settings survive destination " + identity)
	if not _check(not source_pool.is_empty() and loaded_lights.has("F01_BAR_LT_POOL"),"one original pool light datum and owner"): return
	var pool_light: LightFixtureProp = loaded_lights.F01_BAR_LT_POOL
	var original_actor := Transform3D(Basis(Vector3.UP,-deg_to_rad(float(source_pool.get("yaw_deg",0.0)))),GameBoot.b2g(source_pool.pos))
	var expected_actor := bar.global_transform*shift*original_actor
	_check(pool_light.global_transform.is_equal_approx(expected_actor),"pool light follows the exact declared pool relocation")
	var cell := bar.get_node("RetainedBarGeometry") as Node3D
	var mounts := cell.get_node("BarFixtureMounts") as Node3D
	var raw := (load(str(data.asset)) as PackedScene).instantiate() as Node3D
	_check(FileAccess.get_sha256(str(data.asset)) == str(fixture.asset_sha256),"pool support witness binds unchanged original native asset")
	var support_rows: Array = []; var excluded: Array[RID] = [player.get_rid()]
	for body: CollisionObject3D in mounts.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
	for identity: String in ["F01_BAR_LT_POOL__brass_dull","F01_BAR_LT_POOL__iron_blackened"]:
		var originals: Array = raw.find_children(identity,"MeshInstance3D",true,false)
		var actuals: Array = mounts.find_children("*","MeshInstance3D",true,false).filter(func(draw): return str(draw.get_meta("bar_fixture_mount_part","")) == identity)
		if not _check(originals.size() == 1 and actuals.size() == 1,"one original and one live pool support partition " + identity): continue
		var original: MeshInstance3D = originals[0]; var actual: MeshInstance3D = actuals[0]
		var expected := cell.global_transform*shift*_relative_transform(original,raw)
		_check(actual.global_transform.is_equal_approx(expected) and actual.is_visible_in_tree()
			and actual.mesh.get_faces() == original.mesh.get_faces(),"original native pool support geometry follows exact pool frame " + identity)
		var shapes: Array = actual.find_children("*","CollisionShape3D",true,false)
		_check(shapes.size() == 1,"one native pool support collision owner " + identity)
		for shape: CollisionShape3D in shapes:
			var collision_mesh := shape.shape as ConcavePolygonShape3D
			_check(not shape.disabled and collision_mesh != null and shape.global_transform.is_equal_approx(actual.global_transform)
				and collision_mesh.get_faces() == actual.mesh.get_faces(),"relocated pool support collider equals visible native faces " + identity)
		support_rows.append({"identity":identity,"draw":str(actual.get_path()),"actual":actual.global_transform,"expected":expected,"triangles":actual.mesh.get_faces().size()/3})
	raw.free()
	var contacts: Array = fixture.contacts.filter(func(row): return str(row.id) == "F01_BAR_LT_POOL")
	var bearing_rows: Array = []
	if _check(contacts.size() == 1,"original pool suspension has one measured bearing"):
		var contact: Dictionary = contacts[0]
		var p: Array = contact.bearing; var q: Array = contact.fixture_endpoint
		var bearing := cell.to_global(shift*Vector3(p[0],p[1],p[2]))
		var endpoint := cell.to_global(shift*Vector3(q[0],q[1],q[2]))
		_check(pool_light.global_position.distance_to(endpoint) < .000001,"native suspension endpoint meets relocated pool actor")
		for x: float in [-.044,-.022,0.,.022,.044]:
			for z: float in [-.044,-.022,0.,.022,.044]:
				var at := bearing+cell.global_basis*turn*Vector3(x,0,z)
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at-Vector3.UP*.02,at+Vector3.UP*.02,1,excluded))
				var gap: float = INF if hit.is_empty() else hit.position.distance_to(at)
				_check(not hit.is_empty() and gap < .00003 and cell.is_ancestor_of(hit.collider),"retained ceiling supports relocated pool bearing " + str(Vector2(x,z)))
				bearing_rows.append({"at":at,"gap_m":gap,"hit":_hit_record(hit)})
	details["pool_light_relocation"] = {"original_source":source_pool,"declared_relocation":move,"light_owners":loaded_lights.keys(),
		"light_count":light_count,"actual_actor":pool_light.global_transform,"expected_actor":expected_actor,
		"native_asset_sha256":FileAccess.get_sha256(str(data.asset)),"supports":support_rows,"bearing_samples":bearing_rows}

func _relative_transform(node: Node3D, frame: Node3D) -> Transform3D:
	var result := node.transform; var parent := node.get_parent()
	while parent != null and parent != frame:
		if parent is Node3D: result = parent.transform*result
		parent = parent.get_parent()
	return result

func _path(from_id: String, to_id: String) -> Array[String]:
	var queue: Array[String] = [from_id]; var previous := {from_id: ""}
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == to_id: break
		for edge: Array in spec.navigation.edges:
			var other := ""
			if str(edge[0]) == here: other = str(edge[1])
			elif str(edge[1]) == here: other = str(edge[0])
			if other.is_empty() or previous.has(other): continue
			previous[other] = here; queue.append(other)
	var result: Array[String] = []
	if not previous.has(to_id): return result
	var here := to_id
	while here != from_id: result.push_front(here); here = str(previous[here])
	return result

func _go(to_id: String) -> bool:
	if current_node == to_id: return true
	var route := _path(current_node, to_id)
	if not _check(not route.is_empty(), "authored connected route " + current_node + " -> " + to_id): return false
	for identity: String in route:
		if not await _walk(points[identity], identity): return false
		current_node = identity
	return true

func _walk(local: Vector3, label: String) -> bool:
	var passed: bool = await motor._walk_service_player(player, bar, local)
	return _check(passed, "actual production motor reaches " + label)

func _route() -> void:
	var before := _begin_contract("destination_nearby_motor_routes")
	if not await _go("backstage"): return
	await _capture("backstage", [1.6, -36.9, -1.55])
	if not await _go("stage_front"): return
	await _capture("stage", [-1.7, -36.65, -1.8])
	if not await _go("entrance"): return
	if not await _go("counter_e"): return
	await _seat_input()
	if not failures.is_empty(): return
	if not await _go("stair_lower"): return
	await _blocked_stair()
	if not failures.is_empty(): return
	if not await _go("gallery_return"): return
	await _capture("balcony", [-2.0, -35.8, -1.4])
	if not await _go("stair_lower"): return
	if not await _go("darts_oche"): return
	await _capture("playarea", [-8.0, -32.4, -1.3])
	_end_contract("destination_nearby_motor_routes", before)
	await _games()

func _blocked_stair() -> void:
	var before := _begin_contract("destination_blocked_stair_negative_control")
	var target: Vector3 = points.balcony_tread_01
	var blocker := StaticBody3D.new(); blocker.name = "TestOnlyBlockedStair"; add_child(blocker)
	# Reach the ground and stand just ahead of the native first riser. The old
	# raised, thin box denied step-up, leaving the slide contact on the riser.
	blocker.global_position = bar.to_global(Vector3(target.x, points.stair_lower.y, target.z)) + Vector3.UP * .9
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(1.06, 1.8, .4); shape.shape = box; blocker.add_child(shape)
	await get_tree().physics_frame; await get_tree().physics_frame
	var initial_overlap := false
	for hit: Dictionary in _capsule_hits(player.global_position, [player.get_rid()]):
		if hit.collider == blocker: initial_overlap = true
	_check(not initial_overlap, "temporary stair obstruction starts clear of the actual player capsule")
	var delta := bar.to_global(target) - player.global_position
	player.rotation.y = atan2(-delta.x, -delta.z); player.camera.rotation = Vector3.ZERO; player.set_physics_process(true)
	Input.action_press("move_forward")
	var encountered := false
	for frame in 90:
		await get_tree().physics_frame
		for index in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_collider() == blocker: encountered = true
	Input.action_release("move_forward"); player.velocity = Vector3.ZERO; player.set_physics_process(false)
	var blocked_distance := Vector2(player.global_position.x - blocker.global_position.x, player.global_position.z - blocker.global_position.z).length()
	_check(encountered and blocked_distance > PlayerController.BODY_RADIUS and not player.noclip and player.collision_mask == 1, "actual motor is stopped by temporary stair obstruction")
	details["blocked_stair"] = {"encountered_actual_body": encountered, "initial_overlap": initial_overlap,
		"blocker_at": bar.to_local(blocker.global_position), "blocker_size": box.size, "distance_m": blocked_distance, "physics_frames": 90}
	blocker.free(); await get_tree().physics_frame
	_end_contract("destination_blocked_stair_negative_control", before)

func _use(owner_node: Node3D, at: Vector3, label: String) -> bool:
	player.camera.look_at(at); await get_tree().process_frame
	var eye := player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(eye, eye - player.camera.global_basis.z * 2.1)
	ray.collide_with_areas = true; ray.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var matched := false
	if not hit.is_empty():
		var node: Node = hit.collider
		while node != null:
			if node == owner_node: matched = true; break
			node = node.get_parent()
	player._update_prompt()
	if not _check(matched and not player._prompt.text.is_empty(), label + " camera ray reaches actual owner; hit=" + str(_hit_record(hit))): return false
	# The production prompt advertises primary CLICK; E is no longer mapped
	# to this interaction. Exercise the same real player input as seat grips.
	await keyboard._click()
	await get_tree().process_frame
	return true

func _game_key(code: Key) -> void:
	# Polling happens in the player's _process. Start after the rendered frame,
	# flush the real key event, and hold it across complete process frames.
	await RenderingServer.frame_post_draw
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

func _game_state(owner_node: Node3D) -> Dictionary:
	return {"panel_valid": is_instance_valid(owner_node.get("_panel")), "call_locked": player.call_locked,
		"mouse_mode": Input.mouse_mode, "mouse_released": player.mouse_released, "prompt": player._prompt.text,
		"grip_active": player._grab.active(), "process_frame": Engine.get_process_frames()}

func _seat_input() -> void:
	var before := _begin_contract("destination_seat_input_and_reservation")
	var sockets := _seat_sockets()
	var registry := bar.resident_places
	var selected := ""; var identity := ""
	for resident: String in registry.places:
		var candidate: Dictionary = registry.call("preferred", resident)
		var key := str(candidate.get("seat_id", ""))
		if key.begins_with("counter_") and sockets.has(key): selected = key; identity = resident; break
	if not _check(not selected.is_empty(), "resident registry binds an actual counter seat socket"): return
	var seat_spec: Dictionary = spec.seats.filter(func(row): return str(row.id) == selected)[0]
	var approach := GameBoot.b2g(seat_spec.approach)
	# Follow the declared counter aisle before approaching the selected socket.
	if approach.x < -2.0 and not await _go("counter_w"): return
	if not await _walk(approach, selected + " approach"): return
	var socket: Marker3D = sockets[selected]
	player.set_physics_process(true)
	await get_tree().physics_frame; await get_tree().physics_frame
	var actor := Node3D.new(); actor.name = "ReservationOnlyProbe"; add_child(actor)
	_check(bool(registry.call("reserve", identity, actor)), "resident reservation takes the real player seat")
	var prior := player.global_transform
	var grip: Dictionary = await keyboard._aim_seat(selected)
	_check(grip.get("part") != socket, "reserved seat is absent from the actual player's grip lookup")
	await keyboard._click()
	_check(player.seated_on == null and player.global_position.distance_to(prior.origin) < .025 and not player.call_locked,
		"actual click on reserved seat cannot descend or lock the player")
	if player._grab.active(): await keyboard._click()
	_check(bool(registry.call("release", identity, actor)), "resident releases seat through its ordinary registry authority")
	actor.free()
	grip = await keyboard._aim_seat(selected)
	if not _check(grip.get("owner") == seat_gestures and grip.get("part") == socket, "released destination seat is found by actual grip ray"): return
	await keyboard._click()
	_check(player._grab.active() and player.global_position.distance_to(prior.origin) < .025, "first click grips without teleporting the player")
	await keyboard._drag(190.0)
	await keyboard._click()
	await get_tree().create_timer(.3).timeout
	_check(bool(seat_gestures.call("sitting")) and player.seated_on == seat_gestures and not player.call_locked,
		"mouse descent and release sits through production gesture authority")
	_check(absf(player.camera.global_position.y - socket.global_position.y - .62) < .015, "seated eye fits actual destination support")
	grip = await keyboard._aim_seat(selected)
	if not _check(grip.get("part") == socket, "seated player can reacquire the same seat to rise"): return
	await keyboard._click(); await keyboard._drag(-190.0); await keyboard._click()
	await get_tree().create_timer(.3).timeout
	_check(player.seated_on == null and not player._grab.active() and player.global_position.distance_to(prior.origin) < .025,
		"upward mouse gesture releases seat and restores original approach")
	player.set_physics_process(false)
	# Return to the existing graph node without inventing a transport shortcut.
	if not await _walk(points[current_node], current_node + " return"): return
	_end_contract("destination_seat_input_and_reservation", before)

func _games() -> void:
	var before := _begin_contract("destination_original_games_cancel_reopen")
	var darts := bar.actors.get_node_or_null("F01_BAR_DARTS") as DartsProp
	var pool := bar.actors.get_node_or_null("F01_BAR_POOL") as PointBallProp
	if not _check(darts != null and pool != null, "original darts and Point Ball owners survive relocation"): return
	# The rules' throwing line is not an interaction shortcut: walk toward the
	# actual pot/chalk owners and let the ordinary 2.1 m ray resolve them.
	for entry: Array in [[darts, "darts", Vector3(0, .05, 0)], [pool, "pool", Vector3(0, .018, 0)]]:
		var owner_node: Node3D = entry[0]; var label: String = entry[1]
		var approach_id := label + "_interaction"
		if not _check(points.has(approach_id), "authored clear interaction approach " + approach_id): return
		if not await _go(approach_id): return
		for attempt in 2:
			if not await _use(owner_node, owner_node.to_global(entry[2]), label + " open " + str(attempt + 1)): return
			details[label + "_open_" + str(attempt + 1)] = _game_state(owner_node)
			_check(is_instance_valid(owner_node.get("_panel")) and player.call_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, label + " ordinary input opens original panel and locks movement")
			await _game_key(KEY_ESCAPE)
			details[label + "_close_" + str(attempt + 1)] = _game_state(owner_node)
			_check(owner_node.get("_panel") == null and not player.call_locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, label + " Escape cancels original panel and restores control")
	_end_contract("destination_original_games_cancel_reopen", before)

func _capture(label: String, source_look: Array) -> void:
	player.camera.look_at(bar.to_global(GameBoot.b2g(source_look)))
	await get_tree().create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := directory.path_join(label + ".png")
	_check(image != null and image.get_width() > 0 and image.save_png(path) == OK, "capture actual player view " + label)
	captures.append({"label": label, "path": path, "sha256": FileAccess.get_sha256(path), "player": bar.to_local(player.global_position), "camera": player.camera.global_transform,
		"classification": "native rendered technical review; artistic acceptance pending"})

func _test_dependencies() -> Dictionary:
	var pending: Array[String] = [get_script().resource_path, scene_file_path]
	var result := {}; var references := RegEx.new()
	references.compile("res://tests/[A-Za-z0-9_/.-]+\\.[A-Za-z0-9]+(?=[\"'])")
	while not pending.is_empty():
		var path: String = pending.pop_back(); var key := "game/" + path.trim_prefix("res://")
		if result.has(key): continue
		if not _check(FileAccess.file_exists(path), "transitive test dependency exists " + path): continue
		var source := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		result[key] = source.sha256_text()
		for found: RegExMatch in references.search_all(source):
			if not result.has("game/" + found.get_string().trim_prefix("res://")): pending.append(found.get_string())
	return result

func _input_snapshot() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array = []; var physical: Array = []
	_check(OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], runtime) == 0, "bind runtime input signature")
	_check(OS.execute("python", [root.path_join("tools/v2_physical_inputs.py"), "--root", root], physical) == 0, "bind physical input signature")
	return {"runtime": str(runtime[0]).strip_edges() if not runtime.is_empty() else "",
		"physical": str(physical[0]).strip_edges() if not physical.is_empty() else "", "dependencies": _test_dependencies(),
		"test": FileAccess.get_sha256(get_script().resource_path), "scene": FileAccess.get_sha256(scene_file_path)}

func _finish() -> void:
	Input.action_release("move_forward"); Input.action_release("interact")
	if player != null:
		player.set_physics_process(false)
		for owner_id: String in ["F01_BAR_DARTS", "F01_BAR_POOL"]:
			var owner_node: Node = bar.actors.get_node_or_null(owner_id) if bar != null and bar.actors != null else null
			if owner_node != null and is_instance_valid(owner_node.get("_panel")): await _game_key(KEY_ESCAPE)
	if motor != null: details["motor_trace"] = motor.service_travel.duplicate(true)
	# Release held input while its production targets are still alive. Teardown
	# must not turn a failed seating check into an invalid-instance cascade.
	if player != null and player._grab != null and player._grab.active(): player._grab.release()
	if player != null: player.free(); player = null
	if seat_gestures != null: seat_gestures.free(); seat_gestures = null
	if bar != null: bar.shutdown(); bar.free(); bar = null
	await get_tree().process_frame
	if preview_owned:
		_check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "save owner restores original campaign context")
		preview_owned = false
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse
	var final_inputs := _input_snapshot()
	_check(final_inputs == initial_inputs, "runtime physical and transitive test inputs remain frozen")
	_check(str(final_inputs.runtime).length() == 64 and str(final_inputs.physical).length() == 64, "complete provenance signatures")
	var root := ProjectSettings.globalize_path("res://..").simplify_path(); var head: Array = []
	_check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0 and not head.is_empty(), "repository provenance")
	var expected := ["destination_native_uv_pbr_mips", "destination_retired_stock", "destination_twenty_four_supported_seats", "destination_kit_stage_backstage_balcony", "destination_nearby_motor_routes", "destination_blocked_stair_negative_control", "destination_seat_input_and_reservation", "destination_original_games_cancel_reopen"]
	if games_only: expected = ["destination_original_games_cancel_reopen"]
	if stance_only: expected = ["destination_attendance_obstruction_stance"]
	for name: String in expected:
		if not contracts.has(name): contracts[name] = {"executed": false, "status": "FAIL"}
		_check(bool(contracts[name].executed) and contracts[name].status == "PASS", "required contract " + name)
	if not games_only and not stance_only: _check(captures.size() == 5, "five actual player views captured")
	var passed := failures.is_empty()
	var receipt := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
		"scope": "Nearby production OrisonV2BarRegion and real PlayerController: destination UV/PBR/mips, independent source-face retirement scan, 24 supported markers, actual grip/motion/release seating and reservation denial, motor stage/backstage/balcony round trip and blocked stair, original game cancel/reopen. Declared initial entrance placement, isolated nonpersistent context, production LightRig with neutral ambient. No street-to-bar, full-world/crowd/performance, save reconstruction, native-art or artistic acceptance claim.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"test_path": "game/" + get_script().resource_path.trim_prefix("res://"), "test_sha256": final_inputs.test,
			"test_scene_path": "game/" + scene_file_path.trim_prefix("res://"), "test_scene_sha256": final_inputs.scene,
			"test_dependencies": final_inputs.dependencies, "repository_head": str(head[0]).strip_edges() if not head.is_empty() else "",
			"runtime_inputs_sha256": final_inputs.runtime, "physical_inputs_sha256": final_inputs.physical},
		"contracts": contracts, "checks": checks, "failures": failures, "details": details, "captures": captures,
		"viewport": {"width": get_viewport().get_visible_rect().size.x, "height": get_viewport().get_visible_rect().size.y}}
	if games_only:
		receipt.scope = "Nearby games-only preflight: production bar, actual PlayerController, real primary-click/Escape input opens/cancels/reopens original darts and pool panels; ordinary motor between authored interaction stations. Declared initial darts-interaction placement. No full destination route, seat, surface, crowd, save reconstruction or artistic acceptance."
	if stance_only:
		receipt.scope = "Nearby initial-stance geometry preflight only: installed production Harukiya, real full-size player capsule, collision-layer-1 overlap and floor-support queries at bounded socket-derived candidates, start and future-approach distances. Does not execute or qualify NPC attendance, player withdrawal, full-world composition, save behavior or artistic acceptance."
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: push_error("destination receipt could not open"); get_tree().quit(2); return
	file.store_string(JSON.stringify(receipt, "\t")); file.flush()
	var write_ok := file.get_error() == OK; file.close()
	print("HARUKIYA DESTINATION: ", "PASS" if passed and write_ok else "FAIL", " checks=", checks.size(), " failures=", failures.size())
	get_tree().quit(0 if passed and write_ok else 1)
