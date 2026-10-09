"""Real native/retained support geometry for every passive surface record."""
from pathlib import Path
import json,math
import bpy
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
fixture=json.loads((r/'game/tests/fixtures/orison_surface_stock.json').read_text());props={p['id']:p for p in json.loads((r/'game/data/orison_v2/domestic_surface_props.json').read_text())['props']}
furniture={p['id']:p for p in json.loads((r/'game/data/orison_v2/domestic_furniture.json').read_text())['furniture']}
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/surface_stock.blend'))
def bp(p):return Vector((p[0],-p[2],p[1]))
def pose(row):return Matrix.Translation(bp(row['position']))@Matrix.Rotation(row['yaw'],4,'Z')
def native_tree(obj,transform=Matrix.Identity(4)):
 return BVHTree.FromPolygons([transform@obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
def source_tree(row):
 points=[];faces=[]
 for surface in row['surfaces']:
  values=surface['vertices'];normals=surface['normals']
  for i in range(0,len(values),9):
   triangle=[bp(values[i+j:i+j+3]) for j in (0,3,6)];indices=list(range(len(points),len(points)+3))
   if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).dot(bp(normals[i:i+3]))<0:indices.reverse()
   points.extend(triangle);faces.append(indices)
 return BVHTree.FromPolygons(points,faces)
def box_tree(low,high):
 points=[bp((x,y,z)) for z in (low[2],high[2]) for y in (low[1],high[1]) for x in (low[0],high[0])]
 return BVHTree.FromPolygons(points,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)])
native_ids=set(json.loads((r/'game/data/orison_v2/work_tables.json').read_text())['assemblies'][i]['id'] for i in range(5))
with bpy.data.libraries.load(str(r/'art/blender/work_tables.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if '__' in n]
for obj in dst.objects:bpy.context.scene.collection.objects.link(obj);obj.hide_render=True
bpy.context.view_layer.update()
supports={}
for identity in {p['support'] for p in props.values()}:
 if identity in native_ids:supports[identity]=[native_tree(obj) for obj in dst.objects if obj.name.startswith(identity+'__')]
 elif identity in furniture:supports[identity]=[source_tree(furniture[identity])]
 elif identity.endswith('_prep_cabinet'):
  # Native prep cabinet worktop (prep_cabinets.md): .9 m over the retained .83 x .535 envelope.
  supports[identity]=[box_tree((-.415,.88,-.29),(.415,.90,.245))]
 else:
  assert identity.endswith('_KITCHEN_SINK_01'),identity
  script=(r/'game/scripts/props/tap_prop.gd').read_text()
  for literal in ['var board_w := 0.42','Vector3(board_w, 0.026, d)','Vector3(center_x, top - 0.003, 0)','Vector3(0.010, 0.011, d - 0.075)','Vector3(x, top + 0.014, 0)']:assert literal in script,literal
  # Exact standard drainboard and seven ribs; all compact sinks use the
  # separate 4B counter above, not this branch.
  center=.61/2+.42/2;top=.90
  b=[box_tree((center-.21,top-.016,-.23),(center+.21,top+.010,.23))]
  for i in range(7):
   x=center-.15+i*.05;b.append(box_tree((x-.005,top+.0085,-.1925),(x+.005,top+.0195,.1925)))
  supports[identity]=b
checks=[];failures=[]
prop_trees={}
for prop in props.values():
 points=[];faces=[];transform=pose(prop)
 for obj in bpy.context.scene.objects:
  if not obj.name.startswith(prop['id']+'__'):continue
  offset=len(points);points.extend(transform@obj.matrix_world@v.co for v in obj.data.vertices);faces.extend([offset+i for i in p.vertices] for p in obj.data.polygons)
 assert points,prop['id']
 prop_trees[prop['id']]=BVHTree.FromPolygons(points,faces)
separations=[]
for i,left in enumerate(props.values()):
 for right in list(props.values())[i+1:]:
  if left['support']!=right['support']:continue
  crossing=bool(prop_trees[left['id']].overlap(prop_trees[right['id']]))
  separations.append({'left':left['id'],'right':right['id'],'crossing':crossing})
  if crossing:failures.append(separations[-1])
with bpy.data.libraries.load(str(r/'art/blender/task_lamps.blend'),link=False) as (src,lamps):lamps.objects=[n for n in src.objects if n.startswith('TaskLamp_') and '__' in n]
for obj in lamps.objects:bpy.context.scene.collection.objects.link(obj)
bpy.context.view_layer.update()
for lamp in json.loads((r/'game/data/orison_v2/task_lamp_installations.json').read_text())['lamps']:
 trees=[native_tree(o,pose(lamp)) for o in lamps.objects if o.name.startswith('TaskLamp_'+lamp['variant']+'__')]
 for prop in props.values():
  if prop['support']!=lamp['support']:continue
  crossing=any(prop_trees[prop['id']].overlap(t) for t in trees)
  separations.append({'left':prop['id'],'right':lamp['id'],'crossing':crossing})
  if crossing:failures.append(separations[-1])
for contact in fixture['contacts']:
 prop=props[contact['assembly']];at=pose(prop)@bp(contact['point']);trees=supports[prop['support']]
 hits=[t.ray_cast(at+Vector((0,0,.004)),Vector((0,0,-1)),.008) for t in trees]
 valid=any(p is not None and (p-at).length<.00004 and n.z>.9 for p,n,_,_ in hits)
 record={'prop':prop['id'],'support':prop['support'],'label':contact['label'],'point':list(at),'valid':valid}
 if not valid:failures.append(record)
 checks.append(record)
out=r/'tmp/v2-finish-review/surface-stock-context.json';out.write_text(json.dumps({'evidence_class':'INERT','supports':len(supports),'bearings':checks,'neighbour_separations':separations,'failures':failures,'scope':'Actual native work tables, retained furniture triangles, source-asserted drainboard ribs and native prop/lamp neighbours. No runtime collision or visual acceptance.'},indent=2)+'\n',newline='\n')
assert not failures,failures
print('SURFACE STOCK CONTEXT:',len(checks),'bearings;',len(supports),'support actors')
