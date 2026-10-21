"""Unexported changes to installed native flue construction expire evidence."""
import hashlib,sys,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
import v2_surface_evidence as evidence

class NativeEvidence(unittest.TestCase):
    def test_native_only_changes_invalidate_the_surface_digest(self):
        # Substitute changed native bytes at the actual file-hash boundary;
        # never edit production files or the installed exports for this test.
        families=['c_stove_stack/c_stove_stack.blend','flue_breast_fitting/flue_breast_fitting.blend','flue_wall_thimble/flue_wall_thimble.blend']
        seen={};original=evidence.file_hash
        def record(path):
            result=original(path);seen[path.resolve()]=result;return result
        with patch.object(evidence,'file_hash',side_effect=record):base=evidence.inputs(ROOT)['sha256']
        for family in families:
            native=(ROOT/'art/blender'/family).resolve()
            self.assertIn(native,seen)
            changed=hashlib.sha256(b'changed native construction before export').hexdigest()
            with patch.object(evidence,'file_hash',side_effect=lambda path:changed if path.resolve()==native else seen[path.resolve()]):
                self.assertNotEqual(base,evidence.inputs(ROOT)['sha256'],family)

if __name__=='__main__':unittest.main()
