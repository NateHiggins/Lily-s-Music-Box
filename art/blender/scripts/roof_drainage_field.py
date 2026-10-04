"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import json,math
import numpy as np
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file())
field_path=R/'art/blender/roof_drainage_falls_construction.json'
field=json.loads(field_path.read_bytes())
points=np.array(field['points'],dtype=np.float64)
indices=np.array(field['triangles_by_vertex'],dtype=np.int32)
triangles=points[indices][:,:,[0,2]]
planes=np.array([np.linalg.solve(np.c_[points[t][:,[0,2]],np.ones(3)],points[t][:,1]) for t in indices])
buckets={};edges={};boundary_probes=[]
for index,triangle in enumerate(triangles):
 lo=triangle.min(axis=0)-.00002;hi=triangle.max(axis=0)+.00002
 for x in range(math.floor(lo[0]/.5),math.floor(hi[0]/.5)+1):
  for z in range(math.floor(lo[1]/.5),math.floor(hi[1]/.5)+1):buckets.setdefault((x,z),[]).append(index)
 for a,b in zip(triangle,np.roll(triangle,-1,axis=0)):edges[tuple(sorted((tuple(a),tuple(b))))]=(a,b)
def height(x,z):
 at=np.array([x,z])
 candidates=buckets.get((math.floor(x/.5),math.floor(z/.5)),[])
 for index in candidates:
  t=triangles[index];a=t[1]-t[0];b=t[2]-t[0];q=at-t[0];det=a[0]*b[1]-a[1]*b[0]
  u=(q[0]*b[1]-q[1]*b[0])/det;v=(a[0]*q[1]-a[1]*q[0])/det
  if u>=-1e-8 and v>=-1e-8 and u+v<=1.00000001:return float(planes[index]@np.array([x,z,1.]))
 # Blender's stored native coordinates can fall a fraction of a micrometre
 # across an authored exclusion boundary. Find an actual adjacent field edge
 # within 2 micrometres; evaluate that plane without moving the joint vertex.
 # The reopened inspector still compares actual retained faces at 5 microns.
 for index in candidates:
  for a,b in zip(triangles[index],np.roll(triangles[index],-1,axis=0)):
   delta=b-a;t=np.clip(np.dot(at-a,delta)/np.dot(delta,delta),0.,1.);probe=a+t*delta
   if np.linalg.norm(at-probe)<=.000002:
    boundary_probes.append({'point':[x,z],'adjacent_field_point':probe.tolist(),'offset_m':float(np.linalg.norm(at-probe))})
    return float(planes[index]@np.array([x,z,1.]))
 raise AssertionError(('No source field at fitted weather foot',x,z))
def patch_max(rect):
 a,b,c,d=rect
 values=[height(x,z) for x,z in [(a,b),(a,d),(c,b),(c,d)]]
 values += [float(p[1]) for p in points if a-1e-8<=p[0]<=c+1e-8 and b-1e-8<=p[2]<=d+1e-8]
 # Maxima on clipped field edges can also occur at footprint intersections.
 for start,end in edges.values():
  for axis,limits in [(0,[a,c]),(1,[b,d])]:
   delta=end[axis]-start[axis]
   if abs(delta)<1e-12:continue
   for bound in limits:
    t=(bound-start[axis])/delta
    if 0<=t<=1:
     p=start+t*(end-start)
     if a-1e-8<=p[0]<=c+1e-8 and b-1e-8<=p[1]<=d+1e-8:values.append(height(*p))
 return max(values)
