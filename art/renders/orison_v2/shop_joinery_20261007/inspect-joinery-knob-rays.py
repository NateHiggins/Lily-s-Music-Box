from pathlib import Path
import json,bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path.cwd();bpy.ops.wm.open_mainfile(filepath=str(root/'art/blender/shop_joinery.blend'));f=json.loads((root/'game/tests/fixtures/orison_shop_joinery.json').read_text(encoding='utf-8'))
for a in f['assemblies']:
 if a['kind']!='closed_door':continue
 row=next(x for x in f['original_records'] if x['id']==a['id']);k=next(x for x in f['original_records'] if x['id']==a['id'].removesuffix('_door')+'_knob');r=row['rect'];q=a['floor']['rect'];sign=1 if r[1]+r[3]<q[1]+q[3] else -1;face=q[1]+.05 if sign>0 else q[3]-.05;point=Vector(((k['rect'][0]+k['rect'][2])/2,face,k['z0']+k['h']/2));direction=Vector((0,sign,0));o=bpy.data.objects[a['id']+'__brass_dull'];tree=BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[p.vertices[:] for p in o.data.polygons]);hit=tree.ray_cast(point+direction*.2,-direction,.25)
 print('KNOB',a['cell'],'hit_depth',(hit[0]-point).dot(direction) if hit[0] is not None else None,'max_depth',max((o.matrix_world@v.co-point).dot(direction) for v in o.data.vertices))
