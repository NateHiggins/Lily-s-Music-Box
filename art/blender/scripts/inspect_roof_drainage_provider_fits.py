"""Reopen saved runtime faces to prove soil beds and original paving joints."""
from pathlib import Path
import json,math,hashlib
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=next(path for path in Path(__file__).resolve().parents if (path/'game/project.godot').is_file());D=R/'tmp/roof-drainage-review';D.mkdir(parents=True,exist_ok=True);F=json.loads((R/'art/blender/roof_drainage_receivers_construction.json').read_bytes());S=json.loads((R/'art/blender/roof_drainage_reservations.json').read_bytes())
bpy.ops.wm.read_factory_settings(use_empty=True)
def b(p):return Vector((p[0],-p[2],p[1]))
def g(p):return [float(p.x),float(p.z),float(-p.y)]
providers={};bindings={}
for owner,kind in [('Ground','orison_ground'),('FrontPavement','front_pavement'),('ServiceAlley','alley_groundworks')]:
 native=R/'art/blender'/(kind+'.blend');meta=R/'art/blender'/(kind+'_construction.json');report=json.loads(meta.read_bytes());names=[q.get('id',q.get('name')) for q in report['parts']]
 with bpy.data.libraries.load(str(native),link=False) as (available,target):target.objects=[n for n in names if n in available.objects]
 for obj in target.objects:bpy.context.scene.collection.objects.link(obj);bpy.context.view_layer.update()
 bpy.context.view_layer.update();trees=[]
 for obj in target.objects:
  points=[obj.matrix_world@v.co for v in obj.data.vertices];obj.data.calc_loop_triangles();triangles=[tuple(p.vertices) for p in obj.data.loop_triangles]
  bounds=[g(p) for p in points];lo=[min(p[i] for p in bounds) for i in range(3)];hi=[max(p[i] for p in bounds) for i in range(3)]
  trees.append({'name':obj.name,'tree':BVHTree.FromPolygons(points,triangles,all_triangles=True),'lo':lo,'hi':hi})
 providers[owner]=trees;bindings[native.relative_to(R).as_posix()]=hashlib.sha256(native.read_bytes()).hexdigest()
def hit(owner,point,direction,reach):
 result=[]
 for row in providers[owner]:
  if any(point[i]<row['lo'][i]-reach or point[i]>row['hi'][i]+reach for i in range(3)):continue
  p,n,i,d=row['tree'].ray_cast(b(point),b(direction),reach)
  if p is not None:result.append((d,g(p),row['name']))
 return min(result) if result else None
stocks={q['name']:q for q in F['closed_stocks']};soil=[];grade=[];walls=[]
for q in F['main_saddle_beds']+F['receivers']+F['cleanouts']:
 stock=stocks[q.get('bed_owner',q['id'])];lo=stock['bounds'][:3];hi=stock['bounds'][3:];cx=(lo[0]+hi[0])/2;cz=(lo[2]+hi[2])/2
 for x in [lo[0]+.018,hi[0]-.018]:
  for z in [lo[2]+.018,hi[2]-.018]:
   expected=[x,lo[1],z];result=hit('Ground',[x,lo[1]+.002,z],[0,-1,0],.004)
   assert result and abs(result[1][1]-lo[1])<.000006,(q['id'],'missing actual soil bed',expected,result)
   soil.append({'bed':stock['name'],'expected':expected,'actual':result[1],'actual_owner':result[2],'error_m':abs(result[1][1]-lo[1])})
for q in S['grade_ports']:
 a,z0,c,z1=q['rect'];owner=q['provider'];low=q['bounds'][1];high=q['bounds'][4]
 for axis,fixed,other in [(0,a,(z0,z1)),(0,c,(z0,z1)),(2,z0,(a,c)),(2,z1,(a,c))]:
  sign=-1 if fixed in [a,z0] else 1
  for frac in [.18,.5,.82]:
   x,z=(fixed,other[0]+(other[1]-other[0])*frac) if axis==0 else (other[0]+(other[1]-other[0])*frac,fixed)
   point=[x,.05,z];point[axis]+=sign*.00004;retained=hit(owner,point,[0,-1,0],.12)
   assert retained,(q['id'],'missing retained paving outside exact port',point)
   # The receiver grade points come from the original native provider. New
   # source edges must stay on its original affine grade, not a guessed datum.
   original=[q for station in json.loads((R/'art/data/orison_roof_drainage/receiver_grade_datums.json').read_bytes())['stations'] for q in station['retained_grade_triangles']]
   heights=[]
   for t in original:
    p=t['points'];ax=p[1][0]-p[0][0];az=p[1][2]-p[0][2];bx=p[2][0]-p[0][0];bz=p[2][2]-p[0][2];dx=point[0]-p[0][0];dz=point[2]-p[0][2];det=ax*bz-az*bx
    if abs(det)<1e-12:continue
    u=(dx*bz-dz*bx)/det;v=(ax*dz-az*dx)/det
    if u>=-1e-6 and v>=-1e-6 and u+v<=1.000001:heights.append(p[0][1]+u*(p[1][1]-p[0][1])+v*(p[2][1]-p[0][1]))
   assert heights and abs(retained[1][1]-max(heights))<.000006,(q['id'],'changed actual source grade',retained,heights)
   grade.append({'id':q['id'],'point':point,'actual':retained[1],'owner':retained[2],'error_m':abs(retained[1][1]-max(heights))})
   at=[x,retained[1][1]-.08,z];at[axis]+=sign*.002;direction=[0,0,0];direction[axis]=-sign;wall=hit(owner,at,direction,.004)
   assert wall and abs(wall[1][axis]-fixed)<.000006,(q['id'],'port cut wall fit',at,wall)
   walls.append({'id':q['id'],'actual':wall[1],'owner':wall[2]})
out=D/'provider-fits.json';out.write_text(json.dumps({'evidence_class':'INERT','bindings':bindings,'actual_soil_bearings':soil,'actual_retained_grade_edges':grade,'actual_port_walls':walls},indent=2)+'\n',newline='\n')
print('REOPENED RECEIVER PROVIDER FITS',len(soil),'actual soil bearings;',len(grade),'actual original grade edges;',len(walls),'source cut wall contacts')
