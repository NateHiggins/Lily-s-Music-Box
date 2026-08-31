from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "tools" / "m11c0_floor01_rehearsal"
TEMPLATES = HARNESS / "templates"


class M11C0Floor01HarnessContractTest(unittest.TestCase):
    def read(self, name: str) -> str:
        return (TEMPLATES / name).read_text(encoding="utf-8")

    def test_external_project_template_is_forward_plus_1600x900(self) -> None:
        project = self.read("project.godot")
        self.assertIn('run/main_scene="res://harness_main.tscn"', project)
        self.assertIn("window/size/viewport_width=1600", project)
        self.assertIn("window/size/viewport_height=900", project)
        self.assertIn('renderer/rendering_method="forward_plus"', project)

    def test_split_receipt_contract_is_config_driven(self) -> None:
        support = self.read("m11c0_harness_support.gd")
        for token in (
            '"M11C0_CONFIG"',
            '"M11C0_MANIFEST"',
            '"res://split_receipt.json"',
            'entry.get("gltf_path"',
            "ResourceLoader.CACHE_MODE_IGNORE",
        ):
            self.assertIn(token, support)
        self.assertNotIn("game/assets/building/floor_01.gltf", support)

    def test_runtime_measures_two_warmed_cycles_and_public_teardown(self) -> None:
        runtime = self.read("m11c0_runtime_validation.gd")
        composition = self.read("m11c0_cell_composition.gd")
        for token in (
            '"warmup"',
            '"warmed_cycle_1"',
            '"warmed_cycle_2"',
            "_measure_independent",
            "_measure_recomposed",
            "_runtime_equivalence",
            "Support.tree_metrics",
            "Performance.OBJECT_RESOURCE_COUNT",
            "instance_from_id",
            '"PASS_WITH_UNPROVEN_SEAMS"',
        ):
            source = runtime if token != "Performance.OBJECT_RESOURCE_COUNT" else self.read(
                "m11c0_harness_support.gd"
            )
            self.assertIn(token, source)
        self.assertIn("func public_teardown()", composition)
        self.assertIn('"retained_strong_references"', composition)
        self.assertIn('"node_name_reach_ins": false', composition)
        self.assertNotIn(".free()", composition)

    def test_named_seams_refuse_to_fake_missing_collision_facts(self) -> None:
        runtime = self.read("m11c0_runtime_validation.gd")
        support = self.read("m11c0_harness_support.gd")
        self.assertIn('"status":"UNPROVEN"', runtime)
        self.assertIn("no explicit ray endpoints and expected contact", runtime)
        self.assertIn('expected not in ["hit", "clear"]', runtime)
        self.assertIn("seam_unproven = true", runtime)
        self.assertIn("_mark_unproven(reason)", runtime)
        self.assertIn('"hit_position": probe.get("hit_position", [])', runtime)
        self.assertIn('"collider_class": probe.get("collider_class", "")', runtime)
        self.assertIn('manifest.get("shared_boundaries", [])', support)
        self.assertIn('manifest.get("collision_probes", [])', support)

    def test_capture_is_matched_hashed_and_adds_no_scene_content(self) -> None:
        capture = self.read("m11c0_capture.gd")
        for token in (
            'RenderingServer.get_current_rendering_method() != "forward_plus"',
            "EXPECTED_SIZE := Vector2i(1600, 900)",
            '"_original.png"',
            '"_recomposed.png"',
            "Support.file_sha256",
            '"matched_camera"',
            '"harness_added_geometry": false',
            '"harness_added_lights": false',
            '"harness_added_world_environment": false',
            '"harness_added_labels_or_arrows": false',
            'manifest.get("capture_views", [])',
            '"status": "BYTE_IDENTICAL"',
            'var stride := 1',
        ):
            self.assertIn(token, capture)
        for forbidden in (
            "MeshInstance3D.new()",
            "DirectionalLight3D.new()",
            "OmniLight3D.new()",
            "SpotLight3D.new()",
            "WorldEnvironment.new()",
            "Label3D.new()",
        ):
            self.assertNotIn(forbidden, capture)


if __name__ == "__main__":
    unittest.main()
