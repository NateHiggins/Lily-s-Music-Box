"""Independent area and reservation tests for the distant native grade."""
from pathlib import Path
import importlib.util,unittest,sys,math

PATH=Path(__file__).resolve().parents[2]/'art/blender/scripts/city_ground_apron_geometry.py'
sys.path.insert(0,str(PATH.parent))
spec=importlib.util.spec_from_file_location('apron_geometry',PATH)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class Apron(unittest.TestCase):
    def test_union_outlines_keep_overlap_seams_disjoint_components_and_refuse_holes(self):
        from city_street_geometry import rectangle,area
        for stocks,expected,components in [
            ([rectangle([0,0,2,2]),rectangle([1,1,3,3])],7.,1),
            ([rectangle([0,0,1,1]),rectangle([1,0,2,1])],2.,1),
            ([rectangle([0,0,2,2])]*2,4.,1),
            ([rectangle([0,0,1,1]),rectangle([2,0,3,1])],2.,2)]:
            loops=module.convex_union_boundaries(stocks)
            self.assertEqual(len(loops),components)
            self.assertAlmostEqual(sum(area(p) for p in loops),expected)
        # An unsupported inner loop must fail rather than fill a courtyard.
        ring=[rectangle(r) for r in [[0,0,3,1],[0,2,3,3],[0,1,1,2],[2,1,3,2]]]
        with self.assertRaises(AssertionError):module.convex_union_boundaries(ring)

    def test_cavity_chunks_preserve_area_without_spanning_draw_boundaries(self):
        import numpy as np
        chunks=module.chunk_soil_faces([[(0.,-.5,0.),(0.,-.5,9.),(9.,-.5,0.)]])
        total=0.
        for (ix,iz),faces in chunks.items():
            for p in faces:
                self.assertTrue(all(ix*4.-1e-9<=x<=(ix+1)*4.+1e-9 and iz*4.-1e-9<=z<=(iz+1)*4.+1e-9 and y==-.5 for x,y,z in p))
                total+=sum(np.linalg.norm(np.cross(np.subtract(b,p[0]),np.subtract(c,p[0])))*.5 for b,c in zip(p[1:-1],p[2:]))
        self.assertAlmostEqual(total,40.5)

    def test_cut_volume_preserves_existing_voids_and_integrates_grade(self):
        from city_street_geometry import rectangle
        spec=[{'polygons':[rectangle([0,0,2,2])], 'subgrade_profile_m':[[0,-.5],[2,-.5]]}]
        old=[{'bounds':[0,-.4,0,1,0,2]}]
        self.assertAlmostEqual(module.removed_flat_soil_volume(spec,[0,0,2,2],0.,[]),2.)
        self.assertAlmostEqual(module.removed_flat_soil_volume(spec,[0,0,2,2],0.,old+old),1.2)
        spec[0]['subgrade_profile_m']=[[0,-.1],[2,-.5]]
        self.assertAlmostEqual(module.removed_flat_soil_volume(spec,[0,0,2,2],0.,old),.8)

    def test_distant_voids_do_not_change_cut_volume_or_hide_local_overlap(self):
        from city_street_geometry import rectangle
        spec=[{'polygons':[rectangle([0,0,2,2]),rectangle([8,8,9,9])],
               'subgrade_profile_m':[[0,-.5],[10,-.5]]}]
        # All are inside the provider region, but only one meets a cut stock.
        remote=[{'bounds':[3.,-.49+i*.004,3.,7.,-.48+i*.004,7.]} for i in range(100)]
        local={'bounds':[0.,-.4,0.,1.,0.,2.]}
        self.assertAlmostEqual(module.removed_flat_soil_volume(spec,[-1,-1,10,10],0.,remote+[local,local]),1.7)

    def test_open_draw_clipping_removes_only_cut_interior_and_keeps_buried_face(self):
        from city_street_geometry import rectangle
        import numpy as np
        spec=[{'polygons':[rectangle([.5,.5,1.5,1.5])], 'subgrade_profile_m':[[0,-.5],[2,-.5]]}]
        prisms=module.soil_cut_prisms(spec)
        face=[(0.,0.,0.),(0.,0.,2.),(2.,0.,2.),(2.,0.,0.)]
        pieces=module.clip_soil_face(face,prisms)
        area=sum(np.linalg.norm(np.cross(np.subtract(b,p[0]),np.subtract(c,p[0])))*.5 for p in pieces for b,c in zip(p[1:-1],p[2:]))
        self.assertAlmostEqual(area,3.)
        self.assertTrue(all(np.cross(np.subtract(p[1],p[0]),np.subtract(p[2],p[0]))[1]>=0 for p in pieces))
        below=[(x,-1.,z) for x,y,z in face]
        self.assertEqual(module.clip_soil_face(below,prisms),[below])

    def test_cut_union_counts_overlap_once_and_preserves_open_gap(self):
        from city_street_geometry import rectangle,area,intersection
        a,b=rectangle([0,0,2,2]),rectangle([1,1,3,3])
        pieces=module.disjoint_cut_regions([a,b,a,rectangle([4,0,5,1])])
        self.assertAlmostEqual(sum(area(p) for p in pieces),8.)
        for i,p in enumerate(pieces):
            for q in pieces[i+1:]:self.assertLess(abs(area(intersection(p,q))),1e-8)
            self.assertFalse(all(3.1<x<3.9 for x,y in p))

    def test_round_clearance_contains_disk_without_acute_mitre_ears(self):
        p=[(0.,0.),(10.,0.),(.001,.0001)]
        r=.029;result=module.rounded_convex_offset(p,r)
        # Every polygon face must contain the radius-r disk about every source
        # vertex; a narrow triangulation tip must never become a metre-long ear.
        for a,b in zip(result,result[1:]+result[:1]):
            length=math.dist(a,b)
            self.assertGreater(length,0)
            for x,y in p:
                self.assertGreaterEqual(((b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]))/length,r-1e-8)
        self.assertLessEqual(max(x for x,y in result),10+r+0.00004)
        self.assertLessEqual(max(y for x,y in result),.0001+r+0.00004)
        self.assertGreaterEqual(min(x for x,y in result),-r-0.00004)

    def test_street_cuts_cover_both_actual_lods_and_keep_continuation_planes(self):
        import json
        from city_street_geometry import district_topology
        root=PATH.parents[3]
        plan=json.loads((root/'art/data/city_streets/source_plan.json').read_text())
        frame=json.loads((root/'game/data/orison_v2/exterior/street_frame.json').read_text())
        layout=json.loads((root/'game/data/orison_v2_blockout.json').read_text())
        cuts=module.street_cut_footprints(plan,frame,layout)
        self.assertEqual(len(cuts),len(plan['districts']))
        for district,cut in zip(plan['districts'],cuts):
            self.assertAlmostEqual(cut['offset_z_m'],-1.855)
            self.assertLess(cut['padding_max_excess_m'],.00004)
            for n in (12,8):
                topology=district_topology(district,n,plan['curb_width_m'],plan['curb_cap_overhang_m'])
                for original in topology['road']+topology['curb_caps']:
                    # Independent point-in-convex test covers vertices and edge
                    # midpoints; their source stock is convex, not just its AABB.
                    points=original+[((a[0]+b[0])*.5,(a[1]+b[1])*.5) for a,b in zip(original,original[1:]+original[:1])]
                    for x,z in points:
                        q=(-x,z-1.855)
                        self.assertTrue(any(all((b[0]-a[0])*(q[1]-a[1])-(b[1]-a[1])*(q[0]-a[0])>=-1e-7 for a,b in zip(p,p[1:]+p[:1])) for p in cut['polygons']))
            # Actual cap returns extend .175m beyond the nominal road ends;
            # clearance stops at those existing stock planes, with no pad ear.
            self.assertTrue(all(x<=-114.825+1e-8 and z<=111.675+1e-8 for p in cut['polygons'] for x,z in p))
            self.assertEqual(cut['open_stock_planes'],[(0,114.825,True),(1,113.53,False)])
            self.assertEqual(cut['subgrade_profile_m'],[[-210.,-.45],[-135.,-.45],[-115.,-.3975]])

    def test_street_cut_refuses_internal_open_plane_and_nonconvex_offset(self):
        import json,copy
        root=PATH.parents[3]
        plan=json.loads((root/'art/data/city_streets/source_plan.json').read_text())
        bad=copy.deepcopy(plan);bad['districts'][0]['open_edges'][0]['value_m']=140.
        with self.assertRaises(AssertionError):module.street_cut_footprints(bad,json.loads((root/'game/data/orison_v2/exterior/street_frame.json').read_text()),json.loads((root/'game/data/orison_v2_blockout.json').read_text()))
        with self.assertRaises(AssertionError):module.rounded_convex_offset([(0,0),(1,0),(.2,.2),(0,1)],.029)

    def test_exact_ring_area_and_no_old_ground_overlap(self):
        rows=module.apron_boxes([-108,-4,-108,112,-.02,64],[-420,-420,420,420],.28)
        self.assertEqual(len(rows),4)
        area=0
        for row in rows:
            x,y,z,X,Y,Z=row['bounds'];area+=(X-x)*(Z-z)
            self.assertAlmostEqual(Y,-.02)
            self.assertAlmostEqual(Y-y,.28)
            self.assertTrue(X<=-108 or x>=112 or Z<=-108 or z>=64)
        self.assertAlmostEqual(area,840*840-220*172)
        for i,a in enumerate(rows):
            for b in rows[i+1:]:
                av,bv=a['bounds'],b['bounds']
                self.assertTrue(min(av[3],bv[3])<=max(av[0],bv[0]) or min(av[5],bv[5])<=max(av[2],bv[2]))

    def test_invalid_or_intersecting_envelopes_refused(self):
        for outer in [[-100,-420,420,420],[-420,-108,420,420],[-420,-420,112,420],[-420,-420,420,50]]:
            with self.assertRaises(AssertionError):module.apron_boxes([-108,-4,-108,112,-.02,64],outer,.28)
        for depth in [0,-.2,1,5]:
            with self.assertRaises(AssertionError):module.apron_boxes([-108,-4,-108,112,-.02,64],[-420,-420,420,420],depth)

    def test_relief_matches_authored_western_grade_and_retained_eastern_datum(self):
        import json
        root=PATH.parents[3]
        r=json.loads((root/'art/data/city_ground_apron/source_plan.json').read_text())['relief']
        buildings=json.loads((root/'art/data/city_horizon/source_plan.json').read_text())['buildings']
        # Independent AU construction datums, not an inferred 1928 survey.
        profile=[(20.3,-.02),(24.3,-.03),(28.3,-.06),(32.3,-.11),
                 (92,-1.0055),(140,-1.7255),(290,-3.9755),
                 (330,-4.2),(365,-4.6),(390,-4.8),(395,-8),(500,-8)]
        def expected_height(x):
            if x<=profile[0][0]:return -.02
            for (a,h),(b,H) in zip(profile,profile[1:]):
                if x<=b:return h+(H-h)*(x-a)/(b-a)
            return profile[-1][1]
        def check_height(x,z,label):
            actual=module.relief_height(x,z,-.02,r);expected=expected_height(x)
            if expected==-.02:self.assertEqual(actual,expected,label)
            else:self.assertAlmostEqual(actual,expected,places=12,msg=label)
        for b in buildings:
            a,z,A,Z=b['rect']
            for x in [a,(a+A)/2,A]:
                for y in [z,(z+Z)/2,Z]:check_height(x,y,b['id'])
        for x in [-108,0,112]:
            for z in [-108,0,64]:check_height(x,z,'retained ground/apron seam')
        self.assertAlmostEqual(module.relief_height(450,0,-.02,r),-8)
        self.assertAlmostEqual(module.relief_height(-400,0,-.02,r),-3.5)
        self.assertAlmostEqual(module.relief_height(0,-360,-.02,r),-8)
        self.assertEqual(r['street_asl_m']+r['water_scene_y_m'],0)

    def test_coalesced_planes_preserve_exact_occupancy_materials_and_burial(self):
        from itertools import product
        import numpy as np
        def check(solid,retained,asphalt,coords,protected):
            occupied={p for p in product(*(range(n) for n in solid.shape)) if solid[p]}
            native={p for p in product(*(range(n) for n in solid.shape)) if retained[p]}
            expected={};wanted={};buried=base=0
            for p in occupied:
                for axis,direction in product(range(3),(-1,1)):
                    q=list(p);q[axis]+=direction;q=tuple(q)
                    if q in occupied:continue
                    key=(axis,direction,*p);expected[key]=q in native
                    if q in native:buried+=1;continue
                    if axis==1 and direction==-1 and p[1]==0:base+=1;continue
                    chunk=tuple(int(np.floor((coords[i][p[i]]+coords[i][p[i]+1])*.5/4)) for i in (0,2))
                    wanted[key]=(1+int(asphalt[p])+2*int(protected[p[0],p[2]]),chunk)
            streamed={(a,d,x,y,z):flag for a,d,x,y,z,flag in module.exposed_grid_faces(solid,retained)}
            self.assertEqual(streamed,expected)
            source={};rendered={};observed_buried=observed_base=cells=0
            for row in module.coalesced_grid_planes(solid,retained,asphalt,coords,parcel_protection=protected):
                axis,direction=row['axis'],row['direction'];u,v=[i for i in range(3) if i!=axis]
                observed_buried+=row['buried_cells'];observed_base+=row['base_cells'];cells+=row['boundary_cells']
                def expand(rect):
                    for i,j in product(range(rect[0],rect[2]),range(rect[1],rect[3])):
                        at=[0]*3;at[axis]=row['plane']-(direction>0);at[u]=i;at[v]=j
                        yield (axis,direction,*at)
                for rect in row['source']:
                    for key in expand(rect):
                        self.assertNotIn(key,source);source[key]=True
                for label,rect,chunk in row['render']:
                    for key in expand(rect):
                        self.assertNotIn(key,rendered);rendered[key]=(label,chunk)
            self.assertEqual(set(source),set(expected));self.assertEqual(rendered,wanted)
            self.assertEqual((observed_buried,observed_base,cells),(buried,base,len(expected)))
        for bits in range(256):
            solid=np.array([(bits>>i)&1 for i in range(8)],dtype=bool).reshape(2,2,2)
            for mode in range(4):
                retained=(~solid)&np.array([((i+mode)%4)!=0 for i in range(8)]).reshape(2,2,2)
                asphalt=solid&np.array([((i+mode)%3)==0 for i in range(8)]).reshape(2,2,2)
                protected=np.array([mode>=2 and (i+mode)%3==0 for i in range(4)]).reshape(2,2)
                check(solid,retained,asphalt,[[-4.,0.,4.],[-4.,-.7,0.],[-4.,0.,4.]],protected)
        rng=np.random.default_rng(7391)
        for shape in [(1,4,3),(3,1,4),(4,3,1),(5,4,7)]:
            coords=[np.arange(shape[0]+1)-6,np.linspace(-4.,-.02,shape[1]+1),np.arange(shape[2]+1)-3]
            for _ in range(32):
                solid=rng.random(shape)>.4;retained=(~solid)&(rng.random(shape)>.5)
                check(solid,retained,solid&(rng.random(shape)>.5),coords,rng.random((shape[0],shape[2]))>.5)

    def test_relief_and_clipped_water_are_closed_with_real_depth(self):
        import json,collections,numpy as np
        r=json.loads((PATH.parents[3]/'art/data/city_ground_apron/source_plan.json').read_text())['relief']
        for row in module.apron_boxes([-108,-4,-108,112,-.02,64],[-500,-500,500,500],.28):
            v,f,keys=module.relief_stock(row['bounds'],r)
            for points,faces in [(v,f),module.water_stock(v,f,r['water_scene_y_m'])]:
                if not points:continue
                edges=collections.Counter(tuple(sorted((a,b))) for face in faces for a,b in zip(face,face[1:]+face[:1]))
                self.assertTrue(all(n==2 for n in edges.values()),row['id'])
                volume=sum(np.dot(points[face[0]],np.cross(points[face[i]],points[face[i+1]]))/6 for face in faces for i in range(1,len(face)-1))
                self.assertGreater(volume,0,row['id'])
            self.assertEqual(len(keys),len(f))

if __name__=='__main__':unittest.main()
