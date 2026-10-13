from pathlib import Path
import bpy,json,math
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/washer_controls.blend'))
p={o.name:o for o in bpy.context.scene.objects if o.type=='EMPTY'}
for name in ['PressureBridge','LowerRoll','UpperRoll','UpperCarriage','PressureScrew','SafetyRelease','SafetyReset']:p[name].parent=p['SwingingWringer']
def tree(part):
 verts=[];faces=[]
 for o in part.children_recursive:
  if o.type!='MESH':continue
  start=len(verts);verts.extend(o.matrix_world@v.co for v in o.data.vertices);faces.extend(tuple(start+i for i in f.vertices) for f in o.data.polygons)
 return BVHTree.FromPolygons(verts,faces,all_triangles=True,epsilon=0)
rows=[]
for swing in range(-105,106,5):
 p['SwingingWringer'].rotation_euler.z=math.radians(swing);bpy.context.view_layer.update();wringer=tree(p['SwingingWringer']);limit=82
 for lid in range(2,83,2):
  p['TubLid'].rotation_euler.x=math.radians(lid);bpy.context.view_layer.update()
  if tree(p['TubLid']).overlap(wringer):limit=max(0,lid-2);break
 rows.append([swing,limit]);print('CLEARANCE',swing,limit,flush=True)
out=ROOT/'game/data/orison_v2/washer_clearance.json'
out.write_text(json.dumps({'schema':1,'lid_limits_degrees':rows},indent=2)+'\n',encoding='utf-8')

