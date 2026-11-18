from pathlib import Path
import copy,json,sys,unittest
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
import prepare_arcade_darkroom_curtain_intake as intake

class CurtainIntake(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.proof=json.loads((ROOT/intake.PROOF).read_text(encoding='utf-8'))
 def reject(self,change,message):
  p=copy.deepcopy(self.proof);change(p)
  with self.assertRaisesRegex(ValueError,message):intake.build(ROOT,p)
 def test_reproducible_minimal_runtime(self):
  original=copy.deepcopy(self.proof)
  result=intake.build(ROOT,self.proof);self.assertEqual(result,json.loads((ROOT/intake.OUTPUT).read_text(encoding='utf-8')))
  self.assertEqual(set(result),{'schema','asset','asset_sha256','source_sha256_lf','import_sha256_lf'});self.assertEqual(original,self.proof)
 def test_payload_changed(self):self.reject(lambda p:p.update(asset_sha256='0'*64),'payload changed')
 def test_editable_native_changed(self):self.reject(lambda p:p.update(native_sha256='0'*64),'editable curtain native')
 def test_material_lineage_changed(self):self.reject(lambda p:p['original_parts'][0].update(tile=1),'material lineage')
 def test_draw_changed(self):self.reject(lambda p:p['parts'][0].update(triangles=1287),'registered curtain draw')
 def test_missing_stock(self):self.reject(lambda p:p['stocks'].pop(),'two closed cloth stocks')
 def test_envelope_changed(self):self.reject(lambda p:p['stocks'][0]['low'].__setitem__(2,-.03),'existing leaf envelope')
 def test_nonfinite_witness(self):self.reject(lambda p:p['stocks'][0].update(closed_volume_m3=float('inf')),'finite curtain stock')
 def test_broken_source_binding(self):self.reject(lambda p:p['source_bindings']['art/blender/scripts/arcade_darkroom_curtain_geometry.py'].update(sha256='0'*64),'source changed')

if __name__=='__main__':unittest.main()
