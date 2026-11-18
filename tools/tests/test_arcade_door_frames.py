"""Source-derived arcade frames: aperture geometry, authority and drift refusals."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import prepare_arcade_door_frames as producer


class ArcadeDoorFrames(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan=json.loads((producer.ROOT/producer.PLAN).read_text(encoding='utf-8'))
        cls.fabrication=json.loads((producer.ROOT/producer.FABRICATION).read_text(encoding='utf-8'))
        cls.document=producer.build()

    def reject(self,change,message):
        plan=copy.deepcopy(self.plan);fabrication=copy.deepcopy(self.fabrication)
        change(plan,fabrication)
        with self.assertRaisesRegex(ValueError,message):producer.derive(plan,fabrication)

    def test_reproducible_lf_fixture(self):
        raw=(producer.ROOT/producer.FIXTURE).read_bytes()
        self.assertNotIn(b'\r',raw)
        self.assertEqual(raw.decode(),producer.render(self.document))
        self.assertEqual(self.document['counts'],dict(front_pairs=11,stock_singles=11,frames=22))

    def test_exact_front_original_records(self):
        floor=next(f for f in self.fabrication['floors'] if f['id']=='F01')
        markers={r['id']:r for r in floor['markers']}
        for row in self.document['frames']:
            if row['frame_kind']=='front_pair':
                self.assertEqual(row['source_marker'],markers[row['id']])
                self.assertEqual(row['source_marker_id'],row['id'])
                self.assertEqual(row['width'],2.)
                self.assertEqual(row['height'],2.3)
        otis=next(r for r in self.document['frames'] if r['cell']=='shop_otis_son' and r['paired'])
        self.assertEqual(otis['id'],'SITE_SHOP_DOOR_OTIS___SON')

    def test_aperture_endpoints_match_declared_openings(self):
        for row in self.document['frames']:
            m=row['frame_transform'];w=row['width'];centre=row['opening_center_m']
            for k,expected in enumerate([1.18+centre[0],0,38.6+centre[1]]):
                self.assertAlmostEqual(m[k][3]+m[k][0]*w*.5,expected,places=12)
            start=[m[k][3] for k in range(3)]
            end=[m[k][3]+m[k][0]*w for k in range(3)]
            self.assertAlmostEqual(sum((end[k]-start[k])**2 for k in range(3)),w*w)
            self.assertEqual(m[3],[0,0,0,1])
            for i in range(3):
                for j in range(3):self.assertEqual(sum(m[k][i]*m[k][j] for k in range(3)),int(i==j))
            a,b,c=m[:3]
            self.assertEqual(a[0]*(b[1]*c[2]-b[2]*c[1])-a[1]*(b[0]*c[2]-b[2]*c[0])+a[2]*(b[0]*c[1]-b[1]*c[0]),1)

    def test_front_hinge_sides_and_outward_normal(self):
        shops={s['id']:s for s in self.plan['shops']}
        for row in self.document['frames']:
            front=shops[row['cell']]['front'];m=row['frame_transform']
            expected={'east':(90,[1,0,0]),'west':(-90,[-1,0,0]),'north':(180,[0,0,-1])}[front]
            self.assertEqual(row['yaw_deg'],expected[0]);self.assertEqual([m[k][2] for k in range(3)],expected[1])
            self.assertEqual(row['opening_angle_deg'],90)

    def test_stock_centres_and_stable_ids(self):
        shops={s['id']:s for s in self.plan['shops']}
        for row in self.document['frames']:
            if row['paired']:continue
            s=shops[row['cell']];p=s['partition_rect_m']
            expected=s.get('stock_opening_center_m',[(p[0]+p[2])*.5,(p[1]+p[3])*.5])
            self.assertEqual(row['opening_center_m'],expected)
            self.assertEqual(row['id'],'ARCADE_STOCK_DOOR_'+row['cell'].removeprefix('shop_').upper())
            self.assertEqual(row['width'],1.)
        diner=next(r for r in self.document['frames'] if r['cell']=='shop_luncheonette' and not r['paired'])
        self.assertEqual(diner['opening_center_m'],[22.75,27.29])

    def test_external_root_not_baked_twice(self):
        self.assertEqual(self.document['root_origin_godot'],[1.18,0,38.6])
        self.assertFalse(self.document['external_vantry_applied'])
        self.assertEqual(self.document['external_vantry_root_z'],-9.795)
        front=next(r for r in self.document['frames'] if r['cell']=='shop_luncheonette' and r['paired'])
        self.assertEqual(front['frame_transform'][2][3],38.6+22.3)

    def test_source_plan_drift_refused(self):
        original=Path.read_bytes
        def changed(path):return original(path)+b' ' if path==producer.ROOT/producer.PLAN else original(path)
        with mock.patch.object(Path,'read_bytes',changed):
            with self.assertRaisesRegex(ValueError,'source plan drift'):producer.build()

    def test_immutable_fabrication_drift_refused(self):
        original=Path.read_bytes
        def changed(path):return original(path)+b' ' if path==producer.ROOT/producer.FABRICATION else original(path)
        with mock.patch.object(Path,'read_bytes',changed):
            with self.assertRaisesRegex(ValueError,'immutable fabrication drift'):producer.build()

    def test_missing_original_id_refused(self):
        def change(p,f):
            floor=next(r for r in f['floors'] if r['id']=='F01')
            floor['markers']=[r for r in floor['markers'] if r['id']!='SITE_SHOP_DOOR_OTIS___SON']
        self.reject(change,'missing original door marker')

    def test_duplicate_original_id_refused(self):
        def change(p,f):
            floor=next(r for r in f['floors'] if r['id']=='F01')
            floor['markers'].append(copy.deepcopy(next(r for r in floor['markers'] if r['id']=='SITE_SHOP_DOOR_OTIS___SON')))
        self.reject(change,'duplicate original door marker')

    def test_duplicate_cell_refused(self):
        self.reject(lambda p,f:p['shops'].__setitem__(0,copy.deepcopy(p['shops'][1])),'eleven exact unique')

    def test_stock_offset_off_partition_refused(self):
        self.reject(lambda p,f:p['shops'][0].update(stock_opening_center_m=[9,2]),'off partition')

    def test_stock_offset_past_wall_refused(self):
        self.reject(lambda p,f:p['shops'][-1].update(stock_opening_center_m=[90,27.29]),'stock aperture exceeds')

    def test_wrong_width_refused(self):
        self.reject(lambda p,f:p.update(front_frame_clear_m=1.95),'clear dimensions changed')

    def test_wrong_origin_refused(self):
        self.reject(lambda p,f:p.update(source_origin_blender_m=[1.18,-28.805,0]),'source origin changed')

    def test_nonfinite_centre_refused(self):
        self.reject(lambda p,f:p['shops'][0].update(entrance_center_m=[9.65,float('nan')]),'finite datum')


if __name__=='__main__':unittest.main()
