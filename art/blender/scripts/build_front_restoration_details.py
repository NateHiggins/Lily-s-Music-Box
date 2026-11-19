"""Native facade articulation and fitted window seats for restored front volume."""
from pathlib import Path
import sys,json,collections
import bpy,bmesh
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
bpy.ops.wm.read_factory_settings(use_empty=True)
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_bytes())
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
finishes={k:dict(catalog_key=k,tint=t,pigment=1.,normal=.35,roughness=1.) for k,t in {
 'brick':[.85,.78,.72,1], 'concrete':[.88,.84,.74,1], 'wood_dark':[.80,.74,.63,1]}.items()}
mats={k:material(ROOT,k,v,catalog) for k,v in finishes.items()}
native=bpy.data.collections.new('Editable front restoration');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FrontRestoration');bpy.context.scene.collection.children.link(exports)
groups=collections.defaultdict(list);stocks=[]
def box(name,key,at,size):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]));o=bpy.context.object
 o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bevel=o.modifiers.new('Worked edge','BEVEL');bevel.width=min(.006,min(size)*.15);bevel.segments=2;bpy.ops.object.modifier_apply(modifier=bevel.name)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges) and bm.calc_volume()>0;bm.to_mesh(o.data);bm.free()
 o.name=name
 for c in list(o.users_collection):c.objects.unlink(o)
 native.objects.link(o);groups[key].append(o);stocks.append(dict(name=name,finish=key,center=at,size=size));return o
# The existing central entrance remains a shallow protected recess. The new
# facade shares the front plane of the occupied side wings.
for x in [-15.48,-8.50,-5.45,5.45,8.50,15.48]:
 box(f'Pier_{x}','brick',(x,9.6,-12.67),(.32,19.2,.10))
 box(f'PierBase_{x}','concrete',(x,.28,-12.70),(.44,.56,.17))

leaders=json.loads((ROOT/'art/blender/roof_drainage_leaders_construction.json').read_bytes())['leaders']
south=[leader for leader in leaders if leader['side']=='south']
assert {leader['id'] for leader in south}=={'S_W','S_E'}

def leader_clearances(y):
 result=[]
 for leader in south:
  path=leader['pipe_axis']
  if y>path[0][1]:
   x=leader['hopper_center'][0]
   clearance=.205
  else:
   x=path[-1][0]
   for start,finish in zip(path,path[1:]):
    assert start[1]>finish[1],leader['id']
    if start[1]>=y>=finish[1]:
     fraction=(start[1]-y)/(start[1]-finish[1])
     x=start[0]+(finish[0]-start[0])*fraction
     break
   clearance=leader['bore_radius']+leader['wall']+.035
  result.append((x-clearance,x+clearance))
 return sorted(result)

def band(name,a,b,y,z,height,depth):
 # The belts continue behind a small reveal at each drain, leaving the
 # pipe sleeve and its clearance in front of the masonry bearing face.
 cursor=a
 for low,high in leader_clearances(y):
  if high<=a or low>=b:continue
  if low>cursor:box(name,'concrete',((cursor+low)/2,y,z),(low-cursor,height,depth))
  cursor=max(cursor,high)
 if cursor<b:box(name,'concrete',((cursor+b)/2,y,z),(b-cursor,height,depth))

for n in range(1,7):
 y=n*3.2
 band(f'Belt_{n}',-15.60,15.60,y-.13,-12.68,.12,.16)
 band(f'BeltDrip_{n}',-15.63,15.63,y-.06,-12.70,.06,.22)
for a,b in [(-15.60,-2.4),(2.4,15.60)]:band('GroundPlinth',a,b,.18,-12.68,.36,.16)
for y,depth,h in [(18.97,.25,.12),(19.10,.36,.12),(19.21,.44,.10)]:
 band('Cornice',-15.625,15.625,y,-12.62-depth/2,h,depth)
levels={r['id']:r['y'] for r in layout['levels']}
for w in layout['windows']:
 if '_FRONT_' not in w['space']:continue
 x,z=w['center'];base=levels[w['level']];width=w['width'];sill=base+w['sill'];head=sill+w['height']
 box(w['id']+'_Sill','concrete',(x,sill-.045,z-.285),(width+.28,.09,.31))
 box(w['id']+'_Head','concrete',(x,head+.065,z-.285),(width+.34,.13,.30))
 box(w['id']+'_Crown','concrete',(x,head+.155,z-.30),(width+.42,.05,.34))
 box(w['id']+'_Keystone','concrete',(x,head+.055,z-.46),(.17,.19,.05))
 if ('_GALLERY_' in w['id'] and x in (-3.7,0,3.7)) or w['id']=='F01_LOBBY_WINDOW_W':
  for plank in range(3):box(w['id']+'_Seat','wood_dark',(x,base+.455,-11.70+plank*.15),(1.9,.045,.145))
  for leg in [-.78,.78]:
   for zleg in [-11.68,-11.43]:box(w['id']+'_Leg','wood_dark',(x+leg,base+.2175,zleg),(.065,.435,.065))
  box(w['id']+'_Stretcher','wood_dark',(x,base+.19,-11.55),(1.58,.065,.065))
for key,objects in groups.items():partition(exports,'FrontRestoration__'+key,objects,finishes[key],mats[key],Matrix.Identity(4),catalog)
native.hide_render=True;native.hide_viewport=True;bpy.context.preferences.filepaths.save_version=0
result=export(ROOT,'front_restoration_details',exports)
result['asset']=Path(result['asset']).relative_to(ROOT).as_posix()
(ROOT/'art/blender/front_restoration_construction.json').write_text(json.dumps(dict(evidence_class='INERT',stocks=stocks,export=result),indent=2)+'\n',encoding='utf-8',newline='\n')
print('FRONT RESTORATION',len(stocks),result)
