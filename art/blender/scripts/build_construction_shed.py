"""Editable native construction-shed candidate, before runtime installation.

Run Blender with --work-dir <dir>. Source collision boxes and actor identities
remain separate from merged visual material partitions. Generated
glTF is exported by Blender and its final UV/tangent buffers are checked.
"""
from pathlib import Path
import argparse, collections, hashlib, itertools, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Vector, Matrix

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(Path(__file__).parent))
from plan_v2_construction_shed import build, solid_cells
from fabrication_native_batch import partition, material
from fabrication_chart_batch import triangle_charts
from fabrication_normals import stock_corner_normals
from construction_shed_uv import mirrored_triangles
from check_exported_tangents import validate

parser=argparse.ArgumentParser();parser.add_argument('--work-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);work=args.work_dir.resolve();work.mkdir(parents=True,exist_ok=True)
plan=build();origin=np.array(plan['asset_origin_m']);catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf8'))['materials']
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
source_collection=bpy.data.collections.new('RetainedCollisionEnvelope');scene.collection.children.link(source_collection);source_collection.hide_render=True
stock_collection=bpy.data.collections.new('EditableConstructionStock');scene.collection.children.link(stock_collection);stock_collection.hide_render=True
exports=bpy.data.collections.new('NativeExport');scene.collection.children.link(exports)
before=bpy.data.collections.new('OriginalVisualBoxes');scene.collection.children.link(before);before.hide_render=True

def point(p):
    a=np.array(p)-origin
    return (float(a[0]),float(-a[2]),float(a[1]))

def solid(name,vertices,faces,collection,bevel=0):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bevel:
        edges=[e for e in bm.edges if e.is_manifold and e.calc_face_angle()>math.radians(20)]
        bmesh.ops.bevel(bm,geom=edges,offset=bevel,segments=3,affect='EDGES',clamp_overlap=True)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh);bm.free();mesh.update()
    obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);return obj

def box(row,collection):
    center=np.array(row['center_m']);size=np.array(row['size_m']);low=center-size/2;high=center+size/2
    # A shared interval grid creates manifold lapped stock directly. There
    # are no nearly coincident Boolean cutters or hidden internal faces.
    axes,cells=solid_cells(row)
    vertices=[];faces=[];lookup={}
    def vertex(p):
        key=tuple(float(v) for v in p)
        if key not in lookup:
            rotated=np.array(p)-center;a=math.radians(row.get('roll_degrees',0));x,y=rotated[:2]
            rotated[0]=x*math.cos(a)-y*math.sin(a);rotated[1]=x*math.sin(a)+y*math.cos(a)
            lookup[key]=len(vertices);vertices.append(point(rotated+center))
        return lookup[key]
    for index in sorted(cells):
        a=[axes[k][index[k]] for k in range(3)];b=[axes[k][index[k]+1] for k in range(3)]
        for axis in range(3):
            for direction in [-1,1]:
                adjacent=list(index);adjacent[axis]+=direction
                if tuple(adjacent) in cells:continue
                plane=a[axis] if direction<0 else b[axis]
                if axis==0:corners=[(plane,a[1],a[2]),(plane,b[1],a[2]),(plane,b[1],b[2]),(plane,a[1],b[2])]
                elif axis==1:corners=[(a[0],plane,a[2]),(a[0],plane,b[2]),(b[0],plane,b[2]),(b[0],plane,a[2])]
                else:corners=[(a[0],a[1],plane),(b[0],a[1],plane),(b[0],b[1],plane),(a[0],b[1],plane)]
                faces.append(tuple(vertex(p) for p in (corners if direction>0 else list(reversed(corners)))))
    if not vertices:raise ValueError('empty construction stock: '+row['id'])
    return solid(row['id'],vertices,faces,collection,row.get('bevel_m',0))

def radial(name,center,axis,profile,material_key,inner=0,sides=16,hex_outer=False):
    axis=Vector(axis).normalized();seed=Vector((1,0,0)) if abs(axis.x)<.8 else Vector((0,0,1))
    u=axis.cross(seed).normalized();v=axis.cross(u).normalized();at=Vector(center)
    vertices=[];faces=[]
    for radius,distance in profile:
        for k in range(sides):
            angle=k*math.tau/sides
            r=radius*math.cos(math.pi/6)/math.cos(angle%(math.pi/3)-math.pi/6) if hex_outer else radius
            vertices.append(point(at+axis*distance+r*(u*math.cos(angle)+v*math.sin(angle))))
    for layer in range(len(profile)-1):
        for k in range(sides):
            a=layer*sides+k;b=layer*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
    if inner:
        offset=len(vertices)
        for distance in [profile[0][1],profile[-1][1]]:
            for k in range(sides):
                angle=k*math.tau/sides;vertices.append(point(at+axis*distance+inner*(u*math.cos(angle)+v*math.sin(angle))))
        for k in range(sides):
            j=(k+1)%sides;far=(len(profile)-1)*sides
            faces.extend([(k,offset+k,offset+j,j),(far+k,far+j,offset+sides+j,offset+sides+k),
                          (offset+k,offset+sides+k,offset+sides+j,offset+j)])
    else:faces.extend([tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+k for k in range(sides))])
    return solid(name,vertices,faces,stock_collection)

def thread(name,center,axis,start,end,key):
    axis=Vector(axis).normalized();seed=Vector((1,0,0)) if abs(axis.x)<.8 else Vector((0,0,1))
    u=axis.cross(seed).normalized();v=axis.cross(u).normalized();at=Vector(center)
    pitch=.00175;steps=math.ceil((end-start)/pitch*32);vertices=[];faces=[]
    for i in range(steps+1):
        distance=start+(end-start)*i/steps;angle=(distance-start)/pitch*math.tau;radial=u*math.cos(angle)+v*math.sin(angle)
        for r,offset in [(.0052,-pitch*.27),(.00595,0),(.0052,pitch*.27)]:vertices.append(point(at+axis*(distance+offset)+radial*r))
    for i in range(steps):
        for j in range(3):faces.append((i*3+j,i*3+(j+1)%3,(i+1)*3+(j+1)%3,(i+1)*3+j))
    faces.extend([(2,1,0),(steps*3,steps*3+1,steps*3+2)])
    return solid(name,vertices,faces,stock_collection)

groups=collections.defaultdict(list)
for row in plan['parts']:
    if row['kind']=='box':obj=box(row,stock_collection)
    elif row['kind']=='nail':
        # The shank meets the underside of a slightly crowned steel head.
        obj=radial(row['id'],row['center_m'],row['axis'],[(.001,-.024),(.001,0),(.0028,0),(.0028,.0008),(.00225,.0014)],row['material'])
    else:
        low,high=row['bearing_offsets_m'];end=high+.018
        obj=radial(row['id'],row['center_m'],row['axis'],[(.0055,low-.010),(.0055,end)],row['material'])
        for sign,surface in [(-1,low),(1,high)]:
            washer=radial(row['id']+f'_Washer{sign}',row['center_m'],row['axis'],[(.0115,surface),(.0115,surface+sign*.002)],row['material'],inner=.0062,sides=32)
            groups[row['material']].append(washer)
        nut=radial(row['id']+'_HexNut',row['center_m'],row['axis'],[(.011,high+.002),(.011,high+.012)],row['material'],inner=.006,sides=48,hex_outer=True);groups[row['material']].append(nut)
        head=radial(row['id']+'_Head',row['center_m'],row['axis'],[(.011,low-.012),(.011,low-.002)],row['material'],sides=24,hex_outer=True);groups[row['material']].append(head)
        groups[row['material']].append(thread(row['id']+'_Thread',row['center_m'],row['axis'],high-.001,end,row['material']))
    obj['retained_actor']=row['actor'];groups[row['material']].append(obj)

# Cut ends and notched shoulders are a separately authored end-grain stock.
# Grain follows the original timber axis, not an SVD biased by notch vertices.
wood=groups.pop('site_softwood')
rows={row['id']:row for row in plan['parts']}
for obj in wood:
    row=rows[obj.name];axis=np.zeros(3);axis[int(np.argmax(row['size_m']))]=1
    a=math.radians(row['roll_degrees']);x,y=axis[:2];axis[0]=x*math.cos(a)-y*math.sin(a);axis[1]=x*math.sin(a)+y*math.cos(a)
    direction=np.array([axis[0],-axis[2],axis[1]])
    end_faces=[];long_faces=[]
    for face in obj.data.polygons:(end_faces if abs(np.dot(face.normal,direction))>.99 else long_faces).append(tuple(face.vertices))
    for key,faces in [('site_softwood',long_faces),('site_softwood_endgrain',end_faces)]:
        if not faces:continue
        mesh=bpy.data.meshes.new(obj.name+'_'+key);mesh.from_pydata([v.co[:] for v in obj.data.vertices],[],faces);mesh.update()
        child=bpy.data.objects.new(mesh.name,mesh);stock_collection.objects.link(child);child['grain_axis']=direction.tolist();groups[key].append(child)

def wood_partition(key,objects,mat):
    vertices=[];faces=[];frames=[];phases=[]
    for obj in objects:
        direction=np.array(obj['grain_axis']);seed=np.eye(3)[np.argmin(np.abs(direction))]
        lateral=np.cross(seed,direction);lateral/=np.linalg.norm(lateral)
        rotation=np.stack((lateral,np.cross(direction,lateral),direction))
        phase=np.array([int.from_bytes(hashlib.sha256(obj.name.encode()).digest()[i:i+4],'little')/2**32 for i in [0,4]])
        offset=len(vertices);vertices.extend(v.co[:] for v in obj.data.vertices);frames.extend([rotation]*len(obj.data.vertices));phases.extend([phase]*len(obj.data.vertices))
        faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
    mesh=bpy.data.meshes.new('Shed_'+key);mesh.from_pydata(vertices,[],faces);mesh.update();mesh.materials.append(mat)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    coords=np.array([v.co[:] for v in mesh.vertices]);indices=np.array([loop.vertex_index for loop in mesh.loops]).reshape((-1,3))
    rotation=np.stack([frames[i] for i in indices[:,0]]) if key=='site_softwood' else None
    n,u,charts,_=triangle_charts(coords[indices],np.zeros(3),1.,rotation,np.ones(len(indices),dtype=bool) if rotation is not None else None)
    a=math.radians(24);axes=[[1,0,0],[0,1,0],[0,0,1],[math.cos(a),0,math.sin(a)],[-math.sin(a),0,math.cos(a)]]
    normals=np.array(stock_corner_normals(mesh,planar_axes=axes)).reshape((-1,3,3))
    v=np.cross(n,u)
    charts=np.stack((np.einsum('nkj,nj->nk',coords[indices],u),np.einsum('nkj,nj->nk',coords[indices],v)),axis=2)
    charts+=np.stack([phases[i] for i in indices[:,0]])[:,None,:]
    points,charts,normals,guides,signs=mirrored_triangles(coords[indices],charts,normals,u)
    folded=bpy.data.meshes.new(mesh.name+'_Mirrored')
    folded.from_pydata(points.reshape((-1,3)).tolist(),[],np.arange(len(points)*3).reshape((-1,3)).tolist());folded.update();folded.materials.append(mat)
    uv=folded.uv_layers.new(name='Metres');uv.data.foreach_set('uv',charts.astype(np.float32).ravel())
    guide=folded.attributes.new(name='_tangent_guide',type='FLOAT_VECTOR',domain='CORNER');g=guides[:,:,[0,2,1]].copy();g[:,:,2]*=-1;guide.data.foreach_set('vector',g.astype(np.float32).ravel())
    sign=folded.attributes.new(name='_tangent_sign',type='FLOAT',domain='CORNER');sign.data.foreach_set('value',np.repeat(signs,3).astype(np.float32))
    folded.normals_split_custom_set(normals.reshape((-1,3)).tolist())
    obj=bpy.data.objects.new(mesh.name,folded);exports.objects.link(obj);return obj

materials={};finished=[]
for key,objects in sorted(groups.items()):
    spec=catalog[key];finish={'catalog_key':key,'roughness':spec['roughness_multiplier'],'normal':1. if key.startswith('site_softwood') else .35,'pigment':1.,'tint':[1.,1.,1.,1.], 'planar_axes':[[1,0,0],[0,1,0],[0,0,1]]}
    mat=material(ROOT,'CATALOG_'+key,finish,catalog);materials[key]=mat
    if key.startswith('site_softwood'):
        for node in mat.node_tree.nodes:
            if node.type=='TEX_IMAGE':node.extension='EXTEND'
    # The grain frame is computed separately for every source board. Merging
    # happens only after that measurement; it cannot turn a wall of vertical
    # boards into one broad-panel chart.
    result=wood_partition(key,objects,mat) if key.startswith('site_softwood') else partition(exports,'Shed_'+key,objects,finish,mat,Matrix.Identity(4),catalog)
    finished.append(result)

for row in plan['retained_actors']:
    data={'id':row['id'],'center_m':row['center'],'size_m':row['size'],'roll_degrees':row.get('roll_degrees',0)}
    obj=box(data,source_collection);obj['retained_collision']=True
    raw=box(data,before);key=row['material']
    if key not in materials:
        spec=catalog[key];materials[key]=material(ROOT,'CATALOG_'+key,{'catalog_key':key,'roughness':1.,'normal':.35,'pigment':1.,'tint':[1.,1.,1.,1.]},catalog)
    raw.data.materials.append(materials[key])
    uv=raw.data.uv_layers.new(name='Metres')
    for face in raw.data.polygons:
        normal=face.normal;skip=max(range(3),key=lambda i:abs(normal[i]));axes=[i for i in range(3) if i!=skip]
        for loop in face.loop_indices:
            p=raw.data.vertices[raw.data.loops[loop].vertex_index].co;uv.data[loop].uv=(p[axes[0]],p[axes[1]])

def aim(obj,at):obj.rotation_euler=(Vector(at)-obj.location).to_track_quat('-Z','Y').to_euler()
world=bpy.data.worlds.new('NeutralConstructionReview');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.36,.42,.5,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5
sun_data=bpy.data.lights.new('OvercastKey','AREA');sun_data.energy=1800;sun_data.shape='DISK';sun_data.size=8
sun=bpy.data.objects.new('OvercastKey',sun_data);scene.collection.objects.link(sun);sun.location=point((18,8,7));aim(sun,point((23,1.5,2)))
camera_data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',camera_data);scene.collection.objects.link(camera);scene.camera=camera
fill_data=bpy.data.lights.new('InteriorReviewFill','AREA');fill_data.energy=180;fill_data.size=4
fill=bpy.data.objects.new('InteriorReviewFill',fill_data);scene.collection.objects.link(fill);fill.location=point((23.6,2.0,3.5));aim(fill,point((24,1.6,-2)))
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';camera_data.lens=28
for obj in list(bpy.context.selected_objects):obj.select_set(False)
for obj in finished:obj.select_set(True)
class ExportStock:
    def gather_material_hook(self,gltf_material,blender_material,settings):
        gltf_material.pbr_metallic_roughness=None;gltf_material.normal_texture=None;gltf_material.occlusion_texture=None
        gltf_material.emissive_texture=None;gltf_material.emissive_factor=None;gltf_material.extensions=None
    def gather_mesh_hook(self,mesh,data,obj,vertex_groups,modifiers,materials,settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for p in mesh.primitives:
            def values(key):return np.frombuffer(p.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];g=values('_TANGENT_GUIDE');t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
            w=np.frombuffer(p.attributes['_TANGENT_SIGN'].buffer_view.data,dtype='<f4') if '_TANGENT_SIGN' in p.attributes else -np.ones(len(t))
            p.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,w)).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER);del p.attributes['_TANGENT_GUIDE']
            if '_TANGENT_SIGN' in p.attributes:del p.attributes['_TANGENT_SIGN']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportStock
asset=work/'construction_shed.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT')
proof=validate(asset)
for name,eye,at in [('approach',(18.4,1.65,3.15),(23.5,1.8,2.5)),('framing',(24.0,1.7,2.8),(24.0,2.6,-.2)),('closure',(23.9,1.6,-1.7),(24,1.5,-3.0)),('joinery',(24.6,2.2,-.1),(25.27,2.6,-.55))]:
    camera.location=point(eye);aim(camera,point(at))
    for variant in ['before','candidate']:
        before.hide_render=variant!='before';exports.hide_render=variant!='candidate'
        scene.render.filepath=str(work/(name+'_'+variant+'.png'));bpy.ops.render.render(write_still=True)
before.hide_render=True;exports.hide_render=False

# Save editable stock with portable catalogue image paths. Review cameras and
# lighting stay in the native source and are excluded from the GLB selection.
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(ROOT/'art/blender'))
native=ROOT/'art/blender/construction_shed.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native))
for obj in list(bpy.context.selected_objects):obj.select_set(False)
for obj in finished:obj.select_set(True)

proof.update({'evidence_class':'INERT','scope':'Native UV/tangent export and rendered candidate, not installed-world acceptance.',
              'part_count':len(plan['parts']),'joints':plan['joints'],'plan_sha256':hashlib.sha256(json.dumps(plan,sort_keys=True).encode()).hexdigest(),
              'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest()})
(work/'native_review.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf8',newline='\n')
print('NATIVE CONSTRUCTION SHED: exported and inspected',len(plan['parts']),'parts;',len(finished),'material partitions')
