"""Native hollow linen stock for continuously moving fire-hose fittings.
Metre charts, open bores, signed tangents and catalogue-only GLB materials.
"""
from pathlib import Path
import bpy,bmesh,hashlib,json,math,os,shutil,struct,sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_HOSE_OUT',str(R/'tmp/v2-fire-hand-20261019/hose_native1')))
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(R/'art/blender/scripts'))
from fabrication_native_batch import material
from check_exported_tangents import validate
if os.environ.get('ORISON_FIRE_HOSE_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for path,digest in report['source_bindings'].items():
        assert hashlib.sha256((R/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==digest,path
    assert hashlib.sha256((OUT/'fire_hose_stock.glb').read_bytes()).hexdigest()==report['export']['sha256']
    assert hashlib.sha256((OUT/'fire_hose_stock.blend').read_bytes()).hexdigest()==report['blend_sha256']
    validate(OUT/'fire_hose_stock.glb')
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'fire_hose_stock.blend'))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(R/'art/blender/fire_hose_stock.blend'))
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(R/'art/blender/fire_hose_stock.blend'))
    report['candidate_blend_sha256']=report['blend_sha256']
    report['blend_sha256']=hashlib.sha256((R/'art/blender/fire_hose_stock.blend').read_bytes()).hexdigest()
    shutil.copyfile(OUT/'fire_hose_stock.glb',R/'game/assets/props/fire_hose_stock.glb')
    shutil.copyfile(OUT/'runtime_projection.json',R/'game/data/orison_v2/fire_hose_stock.json')
    (R/'art/blender/fire_hose_stock_construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print('Published already-reviewed original stock; no geometry rebuild')
    raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((R/'game/data/runtime_material_sets.json').read_text())['materials']
finish=dict(catalog_key='linen',pigment=1.,normal=.08,roughness=.9,tint=[.75,.71,.59,1],metallic=0.)
preview=material(R,'linen',finish,catalog)
N=64;RINGS=192;OUTER=.021;INNER=.01905
def b(p):return (p[0],-p[2],p[1])
stocks=[];metrics={}
for name,length in [('OutletStock',.30),('NozzleStock',.42)]:
    vertices=[];faces=[];charts=[];kinds=[]
    def index(side,ring,j):return side*(RINGS+1)*N+ring*N+j%N
    for radius in [OUTER,INNER]:
        for ring in range(RINGS+1):
            for j in range(N):vertices.append(b((radius*math.cos(j*math.tau/N),length*ring/RINGS,radius*math.sin(j*math.tau/N))))
    def quad(ids,uv,kind):
        for ids2 in [(0,1,2),(0,2,3)]:
            faces.append(tuple(ids[i] for i in ids2));charts.append([uv[i] for i in ids2]);kinds.append(kind)
    for side,radius in enumerate([OUTER,INNER]):
        chord=2*radius*math.sin(math.pi/N)
        for ring in range(RINGS):
            for j in range(N):
                ids=[index(side,ring,j),index(side,ring+1,j),index(side,ring+1,j+1),index(side,ring,j+1)]
                uv=[(j*chord,length*ring/RINGS),(j*chord,length*(ring+1)/RINGS),((j+1)*chord,length*(ring+1)/RINGS),((j+1)*chord,length*ring/RINGS)]
                if side:ids.reverse();uv.reverse()
                quad(ids,uv,'inner' if side else 'outer')
    for ring,kind in [(0,'bottom'),(RINGS,'top')]:
        for j in range(N):
            ids=[index(0,ring,j),index(0,ring,j+1),index(1,ring,j+1),index(1,ring,j)]
            if ring:ids.reverse()
            uv=[(vertices[i][0],-vertices[i][1]) for i in ids]
            quad(ids,uv,kind)
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(preview)
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);stocks.append(obj)
    layer=mesh.uv_layers.new(name='Metres');layer.active_render=True
    normals=[]
    guides=[mesh.attributes.new(name=x,type='FLOAT_VECTOR',domain='CORNER') for x in ['_native_uv','_native_du','_native_dv']]
    maximum_metric_error=0.
    for face,uv,kind in zip(mesh.polygons,charts,kinds):
        p=np.array([mesh.vertices[i].co[:] for i in face.vertices],dtype=float)
        tex=np.asarray(uv,dtype=np.float32).astype(float);a=tex[1]-tex[0];c=tex[2]-tex[0];det=a[0]*c[1]-c[0]*a[1]
        assert abs(det)>1e-12,(name,'collapsed chart')
        du=((p[1]-p[0])*c[1]-(p[2]-p[0])*a[1])/det
        dv=((p[2]-p[0])*a[0]-(p[1]-p[0])*c[0])/det
        maximum_metric_error=max(maximum_metric_error,abs(np.linalg.norm(du)-1),abs(np.linalg.norm(dv)-1),abs(np.dot(du,dv)))
        for loop,uv_point,point in zip(face.loop_indices,uv,p):
            layer.data[loop].uv=uv_point
            if kind in ['top','bottom']:normal=np.array((0,0,1 if kind=='top' else -1),dtype=float)
            else:
                normal=np.array((point[0],point[1],0));normal/=np.linalg.norm(normal)
                if kind=='inner':normal=-normal
            normals.append(tuple(normal))
            # These are temporary export guides. Canonical corner directions
            # avoid splitting identical native vertices on float noise or on
            # the different face chords meeting a smooth cylindrical normal.
            tangent=du-normal*np.dot(du,normal);tangent/=np.linalg.norm(tangent)
            bitangent=dv-normal*np.dot(dv,normal);bitangent/=np.linalg.norm(bitangent)
            tangent=np.round(tangent,6);bitangent=np.round(bitangent,6)
            guides[0].data[loop].vector=(*uv_point,0)
            guides[1].data[loop].vector=(tangent[0],tangent[2],-tangent[1])
            guides[2].data[loop].vector=(-bitangent[0],-bitangent[2],bitangent[1])
    mesh.normals_split_custom_set(normals)
    bm=bmesh.new();bm.from_mesh(mesh)
    bad=sum(not edge.is_manifold for edge in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    assert bad==0 and volume>0 and maximum_metric_error<.00001,(name,bad,volume,maximum_metric_error)
    tree=BVHTree.FromObject(obj,bpy.context.evaluated_depsgraph_get())
    clear=0;bearing=0
    for j in range(17):
        angle=j*math.tau/16;radius=0 if j==16 else INNER-.0001
        origin=Vector(b((radius*math.cos(angle),-.05,radius*math.sin(angle))))
        assert tree.ray_cast(origin,Vector((0,0,1)),length+.1)[0] is None,(name,'blocked bore',j)
        clear+=1
    for j in range(16):
        angle=j*math.tau/16;radius=(INNER+OUTER)*.5
        hit=tree.ray_cast(Vector(b((radius*math.cos(angle),-.05,radius*math.sin(angle)))),Vector((0,0,1)),length+.1)
        assert hit[0] is not None and abs(hit[0].z)<.0001,(name,'annular end',j)
        bearing+=1
    metrics[name]=dict(length_m=length,outer_radius_m=OUTER,inner_radius_m=INNER,segments=RINGS,sides=N,nonmanifold_edges=bad,volume_m3=volume,maximum_metric_error=maximum_metric_error,triangles=len(mesh.polygons),clear_bore_rays=clear,end_bearing_rays=bearing)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'fire_hose_stock.blend'))
# Review instances are excluded from the exported source library.
copies=[]
for i,obj in enumerate(stocks):
    obj.hide_render=True;copy=obj.copy();copy.location.x=(i-.5)*.12;copy.hide_render=False;bpy.context.collection.objects.link(copy);copies.append(copy)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.world=bpy.data.worlds.new('Neutral stock review');scene.world.color=(.15,.15,.15)
for at,power in [((.5,-.8,.8),130),((-.5,.2,.7),80)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.size=.7;light.rotation_euler=(Vector((0,0,.21))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.48,-.68,.75));scene.camera=bpy.context.object;scene.camera.data.lens=55
scene.camera.rotation_euler=(Vector((0,0,.22))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'native_stock.png');bpy.ops.render.render(write_still=True)
preview.name='linen_native_preview'
clean=bpy.data.materials.new('linen');clean.diffuse_color=(.65,.60,.49,1)
bpy.ops.object.select_all(action='DESELECT')
for obj in stocks:obj.data.materials.clear();obj.data.materials.append(clean);obj.select_set(True);obj.hide_render=False
bpy.context.view_layer.objects.active=stocks[0]
class NativeChartExport:
    def gather_mesh_hook(self,mesh,blender_data,blender_object,vertex_groups,modifiers,materials,export_settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            uv=values('_NATIVE_UV')[:,:2];uv[:,1]*=-1
            n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None]
            du=values('_NATIVE_DU');dv=values('_NATIVE_DV');t=du-n*np.sum(du*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
            handed=np.sign(np.sum(np.cross(n,t)*dv,axis=1));assert np.all(handed!=0)
            primitive.attributes['TEXCOORD_0'].buffer_view=BinaryData(uv.astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,handed)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            for key in ['_NATIVE_UV','_NATIVE_DU','_NATIVE_DV']:del primitive.attributes[key]
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=NativeChartExport
asset=OUT/'fire_hose_stock.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True)
proof=validate(asset)
raw=asset.read_bytes();size=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+size]);assert not gltf.get('images') and not gltf.get('textures')
for mesh in gltf['meshes']:metrics[mesh['name']]['exported_vertices']=sum(gltf['accessors'][p['attributes']['POSITION']]['count'] for p in mesh['primitives'])
bindings={p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in [Path(__file__).resolve(),R/'art/blender/scripts/fabrication_native_batch.py',R/'art/blender/scripts/check_exported_tangents.py',R/'game/data/runtime_material_sets.json']}
report=dict(evidence_class='INERT',scope='Native stock/preview only, no runtime or human acceptance.',parts=metrics,source_bindings=bindings,blend_sha256=hashlib.sha256((OUT/'fire_hose_stock.blend').read_bytes()).hexdigest(),export=dict(sha256=hashlib.sha256(raw).hexdigest(),bytes=len(raw),images=0,tangents=proof))
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
projection=dict(schema_version=1,asset='res://assets/props/fire_hose_stock.glb',catalog_key='linen',stocks={name:{key:part[key] for key in ['length_m','outer_radius_m','inner_radius_m']} for name,part in metrics.items()})
(OUT/'runtime_projection.json').write_text(json.dumps(projection,indent=2)+'\n',encoding='utf8')
print('FIRE HOSE NATIVE STOCK PASS',json.dumps(metrics))
