"""Installed native telephone stock; no played interaction/appearance grant."""
from pathlib import Path
import hashlib
import json
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NativeSwitchboard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw = (ROOT / 'game/assets/props/house_switchboard.glb').read_bytes()
        size, kind = struct.unpack_from('<II', raw, 12)
        assert raw[:4] == b'glTF' and kind == 0x4e4f534a
        cls.gltf = json.loads(raw[20:20 + size])
        cls.raw_sha256 = hashlib.sha256(raw).hexdigest()
        cls.plan = json.loads((ROOT / 'game/data/orison_v2/house_switchboard.json').read_text())
        cls.report = json.loads((ROOT / 'art/blender/house_switchboard_construction.json').read_text())

    def test_export_reuses_catalogue_without_embedded_or_external_images(self):
        self.assertFalse(self.gltf.get('images'))
        self.assertFalse(self.gltf.get('textures'))
        catalogue = json.loads((ROOT / 'game/data/runtime_material_sets.json').read_text())['materials']
        for material in self.gltf['materials']:
            self.assertIn(material['name'], catalogue)

    def test_export_report_binds_validated_binary_and_uses_only_authored_uv0(self):
        self.assertEqual(self.report['export']['sha256'], self.raw_sha256)
        self.assertEqual(self.report['export']['tangents']['status'], 'PASS')
        for mesh in self.gltf['meshes']:
            for primitive in mesh['primitives']:
                self.assertNotIn('TEXCOORD_1', primitive['attributes'])

    def test_export_has_every_declared_stock_with_uv_normal_and_tangent(self):
        names = {n['name'] for n in self.gltf['nodes'] if 'mesh' in n}
        self.assertEqual(names, set(self.plan['parts']))
        self.assertEqual(names, set(self.report['parts']))
        for mesh in self.gltf['meshes']:
            for primitive in mesh['primitives']:
                self.assertTrue({'POSITION', 'NORMAL', 'TANGENT', 'TEXCOORD_0'} <= primitive['attributes'].keys())

    def test_construction_is_bound_to_current_recipe_and_closed_stock(self):
        for relative, expected in self.report['source_bindings'].items():
            raw = (ROOT / relative).read_bytes().replace(b'\r\n', b'\n')
            self.assertEqual(hashlib.sha256(raw).hexdigest(), expected, relative)
        for name, part in self.report['parts'].items():
            with self.subTest(stock=name):
                self.assertEqual(part['nonmanifold_edges'], 0)
                self.assertEqual(part['degenerate_uv'], 0)
                self.assertGreater(part['volume_m3'], 0)
        self.assertEqual(self.report['native_checks']['bore_clearance_samples'], 306)
        self.assertEqual(self.report['native_checks']['collar_bearing_samples'], 288)

    def test_ports_use_actual_insulator_bore_and_registered_caller(self):
        self.assertEqual(self.plan['ports'], self.report['ports'])
        self.assertEqual(len({p['id'] for p in self.plan['ports']}), 18)
        for port in self.plan['ports']:
            self.assertEqual(port['bore_m'], .016)
            self.assertGreater(port['bore_m'] / 2, self.plan['plug']['shaft_radius_m'])
        self.assertEqual(self.plan['calling_ports'], [{'endpoint': 'F02_A_TELEPHONE', 'port': '0_0'}])


if __name__ == '__main__':
    unittest.main()
