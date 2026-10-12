"""Pre-existing stale evidence must never become new acceptance by rebinding."""
import copy
import importlib.util
from pathlib import Path
import unittest

path=Path(__file__).resolve().parents[1]/'rebind_additive_material.py'
spec=importlib.util.spec_from_file_location('additive_rebind',path)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

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

if __name__=='__main__':unittest.main()
