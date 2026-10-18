"""Build and compare the lantern roof candidate; writes no runtime assets."""
from pathlib import Path
import argparse, collections, hashlib, json, math, sys
import bpy, bmesh, numpy as np
from mathutils import Matrix, Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').exists())
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'art/blender/scripts')]
from plan_v2_arcade_lantern import build
from fabrication_native_batch import material, partition
from check_exported_tangents import validate

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir',type=Path,required=True)
parser.add_argument('--publish-native',action='store_true')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
work=args.work_dir.resolve();work.mkdir(parents=True,exist_ok=True)
plan=build()
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
editable=collection('EditableFoldedStock');editable.hide_render=True
exports=collection('NativeCandidate');context=collection('RetainedContext');before=collection('OriginalRoofComparison')
def point(p):return (p[0],-p[2],p[1])
def box(name,lo,hi,owner,bevel=0):
    vertices=[point([lo[i] if s[i]<0 else hi[i] for i in range(3)])
              for s in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=2,affect='EDGES',clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    if not all(e.is_manifold for e in bm.edges) or bm.calc_volume()<=0:raise ValueError('Open/inverted stock: '+name)
    bm.to_mesh(mesh);bm.free();obj=bpy.data.objects.new(name,mesh);owner.objects.link(obj);return obj
objects=[box(r['id'],r['low'],r['high'],editable,r['bevel_m']) for r in plan['parts']]
finish=dict(catalog_key='iron_blackened',normal=.35,roughness=1.,pigment=1.,tint=[1.,1.,1.,1.],planar_axes=[(1,0,0),(0,1,0),(0,0,1)])
iron=material(ROOT,'LanternMappedIron',finish,catalog)
model=partition(exports,'lantern_roof__cast_iron',objects,finish,iron,Matrix.Identity(4),catalog)
from mathutils.bvhtree import BVHTree
tree=BVHTree.FromPolygons([v.co for v in model.data.vertices],
                         [tuple(f.vertices) for f in model.data.polygons],all_triangles=True)
geometry_checks=[]
def verify(condition,label):
    geometry_checks.append(dict(ok=bool(condition),label=label))
    if not condition:raise ValueError(label)
for x in [13.4,14.6]:
    for z in [51.,52.2]:
        hit=tree.ray_cast(Vector(point((x,10.8,z))),Vector((0,0,1)),.8)
        verify(hit[0] is None,'actual exported roof leaves the retained light well clear '+str((x,z)))
for index,x in enumerate([11.2,12.,12.7]):
    hit=tree.ray_cast(Vector(point((x,10.8,52.))),Vector((0,0,1)),.8)
    expected=plan['retire'][index]['high'][1]-.022
    verify(hit[0] is not None and abs(hit[0].z-expected)<.00004 and hit[1].z<-.999,
           'actual underside of tier '+str(index)+' has its intended height and outward normal')
cx,top,cz=plan['hanger_bearing']
hit=tree.ray_cast(Vector(point((cx,top-.01,cz))),Vector((0,0,1)),.2)
verify(hit[0] is not None and abs(hit[0].z-top)<.00004 and hit[1].z<-.999,
       'native collar meets the retained clock stem endpoint with a closed bearing face')
for bearing in plan['post_bearings']:
    x,y,z=bearing['at']
    for sample in range(9):
        angle=2*math.pi*(sample-1)/8
        radius=0 if sample==0 else bearing['radius']*.8
        probe=(x+radius*math.cos(angle),y-.001,z+radius*math.sin(angle))
        hit=tree.ray_cast(Vector(point(probe)),Vector((0,0,1)),.2)
        verify(hit[0] is not None and abs(hit[0].z-y)<.00004 and hit[1].z<-.999,
               'closed channel seats retained post '+bearing['id']+' sample '+str(sample))

# Context is the exact source furniture and the installed native canopy;
# none of these objects are included in the new native export.
layout=json.loads((ROOT/plan['source']).read_text())
source_rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
glass=bpy.data.materials.new('RetainedMilkGlassReviewOnly');glass.use_nodes=True
node=glass.node_tree.nodes['Principled BSDF'];node.inputs['Base Color'].default_value=(.8,.84,.78,1);node.inputs['Roughness'].default_value=.3;node.inputs['Transmission Weight'].default_value=.55
clear=glass.copy();clear.name='RetainedClearGlassReviewOnly';clear.node_tree.nodes['Principled BSDF'].inputs['Transmission Weight'].default_value=1;clear.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.06
for row in source_rows.values():
    identity=row['id']
    if identity in [r['id'] for r in plan['retire']]:
        r=next(r for r in plan['retire'] if r['id']==identity);obj=box('BEFORE_'+identity,r['low'],r['high'],before);obj.data.materials.append(iron)
    elif identity.startswith(('site_passage_lantern_curb_','site_passage_lantern_glass_')) or identity==plan['retained_light']:
        a,b,c,d=row['rect'];obj=box('RETAINED_'+identity,[a,row['z0'],-d],[c,row['z0']+row['h'],-b],context)
        obj.data.materials.append(glass if row['mat']=='milk_glass' else clear if row['mat']=='glassish' else iron)
    elif identity.startswith('site_lantern_post_') or identity in [plan['retained_clock_stem'],'site_lantern_mast']:
        a,b=Vector(point(row['p0'])),Vector(point(row['p1']))
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=row['r'],depth=(b-a).length,location=(a+b)/2)
        obj=bpy.context.object;obj.name='RETAINED_'+identity;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        for c in list(obj.users_collection):c.objects.unlink(obj)
        context.objects.link(obj);obj.data.materials.append(iron)
with bpy.data.libraries.load(str(ROOT/'art/blender/arcade_canopy.blend'),link=False) as (available,loaded):
    loaded.objects=[name for name in available.objects if name.startswith('canopy__')]
for obj in loaded.objects:
    if obj:context.objects.link(obj)
for image in bpy.data.images:
    if image.source!='FILE':continue
    # Appended context images can retain paths relative to the library file.
    # Resolve the registered texture basename before rendering or saving here.
    texture=ROOT/'game/assets/building/textures'/Path(image.filepath).name
    if not texture.is_file():raise ValueError('Missing retained texture: '+image.filepath)
    image.filepath=str(texture);image.reload()

class ExportUV:
    def gather_material_hook(self,mat,source,settings):
        mat.pbr_metallic_roughness=None;mat.normal_texture=None;mat.occlusion_texture=None;mat.emissive_texture=None;mat.emissive_factor=None;mat.extensions=None
    def gather_mesh_hook(self,mesh,data,obj,groups,modifiers,materials,settings):
        from io_scene_gltf2.io.exp.binary_data import BinaryData
        from io_scene_gltf2.io.com.constants import BufferViewTarget
        for primitive in mesh.primitives:
            def values(key):return np.frombuffer(primitive.attributes[key].buffer_view.data,dtype='<f4').reshape((-1,3)).astype(float)
            n=values('NORMAL');n/=np.linalg.norm(n,axis=1)[:,None];g=values('_TANGENT_GUIDE');t=g-n*np.sum(g*n,axis=1)[:,None];t/=np.linalg.norm(t,axis=1)[:,None]
            primitive.attributes['TANGENT'].buffer_view=BinaryData(np.column_stack((t,-np.ones(len(t)))).astype('<f4').tobytes(),BufferViewTarget.ARRAY_BUFFER)
            del primitive.attributes['_TANGENT_GUIDE']
import io_scene_gltf2
io_scene_gltf2.glTF2ExportUserExtension=ExportUV
bpy.ops.object.select_all(action='DESELECT');model.select_set(True)
asset=work/'arcade_lantern.glb'
bpy.ops.export_scene.gltf(filepath=str(asset),export_format='GLB',use_selection=True,export_yup=True,export_tangents=True,export_attributes=True,export_materials='EXPORT')
proof=validate(asset)
proof['geometry_checks']=geometry_checks
scene.world=bpy.data.worlds.new('LanternReviewSky');scene.world.use_nodes=True
world=scene.world.node_tree;sky=world.nodes.new('ShaderNodeTexSky');sky.sky_type='MULTIPLE_SCATTERING';sky.sun_elevation=math.radians(35)
world.links.new(sky.outputs['Color'],world.nodes['Background'].inputs['Color']);world.nodes['Background'].inputs['Strength'].default_value=.35
data=bpy.data.lights.new('UndersideReviewLight','AREA');lamp=bpy.data.objects.new('UndersideReviewLight',data);scene.collection.objects.link(lamp);data.energy=1200;data.size=4
lamp.location=point((14,8,51.6));lamp.rotation_euler=(Vector(point((14,11,51.6)))-lamp.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('ReviewCamera',bpy.data.cameras.new('ReviewCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.lens=28
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
views=[]
for name,eye,target in [('underside',(14,8.7,46.9),(14,11.1,51.6)),('top',(19,14.8,45),(14,11.2,51.6)),('player',(14,1.65,44),(14,10.7,51.6))]:
    camera.location=point(eye);camera.rotation_euler=(Vector(point(target))-camera.location).to_track_quat('-Z','Y').to_euler()
    for state in ['before','after']:
        exports.hide_render=state=='before';before.hide_render=state=='after'
        file=name+'_'+state+'.png';scene.render.filepath=str(work/file);bpy.ops.render.render(write_still=True);views.append(file)
exports.hide_render=False;before.hide_render=True
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(image.filepath,start=str(work))
bpy.ops.wm.save_as_mainfile(filepath=str(work/'arcade_lantern.blend'),relative_remap=False)
if args.publish_native:
    destination=ROOT/'art/blender/arcade_lantern.blend'
    for image in bpy.data.images:
        if image.source=='FILE':
            image.filepath=bpy.path.relpath(str(ROOT/'game/assets/building/textures'/Path(image.filepath).name),start=str(destination.parent))
    bpy.ops.wm.save_as_mainfile(filepath=str(destination),relative_remap=False)
proof.update(evidence_class='INERT',scope='Offline native candidate; composed fit, UV/PBR/mips and appearance verification remain pending.',stock_count=len(objects),views=views,asset_sha256=hashlib.sha256(asset.read_bytes()).hexdigest(),source_bindings_lf={})
for relative in [plan['source'],'tools/plan_v2_arcade_lantern.py','art/blender/arcade_fabric_candidate/build_arcade_lantern.py','art/blender/scripts/fabrication_native_batch.py','game/data/runtime_material_sets.json','art/blender/arcade_canopy.blend']:
    proof['source_bindings_lf'][relative]=hashlib.sha256((ROOT/relative).read_bytes().replace(b'\r\n',b'\n') if Path(relative).suffix!='.blend' else (ROOT/relative).read_bytes()).hexdigest()
if args.publish_native:
    proof['published_native']='art/blender/arcade_lantern.blend'
    proof['published_native_sha256']=hashlib.sha256(destination.read_bytes()).hexdigest()
(work/'plan.json').write_text(json.dumps(plan,indent=2)+'\n',encoding='utf8',newline='\n')
(work/'native_review.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf8',newline='\n')
print('LANTERN NATIVE CANDIDATE',json.dumps(proof))
