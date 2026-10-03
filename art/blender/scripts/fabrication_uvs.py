"""Metre charts with common surface axes and checked float32 UV export."""
import numpy as np

def _representable(points,normal,u,values):
 values=values.astype(np.float32);exported=values.copy();exported[:,1]=np.float32(1)-exported[:,1]
 first=exported[1]-exported[0];second=exported[2]-exported[0]
 determinant=float(first[0])*float(second[1])-float(second[0])*float(first[1])
 if abs(determinant)<=1e-12:return False
 a=(points[1]-points[0]).astype(np.float32);b=(points[2]-points[0]).astype(np.float32)
 expected=(a*second[1]-b*first[1])/determinant;expected=expected.astype(np.float64)
 projected=expected-normal*np.dot(expected,normal);length=np.linalg.norm(projected)
 if not length:return False
 return np.dot(projected/length,u)>.9995

def chart_for_triangle(points,origin,tile,long_grain=False):
 points=np.asarray(points,dtype=np.float64);origin=np.asarray(origin,dtype=np.float64)
 n=np.cross(points[1]-points[0],points[2]-points[0]);length=np.linalg.norm(n)
 assert length>0 and np.isfinite(points).all()
 n/=length
 seed=np.array((0.,0.,1.)) if abs(n[2])<.9 else np.array((0.,1.,0.))
 axial=seed-n*np.dot(seed,n);axial/=np.linalg.norm(axial)
 if long_grain:u=axial;v=np.cross(n,u)
 else:v=axial;u=np.cross(v,n)
 values=np.column_stack(((points+origin)@u,(points+origin)@v))
 # Whole catalogue tiles preserve texture phase while keeping magnitudes
 # small. Adjacent triangles on a planar stock retain the same surface axes.
 values-=np.floor(values.min(axis=0)/tile)*tile
 if _representable(points,n,u,values):return n,u,values,False
 # Microscopic Boolean joints need a local chart. All faces still receive
 # a finite isometric chart and the same strict derivative check.
 pairs=sorted([(i,(i+1)%3) for i in range(3)],key=lambda pair:np.linalg.norm(points[pair[1]]-points[pair[0]]),reverse=True)
 for a,b in pairs:
  u=points[b]-points[a];u/=np.linalg.norm(u);v=np.cross(n,u)
  values=np.column_stack(((points-points[a])@u,(points-points[a])@v))
  if _representable(points,n,u,values):return n,u,values,True
 raise AssertionError(('no representable metre chart',points.tolist()))
