extends Node3D
## Initial reconstruction helper only; reduced authored approach, no live queue.
const Route := preload("res://scripts/characters/orison_v2_resident_route.gd")
const BarRoute := preload("res://scripts/characters/orison_v2_bar_route.gd")
const Presentation := preload("res://scripts/characters/orison_v2_resident_presentation.gd")
const IDS := ["rhea_sato", "jonah_price", "teresa_vale"]
const SOURCES := ["res://tests/bodega_initial_placement_test.gd", "res://tests/BodegaInitialPlacementTest.tscn",
	"res://scripts/characters/orison_v2_resident_route.gd", "res://scripts/characters/orison_v2_bar_route.gd",
	"res://scripts/characters/orison_v2_resident_presentation.gd", "res://scripts/characters/animated_resident.gd",
	"res://scripts/building/orison_v2_exterior_cell.gd", "res://scripts/building/orison_v2_exterior_spatial_resolver.gd",
	"res://scripts/building/orison_v2_bodega_frontage.gd", "res://scripts/building/orison_v2_bodega_fittings.gd",
	"res://scripts/building/orison_v2_bodega_receiving.gd", "res://scripts/building/orison_v2_bodega_power.gd",
	"res://scripts/player/player_controller.gd", "res://scripts/props/door_prop.gd",
	"res://scripts/game/door_keyring.gd", "res://scripts/game/person_inventory.gd",
	"res://tests/guide_bell_error_capture.gd", "res://scripts/generated/v2_bodega_fittings.gd",
	"res://data/orison_v2/exterior/regions.json", "res://data/orison_v2/exterior/exterior_geometry.json",
	"res://data/orison_v2/exterior/street_frame.json"]
var player: PlayerController
var exterior: OrisonV2ExteriorCell
var routes: Array[Node3D] = []
var owned: Array[Node] = []
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var details: Dictionary = {}
var inputs: Dictionary = {}
var paths: Array = []
var prior_data: Dictionary
var prior_hash := ""
var prior_mode: int
var prior_mouse: int
var prior_freeze := false
var preview := false
var directory := ""
var logger

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks.append({"ok": ok, "label": label})
	if not ok: failures.append(label); push_error("BODEGA INITIAL: " + label)
	return ok

func _snapshot() -> Dictionary:
	var result := {}
	for path: String in paths:
		if not FileAccess.file_exists(path): result[path] = {}; continue
		var binary := path.ends_with(".glb") or path.ends_with(".bin")
		var text := "" if binary else FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		result[path] = {"sha256": FileAccess.get_sha256(path) if binary else text.sha256_text()}
		if path.ends_with(".import"):
			var at := text.find("\n[params]\n")
			result[path].parameters_lf_sha256 = text.substr(at+10).sha256_text() if at >= 0 else ""
	return result

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK: get_tree().quit(2); return
	logger = preload("res://tests/guide_bell_error_capture.gd").new(); OS.add_logger(logger)
	paths = SOURCES.duplicate()
	for id: String in IDS:
		paths.append("res://data/orison_v2/%s_routine.json" % id)
		for suffix: String in [".gltf", ".bin", ".gltf.import"]: paths.append("res://assets/characters/%s/%s%s" % [id,id,suffix])
	for name: String in ["bodega_frontage", "bodega_fittings", "bodega_receiving", "bodega_power"]:
		paths.append("res://assets/props/%s.glb" % name); paths.append("res://assets/props/%s.glb.import" % name)
	inputs = _snapshot()
	prior_data = RealityState.data; prior_hash = JSON.stringify(prior_data).sha256_text()
	prior_mode = GameBoot.launch_mode; prior_mouse = Input.mouse_mode; prior_freeze = CampaignTime._frozen_for_tests
	for path: String in paths:
		_check(FileAccess.file_exists(path), "bound source/native/import exists " + path)
		if path.ends_with(".import") and inputs[path].has("parameters_lf_sha256"): _check(not str(inputs[path].parameters_lf_sha256).is_empty(), "declared import parameters exist " + path)
	if not failures.is_empty(): await _finish(); return
	preview = RealityState.begin_preview_campaign(self)
	if not _check(preview, "exclusive nonpersistent preview"): await _finish(); return
	CampaignTime.set_frozen_for_tests(true); GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	_check(CampaignClock.new().configure_date(1929, 6, 15, 1319), "declared diagnostic clock")
	player = PlayerController.new(); add_child(player); owned.append(player); player.set_physics_process(false)
	exterior = OrisonV2ExteriorCell.new()
	if not _check(exterior.configure_dependencies(_exterior_dependencies()), "actual exterior configured pre-tree"): await _finish(); return
	add_child(exterior); owned.append(exterior)
	if not _check(not exterior.startup_failed, "actual bodega/street source owners build"): await _finish(); return
	if not _check(_mount_extra_exterior(), "declared exterior fixture additions ready"): await _finish(); return
	var initial_player: Dictionary = exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[0].placement
	player.global_position = initial_player.position; player.camera.make_current()
	var materials := preload("res://scripts/building/orison_v2_architectural_materials.gd").new()
	_check(preload("res://scripts/building/orison_v2_bodega_frontage.gd").mount(exterior, materials) != null, "actual native frontage and leaf infill")
	for source: Script in [preload("res://scripts/building/orison_v2_bodega_receiving.gd"), preload("res://scripts/building/orison_v2_bodega_power.gd")]:
		var node: Node3D = source.new()
		if not _check(node.configure(exterior), "native service fabric configures"): node.free(); await _finish(); return
		add_child(node); owned.append(node); _check(not node.startup_failed, "native service fabric ready")
	_check(preload("res://scripts/building/orison_v2_bodega_fittings.gd").mount(exterior, materials) != null, "actual native retail fittings retain collision")
	await get_tree().physics_frame; await get_tree().physics_frame
	if not failures.is_empty(): await _finish(); return
	var leaf := exterior.interaction_leaf("SHOP_BODEGA_STOREFRONT_LEAF")
	details.support_survey = []
	for datum: Dictionary in exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes:
		var feet: Vector3 = datum.placement.position
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.34, feet-Vector3.UP*.5, 1))
		details.support_survey.append({"id": datum.id, "authored": feet, "floor": floor_hit.position if not floor_hit.is_empty() else null, "delta": floor_hit.position.y-feet.y if not floor_hit.is_empty() else null})
	var interior: Vector3 = exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[4].placement.position
	var outside: Vector3 = exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[3].placement.position
	_check(not leaf.standing_position_clear(interior, .28, 1.65), "original interior predecessor blocks actual leaf arc")
	_check(leaf.standing_position_clear(outside, .28, 1.65), "existing exterior predecessor clears actual leaf arc")
	for index in IDS.size():
		var route := Route.new(); route.resident = IDS[index]; route.world = self; route.set_physics_process(false); add_child(route); owned.append(route); route.set_physics_process(false)
		route._capsule.radius = .28; route._capsule.height = 1.40
		route._bar_route = BarRoute.new(); route._bar_route.route = route; route._doors.append(leaf)
		var previous := -1
		for i in range(1, 5):
			var point := route._point("bodega_route_%d" % i, exterior.route("ROUTE_ORISON_TO_SHOP_BODEGA").nodes[i].placement.position)
			if previous >= 0: route.graph.connect_points(previous, point)
			previous = point
		route.desired_id = route._point("bodega", exterior.spatial_resolver.resolve_placement("SHOP_BODEGA", "service_stance").position)
		route.graph.connect_points(previous, route.desired_id); route.current_id = route.desired_id; route.destination = "bodega"
		route.places = {"unit": "bodega_route_1", "bodega": "bodega"} # Explicit reduced diagnostic home connector.
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/%s_routine.json" % IDS[index]))
		route.actor = Presentation.new(); route.actor.setup(str(source.name), IDS[index], str(source.unit), "res://assets/characters/%s/%s.gltf" % [IDS[index], IDS[index]])
		route.actor.externally_driven = true; route.add_child(route.actor); route.actor.global_position = route.graph.get_point_position(route.desired_id)
		if not _check(route.actor._model != null, "real presentation loads " + IDS[index]): await _finish(); return
		if index == 1:
			_check(route.actor.global_position == routes[0].actor.global_position and not route._initial_peer_clear(route.actor.global_position), "original shared-goal equal-position negative")
			_check(not route._initial_peer_clear(route.actor.global_position+Vector3(.3,0,0)), "initial admission rejects300mm overlap even when moving apart")
			route.places.unit = "bodega"; _check(not route._place_initial_body() and route.current_id == route.desired_id, "no-fallback refuses without relocating or retargeting")
			route.places.unit = "bodega_route_1"
		var desired: int = route.desired_id
		_check(route._place_initial_body() and route.identities.values().has(route.current_id) and route.current_id != int(route.identities.bodega_route_4) and route.desired_id == desired and route.destination == "bodega", "real initial helper chooses actual clear existing source node " + IDS[index])
		if index > 0: _check(str(route.identities.find_key(route.current_id)) == ("bodega_route_3" if index == 1 else "bodega_route_2"), "nearest free source predecessor retained " + IDS[index])
		routes.append(route)
		if not failures.is_empty(): await _finish(); return
		var at: Vector3 = route.actor.global_position
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.06, at-Vector3.UP*.06, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var query := PhysicsShapeQueryParameters3D.new(); query.shape = route._capsule; query.collision_mask = 1; query.exclude = [player.get_rid()]; query.transform.origin = at+Vector3.UP*.95
		_check(not hit.is_empty() and hit.normal.y >= .45 and absf(hit.position.y-at.y) <= (.041 if index == 0 else .003), "real floor under authored40mm-offset stance " + IDS[index])
		_check(get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "unchanged standing capsule clears native bodega " + IDS[index])
		details[IDS[index]] = {"at": at, "current": route.current_id, "desired": desired, "chosen_identity": route.identities.find_key(route.current_id), "floor": {"point": hit.position, "normal": hit.normal, "path": str(hit.collider.get_path())} if not hit.is_empty() else {}, "node": route.identities.find_key(route.current_id), "placement_offset_m": at.y-hit.position.y if not hit.is_empty() else null}
	details.player = {"at": player.global_position, "physics_enabled": player.is_physics_processing()}
	for a in routes.size():
		for b in range(a+1, routes.size()): _check(routes[a].actor.global_position.distance_to(routes[b].actor.global_position) >= .60, "actual reconstructed bodies retain full separation")
	_check(leaf.motion_clear(true), "actual leaf full opening sweep clears all people")
	leaf.hold_passage(routes[0].actor); _check(leaf.request_passage(routes[0].actor, IDS[0]), "actual passage owner starts original leaf")
	var deadline := Time.get_ticks_msec()+3000
	while not leaf.is_ready_for_passage() and Time.get_ticks_msec()<deadline: leaf.hold_passage(routes[0].actor); await get_tree().physics_frame
	_check(leaf.is_ready_for_passage() and leaf.motion_clear(false), "actual opened leaf and full closing sweep clear")
	leaf.release_passage(routes[0].actor)
	await _finish()

## Derived nearby fixtures may use the real composed paving/lamps. The default
## remains the original native template recipe; no alternate geometry is implicit.
func _exterior_dependencies() -> Dictionary:
	return {"player": player, "geometry_instance_ids": ["STREET_ORISON_01", "SHOP_BODEGA"]}

func _mount_extra_exterior() -> bool:
	return true

func _finish() -> void:
	for route: Node3D in routes: route.set_physics_process(false)
	for node: Node in owned.duplicate():
		if is_instance_valid(node) and node != exterior and node != player: remove_child(node); node.free()
	if is_instance_valid(exterior):
		exterior.shutdown_for_tests()
		if exterior.get_parent() == self: remove_child(exterior)
		exterior.free()
	if is_instance_valid(player): remove_child(player); player.free()
	await get_tree().process_frame
	if preview: _check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, prior_data), "exact original preview context restored")
	GameBoot.launch_mode = prior_mode; Input.mouse_mode = prior_mouse; CampaignTime.set_frozen_for_tests(prior_freeze)
	_check(JSON.stringify(prior_data).sha256_text() == prior_hash and CampaignTime._frozen_for_tests == prior_freeze, "original campaign/freeze custody unchanged")
	_check(inputs == _snapshot(), "source/native/import parameter bindings stable")
	var errors: Array = []
	for error: String in logger.errors:
		if not error.contains("BODEGA INITIAL:"): errors.append(error)
	_check(errors.is_empty(), "no unexpected engine errors"); OS.remove_logger(logger)
	var result := {"schema_version": 2, "evidence_kind": "diagnostic", "production_runtime": false, "status": "PASS" if failures.is_empty() else "FAIL",
		"scope": "real native bodega and three real presentation/route initial helpers; reduced existing approach graph with explicit home alias; no full route.setup, agenda, live queue, traversal or natural-arrival proof",
		"inputs": inputs, "checks": checks, "failures": failures, "details": details, "engine_errors": errors}
	var file := FileAccess.open(directory.path_join("initial_placement.json"), FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(result, "\t")); file.flush(); var written := file.get_error() == OK; file.close()
	get_tree().quit(0 if failures.is_empty() and written else 1)
