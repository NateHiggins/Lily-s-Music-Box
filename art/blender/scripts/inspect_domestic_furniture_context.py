"""All 103 native installations against production anchors and neighbours."""
from pathlib import Path
import json, math
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
layout=json.loads((r/'game/data/orison_v2_blockout.json').read_text())
anchors={x['id']:x for x in layout['anchors']};levels={x['id']:x['y'] for x in layout['levels']};spaces={x['id']:x for x in layout['spaces']}
source=json.loads((r/'game/data/orison_v2/domestic_furniture.json').read_text())['furniture'];furniture={x['id']:x for x in source}
for row in json.loads((r/'game/data/orison_v2/completion_interiors.json').read_text())['furniture']:
 furniture[row['id']]={**furniture[row['template']],'id':row['id']}

def bp(p):return Vector((p[0],-p[2],p[1]))
def pose(identity):
 a=anchors[identity];at=bp(a['position']);at.z+=levels[a['level']]
 return Matrix.Translation(at)@Matrix.Rotation(float(a['yaw']),4,'Z')

def native_mesh(obj):
 return ([obj.matrix_world@v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])

def merge(meshes):
 points=[];faces=[]
 for vertices,polygons in meshes:
  offset=len(points);points.extend(vertices);faces.extend([[offset+i for i in p] for p in polygons])
 return points,faces

def old_mesh(record):
 if 'surfaces' not in record:
  lo,hi=record['bounds'];vertices=[bp([x,y,z]) for z in [lo[2],hi[2]] for y in [lo[1],hi[1]] for x in [lo[0],hi[0]]]
  return vertices,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
 vertices=[];faces=[]
 for surface in record['surfaces']:
  values=surface['vertices'];normals=surface['normals'];offset=len(vertices);vertices.extend(bp(values[i:i+3]) for i in range(0,len(values),3))
  for i in range(0,len(values)//3,3):
   ids=[offset+i,offset+i+1,offset+i+2];a,b,c=[vertices[j] for j in ids]
   if (b-a).cross(c-a).dot(bp(normals[i*3:i*3+3]))<0:ids.reverse()
   faces.append(ids)
 return vertices,faces

def moved(mesh,identity):
 points,faces=mesh;matrix=pose(identity);points=[matrix@p for p in points];a=np.asarray(points)
 return {'tree':BVHTree.FromPolygons(points,faces),'low':a.min(0),'high':a.max(0),'points':points,'faces':faces}

bpy.ops.wm.read_factory_settings(use_empty=True)
native={};contacts={};variants={};owners={}
for family in ['domestic_seating','domestic_tables','work_tables']:
 with bpy.data.libraries.load(str(r/f'art/blender/{family}.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if '__' in n]
 objects=dst.objects
 for obj in objects:bpy.context.scene.collection.objects.link(obj)
 bpy.context.view_layer.update()
 fixture=json.loads((r/f'game/tests/fixtures/orison_{family}.json').read_text())
 for row in fixture['assemblies']:
  identity=row['id'];mesh=merge([native_mesh(o) for o in objects if o.name.startswith(identity+'__')]);assert mesh[0],identity
  native[identity]=mesh
 if family=='work_tables':
  for row in fixture['assemblies']:owners[row['id']]=row['id']
 else:
  for row in fixture['runtime']['instances']:
   owners[row['id']]=row['variant'];variants[row['id']]=row['variant'];contacts[row['id']]=[c for c in fixture['contacts'] if c['assembly']==row['variant']]

world={}
for identity,row in furniture.items():
 assert identity in anchors,identity
 world[identity]=moved(native[owners[identity]] if identity in owners else old_mesh(row),identity)

bearings=[];clearances=[];failures=[]
for identity,variant in variants.items():
 matrix=pose(identity);anchor=anchors[identity]
 candidates=[spaces[anchor['space']]] if 'space' in anchor else [s for s in spaces.values() if s['level']==anchor['level'] and s['rect'][0]<=anchor['position'][0]<=s['rect'][2] and s['rect'][1]<=anchor['position'][2]<=s['rect'][3]]
 assert candidates,(identity,'no source floor rectangle')
 space=min(candidates,key=lambda s:(s['rect'][2]-s['rect'][0])*(s['rect'][3]-s['rect'][1]));rect=space['rect'];level_y=levels[anchor['level']]
 for contact in contacts[identity]:
  point=matrix@bp(contact['point'])
  inside=rect[0]-.00004<=point.x<=rect[2]+.00004 and rect[1]-.00004<=-point.y<=rect[3]+.00004
  if not inside or abs(point.z-level_y)>.00004:failures.append([identity,'foot outside retained floor',list(point),rect])
  bearings.append({'id':identity,'point':[point.x,point.z,-point.y],'space':space['id']})
 left=world[identity]
 for other,right in world.items():
  if other==identity or (other in variants and other<identity):continue
  if np.any(left['high']<=right['low']+.00002) or np.any(right['high']<=left['low']+.00002):continue
  overlap=left['tree'].overlap(right['tree'])
  if overlap:failures.append([identity,other,'surface intersections',len(overlap)])
  clearances.append([identity,other,len(overlap)])

stock_bearings=[]
stock=json.loads((r/'game/tests/fixtures/orison_surface_stock.json').read_text())
for row in json.loads((r/'game/data/orison_v2/domestic_surface_props.json').read_text())['props']:
 if row['support'] not in variants:continue
 transform=pose(row['support'])@Matrix.Translation(bp(row['position']))@Matrix.Rotation(float(row['yaw']),4,'Z')
 for c in stock['contacts']:
  if c['assembly']!=row['id']:continue
  point=transform@bp(c['point']);hit,normal,_,distance=world[row['support']]['tree'].ray_cast(point+Vector((0,0,.004)),Vector((0,0,-1)),.008)
  if hit is None or (hit-point).length>.00004 or normal.z<.99:failures.append([row['id'],row['support'],'missing native support',list(point)])
  stock_bearings.append({'id':row['id'],'support':row['support'],'point':[point.x,point.z,-point.y]})

out=r/'tmp/v2-finish-review/domestic-furniture-context.json'
out.write_text(json.dumps({'evidence_class':'INERT','installations':len(variants),'bearings':bearings,'nearby_pairs':clearances,'retained_stock_bearings':stock_bearings,'failures':failures,'scope':'Production anchor transforms; native seating, tables and accepted work tables; other neighbours use retained furniture triangles or conservative source bounds for model-only fixtures. Floor planes come from the source room rectangles. Actual runtime collisions and lighting remain required.'},indent=2)+'\n')
assert not failures,failures
print('DOMESTIC CONTEXT:',len(variants),'installations;',len(bearings),'floor bearings;',len(clearances),'nearby pairs clear')
