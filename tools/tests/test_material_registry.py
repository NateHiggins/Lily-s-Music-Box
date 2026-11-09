"""Material registry: round trip, subset rule, validation and the live tables."""
import json, sys, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]; sys.path.insert(0, str(ROOT / 'art/tools'))
import material_registry as mr


def write_tables(root: Path, catalog: dict, game: dict, mapping: dict) -> None:
    for rel, data, tail in ((mr.ART_CATALOG, catalog, True), (mr.GAME_CATALOG, game, False),
                            (mr.MAPPING, mapping, True)):
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).write_text(mr._dump(data, tail), encoding='utf8', newline='\n')


class MaterialRegistryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        write_tables(self.root,
                     {'plaster': {'roughness': 0.8}, 'brick': {'roughness': 0.85}, 'wool': {'metallic': 0.0}},
                     {'plaster': {'roughness': 0.8}, 'wool': {'metallic': 0.0}},
                     {'wool': 'procedural/wool', 'appliance': 'ai_materials/appliance',
                      'plaster': 'library/walls/plaster'})

    def tearDown(self):
        self.tmp.cleanup()

    def test_legacy_import_round_trips_byte_for_byte(self):
        registry = mr.import_legacy(self.root, None)
        self.assertEqual(mr.check(self.root, registry), [])
        self.assertEqual([r['id'] for r in registry['materials']], ['plaster', 'brick', 'wool', 'appliance'])

    def test_hand_edited_catalogue_is_reported(self):
        registry = mr.import_legacy(self.root, None)
        path = self.root / mr.GAME_CATALOG
        path.write_text(path.read_text().replace('0.8', '0.7'))
        self.assertTrue(any(mr.GAME_CATALOG in e for e in mr.check(self.root, registry)))

    def test_validation_rules(self):
        registry = mr.import_legacy(self.root, None)
        appliance = registry['materials'][3]
        appliance['in_game_catalog'] = True
        appliance['texture_status'] = 'maybe'
        registry['legacy_order']['catalog_mapping'].pop()
        errors = ' '.join(mr.validate(registry))
        for fragment in ('in_game_catalog needs', 'texture_status must', 'legacy_order'):
            self.assertIn(fragment, errors)

    def test_texture_status_follows_the_trace_sort(self):
        sort = {'assets/building/textures/T_library_walls_plaster_albedo.png': 'v2_live',
                'assets/building/textures/T_ai_materials_wool_rough.png': 'v1_only',
                'assets/building/textures/T_ai_materials_appliance_albedo.png': 'never_loaded'}
        self.assertEqual(mr.texture_status('plaster', 'library/walls/plaster', sort), 'live')
        self.assertEqual(mr.texture_status('wool', 'procedural/wool', sort), 'v1_only')
        self.assertEqual(mr.texture_status('appliance', 'ai_materials/appliance', sort), 'unloaded')
        self.assertEqual(mr.texture_status('brick', None, sort), 'no_maps')

    def test_repository_tables_match_the_registry(self):
        registry = json.loads((ROOT / mr.REGISTRY).read_text(encoding='utf8'))
        self.assertEqual(mr.check(ROOT, registry), [])


if __name__ == '__main__':
    unittest.main()
