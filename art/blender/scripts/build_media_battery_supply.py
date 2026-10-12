"""Eight source-fitted receiver battery trays and four-conductor supply looms."""
from pathlib import Path
import ast,json,math,hashlib,sys
import numpy as np
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-media-battery-20261012';OUT.mkdir(parents=True,exist_ok=True)
plan=json.loads((ROOT/'art/data/media_battery_supply/source_plan.json').read_text(encoding='utf-8'))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
keys=['oak_quartered','rubber_aged','paper','brass_dull','bakelite_black','linen','iron_neutral']
materials={k:bpy.data.materials.new(k) for k in keys}
for mat in materials.values():mat.use_nodes=True
for filename,names in [('build_electrical_service.py',{'point','cube','cylinder','cut','ring','finish'}),('build_media_ac_supply.py',{'finished','rounded','flex'})]:
    path=Path(__file__).with_name(filename);tree=ast.parse(path.read_text(encoding='utf-8'))
    exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),str(path),'exec'))
parts=[]
def stock(name,objects,key,bevel=.0004):
    obj=finished(name,objects,key,bevel);parts.append({'name':name,'material':key});return obj
# Shared separate stocks, all authored at their actual floor bearing datum.
stock('BatteryTray',[cube((.41,.014,.25),(0,.007,0)),cube((.012,.035,.25),(-.199,.0315,0)),cube((.012,.035,.25),(.199,.0315,0)),cube((.386,.035,.012),(0,.0315,-.119)),cube((.386,.035,.012),(0,.0315,.119))],'oak_quartered')
case=cube((.17,.185,.18),(-.105,.1065,0));cut(case,cube((.154,.176,.164),(-.105,.120,0)))
stock('FilamentBatteryCase',[case,cube((.17,.008,.18),(-.105,.203,0))],'rubber_aged')
stock('FilamentBatteryCaps',[cylinder(.013,.008,(-.105,.211,z)) for z in [-.053,0,.053]],'bakelite_black')
stock('PlateBatteryWrapper',[cube((.17,.145,.18),(.085,.0865,0))],'paper',.001)
stock('PlateBatteryTop',[cube((.17,.008,.18),(.085,.163,0))],'bakelite_black')
terminals=[[-.15,.219,.04],[-.06,.219,.04],[.04,.179,.04],[.13,.179,.04]]
stock('BatteryBindingPosts',[cylinder(.004,.024,(p[0],p[1]-.012,p[2])) for p in terminals]+[cylinder(.008,.006,(p[0],p[1]-.005,p[2])) for p in terminals],'brass_dull')
stock('BatteryHandles',[cube((.075,.010,.014),(-.105,.220,-.075)),cube((.012,.016,.014),(-.142,.213,-.075)),cube((.012,.016,.014),(-.068,.213,-.075))],'iron_neutral')
shared=parts[:];installations=[];routes=[]
for row in plan['installations']:
    parts=[];identity=row['id'];pos=Vector(row['position']);w,h,d=row['dimensions'];back=d/2-.025
    y=pos.y+h;z=pos.z+back
    stock(identity+'_TerminalStrip',[cube((.094,.006,.026),(pos.x,y+.003,z))],'bakelite_black')
    posts=[]
    for i,x in enumerate([-.03,-.01,.01,.03]):
        posts.extend([cylinder(.002,.030,(pos.x+x,y+.005,z)),cylinder(.005,.006,(pos.x+x,y+.014,z))])
    stock(identity+'_TerminalPosts',posts,'brass_dull')
    wire_names=[]
    for i,x in enumerate([-.03,-.01,.01,.03]):
        start=[pos.x+x,y+.014,z+.004];fall=pos.x+(i-1.5)*.005
        end=terminals[i]
        knots=[start,[pos.x+x,y+.014,.249+i*.004],[fall,.770,.249+i*.004],[fall,.680,.249+i*.004],[fall,.665,.200+i*.004],[fall,.610,.200+i*.004],[fall,.300,.200+i*.004],[end[0],end[1]+.035,end[2]],[end[0],end[1]-.004,end[2]]]
        path=rounded(knots);name=identity+'_Lead'+str(i);obj,length=flex(name,path,.0015)
        parts.append({'name':name,'material':'linen'});wire_names.append(name)
        routes.append({'id':identity,'wire':i,'radius':.0015,'length':length,'centerline':[list(p) for p in path]})
    # Cut the untriangulated clip blank before joining/export triangulation.
    # Cutting already triangulated stock creates near-collinear UV slivers.
    bridge=cube((.025,.007,.023),(pos.x,.640,.206))
    for i in range(4):cut(bridge,cylinder(.0016,.020,(pos.x+(i-1.5)*.005,.640,.200+i*.004)))
    stock(identity+'_LoomClip',[cube((.027,.004,.030),(pos.x,.698,.206)),bridge,cylinder(.0025,.053,(pos.x,.6715,.216))],'iron_neutral')
    installations.append({'id':identity,'support':row['support'],'parts':parts})
stats=[]
for obj in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    # Booleans added after finish need fresh charts and triangles.
    if obj.name.endswith('_LoomClip'):
        bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Clip bore triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        uv=obj.data.uv_layers.active
        for f in obj.data.polygons:
            axis=max(range(3),key=lambda i:abs(f.normal[i]));a,b=[(1,2),(0,2),(0,1)][axis]
            for loop in f.loop_indices:
                p=obj.data.vertices[obj.data.loops[loop].vertex_index].co;uv.data[loop].uv=(p[a],p[b])
    for face in obj.data.polygons:face.use_smooth=False
    bm=bmesh.new();bm.from_mesh(obj.data);closed=all(e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    uv=obj.data.uv_layers.active;bad=0
    for f in obj.data.polygons:
        q=[Vector(uv.data[i].uv) for i in f.loop_indices]
        if abs((q[1]-q[0]).cross(q[2]-q[0]))<=1e-12:bad+=1
    assert closed and volume>0 and bad==0,(obj.name,closed,volume,bad)
    stats.append({'name':obj.name,'volume':volume,'triangles':len(obj.data.polygons),'collapsed_uv':bad})
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/media_battery_supply.blend'))
asset=ROOT/'game/assets/props/media_battery_supply.glb'
class ExportDerivatives:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def array(key,width):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,width)).astype(float)
            p=array('POSITION',3);n=array('NORMAL',3);uv=array('TEXCOORD_0',2)
            ids=np.frombuffer(primitive.indices.buffer_view.data,dtype={5121:'u1',5123:'<u2',5125:'<u4'}[primitive.indices.component_type]).reshape((-1,3))
            a=uv[ids[:,1]]-uv[ids[:,0]];b=uv[ids[:,2]]-uv[ids[:,0]];det=a[:,0]*b[:,1]-a[:,1]*b[:,0]
            assert np.all(abs(det)>1e-12),(mesh.name,'export UV collapse')
            du=((p[ids[:,1]]-p[ids[:,0]])*b[:,1,None]-(p[ids[:,2]]-p[ids[:,0]])*a[:,1,None])/det[:,None]
            dv=((p[ids[:,2]]-p[ids[:,0]])*a[:,0,None]-(p[ids[:,1]]-p[ids[:,0]])*b[:,0,None])/det[:,None]
            normals=n[ids];t=du[:,None,:]-normals*np.sum(du[:,None,:]*normals,axis=2)[:,:,None];t/=np.linalg.norm(t,axis=2)[:,:,None]
            signs=np.sign(np.sum(np.cross(normals,t)*dv[:,None,:],axis=2));assert np.all(signs!=0)
            result=np.zeros((len(p),4));result[ids.ravel(),:3]=t.reshape((-1,3));result[ids.ravel(),3]=signs.ravel()
            if '_TANGENT_GUIDE' in primitive.attributes:del primitive.attributes['_TANGENT_GUIDE']
            primitive.attributes['TANGENT'].buffer_view=BinaryData(result.astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportDerivatives
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',export_apply=True,export_tangents=True,export_lights=False,export_cameras=False)
sys.path.insert(0,str(Path(__file__).parent))
from check_exported_tangents import validate
export_check=validate(asset)
(ROOT/'game/data/orison_v2/media_battery_supply.json').write_text(json.dumps({'schema_version':1,'asset':'res://assets/props/media_battery_supply.glb','shared':shared,'installations':installations},indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'construction.json').write_text(json.dumps({'evidence_class':'INERT','asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'parts':stats,'routes':routes,'exported_tangents':export_check,'scope':'Native construction only. Furniture/case fit, rendered review and runtime proof remain required.'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('BATTERY SUPPLY:',len(installations),'installations;',len(stats),'parts')
