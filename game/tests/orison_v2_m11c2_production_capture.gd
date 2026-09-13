extends Node
## M11C2 matched production capture and continuous player-route packet.
##
## Both matched sides instantiate the real v1 BuildingRoot through
## BuildingRootSelector.  The only injected choice is the session-only F01
## geometry provider.  Cameras, world environment, lighting, detail passes,
## collision, interaction actors, and the PlayerController all belong to the
## production root.  Every camera and route point comes from the immutable,
## hash-bound M11C1 contract.

const Selector := preload("res://scripts/building/building_root_selector.gd")
const GeometryConfiguration := preload(
		"res://scripts/building/floor01_geometry_configuration.gd")
const Support := preload(
		"res://tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd")
const DoorCrossingSupport := preload(
		"res://tests/orison_v2_m11c2_door_crossing_support.gd")

const EXPECTED_SIZE := Vector2i(1600, 900)
const M11C1_CONFIG_PATH := \
		"res://../art/renders/orison_v2/m11c1_owner_first_rehearsal_01/" + \
		"runtime/m11c1_runtime_config.json"
const M11C1_CONFIG_LF_SHA256 := \
		"98b57247de62133d270b155bd9b0d8b21c533290887a7ee46bb2012f62918fd7"
const PROD_LAYOUT_PATH := "res://data/building_layout.json"
const HARNESS_PATH := "res://tests/orison_v2_m11c2_production_capture.gd"
const OUTPUT_ENV := "M11C2_CAPTURE_DIR"
const RECEIPT_ENV := "M11C2_CAPTURE_RECEIPT"
const PHASE_ENV := "M11C2_CAPTURE_PHASE"
const DEFAULT_OUTPUT := "user://m11c2/production_capture"
const DEFAULT_RECEIPT := "user://m11c2/production_capture_receipt.json"
const MODES := [&"legacy_monolith", &"owner_first_cells"]
const MINIMUM_MEAN_LUMA := 8.0
const MAXIMUM_DARK_PIXEL_FRACTION := 0.92
const MINIMUM_TARGET_VISIBILITY_FRACTION := 0.65
const DOOR_PHYSICAL_SETTLE_SECONDS := 0.60
const PROOF_CLOCK := "12:30"
const PROOF_MINUTE := 750

var _config: Dictionary = {}
var _layout: Dictionary = {}
var _seams: Dictionary = {}
var _output_dir := ""
var _failures: Array[String] = []
var _receipt := {
	"schema": "orison.m11c2.production-matched-capture.v1",
	"task": "ORISON-V2-M11C2",
	"status": "RUNNING",
	"matched_modes": {},
	"matched_pairs": [],
	"owner_first_route": {},
	"lifecycle": {},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var globals := _snapshot_globals()
	# Use one deterministic public trading hour for both providers.  Every
	# ordinarily accessible Passage shop is then open; NEWS/CIGARS remains
	# locked by its real DoorProp.  _finish() restores the prior environment.
	OS.set_environment("DAYNIGHT_FORCE", PROOF_CLOCK)
	if not _load_contract():
		await _finish(globals)
		return
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("M11C2 capture requires Forward+")
	if get_viewport().get_visible_rect().size != Vector2(EXPECTED_SIZE):
		_fail("M11C2 capture requires an exact 1600x900 viewport")
	if not _failures.is_empty():
		await _finish(globals)
		return
	RenderingServer.viewport_set_measure_render_time(
			get_viewport().get_viewport_rid(), true)
	_output_dir = OS.get_environment(OUTPUT_ENV).strip_edges()
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path(DEFAULT_OUTPUT)
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var phase := OS.get_environment(PHASE_ENV).strip_edges()
	_receipt["capture_phase"] = phase
	_receipt["capture_harness_sha256"] = FileAccess.get_sha256(HARNESS_PATH)
	_receipt["process_isolation"] = {
		"required": true,
		"reason": "Forward+ complete-root replacement is isolated from visual proof",
		"one_complete_production_root_per_process": true,
		"process_exit_owns_root_release": true,
		"public_live_root_teardown_proven_by":
				"m11c2_production_matrix_receipt.json",
		"capture_process_performs_render_node_mutation": false,
		"capture_process_performs_provider_teardown": false,
	}
	match phase:
		"legacy_monolith":
			var legacy_packet := await _capture_matched_mode("legacy_monolith")
			_receipt.matched_modes = {"legacy_monolith": legacy_packet}
			if str(legacy_packet.get("status", "FAIL")) != "PASS":
				_fail("legacy matched production capture failed")
		"owner_first_cells":
			var cells_packet := await _capture_matched_mode("owner_first_cells")
			_receipt.matched_modes = {"owner_first_cells": cells_packet}
			if str(cells_packet.get("status", "FAIL")) != "PASS":
				_fail("cell matched production capture failed")
		"owner_first_route":
			var route := await _capture_owner_first_route()
			_receipt.owner_first_route = route
			if str(route.get("status", "FAIL")) != "PASS":
				_fail("owner-first complete production PlayerController route failed")
		"legacy_route_control":
			var control := await _capture_owner_first_route(
					"legacy_monolith", "legacy_monolith_route_control")
			_receipt["legacy_route_control"] = control
			if str(control.get("status", "FAIL")) != "PASS":
				_fail("legacy complete production PlayerController route control failed")
		_:
			_fail("M11C2_CAPTURE_PHASE must name one isolated capture phase")
	_receipt["capture_boundary"] = {
		"production_root_through_selector": true,
		"production_player_and_camera": true,
		"harness_added_geometry": false,
		"harness_added_collision": false,
		"harness_added_lights": false,
		"harness_added_world_environment": false,
		"harness_added_labels_arrows_or_seam_covers": false,
		"capture_collision_changes": false,
		"noclip": false,
		"matched_camera_source": M11C1_CONFIG_PATH,
		"route_coordinate_source": M11C1_CONFIG_PATH,
		"route_initial_placement_count": 1,
		"route_intermediate_transform_writes": 0,
		"production_time_mode": PROOF_CLOCK,
		"time_frozen_through_production_clock_interface": true,
	}
	await _finish(globals, false)


func _load_contract() -> bool:
	if not FileAccess.file_exists(M11C1_CONFIG_PATH):
		_fail("immutable M11C1 runtime contract is missing")
		return false
	var text := FileAccess.get_file_as_string(M11C1_CONFIG_PATH)
	var normalized_hash := text.replace("\r\n", "\n").sha256_text()
	if normalized_hash != M11C1_CONFIG_LF_SHA256:
		_fail("immutable M11C1 runtime contract hash differs")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		_fail("immutable M11C1 runtime contract does not parse")
		return false
	_config = parsed
	var layout_value: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(PROD_LAYOUT_PATH))
	if layout_value is not Dictionary:
		_fail("production layout does not parse for vertical-route derivation")
		return false
	_layout = layout_value
	_seams = Support.index_by_id(_config.get("seams", []))
	var views: Array = _config.get("capture_views", [])
	if views.size() != 5 or _seams.size() != 5:
		_fail("M11C1 contract must supply five seams and five capture views")
	_receipt["input_provenance"] = {
		"path": M11C1_CONFIG_PATH,
		"normalized_sha256": normalized_hash,
		"seams": _seams.size(),
		"capture_views": views.size(),
		"embedded_camera_or_route_coordinates": false,
		"vertical_route_authority": PROD_LAYOUT_PATH,
		"production_layout_sha256": FileAccess.get_sha256(PROD_LAYOUT_PATH),
	}
	return _failures.is_empty()


func _capture_matched_mode(mode: String) -> Dictionary:
	_prepare_world_facts()
	var initial_simulation_facts := _simulation_facts()
	var initial_simulation_sha256 := JSON.stringify(initial_simulation_facts).sha256_text()
	if not GeometryConfiguration.set_for_tests(mode):
		return {"status": "FAIL", "mode": mode,
				"reason": "geometry configuration refused mode"}
	Selector.reset_for_tests("v1")
	var root := await _instantiate_production_root()
	if root == null:
		return {"status": "FAIL", "mode": mode,
				"reason": "production root failed to instantiate"}
	var player := root.get("player") as PlayerController
	var frames: Array[Dictionary] = []
	var ok := player != null and not player.noclip
	if player == null:
		_fail("%s production root has no PlayerController" % mode)
	else:
		var mode_dir := _output_dir.path_join(mode)
		DirAccess.make_dir_recursive_absolute(mode_dir)
		var views: Array = _config.get("capture_views", [])
		for index in views.size():
			var raw: Variant = views[index]
			if raw is not Dictionary:
				ok = false
				continue
			var frame := await _capture_config_view(root, player, raw, mode,
					mode_dir, index)
			frames.append(frame)
			ok = ok and str(frame.get("status", "FAIL")) == "PASS"
	ok = ok and frames.size() == 5
	var end_simulation_facts := _simulation_facts()
	return {
		"status": "PASS" if ok else "FAIL",
		"mode": mode,
		"selector_id": Selector.selected_id(),
		"selector_path": Selector.scene_path(),
		"frame_count": frames.size(),
		"frames": frames,
		"simulation_facts": initial_simulation_facts,
		"simulation_facts_sha256": initial_simulation_sha256,
		"capture_end_simulation_facts": end_simulation_facts,
		"capture_end_simulation_facts_sha256": JSON.stringify(
				end_simulation_facts).sha256_text(),
		"lifecycle_boundary": {
			"one_complete_root_per_process": true,
			"root_remains_live_until_process_exit": true,
			"render_nodes_or_provider_not_mutated_after_capture": true,
			"live_root_public_teardown_receipt":
					"m11c2_production_matrix_receipt.json",
		},
	}


func _capture_config_view(root: Node, player: PlayerController,
		view: Dictionary, mode: String, output_dir: String,
		index: int) -> Dictionary:
	var eye := Support.vector3(view.get("eye", []))
	var target := Support.vector3(view.get("target", []))
	player.global_position = eye - Vector3.UP * PlayerController.STANDING_EYE
	player.velocity = Vector3.ZERO
	player.autopilot = Vector3.ZERO
	await _settle_player(player)
	var camera := player.camera
	if camera == null:
		return {"status": "FAIL", "reason": "production camera missing"}
	camera.fov = float(view.get("fov_degrees", 70.0))
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	await _settle_render()
	var image := get_viewport().get_texture().get_image()
	var dimensions := image.get_size() if image != null else Vector2i.ZERO
	var readability := _image_readability(image)
	var occlusion := _camera_occlusion(player, camera, target)
	var filename := "%02d_%s_%s.png" % [index + 1,
			_safe_slug(str(view.get("id", "view"))), mode]
	var path := output_dir.path_join(filename)
	var saved := image != null and image.save_png(path) == OK
	image = null
	var hash := Support.file_sha256(path) if saved else ""
	var ground_contact := _ground_contact(player)
	var camera_row := {
		"eye": Support.vector3_array(camera.global_position),
		"target": view.get("target", []),
		"fov_degrees": camera.fov,
		"source": M11C1_CONFIG_PATH,
		"production_class": "PlayerController/Camera3D",
	}
	var frame_ok := saved and hash.length() == 64 \
			and dimensions == EXPECTED_SIZE \
			and bool(readability.get("passed", false)) \
			and bool(occlusion.get("passed", false)) \
			and str(root.call("active_floor01_geometry_mode")) == mode
	return {
		"status": "PASS" if frame_ok else "FAIL",
		"id": view.get("id", ""),
		"seam_id": view.get("seam_id", ""),
		"mode": mode,
		"png": path,
		"png_sha256": hash,
		"dimensions": [dimensions.x, dimensions.y],
		"camera": camera_row,
		"requested_camera_eye": view.get("eye", []),
		"player_feet": Support.vector3_array(player.global_position),
		"player_grounded": player.is_on_floor(),
		"ground_contact": ground_contact,
		"camera_occlusion": occlusion,
		"readability": readability,
		"production_root": Selector.scene_path(),
		"production_geometry_receipt": root.call("floor01_geometry_receipt"),
		"tree_metrics": Support.tree_metrics(root),
		"performance": Support.performance_snapshot(get_viewport()),
		"harness_added_scene_content": false,
		"initial_capture_placement_count": 1,
	}


func _compare_pairs(mode_packets: Dictionary) -> Array[Dictionary]:
	var legacy: Array = (mode_packets.get("legacy_monolith", {}) as Dictionary).get(
			"frames", [])
	var cells: Array = (mode_packets.get("owner_first_cells", {}) as Dictionary).get(
			"frames", [])
	var result: Array[Dictionary] = []
	for index in mini(legacy.size(), cells.size()):
		if legacy[index] is not Dictionary or cells[index] is not Dictionary:
			continue
		var first: Dictionary = legacy[index]
		var second: Dictionary = cells[index]
		var first_camera: Dictionary = first.get("camera", {})
		var second_camera: Dictionary = second.get("camera", {})
		var camera_exact := JSON.stringify(first_camera) == JSON.stringify(
				second_camera)
		var dimensions_exact: bool = first.get("dimensions", []) \
				== second.get("dimensions", []) \
				and first.get("dimensions", []) == [EXPECTED_SIZE.x, EXPECTED_SIZE.y]
		result.append({
			"id": first.get("id", ""),
			"seam_id": first.get("seam_id", ""),
			"legacy_png": first.get("png", ""),
			"legacy_sha256": first.get("png_sha256", ""),
			"cells_png": second.get("png", ""),
			"cells_sha256": second.get("png_sha256", ""),
			"camera_exact": camera_exact,
			"dimensions_exact": dimensions_exact,
			"pixel_difference": _image_difference(str(first.get("png", "")),
					str(second.get("png", ""))),
			"human_review_required": true,
		})
	return result


func _capture_owner_first_route(mode := "owner_first_cells",
		output_leaf := "owner_first_cells_route") -> Dictionary:
	_prepare_world_facts()
	var initial_simulation_facts := _simulation_facts()
	var initial_simulation_sha256 := JSON.stringify(initial_simulation_facts).sha256_text()
	if not GeometryConfiguration.set_for_tests(mode):
		return {"status": "FAIL", "reason": "%s mode refused" % mode}
	Selector.reset_for_tests("v1")
	var root := await _instantiate_production_root()
	if root == null:
		return {"status": "FAIL", "reason": "production root failed to instantiate"}
	var player := root.get("player") as PlayerController
	if player == null:
		return {"status": "FAIL", "reason": "production PlayerController missing"}
	var route_dir := _output_dir.path_join(output_leaf)
	DirAccess.make_dir_recursive_absolute(route_dir)
	var shell := _traversal("SEAM_ORISON_SOUTH_SHELL_STREET", 0)
	var bodega := _traversal("SEAM_BODEGA_STREET", 0)
	var portal := _traversal("SEAM_STREET_PASSAGE_PORTAL", 0)
	var passage: Dictionary = _seams.get("SEAM_PASSAGE_SHOP_AISLES", {})
	var initial_waypoints: Array = shell.get("forward_waypoints", [])
	if shell.is_empty() or bodega.is_empty() or portal.is_empty() \
			or passage.is_empty() or initial_waypoints.is_empty():
		return {"status": "FAIL", "reason": "M11C1 route records incomplete"}
	# This is the only route transform write.  Every later stage is reached by
	# collision-bearing PlayerController movement.
	player.global_position = Support.vector3(initial_waypoints[0])
	player.velocity = Vector3.ZERO
	player.autopilot = Vector3.ZERO
	await _settle_player(player)
	var frames: Array[Dictionary] = []
	var legs: Array[Dictionary] = []
	var interactions: Array[Dictionary] = []
	var ok := player.is_on_floor() and not player.noclip \
			and player.collision_layer != 0 and player.collision_mask != 0
	frames.append(await _capture_route_frame(player, route_dir, 0,
			"orison_interior_looking_to_street", Support.vector3(shell.get("start", []))))
	var shell_door := await _interact_door(root,
			str(shell.get("door_identity", "")), player, false)
	interactions.append(shell_door)
	ok = ok and bool(shell_door.get("ok", false))
	var leave := await _walk_to(player, Support.vector3(shell.get("start", [])),
			shell, "orison_to_street")
	legs.append(leave)
	ok = ok and bool(leave.get("reached", false))
	frames.append(await _capture_route_frame(player, route_dir, 1,
			"street_looking_to_bodega", Support.vector3(bodega.get("start", []))))

	var bodega_approach := await _walk_to(player,
			Support.vector3(bodega.get("start", [])), bodega,
			"street_to_bodega_threshold")
	legs.append(bodega_approach)
	var bodega_door := await _interact_door(root,
			str(bodega.get("door_identity", "")), player, false)
	interactions.append(bodega_door)
	var bodega_in := await _walk_config_waypoints(player,
			bodega.get("forward_waypoints", []), bodega, "enter_bodega")
	legs.append(bodega_in)
	ok = ok and bool(bodega_approach.get("reached", false)) \
			and bool(bodega_door.get("ok", false)) \
			and bool(bodega_in.get("reached", false))
	frames.append(await _capture_route_frame(player, route_dir, 2,
			"bodega_interior_looking_to_street",
			Support.vector3(bodega.get("start", []))))
	var bodega_out := await _walk_config_waypoints(player,
			bodega.get("return_waypoints", []), bodega, "leave_bodega")
	legs.append(bodega_out)
	ok = ok and bool(bodega_out.get("reached", false))

	var semantic_seam_chains: Array[Dictionary] = []
	var portal_start := await _walk_semantic_seam_chain(player, [
		{
			"authority_id": "SEAM_ORISON_SOUTH_SHELL_STREET",
			"record": shell,
			"endpoint_role": "start",
			"relationship": "reverse of passed Orison-to-bodega connector",
		},
		{
			"authority_id": "SEAM_STREET_PASSAGE_PORTAL",
			"record": portal,
			"endpoint_role": "start",
			"relationship": "Passage exterior approach",
		},
	], "bodega_to_passage_portal")
	semantic_seam_chains.append(portal_start)
	var portal_in := await _walk_config_waypoints(player,
			portal.get("forward_waypoints", []), portal, "street_to_passage")
	legs.append(portal_start)
	legs.append(portal_in)
	ok = ok and bool(portal_start.get("reached", false)) \
			and bool(portal_in.get("reached", false))
	var shop_rows: Array = passage.get("traversals", [])
	var first_shop_target := Support.vector3((shop_rows[0] as Dictionary).get(
			"start", [])) if not shop_rows.is_empty() \
			and shop_rows[0] is Dictionary else player.global_position
	frames.append(await _capture_route_frame(player, route_dir, 3,
			"passage_looking_to_shop_aisles", first_shop_target))

	var shop_results: Array[Dictionary] = []
	for raw: Variant in shop_rows:
		if raw is not Dictionary:
			ok = false
			continue
		var shop: Dictionary = raw
		var approach := await _walk_to(player,
				Support.vector3(shop.get("start", [])), shop,
				"approach_%s" % str(shop.get("shop_cell_id", "shop")))
		var locked := str(shop.get("expectation", "")) \
				== "locked_non_crossable"
		var interaction := await _interact_door(root,
				str(shop.get("door_identity", "")), player, locked)
		interactions.append(interaction)
		var crossing_path := {"ok": true, "receipt": {
			"applicable": false, "reason": "locked_non_crossable"}}
		var crossing: Dictionary
		if locked:
			var before_attempt := player.global_position
			crossing = await _walk_config_waypoints(player,
					shop.get("forward_waypoints", []), shop,
					"locked_%s" % str(shop.get("shop_cell_id", "shop")), true)
			var plane_crossed := _crossed_between(before_attempt,
					player.global_position, shop.get("plane", {}))
			crossing["correctly_blocked"] = not bool(crossing.get("reached", false)) \
					and not plane_crossed
			ok = ok and bool(crossing.correctly_blocked)
		else:
			crossing_path = DoorCrossingSupport.derive(root, shop)
			if bool(crossing_path.get("ok", false)):
				crossing = await _walk_waypoints(player,
						crossing_path.get("forward_waypoints", []) as Array[Vector3],
						shop, "enter_%s" % str(shop.get("shop_cell_id", "shop")))
			else:
				crossing = {"reached": false,
						"reason": crossing_path.get("reason", "crossing derivation failed")}
			var return_leg: Dictionary
			if bool(crossing_path.get("ok", false)):
				return_leg = await _walk_waypoints(player,
						crossing_path.get("return_waypoints", []) as Array[Vector3],
						shop, "return_%s" % str(shop.get("shop_cell_id", "shop")))
			else:
				return_leg = {"reached": false,
						"reason": crossing_path.get("reason", "crossing derivation failed")}
			crossing["return"] = return_leg
			ok = ok and bool(crossing.get("reached", false)) \
					and bool(return_leg.get("reached", false))
		ok = ok and bool(approach.get("reached", false)) \
				and bool(interaction.get("ok", false))
		shop_results.append({"cell_id": shop.get("shop_cell_id", ""),
				"approach": approach, "interaction": interaction,
				"crossing": crossing,
				"derived_crossing": crossing_path.get("receipt", {})})
	frames.append(await _capture_route_frame(player, route_dir, 4,
			"passage_after_all_shop_fronts",
			Support.vector3(portal.get("start", []))))

	var portal_out := await _walk_config_waypoints(player,
			portal.get("return_waypoints", []), portal, "passage_to_street")
	var shell_return := await _walk_semantic_seam_chain(player, [
		{
			"authority_id": "SEAM_ORISON_SOUTH_SHELL_STREET",
			"record": shell,
			"endpoint_role": "start",
			"relationship": "Passage return to Orison exterior",
		},
	], "street_return_to_orison")
	semantic_seam_chains.append(shell_return)
	legs.append(portal_out)
	legs.append(shell_return)
	ok = ok and bool(portal_out.get("reached", false)) \
			and bool(shell_return.get("reached", false))
	frames.append(await _capture_route_frame(player, route_dir, 5,
			"street_return_looking_to_orison",
			Support.vector3(initial_waypoints[0])))
	var shell_in := await _walk_config_waypoints(player,
			shell.get("forward_waypoints", []), shell, "street_to_orison")
	legs.append(shell_in)
	ok = ok and bool(shell_in.get("reached", false))
	frames.append(await _capture_route_frame(player, route_dir, 6,
			"orison_return_complete", Support.vector3(shell.get("start", []))))
	var vertical := await _capture_vertical_core_round_trip(player, route_dir,
			frames.size())
	for raw_vertical_frame: Variant in vertical.get("frames", []):
		if raw_vertical_frame is Dictionary:
			frames.append(raw_vertical_frame)
		else:
			ok = false
	ok = ok and str(vertical.get("status", "FAIL")) == "PASS"
	for frame: Dictionary in frames:
		ok = ok and str(frame.get("status", "FAIL")) == "PASS"
	ok = ok and frames.size() == 9
	var route_end_simulation_facts := _simulation_facts()
	return {
		"status": "PASS" if ok else "FAIL",
		"mode": mode,
		"production_player": true,
		"production_root_through_selector": true,
		"source_contract": M11C1_CONFIG_PATH,
		"source_contract_sha256": M11C1_CONFIG_LF_SHA256,
		"initial_simulation_facts": initial_simulation_facts,
		"initial_simulation_facts_sha256": initial_simulation_sha256,
		"route_end_simulation_facts": route_end_simulation_facts,
		"route_end_simulation_facts_sha256": JSON.stringify(
				route_end_simulation_facts).sha256_text(),
		"initial_placement_count": 1,
		"intermediate_transform_writes": 0,
		"teleports": 0,
		"noclip": false,
		"expected_frame_count": 9,
		"frame_count": frames.size(),
		"frames": frames,
		"legs": legs,
		"shop_results": shop_results,
		"semantic_seam_chains": semantic_seam_chains,
		"vertical_core": vertical,
		"literal_route_sequence": "Orison interior -> street -> bodega -> Passage/shops -> Orison -> F02 -> F01 hall",
		"interactions": interactions,
		"lifecycle_boundary": {
			"one_complete_root_per_process": true,
			"root_remains_live_until_process_exit": true,
			"render_nodes_or_provider_not_mutated_after_capture": true,
			"live_root_public_teardown_receipt":
					"m11c2_production_matrix_receipt.json",
		},
	}


func _capture_vertical_core_round_trip(player: PlayerController,
		output_dir: String, frame_start_index: int) -> Dictionary:
	var stairs: Array = _layout.get("stairs", [])
	if stairs.is_empty() or stairs[0] is not Dictionary:
		return {"status": "FAIL", "reason": "production stair record missing",
				"frames": []}
	var parts: Array = (stairs[0] as Dictionary).get("parts", [])
	var first: Dictionary = {}
	var turn: Dictionary = {}
	var second: Dictionary = {}
	var arrival: Dictionary = {}
	for raw: Variant in parts:
		if raw is not Dictionary:
			continue
		var part: Dictionary = raw
		if str(part.get("kind", "")) == "flight" \
				and is_equal_approx(float(part.get("z0", -99.0)), 0.0):
			first = part
		elif str(part.get("kind", "")) == "landing" \
				and is_equal_approx(float(part.get("z", -99.0)), 1.6):
			turn = part
		elif str(part.get("kind", "")) == "flight" \
				and is_equal_approx(float(part.get("z0", -99.0)), 1.6):
			second = part
		elif str(part.get("kind", "")) == "landing" \
				and is_equal_approx(float(part.get("z", -99.0)), 3.2):
			arrival = part
	if first.is_empty() or turn.is_empty() or second.is_empty() \
			or arrival.is_empty():
		return {"status": "FAIL", "reason": "F01/F02 stair topology incomplete",
				"frames": []}
	var offset := _route_ground_offset()
	var f01_hall := _room_rect("F01", "F01_HALL")
	var f01_atrium := _room_rect("F01", "F01_ATRIUM")
	var f02_hall := _room_rect("F02", "F02_HALL")
	var f02_atrium := _room_rect("F02", "F02_ATRIUM")
	if f01_hall.size() != 4 or f01_atrium.size() != 4 \
			or f02_hall.size() != 4 or f02_atrium.size() != 4:
		return {"status": "FAIL", "reason": "authored F01/F02 hall topology missing",
				"frames": []}

	# These are the same production-layout-derived common-space connectors used
	# by the matrix. No world point is embedded in this capture harness.
	var first_x := (float(first.get("b0", 0.0)) \
			+ float(first.get("b1", 0.0))) * 0.5
	var hall_x := (float(f01_hall[0]) + float(f01_hall[2])) * 0.5
	var hall_y := (float(f01_hall[1]) + float(f01_hall[3])) * 0.5
	var atrium_x := (float(f01_atrium[0]) + float(f01_atrium[2])) * 0.5
	var atrium_south_y := float(f01_atrium[1])
	var atrium_depth := float(f01_atrium[3]) - atrium_south_y
	var atrium_inside_y := atrium_south_y + atrium_depth * 0.1
	var foot_y := (atrium_south_y + float(first.get("start", 0.0))) * 0.5
	var entry_path: Array[Vector3] = [
		_plan_point(hall_x, hall_y, float(first.get("z0", 0.0)) + offset),
		_plan_point(atrium_x, atrium_inside_y,
				float(first.get("z0", 0.0)) + offset),
		_plan_point(first_x, foot_y, float(first.get("z0", 0.0)) + offset),
	]
	var up: Array[Vector3] = []
	_append_flight_waypoints(up, first, offset)
	_append_landing_turn(up, turn, first, second, offset)
	_append_flight_waypoints(up, second, offset)
	var arrival_rect: Array = arrival.get("rect", [])
	if arrival_rect.size() != 4:
		return {"status": "FAIL", "reason": "F02 arrival rect missing",
				"frames": []}
	up.append(_plan_point((float(arrival_rect[0]) + float(arrival_rect[2])) * 0.5,
			(float(arrival_rect[1]) + float(arrival_rect[3])) * 0.5,
			float(arrival.get("z", 0.0)) + offset))
	var f02_hall_x := (float(f02_hall[0]) + float(f02_hall[2])) * 0.5
	var f02_hall_y := (float(f02_hall[1]) + float(f02_hall[3])) * 0.5
	var f02_atrium_x := (float(f02_atrium[0]) + float(f02_atrium[2])) * 0.5
	var f02_atrium_south_y := float(f02_atrium[1])
	var f02_atrium_depth := float(f02_atrium[3]) - f02_atrium_south_y
	up.append(_plan_point(f02_atrium_x,
			f02_atrium_south_y + f02_atrium_depth * 0.1,
			float(arrival.get("z", 0.0)) + offset))
	up.append(_plan_point(f02_hall_x, f02_hall_y,
			float(arrival.get("z", 0.0)) + offset))
	if up.size() < 2:
		return {"status": "FAIL", "reason": "derived stair route has no arrival",
				"frames": []}

	var connector := await _walk_waypoints(player, entry_path, {},
			"lobby_to_public_core")
	var ascent := await _walk_waypoints(player, up, {},
			"f01_to_f02_public_stair")
	var frames: Array[Dictionary] = []
	var f02_target := up[up.size() - 2]
	frames.append(await _capture_route_frame(player, output_dir,
			frame_start_index, "f02_public_hall_arrival", f02_target))
	var down: Array[Vector3] = up.duplicate()
	down.reverse()
	down.append(entry_path[entry_path.size() - 1])
	var descent := await _walk_waypoints(player, down, {},
			"f02_to_f01_public_stair")
	var return_path: Array[Vector3] = entry_path.duplicate()
	return_path.reverse()
	var return_to_hall := await _walk_waypoints(player, return_path, {},
			"public_core_to_f01_hall")
	frames.append(await _capture_route_frame(player, output_dir,
			frame_start_index + 1, "f01_public_hall_return", entry_path[1]))
	var elevator: Dictionary = _layout.get("elevator", {})
	var stops: Dictionary = elevator.get("stops", {})
	var elevator_contract := stops.has("F01") and stops.has("F02") \
			and is_equal_approx(float(stops.F01), 0.0) \
			and float(elevator.get("door_w", 0.0)) \
					>= PlayerController.BODY_RADIUS * 2.0
	var frames_ok := frames.size() == 2
	for frame: Dictionary in frames:
		frames_ok = frames_ok and str(frame.get("status", "FAIL")) == "PASS"
	var ok := bool(connector.get("reached", false)) \
			and bool(ascent.get("reached", false)) \
			and bool(descent.get("reached", false)) \
			and bool(return_to_hall.get("reached", false)) \
			and elevator_contract and frames_ok
	return {
		"status": "PASS" if ok else "FAIL",
		"source": PROD_LAYOUT_PATH,
		"source_sha256": FileAccess.get_sha256(PROD_LAYOUT_PATH),
		"derived_without_embedded_coordinates": true,
		"initial_placement_or_teleport": false,
		"connector": connector,
		"ascent": ascent,
		"descent": descent,
		"return_to_hall": return_to_hall,
		"elevator_f01_f02_contract": elevator_contract,
		"frames": frames,
	}


func _room_rect(floor_id: String, room_id: String) -> Array:
	for raw_floor: Variant in _layout.get("floors", []):
		if raw_floor is not Dictionary or str(raw_floor.get("id", "")) != floor_id:
			continue
		for raw_room: Variant in raw_floor.get("rooms", []):
			if raw_room is Dictionary and str(raw_room.get("id", "")) == room_id:
				return (raw_room.get("rect", []) as Array).duplicate()
	return []


func _capture_route_frame(player: PlayerController, output_dir: String,
		index: int, label: String, target_feet: Vector3) -> Dictionary:
	var camera := player.camera
	if camera == null:
		return {"status": "FAIL", "label": label,
				"reason": "production camera missing"}
	var target := target_feet + Vector3.UP * PlayerController.STANDING_EYE
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	await _settle_render()
	var image := get_viewport().get_texture().get_image()
	var dimensions := image.get_size() if image != null else Vector2i.ZERO
	var readability := _image_readability(image)
	var path := output_dir.path_join("%02d_%s.png" % [index + 1,
			_safe_slug(label)])
	var saved := image != null and image.save_png(path) == OK
	image = null
	var hash := Support.file_sha256(path) if saved else ""
	var ok := saved and hash.length() == 64 and dimensions == EXPECTED_SIZE \
			and bool(readability.get("passed", false)) and player.is_on_floor() \
			and not player.noclip
	return {
		"status": "PASS" if ok else "FAIL",
		"label": label,
		"png": path,
		"png_sha256": hash,
		"dimensions": [dimensions.x, dimensions.y],
		"player_feet": Support.vector3_array(player.global_position),
		"camera_eye": Support.vector3_array(camera.global_position),
		"look_target": Support.vector3_array(target),
		"readability": readability,
		"grounded": player.is_on_floor(),
		"noclip": player.noclip,
		"production_player_camera": true,
	}


func _instantiate_production_root() -> Node:
	if Selector.DEFAULT_ID != "v1" or Selector.selected_id() != "v1":
		_fail("capture selector is not the committed v1 production root")
		return null
	var packed := load(Selector.scene_path()) as PackedScene
	if packed == null:
		_fail("capture could not load the selected production root")
		return null
	var root := packed.instantiate()
	add_child(root)
	await _settle_render()
	if not root.has_method("active_floor01_geometry_mode"):
		_fail("production root lacks F01 provider API")
		return null
	return root


func _interact_door(root: Node, identity: String, player: PlayerController,
		expect_locked: bool) -> Dictionary:
	if identity.is_empty():
		return {"ok": true, "identity": "", "action": "none"}
	var matches := root.find_children(identity, "", true, false)
	var interactables: Array[Node] = []
	for candidate: Node in matches:
		if candidate.has_method("interact"):
			interactables.append(candidate)
	if interactables.size() != 1:
		return {"ok": false, "identity": identity,
				"reason": "public interaction owner must resolve exactly once",
				"matching_interactable_count": interactables.size(),
				"all_name_matches": matches.size()}
	var door: Node = interactables[0]
	var was_open := bool(door.get("open"))
	var interaction_called := false
	var settle_physics_frames := 0
	var settle_wall_ms := 0.0
	var settle_simulated_seconds := 0.0
	if not was_open or expect_locked:
		interaction_called = true
		var settle_started := Time.get_ticks_usec()
		door.call("interact", player)
		var physics_ticks := maxi(1, Engine.physics_ticks_per_second)
		settle_physics_frames = mini(120,
				maxi(1, ceili(DOOR_PHYSICAL_SETTLE_SECONDS * physics_ticks)))
		for _frame: int in settle_physics_frames:
			await get_tree().physics_frame
		settle_wall_ms = float(Time.get_ticks_usec() - settle_started) / 1000.0
		settle_simulated_seconds = float(settle_physics_frames) \
				/ float(physics_ticks)
	var is_open := bool(door.get("open"))
	var leaf_state := str(door.get("leaf_state"))
	var ok := not is_open and leaf_state == "locked" \
			if expect_locked else is_open
	return {"ok": ok, "identity": identity, "was_open": was_open,
			"open_after": is_open, "leaf_state_after": leaf_state,
			"public_interact": true, "expected_locked": expect_locked,
			"interaction_called": interaction_called,
			"physical_settle_required_seconds": DOOR_PHYSICAL_SETTLE_SECONDS,
			"physical_settle_physics_frames": settle_physics_frames,
			"physical_settle_simulated_seconds": settle_simulated_seconds,
			"physical_settle_wall_ms": settle_wall_ms,
			"matching_interactable_count": interactables.size(),
			"all_name_matches": matches.size()}


func _walk_to(player: PlayerController, target: Vector3, spec: Dictionary,
		label: String, expect_blocked := false) -> Dictionary:
	var waypoints: Array[Vector3] = [target]
	return await _walk_waypoints(player, waypoints, spec, label, expect_blocked)


func _walk_config_waypoints(player: PlayerController, raw_waypoints: Variant,
		spec: Dictionary, label: String, expect_blocked := false) -> Dictionary:
	var waypoints: Array[Vector3] = []
	if raw_waypoints is Array:
		for raw: Variant in raw_waypoints:
			waypoints.append(Support.vector3(raw))
	return await _walk_waypoints(player, waypoints, spec, label, expect_blocked)


func _walk_semantic_seam_chain(player: PlayerController, raw_sublegs: Array,
		label: String) -> Dictionary:
	var reached_all := not raw_sublegs.is_empty()
	var sublegs: Array[Dictionary] = []
	for index: int in raw_sublegs.size():
		var raw: Variant = raw_sublegs[index]
		if raw is not Dictionary:
			reached_all = false
			sublegs.append({"index": index, "reached": false,
					"reason": "semantic subleg is not a dictionary"})
			break
		var subleg: Dictionary = raw
		var authority_id := str(subleg.get("authority_id", ""))
		var endpoint_role := str(subleg.get("endpoint_role", ""))
		var record: Dictionary = subleg.get("record", {}) as Dictionary
		var raw_endpoint: Variant = record.get(endpoint_role)
		var endpoint_valid := not authority_id.is_empty() \
				and endpoint_role == "start" and raw_endpoint is Array \
				and (raw_endpoint as Array).size() == 3
		var target := Support.vector3(raw_endpoint) if endpoint_valid else Vector3.INF
		endpoint_valid = endpoint_valid and target.is_finite()
		var authority_payload := {
			"seam_id": authority_id,
			"traversal_id": str(record.get("id", "")),
			"record": record,
		}
		var authority_sha256 := JSON.stringify(
				authority_payload, "", true, true).sha256_text()
		var endpoint_sha256 := JSON.stringify(
				raw_endpoint, "", true, true).sha256_text() \
				if endpoint_valid else ""
		var movement: Dictionary
		if endpoint_valid:
			movement = await _walk_to(player, target, record,
					"%s_%02d" % [label, index + 1])
		else:
			movement = {"reached": false,
					"reason": "invalid semantic endpoint record"}
		var reached := endpoint_valid and bool(movement.get("reached", false))
		sublegs.append({
			"index": index,
			"reached": reached,
			"authority_id": authority_id,
			"traversal_id": str(record.get("id", "")),
			"endpoint_role": endpoint_role,
			"relationship": str(subleg.get("relationship", "")),
			"authority_sha256": authority_sha256,
			"endpoint_sha256": endpoint_sha256,
			"source_contract_sha256": M11C1_CONFIG_LF_SHA256,
			"endpoint_coordinates_recorded": false,
			"movement": _coordinate_free_movement_receipt(movement),
		})
		if not reached:
			reached_all = false
			break
	return {
		"id": label,
		"reached": reached_all,
		"authority": "immutable M11C1 semantic seam endpoints",
		"source_contract": M11C1_CONFIG_PATH,
		"source_contract_sha256": M11C1_CONFIG_LF_SHA256,
		"endpoint_coordinates_recorded": false,
		"subleg_count": sublegs.size(),
		"sublegs": sublegs,
	}


func _coordinate_free_movement_receipt(movement: Dictionary) -> Dictionary:
	return {
		"reached": bool(movement.get("reached", false)),
		"physics_frames": int(movement.get("physics_frames", 0)),
		"grounded_fraction": float(movement.get("grounded_fraction", 0.0)),
		"noclip": bool(movement.get("noclip", false)),
		"collision_layer": int(movement.get("collision_layer", 0)),
		"collision_mask": int(movement.get("collision_mask", 0)),
		"coordinate_fields_omitted": true,
	}


func _walk_waypoints(player: PlayerController, waypoints: Array[Vector3],
		spec: Dictionary, label: String, expect_blocked := false) -> Dictionary:
	var tolerance := float(spec.get("waypoint_tolerance_m", 0.16))
	var vertical_tolerance := float(spec.get("vertical_tolerance_m", 0.24))
	var samples := 0
	var grounded := 0
	var rows: Array[Dictionary] = []
	var reached_all := true
	for target: Vector3 in waypoints:
		var distance := _planar_distance(player.global_position, target)
		var max_frames := maxi(int(spec.get("max_frames_per_waypoint", 420)),
				int(ceil(distance * 48.0)) + 180)
		if expect_blocked:
			max_frames = mini(max_frames, 180)
		var frames := 0
		while not _point_reached(player.global_position, target, tolerance,
				vertical_tolerance) and frames < max_frames:
			var delta := target - player.global_position
			delta.y = 0.0
			player.autopilot = delta.normalized() \
					if delta.length_squared() > 0.0001 else Vector3.ZERO
			await get_tree().physics_frame
			frames += 1
			samples += 1
			if player.is_on_floor():
				grounded += 1
		var reached := _point_reached(player.global_position, target, tolerance,
				vertical_tolerance)
		rows.append({"target": Support.vector3_array(target),
				"finish": Support.vector3_array(player.global_position),
				"frames": frames, "reached": reached})
		if not reached:
			reached_all = false
			break
	player.autopilot = Vector3.ZERO
	await get_tree().physics_frame
	var grounded_fraction := float(grounded) / maxf(1.0, float(samples))
	return {"id": label,
		"reached": reached_all and grounded_fraction >= 0.90,
		"expected_blocked": expect_blocked,
		"waypoints": rows,
		"physics_frames": samples,
		"grounded_fraction": grounded_fraction,
		"noclip": player.noclip,
		"collision_layer": player.collision_layer,
		"collision_mask": player.collision_mask}


func _traversal(seam_id: String, index: int) -> Dictionary:
	var seam: Dictionary = _seams.get(seam_id, {})
	var rows: Array = seam.get("traversals", [])
	return rows[index] as Dictionary if index >= 0 and index < rows.size() \
			and rows[index] is Dictionary else {}


func _append_flight_waypoints(out: Array[Vector3], flight: Dictionary,
		offset: float) -> void:
	var n := int(flight.get("n", 0))
	var rise := float(flight.get("rise", 0.0))
	var tread := float(flight.get("tread", 0.0))
	var start := float(flight.get("start", 0.0))
	var direction := float(flight.get("dir", 0.0))
	var x := (float(flight.get("b0", 0.0)) \
			+ float(flight.get("b1", 0.0))) * 0.5
	var z0 := float(flight.get("z0", 0.0))
	for index in range(1, n):
		out.append(_plan_point(x, start + direction * float(index) * tread,
				z0 + float(index) * rise + offset))


func _append_landing_turn(out: Array[Vector3], landing: Dictionary,
		first: Dictionary, second: Dictionary, offset: float) -> void:
	var rect: Array = landing.get("rect", [])
	var y := (float(rect[1]) + float(rect[3])) * 0.5
	var first_x := (float(first.get("b0", 0.0)) \
			+ float(first.get("b1", 0.0))) * 0.5
	var second_x := (float(second.get("b0", 0.0)) \
			+ float(second.get("b1", 0.0))) * 0.5
	var height := float(landing.get("z", 0.0)) + offset
	out.append(_plan_point(first_x, y, height))
	out.append(_plan_point(second_x, y, height))
	out.append(_plan_point(second_x, float(second.get("start", 0.0)), height))


func _plan_point(x: float, plan_y: float, height: float) -> Vector3:
	return Vector3(x, height, -plan_y)


func _route_ground_offset() -> float:
	return Support.vector3(_traversal(
			"SEAM_ORISON_SOUTH_SHELL_STREET", 0).get("start", [])).y


func _camera_occlusion(player: PlayerController, camera: Camera3D,
		target: Vector3) -> Dictionary:
	var total := camera.global_position.distance_to(target)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_distance := total
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", camera.global_position)
		hit_distance = camera.global_position.distance_to(hit_position)
	var fraction := hit_distance / maxf(total, 0.001)
	return {"passed": fraction >= MINIMUM_TARGET_VISIBILITY_FRACTION,
		"target_distance_m": total, "first_hit_distance_m": hit_distance,
		"visible_fraction": fraction,
		"minimum_visible_fraction": MINIMUM_TARGET_VISIBILITY_FRACTION,
		"first_hit_class": hit.get("collider").get_class() \
				if hit.get("collider") is Object else ""}


func _image_readability(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {"passed": false, "reason": "viewport image unavailable"}
	var sample := image.duplicate() as Image
	sample.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var luma_total := 0.0
	var dark := 0
	var pixels := sample.get_width() * sample.get_height()
	for y: int in sample.get_height():
		for x: int in sample.get_width():
			var color := sample.get_pixel(x, y)
			var luma := (color.r * 0.2126 + color.g * 0.7152 \
					+ color.b * 0.0722) * 255.0
			luma_total += luma
			if luma < 16.0:
				dark += 1
	var mean := luma_total / maxf(1.0, float(pixels))
	var dark_fraction := float(dark) / maxf(1.0, float(pixels))
	return {"passed": mean >= MINIMUM_MEAN_LUMA \
			and dark_fraction <= MAXIMUM_DARK_PIXEL_FRACTION,
		"mean_luma_255": mean, "fraction_below_16": dark_fraction,
		"minimum_mean_luma_255": MINIMUM_MEAN_LUMA,
		"maximum_fraction_below_16": MAXIMUM_DARK_PIXEL_FRACTION}


func _image_difference(first_path: String, second_path: String) -> Dictionary:
	var first := Image.load_from_file(first_path)
	var second := Image.load_from_file(second_path)
	if first == null or second == null or first.is_empty() or second.is_empty() \
			or first.get_size() != second.get_size():
		return {"available": false}
	first.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	second.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var absolute_total := 0.0
	var changed := 0
	var pixels := first.get_width() * first.get_height()
	for y: int in first.get_height():
		for x: int in first.get_width():
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			var difference := (absf(a.r - b.r) + absf(a.g - b.g) \
					+ absf(a.b - b.b)) / 3.0
			absolute_total += difference
			if difference > (8.0 / 255.0):
				changed += 1
	return {"available": true,
		"sample_dimensions": [first.get_width(), first.get_height()],
		"mean_absolute_rgb_255": absolute_total / maxf(1.0, float(pixels)) * 255.0,
		"fraction_changed_above_8_255": float(changed) / maxf(1.0, float(pixels)),
		"technical_gate": false,
		"reason": "human review judges visible seam continuity"}


func _point_reached(at: Vector3, target: Vector3, horizontal: float,
		vertical: float) -> bool:
	return _planar_distance(at, target) <= horizontal \
			and absf(at.y - target.y) <= vertical


func _planar_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _crossed_between(first: Vector3, second: Vector3,
		raw_plane: Variant) -> bool:
	if raw_plane is not Dictionary:
		return false
	var point := Support.vector3(raw_plane.get("point", []))
	var normal := Support.vector3(raw_plane.get("normal", [])).normalized()
	if not point.is_finite() or not normal.is_finite() or normal.is_zero_approx():
		return false
	var a := (first - point).dot(normal)
	var b := (second - point).dot(normal)
	return a * b < 0.0 and absf(a) >= 0.15 and absf(b) >= 0.15


func _prepare_world_facts() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {
		"phase": FirstShiftDirector.PHASE_COMPLETE,
		"report_id": ChirpHunt.JOB_ID,
		"filing": "fault_corrected",
	}
	RealityState.data.core_loop = {
		"safe_return_anchor": "F04_B_BED",
		"boundary": "wake_complete",
	}
	var fixed_clock := CampaignClock.new()
	if not fixed_clock.configure_start("mon", 243, PROOF_MINUTE):
		_fail("public CampaignClock refused fixed capture epoch")


func _simulation_facts() -> Dictionary:
	return {
		"intro_complete": RealityState.data.get("intro_complete", false),
		"first_shift": RealityState.data.get("first_shift", {}),
		"core_loop": RealityState.data.get("core_loop", {}),
		"campaign_clock": RealityState.data.get("campaign_clock", {}),
	}


func _settle_player(player: PlayerController) -> void:
	var consecutive_grounded_frames := 0
	for _index in 90:
		player.autopilot = Vector3.ZERO
		await get_tree().physics_frame
		if player.is_on_floor():
			consecutive_grounded_frames += 1
			if consecutive_grounded_frames >= 10:
				return
		else:
			consecutive_grounded_frames = 0


func _ground_contact(player: PlayerController) -> Dictionary:
	var start := player.global_position + Vector3.UP * 0.10
	var finish := player.global_position + Vector3.DOWN * 0.30
	var query := PhysicsRayQueryParameters3D.create(start, finish,
			player.collision_mask, [player.get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"hit": false}
	var collider: Variant = hit.get("collider")
	return {
		"hit": true,
		"position": Support.vector3_array(hit.get("position", Vector3.ZERO)),
		"normal": Support.vector3_array(hit.get("normal", Vector3.UP)),
		"collider_class": collider.get_class() if collider is Object else "",
		"collider_name": str(collider.name) if collider is Node else "",
	}


func _settle_render() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _settle(frames: int) -> void:
	for _index in frames:
		await get_tree().process_frame


func _safe_slug(value: String) -> String:
	var result := ""
	for character: String in value.to_lower():
		result += character if character.is_valid_identifier() \
				or (character >= "0" and character <= "9") else "_"
	return result.substr(0, 80)


func _snapshot_globals() -> Dictionary:
	return {
		"reality_data": RealityState.data.duplicate(true),
		"save_path": RealityState.save_path,
		"persistence": RealityState.persistence_enabled,
		"save_write_blocked": RealityState.save_write_blocked,
		"incompatible_save_version": RealityState.incompatible_save_version,
		"acoustic_nodes": AcousticGraphData.nodes.duplicate(true),
		"daynight_present": OS.has_environment("DAYNIGHT"),
		"daynight": OS.get_environment("DAYNIGHT"),
		"daynight_force_present": OS.has_environment("DAYNIGHT_FORCE"),
		"daynight_force": OS.get_environment("DAYNIGHT_FORCE"),
	}


func _restore_globals(snapshot: Dictionary) -> void:
	GeometryConfiguration.reset_for_tests()
	Selector.reset_for_tests()
	RealityState.data = (snapshot.get("reality_data", {}) as Dictionary).duplicate(true)
	RealityState.save_path = str(snapshot.get("save_path", RealityState.SAVE_PATH))
	RealityState.persistence_enabled = bool(snapshot.get("persistence", true))
	RealityState.save_write_blocked = bool(snapshot.get("save_write_blocked", false))
	RealityState.incompatible_save_version = int(snapshot.get(
			"incompatible_save_version", 0))
	AcousticGraphData.nodes = (snapshot.get("acoustic_nodes", {}) as Dictionary).duplicate(true)
	if bool(snapshot.get("daynight_present", false)):
		OS.set_environment("DAYNIGHT", str(snapshot.get("daynight", "")))
	else:
		OS.unset_environment("DAYNIGHT")
	if bool(snapshot.get("daynight_force_present", false)):
		OS.set_environment("DAYNIGHT_FORCE", str(snapshot.get(
				"daynight_force", "")))
	else:
		OS.unset_environment("DAYNIGHT_FORCE")


func _fail(reason: String) -> void:
	if reason not in _failures:
		_failures.append(reason)
	push_error("M11C2 CAPTURE: " + reason)


func _finish(globals: Dictionary, restore_before_quit := true) -> void:
	if restore_before_quit:
		_restore_globals(globals)
	_receipt["failures"] = _failures
	_receipt["status"] = "PASS" if _failures.is_empty() else "FAIL"
	var output := OS.get_environment(RECEIPT_ENV).strip_edges()
	if output.is_empty():
		output = DEFAULT_RECEIPT
	var absolute := ProjectSettings.globalize_path(output) \
			if output.begins_with("user://") else output
	if not output.begins_with("user://") and not output.is_absolute_path():
		_fail("capture receipt path must be absolute or user://")
	else:
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		var file := FileAccess.open(absolute, FileAccess.WRITE)
		if file == null:
			_fail("could not write M11C2 capture receipt")
		else:
			file.store_string(JSON.stringify(_receipt, "\t"))
	print("ORISON V2 M11C2 PRODUCTION CAPTURE: %s failures=%d" % [
			_receipt.status, _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else mini(255, _failures.size()))
