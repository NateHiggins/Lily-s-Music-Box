"""Pre-existing stale evidence must never become new acceptance by rebinding."""
import copy
import json
import importlib.util
from pathlib import Path
import unittest
import tempfile

path=Path(__file__).resolve().parents[1]/'rebind_additive_material.py'
spec=importlib.util.spec_from_file_location('additive_rebind',path)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class NativeOwnerDiscoveryTest(unittest.TestCase):
    def test_nonprefixed_shop_leaf_owner_is_discovered(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);fixture=root/'game/tests/fixtures/passage_shop_leaves.json'
            fixture.parent.mkdir(parents=True);fixture.write_text('{"source_bindings": {}}')
            self.assertIn(fixture,module.binding_files(root))

    def test_runtime_receipt_is_not_a_construction_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);fixture=root/'game/tests/fixtures/runtime_contract.json'
            fixture.parent.mkdir(parents=True);fixture.write_text('{"source_bindings": {"catalog": "old"}}')
            self.assertNotIn(fixture,module.binding_files(root))

class BaselineDriftGuardTest(unittest.TestCase):
    def setUp(self):
        self.prior={'asset_sha256':'original-geometry','source_bindings':{'catalog':'old-hash'},'parts':[1,2]}

    def test_unchanged_stale_payload_can_remain_stale(self):
        self.assertTrue(module.unchanged_stale_binding(self.prior,copy.deepcopy(self.prior),'catalog','old-hash'))

    def test_replaced_geometry_is_rejected(self):
        current=copy.deepcopy(self.prior);current['asset_sha256']='changed-geometry'
        self.assertFalse(module.unchanged_stale_binding(self.prior,current,'catalog','old-hash'))

    def test_changed_parts_are_rejected(self):
        current=copy.deepcopy(self.prior);current['parts'].append(3)
        self.assertFalse(module.unchanged_stale_binding(self.prior,current,'catalog','old-hash'))

    def test_rewritten_binding_is_rejected(self):
        current=copy.deepcopy(self.prior);current['source_bindings']['catalog']='new-hash'
        self.assertFalse(module.unchanged_stale_binding(self.prior,current,'catalog','new-hash'))

    def test_unrecorded_binding_is_rejected(self):
        self.assertFalse(module.unchanged_stale_binding(self.prior,self.prior,'other','old-hash'))

class RebuiltDependencyGuardTest(unittest.TestCase):
    def encoded(self, parts, catalog):
        return json.dumps({'parts':parts,'asset_sha256':str(parts),'source_bindings':{'catalog':catalog}}).encode()

    def test_fresh_consumer_may_follow_exact_rebuilt_payload_provenance(self):
        prior=self.encoded([1,2],'old')
        original=self.encoded([1,2,3],'old')
        updated=self.encoded([1,2,3],'new')
        expected=module.digest(original)
        self.assertEqual(module.dependency_binding_preimages(prior,original,updated,expected),{expected})
        self.assertEqual(module.dependency_binding_preimages(None,original,updated,expected),{expected})

    def test_old_geometry_hash_cannot_be_carried_to_new_geometry(self):
        prior=self.encoded([1,2],'old')
        original=self.encoded([1,2,3],'old')
        updated=self.encoded([1,2,3],'new')
        with self.assertRaises(AssertionError):
            module.dependency_binding_preimages(prior,original,updated,module.digest(prior))

    def test_even_fresh_binding_cannot_hide_another_geometry_change(self):
        original=self.encoded([1,2,3],'old')
        updated=self.encoded([1,2,3,4],'new')
        with self.assertRaises(AssertionError):
            module.dependency_binding_preimages(None,original,updated,module.digest(original))

class GeneratedCalibrationGuardTest(unittest.TestCase):
    before=b"extends RefCounted\nconst SETS := {\n\t'old': ['a', 'r', 'n', 1., 0],\n}\nconst OPTICS := {\n\t'old': {'normal_scale': .35},\n}\n"
    def candidate(self):
        return self.before.replace(b'const SETS := {\n',b"const SETS := {\n\t'new': ['x', 'y', 'z', .25, 0],\n").replace(b'const OPTICS := {\n',b"const OPTICS := {\n\t'new': {'normal_scale': 1.0},\n")
    def test_new_material_may_declare_its_own_normal_calibration(self):
        self.assertTrue(module.unchanged_generated_materials(self.before,self.candidate(),{'new'}))
    def test_existing_calibration_or_texture_cannot_change(self):
        for old,new in [(b"['a', 'r', 'n'",b"['changed', 'r', 'n'"),(b"'normal_scale': .35",b"'normal_scale': 1.")]:
            self.assertFalse(module.unchanged_generated_materials(self.before,self.candidate().replace(old,new),{'new'}))
    def test_duplicate_or_unrelated_table_is_rejected(self):
        candidate=self.candidate()
        self.assertFalse(module.unchanged_generated_materials(self.before,candidate.replace(b'const OPTICS',b'const OTHER'),{'new'}))
        self.assertFalse(module.unchanged_generated_materials(self.before,candidate.replace(b"\t'new': {'normal_scale': 1.0},",b"\t'new': {'normal_scale': 1.0},\n\t'new': {'normal_scale': 1.0},"),{'new'}))

if __name__=='__main__':unittest.main()
