"""Fit city lamp bearings to retained exported surfaces in their source frame."""
from pathlib import Path
import bpy,json,math
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
plan=json.loads((r/'art/data/fixed_lighting/source_plan.json').read_text(encoding='utf-8'))
fixture=json.loads((r/'game/tests/fixtures/orison_fixed_lighting.json').read_text(encoding='utf-8'))
bpy.ops.wm.read_factory_settings(use_empty=True)
paths=sorted((r/'game/assets/building/floor_01_cells').glob('*.gltf'))
paths.append(r/'game/assets/building/orison_v2/exterior/passage_gateway.gltf')
trees=[]
for p in paths:
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p));bpy.context.view_layer.update()
 for o in set(bpy.data.objects)-before:
  if o.type=='MESH':trees.append((p.name,o.name,BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[tuple(f.vertices) for f in o.data.polygons])))
with bpy.data.libraries.load(str(r/'art/blender/bar_ceiling_finish.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if '__' in n]
for o in dst.objects:
 if o is not None and o.type=='MESH':
  bpy.context.scene.collection.objects.link(o);bpy.context.view_layer.update();trees.append(('shop_bar.gltf',o.name,BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[tuple(f.vertices) for f in o.data.polygons])))
contacts=[];failures=[];actors=0
for row in plan['instances']:
 if row.get('domain','room')=='room':continue
 actors+=1;m=row['source_marker'];pose=Matrix.Translation(Vector(m['pos']))@Matrix.Rotation(math.radians(m.get('yaw_deg',0)*(1 if m['kind']=='sconce_globe' else -1)),4,'Z')
 offset=row.get('visual_offset',[0,0,0]);pose=pose@Matrix.Translation((offset[0],-offset[2],offset[1]))
 for c in fixture['contacts']:
  if c['assembly']!=row['variant']:continue
  p=c['point'];d=c['direction'];at=pose@Vector((p[0],-p[2],p[1]));direction=pose.to_3x3()@Vector((d[0],-d[2],d[1]));hits=[]
  for file,name,t in trees:
   if row['domain']=='bar' and file!='shop_bar.gltf':continue
   hit,n,_,distance=t.ray_cast(at+direction*.004,-direction,.008)
   if hit is not None and (hit-at).length<.00004 and n.dot(direction)>.99:hits.append({'source':file,'mesh':name,'error_m':(hit-at).length,'normal':list(n)})
  result={'id':row['id'],'variant':row['variant'],'point':list(at),'direction':list(direction),'support':hits};contacts.append(result)
  if not hits:failures.append(result)
out=r/'tmp/v2-finish-review/fixed-lighting-city-context.json';out.write_text(json.dumps({'evidence_class':'INERT','actors':actors,'contacts':contacts,'failures':failures,'scope':'Retained source surface contacts; engine collision and composed review remain separate.'},indent=2)+'\n',encoding='utf-8',newline='\n')
assert not failures,failures
print('FIXED LIGHTING CITY CONTEXT:',actors,'actors;',len(contacts),'actual exported surface bearings')
