"""Continuous conservative swept-volume fit, before any Godot import.

Each moving manufactured stock is convex. Its hull over the entire original
translation interval is exact (or conservative for simultaneous X/Y play).
Clip fixed native triangles to a 30-micrometre-inset swept hull. This admits
touching guide faces, but refuses penetration between sampled endpoints too.
"""
from pathlib import Path
import bpy,bmesh,json,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_toasters.blend'))
bpy.context.view_layer.update()
objects=list(bpy.data.collections['ClosedConstruction'].objects)
epsilon=.00003

def geometry(obj):
 obj.data.calc_loop_triangles()
 points=np.asarray([obj.matrix_world@v.co for v in obj.data.vertices])
 faces=np.asarray([t.vertices[:] for t in obj.data.loop_triangles])
 return points,faces

def planes(points):
 bm=bmesh.new()
 for p in points:bm.verts.new(p)
 bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
 bm.normal_update();result={}
 for face in bm.faces:
  normal=np.asarray(face.normal);d=normal@np.asarray(face.verts[0].co)
  result[tuple(np.round(np.r_[normal,d],7))]=np.r_[normal,d]
 bm.free();return np.asarray(list(result.values()))

def clip(triangle,hull):
 polygon=list(triangle)
 for plane in hull:
  if not polygon:return []
  new=[];a=polygon[-1];da=plane[:3]@a-plane[3]+epsilon
  for b in polygon:
   db=plane[:3]@b-plane[3]+epsilon
   if (da<0)!=(db<0):new.append(a+(b-a)*da/(da-db))
   if db<=0:new.append(b)
   a,da=b,db
  polygon=new
 return polygon

def crossings(points,faces,hull,low,high):
 tris=points[faces]
 mask=np.all(tris.max(1)>low+epsilon,axis=1)&np.all(tris.min(1)<high-epsilon,axis=1)
 tris=tris[mask]
 if not len(tris):return 0
 distances=tris@hull[:,:3].T-hull[:,3]+epsilon
 tris=tris[~np.any(np.all(distances>0,axis=1),axis=1)]
 count=0
 for tri in tris:
  p=clip(tri,hull)
  if len(p)>=3 and sum(np.linalg.norm(np.cross(p[i]-p[0],p[i+1]-p[0])) for i in range(1,len(p)-1))>1e-10:count+=1
 return count

def inside(tree,point):
 direction=Vector((1.,.317,.613)).normalized();at=Vector(point);hits=0
 for _ in range(100):
  hit,_,_,_=tree.ray_cast(at,direction,2.)
  if hit is None:return hits%2==1
  hits+=1;at=hit+direction*.0000001
 raise AssertionError('ambiguous containment ray')

checks=[];failures=[]
for identity,axis in [('ToasterFront',(0,.160,0)),('ToasterEnd',(-.160,0,0))]:
 family=[o for o in objects if o.name.startswith(identity+'_')]
 fixed=[o for o in family if o.get('component','Body') in ['Body','ResistanceWire']]
 motions={'OrisonRetrofitCrumbTray':[np.zeros(3),np.asarray(axis)],
          'BreadCarrier':[np.array((0,0,z)) for z in [-.087,.024]],
          'CarriageLever':[np.array((x,0,z)) for x in [-.004,.003] for z in [-.046,.010]]}
 envelopes={}
 for component,deltas in motions.items():
  p=np.concatenate([geometry(o)[0] for o in family if o.get('component')==component])
  swept=np.concatenate([p+d for d in deltas]);envelopes[component]=(swept.min(0),swept.max(0))
 for i,left in enumerate(envelopes):
  for right in list(envelopes)[i+1:]:
   lo,hi=envelopes[left];rlo,rhi=envelopes[right]
   separated=bool(np.any(hi<rlo-epsilon) or np.any(rhi<lo-epsilon))
   checks.append([identity,left,right,'independent moving envelopes disjoint',separated])
   if not separated:failures.append(checks[-1])
 for obj in family:
  component=obj.get('component','Body')
  if component not in motions:continue
  points,faces=geometry(obj);deltas=motions[component]
  swept=np.concatenate([points+d for d in deltas]);hull=planes(swept);low=swept.min(0);high=swept.max(0)
  for other in fixed:
   q,indices=geometry(other)
   if np.any(q.max(0)<=low+epsilon) or np.any(q.min(0)>=high-epsilon):continue
   count=crossings(q,indices,hull,low,high)
   # Also reject the exceptional containment case: the whole moving stock
   # inside a closed fixed stock without crossing any of its surface faces.
   tree=BVHTree.FromPolygons([Vector(p) for p in q],indices.tolist())
   contained=False
   for point in [points.mean(0)+d for d in deltas]:
    hit,normal,_,distance=tree.find_nearest(Vector(point))
    if hit is not None and distance>epsilon and normal.dot(Vector(point)-hit)<-epsilon and inside(tree,point):contained=True;break
   checks.append([obj.name,other.name,count,contained])
   if count or contained:failures.append(checks[-1])
out=r/'tmp/v2-finish-review/household-toasters-motion.json'
out.write_text(json.dumps({'evidence_class':'INERT','scope':'Continuous native moving-stock envelopes against fixed case, full 160mm tray, 87mm carrier descent plus conservative 24mm spring overshoot, 46mm lever plus 10mm overshoot and +/-4mm play. Guide boundary tolerance 30 micrometres.','checks':checks,'failures':failures},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('TOASTER MOTION:',len(checks),'continuous candidate pairs clear')
