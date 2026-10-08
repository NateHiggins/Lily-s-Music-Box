"""Continuous native door clearance with analytic arc bounds and refined hulls."""
from pathlib import Path
import ast,json,math
import bpy,bmesh,numpy as np
from mathutils import Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
helper=r/'art/blender/scripts/inspect_household_toaster_motion.py'
tree=ast.parse(helper.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'geometry','planes','clip','crossings'}],type_ignores=[]),str(helper),'exec'))
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/household_fridges.blend'));bpy.context.view_layer.update()
epsilon=.00003;checks=[];failures=[]

def rotate(points,pivot,angle):
 c,s=np.cos(angle),np.sin(angle);matrix=np.array([[c,-s,0],[s,c,0],[0,0,1]])
 return (points-pivot)@matrix.T+pivot

def arc_bounds(points,pivot,a,b):
 values=[rotate(points,pivot,a),rotate(points,pivot,b)];q=points-pivot
 for axis in [0,1]:
  u=q[:,0] if axis==0 else q[:,1];v=-q[:,1] if axis==0 else q[:,0]
  for k in range(-2,4):
   angles=np.arctan2(v,u)+k*math.pi;valid=(angles>=a)&(angles<=b)
   if valid.any():
    extreme=u[valid]*np.cos(angles[valid])+v[valid]*np.sin(angles[valid])+pivot[axis]
    # Only this coordinate matters for the bound; copy other coordinates.
    extra=points[valid].copy();extra[:,axis]=extreme;values.append(extra)
 p=np.concatenate(values);return p.min(0),p.max(0)

for identity,owner,degrees,w,front in [('FridgeIcebox','Door',105,.70,.29),('FridgeIcebox','IceDoor',98,.70,.29),('FridgeMonitor','Door',105,.72,.32)]:
 objects=[o for o in bpy.data.collections['ClosedConstruction'].objects if o.name.startswith(identity+'_')]
 fixed=[o for o in objects if o.get('component','Body')=='Body'];leaf=[o for o in objects if o.get('component')==owner]
 pivot=np.array((-w/2,front,0.));end=math.radians(degrees);a,b=sorted([0,end])
 for obj in leaf:
  points,_=geometry(obj)
  for other in fixed:
   q,faces=geometry(other);qlow,qhigh=q.min(0),q.max(0)
   # Coaxial bore and fixed pin have the same 3mm bearing radius. The hollow
   # knuckle must not be approximated by a solid convex hull for this pair.
   if '_MovingKnuckle' in obj.name and '_Pin' in other.name:
    radial=np.linalg.norm((points-pivot)[:,:2],axis=1)
    pinradial=np.linalg.norm((q-pivot)[:,:2],axis=1)
    if qhigh[2]<points[:,2].min() or qlow[2]>points[:,2].max():continue
    assert radial.min()>=.003-epsilon and pinradial[q[:,2]<=points[:,2].max()].max()<=.003+epsilon
    checks.append([obj.name,other.name,'coaxial annular bearing']);continue
   pending=[(a,b)];refined=0;bad=0
   while pending:
    lo_angle,hi_angle=pending.pop();low,high=arc_bounds(points,pivot,lo_angle,hi_angle)
    if np.any(high<=qlow+epsilon) or np.any(qhigh<=low+epsilon):continue
    if hi_angle-lo_angle>math.radians(.5):
     middle=(lo_angle+hi_angle)*.5;pending.extend([(lo_angle,middle),(middle,hi_angle)]);continue
    swept=np.concatenate([rotate(points,pivot,angle) for angle in [lo_angle,hi_angle]])
    hull=planes(swept)
    # Circumscribe every continuous arc between the endpoints. Maximum
    # sagitta is under 5 micrometres at a half-degree appliance-door step.
    sagitta=np.linalg.norm((points-pivot)[:,:2],axis=1).max()*(1-math.cos((hi_angle-lo_angle)*.5))
    hull[:,3]+=sagitta;refined+=1
    bad+=crossings(q,faces,hull,low,high)
    if bad:break
   if refined:checks.append([obj.name,other.name,refined,bad])
   if bad:failures.append(checks[-1])
objects=[o for o in bpy.data.collections['ClosedConstruction'].objects if o.name.startswith('FridgeIcebox_')]
for obj in [o for o in objects if o.get('component')=='DripTray']:
 points,_=geometry(obj);swept=np.concatenate([points,points+np.array((0,.30,0))]);low,high=swept.min(0),swept.max(0);hull=planes(swept)
 for other in [o for o in objects if o.get('component','Body')=='Body']:
  q,faces=geometry(other)
  if np.any(high<=q.min(0)+epsilon) or np.any(q.max(0)<=low+epsilon):continue
  bad=crossings(q,faces,hull,low,high);checks.append([obj.name,other.name,'full tray translation',bad])
  if bad:failures.append(checks[-1])
out=r/'tmp/v2-finish-review/household-fridges-motion.json'
out.write_text(json.dumps({'evidence_class':'INERT','checks':checks,'failures':failures,'scope':'All three source hinges (105/98 degrees) and the 300 mm pan stroke. Analytic arc bounds reject distant stocks; bounded convex hulls enclose every intermediate angle. Exact annular pin exception; 30 micrometre contact tolerance.'},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('REFRIGERATOR MOTION:',len(checks),'nearby native door pairs clear')
