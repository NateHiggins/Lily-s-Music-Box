"""Full-shop source coverage and strict native/raw/disposition refusal controls."""
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import prepare_arcade_retained_equipment as gen

class ArcadeRetainedEquipmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original=json.loads((gen.ROOT/gen.PLAN).read_text(encoding='utf-8'))
        cls.ctx=gen.context(gen.ROOT,cls.original)
        cls.expected=gen.project(cls.original,cls.ctx)
    def setUp(self):
        self.doc=copy.deepcopy(self.original)
    def reject(self, message):
        with self.assertRaisesRegex(ValueError,message):gen.project(self.doc,self.ctx)
    def first_part(self):
        return next(p for g in self.doc['groups'] for a in g['native_assemblies'] for p in a['parts'])
    def test_current_projection_is_reproducible_and_complete(self):
        self.assertEqual(self.original['projection'],self.expected)
        self.assertEqual((gen.ROOT/gen.PLAN).read_text(encoding='utf-8').replace('\r\n','\n'),gen.render(self.original))
        self.assertEqual(self.expected['counts'],dict(cells=11,groups=109,native_assemblies=427,placed_native_parts=1168,native_rebuild_parts=81,retained_raw_stocks=102,source_dispositions=1555,affected_shared_sources=8,native_families=46,labels=4,selected_lane_reservations=69))
    def test_all_owned_source_records_and_shared_custody_are_present(self):
        expected={key for key,row in self.ctx['ownership'].items() if row['owner_cell'] in {'CELL_'+c.upper() for c in self.ctx['cells']}}
        actual={(r['collection'],r['id']) for r in self.original['source_dispositions']}
        self.assertEqual(len(expected),1547)
        self.assertEqual(len(actual),1555)
        self.assertTrue(expected<=actual)
        self.assertEqual(actual-expected,{('furniture',identity)for identity in gen.SHARED_IDS})
        self.assertTrue(all(r['action'].startswith('REBUILD_') for r in self.original['source_dispositions'] if r['affected_shared_source']))
    def test_current_diner_is_the_only_diner_placement_authority(self):
        self.assertFalse(any(g['cell']=='shop_luncheonette'for g in self.original['groups']))
        actual={p['part']:p for p in self.expected['native_entries']if p['cell']=='shop_luncheonette'}
        declared={p['part_id']:p['target_transform']for g in self.ctx['diner']['groups']for a in g['assemblies']for p in a['parts']}
        self.assertEqual(set(actual),set(declared))
        self.assertEqual(len(actual),41)
        self.assertTrue(all(actual[k]['target_transform']==v for k,v in declared.items()))
        self.assertEqual({r['id']for r in self.expected['raw_entries']if r['cell']=='shop_luncheonette'},set(self.ctx['diner']['raw_stock_ids']))
    def test_no_private_runtime_dependencies_or_hidden_payload_renewal(self):
        text=gen.render(self.original)
        self.assertNotIn('C:/',text)
        self.assertNotIn('C:\\',text)
        self.assertNotIn('C:/ov',Path(gen.__file__).read_text(encoding='utf-8'))
        controls=self.original['source_change_controls']
        self.assertEqual([r['family']for r in controls],['shop_seating'])
        self.assertEqual(len(controls[0]['unchanged_other_part_ids']),24)
    def test_missing_source_disposition_refuses(self):
        self.doc['source_dispositions'].pop()
        self.reject('missing owned source dispositions')
    def test_duplicate_source_disposition_refuses(self):
        self.doc['source_dispositions'].append(copy.deepcopy(self.doc['source_dispositions'][0]))
        self.reject('duplicate source disposition')
    def test_literal_source_record_change_refuses(self):
        self.doc['source_dispositions'][0]['source_record']['h']+=.01
        self.reject('literal source disposition changed')
    def test_source_owner_change_refuses(self):
        self.doc['source_dispositions'][0]['owner_cell']='CELL_PASSAGE'
        self.reject('source owner changed')
    def test_shared_frontage_cannot_be_declared_retired(self):
        row=next(r for r in self.doc['source_dispositions']if r['affected_shared_source'])
        row['action']='RETIRED_EXACT_ACTIVE_NATIVE_MASK'
        self.reject('shared source cannot be retired')
    def test_missing_native_part_refuses(self):
        next(a for g in self.doc['groups']for a in g['native_assemblies']if len(a['parts'])>1)['parts'].pop()
        self.reject('native parts missing disposition')
    def test_duplicate_native_part_refuses(self):
        a=next(a for g in self.doc['groups']for a in g['native_assemblies'])
        a['parts'].append(copy.deepcopy(a['parts'][0]))
        self.reject('duplicate placed native part')
    def test_wrong_native_frame_refuses(self):
        self.first_part()['source_transform'][0][3]+=.01
        self.reject('native source frame changed')
    def test_wrong_encoded_native_payload_refuses(self):
        self.first_part()['encoded_source'][0]['attributes']['POSITION']['sha256']='0'*64
        self.reject('encoded native attributes changed')
    def test_double_native_transform_refuses(self):
        group=next(g for g in self.doc['groups']if g['native_assemblies'])
        part=group['native_assemblies'][0]['parts'][0]
        part['target_transform']=gen.mul(group['delta_transform'],part['target_transform'])
        self.reject('native target differs')
    def test_missing_native_rebuild_part_refuses(self):
        self.doc['native_rebuild_parts'].pop()
        self.reject('native parts missing disposition')
    def test_nonfinite_delta_or_raw_target_refuses(self):
        self.doc['groups'][0]['delta_transform'][0][3]=float('nan')
        self.reject('nonfinite matrix')
        self.doc=copy.deepcopy(self.original)
        stock=next(r for g in self.doc['groups']for r in g['raw_stocks'])
        stock['target_high'][2]=float('nan')
        self.reject('nonfinite raw target bounds')
    def test_wrong_raw_record_refuses(self):
        stock=next(r for g in self.doc['groups']for r in g['raw_stocks'])
        stock['source_record']['h']+=.01
        self.reject('raw stock record changed')
    def test_missing_retained_raw_stock_refuses(self):
        group=next(g for g in self.doc['groups'] if len(g['raw_stocks'])>1)
        group['raw_stocks'].pop()
        self.reject('retained raw stock inventory incomplete')
    def test_duplicate_retained_raw_stock_refuses(self):
        group=next(g for g in self.doc['groups'] if g['raw_stocks'])
        group['raw_stocks'].append(copy.deepcopy(group['raw_stocks'][0]))
        self.reject('duplicate retained raw stock')
    def test_exact_native_source_mask_cannot_change(self):
        row=next(r for r in self.doc['source_dispositions'] if r['native_masks'])
        row['native_masks'][0]['record']['expected_triangles']+=1
        self.reject('exact native replacement boundary changed')
    def test_false_resolved_non_diner_label_refuses(self):
        row=next(r for r in self.doc['label_dispositions']if r['action']=='UNRESOLVED_LABEL_OWNER_PROJECTION')
        row['action']='CANONICAL_DINER_PROJECTION'
        self.reject('false resolved label disposition')
    def test_missing_label_disposition_refuses(self):
        self.doc['label_dispositions'].pop()
        self.reject('labels missing disposition')
    def test_changed_source_binding_refuses(self):
        first=next(iter(self.doc['source_bindings']))
        self.doc['source_bindings'][first]['sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'source binding changed'):gen.context(gen.ROOT,self.doc)
    def test_changed_native_hash_refuses(self):
        self.doc['families'][0]['asset_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'native payload changed'):gen.context(gen.ROOT,self.doc)

if __name__=='__main__':unittest.main()
