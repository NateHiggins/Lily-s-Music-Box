"""Right-facing V2 play-pipe: native socket and four source-fact hose poses.
The inlet datum stays fixed. Straight hose insertion bears on a real annular
socket shoulder; a visual180degree turn never twists/repositions the hose end.
"""
from pathlib import Path
import hashlib,json,math,os,shutil,sys
import bpy,bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('ORISON_FIRE_NOZZLE_OUT',str(ROOT/'tmp/v2-fire-hand-20261019/nozzle_native1'))).resolve()
assert OUT.is_relative_to(ROOT/'tmp')
for directory in ['art/blender','game/assets/props']:(OUT/directory).mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material,partition,export
from check_exported_tangents import validate
if os.environ.get('ORISON_FIRE_NOZZLE_PUBLISH')=='1':
    report=json.loads((OUT/'construction.json').read_text())
    for path,digest in report['source_bindings'].items():
        source_path=ROOT/path;raw=source_path.read_bytes()
        assert hashlib.sha256(raw.replace(b'\r\n',b'\n') if source_path.suffix in ['.py','.json'] else raw).hexdigest()==digest,path
    source=OUT/'game/assets/props/fire_nozzle_hose.glb';blend=OUT/'art/blender/fire_nozzle_hose.blend'
    assert hashlib.sha256(source.read_bytes()).hexdigest()==report['glb_sha256']
    assert hashlib.sha256(blend.read_bytes()).hexdigest()==report['blend_sha256'];validate(source)
    bpy.ops.wm.open_mainfile(filepath=str(blend));bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_nozzle_hose.blend'))
    bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/fire_nozzle_hose.blend'))
    report['candidate_blend_sha256']=report['blend_sha256'];report['blend_sha256']=hashlib.sha256((ROOT/'art/blender/fire_nozzle_hose.blend').read_bytes()).hexdigest()
    shutil.copyfile(source,ROOT/'game/assets/props/fire_nozzle_hose.glb')
    (ROOT/'art/blender/fire_nozzle_hose_construction.json').write_text(json.dumps(report,indent=2)+'\n')
    print('FIRE NOZZLE PUBLISH PASS');raise SystemExit(0)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
def b(p):return Vector((p[0],-p[2],p[1]))
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
finishes={'Linen':dict(catalog_key='linen',tint=[.75,.71,.59,1],pigment=1.,normal=.08,roughness=.9,metallic=0.),'Brass':dict(catalog_key='radiator_service_brass',tint=[.9,.82,.63,1],pigment=1.,normal=.15,roughness=.8,metallic=.92)}
mats={k:material(ROOT,k,f,catalog) for k,f in finishes.items()}
native=bpy.data.collections.new('Editable nozzle and hose');bpy.context.scene.collection.children.link(native)
exports=bpy.data.collections.new('FireNozzleHose');bpy.context.scene.collection.children.link(exports)
proofs={};source_objects={}
def stock(name,vertices,faces,key):
    mesh=bpy.data.meshes.new(name+'_Source');mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True)
    assert bad==0 and volume>0,(name,bad,volume)
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name+'_Editable',mesh);native.objects.link(obj);source_objects[name]=obj
    result=partition(exports,name,[obj],finishes[key],mats[key],Matrix.Identity(4),catalog)
    proofs[name]=dict(nonmanifold_edges=bad,volume_m3=volume,triangles=len(result.data.polygons))
    return result
N=64
def connect(rings):
    faces=[]
    for row in range(rings):
        for j in range(N):faces.append((row*N+j,((row+1)%rings)*N+j,((row+1)%rings)*N+(j+1)%N,row*N+(j+1)%N))
    return faces
# Local origin is the retained source F060 draw,12mm behind nozzle origin.
profile=[(-.016,.028),(.012,.028),(.012,.012),(0,.012),(0,.02125),(-.016,.02125)]
vertices=[b((r*math.cos(j*math.tau/N),y,r*math.sin(j*math.tau/N))) for y,r in profile for j in range(N)]
adapter=stock('NozzleSocket',vertices,connect(len(profile)),'Brass')
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_service.blend'),link=False) as (available,loaded):loaded.objects=['F059']
body=loaded.objects[0];assert body is not None
bpy.context.collection.objects.link(body);body.hide_render=True
def tree(obj,frame=Matrix.Identity(4)):
    return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],[list(f.vertices) for f in obj.data.polygons])
poses={};review=[]
for fresh in [False,True]:
    shift=.01475 if fresh else 0.;drop=.004 if fresh else 0.
    for coupled in [False,True]:
        old=2.42 if coupled else 1.5708;angle=old+math.pi
        original=Vector((.045,.205,.120) if coupled else (-.060,.068,.112))
        end=original+Matrix.Rotation(old,3,'Z')@Vector((0,-.012,0))
        axis=Matrix.Rotation(angle,3,'Z')@Vector((0,1,0))
        pivot=end-Matrix.Rotation(angle,3,'Z')@Vector((0,-.012,0))
        start=Vector((-.265+shift,.119-drop,.100));entry=end-axis*.025
        a=start;c1=start+Vector((0,-.09,.02));c2=entry-axis*.05
        points=[(1-t)**3*a+3*(1-t)**2*t*c1+3*(1-t)*t*t*c2+t**3*entry for t in [i/64 for i in range(65)]]
        points.extend(entry+(end-entry)*i/8 for i in range(1,9))
        vertices=[]
        for inner in [False,True]:
            radius=.01905 if inner else .021
            for i,point in enumerate(points):
                tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
                radial=tangent.cross(Vector((0,0,1))).normalized();other=radial.cross(tangent).normalized()
                for j in range(N):vertices.append(b(point+radius*(radial*math.cos(j*math.tau/N)+other*math.sin(j*math.tau/N))))
        faces=[];count=len(points)
        for inner in range(2):
            off=inner*count*N
            for i in range(count-1):
                for j in range(N):
                    face=(off+i*N+j,off+(i+1)*N+j,off+(i+1)*N+(j+1)%N,off+i*N+(j+1)%N)
                    faces.append(tuple(reversed(face)) if inner else face)
        for row in [0,count-1]:
            for j in range(N):faces.append((row*N+j,row*N+(j+1)%N,count*N+row*N+(j+1)%N,count*N+row*N+j))
        name='HoseTail%d%d'%(fresh,coupled);draw=stock(name,vertices,faces,'Linen')
        frame=Matrix.Translation(b(end))@Matrix.Rotation(-angle,4,'Y')
        hose_tree=tree(source_objects[name]);socket_tree=tree(source_objects['NozzleSocket'],frame)
        contact=0
        for i,j in hose_tree.overlap(socket_tree):
            hv=[source_objects[name].data.vertices[k].co for k in source_objects[name].data.polygons[i].vertices]
            sv=[frame@source_objects['NozzleSocket'].data.vertices[k].co for k in source_objects['NozzleSocket'].data.polygons[j].vertices]
            h=[(v-b(end)).dot(b(axis)) for v in hv];s=[(v-b(end)).dot(b(axis)) for v in sv]
            assert max(h)<1e-7 and min(s)>-1e-7,(name,'hose/socket crossing',i,j,h,s)
            contact+=1
        body_frame=Matrix.Translation(b(pivot+Matrix.Rotation(angle,3,'Z')@Vector((0,.085,0))))@Matrix.Rotation(-angle,4,'Y')
        assert not hose_tree.overlap(tree(body,body_frame)),(name,'hose/nozzle-body crossing')
        assert contact>0,(name,'missing socket shoulder bearing')
        proofs[name]['socket_contact_pairs']=contact
        proofs[name]['body_intersections']=0
        poses[name]=dict(pivot=list(pivot),angle=angle,inlet=list(end),axis=list(axis))
        if not fresh and not coupled:review=[draw,frame,body_frame]
native.hide_render=True;native.hide_viewport=True
for obj in exports.objects:obj.hide_render=True
review[0].hide_render=False
copy=adapter.copy();copy.hide_render=False;copy.matrix_world=review[1];bpy.context.collection.objects.link(copy)
body.matrix_world=review[2];body.hide_render=False;body.data.materials.clear();body.data.materials.append(mats['Brass'])
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1100;scene.render.resolution_y=750;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Nozzle neutral review');scene.world.color=(.18,.18,.18)
for at,energy in [((0,-.4,.5),10),((-.3,.2,.3),6)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=energy;light.data.size=.4
    light.rotation_euler=(Vector((-.06,-.10,.09))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.20,-.60,.40));scene.camera=bpy.context.object;scene.camera.data.lens=55
scene.camera.rotation_euler=(Vector((-.06,-.10,.09))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'native_nozzle.png');bpy.ops.render.render(write_still=True)
bpy.data.objects.remove(copy,do_unlink=True);bpy.data.objects.remove(body,do_unlink=True)
for obj in exports.objects:obj.hide_render=False
result=export(OUT,'fire_nozzle_hose',exports,material_names_only=True)
paths=[Path(__file__).resolve(),ROOT/'art/blender/scripts/fabrication_native_batch.py',ROOT/'art/blender/scripts/fabrication_chart_batch.py',ROOT/'art/blender/scripts/fabrication_normals.py',ROOT/'art/blender/fire_service.blend',ROOT/'game/data/runtime_material_sets.json']
bindings={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n') if p.suffix in ['.py','.json'] else p.read_bytes()).hexdigest() for p in paths}
report=dict(evidence_class='INERT',scope='Right-facing nozzle native stock and clearance only; no runtime/human acceptance.',source_bindings=bindings,parts=proofs,poses=poses,export=result,glb_sha256=hashlib.sha256((OUT/'game/assets/props/fire_nozzle_hose.glb').read_bytes()).hexdigest(),blend_sha256=hashlib.sha256((OUT/'art/blender/fire_nozzle_hose.blend').read_bytes()).hexdigest())
(OUT/'construction.json').write_text(json.dumps(report,indent=2)+'\n')
print('FIRE NOZZLE NATIVE PASS',json.dumps(proofs))
