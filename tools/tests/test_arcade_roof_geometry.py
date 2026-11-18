"""CPU construction controls, deliberately not loaded/structural acceptance."""
import collections
import copy
import importlib.util
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('arcade_roof_geometry',
    ROOT / 'art/blender/scripts/arcade_roof_geometry.py')
geo = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(geo)


def bounds(stock):
    return [[min(v[i] for v in stock['vertices']) for i in range(3)],
            [max(v[i] for v in stock['vertices']) for i in range(3)]]


def covers(stock, u, v):
    # Independent 2D barycentric test of actual exported triangle topology.
    for indices in stock['faces']:
        a,b,c = [stock['vertices'][i] for i in indices]
        denominator=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(denominator)<1e-14:
            continue
        x=((b[1]-c[1])*(u-c[0])+(c[0]-b[0])*(v-c[1]))/denominator
        y=((c[1]-a[1])*(u-c[0])+(a[0]-c[0])*(v-c[1]))/denominator
        if min(x,y,1-x-y)>=-1e-9:
            return True
    return False


def manifold(stock):
    edges=collections.Counter()
    for a,b,c in stock['faces']:
        edges.update([(a,b),(b,c),(c,a)])
    return all(count==1 and edges[(b,a)]==1 for (a,b),count in edges.items())


class ArcadeRoofGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plaza=json.loads((ROOT/'art/data/arcade_plaza/source_plan.json').read_text())
        cls.roof=json.loads((ROOT/'art/data/arcade_plaza/roof_plan.json').read_text())
        cls.output=geo.stocks(cls.plaza,cls.roof)

    def test_source_binding_and_optics_refuse_changes(self):
        for change in ['door','height','glass']:
            p=copy.deepcopy(self.plaza)
            if change=='door':p['shops'][0]['entrance_center_m'][1]+=.01
            elif change=='height':p['wall_height_m']+=.01
            else:p['materials']['glazing']['runtime_optics']['surface_roughness']=.2
            with self.assertRaisesRegex(ValueError,'source changed'):
                geo.stocks(p,self.roof)
        r=copy.deepcopy(self.roof)
        r['materials']['roof_glazing']['runtime_optics']['normal_strength']=.5
        with self.assertRaisesRegex(ValueError,'registered glazing'):
            geo.stocks(self.plaza,r)

    def test_invalid_profiles_and_lost_coverage_refuse(self):
        for field,value in [('crown_m',10.1),('spring_m',6),('arch_segments',1),('bay_max_m',0)]:
            r=copy.deepcopy(self.roof);r['nave'][field]=value
            with self.assertRaises(ValueError):geo.stocks(self.plaza,r)
        r=copy.deepcopy(self.roof);r['nave']['v_span_m'][1]=26
        with self.assertRaisesRegex(ValueError,'coverage'):
            geo.stocks(self.plaza,r)
        r=copy.deepcopy(self.roof);r['support_footprint_max_m']=.3
        with self.assertRaisesRegex(ValueError,'support footprint'):
            geo.stocks(self.plaza,r)

    def test_stock_manifold_volume_finite_and_owner_inventory(self):
        owners={'public'}|{s['id'] for s in self.plaza['shops']}
        self.assertEqual(len({s['name'] for s in self.output}),len(self.output))
        for stock in self.output:
            self.assertIn(stock['owner'],owners)
            self.assertIn(stock['material'],self.roof['materials'])
            self.assertTrue(manifold(stock),stock['name'])
            self.assertGreater(geo.volume(stock['vertices'],stock['faces']),1e-12)
            for a,b,c in stock['faces']:
                n=geo._cross(geo._sub(stock['vertices'][b],stock['vertices'][a]),
                             geo._sub(stock['vertices'][c],stock['vertices'][a]))
                self.assertGreater(geo._dot(n,n),1e-22,stock['name'])
            self.assertTrue(all(math.isfinite(x) for p in stock['vertices'] for x in p))
        bad=copy.deepcopy(self.output[0]);bad['faces'].pop()
        self.assertFalse(manifold(bad),'removed cap must be detected')

    def test_prism_containment_height_and_no_eaves(self):
        rectangles=[self.plaza[k] for k in ['hall_rect_m','court_rect_m','court_join_rect_m']]
        for stock in self.output:
            for u,v,h in stock['vertices']:
                self.assertGreaterEqual(h,-1e-10)
                self.assertLessEqual(h,10)
                self.assertTrue(any(a-1e-9<=u<=c+1e-9 and b-1e-9<=v<=d+1e-9
                                    for a,b,c,d in rectangles),stock['name'])
        highest=max(v[2] for s in self.output for v in s['vertices'])
        self.assertGreater(highest,9.8,'original tall identity retained')

    def test_weather_surface_coverage_and_removed_pane_negative(self):
        roofs=[s for s in self.output if s['role'] in
               ['vault_glazing','neck_weather_glazing','weather_roof']]
        for rect in [self.plaza[k] for k in ['hall_rect_m','court_rect_m','court_join_rect_m']]:
            a,b,c,d=rect
            for i in range(41):
                u=a+(c-a)*(i+.5)/41
                for j in range(31):
                    v=b+(d-b)*(j+.5)/31
                    self.assertTrue(any(covers(s,u,v) for s in roofs),(u,v))
        # Narrow vault bay away from the neck/low-roof overlap: no other pane
        # may hide a removed weather panel at its own interior point.
        pane=next(s for s in roofs if s['name']=='Nave_pane03_05')
        u,v,_=pane['pane_probe']['centre']
        self.assertTrue(covers(pane,u,v))
        self.assertFalse(any(covers(s,u,v) for s in roofs if s is not pane))

    def test_neck_receiving_edges_match_actual_vault_facets(self):
        # Shared endpoints must match the polygonal roof, not an unrelated
        # analytic ellipse which could leave a visible seam between chords.
        roof=[s for s in self.output if s['role']=='vault_glazing']
        neck=[s for s in self.output if s['role']=='neck_weather_glazing']
        for s in neck:
            for u,v,h in s['vertices'][:4]:
                matches=[]
                for receiver in roof:
                    p=receiver['vertices'][:4]
                    for a,b in zip(p,p[1:]+p[:1]):
                        if abs(a[1]-v)>1e-9 or abs(b[1]-v)>1e-9 or abs(b[0]-a[0])<1e-12:
                            continue
                        t=(u-a[0])/(b[0]-a[0])
                        if -1e-9<=t<=1+1e-9:
                            matches.append(a[2]*(1-t)+b[2]*t)
                self.assertTrue(any(abs(z-h)<1e-9 for z in matches),(s['name'],u,v,h))

    def test_shop_ceilings_joists_decks_and_receivers(self):
        for shop in self.plaza['shops']:
            rows=[s for s in self.output if s['owner']==shop['id']]
            for role in ['shop_ceiling','shop_joist','roof_deck','weather_roof','roof_rim']:
                self.assertTrue(any(s['role']==role for s in rows),(shop['id'],role))
            ceiling=next(s for s in rows if s['role']=='shop_ceiling')
            b=bounds(ceiling);a,c,d,e=shop['rect_m']
            self.assertEqual([b[0][0],b[0][1],b[1][0],b[1][1]],[a,c,d,e])
            self.assertAlmostEqual(b[1][2],3.3)
            for joist in [s for s in rows if s['role']=='shop_joist']:
                self.assertAlmostEqual(bounds(joist)[0][2],3.3)

    def test_support_chains_clear_frontage_and_registered_route(self):
        plates=[s for s in self.output if s['role']=='support_baseplate']
        columns=[s for s in self.output if s['role']=='support_column']
        self.assertEqual(len(plates),16)
        self.assertEqual(len(columns),16)
        byname={s['name']:s for s in self.output}
        for plate in plates:
            b=bounds(plate)
            self.assertLessEqual(b[1][0]-b[0][0],.120000001)
            self.assertLessEqual(b[1][1]-b[0][1],.120000001)
            prefix=plate['name'].removesuffix('_plate')
            for suffix in ['_foot','_shaft','_collar','_capital','_knee']:
                self.assertIn(prefix+suffix,byname)
            self.assertEqual(sum(s['name'].startswith(prefix+'_bolt') for s in self.output),4)
            # Real registered arcade route is x14world => planu12.82. These
            # footprints must never obstruct its centreline in either direction.
            self.assertFalse(b[0][0]<=12.82<=b[1][0])
            for shop in self.plaza['shops']:
                a,v,c,w=shop['rect_m'];side=shop['front']
                wall=c if side=='east' else a if side=='west' else v
                cross=0 if side in ['east','west'] else 1
                along=1-cross
                if not b[0][cross]-1e-9<=wall<=b[1][cross]+1e-9:continue
                interval=[b[0][along],b[1][along]]
                centre=shop['entrance_center_m'][along]
                openings=[[centre-1.08,centre+1.08]]
                display=shop['frontage']['display_clear_interval_m']
                openings.append([display[0]-.03,display[1]+.03])
                for lo,hi in openings:
                    self.assertLessEqual(min(interval[1],hi)-max(interval[0],lo),1e-9,
                                         (plate['name'],shop['id']))

    def test_neck_glazing_is_not_buried_under_its_metal_seams(self):
        def first_hit(output, pane, side):
            probe=pane['pane_probe'];normal=probe['normal']
            origin=[a+b*.12*side for a,b in zip(probe['centre'],normal)]
            direction=[-b*.24*side for b in normal]
            hits=[]
            for stock in output:
                for face in stock['faces']:
                    a,b,c=[stock['vertices'][i] for i in face]
                    e1,e2=geo._sub(b,a),geo._sub(c,a)
                    q=geo._cross(direction,e2);det=geo._dot(e1,q)
                    if abs(det)<1e-10:continue
                    t=geo._sub(origin,a);u=geo._dot(t,q)/det
                    if not 0<=u<=1:continue
                    q=geo._cross(t,e1);v=geo._dot(direction,q)/det
                    if v<0 or u+v>1:continue
                    distance=geo._dot(e2,q)/det
                    if 0<=distance<=1:hits.append((distance,stock['material']))
            return min(hits)[1] if hits else None
        neck=[s for s in self.output if s['role']=='neck_weather_glazing']
        self.assertTrue(neck)
        for pane in neck:
            for side in [-1,1]:
                self.assertEqual(first_hit(self.output,pane,side),'roof_glazing',pane['name'])
        # Original receiving failure: over-wide metal covers both small panes.
        broken=copy.deepcopy(self.output)
        for stock in broken:
            if stock['name']=='Neck_seam01':
                centre=sum(v[0] for v in stock['vertices'])/len(stock['vertices'])
                for vertex in stock['vertices']:vertex[0]=centre+(vertex[0]-centre)*5
        self.assertNotEqual(first_hit(broken,next(s for s in neck if s['name']=='Neck_pane01'),-1),'roof_glazing')

    def test_all_glass_has_probe_and_same_registered_recipe(self):
        for s in self.output:
            if s['material']=='roof_glazing':
                self.assertIn('pane_probe',s)
                self.assertEqual(len(s['pane_probe']['centre']),3)
                self.assertAlmostEqual(sum(x*x for x in s['pane_probe']['normal']),1)
        self.assertEqual(self.roof['materials']['roof_glazing'],self.plaza['materials']['glazing'])


if __name__=='__main__':
    unittest.main()
