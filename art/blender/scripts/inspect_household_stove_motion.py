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

# Frozen native L-hook witness from the delivered parking_bearing.py.
def retained_bearing(shoe,pose,center,tolerance=.00003,offset=None):
 assert tolerance<=.00003
 theta=math.radians(shoe['keeper_facet_degrees']);radial=Vector((math.cos(theta),math.sin(theta),0));inv=pose.inverted()
 points=[inv@(shoe.matrix_world@v.co+(offset or Vector())) for v in shoe.data.vertices]
 radius=.104*math.cos(math.pi/48);origin=Vector((center[0],center[1],0));shoe.data.calc_loop_triangles()
 # Every surface triangle belongs wholly to the below-seat or inside-bore
 # complement. The two closed rectangular legs make the same L decomposition.
 for tri in shoe.data.loop_triangles:
  pp=[points[j] for j in tri.vertices]
  if not (max(p.z-.888 for p in pp)<=tolerance or max((p-origin).dot(radial)-radius for p in pp)<=tolerance):return False
 return True

def coaxial_contact(a,b):
 # The source's circular pin/annular receiver is an intentional bearing, not
 # a general crossing waiver. Check their actual common axis and nominal radii.
 axis=b['points'][:,1:].mean(0)
 if np.linalg.norm(a['points'][:,1:].mean(0)-axis)>.00003:return False
 outer=np.linalg.norm(b['points'][:,1:]-axis,axis=1)
 annulus=np.linalg.norm(a['points'][:,1:]-axis,axis=1)
 return abs(float(outer.max())-.004)<.000001 and abs(float(annulus.min())-.004)<.000001 and abs(float(annulus.max())-.009)<.000001

bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_stoves.blend'));bpy.context.view_layer.update()
objects=list(bpy.data.collections['ClosedConstruction'].objects);native={}
fixture=json.loads((r/'art/blender/household_stoves_construction.json').read_text(encoding='utf-8'))
assemblies={stock['name']:stock['assembly'] for stock in fixture['closed_stocks']}
obstructions={row['id']:set(row.get('service_obstructions',[])) for row in fixture['runtime']['assemblies']}
def moves(stock,service):
 return stock['component']=='OvenDoor' or (stock['component'] in ['Grate'+str(service+1),'BurnerCap'+str(service+1)] and service not in obstructions[stock['assembly']])
for o in objects:
 p=np.asarray([o.matrix_world@v.co for v in o.data.vertices]);f=[list(t.vertices) for t in o.data.polygons]
 native[o.name]={'points':p,'faces':f,'low':p.min(0),'high':p.max(0),'tree':BVHTree.FromPolygons(p,f),'component':o.get('component','Body'),'assembly':assemblies[o.name],'source_label':o.name[len(assemblies[o.name])+1:]}
members={identity:[name for name,d in native.items() if d['assembly']==identity] for identity in set(assemblies.values())}
failures=[];checks=0;classified=[]
for service in range(4):
 for u in np.linspace(0,1,41):
  moved={}
  for name,d in native.items():
   if u==0 or not moves(d,service):
    moved[name]=d;continue
   m=motion(d['component'],service,float(u));p=d['points']@np.asarray(m.to_3x3()).T+np.asarray(m.translation)
   moved[name]={**d,'points':p,'low':p.min(0),'high':p.max(0),'tree':BVHTree.FromPolygons(p,d['faces'])}
  for j,(name,a) in enumerate(moved.items()):
   if not moves(a,service):continue
   for other in members[a['assembly']]:
    b=moved[other]
    # Variants are authored at the same origin but installed in different rooms.
    # Preserve every within-appliance collision pair, not artificial crossings
    # between seven alternative appliances superimposed in the source library.
    if b['assembly']!=a['assembly'] or other==name or b['component']==a['component']:continue
    if np.any(a['high']<=b['low']+.00003) or np.any(b['high']<=a['low']+.00003):continue
    if '_Knuckle' in name and '_Pin' in other:continue
    if a['source_label'].startswith('Moving hinge knuckle') and b['source_label'].startswith('Hinge pin') and coaxial_contact(a,b):
     wrong={**b,'points':b['points']+np.array((0,.002,0))}
     assert not coaxial_contact(a,wrong),'off-axis pin must not qualify as a bearing'
     classified.append({'source':name,'other':other,'station':service,'progress':float(u),'kind':'nominal_circular_pin_bearing'});continue
    hits=a['tree'].overlap(b['tree']);checks+=1
    if hits:
     shoe=bpy.data.objects[other]
     if u==1 and a['source_label'].startswith('Grate cast hoop') and b['source_label'].startswith('Grate hanger shoe') and abs(shoe['parked_side_x']-fit['grate_parking'][service]['blender_center'][0])<1e-7:
      pose=motion(a['component'],service,1.);center=[(-.17,.13),(.17,.13),(-.17,-.14),(.17,-.14)][service]
      if retained_bearing(shoe,pose,center):
       theta=math.radians(shoe['keeper_facet_degrees']);offset=pose.to_3x3()@Vector((.002*math.cos(theta),.002*math.sin(theta),0))
       assert not retained_bearing(shoe,pose,center,offset=offset),'penetrating hook must fail its half-space witness'
       classified.append({'source':name,'other':other,'station':service,'progress':float(u),'kind':'retained_endpoint_bearing','penetration_negative_control':True});continue
     failures.append({'source':name,'other':other,'station':service,'progress':float(u),'intersections':len(hits)})
out={'evidence_class':'INERT','sampled_surface_checks':checks,'obstructed_station_denials':{k:sorted(v) for k,v in obstructions.items() if v},'classified_contacts':classified,'failures':failures,'scope':'Exact triangle survey at 41 poses for each of four indexed maintenance stations. Includes original oven arc and fitted loose-stock presentation. This is sampled motion QA, not a mathematical continuous-clearance proof.'}
(r/'tmp/v2-finish-review/household-stoves-motion.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,[(f['source'],f['other'],f['station'],f['progress']) for f in failures[:15]]
print('STOVE SURVEY:',checks,'sampled nearby surface pairs clear')
