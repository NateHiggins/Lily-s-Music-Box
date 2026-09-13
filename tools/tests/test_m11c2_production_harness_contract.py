from __future__ import annotations

import hashlib
import importlib.util
import json
import re
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
TESTS = GAME / "tests"
MATRIX = TESTS / "orison_v2_m11c2_production_matrix.gd"
CAPTURE = TESTS / "orison_v2_m11c2_production_capture.gd"
DOOR_CROSSING = TESTS / "orison_v2_m11c2_door_crossing_support.gd"
CAPTURE_MERGER = ROOT / "tools/merge_m11c2_capture_receipts.py"
CAMPAIGN_SHELL = GAME / "scripts/dream/campaign_shell.gd"
M11C1_CONFIG = (
    ROOT
    / "art/renders/orison_v2/m11c1_owner_first_rehearsal_01/runtime"
    / "m11c1_runtime_config.json"
)
M11C1_LF_SHA256 = (
    "98b57247de62133d270b155bd9b0d8b21c533290887a7ee46bb2012f62918fd7"
)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    match = re.search(rf"(?m)^func {re.escape(name)}\([^\n]*", source)
    if not match:
        raise AssertionError(f"missing GDScript function {name}")
    tail = source[match.start() :]
    next_function = re.search(r"(?m)^func ", tail[match.end() - match.start() :])
    if next_function:
        return tail[: match.end() - match.start() + next_function.start()]
    return tail


class ProductionMatrixContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = read(MATRIX)

    def test_complete_root_is_loaded_only_through_selector(self) -> None:
        self.assertIn('Selector.reset_for_tests("v1")', self.source)
        self.assertIn("load(Selector.scene_path()) as PackedScene", self.source)
        self.assertIn('Selector.DEFAULT_ID == "v1"', self.source)
        self.assertNotIn(
            'preload("res://scenes/building/orison_root.tscn")', self.source
        )
        self.assertNotIn("orison_v2_runtime.tscn", self.source)
        self.assertIn("MATRIX_HARNESS_PATH", self.source)
        self.assertIn('FileAccess.get_sha256(\n\t\t\tMATRIX_HARNESS_PATH)', self.source)

    def test_both_session_only_geometry_modes_are_complete_cycles(self) -> None:
        for token in (
            '&"legacy_monolith"',
            '&"owner_first_cells"',
            '"cycle_1"',
            '"cycle_2"',
            '"warmup"',
            '"resource_xor"',
            '"simultaneous"',
            'root.call("teardown_floor01_geometry")',
            "weakref(root)",
            "Support.object_delta",
        ):
            self.assertIn(token, self.source)

    def test_direct_cycle_uses_campaign_scene_replacement_boundary(self) -> None:
        body = function_body(self.source, "_run_direct_cycle")
        for token in (
            "root.get_parent().remove_child(root)",
            "root.free()",
            "await _settle_teardown(6)",
            '"ok_components": ok_components',
            '"contract":',
            '"route":',
            '"public_interaction_prompt":',
            '"tracked_weakrefs_released":',
            '"lifecycle_delta_clean":',
        ):
            self.assertIn(token, body)
        self.assertNotIn("root.queue_free()", body)

    def test_campaign_reconstruction_is_a_real_disk_transaction(self) -> None:
        body = function_body(self.source, "_campaign_reconstruction")
        prepare = body.index("_prepare_campaign_facts()")
        persistence = body.index("RealityState.persistence_enabled = true")
        save = body.index("RealityState.save_game()")
        load = body.index("RealityState.load_game()")
        shell_count = body.count("CampaignShell.new()")
        self.assertLess(prepare, persistence)
        self.assertLess(persistence, save)
        self.assertLess(save, load)
        self.assertEqual(shell_count, 2)
        self.assertIn("_forbidden_save_fact", body)
        self.assertIn("origin.teardown_active_world()", body)
        self.assertIn("shell.teardown_active_world()", body)
        self.assertNotIn('origin_world.call(\n\t\t\t"teardown_floor01_geometry")', body)
        self.assertIn(
            'str(_configuration.call("selected_mode")) == reconstruction_mode',
            body,
        )

    def test_campaign_shell_owns_safe_public_world_replacement(self) -> None:
        source = read(CAMPAIGN_SHELL)
        replacement = function_body(source, "_replace_world")
        teardown = function_body(source, "teardown_active_world")
        self.assertIn("var teardown := teardown_active_world()", replacement)
        self.assertIn("return false", replacement)
        self.assertIn("return true", replacement)
        self.assertNotIn("active_world.free()", replacement)
        for token in (
            'retiring.has_method("teardown_floor01_geometry")',
            'retiring.call("teardown_floor01_geometry")',
            "retiring.queue_free()",
            "world_slot.remove_child(retiring)",
            '"synchronous_world_free": false',
            '"retained_instances"',
            '"retained_resources"',
            '"retained_strong_references"',
        ):
            self.assertIn(token, teardown)
        self.assertNotIn("retiring.free()", teardown)
        restore = function_body(source, "_restore_world")
        swap = function_body(source, "_apply_world_swap")
        self.assertIn('if _replace_world("dream"):', restore)
        self.assertIn('if _replace_world("waking"):', restore)
        self.assertIn('if _replace_world("dream"):', swap)
        self.assertIn('if _replace_world("waking"):', swap)

    def test_reconstruction_executes_both_rollback_directions(self) -> None:
        for token in (
            '"legacy_monolith_to_owner_first_cells"',
            '"owner_first_cells_to_legacy_monolith"',
            '"cross_mode": save_mode != reconstruction_mode',
            '"provider_identity_absent_from_save"',
            '"semantic_world_equal_across_transaction"',
        ):
            self.assertIn(token, self.source)

    def test_runtime_owners_and_public_interactions_are_exact_once(self) -> None:
        for token in (
            '"legacy_monolith_mounted"',
            '"public_reference_is_unique_instance"',
            'scope.find_children("*", type_name, true, false)',
            'ancestor.is_in_group("campaign_shell")',
            'if interactables.size() != 1:',
            '"matching_interactable_count": interactables.size()',
        ):
            self.assertIn(token, self.source)

        route = function_body(self.source, "_continuous_route")
        door = function_body(self.source, "_open_public_door")
        self.assertEqual(route.count("await _open_public_door"), 3)
        for token in (
            "DOOR_PHYSICAL_SETTLE_SECONDS := 0.60",
            'door.call("interact", player)',
            "await get_tree().physics_frame",
            '"physical_settle_physics_frames"',
            '"physical_settle_simulated_seconds"',
            '"physical_settle_wall_ms"',
        ):
            self.assertIn(token, self.source if token.startswith("DOOR_") else door)

    def test_m11a_remains_a_separate_public_scene_lifecycle(self) -> None:
        body = function_body(self.source, "_exercise_m11a_lifecycle")
        for token in (
            "M11A_SCENE_PATH",
            'instance.call("route", route_id)',
            '"resolve_threshold", threshold_id',
            '"F01_BODEGA_DOOR"',
            '"m11a_exterior_threshold"',
            'instance.call("shutdown_for_tests")',
            '"already_torn_down"',
            '"complete_building_root_co_mounted"',
            '"tracked_weakrefs_released"',
            '"normalized_result"',
        ):
            self.assertIn(token, body)
        self.assertNotIn("add_child(instance)", function_body(
            self.source, "_run_direct_cycle"
        ))

    def test_matrix_uses_hash_bound_spatial_contract_not_copied_coordinates(self) -> None:
        self.assertIn(M11C1_LF_SHA256, self.source)
        self.assertIn("M11C1_CONFIG_PATH", self.source)
        route = function_body(self.source, "_continuous_route")
        self.assertEqual(route.count("player.global_position ="), 1)
        self.assertIn('"initial_placement_count": 1', route)
        self.assertIn('"intermediate_transform_writes": 0', route)
        self.assertIn('"teleports": 0', route)
        self.assertIn("player.autopilot", self.source)

        seam_chain = function_body(self.source, "_walk_semantic_seam_chain")
        self.assertEqual(route.count("_walk_semantic_seam_chain"), 2)
        for token in (
            '"authority_id"',
            '"authority_sha256"',
            '"endpoint_sha256"',
            '"source_contract_sha256": M11C1_CONFIG_LF_SHA256',
            '"endpoint_coordinates_recorded": false',
            '"sublegs"',
            "await _walk_to(player, target, record",
        ):
            self.assertIn(token, seam_chain)
        self.assertNotIn("nav.route(", route + seam_chain)
        self.assertIn('"record": shell', route)
        self.assertIn('"record": portal', route)

        walker = function_body(self.source, "_walk_waypoints")
        collision_collector = function_body(self.source, "_collect_slide_collisions")
        for token in (
            "player.get_slide_collision_count()",
            "player.get_slide_collision(",
            "collision.get_collider()",
            "collision.get_normal()",
            "collision.get_position()",
            '"collider_path"',
            '"collider_class"',
            '"collider_name"',
            '"slide_collision_colliders"',
            '"[M11C2-ROUTE-COLLISIONS]',
        ):
            self.assertIn(token, walker + collision_collector)

    def test_matrix_proves_public_consumers_and_mode_independent_world_facts(self) -> None:
        for token in (
            '"OrisonDetailPass"',
            '"ExteriorDetailPass"',
            '"VantryPointNetwork"',
            '"ResidentNav"',
            '"accessibility"',
            '"acoustic"',
            '"first_shift"',
            '"service_round"',
            '"work_orders"',
            '"semantic_world_equal"',
            '"matched_performance"',
            '"gpu_or_vram_not_inferred_when_unavailable": true',
            '"save_ms"',
            '"reconstructed_campaign_shell_compose_ms"',
            '"raw_coordinates_compared": false',
            '"logical_residency": "FULL_RECOMPOSITION"',
            '"production_clock_frozen": true',
            'const PROOF_CLOCK := "12:30"',
            'OS.set_environment("DAYNIGHT_FORCE", PROOF_CLOCK)',
            'fixed_clock.configure_start("mon", 243, PROOF_MINUTE)',
        ):
            self.assertIn(token, self.source)

    def test_shop_crossing_is_one_provider_independent_hinge_path(self) -> None:
        helper = read(DOOR_CROSSING)
        capture = read(CAPTURE)
        for source in (self.source, capture):
            self.assertIn("DoorCrossingSupport.derive(root,", source)
            self.assertIn('"derived_crossing": crossing_path.get("receipt", {})', source)
            self.assertIn('"applicable": false, "reason": "locked_non_crossable"', source)
        for token in (
            '"applicable": true',
            '"authority": "opening_bounds plus resolved production DoorProp pivot"',
            '"provider_identity_read": false',
            '"shop_identity_branch": false',
            '"coordinate_fields_omitted": true',
            'spec.get("opening_bounds", {})',
            'door.global_position - center',
        ):
            self.assertIn(token, helper)
        self.assertNotRegex(helper, r'if\s+identity\s*==')
        self.assertNotRegex(helper, r'CELL_SHOP_[A-Z_]')

        world_facts = function_body(self.source, "_mode_independent_world_facts")
        self.assertIn("vantry.point_spec(point_id)", world_facts)
        self.assertIn('point.get("floor", "")', world_facts)
        self.assertIn('"authored_floor_ids": vantry_floor_ids', world_facts)
        self.assertIn('"authored_floor_id_sha256"', world_facts)
        self.assertIn("vantry.floor_batch_count() == vantry_floor_ids.size()", world_facts)
        self.assertNotIn("vantry.floor_batch_count() == nav_levels.size()", world_facts)

    def test_complete_world_service_boundary_accounts_for_clock_work(self) -> None:
        boundary = function_body(self.source, "_establish_service_fact_boundary")
        snapshot = function_body(self.source, "_open_work_snapshot")
        for token in (
            "CoreLoopDirector.offer_opening_report",
            "ClockProp.ORDER_ID",
            '"exact_expected_open_work"',
            '"open_simple_order_ids"',
            '"open_maintenance_job_ids"',
            '"aggregate_has_open_work"',
        ):
            self.assertIn(token, boundary + snapshot)
        self.assertIn("orders.serialize_jobs()", snapshot)
        self.assertNotIn("not orders.has_open_work()", boundary)


class ProductionCaptureContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = read(CAPTURE)

    def test_capture_is_forward_plus_exact_size_and_matched(self) -> None:
        for token in (
            "EXPECTED_SIZE := Vector2i(1600, 900)",
            'RenderingServer.get_current_rendering_method() != "forward_plus"',
            '&"legacy_monolith"',
            '&"owner_first_cells"',
            'const PHASE_ENV := "M11C2_CAPTURE_PHASE"',
            '"owner_first_route":',
            '"legacy_route_control":',
            "_capture_config_view",
            "_compare_pairs",
            '"camera_exact"',
            '"pixel_difference"',
            "Support.file_sha256",
            'const PROOF_CLOCK := "12:30"',
            'fixed_clock.configure_start("mon", 243, PROOF_MINUTE)',
            '"one_complete_production_root_per_process": true',
        ):
            self.assertIn(token, self.source)

    def test_capture_uses_production_root_player_camera_and_no_added_content(self) -> None:
        for token in (
            "load(Selector.scene_path()) as PackedScene",
            'root.get("player") as PlayerController',
            "player.camera",
            '"harness_added_geometry": false',
            '"harness_added_collision": false',
            '"harness_added_lights": false',
            '"harness_added_world_environment": false',
            '"harness_added_labels_arrows_or_seam_covers": false',
        ):
            self.assertIn(token, self.source)
        for forbidden in (
            "MeshInstance3D.new()",
            "StaticBody3D.new()",
            "CollisionShape3D.new()",
            "DirectionalLight3D.new()",
            "OmniLight3D.new()",
            "SpotLight3D.new()",
            "WorldEnvironment.new()",
            "Label3D.new()",
            "orison_v2_runtime.tscn",
        ):
            self.assertNotIn(forbidden, self.source)
        self.assertNotIn("root.queue_free()", self.source)
        self.assertNotIn("root.get_parent().remove_child(root)", self.source)
        self.assertNotIn("root.free()", self.source)
        self.assertNotIn("teardown_floor01_geometry", self.source)
        self.assertNotIn('find_children("*", "Light3D"', self.source)

        run = function_body(self.source, "_run")
        for token in (
            '"legacy_monolith":',
            '"owner_first_cells":',
            '"owner_first_route":',
            '"legacy_route_control":',
            '"capture_process_performs_render_node_mutation": false',
            '"capture_process_performs_provider_teardown": false',
            "await _finish(globals, false)",
        ):
            self.assertIn(token, run)
        for name in ("_capture_matched_mode", "_capture_owner_first_route"):
            lifecycle = function_body(self.source, name)
            self.assertIn('"one_complete_root_per_process": true', lifecycle)
            self.assertIn('"root_remains_live_until_process_exit": true', lifecycle)
            self.assertIn(
                '"render_nodes_or_provider_not_mutated_after_capture": true',
                lifecycle,
            )

    def test_process_isolated_capture_merger_is_strict(self) -> None:
        source = read(CAPTURE_MERGER)
        for token in (
            "EXPECTED_PAIR_COUNT = 5",
            "EXPECTED_ROUTE_COUNT = 9",
            "matched simulation hashes differ",
            "camera_exact",
            "dimensions_exact",
            "unknown_error_count",
            "legacy/cell renderer error signatures differ",
            "legacy/cell route renderer error signatures differ",
            "legacy/cell route initial simulation hashes differ",
            "legacy/cell route end simulation hashes differ",
            "matched capture end simulation hashes differ",
            "legacy/cell normalized route contracts differ",
            "cell route contract schema is invalid",
            '"elevator_f01_f02_contract"',
            '"connector"',
            '"ascent"',
            '"descent"',
            '"return_to_hall"',
            '"expected_locked"',
            '"open_after"',
            '"leaf_state_after"',
            '"derived_crossing"',
            "resident_nav_wall_safe_route",
            "production matrix receipt is stale for the current matrix harness",
            "visibility and process-retirement",
            '"technical_lifecycle_gate": False',
            '"tracked_production_cut_owner_retention_gate": True',
            '"status": "PENDING"',
        ):
            self.assertIn(token, source)

    def test_merger_refuses_script_parse_fatal_and_crash_diagnostics(self) -> None:
        spec = importlib.util.spec_from_file_location("m11c2_capture_merge", CAPTURE_MERGER)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "diagnostics.log"
            path.write_text(
                "SCRIPT ERROR: Invalid call.\n"
                "Parse Error: Unexpected token.\n"
                "FATAL: renderer stopped.\n"
                "CrashHandler: Program crashed.\n"
                "ERROR: geom->softshadow_count==0 - BUG!\n",
                encoding="utf-8",
            )
            result = module.log_diagnostics(path)
        self.assertEqual(result["unknown_error_count"], 4)
        self.assertTrue(
            result[
                "historical_forward_plus_visibility_and_process_retirement_diagnostic"
            ]
        )

    def test_merger_consumes_serial_runner_stderr_sidecar(self) -> None:
        spec = importlib.util.spec_from_file_location("m11c2_capture_merge", CAPTURE_MERGER)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.log"
            path.write_text("capture passed\n", encoding="utf-8")
            sidecar = Path(f"{path}.stderr")
            sidecar.write_text(
                "ERROR: BUG, indexing did not unpair geometries from light.\n",
                encoding="utf-8",
            )
            result = module.log_diagnostics(path)
        self.assertTrue(result["stderr_sidecar_consumed"])
        self.assertEqual(len(result["streams"]), 2)
        self.assertEqual(result["known_signature_counts"]["light_geometry_index"], 1)
        self.assertEqual(result["unknown_error_count"], 0)

    def test_route_normalizer_uses_real_schema_and_fails_closed(self) -> None:
        spec = importlib.util.spec_from_file_location("m11c2_capture_merge", CAPTURE_MERGER)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        def movement(identity: str) -> dict:
            return {
                "id": identity,
                "reached": True,
                "expected_blocked": False,
                "noclip": False,
                "collision_layer": 1,
                "collision_mask": 1,
                "grounded_fraction": 1.0,
                "waypoints": [{"reached": True}],
            }

        interaction = {
            "identity": "SITE_SHOP_DOOR_TEST",
            "ok": True,
            "expected_locked": False,
            "open_after": True,
            "leaf_state_after": "open",
            "public_interact": True,
            "matching_interactable_count": 1,
        }
        crossing_receipt = {
            "applicable": True,
            "authority": "opening_bounds plus resolved production DoorProp pivot",
            "door_identity": "SITE_SHOP_DOOR_TEST",
            "source_traversal_id": "PASSAGE_TEST_BIDIRECTIONAL",
            "source_record_sha256": "a" * 64,
            "hinge_jamb": "positive_right_axis",
            "capsule_radius_m": 0.32,
            "half_width_m": 0.8,
            "minimum_side_clearance_m": 0.05,
            "lateral_offset_m": 0.3655,
            "retained_clearance_fraction": 0.85,
            "provider_identity_read": False,
            "shop_identity_branch": False,
            "coordinate_fields_omitted": True,
        }
        crossing = movement("enter_test")
        crossing["return"] = movement("return_test")
        source_contract_hash = "d" * 64
        semantic_leg = {
            "id": "bodega_to_passage_portal",
            "reached": True,
            "authority": "immutable M11C1 semantic seam endpoints",
            "source_contract": "res://../art/runtime/m11c1_runtime_config.json",
            "source_contract_sha256": source_contract_hash,
            "endpoint_coordinates_recorded": False,
            "subleg_count": 1,
            "sublegs": [{
                "index": 0,
                "reached": True,
                "authority_id": "SEAM_STREET_PASSAGE_PORTAL",
                "traversal_id": "STREET_PASSAGE_BIDIRECTIONAL",
                "endpoint_role": "start",
                "relationship": "Passage exterior approach",
                "authority_sha256": "e" * 64,
                "endpoint_sha256": "f" * 64,
                "source_contract_sha256": source_contract_hash,
                "endpoint_coordinates_recorded": False,
                "movement": {
                    "reached": True,
                    "physics_frames": 42,
                    "grounded_fraction": 1.0,
                    "noclip": False,
                    "collision_layer": 1,
                    "collision_mask": 1,
                    "coordinate_fields_omitted": True,
                },
            }],
        }
        route = {
            "status": "PASS",
            "frame_count": 9,
            "literal_route_sequence": "semantic route",
            "initial_placement_count": 1,
            "intermediate_transform_writes": 0,
            "teleports": 0,
            "noclip": False,
            "legs": [movement("street"), semantic_leg],
            "interactions": [interaction],
            "shop_results": [{
                "cell_id": "CELL_SHOP_TEST",
                "approach": movement("approach_test"),
                "interaction": interaction,
                "crossing": crossing,
                "derived_crossing": crossing_receipt,
            }],
            "vertical_core": {
                "status": "PASS",
                "derived_without_embedded_coordinates": True,
                "elevator_f01_f02_contract": True,
                "connector": movement("connector"),
                "ascent": movement("ascent"),
                "descent": movement("descent"),
                "return_to_hall": movement("return_to_hall"),
            },
        }
        normalized = module.route_contract(route)
        self.assertTrue(normalized["vertical"]["elevator_f01_f02_contract"])
        self.assertEqual(normalized["vertical"]["connector"]["id"], "connector")
        self.assertEqual(normalized["legs"][0]["shape"], "movement")
        self.assertEqual(normalized["legs"][1]["shape"], "semantic_chain")
        self.assertEqual(
            normalized["legs"][1]["sublegs"][0]["authority_id"],
            "SEAM_STREET_PASSAGE_PORTAL",
        )
        self.assertEqual(normalized["interactions"][0]["expected_locked"], False)
        self.assertEqual(normalized["interactions"][0]["open_after"], True)
        self.assertEqual(normalized["interactions"][0]["leaf_state_after"], "open")
        self.assertEqual(
            normalized["shops"][0]["derived_crossing"]["hinge_jamb"],
            "positive_right_axis",
        )

        timing_variant = json.loads(json.dumps(route))
        timing_variant["legs"][1]["sublegs"][0]["movement"][
            "grounded_fraction"
        ] = 0.94
        timing_comparison = module.compare_route_contracts(
            module.route_contract(timing_variant), normalized
        )
        self.assertTrue(timing_comparison["semantic_match"])
        self.assertTrue(timing_comparison["all_non_timing_fields_exact"])
        self.assertFalse(
            module.canonical(module.route_contract(timing_variant))
            == module.canonical(normalized)
        )

        ungrounded_variant = json.loads(json.dumps(route))
        ungrounded_variant["legs"][1]["sublegs"][0]["movement"][
            "grounded_fraction"
        ] = 0.89
        self.assertFalse(
            module.compare_route_contracts(
                module.route_contract(ungrounded_variant), normalized
            )["semantic_match"]
        )

        changed_vertical = json.loads(json.dumps(route))
        changed_vertical["vertical_core"]["ascent"]["reached"] = False
        self.assertFalse(
            module.compare_route_contracts(
                module.route_contract(changed_vertical), normalized
            )["semantic_match"]
        )
        self.assertNotEqual(
            module.canonical(normalized),
            module.canonical(module.route_contract(changed_vertical)),
        )
        changed_lock_state = json.loads(json.dumps(route))
        changed_lock_state["interactions"][0]["leaf_state_after"] = "locked"
        self.assertNotEqual(
            module.canonical(normalized),
            module.canonical(module.route_contract(changed_lock_state)),
        )
        changed_semantic_owner = json.loads(json.dumps(route))
        changed_semantic_owner["legs"][1]["sublegs"][0]["authority_sha256"] = (
            "0" * 64
        )
        self.assertNotEqual(
            module.canonical(normalized),
            module.canonical(module.route_contract(changed_semantic_owner)),
        )

        end_facts = {"campaign_clock": {"minute": 60}, "doors": ["open"]}
        end_hash = "b" * 64
        self.assertTrue(
            module.exact_simulation_facts(end_facts, end_hash, end_facts, end_hash)
        )
        changed_end_facts = json.loads(json.dumps(end_facts))
        changed_end_facts["campaign_clock"]["minute"] = 61
        self.assertFalse(
            module.exact_simulation_facts(
                end_facts, end_hash, changed_end_facts, end_hash
            )
        )
        self.assertFalse(
            module.exact_simulation_facts(end_facts, end_hash, end_facts, "c" * 64)
        )

        for missing_path in (
            ("vertical_core", "connector"),
            ("vertical_core", "elevator_f01_f02_contract"),
            ("shop_results", 0, "derived_crossing"),
            ("interactions", 0, "open_after"),
            ("legs", 1, "sublegs", 0, "endpoint_sha256"),
        ):
            malformed = json.loads(json.dumps(route))
            target = malformed
            for component in missing_path[:-1]:
                target = target[component]
            del target[missing_path[-1]]
            with self.subTest(missing_path=missing_path):
                with self.assertRaises(ValueError):
                    module.route_contract(malformed)

        leaked_coordinates = json.loads(json.dumps(route))
        leaked_coordinates["legs"][1]["sublegs"][0]["movement"]["target"] = [
            1.0,
            2.0,
            3.0,
        ]
        with self.assertRaises(ValueError):
            module.route_contract(leaked_coordinates)

    def test_route_is_one_initial_placement_then_collision_bearing(self) -> None:
        body = function_body(self.source, "_capture_owner_first_route")
        self.assertEqual(body.count("player.global_position ="), 1)
        for token in (
            '"initial_placement_count": 1',
            '"intermediate_transform_writes": 0',
            '"teleports": 0',
            '"noclip": false',
            "_walk_config_waypoints",
            "_interact_door",
            '"locked_non_crossable"',
        ):
            self.assertIn(token, body)
        self.assertEqual(body.count("await _interact_door"), 3)
        self.assertEqual(body.count("_walk_semantic_seam_chain"), 2)
        semantic_chain = function_body(self.source, "_walk_semantic_seam_chain")
        for token in (
            '"authority_sha256"',
            '"endpoint_sha256"',
            '"source_contract_sha256": M11C1_CONFIG_LF_SHA256',
            '"endpoint_coordinates_recorded": false',
            '"coordinate_fields_omitted": true',
        ):
            self.assertIn(token, self.source)
        door = function_body(self.source, "_interact_door")
        self.assertIn("DOOR_PHYSICAL_SETTLE_SECONDS := 0.60", self.source)
        self.assertIn('door.call("interact", player)', door)
        self.assertIn("await get_tree().physics_frame", door)
        self.assertIn("_capture_vertical_core_round_trip", body)
        self.assertIn('"expected_frame_count": 9', body)
        self.assertIn('"vertical_core": vertical', body)

        vertical = function_body(self.source, "_capture_vertical_core_round_trip")
        for token in (
            "PROD_LAYOUT_PATH",
            '_room_rect("F01", "F01_HALL")',
            '_room_rect("F01", "F01_ATRIUM")',
            '_room_rect("F02", "F02_HALL")',
            '_room_rect("F02", "F02_ATRIUM")',
            "_append_flight_waypoints",
            "_append_landing_turn",
            '"lobby_to_public_core"',
            '"f01_to_f02_public_stair"',
            '"f02_to_f01_public_stair"',
            '"public_core_to_f01_hall"',
            '"f02_public_hall_arrival"',
            '"f01_public_hall_return"',
            '"initial_placement_or_teleport": false',
            '"derived_without_embedded_coordinates": true',
        ):
            self.assertIn(token, vertical)
        self.assertNotIn("Vector3(", vertical)

    def test_capture_and_matrix_bind_same_immutable_m11c1_contract(self) -> None:
        self.assertIn(M11C1_LF_SHA256, self.source)
        normalized = M11C1_CONFIG.read_bytes().replace(b"\r\n", b"\n")
        self.assertEqual(hashlib.sha256(normalized).hexdigest(), M11C1_LF_SHA256)
        config = json.loads(normalized)
        self.assertEqual(len(config["seams"]), 5)
        self.assertEqual(len(config["capture_views"]), 5)
        self.assertEqual(len(config["save_reconstruction"]["required_cell_ids"]), 17)


class SceneAndDefaultContractTests(unittest.TestCase):
    def test_scenes_are_thin_launchers_for_owned_scripts(self) -> None:
        for stem in (
            "orison_v2_m11c2_production_matrix",
            "orison_v2_m11c2_production_capture",
        ):
            scene = read(TESTS / f"{stem}.tscn")
            self.assertIn(f'path="res://tests/{stem}.gd"', scene)
            self.assertNotIn("MeshInstance3D", scene)
            self.assertNotIn("Camera3D", scene)
            self.assertNotIn("Light3D", scene)

    def test_production_defaults_remain_bounded(self) -> None:
        selector = read(GAME / "scripts/building/building_root_selector.gd")
        configuration = read(
            GAME / "scripts/building/floor01_geometry_configuration.gd"
        )
        self.assertIn('const DEFAULT_ID := "v1"', selector)
        self.assertIn("const DEFAULT_MODE := OWNER_FIRST_CELLS", configuration)
        self.assertIn('"persistent": false', configuration)
        self.assertIn('"save_authority": false', configuration)


if __name__ == "__main__":
    unittest.main()
