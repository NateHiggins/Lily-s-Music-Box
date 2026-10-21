"""Editable sealed stove thimble, loose closure and fading soot deposit."""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from repair_surface_uvs import repair_mesh
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.out_dir.resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
cv=lambda p:Vector((p[0],-p[2],p[1]));CY=1.44
materials={}
for key in ['iron_neutral','soot']:
    spec=catalog[key];mat=bpy.data.materials.new(key);mat.use_nodes=True;n=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=n.get('Principled BSDF');bsdf.inputs['Metallic'].default_value=spec['metallic']
    for index,socket in enumerate(['Base Color','Roughness','Normal']):
        texture=n.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
        if index:texture.image.colorspace_settings.name='Non-Color'
        if index==2:
            normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25 if key=='iron_neutral' else .15;links.new(texture.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs[socket])
        elif index==1:
            channels=n.new('ShaderNodeSeparateColor');factor=n.new('ShaderNodeMath');factor.operation='MULTIPLY';factor.inputs[1].default_value=spec['roughness_multiplier'];links.new(texture.outputs['Color'],channels.inputs['Color']);links.new(channels.outputs['Green'],factor.inputs[0]);links.new(factor.outputs[0],bsdf.inputs[socket])
        else:links.new(texture.outputs['Color'],bsdf.inputs[socket])
    if key=='soot':
        vertex=n.new('ShaderNodeVertexColor');vertex.layer_name='BurntEdge';links.new(vertex.outputs['Alpha'],bsdf.inputs['Alpha']);mat.surface_render_method='DITHERED'
    materials[key]=mat

def finish(obj,key):
    bpy.context.view_layer.objects.active=obj
    for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    for face in bm.faces:face.smooth=True
    for edge in bm.edges:edge.smooth=edge.is_manifold and edge.calc_face_angle()<math.radians(35)
    bm.to_mesh(obj.data);bm.free();mesh=obj.data;mesh.update();uv=mesh.uv_layers.active or mesh.uv_layers.new(name='Metres');tile=float(catalog[key]['meters_per_tile'])
    for face in mesh.polygons:
        normal=face.normal.normalized();seed=Vector((0,0,1)) if abs(normal.z)<.9 else Vector((1,0,0));u=normal.cross(seed).normalized();v=normal.cross(u);origin=Vector((0,0,0))
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co-origin;uv.data[loop].uv=(p.dot(u)/tile,p.dot(v)/tile)
    repair_mesh(obj);mesh.materials.clear();mesh.materials.append(materials[key]);obj['material_key']=key
    return obj

def tube(name,profile,center=(0,CY,0),sides=128):
    vertices=[cv((center[0]+r*math.cos(i*math.tau/sides),center[1]+r*math.sin(i*math.tau/sides),center[2]+z)) for r,z in profile for i in range(sides)]
    faces=[(j*sides+i,j*sides+(i+1)%sides,((j+1)%len(profile))*sides+(i+1)%sides,((j+1)%len(profile))*sides+i) for j in range(len(profile)) for i in range(sides)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj

parts=[]
parts.append(finish(tube('SteppedReducer',[(.165,0),(.165,-.018),(.151,-.025),(.151,-.039),(.115,-.048),(.115,-.057),(.083,-.064),(.083,-.078),(.0735,-.078),(.0735,-.010)]),'iron_neutral'))
parts.append(finish(tube('WallSleeve',[(.137,0),(.137,.085),(.133,.085),(.133,0)]),'iron_neutral'))
# A closed thin deposit with a soft, irregular vertex-alpha boundary. It is
# visual material layering, not a solid cylinder blocking the actual throat.
sides=128;verts=[]
for z in [-.002,.0002]:
    for radius in [.145,.195,.224]:
        for i in range(sides):
            a=i*math.tau/sides;r=radius*(1+.012*math.sin(7*a)+.009*math.sin(11*a+.4)+.004*math.sin(19*a));verts.append(cv((r*math.cos(a),CY+r*math.sin(a),z)))
faces=[]
for side in [0,1]:
    offset=side*3*sides
    for ring in range(2):
        for i in range(sides):
            row=(offset+ring*sides+i,offset+ring*sides+(i+1)%sides,offset+(ring+1)*sides+(i+1)%sides,offset+(ring+1)*sides+i);faces.append(row if side else row[::-1])
for ring in [0,2]:
    for i in range(sides):faces.append((ring*sides+i,ring*sides+(i+1)%sides,(3+ring)*sides+(i+1)%sides,(3+ring)*sides+i))
mesh=bpy.data.meshes.new('SootHalo');mesh.from_pydata(verts,[],faces);obj=bpy.data.objects.new('SootHalo',mesh);bpy.context.collection.objects.link(obj);finish(obj,'soot')
colors=mesh.color_attributes.new(name='BurntEdge',type='FLOAT_COLOR',domain='POINT');mesh.color_attributes.active_color=colors
for vertex in mesh.vertices:
    angle=math.atan2(vertex.co.z-CY,vertex.co.x);r=math.hypot(vertex.co.x,vertex.co.z-CY)/(1+.012*math.sin(7*angle)+.009*math.sin(11*angle+.4)+.004*math.sin(19*angle));a=max(0,min(1,(.224-r)/.055));colors.data[vertex.index].color=(1,1,1,a*a*(3-2*a))
parts.append(obj)
for index in range(4):
    a=math.pi/4+index*math.pi/2;x=.155*math.cos(a);y=CY+.155*math.sin(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0055,depth=.004,location=cv((x,y,-.025)),rotation=(math.pi/2,0,0));head=bpy.context.object;head.name='SlottedHead_'+str(index)
    bpy.ops.mesh.primitive_cube_add(size=1,location=cv((x,y,-.027)));cutter=bpy.context.object;cutter.dimensions=(.008,.002,.0015);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=head;mod=head.modifiers.new('ActualDriverSlot','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    bevel=head.modifiers.new('WorkedArris','BEVEL');bevel.width=.0003;bevel.segments=2;parts.append(finish(head,'iron_neutral'))
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.003,depth=.063,location=cv((x,y,.0085)),rotation=(math.pi/2,0,0));shank=bpy.context.object;shank.name='AnchorShank_'+str(index);parts.append(finish(shank,'iron_neutral'))
cap=bpy.data.objects.new('ClosurePlate',None);bpy.context.collection.objects.link(cap);cap.location=cv((0,CY,-.083))
bpy.ops.mesh.primitive_cylinder_add(vertices=128,radius=.0755,depth=.006,rotation=(math.pi/2,0,0));closure=bpy.context.object;closure.name='ClosureCasting';bevel=closure.modifiers.new('RolledClosureEdge','BEVEL');bevel.width=.0012;bevel.segments=3;finish(closure,'iron_neutral');closure.parent=cap;parts.append(closure)
curve=bpy.data.curves.new('FixedFingerBridge','CURVE');curve.dimensions='3D';curve.bevel_depth=.0025;curve.bevel_resolution=3;curve.use_fill_caps=True
path=[(-.018,-.010,-.004),(-.018,-.010,-.015),(-.013,-.010,-.022),(.013,-.010,-.022),(.018,-.010,-.015),(.018,-.010,-.004)]
spline=curve.splines.new('POLY');spline.points.add(len(path)-1)
for point,p in zip(spline.points,path):point.co=(*cv(p),1)
bridge=bpy.data.objects.new(curve.name,curve);bpy.context.collection.objects.link(bridge);bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=bridge;bridge.select_set(True);bpy.ops.object.convert(target='MESH');bridge=bpy.context.object;finish(bridge,'iron_neutral');bridge.parent=cap;parts.append(bridge)
checks=[]
for obj in parts:
    bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free();obj.data.calc_loop_triangles();uv=obj.data.uv_layers.active.data
    collapsed=sum(abs((uv[t.loops[1]].uv-uv[t.loops[0]].uv).cross(uv[t.loops[2]].uv-uv[t.loops[0]].uv))<1e-12 for t in obj.data.loop_triangles)
    checks.append(dict(part=obj.name,nonmanifold_edges=bad,volume_m3=volume,collapsed_uv_triangles=collapsed));assert bad==0 and volume>0 and collapsed==0,checks[-1]
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(out))
native=out/'flue_breast_fitting.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts+[cap]:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=out/'flue_breast_fitting.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
for material in materials.values():material.use_nodes=True
# A neutral wall receives the deposit, rather than an isolated transparent
# annulus casting a misleading free-standing silhouette. Review geometry only.
bpy.ops.mesh.primitive_cube_add(size=1,location=cv((0,CY,.06)));wall=bpy.context.object;wall.name='ReviewWall';wall.dimensions=(.75,.12,.75)
wallmat=bpy.data.materials.new('ReviewPlaster');wallmat.diffuse_color=(.32,.29,.24,1);wall.data.materials.append(wallmat)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.color=(.06,.06,.06)
target=Vector((0,0,CY))
for position,power,size in [((-.45,.6,1.95),20,.6),((.5,-.3,1.65),12,.5)]:
    data=bpy.data.lights.new('ReviewSoftbox','AREA');data.energy=power;data.shape='DISK';data.size=size;obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=position;obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera);scene.camera=camera;camera.location=(.3,.7,1.64);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=.58
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
for amount,name in [(0.,'seated'),(1.,'rocked')]:
    cap.location=cv((.002*amount,CY-.001*amount,-.083-.003*amount));cap.rotation_euler=(math.radians(1.6)*amount,-math.radians(.4)*amount,0)
    bpy.context.view_layer.update()
    scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
report=dict(evidence_class='INERT',scope='Saved native fitting and catalogue review only; not imported UV/mip, hand-input or installed-world proof.',native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),asset_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),checks=checks,parts=len(parts),center_y_m=CY,closure_pose=[0,CY,-.083],generator_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest())
report['source_bindings']={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['game/data/runtime_material_sets.json']+['game/assets/building/textures/'+file for key in materials for file in catalog[key]['files']]}
(out/'native_review.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print('FLUE BREAST NATIVE:',len(parts),'closed stocks; zero UV collapses')
