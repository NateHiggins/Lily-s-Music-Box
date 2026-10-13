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
for x in [-5.45,5.55,9.45]:
 box(f'Pier_{x}','brick',(x,9.6,-12.67),(.32,19.2,.10))
 box(f'PierBase_{x}','concrete',(x,.28,-12.70),(.44,.56,.17))
for n in range(1,7):
 y=n*3.2
 box(f'Belt_{n}','concrete',(1.95,y-.13,-12.68),(15.35,.12,.16))
 box(f'BeltDrip_{n}','concrete',(1.95,y-.06,-12.70),(15.42,.06,.22))
for a,b in [(-5.45,-2.4),(2.4,9.45)]:box('GroundPlinth','concrete',((a+b)/2,.18,-12.68),(b-a,.36,.16))
for y,depth,h in [(18.97,.25,.12),(19.10,.36,.12),(19.21,.44,.10)]:
 box('Cornice','concrete',(1.95,y,-12.62-depth/2),(15.5,h,depth))
levels={r['id']:r['y'] for r in layout['levels']}
for w in layout['windows']:
 if '_FRONT_' not in w['space']:continue
 x,z=w['center'];base=levels[w['level']];width=w['width'];sill=base+w['sill'];head=sill+w['height']
 box(w['id']+'_Sill','concrete',(x,sill-.045,z-.285),(width+.28,.09,.31))
 box(w['id']+'_Head','concrete',(x,head+.065,z-.285),(width+.34,.13,.30))
 box(w['id']+'_Crown','concrete',(x,head+.155,z-.30),(width+.42,.05,.34))
 box(w['id']+'_Keystone','concrete',(x,head+.055,z-.46),(.17,.19,.05))
 if '_GALLERY_' in w['id'] and abs(x)==3.7:
  for plank in range(3):box(w['id']+'_Seat','wood_dark',(x,base+.455,-11.70+plank*.15),(1.9,.045,.145))
  for leg in [-.78,.78]:
   for zleg in [-11.68,-11.43]:box(w['id']+'_Leg','wood_dark',(x+leg,base+.2175,zleg),(.065,.435,.065))
  box(w['id']+'_Stretcher','wood_dark',(x,base+.19,-11.55),(1.58,.065,.065))
for key,objects in groups.items():partition(exports,'FrontRestoration__'+key,objects,finishes[key],mats[key],Matrix.Identity(4),catalog)
native.hide_render=True;native.hide_viewport=True;bpy.context.preferences.filepaths.save_version=0
result=export(ROOT,'front_restoration_details',exports)
(ROOT/'art/blender/front_restoration_construction.json').write_text(json.dumps(dict(evidence_class='INERT',stocks=stocks,export=result),indent=2)+'\n',encoding='utf-8',newline='\n')
print('FRONT RESTORATION',len(stocks),result)
