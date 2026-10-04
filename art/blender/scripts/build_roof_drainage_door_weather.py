"""Source-owned Orison roof/drainage construction.

Retained gameplay authorities remain; geometry and material validation are
independent of this source recipe. No drainage capacity acceptance.
"""
from pathlib import Path
import sys,ast,json,hashlib,collections,math
import bpy,bmesh,numpy as np
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent));import roof_drainage_field as roof
R=roof.R;O=R/'art/blender';O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
closed_collection=bpy.data.collections.new('ClosedDoorWeatherStocks');bpy.context.scene.collection.children.link(closed_collection);closed_collection.hide_render=True
materials={}
for key,color,metal,rough in [('galvanized_roof',(.35,.37,.38,1),.9,.5),('rubber_aged',(.08,.075,.07,1),0,.9)]:
 mat=bpy.data.materials.new(key);mat.use_nodes=True;shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Base Color'].default_value=color;shader.inputs['Metallic'].default_value=metal;shader.inputs['Roughness'].default_value=rough;materials[key]=mat
def blender(p):return Vector((p[0],-p[2],p[1]))
def game(p):return Vector((p.x,p.z,-p.y))
# Reuse the same checked sheet-conditioning and exact field-splitting function,
# without evaluating its builder or loading/writing another assembly.
helper_path=R/'art/blender/scripts/build_roof_drainage_plant_weather.py';tree=ast.parse(helper_path.read_text());functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='piece'];exec(compile(ast.Module(body=functions,type_ignores=[]),str(helper_path),'exec'))
stocks=[];groups=collections.defaultdict(list);specs=[];feet=[]
def prism(name,rings,key,owner,follow=None,omit=()):
 n=len(rings[0]);vertices=rings[0]+rings[1];faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return piece(name,vertices,faces,key,owner,follow,omit)
def box(name,low,high,key,owner,omit=()):
 a,y,b=low;c,t,d=high;return prism(name,[[[a,y,b],[c,y,b],[c,y,d],[a,y,d]],[[a,t,b],[c,t,b],[c,t,d],[a,t,d]]],key,owner,omit=omit)
for door in roof.field['door_fittings']:
 ident=door['id'];a,b,c,d=door['curb_rect'];top=door['candidate_curb_top'];x,z=door['source_record']['center'];width=door['source_record']['width'];face=x-.07
 cap=box(ident+'__ThresholdCap',[a,top-.004,b],[c,top,d],'galvanized_roof',ident,omit=[0,2,4,5])
 runs=[('West',(a,b),(a,d),(-1,0,0),True,True),('South',(a,b),(face,b),(0,0,-1),True,False),('North',(a,d),(face,d),(0,0,1),True,False)]
 profile=[(0,top-.004),(0,top),(.0012,top),(.0012,19.2012),(.04,19.2012),(.04,19.2),(0,19.2)];follow=[0,0,0,1,1,1,1]
 for side,start,end,normal,first,last in runs:
  base=Vector((start[0],0,start[1]));tangent=Vector((end[0]-start[0],0,end[1]-start[1])).normalized();normal=Vector(normal);length=(Vector((end[0],0,end[1]))-base).length
  rings=[]
  for along,corner,sign in [(0,first,-1),(length,last,1)]:
   # West and opposite end have opposed interior miter handedness.
   ring=[]
   for u,h in profile:
    shift=0
    if corner:
     if side=='West':shift=sign*u
     else:shift=-u
    p=base+tangent*(along+shift)+normal*u+Vector((0,h,0));ring.append(list(p))
   rings.append(ring)
  stock=prism(ident+'__Pan_'+side,rings,'galvanized_roof',ident,follow*2,omit=[2,7,8]+([0] if first else [])+([1] if last else []))
  mid=base+tangent*(length/2)+normal*.025;feet.append({'id':ident,'side':side,'point':[mid.x,roof.height(mid.x,mid.z)+.0012,mid.z]})
 # Leaf-local export, with a separate exact moving owner. The runtime applies
 # the existing hinge setback once. 4 mm blade toe seats at original saddle.
 moving=ident+'__Moving';box(ident+'__BottomBlade',[.01,.004,-.021],[width-.01,.034,-.019],'rubber_aged',moving)
 # The rain lip is on the original fixed sill; an outward moving strip would
 # enter the retained jamb during the hinge sweep. Its underside bears on
 # the new cap and its back meets the original 4 mm saddle front.
 fixed=ident+'__Fixed';drip_profile=[(-.07,0),(-.10,0),(-.10,.0012),(-.07,.004)]
 rings=[[[u,y,zv] for zv,y in drip_profile] for u in [.01,width-.01]];prism(ident+'__FixedRainLip',rings,'galvanized_roof',fixed,omit=[2,5])
 specs.append({'id':ident,'source_record':door['source_record'],'curb_top_y':top,'curb_rect':door['curb_rect'],'fitted_leaf_normal_offset_m':door['fitted_leaf_normal_offset_m'],'original_cap_stock_replaced':ident+'__CurbCap','cap_stock':cap.name,'weather_pan_end_x':face,'pan_foot_width_m':.04,'minimum_bottom_seal_y':.004,'bottom_seal_z':[-.021,-.019],'original_leaf_bottom_y':.010,'moving_owner':moving,'fixed_owner':fixed,'moving_parts_are_leaf_local':True})
parts=[]
for (owner,key),polygons in sorted(groups.items()):
 pivot=sum((p for polygon in polygons for p in polygon),Vector())/sum(map(len,polygons));pivot=Vector(tuple(round(float(v),3) for v in pivot));vertices=[];faces=[]
 for polygon in polygons:
  start=len(vertices);vertices.extend(p-pivot for p in polygon);faces.append(tuple(range(start,start+len(polygon))))
 mesh=bpy.data.meshes.new(owner+'__'+key);mesh.from_pydata(vertices,[],faces);mesh.update();bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000002);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000002);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
 uv=mesh.uv_layers.new(name='Metres');uv.active_render=True
 for face in mesh.polygons:
  normal=face.normal.normalized();seed=Vector((0,1,0)) if abs(normal.y)<.85 else Vector((1,0,0));u=(seed-normal*seed.dot(normal)).normalized();v=normal.cross(u).normalized()
  for loop in face.loop_indices:
   p=mesh.vertices[mesh.loops[loop].vertex_index].co;uv.data[loop].uv=(p.dot(u),p.dot(v))
 mesh.materials.append(materials[key]);obj=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(obj);obj.location=pivot;parts.append({'name':obj.name,'owner':owner,'material':key,'moving':owner.endswith('__Moving'),'fixed_leaf_local':owner.endswith('__Fixed')})
bpy.ops.outliner.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True);native=O/'roof_drainage_door_weather.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for part in parts:bpy.data.objects[part['name']].select_set(True)
hook=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportUVHandedness'];exec(compile(ast.Module(body=hook,type_ignores=[]),str(helper_path),'exec'));import io_scene_gltf2;io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=R/'game/assets/props/roof_drainage_door_weather.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
report={'evidence_class':'INERT','classification':'ADAPTATION','status':'SOURCE-GENERATED CONSTRUCTION; INDEPENDENT VALIDATION REQUIRED','native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'source_bindings':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [roof.field_path,helper_path,Path(__file__)]},'closed_stocks':stocks,'parts':parts,'door_pans':specs,'field_feet':feet,'open_work':['native exact miter and field contacts','imported UV and actual leaf/saddle fitting','full movement to original leaf-owner target and normal roof route','weather/reservoir downstream and production installation']}
for path in [O/'roof_drainage_door_weather_construction.json',R/'game/tests/fixtures/orison_roof_drainage_door_weather.json']:path.write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('SOURCE DOOR WEATHER',len(stocks),'closed stocks;',len(parts),'bounded parts')
