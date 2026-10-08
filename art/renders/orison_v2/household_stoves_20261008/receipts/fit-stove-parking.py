from pathlib import Path
import bpy,json,math,numpy as np
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
r=Path('C:/PleaseRemainOnTheLine');bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_stoves.blend'));bpy.context.view_layer.update()
native={}
for o in bpy.data.collections['ClosedConstruction'].objects:
 p=np.asarray([o.matrix_world@v.co for v in o.data.vertices]);faces=[list(t.vertices) for t in o.data.polygons]
 native[o.name]={'points':p,'faces':faces,'low':p.min(0),'high':p.max(0),'tree':BVHTree.FromPolygons(p,faces),'part':o.get('component','Body')}
endpoints=[]
for i,(x,y) in enumerate([(-.17,.13),(.17,.13),(-.17,-.14),(.17,-.14)]):
 part='Grate'+str(i+1);selected={n:d for n,d in native.items() if d['part']==part};fixed={n:d for n,d in native.items() if d['part'] not in [part,'BurnerCap'+str(i+1)]};angle=math.radians(-60)
 rotation=np.asarray(Matrix.Rotation(angle,3,'X'));p0=np.array((x,y,.9));rotated={n:(d['points']-p0)@rotation.T for n,d in selected.items()};points=np.concatenate(list(rotated.values()))
 yy=-.268-points[:,1].min()+.000002;zlow=.877-points[:,2].min();zhigh=1.113-points[:,2].max()-.000002;xx=-.2 if i%2==0 else .2
 def intersects(z):
  for name,q in rotated.items():
   p=q+np.array((xx,yy,z));lo=p.min(0);hi=p.max(0);tree=BVHTree.FromPolygons(p,selected[name]['faces'])
   for other,d in fixed.items():
    if np.any(hi<=d['low']+.000001) or np.any(d['high']<=lo+.000001):continue
    if tree.overlap(d['tree']):return True
  return False
 # Find the lowest valid interval; refine its support contact from below.
 grid=np.linspace(zlow,zhigh,151);valid=[float(z) for z in grid if not intersects(z)]
 assert valid,(i,zlow,zhigh)
 z=valid[0]
 if z>zlow+1e-7:
  a=z-(zhigh-zlow)/150;b=z
  for _ in range(24):
   mid=(a+b)/2
   if intersects(mid):a=mid
   else:b=mid
  z=b+.000002
 else:z+=.000002
 assert not intersects(z)
 endpoints.append({'index':i,'blender_center':[xx,float(yy),float(z)],'angle_degrees':-60,'floor_gap_m':float(z+points[:,2].min()-.877),'rear_gap_m':.000002})
p=r/'art/data/household_stoves/source_plan.json';d=json.loads(p.read_text(encoding='utf-8'));d['native_service']={'grate_parking':endpoints,'grate_lift_m':.085,'cap_lift_m':.028,'cap_end_blender_delta':[[.12 if i%2==0 else -.12,.10,0.] for i in range(4)],'scope':'Native presentation only; all original actor owners, source transforms, service methods and logical controls remain authoritative. One indexed maintenance station per service pose.'};p.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8',newline='\n')
(r/'tmp/v2-finish-review/stoves-parking-fit.json').write_text(json.dumps({'evidence_class':'INERT','endpoints':endpoints,'method':'Exact native surface fit between deck, backsplash, condiment shelf and retained other burner stock. Endpoints seated at first collision boundary with two-micrometre clearance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print(endpoints)
