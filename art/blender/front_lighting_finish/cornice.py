"""Offline three-piece cornice passage at the authored 2.95 m conduit band."""
from pathlib import Path
import ast
import hashlib
import json
import math
import sys
import bpy
import bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-front-trim-20261017';OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
wood=material(ROOT,'CornicePaintedWood',dict(catalog_key='trim',tint=[1,1,1,1],pigment=1.,normal=.1,roughness=.7),catalog)
iron=material(ROOT,'CorniceConduit',dict(catalog_key='iron_neutral',tint=[.65,.67,.68,1],pigment=1.,normal=.12,roughness=.7),catalog)
source=ROOT/'art/blender/millwork_profile.blend'
with bpy.data.libraries.load(str(source),link=False) as (available,loaded):loaded.objects=['BeadedTrim']
template=loaded.objects[0]
collection=bpy.data.collections.new('OfflineCorniceFitting');bpy.context.scene.collection.children.link(collection)
helper=Path(__file__).with_name('prototype.py')
tree=ast.parse(helper.read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['chart','subtract']],type_ignores=[]),str(helper),'exec'))

def stock(name,length,center,height,depth,elevation):
    obj=template.copy();obj.data=template.data.copy();obj.name=name;collection.objects.link(obj)
    obj.matrix_world=Matrix.Identity(4)
    obj.data.transform(Matrix.Diagonal(Vector((length,depth,height,1))))
    obj.location=(center,-depth/2,elevation);obj.data.materials.clear();obj.data.materials.append(wood)
    return obj

def bore(radius,length):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=length,location=(0,-.025,0),rotation=(math.pi/2,0,0))
    return bpy.context.object

bridges=[];ends=[]
for n,(height,depth,elevation) in enumerate([(.05,.032,.025),(.05,.046,-.025),(.025,.054,-.0625)]):
    bridge=stock('BoredCornice_'+str(n),.14,0,height,depth,elevation)
    before={tuple(round(c,8) for c in v.co) for v in bridge.data.vertices if abs(v.co.x)>.06999}
    # Each closed stock is drilled independently; touching joined solids are
    # never submitted to a single ambiguous Boolean operation.
    subtract(bridge,bore(.0145,.16));bridges.append(bridge)
    after={tuple(round(c,8) for c in v.co) for v in bridge.data.vertices if abs(v.co.x)>.06999}
    ends.append(before==after)
    stock('RetainedCorniceLeft_'+str(n),.28,-.21,height,depth,elevation)
    stock('RetainedCorniceRight_'+str(n),.28,.21,height,depth,elevation)
pipe=bore(.0125,.30);pipe.name='HollowWallConduit';subtract(pipe,bore(.0105,.32));pipe.data.materials.append(iron)
for old in list(pipe.users_collection):old.objects.unlink(pipe)
collection.objects.link(pipe)
for obj in collection.objects:chart(obj)
bpy.data.objects.remove(template,do_unlink=True);bpy.context.view_layer.update()
checks=[]
def check(label,passed,**detail):checks.append(dict(check=label,passed=bool(passed),**detail))
check('all three exact flat end sections retain their original butt joins',all(ends))
trees=[]
for obj in bridges:
    bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(obj.matrix_world);bm.normal_update();trees.append(BVHTree.FromBMesh(bm));bm.free()
for i in range(32):
    a=math.tau*i/32;at=Vector((math.cos(a)*.0126,-.15,math.sin(a)*.0126))
    check('horizontal pipe envelope clears every cornice member',all(t.ray_cast(at,Vector((0,1,0)),.30)[0] is None for t in trees),index=i)
for x in [-.04,.04]:
    check('cornice remains beside the drilled passage',any(t.ray_cast(Vector((x,-.15,-.02)),Vector((0,1,0)),.30)[0] is not None for t in trees),x=x)
for obj in collection.objects:
    bm=bmesh.new();bm.from_mesh(obj.data)
    check('closed positive native stock',all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,id=obj.name);bm.free()
    bad=0
    for face in obj.data.polygons:
        uv=[Vector(obj.data.uv_layers.active.data[i].uv) for i in face.loop_indices]
        if face.area>1e-12 and abs((uv[1]-uv[0]).cross(uv[2]-uv[0]))<1e-13:bad+=1
    check('finite noncollapsed metre grain charts',bad==0 and all(math.isfinite(v) for row in obj.data.uv_layers.active.data for v in row.uv),id=obj.name)
native=ROOT/'art/blender/front_lighting_cornice_candidate.blend'
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(bpy.path.abspath(image.filepath),start=str(native.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(native));bpy.ops.wm.open_mainfile(filepath=str(native))
for image in bpy.data.images:
    if image.source=='FILE' and image.users:check('portable catalogue image resolves',Path(bpy.path.abspath(image.filepath)).is_file(),id=image.name)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Cornice review ambient');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.3
bpy.ops.object.camera_add(location=(.28,-.42,.22));camera=bpy.context.object
camera.rotation_euler=(Vector((0,-.02,-.015))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=65;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(-.12,-.24,.32));light=bpy.context.object;light.data.energy=.8;light.data.size=.3
light.rotation_euler=(Vector((0,-.02,0))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'bored_cornice.png');bpy.ops.render.render(write_still=True)
failures=[r for r in checks if not r['passed']]
report=dict(evidence_class='INERT',status='OFFLINE_PROTOTYPE_NOT_INSTALLED',checks=checks,failures=failures,
    native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),source_profile_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    helper_sha256_lf=hashlib.sha256(helper.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
    scope='Three actual cornice profile bands and hollow transverse conduit; not exported or installed in the game.')
(OUT/'cornice.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('CORNICE FITTING:',len(checks),'checks;',len(failures),'failures')
if failures:raise RuntimeError(str(failures))
