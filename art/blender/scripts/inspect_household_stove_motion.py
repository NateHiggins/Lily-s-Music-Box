"""Native source motion survey: exact surfaces at endpoints and interior poses."""
from pathlib import Path
import json,math,ast
import bpy,numpy as np
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
fit=json.loads((r/'art/data/household_stoves/source_plan.json').read_text(encoding='utf-8'))['native_service']
def smoothstep(value):
 t=min(1.,max(0.,value));return t*t*(3-2*t)
def motion(part,service,u):
 if part=='OvenDoor':
  p=Vector((0,.318,.34));return Matrix.Translation(p)@Matrix.Rotation(math.radians(-86)*u,4,'X')@Matrix.Translation(-p)
 i=service;x,y=[(-.17,.13),(.17,.13),(-.17,-.14),(.17,-.14)][i]
 if part=='Grate'+str(i+1):
  p=Vector((x,y,.90));q=Vector(fit['grate_parking'][i]['blender_center']);at=p.lerp(q,u)+Vector((0,fit['grate_forward_m']*math.sin(math.pi*u) if i>=2 else 0,fit['grate_lift_m']*math.sin(math.pi*u)))
  return Matrix.Translation(at)@Matrix.Rotation(math.radians(fit['grate_parking'][i]['angle_degrees'])*u,4,'X')@Matrix.Translation(-p)
 if part=='BurnerCap'+str(i+1):
  lift=fit['cap_lift_m']*(smoothstep((u-.25)/.20)-smoothstep((u-.8)/.2))
  return Matrix.Translation(Vector(fit['cap_end_blender_delta'][i])*smoothstep((u-.45)/.35)+Vector((0,0,lift)))
 return Matrix.Identity(4)

bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_stoves.blend'));bpy.context.view_layer.update()
objects=list(bpy.data.collections['ClosedConstruction'].objects);native={}
for o in objects:
 p=np.asarray([o.matrix_world@v.co for v in o.data.vertices]);f=[list(t.vertices) for t in o.data.polygons]
 native[o.name]={'points':p,'faces':f,'low':p.min(0),'high':p.max(0),'tree':BVHTree.FromPolygons(p,f),'component':o.get('component','Body')}
failures=[];checks=0
for service in range(4):
 for u in np.linspace(0,1,41):
  moved={}
  for name,d in native.items():
   m=motion(d['component'],service,float(u));p=d['points']@np.asarray(m.to_3x3()).T+np.asarray(m.translation)
   moved[name]={**d,'points':p,'low':p.min(0),'high':p.max(0),'tree':BVHTree.FromPolygons(p,d['faces'])}
  for j,(name,a) in enumerate(moved.items()):
   if a['component'] not in ['OvenDoor','Grate'+str(service+1),'BurnerCap'+str(service+1)]:continue
   for other,b in moved.items():
    if other==name or b['component']==a['component']:continue
    if np.any(a['high']<=b['low']+.00003) or np.any(b['high']<=a['low']+.00003):continue
    if '_Knuckle' in name and '_Pin' in other:continue
    hits=a['tree'].overlap(b['tree']);checks+=1
    if hits:failures.append({'source':name,'other':other,'station':service,'progress':float(u),'intersections':len(hits)})
out={'evidence_class':'INERT','sampled_surface_checks':checks,'failures':failures,'scope':'Exact triangle survey at 41 poses for each of four indexed maintenance stations. Includes original oven arc and fitted loose-stock presentation. This is sampled motion QA, not a mathematical continuous-clearance proof.'}
(r/'tmp/v2-finish-review/household-stoves-motion.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,[(f['source'],f['other'],f['station'],f['progress']) for f in failures[:15]]
print('STOVE SURVEY:',checks,'sampled nearby surface pairs clear')
