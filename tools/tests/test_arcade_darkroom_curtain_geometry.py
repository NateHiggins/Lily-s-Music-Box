"""CPU shape/UV controls for the existing one-metre leaf receiver only."""
import collections
import copy
import importlib.util
import json
import math
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
def module(name,file):
 spec=importlib.util.spec_from_file_location(name,ROOT/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
g=module('darkroom_curtain','art/blender/scripts/arcade_darkroom_curtain_geometry.py')
leaf=module('original_leaf','art/blender/scripts/arcade_door_leaf_geometry.py')
def sub(a,b):return [a[i]-b[i] for i in range(len(a))]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def uv_area(a,b,c):
 u=sub(b,a);v=sub(c,a);return abs(u[0]*v[1]-u[1]*v[0])*.5

class DarkroomCurtain(unittest.TestCase):
 def test_two_source_owned_stocks(self):
  rows=g.stocks();self.assertEqual(len(rows),2)
  for r in rows:
   self.assertEqual(r['owner'],'storm_shop_photo_supplies_dr_door')
   self.assertEqual(r['material_family'],'fabric_warm');self.assertEqual(r['tint'],[.035,.035,.035,1])
   self.assertEqual(r['coordinate_frame'],'LOCAL_GODOT_LEFT_LEAF')
   self.assertFalse(r['fixed']);self.assertFalse(r['source_disposal_authorized']);self.assertFalse(r['optical_light_tightness_qualified'])
 def test_complete_closed_pose_receiver_coverage(self):
  left,right=g.stocks()
  self.assertEqual([left['bounds_low'][0],left['bounds_high'][0],right['bounds_low'][0],right['bounds_high'][0]],[.13,.52,.48,.87])
  self.assertAlmostEqual(left['bounds_high'][0]-right['bounds_low'][0],.04)
  for r in [left,right]:self.assertEqual([r['bounds_low'][1],r['bounds_high'][1]],[.85,2.18])
  # Each segment's front/back projection spans its full width and full receiver height.
  for r in [left,right]:
   for j in range(80):
    face=r['faces'][j*4];p=[r['vertices'][i] for i in face]
    self.assertEqual({v[1] for v in p},{.85,2.18})
    self.assertGreater(max(v[0] for v in p),min(v[0] for v in p))
 def test_layers_are_disjoint_and_inside_old_woodcore(self):
  a,b=g.stocks();self.assertLess(a['bounds_high'][2],b['bounds_low'][2])
  for r in [a,b]:
   self.assertTrue(all(.13<=x<=.87 and .85<=y<=2.18 and -.022<=z<=.022 for x,y,z in r['vertices']))
 def test_original_shape_recipe_and_receiver_adaptation(self):
  for number,r in enumerate(g.stocks()):
   self.assertEqual(len(r['vertices']),324);self.assertEqual(len(r['faces']),322)
   amplitude=[.008,.004][number];mean=[-.010,.010][number];x0,x1=[(.13,.52),(.48,.87)][number]
   for side in range(2):
    for high in range(2):
     for j in range(81):
      x,y,z=r['vertices'][side*162+high*81+j]
      self.assertAlmostEqual(x,x0+(x1-x0)*j/80)
      self.assertAlmostEqual(z,mean+amplitude*math.cos(j/80*math.tau*7)+(-1 if side==0 else 1)*.0012)
   self.assertEqual(r['source_witness']['original_mean_source_blender_x_m'],[22.844,22.872])
   self.assertEqual(r['source_witness']['original_overlap_m'],.09)
 def test_closed_manifold_and_positive_volume(self):
  for r in g.stocks():
   edges=collections.Counter();volume=0;v=r['vertices']
   for f in r['faces']:
    for a,b in zip(f,f[1:]+f[:1]):edges[(a,b)]+=1
    for k in range(1,len(f)-1):volume+=dot(v[f[0]],cross(v[f[k]],v[f[k+1]]))/6
   self.assertTrue(all(n==1 and edges[(b,a)]==1 for (a,b),n in edges.items()))
   self.assertGreater(volume,0);self.assertAlmostEqual(volume,r['closed_volume_m3'],places=12)
 def test_every_triangle_geometry_and_uv_nondegenerate_equal_metric_area(self):
  for r in g.stocks():
   for face,chart,role in zip(r['faces'],r['face_uvs'],r['face_roles']):
    self.assertEqual(len(face),len(chart))
    for k in range(1,len(face)-1):
     a,b,c=[r['vertices'][face[i]] for i in [0,k,k+1]]
     normal=cross(sub(b,a),sub(c,a));area=math.sqrt(dot(normal,normal))*.5
     u=sub(chart[k],chart[0]);w=sub(chart[k+1],chart[0]);self.assertGreater(u[0]*w[1]-u[1]*w[0],0)
     uv=uv_area(chart[0],chart[k],chart[k+1]);self.assertGreater(area,1e-12);self.assertGreater(uv,1e-12)
     self.assertAlmostEqual(area,uv,places=12)
     axis={'front':(2,-1),'back':(2,1),'bottom_hem':(1,-1),'top_hem':(1,1),'left_cap':(0,-1),'right_cap':(0,1)}[role]
     self.assertGreater(normal[axis[0]]*axis[1],0)
 def test_front_back_uv_follows_fold_rest_arclength(self):
  for r in g.stocks():
   arc=r['rest_arclength_m'];self.assertEqual(len(arc),81);self.assertEqual(arc[0],0)
   self.assertGreater(arc[-1],.39)
   for i in range(80):
    self.assertGreater(arc[i+1],arc[i])
    for face_index in [i*4,i*4+1]:
     f=r['faces'][face_index];uv=r['face_uvs'][face_index]
     for vertex,corner in zip(f,uv):self.assertEqual(abs(corner[0]),arc[vertex%81])
 def test_all_values_finite_and_deterministic_without_rest_mutation(self):
  before=copy.deepcopy(leaf.stocks());a=g.stocks();b=g.stocks();self.assertEqual(a,b);self.assertEqual(before,leaf.stocks())
  for r in a:self.assertTrue(all(math.isfinite(x) for p in r['vertices'] for x in p));self.assertTrue(all(math.isfinite(x) for f in r['face_uvs'] for uv in f for x in uv))
  a[0]['source_witness']['tint'][0]=9
  self.assertEqual(g.stocks()[0]['source_witness']['tint'],[.035,.035,.035,1])
 def test_actual_original_recipe_witnesses_still_match(self):
  text=(ROOT/g.SOURCE_WITNESS['geometry_source']).read_text(encoding='utf-8')
  for token in ['steps=80','math.tau*7','22.844,.008','22.872,.004','[-.0012,.0012]','mid+.045','mid-.045']:
   self.assertIn(token,text)
  source=json.loads((ROOT/g.SOURCE_WITNESS['material_source']).read_text(encoding='utf-8'))
  self.assertEqual(source['material_tints']['fabric_warm'],g.SOURCE_WITNESS['tint'])
  runtime=json.loads((ROOT/'game/data/orison_v2/photo_radio_fittings.json').read_text(encoding='utf-8'))
  row=next(p for c in runtime['cells'] for p in c['parts'] if p['name']==g.OWNER+'__fabric_warm')
  self.assertEqual(row['tile'],.7);self.assertEqual(row['tint'],g.SOURCE_WITNESS['tint'])

if __name__=='__main__':unittest.main()
