"""Native open flue-wall sleeve and anchored cast plate; candidate output only."""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from repair_surface_uvs import repair_mesh
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out-dir',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);out=args.out_dir.resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
cv=lambda p:Vector((p[0],-p[2],p[1]))
materials={}
for key in ['iron_neutral']:
    spec=catalog[key];mat=bpy.data.materials.new(key);mat.use_nodes=True;bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Metallic'].default_value=spec['metallic']
    for index,socket in enumerate(['Base Color','Roughness','Normal']):
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
        if index:tex.image.colorspace_settings.name='Non-Color'
        if index==2:
            normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25
            mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs[socket])
        elif index==1:
            factor=mat.node_tree.nodes.new('ShaderNodeMath');factor.operation='MULTIPLY';factor.inputs[1].default_value=spec['roughness_multiplier']
            channels=mat.node_tree.nodes.new('ShaderNodeSeparateColor')
            mat.node_tree.links.new(tex.outputs['Color'],channels.inputs['Color']);mat.node_tree.links.new(channels.outputs['Green'],factor.inputs[0]);mat.node_tree.links.new(factor.outputs[0],bsdf.inputs[socket])
        else:mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs[socket])
    materials[key]=mat

def finish(obj,key):
    bpy.context.view_layer.objects.active=obj
    for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    for face in bm.faces:face.smooth=True
    for edge in bm.edges:edge.smooth=edge.is_manifold and edge.calc_face_angle()<math.radians(35)
    bm.to_mesh(obj.data);bm.free()
    mesh=obj.data;mesh.update();uv=mesh.uv_layers.active or mesh.uv_layers.new(name='Metres')
    tile=float(catalog[key]['meters_per_tile'])
    for face in mesh.polygons:
        n=face.normal.normalized();seed=Vector((0,0,1)) if abs(n.z)<.9 else Vector((1,0,0))
        u=n.cross(seed).normalized();v=n.cross(u);origin=mesh.vertices[face.vertices[0]].co
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co-origin;uv.data[loop].uv=(p.dot(u)/tile,p.dot(v)/tile)
    repair_mesh(obj);mesh.materials.clear();mesh.materials.append(materials[key]);obj['material_key']=key
    return obj

def tube(name,profile,center=(0,0,0),sides=96):
    # Profile runs around the closed radial/axial cross-section, leaving a real bore.
    verts=[cv([center[0]+r*math.cos(i*math.tau/sides),center[1]+r*math.sin(i*math.tau/sides),center[2]+z]) for r,z in profile for i in range(sides)]
    faces=[]
    for j in range(len(profile)):
        for i in range(sides):faces.append((j*sides+i,j*sides+(i+1)%sides,((j+1)%len(profile))*sides+(i+1)%sides,((j+1)%len(profile))*sides+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj

bpy.ops.mesh.primitive_cube_add(size=1);plate=bpy.context.object;plate.name='CastPlate';plate.dimensions=(.48,.014,.48)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bevel=plate.modifiers.new('CastCornerRadii','BEVEL');bevel.width=.009;bevel.segments=4
bpy.context.view_layer.objects.active=plate;bpy.ops.object.modifier_apply(modifier=bevel.name)
bpy.ops.mesh.primitive_cylinder_add(vertices=128,radius=.1735,depth=.07,rotation=(math.pi/2,0,0));cutter=bpy.context.object
bpy.context.view_layer.objects.active=plate;cut=plate.modifiers.new('OpenFlueBore','BOOLEAN');cut.operation='DIFFERENCE';cut.solver='EXACT';cut.object=cutter;bpy.ops.object.modifier_apply(modifier=cut.name);bpy.data.objects.remove(cutter,do_unlink=True)
# Fused socket and rolled front lip, never a smooth capped cylinder.
for part in [tube('Socket',[(.177,-.012),(.177,.095),(.1715,.095),(.1715,-.012)]),
             tube('RolledMouth',[(.173,-.026),(.189,-.026),(.195,-.022),(.195,-.014),(.187,-.010),(.1715,-.010),(.1715,-.023)])]:
    bpy.context.view_layer.objects.active=plate;mod=plate.modifiers.new('FusedCasting','BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=part;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(part,do_unlink=True)
finish(plate,'iron_neutral');parts=[plate]
for x in [-.205,.205]:
    for y in [-.205,.205]:
        # Anchors sit outside the 360mm masonry penetration, with a real bearing washer.
        washer=finish(tube('BearingWasher',[(.014,-.018),(.014,-.010),(.0065,-.010),(.0065,-.018)],(x,y,0),48),'iron_neutral');parts.append(washer)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.0105,depth=.012,location=cv([x,y,-.024]),rotation=(math.pi/2,0,0));head=bpy.context.object;head.name='HexBoltHead'
        bevel=head.modifiers.new('WrenchArris','BEVEL');bevel.width=.0012;bevel.segments=2
        parts.append(finish(head,'iron_neutral'))
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.006,depth=.087,location=cv([x,y,.0215]),rotation=(math.pi/2,0,0))
        shank=bpy.context.object;shank.name='AnchorShank';parts.append(finish(shank,'iron_neutral'))

checks=[];failures=[]
for obj in parts:
    bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    obj.data.calc_loop_triangles();uv=obj.data.uv_layers.active.data;collapsed=0
    for tri in obj.data.loop_triangles:
        a,b,c=[uv[i].uv for i in tri.loops]
        if abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-12:collapsed+=1
    row=dict(part=obj.name,nonmanifold_edges=bad,signed_volume=volume,collapsed_uv_triangles=collapsed);checks.append(row)
    if bad or volume<=0 or collapsed:failures.append(row)
if failures:raise RuntimeError(str(failures))
native=out/'flue_wall_thimble.blend'
for image in bpy.data.images:
    if image.source=='FILE' and image.filepath:image.filepath=bpy.path.relpath(image.filepath,start=str(out))
bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
class ExportUVHandedness:
    def gather_attribute_change(self,attribute,data,normalized,export_settings):
        if attribute=='TANGENT':data['data'][:,3]*=-1
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUVHandedness
asset=out/'flue_wall_thimble.glb';bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_materials='PLACEHOLDER')
# Review the actual candidate under its catalogue PBR maps.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.color=(.055,.055,.055)
for point,power,size in [((-.65,-.75,.7),120,.7),((.55,.3,.5),75,.6)]:
    lamp=bpy.data.lights.new('ReviewSoftbox','AREA');lamp.energy=power;lamp.shape='DISK';lamp.size=size;obj=bpy.data.objects.new('ReviewSoftbox',lamp);scene.collection.objects.link(obj);obj.location=point;obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.cameras.new('ReviewCamera');obj=bpy.data.objects.new('ReviewCamera',camera);scene.collection.objects.link(obj);scene.camera=obj;obj.location=(.55,.85,.45);obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler();camera.type='ORTHO';camera.ortho_scale=.72
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.filepath=str(out/'thimble_review.png');bpy.ops.render.render(write_still=True)
report=dict(evidence_class='INERT',scope='Closed native candidate and catalogue PBR review only. Not imported mip/UV proof or runtime acceptance.',native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),asset_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),checks=checks,failures=failures,plate_width_m=.48,bore_radius_m=.1715,anchor_centers_m=.205,wall_port_half_m=.18,
    generator_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    source_bindings={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['game/data/runtime_material_sets.json']+['game/assets/building/textures/'+name for name in catalog['iron_neutral']['files']]})
(out/'native_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('FLUE THIMBLE CANDIDATE',len(parts),'closed stocks, zero native failures',flush=True)
