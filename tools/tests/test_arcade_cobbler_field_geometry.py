"""CPU-only source support/closed-stock tests; no Blender or runtime admission."""
import collections
import copy
import importlib.util
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('cobbler_field',ROOT/'art/blender/scripts/arcade_cobbler_field_geometry.py')
g=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(g)
def load(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))
def sub(a,b):return [a[i]-b[i] for i in range(3)]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def area(r):return max(0,r[2]-r[0])*max(0,r[3]-r[1])
def intersection(a,b):return [max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])]

class CobblerField(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.inputs=[load('art/data/arcade_plaza/source_plan.json'),load('game/data/building_layout.json'),load('art/data/arcade_plaza/retained_equipment_placements.json'),load('game/tests/fixtures/orison_cobbler_fittings.json')]
  cls.result=g.build(*cls.inputs)
 def reject(self,change,message):
  values=copy.deepcopy(self.inputs);change(*values)
  with self.assertRaisesRegex(ValueError,message):g.build(*values)
 def test_eight_owners_actual_contact_census(self):
  p=self.result['proof'];self.assertEqual({c['assembly'] for c in p['felt_contacts']},g.OWNERS)
  self.assertEqual((len(p['felt_contacts']),len(p['floor_contacts'])),(25,12));self.assertEqual(len(self.result['stocks']),8)
  for row in p['felt_contacts']+p['floor_contacts']:
   self.assertEqual(row['source_record'],self.inputs[3]['contacts'][row['source_index']])
   self.assertAlmostEqual(row['target_point'][1],.008 if row['source_record']['owner']==g.FELT else 0,places=12)
 def test_full_contact_edge_coverage(self):
  p=self.result['proof'];rects=[r['godot_rect_m'] for r in self.result['stocks']]
  for island in p['assembly_islands']:
   for r in island['required_support_rectangles']:
    self.assertAlmostEqual(sum(area(intersection(r,q)) for q in rects),area(r),places=11)
  for row in p['felt_contacts']:
   x,y,z=row['target_point'];required=[x-.06,z-.06,x+.06,z+.06]
   self.assertAlmostEqual(sum(area(intersection(required,q)) for q in rects),.12*.12,places=11)
 def test_floor_contacts_excluded_with_full_protected_area(self):
  for r in self.result['stocks']:
   for cut in self.result['proof']['protected_floor_rectangles']:self.assertFalse(g._overlap(r['godot_rect_m'],cut))
 def test_room_wall_exclusion(self):
  for row in self.result['stocks']:
   r=row['godot_rect_m'];self.assertTrue(any(q[0]<=r[0] and q[1]<=r[1] and q[2]>=r[2] and q[3]>=r[3] for q in self.result['proof']['rooms_godot']))
 def test_disjoint_union(self):
  rows=self.result['stocks']
  for i,row in enumerate(rows):
   for other in rows[i+1:]:self.assertFalse(g._overlap(row['godot_rect_m'],other['godot_rect_m']))
  self.assertAlmostEqual(sum(area(r['godot_rect_m']) for r in rows),sum(area(i['rect']) for i in self.result['proof']['assembly_islands']),places=11)
 def test_closed_manifold_outward_volume(self):
  for row in self.result['stocks']:
   v=row['vertices'];centre=[sum(p[k] for p in v)/len(v) for k in range(3)];edges=collections.Counter();volume=0
   for face in row['faces']:
    p=[v[i] for i in face];self.assertGreater(dot(cross(sub(p[1],p[0]),sub(p[2],p[0])),sub(p[0],centre)),0)
    for a,b in zip(face,face[1:]+face[:1]):edges[(a,b)]+=1
    for k in range(1,len(p)-1):volume+=dot(p[0],cross(p[k],p[k+1]))/6
   self.assertTrue(all(n==1 and edges[(b,a)]==1 for (a,b),n in edges.items()))
   self.assertAlmostEqual(volume,row['closed_volume_m3'],places=11)
   self.assertEqual({p[2] for p in v},{0.,.008});self.assertGreater(volume,0)
 def test_plan_source_coordinates_and_no_disposal(self):
  origin=self.inputs[0]['source_origin_blender_m']
  for row in self.result['stocks']:
   a,b,c,d=row['plan_rect_m'];self.assertEqual(row['godot_rect_m'],[a+origin[0],b-origin[1],c+origin[0],d-origin[1]])
   self.assertFalse(row['disposal_authorized'])
  self.assertFalse(self.result['proof']['disposal_authorized'])
 def test_single_centre_retains_entire_actual_source_base(self):
  island=next(r for r in self.result['proof']['assembly_islands'] if r['assembly'].endswith('_sole_stack'))
  self.assertEqual(island['source_base_record']['id'],island['assembly']);self.assertGreater(area(island['rect']),.12*.12)
 def test_inputs_immutable_and_deterministic(self):
  original=copy.deepcopy(self.inputs);self.assertEqual(g.build(*self.inputs),self.result);self.assertEqual(self.inputs,original)
 def test_missing_contact_owner_refused(self):
  self.reject(lambda p,l,e,c:c.update(contacts=[x for x in c['contacts'] if not x['assembly'].endswith('_sole_stack')]),'eight exact')
 def test_duplicate_contact_refused(self):
  self.reject(lambda p,l,e,c:c['contacts'].append(copy.deepcopy(c['contacts'][0])),'duplicate original contact')
 def test_nonfinite_contact_refused(self):
  self.reject(lambda p,l,e,c:c['contacts'][0]['point'].__setitem__(0,float('nan')),'nonfinite')
 def test_wrong_foot_height_refused(self):
  self.reject(lambda p,l,e,c:c['contacts'][0]['point'].__setitem__(1,.02),'foot height changed')
 def test_missing_source_record_refused(self):
  def change(p,l,e,c):
   f=next(f for f in l['floors'] if f['id']=='F01');f['furniture']=[r for r in f['furniture'] if r['id']!=g.FELT]
  self.reject(change,'missing or duplicate source record')
 def test_duplicate_source_record_refused(self):
  def change(p,l,e,c):
   f=next(f for f in l['floors'] if f['id']=='F01');f['furniture'].append(copy.deepcopy(next(r for r in f['furniture'] if r['id']==g.FELT)))
  self.reject(change,'missing or duplicate source record')
 def test_native_source_binding_required(self):
  self.reject(lambda p,l,e,c:c.update(source_bindings={}),'missing native source')
 def test_duplicate_retained_group_refused(self):
  def change(p,l,e,c):e['groups'].append(copy.deepcopy(next(r for r in e['groups'] if r['cell']==g.CELL and r['native_assemblies'])))
  self.reject(change,'duplicate retained')
 def test_scale_change_refused(self):
  def change(p,l,e,c):next(r for r in e['groups'] if r['cell']==g.CELL and r['native_assemblies'])['delta_transform'][0][0]=2
  self.reject(change,'nonrigid')
 def test_protected_floor_foot_conflict_refused(self):
  def change(p,l,e,c):
   target=next(r for r in c['contacts'] if r['owner']==g.FELT and r['assembly'].endswith('_rack0'))
   floor=next(r for r in c['contacts'] if r['owner']==g.FLOOR and r['assembly']==target['assembly'])
   floor['point']=[target['point'][0],.01,target['point'][2]]
  self.reject(change,'protected floor foot conflicts')
 def test_rectangular_subtraction_and_union_do_not_fill_holes(self):
  pieces=g._subtract([0,0,4,4],[1,1,3,3]);union=g._union(pieces)
  self.assertEqual(sum(area(r) for r in union),12)
  self.assertTrue(all(not g._overlap(r,[1,1,3,3]) for r in union))
  self.assertEqual(sum(area(r) for r in g._union([[0,0,2,2],[1,1,3,3]])),7)

if __name__=='__main__':unittest.main()
