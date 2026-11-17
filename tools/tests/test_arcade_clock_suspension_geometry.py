"""Actual-source closed suspension/coped receiver tests, without Blender/Godot."""
import collections,copy,importlib.util,json,math,sys,unittest
from pathlib import Path
from unittest import mock
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
import arcade_clock_suspension_geometry as g

def sub(a,b):return [x-y for x,y in zip(a,b)]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def dot(a,b):return sum(x*y for x,y in zip(a,b))

class ClockSuspension(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.inputs=[json.loads((ROOT/f).read_text(encoding='utf-8')) for f in ['game/data/building_layout.json','game/data/orison_v2/arcade_clock.json','art/data/arcade_plaza/source_plan.json','art/data/arcade_plaza/roof_plan.json']]
  cls.result=g.build(*cls.inputs)
 def reject(self,change,message):
  values=copy.deepcopy(self.inputs);change(*values)
  with self.assertRaisesRegex(ValueError,message):g.build(*values)
 def test_actual_nearest_receivers_and_single_translation(self):
  p=self.result['proof'];self.assertEqual(p['receiver_station'],'Nave_rib07')
  self.assertEqual([r['source_stock']['name'] for r in p['receiver_stocks']],['Nave_rib07_05','Nave_rib07_06'])
  self.assertAlmostEqual(p['delta'][1],-1.24);self.assertAlmostEqual(p['delta'][2],.67333333333333)
  m=p['delta_transform'];self.assertEqual([r[:3] for r in m[:3]],[[1,0,0],[0,1,0],[0,0,1]])
  self.assertEqual(p['delta'][0],0)
  self.assertAlmostEqual(p['cap_centre_target'][2],52.2733333333333)
 def test_source_rows_and_materials_literal(self):
  source={r['id']:r for f in self.inputs[0]['floors'] if f['id']=='F01' for r in f['furniture']}
  self.assertEqual(len(self.result['stocks']),2)
  for r in self.result['stocks']:
   self.assertEqual(r['source_record'],source[r['source_record_id']]);self.assertEqual(r['material'],source[r['source_record_id']]['mat'])
   self.assertEqual(r['sides'],32);self.assertFalse(r['source_disposal_authorized'])
 def test_closed_manifold_positive_volume_and_nonzero_triangles(self):
  for r in self.result['stocks']:
   edges=collections.Counter();volume=0;v=r['vertices'];anchor=v[0]
   for face in r['faces']:
    for a,b in zip(face,face[1:]+face[:1]):edges[(a,b)]+=1
    for k in range(1,len(face)-1):
     a,b,c=[sub(v[face[i]],anchor) for i in [0,k,k+1]]
     n=cross(sub(b,a),sub(c,a));self.assertGreater(dot(n,n),1e-22);volume+=dot(a,cross(b,c))/6
   self.assertTrue(all(n==1 and edges[(b,a)]==1 for (a,b),n in edges.items()));self.assertGreater(volume,0)
   radius=r['source_record']['r'];low=min(r['source_record']['p0'][2],r['source_record']['p1'][2]);high=max(r['source_record']['p0'][2],r['source_record']['p1'][2])
   expected_area=32*.5*radius*radius*math.sin(math.tau/32)
   if r['source_record_id']==g.DROP:self.assertAlmostEqual(volume,expected_area*(high-low),places=12)
   else:self.assertLess(volume,expected_area*(high-low));self.assertGreater(volume,expected_area*(high-low-.0022))
 def test_all32_actual_cap_samples_and_all_cap_triangle_planes(self):
  p=self.result['proof'];v=self.result['stocks'][0]['vertices'];delta=p['delta'];origin=p['origin']
  self.assertEqual(len(p['cap_contacts']),32)
  for contact in p['cap_contacts']:
   target=[v[32+contact['index']][i]+origin[i]+delta[i] for i in range(3)]
   self.assertTrue(all(abs(a-b)<1e-12 for a,b in zip(target,contact['target_point'])))
   receiver=next(r for r in p['receiver_stocks'] if r['source_stock']['name']==contact['receiver_stock'])
   self.assertAlmostEqual(target[1],g._height(receiver,target[0],target[2]),places=12)
  # Every triangular cap interior stays in one actual receiving plane.
  for f in self.result['stocks'][0]['faces']:
   if len(f)!=3:continue
   points=[[v[j][i]+origin[i]+delta[i] for i in range(3)] for j in f]
   at=[sum(q[i] for q in points)/3 for i in range(3)]
   receiver=p['receiver_stocks'][0 if at[0]<=origin[0] else 1]
   self.assertAlmostEqual(at[1],g._height(receiver,at[0],at[2]),places=12)
 def test_cap_margin_and_coping_bound(self):
  p=self.result['proof'];self.assertGreaterEqual(p['receiver_edge_margin_m'],.01-1e-12)
  self.assertAlmostEqual(p['maximum_cope_trim_m'],.00207682681887533)
  self.assertLess(p['maximum_cope_trim_m'],.0022)
  for r in self.result['stocks']:
   radius=r['source_record']['r']
   for x,y,z in r['vertices'][:64]:self.assertAlmostEqual(math.hypot(x,z),radius,places=12)
 def test_axial_endpoint_and_overhead_clearance(self):
  p=self.result['proof'];top=self.result['stocks'][0]['vertices'][64]
  self.assertEqual(top,[0.,10.9-p['origin'][1],0.])
  self.assertAlmostEqual(p['finial_bottom_y'],4.42);self.assertAlmostEqual(p['standing_player_overhead_clearance_m'],2.896)
  self.assertGreater(p['finial_bottom_y'],3.3);self.assertFalse(p['source_disposal_authorized'])
 def test_no_source_mutation(self):
  before=copy.deepcopy(self.inputs);self.assertEqual(g.build(*self.inputs),self.result);self.assertEqual(before,self.inputs)
 def test_missing_pipe_refused(self):
  def change(l,c,p,r):
   f=next(f for f in l['floors'] if f['id']=='F01');f['furniture']=[x for x in f['furniture'] if x['id']!=g.STEM]
  self.reject(change,'missing original')
 def test_duplicate_pipe_refused(self):
  def change(l,c,p,r):
   f=next(f for f in l['floors'] if f['id']=='F01');f['furniture'].append(copy.deepcopy(next(x for x in f['furniture'] if x['id']==g.STEM)))
  self.reject(change,'duplicate original')
 def test_changed_source_radius_refused(self):
  def change(l,c,p,r):next(x for f in l['floors'] if f['id']=='F01' for x in f['furniture'] if x['id']==g.STEM)['r']=.031
  self.reject(change,'profile/material')
 def test_nonfinite_source_refused(self):
  def change(l,c,p,r):next(x for f in l['floors'] if f['id']=='F01' for x in f['furniture'] if x['id']==g.STEM)['p0'][2]=float('nan')
  self.reject(change,'nonfinite')
 def test_changed_clock_origin_refused(self):self.reject(lambda l,c,p,r:c['origin'].__setitem__(1,6.22),'origin changed')
 def test_changed_plaza_refused(self):self.reject(lambda l,c,p,r:p['hall_rect_m'].__setitem__(3,30),'plaza source changed')
 def test_missing_receiver_refused(self):
  actual=g.Roof.stocks(*self.inputs[2:]);bad=[r for r in actual if r['name']!='Nave_rib07_05']
  with mock.patch.object(g.Roof,'stocks',return_value=bad):
   with self.assertRaisesRegex(ValueError,'missing or ambiguous'):g.build(*self.inputs)
 def test_duplicate_receiver_refused(self):
  bad=g.Roof.stocks(*self.inputs[2:]);bad.append(copy.deepcopy(next(r for r in bad if r['name']=='Nave_rib07_05')))
  with mock.patch.object(g.Roof,'stocks',return_value=bad):
   with self.assertRaisesRegex(ValueError,'duplicate roof'):g.build(*self.inputs)
 def test_changed_receiver_plane_refused(self):
  bad=g.Roof.stocks(*self.inputs[2:]);r=next(r for r in bad if r['name']=='Nave_rib07_05');r['vertices'][1][2]-=.01
  with mock.patch.object(g.Roof,'stocks',return_value=bad):
   with self.assertRaisesRegex(ValueError,'planar|crown height'):g.build(*self.inputs)

if __name__=='__main__':unittest.main()
