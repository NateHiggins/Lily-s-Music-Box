"""Independent CPU geometry controls; native derivatives/render remain separate."""
import collections
import importlib.util
import math
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('arcade_door_leaf_geometry',
    ROOT/'art/blender/scripts/arcade_door_leaf_geometry.py')
geo=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(geo)


def bounds(parts):
    vs=[v for p in parts for v in p['vertices']]
    return [[min(v[i] for v in vs) for i in range(3)],
            [max(v[i] for v in vs) for i in range(3)]]


class ArcadeDoorGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.parts=geo.stocks()

    def test_exact_eight_separate_local_groups(self):
        self.assertEqual({p['group'] for p in self.parts},
            {side+part for side in ['Left','Right'] for part in ['Wood','Glass','Brass','FixedBrass']})
        self.assertEqual(len({p['name'] for p in self.parts}),len(self.parts))

    def test_fullsize_core_and_central_pair_clearance(self):
        for side,x in [('Left',[.01,.99]),('Right',[-.99,-.01])]:
            b=bounds([p for p in self.parts if p['side']==side and p['material']=='door_oak'])
            self.assertAlmostEqual(b[0][0],x[0]);self.assertAlmostEqual(b[1][0],x[1])
            self.assertEqual([b[0][1],b[1][1]],[.02,2.29])
            self.assertEqual([b[0][2],b[1][2]],[-.022,.022])
        self.assertAlmostEqual((2-.99)-.99,.02)

    def test_closed_consistently_oriented_stocks_and_positive_volume(self):
        for p in self.parts:
            edges=collections.Counter()
            for face in p['faces']:
                self.assertGreaterEqual(len(face),3)
                for a,b in zip(face,face[1:]+face[:1]):edges[(a,b)]+=1
                self.assertGreater(len(set(face)),2)
            self.assertTrue(all(n==1 and edges[(b,a)]==1 for (a,b),n in edges.items()),p['name'])
            self.assertGreater(geo.signed_volume(p['vertices'],p['faces']),1e-12,p['name'])
            self.assertTrue(all(math.isfinite(v) for p in p['vertices'] for v in p))

    def test_right_is_geometry_mirror_not_scaled_or_translated_node(self):
        rows={p['name']:p for p in self.parts}
        for name,p in rows.items():
            if not name.startswith('Left_'):continue
            q=rows['Right_'+name[5:]]
            self.assertEqual(q['vertices'],[[-x,y,z] for x,y,z in p['vertices']])
            self.assertEqual(q['faces'],[list(reversed(f)) for f in p['faces']])

    def test_upper_glass_has_real_timber_laps_and_opaque_lower_panel(self):
        for side in ['Left','Right']:
            rows=[p for p in self.parts if p['side']==side]
            glass=next(p for p in rows if p['role']=='clear_upper_glazing')
            b=bounds([glass]);self.assertEqual([b[0][1],b[1][1]],[.85,2.18])
            self.assertEqual([b[0][2],b[1][2]],[-.006,.006])
            self.assertEqual(sum(p['role']=='glazing_bead' for p in rows),8)
            panel=next(p for p in rows if p['role']=='opaque_lower_panel')
            b=bounds([panel]);self.assertEqual([b[0][1],b[1][1]],[.14,.74])
            self.assertEqual(panel['material'],'door_oak')

    def test_longitudinal_wood_axes_and_small_soft_bevels(self):
        for p in self.parts:
            if p['role']=='stile':self.assertEqual(p['grain'],'vertical')
            if p['role']=='rail':self.assertEqual(p['grain'],'horizontal')
            self.assertLessEqual(p['bevel_m'],.001)

    def test_tight_both_face_pull_bounds_do_not_include_hinges_or_keyhole(self):
        boxes=geo.pull_collision_boxes(self.parts)
        for side in ['Left','Right']:
            self.assertEqual(len(boxes[side]),2)
            for b in boxes[side]:
                self.assertLess(b['high'][0]-b['low'][0],.08)
                self.assertGreater(min(abs(b['low'][0]),abs(b['high'][0])),.85)
                self.assertGreater(b['low'][1],.89)
                self.assertTrue(all('Pull' in p for p in b['source_stocks']))
                if b['face']>0:self.assertGreater(b['high'][2],.09)
                else:self.assertLess(b['low'][2],-.09)

    def test_three_real_alternating_hinge_knuckle_sets(self):
        for side in ['Left','Right']:
            rows=[p for p in self.parts if p['side']==side]
            moving=[p for p in rows if p['role']=='moving_hinge_barrel']
            fixed=[p for p in rows if p['role']=='fixed_hinge_barrel']
            self.assertEqual(len(moving),6);self.assertEqual(len(fixed),9)
            for p in moving+fixed:
                # Ring-centre is the ABI pivot atz−26mm, not a second transform.
                self.assertAlmostEqual(sum(v[0] for v in p['vertices'])/len(p['vertices']),0)
                self.assertAlmostEqual(sum(v[2] for v in p['vertices'])/len(p['vertices']),-.026)
                radii={round(math.hypot(v[0],v[2]+.026),8) for v in p['vertices']}
                self.assertEqual(radii,{.0045,.01})
            for m in moving:
                a=bounds([m])
                for f in fixed:
                    b=bounds([f]);self.assertLessEqual(min(a[1][1],b[1][1])-max(a[0][1],b[0][1]),0)

    def test_pin_and_flaps_preserve_radial_bore_clearance(self):
        for p in self.parts:
            if p['role']=='fixed_hinge_pin':
                self.assertTrue(all(math.hypot(v[0],v[2]+.026)<.0045 for v in p['vertices']))
            if p['role'] in ['moving_hinge_flap','fixed_hinge_flap']:
                self.assertTrue(all(abs(v[0])>=.008-1e-12 for v in p['vertices']))
            if p['role'].startswith('fixed_hinge'):self.assertTrue(p['fixed'])
            if p['role'].startswith('moving_hinge'):self.assertFalse(p['fixed'])


if __name__=='__main__':unittest.main()
