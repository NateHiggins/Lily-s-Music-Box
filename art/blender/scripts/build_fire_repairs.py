"""Period timber staging and source-fitted masonry repairs; no gameplay authority.
The owner's fire/renovation direction is the narrative source, not dated canon.
"""
from pathlib import Path
import sys,json,collections,math,hashlib
import bpy,bmesh
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
bpy.ops.wm.read_factory_settings(use_empty=True)
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_bytes())
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_bytes())['materials']
finishes={k:dict(catalog_key=k,tint=t,pigment=1.,normal=.65,roughness=1.) for k,t in {
 'timber':[.72,.65,.53,1], 'iron_neutral':[.55,.55,.52,1],
 'brick':[.92,.84,.71,1]}.items()}
mats={k:material(ROOT,k,v,catalog) for k,v in finishes.items()}
native=bpy.data.collections.new('Editable fire repair stock');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireRepairs');bpy.context.scene.collection.children.link(exports)
groups=collections.defaultdict(list);stocks=[]
def bv(p):return Vector((p[0],-p[2],p[1]))
def keep(obj,name,key):
 obj.name=name
 bpy.context.view_layer.objects.active=obj
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 assert all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,name
 bm.to_mesh(obj.data);bm.free()
 for c in list(obj.users_collection):c.objects.unlink(obj)
 native.objects.link(obj);groups[key].append(obj)
 coords=[v.co for v in obj.data.vertices]
 stocks.append(dict(name=name,key=key,bounds=[min(p[i] for p in coords) for i in range(3)]+[max(p[i] for p in coords) for i in range(3)]))
 return obj
def box(name,key,at,size):
 bpy.ops.mesh.primitive_cube_add(size=1,location=bv(at));obj=bpy.context.object
 obj.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bevel=obj.modifiers.new('Worked edge','BEVEL');bevel.width=min(.002,min(size)*.15);bevel.segments=1;bpy.ops.object.modifier_apply(modifier=bevel.name)
 return keep(obj,name,key)
def spar(name,a,b,width=.075):
 a,b=bv(a),bv(b);bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)/2);obj=bpy.context.object
 obj.dimensions=(width,width,(b-a).length);obj.rotation_mode='QUATERNION';obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(b-a)
 return keep(obj,name,'timber')
# Four timber uprights on individual sole boards. The narrow assembly is
# outside the brick leaf and all authored street/apartment door apertures.
xs=[-11.25,-8.35];zs=[-13.72,-12.80]
for i,x in enumerate(xs):
 for j,z in enumerate(zs):
  box(f'Sole_{i}_{j}','timber',(x,.025,z),(.50,.05,.38))
  box(f'Upright_{i}_{j}','timber',(x,6.43,z),(.12,12.76,.12))
for tier,y in enumerate([3.15,6.35,9.55,12.75]):
 for j,z in enumerate(zs):
  box(f'Ledger_{tier}_{j}','timber',(-9.80,y-.12,z),(3.18,.16,.10))
  for i,x in enumerate(xs):
   box(f'IronStrap_{tier}_{i}_{j}','iron_neutral',(x,y-.12,z-.066),(.15,.21,.012))
 for i,x in enumerate(xs):
  box(f'Bearer_{tier}_{i}','timber',(x,y-.055,-13.26),(.12,.10,1.16))
 # Independent boards, three-millimetre joints and covered bearer seats.
 for n in range(5):
  box(f'Deck_{tier}_{n}','timber',(-9.80,y+.021,-13.70+n*.218),(3.08,.042,.215))
 box(f'ToeBoard_{tier}','timber',(-9.80,y+.12,-13.81),(3.08,.20,.035))
 for i,x in enumerate(xs):
  box(f'GuardPost_{tier}_{i}','timber',(x,y+.59,-13.76),(.075,1.12,.075))
 for n,h in enumerate([.58,1.05]):box(f'Guard_{tier}_{n}','timber',(-9.80,y+h,-13.76),(3.08,.075,.055))
 bottom=.12 if tier==0 else y-3.08
 spar(f'FaceBrace_{tier}',(xs[tier%2],bottom,-13.80),(xs[1-tier%2],y-.18,-13.80))
 for i,x in enumerate(xs):
  spar(f'EndBrace_{tier}_{i}',(x,bottom,zs[0]),(x,y-.20,zs[1]))
  # Wall tie enters solid masonry at the floor line; never through glazing.
  box(f'WallTie_{tier}_{i}','iron_neutral',(x,y-.18,-12.68),(.035,.035,.42))
  box(f'TiePlate_{tier}_{i}','iron_neutral',(x,y-.18,-12.638),(.23,.23,.016))
# Replacement heads around the west study bays. Real angle section with end
# bearing (180 mm), not a flat stripe painted on the wall.
levels={r['id']:r['y'] for r in layout['levels']}
windows=[w for w in layout['windows'] if w['axis']=='x' and w['center'][1]<-12 and -11<w['center'][0]<-8]
for w in windows:
 x,z=w['center'];y=levels[w['level']]+w['sill']+w['height'];length=w['width']+.36
 box(w['id']+'_LintelWeb','iron_neutral',(x,y+.047,z-.292),(length,.10,.012))
 box(w['id']+'_LintelSeat','iron_neutral',(x,y+.003,z-.25),(length,.012,.095))
 # Toothed replacement brick reveals, leaving the full clear aperture open.
 for side in [-1,1]:
  for row in range(7):
   extent=.23 if row%2 else .35
   box(w['id']+f'_Repair_{side}_{row}','brick',(x+side*(w['width']/2+extent/2+.025),y-.04-row*.083,z-.286),(extent,.073,.023))
for key,objects in groups.items():
 partition(exports,'FireRepairs__'+key,objects,finishes[key],mats[key],Matrix.Identity(4),catalog)
native.hide_render=True;native.hide_viewport=True
bpy.context.preferences.filepaths.save_version=0
result=export(ROOT,'fire_repairs',exports)
out=ROOT/'art/blender/fire_repairs_construction.json'
out.write_text(json.dumps(dict(evidence_class='INERT',layout_sha256_lf=hashlib.sha256((ROOT/'game/data/orison_v2_blockout.json').read_bytes().replace(b'\r\n',b'\n')).hexdigest(),stocks=stocks,export=result,scope='Localized west-front repair staging, replacement lintels and toothed masonry; no shell demolition or historical fire date asserted.'),indent=2)+'\n',encoding='utf-8',newline='\n')
print('FIRE REPAIRS',len(stocks),result)
