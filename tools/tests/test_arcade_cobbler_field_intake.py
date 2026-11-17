"""Source/payload-bound intake controls for the fitted physical support field."""
from pathlib import Path
import copy,importlib.util,json,sys,unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import prepare_arcade_cobbler_field_intake as intake

class FieldIntake(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.proof=json.loads((ROOT/intake.PROOF).read_text(encoding='utf-8'))
 def reject(self,change,message):
  p=copy.deepcopy(self.proof);change(p)
  with self.assertRaisesRegex(ValueError,message):intake.build(ROOT,p)
 def test_runtime_reproducible(self):
  original=copy.deepcopy(self.proof);result=intake.build(ROOT,self.proof)
  self.assertEqual(result,json.loads((ROOT/intake.OUTPUT).read_text(encoding='utf-8')))
  self.assertEqual(self.proof,original)
  self.assertEqual((len(self.proof['stocks']),len(self.proof['support']['felt_contacts']),len(self.proof['support']['floor_contacts'])),(8,25,12))
  self.assertEqual(set(result),{'schema','asset','asset_sha256','cell','source_parts','source_bindings','source_disposal_authorized'})
  self.assertFalse(result['source_disposal_authorized'])
 def test_changed_payload_refused(self):self.reject(lambda p:p.update(asset_sha256='0'*64),'payload changed')
 def test_changed_source_refused(self):
  self.reject(lambda p:p['source_bindings']['game/data/building_layout.json'].update(sha256='0'*64),'source changed')
 def test_source_escape_refused(self):
  self.reject(lambda p:p['source_bindings'].update({'../outside':dict(kind='lf',sha256='0'*64)}),'path unavailable')
 def test_support_record_change_refused(self):
  self.reject(lambda p:p['support']['felt_contacts'][0]['target_point'].__setitem__(1,.018),'contact/support projection')
 def test_mat_removed_refused(self):self.reject(lambda p:p['stocks'].pop(),'closed support stocks')
 def test_mat_expanded_refused(self):self.reject(lambda p:p['stocks'][0]['godot_rect_m'].__setitem__(0,0),'closed support stocks')
 def test_invented_draw_refused(self):self.reject(lambda p:p['draw'].update(name='Wrong'),'registered field draw')
 def test_false_triangle_count_refused(self):self.reject(lambda p:p['draw'].update(triangles=95),'triangle inventory')
 def test_one_donor_missing_refused(self):self.reject(lambda p:p['source_material_parts'].pop(),'both original field')
 def test_changed_donor_material_refused(self):self.reject(lambda p:p['source_material_parts'][0].update(tile=1),'material witnesses')
 def test_hash_path_keys_are_identities_but_values_still_audited(self):
  import audit_data_consumption as audit
  value={'schema':'orison.v2.arcade-cobbler-field.v1','source_bindings':{'res://maps/example.png':{'kind':'raw','sha256':'0'*64,'unread_probe':1}},'metadata':{'unread_probe':2}}
  fields=audit.data_json_fields(value,'orison_v2/arcade_cobbler_field.json')
  self.assertFalse(any('example.png' in f for f in fields))
  self.assertTrue(any(f.endswith('sha256') for f in fields))
  self.assertTrue(any(f.endswith('unread_probe') for f in fields))
  unknown=dict(value,schema='unrecognized.schema')
  self.assertTrue(any('example.png' in f for f in audit.data_json_fields(unknown,'unrelated.json')))

if __name__=='__main__':unittest.main()
