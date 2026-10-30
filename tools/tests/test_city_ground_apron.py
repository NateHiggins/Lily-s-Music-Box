"""Independent area and reservation tests for the distant native grade."""
from pathlib import Path
import importlib.util,unittest

PATH=Path(__file__).resolve().parents[2]/'art/blender/scripts/city_ground_apron_geometry.py'
spec=importlib.util.spec_from_file_location('apron_geometry',PATH)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class Apron(unittest.TestCase):
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
