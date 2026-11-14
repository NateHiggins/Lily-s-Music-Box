extends "res://tests/harukiya_destination_test.gd"
## Nearby native backstage/stage access with unchanged full-body motors.
## Reuses existing graph walker and real PlayerController service motor only.
const ResidentRoute := preload("res://scripts/characters/orison_v2_resident_route.gd")
const ResidentBarRoute := preload("res://scripts/characters/orison_v2_bar_route.gd")
const ResidentPresentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const Motion := preload("res://tests/harukiya_attendance_test.gd")
var bar_region: OrisonV2BarRegion
var campaign_clock := CampaignClock.new()
var adapter: OrisonV2AnchorAdapter
var npc: Node3D
var npc_before := Vector3.ZERO
var npc_watch := false
var log_capture
var bound_sources: Dictionary = {}
const BOUND := ["res://tests/harukiya_backstage_access_test.gd",
	"res://tests/HarukiyaBackstageAccessTest.tscn", "res://tests/harukiya_destination_test.gd",
	"res://tests/orison_v2_first_slice_contract_test.gd", "res://tests/harukiya_attendance_test.gd",
	"res://scripts/characters/orison_v2_resident_route.gd", "res://scripts/characters/orison_v2_bar_route.gd",
	"res://scripts/characters/orison_v2_bar_visit.gd", "res://scripts/characters/orison_v2_resident_presentation.gd",
	"res://scripts/characters/animated_resident.gd", "res://scripts/characters/resident_moves_library.gd",
	"res://scripts/characters/resident_attention.gd", "res://scripts/player/door_passage_guide.gd",
	"res://scripts/player/constrained_grab.gd", "res://project.godot",
	"res://scripts/building/orison_v2_bar_destination.gd", "res://scripts/building/orison_v2_bar_region.gd",
	"res://scripts/building/harukiya_destination_retirement.gd", "res://scripts/building/orison_v2_street_frame.gd",
	"res://data/orison_v2/harukiya_destination_retirement.json", "res://data/floor_01_cell_registry.json",
	"res://data/building_layout.json",
	"res://scripts/player/player_controller.gd", "res://tests/guide_bell_error_capture.gd",
	"res://data/orison_v2/rhea_sato_routine.json", "res://data/orison_v2/harukiya_destination_layout.json"]

const NATIVE_INPUTS := ["res://assets/props/harukiya_destination.glb",
	"res://assets/building/floor_01_cells/shop_bar.gltf", "res://assets/building/floor_01_cells/shop_bar.bin"]
const IMPORT_INPUTS := ["res://assets/props/harukiya_destination.glb.import",
	"res://assets/building/floor_01_cells/shop_bar.gltf.import"]

func _ready() -> void:
	process_physics_priority = 100
	_run.call_deferred()

func _snapshot() -> Dictionary:
	var text := {}; var native := {}; var imports := {}
	for path: String in BOUND:
		text[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text() if FileAccess.file_exists(path) else ""
	for path: String in NATIVE_INPUTS:
		native[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	for path: String in IMPORT_INPUTS:
		var source := FileAccess.get_file_as_string(path).replace("\r\n", "\n") if FileAccess.file_exists(path) else ""
		var offset := source.find("\n[params]\n")
		imports[path] = {"source_lf_sha256": source.sha256_text() if not source.is_empty() else "",
			"declared_parameters_lf_sha256": source.substr(offset + 10).sha256_text() if offset >= 0 else ""}
	return {"text_lf_sha256": text, "native_file_sha256": native, "imports": imports}

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if not _check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "explicit writable SHOT_DIR"):
		get_tree().quit(2); return
	log_capture = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(log_capture)
	bound_sources = _snapshot()
	for path: String in BOUND + NATIVE_INPUTS + IMPORT_INPUTS:
		_check(FileAccess.file_exists(path), "bound source/native/import exists " + path)
	for path: String in IMPORT_INPUTS:
		_check(not str(bound_sources.imports[path].declared_parameters_lf_sha256).is_empty(), "declared import parameters present " + path)
	prior_data = RealityState.data; prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode
	preview_owned = RealityState.begin_preview_campaign(self)
	if not _check(preview_owned, "exclusive preview campaign custody"): await _finish(); return
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(campaign_clock.configure_date(1929, 6, 14, 21 * 60), "preview clock configured")
	adapter = OrisonV2AnchorAdapter.new(self)
	bar = OrisonV2BarRegion.new(); bar_region = bar; add_child(bar)
	if not _check(not bar.startup_failed and bar.destination != null, "real native bar mounted"): await _finish(); return
	destination = bar.destination; spec = destination.get("spec")
	for row: Dictionary in spec.navigation.nodes: points[str(row.id)] = GameBoot.b2g(row.at)
	if not _check(points.has("backstage_public_axis") and spec.navigation.edges.has(["backstage_entrance", "backstage_public_axis"])
		and spec.navigation.edges.has(["backstage_public_axis", "backstage"])
		and not spec.navigation.edges.has(["backstage_entrance", "backstage"]), "installed repaired graph replaces only original diagonal"):
		await _finish(); return
	details.player_forward_graph = _path("entrance", "stage_front")
	details.player_return_graph = _path("stage_front", "entrance")
	_check(details.player_forward_graph == ["backstage_entrance", "backstage_public_axis", "backstage", "stage_e", "stage_front"], "actual inherited walker forward path includes repaired aperture and stage")
	_check(details.player_return_graph == ["stage_e", "backstage", "backstage_public_axis", "backstage_entrance", "entrance"], "actual inherited walker return path includes repaired aperture and stage")
	if not failures.is_empty(): await _finish(); return
	player = PlayerController.new(); add_child(player); player.set_physics_process(false)
	player.global_position = bar.to_global(points.entrance) + Vector3.UP * .02
	player.enable_low_step_probe(); player.camera.make_current(); player.set_mouse_released(false)
	motor = Motor.new(); motor.service_bench_only = true; add_child(motor)
	var rig := LightRig.new(); add_child(rig)
	await get_tree().physics_frame; await get_tree().physics_frame
	_check(DisplayServer.get_name() != "headless", "windowed real-player diagnostic")
	if not failures.is_empty(): await _finish(); return
	var old := [points.backstage_entrance, points.backstage]
	var corrected := [points.backstage_entrance, points.backstage_public_axis, points.backstage]
	var complete := [points.entrance, points.backstage_entrance, points.backstage_public_axis, points.backstage, points.stage_e, points.stage_front]
	for profile: String in ["resident", "player"]:
		var radius := .28 if profile == "resident" else PlayerController.BODY_RADIUS
		var height := 1.40 if profile == "resident" else PlayerController.STANDING_HEIGHT
		var lift := .25 if profile == "resident" else .003
		var negative := _geometry(old, radius, height, lift)
		details[profile + "_original_negative"] = negative
		_check(not negative.clear and negative.native_oak_hit, "original diagonal hits actual backstage oak " + profile)
		# Full player geometry is confined to flat public opening. Real unchanged
		# low-step motor below, rather than a straight capsule cast, proves steps.
		var positive := _geometry(complete if profile == "resident" else corrected, radius, height, lift)
		details[profile + "_corrected_geometry"] = positive
		_check(positive.clear, "full body corrected native aperture geometry " + profile)
	if not failures.is_empty(): await _finish(); return
	current_node = "entrance"
	if not await _go("stage_front"): await _finish(); return
	if not await _go("entrance"): await _finish(); return
	# Clear the entrance through real input/motor; no second player placement.
	if not await _go("lounge_approach"): await _finish(); return
	details.player_motor = motor.service_travel
	if not _create_npc(): await _finish(); return
	npc_before = npc.actor.global_position; npc_watch = true; npc.set_physics_process(true)
	for goal: String in ["bench_stage", "bench_entrance"]:
		npc.force_destination = goal; npc._select_destination()
		var deadline := Time.get_ticks_msec() + 35000
		while failures.is_empty() and Time.get_ticks_msec() < deadline:
			if npc.current_id == npc.desired_id and npc.path.is_empty(): break
			await get_tree().physics_frame
		_check(npc.current_id == npc.desired_id and npc.path.is_empty()
			and npc.actor.global_position.distance_to(npc.graph.get_point_position(npc.desired_id)) < .05,
			"ordinary unchanged NPC motor reaches " + goal)
		var feet: Vector3 = npc.actor.global_position
		var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .03, feet - Vector3.UP * .03, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty() and absf(hit.position.y - feet.y) < .003, "actual supported NPC endpoint " + goal)
		if not failures.is_empty(): break
	await _finish()

func _walk(local: Vector3, label: String) -> bool:
	var walked: bool = await motor._walk_service_player(player, bar, local)
	if not _check(walked, "actual player input motor reaches " + label): return false
	var feet := player.global_position
	var support := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .04, feet - Vector3.UP * .04, 1)
	support.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(support)
	return _check(not hit.is_empty() and absf(hit.position.y - feet.y) < .01
		and absf(feet.y - bar.to_global(local).y) < .03,
		"actual supported player height at " + label)

func _geometry(local_points: Array, radius: float, height: float, lift: float) -> Dictionary:
	var shape := CapsuleShape3D.new(); shape.radius = radius; shape.height = height
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1
	query.margin = .001; query.exclude = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	var rows: Array[Dictionary] = []; var clear := true; var oak := false
	for reverse: bool in [false, true]:
		var sequence := local_points.duplicate()
		if reverse: sequence.reverse()
		var previous := Vector3.ZERO; var have_previous := false
		for edge in sequence.size() - 1:
			var a: Vector3 = bar.to_global(sequence[edge]); var b: Vector3 = bar.to_global(sequence[edge + 1])
			var steps := maxi(1, ceili(a.distance_to(b) / .01))
			for index in steps + 1:
				var feet := a.lerp(b, float(index) / steps)
				var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .34, feet - Vector3.UP * .5, 1)
				ray.exclude = [player.get_rid()]
				var floor_hit := space.intersect_ray(ray)
				if floor_hit.is_empty(): clear = false; rows.append({"missing_support": feet}); continue
				feet.y = floor_hit.position.y
				if have_previous and absf(feet.y - previous.y) > .25001: clear = false
				query.transform.origin = feet + Vector3.UP * (lift + height * .5); query.motion = Vector3.ZERO
				var hits := space.intersect_shape(query, 8)
				for hit: Dictionary in hits:
					var path := str(hit.collider.get_path())
					if path.contains("Destination_Backstage_oak"): oak = true
					clear = false; rows.append({"reverse": reverse, "feet": feet, "hit": path})
				if have_previous:
					query.transform.origin = previous + Vector3.UP * (lift + height * .5); query.motion = feet - previous
					var sweep := space.cast_motion(query)
					if sweep.size() != 2 or sweep[0] < 1.0:
						clear = false; rows.append({"reverse": reverse, "from": previous, "to": feet, "cast": Array(sweep)})
				previous = feet; have_previous = true
	return {"clear": clear, "native_oak_hit": oak, "rows": rows, "radius": radius, "height": height,
		"feet_lift": lift, "max_sample_spacing": .01, "bidirectional": true,
		"support": "actual mask1 ray; <=.25m adjacent supported corrections"}

func _create_npc() -> bool:
	var identity := "rhea_sato"
	var path := "res://data/orison_v2/rhea_sato_routine.json"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(ResidentRoute.valid_route_header(source, identity), "original resident route header"): return false
	npc = ResidentRoute.new(); npc.resident = identity; npc.source_path = path; npc.world = self
	npc.set_physics_process(false); add_child(npc)
	npc._point("street", ResidentBarRoute.STREET_APPROACH[0]); npc._bar_route = ResidentBarRoute.new()
	if not _check(npc._bar_route.attach(npc), "actual NPC bar graph attachment"): return false
	npc.places.bench_stage = "bar_stage_front"; npc.places.bench_entrance = "bar_entrance"
	npc.current_id = int(npc.identities.bar_entrance)
	npc._capsule.radius = .28; npc._capsule.height = 1.40
	npc.actor = ResidentPresentation.new()
	npc.actor.setup(str(source.name), identity, str(source.unit), "res://assets/characters/rhea_sato/rhea_sato.gltf")
	npc.actor.externally_driven = true; npc.actor.face_interacting_player = true
	npc.add_child(npc.actor); npc.actor.global_position = npc.graph.get_point_position(npc.current_id)
	return _check(npc.actor._model != null and npc._bar_route.bind_actor(), "real resident model/visit; one declared initial entrance placement")

func _physics_process(delta: float) -> void:
	if not npc_watch or not failures.is_empty(): return
	var at: Vector3 = npc.actor.global_position
	var witness := Motion.motion_witness(get_world_3d().direct_space_state, npc_before, at, delta, false)
	if not witness.clear: _check(false, "actual NPC supported motion continuity")
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = npc._capsule; query.collision_mask = 1
	query.exclude = [player.get_rid()]; query.transform.origin = at + Vector3.UP * .95
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): _check(false, "actual full NPC clears native geometry")
	if absf(npc.route_speed - 1.05) > .00001: _check(false, "ordinary NPC speed1.05")
	if not details.has("npc_trace"): details.npc_trace = []
	details.npc_trace.append({"at": at, "current": npc.current_id, "next": npc.path[0] if not npc.path.is_empty() else -1,
		"blocked": npc.blocked_reason, "floor": npc.last_floor, "motion": witness})
	npc_before = at

func _finish() -> void:
	npc_watch = false; Input.action_release("move_forward")
	if is_instance_valid(npc): npc.set_physics_process(false); npc._bar_route.cancel(); remove_child(npc); npc.free()
	if is_instance_valid(bar): remove_child(bar); bar.free()
	if is_instance_valid(player): remove_child(player); player.free()
	if is_instance_valid(motor): remove_child(motor); motor.free()
	await get_tree().process_frame
	if preview_owned: _check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "exact preview restoration after owners retire")
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse
	_check(bound_sources == _snapshot(), "bound source/native hashes stable")
	var unexpected: Array = []
	for error: String in log_capture.errors:
		if not error.contains("HARUKIYA DESTINATION:"): unexpected.append(error)
	_check(unexpected.is_empty(), "no unexpected engine errors"); OS.remove_logger(log_capture)
	var result := {"schema_version": 2, "evidence_kind": "diagnostic", "production_runtime": false,
		"scope": "nearby real native backstage aperture and stage; full NPC geometry/motor and real player input motor both directions; original diagonal negative; no crowd/outside-world/schedule/fit acceptance",
		"status": "PASS" if failures.is_empty() else "FAIL", "source_hashes": bound_sources,
		"checks": checks, "failures": failures, "details": details, "unexpected_engine_errors": unexpected}
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush()
	var written := file.get_error() == OK; file.close()
	print("BACKSTAGE ACCESS: ", "PASS" if failures.is_empty() and written else "FAIL", " checks=", checks.size(), " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() and written else 1)
