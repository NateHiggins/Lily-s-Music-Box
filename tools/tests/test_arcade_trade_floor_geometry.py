"""CPU geometry checks for replacement trade floors, not runtime qualification."""
import collections
import copy
import importlib.util
import json
import math
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('trade_floor_geometry',ROOT/'art/blender/scripts/arcade_trade_floor_geometry.py')
geometry=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(geometry)


def sub(a,b):return [a[i]-b[i] for i in range(3)]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def dot(a,b):return sum(a[i]*b[i] for i in range(3))


class TradeFloorGeometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=json.loads((ROOT/'art/data/arcade_plaza/source_plan.json').read_text(encoding='utf-8'))
        cls.layout=json.loads((ROOT/'game/data/building_layout.json').read_text(encoding='utf-8'))
        cls.output=geometry.stocks(cls.plan,cls.layout)

    def reject(self,change,message):
        p=copy.deepcopy(self.plan);layout=copy.deepcopy(self.layout);change(p,layout)
        with self.assertRaisesRegex(ValueError,message):geometry.stocks(p,layout)

    def test_count_source_identity_and_literal_materials(self):
        self.assertEqual(len(self.output),22)
        records={r['id']:r for f in self.layout['floors'] if f['id']=='F01' for r in f['furniture']}
        for row in self.output:
            self.assertEqual(row['source_record'],records[row['source_record_id']])
            self.assertEqual(row['material_family'],row['source_record']['mat'])
            self.assertEqual(row['material'],row['material_family']+'_b')
            if row['role']=='stock_floor':self.assertEqual(row['material_family'],'concrete')
        otis=[r for r in self.output if r['owner']=='shop_otis_son']
        self.assertEqual({r['source_record_id'] for r in otis},{'storm_shop_otis___son_floor','site_rear_otis___son_floor'})

    def test_full_envelope_coverage_and_no_positive_area_overlap(self):
        for shop in self.plan['shops']:
            rows=[r for r in self.output if r['owner']==shop['id']];self.assertEqual(len(rows),2)
            a,b=[r['plan_rect_m'] for r in rows];r=shop['rect_m']
            self.assertEqual([min(a[0],b[0]),min(a[1],b[1]),max(a[2],b[2]),max(a[3],b[3])],r)
            overlap=max(0,min(a[2],b[2])-max(a[0],b[0]))*max(0,min(a[3],b[3])-max(a[1],b[1]))
            self.assertEqual(overlap,0)
            self.assertAlmostEqual(sum(x['area_m2'] for x in rows),(r[2]-r[0])*(r[3]-r[1]),places=11)
            for u,v in [(r[0],r[1]),(r[0],r[3]),(r[2],r[1]),(r[2],r[3])]:
                self.assertTrue(any([u,v,h] in [list(q) for q in row['vertices']] for row in rows for h in [0]))

    def test_partition_centreline_and_correct_stock_side(self):
        for shop in self.plan['shops']:
            row=next(r for r in self.output if r['owner']==shop['id'] and r['role']=='stock_floor')
            p=shop['partition_rect_m'];r=row['plan_rect_m']
            if shop['front']=='east':self.assertEqual(r[2],(p[0]+p[2])*.5)
            elif shop['front']=='west':self.assertEqual(r[0],(p[0]+p[2])*.5)
            else:self.assertEqual(r[1],(p[1]+p[3])*.5)

    def test_closed_volume_outward_winding_and_no_degenerate_faces(self):
        for row in self.output:
            vertices=row['vertices'];centre=[sum(v[k] for v in vertices)/8 for k in range(3)]
            edges=collections.Counter();signed=0
            for face in row['faces']:
                points=[vertices[i] for i in face];n=cross(sub(points[1],points[0]),sub(points[2],points[0]))
                self.assertGreater(dot(n,sub(points[0],centre)),0)
                for i,j in zip(face,face[1:]+face[:1]):edges[(i,j)]+=1
                for k in range(1,len(face)-1):signed+=dot(points[0],cross(points[k],points[k+1]))/6
            self.assertTrue(all(n==1 and edges[(b,a)]==1 for (a,b),n in edges.items()))
            self.assertGreater(signed,0)
            self.assertAlmostEqual(signed,row['closed_volume_m3'],places=10)

    def test_finished_top_and_envelope_unchanged(self):
        for row in self.output:
            self.assertEqual(row['top_m'],0)
            self.assertEqual(row['bottom_m'],-self.plan['finish_layer_m'])
            self.assertEqual({v[2] for v in row['vertices']},{-self.plan['finish_layer_m'],0})
            self.assertFalse(row['disposal_authorized'])
            self.assertEqual(row['replaces_unfinished_deck'],row['owner']+'_deck')
            self.assertIn('NOT_RUNTIME',row['admission'])

    def test_no_mutation_of_plan_doors_or_layout(self):
        p=copy.deepcopy(self.plan);layout=copy.deepcopy(self.layout)
        first=geometry.stocks(p,layout);second=geometry.stocks(p,layout)
        self.assertEqual(first,second);self.assertEqual(p,self.plan);self.assertEqual(layout,self.layout)

    def test_missing_original_source_refused(self):
        def change(p,l):
            f=next(f for f in l['floors'] if f['id']=='F01');f['furniture']=[r for r in f['furniture'] if r['id']!='site_rear_otis___son_floor']
        self.reject(change,'missing or duplicate')

    def test_duplicate_original_source_refused(self):
        def change(p,l):
            f=next(f for f in l['floors'] if f['id']=='F01');f['furniture'].append(copy.deepcopy(next(r for r in f['furniture'] if r['id']=='storm_shop_otis___son_floor')))
        self.reject(change,'missing or duplicate')

    def test_source_batch_mismatch_refused(self):
        def change(p,l):next(r for f in l['floors'] if f['id']=='F01' for r in f['furniture'] if r['id']=='storm_shop_otis___son_floor')['batch']='shop_other'
        self.reject(change,'ownership changed')

    def test_original_stock_material_substitution_refused(self):
        def change(p,l):next(r for f in l['floors'] if f['id']=='F01' for r in f['furniture'] if r['id']=='site_rear_otis___son_floor')['mat']='terrazzo'
        self.reject(change,'retain concrete')

    def test_duplicate_cell_refused(self):
        self.reject(lambda p,l:p['shops'].__setitem__(0,copy.deepcopy(p['shops'][1])),'eleven unique')

    def test_bad_partition_refused(self):
        self.reject(lambda p,l:p['shops'][0].update(partition_rect_m=[-1,.12,3,5.48]),'inside shop')

    def test_wrong_stock_side_refused(self):
        self.reject(lambda p,l:p['shops'][0].update(stock_rect_m=[4,.12,9,5.48]),'stock responsibility')

    def test_nonfinite_bounds_refused(self):
        self.reject(lambda p,l:p['shops'][0].update(rect_m=[0,0,float('inf'),5.6]),'finite rectangle')

    def test_invalid_depth_refused(self):
        for value in [0,-.04,float('nan'),True]:
            self.reject(lambda p,l:p.update(finish_layer_m=value),'positive finite')

    def test_missing_material_refused(self):
        def change(p,l):next(r for f in l['floors'] if f['id']=='F01' for r in f['furniture'] if r['id']=='storm_shop_otis___son_floor')['mat']=''
        self.reject(change,'material missing')

    def test_multiple_F01_refused(self):
        self.reject(lambda p,l:l['floors'].append(copy.deepcopy(next(f for f in l['floors'] if f['id']=='F01'))),'exactly one')


if __name__=='__main__':unittest.main()
