"""Pure source/custody controls for exact all-shop raw projection."""
import copy
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_arcade_raw_projection as gen
import prepare_arcade_native_projection as diner


class ArcadeRawProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = json.loads((gen.ROOT/gen.PLAN).read_text(encoding='utf-8'))
        cls.fixture = gen.build()
    def reject(self, plan, message):
        with self.assertRaisesRegex(ValueError, message):
            gen.build(plan=plan)
    def first_group(self, plan):
        return next(g for g in plan['groups'] if g['raw_stocks'])
    def test_fixture_is_reproducible_complete_and_material_preserving(self):
        self.assertEqual((gen.ROOT/gen.FIXTURE).read_text(encoding='utf-8').replace('\r\n','\n'),gen.render(self.fixture))
        self.assertEqual(self.fixture['counts'],dict(cells=11,raw_stocks=102,triangles=1224))
        ids=[r['id'] for c in self.fixture['cells'] for r in c['raw_stocks']]
        self.assertEqual(len(ids),len(set(ids)))
        expected={r['id'] for r in self.plan['source_dispositions'] if r['action'] in gen.KEEP_ACTIONS}
        self.assertEqual(set(ids),expected)
        for c in self.fixture['cells']:
            self.assertEqual(c['raw_stock_ids'],[r['id'] for r in c['raw_stocks']])
            self.assertTrue(all(r['expected_triangles']==12 for r in c['raw_stocks']))
            self.assertEqual(c['fabrication_source'],'res://data/building_layout.json')
            self.assertTrue(all(k.startswith('res://') for k in c['source_bindings']))
    def test_diner_uses_exact_existing_authoritative_rows(self):
        plan=json.loads((gen.ROOT/self.plan['diner_plan']).read_text(encoding='utf-8'))
        original,bindings=diner.raw_projection(gen.ROOT,plan)
        actual=next(c for c in self.fixture['cells'] if c['cell']=='shop_luncheonette')
        for old,new in zip(original,actual['raw_stocks']):
            self.assertEqual(old,{k:new[k] for k in old})
        for name,b in bindings.items():self.assertEqual(actual['source_bindings'][name],b)
    def test_exact_original_selections_indices_attributes_and_ownership(self):
        for c in self.fixture['cells']:
            native=gen.SourceCell(gen.ROOT,c['cell_source'],c['cell_buffers'])
            source={(f['binding']['node_index'],f['binding']['primitive_index'],f['triangle']):f for f in native.faces}
            used=set()
            for r in c['raw_stocks']:
                actual=[]
                for p in r['source_selections']:
                    self.assertIn('POSITION',p['attributes']);self.assertIn('NORMAL',p['attributes']);self.assertIn('TEXCOORD_0',p['attributes'])
                    selected=[]
                    for ti in p['selected_triangle_indices']:
                        key=(p['node_index'],p['primitive_index'],ti)
                        self.assertNotIn(key,used);used.add(key)
                        face=source[key];actual.append(face);selected+=face['indices']
                        self.assertEqual(p['attributes'],face['binding']['attributes'])
                        self.assertEqual(p['material_name'],face['binding']['material_name'])
                    self.assertEqual(p['selected_indices'],selected)
                gen.validate_box_faces(actual,r)
    def test_unsuffixed_original_screen_and_rail_materials_remain_exact(self):
        rows={r['id']:r for c in self.fixture['cells'] for r in c['raw_stocks']}
        for identity,name in gen.UNSUFFIXED_MATERIALS.items():
            row=rows[identity]
            self.assertEqual({p['material_name'] for p in row['source_selections']},{name})
            self.assertEqual(row['expected_triangles'],12)
            self.assertEqual(row['selection_kind'],'original_box_unsuffixed_material')
    def test_imports_are_bound_without_new_compression_policy(self):
        for c in self.fixture['cells']:
            path=c['cell_source']+'.import'
            self.assertEqual(c['source_bindings'][path],dict(kind='lf',sha256=gen.sha(gen.resource(gen.ROOT,path),True)))
        self.assertTrue(next(c for c in self.fixture['cells'] if c['cell']=='shop_luncheonette')['existing_force_disable_compression'])
    def test_source_bindings_are_reproducible_and_portable(self):
        for name,b in self.fixture['source_bindings'].items():
            self.assertFalse(Path(name).is_absolute());self.assertNotIn('res://',name)
            self.assertEqual(gen.sha(gen.ROOT/name,b['kind']=='lf'),b['sha256'])
        self.assertNotIn('C:/',Path(gen.__file__).read_text(encoding='utf-8'))
    def test_missing_raw_stock_refuses(self):
        p=copy.deepcopy(self.plan);self.first_group(p)['raw_stocks'].pop();self.reject(p,'missing retained raw stocks')
    def test_duplicate_raw_stock_refuses(self):
        p=copy.deepcopy(self.plan);g=self.first_group(p);g['raw_stocks'].append(copy.deepcopy(g['raw_stocks'][0]));self.reject(p,'duplicate retained raw stock')
    def test_literal_record_corruption_refuses(self):
        p=copy.deepcopy(self.plan);self.first_group(p)['raw_stocks'][0]['source_record']['h']+=.01;self.reject(p,'literal original stock record changed')
    def test_source_bounds_corruption_refuses(self):
        p=copy.deepcopy(self.plan);self.first_group(p)['raw_stocks'][0]['source_low'][0]+=.01;self.reject(p,'false raw source bounds')
    def test_target_corruption_refuses(self):
        p=copy.deepcopy(self.plan);self.first_group(p)['raw_stocks'][0]['target_low'][0]+=.01;self.reject(p,'raw target differs')
    def test_delta_scale_and_double_target_refuse(self):
        p=copy.deepcopy(self.plan);self.first_group(p)['delta_transform'][0][0]=2;self.reject(p,'scale/shear')
        p=copy.deepcopy(self.plan);self.first_group(p)['delta_transform'][2][3]+=9.795;self.reject(p,'raw target differs')
    def test_projection_only_target_corruption_refuses(self):
        p=copy.deepcopy(self.plan);p['projection']['raw_entries'][0]['target_low'][0]+=.01;self.reject(p,'canonical raw projection changed')
    def test_record_hash_corruption_refuses(self):
        p=copy.deepcopy(self.plan);p['projection']['raw_entries'][0]['source_record_sha256']='0'*64;self.reject(p,'canonical raw record hash changed')
    def test_missing_original_fabrication_stock_refuses(self):
        real=gen.records_for_floor
        missing=self.first_group(self.plan)['raw_stocks'][0]['id']
        def without(fab):
            records=real(fab);records.pop(missing);return records
        with patch.object(gen,'records_for_floor',without):self.reject(self.plan,'missing or foreign original stock')
    def test_duplicate_literal_original_stock_refuses(self):
        fabricated={'floors':[{'id':'F01','furniture':[{'id':'same'},{'id':'same'}]}]}
        with self.assertRaisesRegex(ValueError,'duplicate fabrication stock'):gen.records_for_floor(fabricated)
    def test_cell_source_change_refuses(self):
        real=gen.sha
        def altered(path,lf=False):return '0'*64 if str(path).endswith('shop_radio_service.gltf') else real(path,lf)
        with patch.object(gen,'sha',altered):self.reject(self.plan,'original cell source changed')
    def test_cell_binary_change_refuses(self):
        real=diner.sha
        def altered(path,lf=False):return '0'*64 if str(path).endswith('shop_radio_service.bin') else real(path,lf)
        with patch.object(diner,'sha',altered):self.reject(self.plan,'cell binary binding changed')
    def test_ambiguous_same_oriented_faces_refuse(self):
        c=next(c for c in self.fixture['cells'] if c['cell']=='shop_keys_cut');native=gen.SourceCell(gen.ROOT,c['cell_source'],c['cell_buffers']);first=c['raw_stocks'][0];alias=copy.deepcopy(first);alias['id']='alias'
        with self.assertRaisesRegex(ValueError,'ambiguous original stock facets'):gen.select_original_faces(native,[first,alias])
    def test_coincident_opposite_faces_remain_separate(self):
        points=[[0.,1.,0.],[0.,1.,1.],[1.,1.,0.]]
        b=dict(material_name='M_timber_b',node_index=0,primitive_index=0)
        cell=SimpleNamespace(faces=[dict(points=points,triangle=0,binding=b),dict(points=list(reversed(points)),triangle=1,binding=b)])
        stocks=[dict(id='lower',source_low=[0,0,0],source_high=[1,1,1],source_record={'mat':'timber'}),dict(id='upper',source_low=[0,1,0],source_high=[1,2,1],source_record={'mat':'timber'})]
        selected=gen.select_original_faces(cell,stocks)
        self.assertEqual([f['triangle'] for f in selected['lower']],[0]);self.assertEqual([f['triangle'] for f in selected['upper']],[1])
    def test_missing_or_repeated_exact_triangle_is_not_a_proxy(self):
        c=next(c for c in self.fixture['cells'] if c['cell']=='shop_keys_cut');native=gen.SourceCell(gen.ROOT,c['cell_source'],c['cell_buffers']);stock=c['raw_stocks'][0];faces=gen.select_original_faces(native,[stock])[stock['id']]
        with self.assertRaisesRegex(ValueError,'unsupported original raw shape.*'+stock['id']):gen.selection_contract(faces[:-1],stock)
        faces[-1]=faces[0]
        with self.assertRaisesRegex(ValueError,'unsupported original raw shape'):gen.selection_contract(faces,stock)
    def test_changed_triangle_contract_is_detected_by_check(self):
        bad=copy.deepcopy(self.fixture);bad['cells'][0]['raw_stocks'][0]['source_selections'][0]['selected_triangle_indices'][0]+=1
        real=Path.read_text;target=gen.ROOT/gen.FIXTURE
        def changed(path,*args,**kwargs):return gen.render(bad) if path==target else real(path,*args,**kwargs)
        with patch.object(Path,'read_text',changed),patch.object(sys,'argv',['raw','--check']):
            with self.assertRaisesRegex(ValueError,'all raw projection fixture stale'):gen.main()


if __name__=='__main__':unittest.main()
