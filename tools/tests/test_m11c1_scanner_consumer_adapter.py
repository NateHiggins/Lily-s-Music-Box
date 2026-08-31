#!/usr/bin/env python3
"""Static boundary checks for the disposable M11C1 scanner adapter.

Runtime behavior is exercised by the scratch Godot harness. These checks keep
the adapter honest about which production APIs it calls and guard the
full/selective/restored ancestry mechanism against being replaced with visual
visibility alone.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ADAPTER = (
    ROOT
    / "game/tests/orison_v2_m11c1_owner_first"
    / "m11c1_scanner_consumer_adapter.gd"
)

EXPECTED = {
    "HeightmapPass": ("game/scripts/building/heightmap_pass.gd", "build"),
    "SurfacePass": ("game/scripts/building/surface_pass.gd", "apply"),
    "AtmosphericDecalPass": (
        "game/scripts/building/atmospheric_decal_pass.gd",
        "build",
    ),
    "BroadcastDirector": (
        "game/scripts/building/broadcast_director.gd",
        "build",
    ),
    "ArcadeRow": ("game/scripts/building/arcade_row.gd", "install"),
    "FurnitureInteractionPass": (
        "game/scripts/building/furniture_interaction_pass.gd",
        "build",
    ),
    "FoundArtPass": ("game/scripts/building/found_art_pass.gd", "build"),
    "DomesticWitnessSystem": (
        "game/scripts/reality/domestic_witness_system.gd",
        "build",
    ),
    "ApartmentEncroachment": (
        "game/scripts/reality/apartment_encroachment.gd",
        "build",
    ),
    "ResidentRoutines": (
        "game/scripts/characters/resident_routines.gd",
        "bind_floors",
    ),
}


class ScannerConsumerAdapterContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = ADAPTER.read_text(encoding="utf-8")

    def test_every_named_production_consumer_is_bound_to_a_real_api(self) -> None:
        for class_name, (path, api) in EXPECTED.items():
            with self.subTest(class_name=class_name):
                production = (ROOT / path).read_text(encoding="utf-8")
                self.assertRegex(production, rf"(?m)^func {re.escape(api)}\(")
                self.assertIn(f'"{class_name}"', self.source)
                self.assertIn(f'res://{path.removeprefix("game/")}', self.source)

    def test_public_runtime_contract_is_stable(self) -> None:
        self.assertIn(
            'const CONTRACT_ID := "F01_SCANNER_PASS_DIRECTOR_CENSUS"',
            self.source,
        )
        self.assertRegex(
            self.source,
            r"func configure\(layout: Dictionary, composition_host: Node3D,\s*"
            r"cell_registry: Node\) -> bool:",
        )
        self.assertRegex(
            self.source,
            r"func exercise\(full_ids: Array\[String\], selective_ids: "
            r"Array\[String\]\) -> Dictionary:",
        )
        self.assertIn("func public_teardown() -> Dictionary:", self.source)

    def test_selective_residency_changes_scanner_ancestry(self) -> None:
        self.assertIn("instance.reparent(wanted_parent, true)", self.source)
        self.assertIn("_dormant", self.source)
        self.assertIn(
            '"sequence":["FULL", "SELECTIVE", "RESTORED_FULL"]',
            self.source,
        )
        self.assertIn(
            '"inactive_ids_excluded_from_scanner_input"', self.source
        )
        # Hiding a cell alone is not accepted as scanner exclusion.
        self.assertIn('"collision_changed":false', self.source)

    def test_no_spatial_or_node_name_residency_inference(self) -> None:
        self.assertNotIn("global_position", self.source)
        self.assertNotIn("get_aabb", self.source)
        self.assertNotIn("get_node(", self.source)
        self.assertNotIn("get_node_or_null(", self.source)
        self.assertIn(
            '"classification_source":"explicit m11c1_owner_cell metadata',
            self.source,
        )

    def test_teardown_is_queued_and_state_restoring(self) -> None:
        self.assertNotRegex(self.source, r"(?m)(?:^|[.;\s])free\(")
        self.assertIn("_restore_standard_materials", self.source)
        self.assertIn("_restore_surface_overrides", self.source)
        self.assertIn("_restore_wall_art_reservations", self.source)
        self.assertIn("_restore_environment", self.source)
        self.assertIn('"forced_object_deletion":false', self.source)


if __name__ == "__main__":
    unittest.main()
