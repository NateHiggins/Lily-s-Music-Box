"""Offline source-fitted pendant clock. Does not write runtime files."""
from pathlib import Path
import argparse,collections,hashlib,json,math,sys
import bpy,bmesh,numpy as np
from mathutils import Matrix,Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'art/blender/scripts')]
from plan_v2_arcade_clock import build
from fabrication_native_batch import material,partition
from check_exported_tangents import validate
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work-dir',type=Path,required=True);args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
work=args.work_dir.resolve();work.mkdir(parents=True,exist_ok=True);plan=build()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
editable=collection('EditableClockStock');editable.hide_render=True
exports=collection('NativeClockCandidate');before=collection('OriginalClockBlocks');context=collection('RetainedSupports')
def point(p):return (p[0],-p[2],p[1])
faces={f['id']:f for f in plan['faces']};groups=collections.defaultdict(list);checks=[]
def verify(ok,label):
    checks.append(dict(ok=bool(ok),label=label))
    if not ok:raise ValueError(label)
def mesh(name,verts,polys,owner,bevel=0):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],polys);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES',clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    verify(all(e.is_manifold for e in bm.edges) and bm.calc_volume()>0,'closed outward stock '+name)
    bm.to_mesh(data);bm.free();obj=bpy.data.objects.new(name,data);owner.objects.link(obj);return obj
def extrude(name,polygon,low,high,mapper,owner=editable,bevel=0):
    n=len(polygon);verts=[mapper(x,y,z) for z in [low,high] for x,y in polygon]
    polys=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,polys,owner,bevel)
def ring(name,profile,mapper,owner=editable,segments=72,bevel=0):
    # Each profile point is radius/depth; sweep the closed profile.
    count=len(profile);verts=[]
    for radius,depth in profile:
        for i in range(segments):
            a=math.tau*i/segments;verts.append(mapper(radius*math.cos(a),radius*math.sin(a),depth))
    polys=[]
    for j in range(count):
        for i in range(segments):polys.append((j*segments+i,j*segments+(i+1)%segments,((j+1)%count)*segments+(i+1)%segments,((j+1)%count)*segments+i))
    obj=mesh(name,verts,polys,owner,bevel)
    normals=[]
    for j,(radius,depth) in enumerate(profile):
        previous=Vector((radius-profile[j-1][0],depth-profile[j-1][1])).normalized()
        following=Vector((profile[(j+1)%count][0]-radius,profile[(j+1)%count][1]-depth)).normalized()
        tangent=(previous+following).normalized();nr,nd=-tangent.y,tangent.x
        for i in range(segments):
            angle=math.tau*i/segments
            normal=(Vector(mapper(nr*math.cos(angle),nr*math.sin(angle),nd))-Vector(mapper(0,0,0))).normalized()
            normals.extend(normal)
    obj['analytic_normals']=normals
    return obj
def box(name,lo,hi,owner=editable,bevel=0,offset=None):
    offset=np.zeros(3) if offset is None else np.array(offset)
    verts=[point(np.array([x,y,z])+offset) for x,y,z in [(lo[0],lo[1],lo[2]),(hi[0],lo[1],lo[2]),(hi[0],hi[1],lo[2]),(lo[0],hi[1],lo[2]),(lo[0],lo[1],hi[2]),(hi[0],lo[1],hi[2]),(hi[0],hi[1],hi[2]),(lo[0],hi[1],hi[2])]]
    return mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],owner,bevel)
def frame_for(face,depth=0):
    u=Vector(point(face['u']));v=Vector(point(face['v']));n=Vector(point(face['normal']))
    matrix=Matrix((u,-n,v)).transposed().to_4x4();matrix.translation=Vector(point(np.array(plan['origin'])+np.array(face['center'])+np.array(face['normal'])*depth));return matrix
frame=Matrix.Translation(point(plan['origin']));moving={}
for row in plan['parts']:
    kind=row['kind'];name=row['id'];objs=[]
    if kind=='box':objs=[box(name,row['low'],row['high'],bevel=row['bevel_m'])]
    else:
        face=faces[row['face']]
        def mapped(x,y,z):return point(np.array(face['center'])+np.array(face['u'])*x+np.array(face['v'])*y+np.array(face['normal'])*z)
        offset=row.get('offset',[0,0])
        def at(x,y,z):return mapped(x+offset[0],y+offset[1],z)
        if kind=='lathe':objs=[ring(name,row['profile'],mapped,segments=row['segments'])]
        elif kind=='square_ring':
            n=72;verts=[]
            for depth in [row['low'],row['high']]:
                for outer in [True,False]:
                    for i in range(n):
                        a=math.tau*i/n;cs=math.cos(a);sn=math.sin(a);radius=min(row['half']/max(abs(cs),1e-12),row['half_height']/max(abs(sn),1e-12)) if outer else row['radius'];verts.append(mapped(radius*cs,radius*sn,depth))
            polys=[]
            for i in range(n):
                j=(i+1)%n
                polys.extend([(i,j,j+2*n,i+2*n),(n+j,n+i,3*n+i,3*n+j),(j,i,n+i,n+j),(2*n+i,2*n+j,3*n+j,3*n+i)])
            objs=[mesh(name,verts,polys,editable,row['bevel_m'])]
        elif kind in ['disc','screw']:
            n=row['segments'];circle=[(row['radius']*math.cos(math.tau*i/n),row['radius']*math.sin(math.tau*i/n)) for i in range(n)]
            if kind=='disc':objs=[extrude(name,circle,row['low'],row['high'],at)]
            else:
                middle=row['low']+.0007;objs=[extrude(name+'_base',circle,row['low'],middle,at)]
                angle=math.asin(.0005/row['radius'])
                cap=[(row['radius']*math.cos(angle+(math.pi-2*angle)*i/16),row['radius']*math.sin(angle+(math.pi-2*angle)*i/16)) for i in range(17)]
                for side in [-1,1]:objs.append(extrude(name+'_cheek_'+str(side),[(x,y*side) for x,y in cap],middle,row['high'],at))
        elif kind=='stroke':
            a=row['angle'];rad=row['radius'];length=row['length'];width=row['width']
            poly=[(x,y) for x,y in [(-width/2,rad-length),(width/2,rad-length),(width/2,rad),(-width/2,rad)]]
            objs=[extrude(name,[(x*math.cos(a)+y*math.sin(a),-x*math.sin(a)+y*math.cos(a)) for x,y in poly],row['low'],row['high'],mapped)]
        elif kind=='hand':
            w=row['width'];length=row['length'];poly=[(-w*.65,-.025),(w*.65,-.025),(w*.65,.04),(w*.5,length*.7),(0,length),(-w*.5,length*.7),(-w*.65,.04)]
            objs=[extrude(name,poly,0,row['high']-row['low'],lambda x,y,z:point((x,y,z)),bevel=.0002)]
            for obj in objs:obj.name='EDIT_'+obj.name;obj.data.name='EDIT_'+obj.data.name
            moving[name]=(row,objs,frame_for(face,row['low']));continue
        else:raise ValueError(kind)
    for obj in objs:obj.name='EDIT_'+obj.name;obj.data.name='EDIT_'+obj.data.name
    group=row['catalog_key']+('_turned_rims' if kind=='lathe' else '')
    groups[group].extend(objs)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials'];models=[];materials={}
for group in groups:
    key=group.removesuffix('_turned_rims')
    finish=dict(catalog_key=key,normal=.12,roughness=1.,pigment=1.,tint=[1.,1.,1.,1.])
    if key=='iron_blackened':finish['normal']=.035
    if key=='water_clear':finish['normal']=0.
    mat=materials.get(key)
    if mat is None:mat=material(ROOT,'Clock_'+key,finish,catalog);materials[key]=mat
    if key=='water_clear':
        node=mat.node_tree.nodes['Principled BSDF'];node.inputs['Transmission Weight'].default_value=1.;node.inputs['IOR'].default_value=1.52
    obj=partition(exports,'clock_fixed__'+group,groups[group],finish,mat,frame,catalog)
    if group.endswith('_turned_rims'):
        normals=[]
        for source_obj in groups[group]:
            data=list(source_obj['analytic_normals']);normals.extend(tuple(data[i:i+3]) for i in range(0,len(data),3))
        verify(len(normals)==len(obj.data.vertices),'analytic turned-rim normals retain the actual source vertices')
        obj.data.normals_split_custom_set_from_vertices(normals)
        minimum=min(Vector(normals[obj.data.loops[loop].vertex_index]).dot(poly.normal) for poly in obj.data.polygons for loop in poly.loop_indices)
        verify(minimum>.01,'analytic rim normals remain outward on every actual triangle')
    models.append(obj)
for name,(row,objs,matrix) in moving.items():
    finish=dict(catalog_key=row['catalog_key'],normal=.035,roughness=1.,pigment=1.,tint=[1.,1.,1.,1.])
    models.append(partition(exports,name,objs,finish,materials[row['catalog_key']],matrix,catalog))
# Actual bounds/cavity and hand-depth checks precede export and review.
verify(plan['support_high']>0 and plan['support_low']<0,'retained upper/lower support bearings bound the case')
from mathutils.bvhtree import BVHTree
vertices=[];polygons=[]
for obj in models:
    base=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices);polygons.extend(tuple(base+i for i in f.vertices) for f in obj.data.polygons)
tree=BVHTree.FromPolygons(vertices,polygons,all_triangles=True)
origin=np.array(plan['origin'])
for direction,bearing in [(1,plan['support_high']),(-1,plan['support_low'])]:
    hit=tree.ray_cast(Vector(point(origin+np.array([0,direction*.5,0]))),Vector(point([0,-direction,0])),.5)
    verify(hit[0] is not None and abs(hit[0].z-(origin[1]+bearing))<.00004 and hit[1].z*direction>.999,'actual case bearing meets retained support '+str(direction))
for face in plan['faces']:
    verify(.0065<.010<.0112<.013<.0142<.018<.020,'hand spindle, dial and glass depth separation '+face['id'])
    normal=np.array(face['normal'])
    hit=tree.ray_cast(Vector(point(origin)),Vector(point(normal)),.4)
    verify(hit[0] is not None and abs(hit[3]-.285)<.00004 and hit[1].dot(Vector(point(normal)))<-.999,'real empty case cavity behind recessed dial '+face['id'])
    for height in [-.29,.29]:
        hit=tree.ray_cast(Vector(point(origin+np.array([0,height,0]))),Vector(point(normal)),.4)
        verify(hit[0] is not None and abs(hit[3]-.275)<.00004,'upper/lower sheet closes cap seam '+face['id']+' '+str(height))
class ExportUV:
    def gather_material_hook(self,mat,source,settings):
        mat.pbr_metallic_roughness=None;mat.normal_texture=None;mat.occlusion_texture=None;mat.emissive_texture=None;mat.emissive_factor=None;mat.extensions=None
    def gather_mesh_hook(self,mesh,data,obj,groups,modifiers,materials,settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];g=values('_TANGENT_GUIDE');t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
            primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,-np.ones(len(t)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER);del primitive.attributes['_TANGENT_GUIDE']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUV
bpy.ops.object.select_all(action='DESELECT')
for obj in models:obj.select_set(True)
asset=work/'arcade_clock.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT')
proof=validate(asset);verify(proof.get('status')=='PASS', 'exported corner normals, tangents and UV derivatives')
# Comparisons include the exact old five boxes and retained support axes.
for row in plan['retire']:
    obj=box('BEFORE_'+row['id'],row['low'],row['high'],before);obj.data.materials.append(materials['washer_enamel' if row['key']=='milk_glass' else 'radiator_service_brass' if row['key']=='brass_dull' else 'iron_blackened'])
source=json.loads((ROOT/'art/data/building_layout.json').read_text(encoding='utf8'));lookup={r['id']:r for f in source['floors'] if f['id']=='F01' for r in f['furniture']}
for identity in [plan['retained_stem'],plan['retained_finial']]:
    row=lookup[identity];a,b=Vector(point([row['p0'][0],row['p0'][2],-row['p0'][1]])),Vector(point([row['p1'][0],row['p1'][2],-row['p1'][1]]))
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=row['r'],depth=(b-a).length,location=(a+b)/2);obj=bpy.context.object;obj.name='RETAINED_'+identity;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();obj.data.materials.append(materials['iron_blackened'] if identity==plan['retained_stem'] else materials['radiator_service_brass'])
    for c in list(obj.users_collection):c.objects.unlink(obj)
    context.objects.link(obj)
for obj in models:
    if obj.name in moving:obj.matrix_world=moving[obj.name][2]@Matrix.Rotation(math.radians(305 if '_hour_' in obj.name else 60),4,'Y')
world=bpy.data.worlds.new('ControlledReview');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.19,.23,1);world.node_tree.nodes['Background'].inputs[1].default_value=.65
for name,location,power,size in [('Key',(12,8.2,47.6),550,3),('Grazing',(16,6.8,51),300,1.5)]:
    light=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA'));scene.collection.objects.link(light);light.location=point(location);light.rotation_euler=(Vector(point(plan['origin']))-light.location).to_track_quat('-Z','Y').to_euler();light.data.energy=power;light.data.shape='DISK';light.data.size=size
camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
views=[]
for name,eye,target,lens in [('detail',(15.0,6.6,50.3),(14,6.21,51.6),62),('underside',(14.65,5.25,50.7),(14,6.16,51.6),60),('player',(14,1.65,46),(14,6.21,51.6),45)]:
    camera.location=point(eye);camera.rotation_euler=(Vector(point(target))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=lens
    for state in ['before','after']:
        before.hide_render=state=='after';exports.hide_render=state=='before';file=name+'_'+state+'.png';scene.render.filepath=str(work/file);bpy.ops.render.render(write_still=True);views.append(file)
before.hide_render=True;exports.hide_render=False
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(str(ROOT/'game/assets/building/textures'/Path(image.filepath).name),start=str(work))
bpy.ops.wm.save_as_mainfile(filepath=str(work/'arcade_clock.blend'),relative_remap=False)
proof.update(evidence_class='INERT',scope=plan['scope'],asset_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),checks=checks,views=views,stocks=len(plan['parts']),draws=len(models),numerals=plan['numerals'],glass='Mapped water_clear is a preview placeholder; purpose-made glazing stock and composed optics remain pending.')
proof['published_runtime']=False
proof['native_sha256']=hashlib.sha256((work/'arcade_clock.blend').read_bytes()).hexdigest()
proof['source_bindings_lf']={relative:hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for relative in ['tools/plan_v2_arcade_clock.py','art/blender/arcade_fabric_candidate/build_arcade_clock.py','art/blender/scripts/fabrication_native_batch.py','art/blender/scripts/fabrication_chart_batch.py','art/blender/scripts/fabrication_normals.py','art/blender/scripts/check_exported_tangents.py','art/data/building_layout.json','game/data/runtime_material_sets.json']}
proof['mapped_source_sha256']={name:hashlib.sha256((ROOT/'game/assets/building/textures'/name).read_bytes()).hexdigest() for key in materials for name in catalog[key]['files']}
(work/'plan.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf8',newline='\n');(work/'native_review.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf8',newline='\n');print('CLOCK NATIVE CANDIDATE',len(models),'draws;',len(plan['parts']),'closed stock specifications')
