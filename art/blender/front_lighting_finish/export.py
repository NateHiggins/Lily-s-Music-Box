"""Export retained bored cornice stock; the eye-level rail is retired."""
from pathlib import Path
import ast,hashlib,json,sys,os
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[3];OUT=Path(os.environ.get('FRONT_TRIM_EXPORT_OUT',str(ROOT/'tmp/v2-front-trim-20261019')));OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
draws=[];bindings={}
for file,names in [('front_lighting_cornice_candidate.blend',['BoredCornice_0','BoredCornice_1','BoredCornice_2'])]:
    path=ROOT/'art/blender'/file;bindings[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    with bpy.data.libraries.load(str(path),link=False) as (available,loaded):loaded.objects=names
    for obj in loaded.objects:
        bpy.context.collection.objects.link(obj);draws.append(obj)
        mesh=obj.data;mesh.calc_loop_triangles()
        positions=np.asarray([v.co[:] for v in mesh.vertices],dtype=np.float32).astype(float)
        uv=mesh.uv_layers.active;guides=[];bitangents=[];normals=[]
        for tri in mesh.loop_triangles:
            p=positions[list(tri.vertices)];n=np.cross(p[1]-p[0],p[2]-p[0]);assert np.linalg.norm(n)>1e-12
            values=np.asarray([uv.data[i].uv[:] for i in tri.loops],dtype=np.float32)
            values[:,1]=np.float32(1)-values[:,1];values=values.astype(float)
            a=values[1]-values[0];b=values[2]-values[0];det=a[0]*b[1]-a[1]*b[0];assert abs(det)>1e-12
            du=((p[1]-p[0])*b[1]-(p[2]-p[0])*a[1])/det
            dv=((p[2]-p[0])*a[0]-(p[1]-p[0])*b[0])/det
            guides.extend([du[[0,2,1]]*np.array([1,1,-1])]*3)
            bitangents.extend([dv[[0,2,1]]*np.array([1,1,-1])]*3)
            normals.extend([n/np.linalg.norm(n)]*3)
        # Every source polygon is already triangulated by its native recipe.
        assert len(guides)==len(mesh.loops)
        for name,values in [('_tangent_guide',guides),('_bitangent_guide',bitangents)]:
            attr=mesh.attributes.new(name=name,type='FLOAT_VECTOR',domain='CORNER')
            attr.data.foreach_set('vector',np.asarray(values,dtype=np.float32).ravel())
        corner=np.asarray([n.vector[:] for n in mesh.corner_normals]);robust=np.asarray(normals)
        bad=(np.linalg.norm(corner,axis=1)<.99)|~np.isfinite(corner).all(axis=1)|(np.sum(corner*robust,axis=1)<.7)
        corner[bad]=robust[bad];corner/=np.linalg.norm(corner,axis=1)[:,None]
        mesh.normals_split_custom_set(corner.tolist())
helper=ROOT/'art/blender/front_lighting_candidate/export_candidate.py'
tree=ast.parse(helper.read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='ExportUVHandedness'],type_ignores=[]),str(helper),'exec'))
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
bpy.ops.object.select_all(action='DESELECT')
for obj in draws:obj.select_set(True)
asset=OUT/'front_lighting_trim.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_tangents=True,export_attributes=True,export_materials='PLACEHOLDER')
sys.path.insert(0,str(ROOT/'art/blender/scripts'));from check_exported_tangents import validate
result=validate(asset)
expected={o.name:sum(len(p.vertices)-2 for p in o.data.polygons) for o in draws}
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(asset))
actual={o.name:len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'}
assert expected==actual,(expected,actual)
report=dict(evidence_class='INERT',scope='Three retained native cornice stocks only; export/reimport and strict tangent checks, not runtime acceptance.',
    asset_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),source_bindings=bindings,tangents=result,parts=actual,
    recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    exporter_hook_sha256_lf=hashlib.sha256(helper.read_bytes().replace(b'\r\n',b'\n')).hexdigest())
(OUT/'export.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('TRIM EXPORT:',json.dumps(result))
