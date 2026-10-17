"""Offline native rail/conduit fitting prototype; does not edit shipping assets."""
from pathlib import Path
import hashlib
import json
import math
import sys
import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-front-trim-20261017'
OUT.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from fabrication_native_batch import material

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
wood=material(ROOT,'PrototypePaintedWood',dict(catalog_key='trim',tint=[1,1,1,1],pigment=1.,normal=.1,roughness=.7),catalog)
iron=material(ROOT,'PrototypeConduit',dict(catalog_key='iron_neutral',tint=[.65,.67,.68,1],pigment=1.,normal=.12,roughness=.7),catalog)
source=ROOT/'art/blender/millwork_profile.blend'
with bpy.data.libraries.load(str(source),link=False) as (available,loaded):
    loaded.objects=['BeadedTrim']
template=loaded.objects[0]
collection=bpy.data.collections.new('OfflineRailFitting');bpy.context.scene.collection.children.link(collection)

def chart(obj):
    mesh=obj.data
    tri=obj.modifiers.new('Finite stock triangles','TRIANGULATE')
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=tri.name)
    for old in list(mesh.uv_layers):mesh.uv_layers.remove(old)
    uv=mesh.uv_layers.new(name='MetreGrain')
    for face in mesh.polygons:
        axis=max(range(3),key=lambda i:abs(face.normal[i]))
        a,b=(1,2) if axis==0 else (0,2) if axis==1 else (0,1)
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co
            # The catalogue's timber grain runs along texture V. Match the
            # surrounding millwork's longitudinal chart in the native UVs;
            # export then derives its tangent frame from this actual chart.
            uv.data[loop].uv=(p[b],p[a])

def stock(name,length,center):
    obj=template.copy();obj.data=template.data.copy();obj.name=name
    collection.objects.link(obj)
    obj.matrix_world=Matrix.Identity(4)
    obj.data.transform(Matrix.Diagonal(Vector((length,.042,.042,1))))
    obj.location=(center,-.021,0)
    obj.data.materials.clear();obj.data.materials.append(wood)
    return obj

def cylinder(radius,height):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=height,location=(0,-.020,0))
    return bpy.context.object

def subtract(obj,cutter):
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Actual drilled passage','BOOLEAN')
    modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter,do_unlink=True)

bridge=stock('BoredRailBridge',.14,0)
end_sections={tuple(round(c,8) for c in v.co) for v in bridge.data.vertices if abs(v.co.x)>.06999}
subtract(bridge,cylinder(.014,.10))
after={tuple(round(c,8) for c in v.co) for v in bridge.data.vertices if abs(v.co.x)>.06999}
left=stock('RetainedRailLeft',.28,-.21);right=stock('RetainedRailRight',.28,.21)
pipe=cylinder(.0125,.24);pipe.name='HollowConduit'
subtract(pipe,cylinder(.0105,.26))
pipe.data.materials.append(iron)
for old in list(pipe.users_collection):old.objects.unlink(pipe)
collection.objects.link(pipe)
for obj in collection.objects:chart(obj)
bpy.data.objects.remove(template,do_unlink=True)
bpy.context.view_layer.update()

checks=[]
def check(label,passed,**detail):checks.append(dict(check=label,passed=bool(passed),**detail))
check('untouched flat end sections preserve exact butt joins',end_sections==after)
bm=bmesh.new();bm.from_mesh(bridge.data);bm.transform(bridge.matrix_world);bm.normal_update()
tree=BVHTree.FromBMesh(bm);bm.free()
for i in range(32):
    angle=math.tau*i/32
    origin=Vector((math.cos(angle)*.0126,-.020+math.sin(angle)*.0126,.08))
    check('pipe envelope passes through wood with real clearance',tree.ray_cast(origin,Vector((0,0,-1)),.16)[0] is None,index=i)
for x in [-.04,.04]:
    check('stock remains on both sides of drilled passage',tree.ray_cast(Vector((x,-.02,.08)),Vector((0,0,-1)),.16)[0] is not None,x=x)
for obj in collection.objects:
    bm=bmesh.new();bm.from_mesh(obj.data)
    check('closed positive native stock',all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0,id=obj.name)
    bm.free();bad=0
    for face in obj.data.polygons:
        uv=[Vector(obj.data.uv_layers.active.data[i].uv) for i in face.loop_indices]
        if face.area>1e-12 and abs((uv[1]-uv[0]).cross(uv[2]-uv[0]))<1e-13:bad+=1
    check('finite noncollapsed physical-scale grain charts',bad==0 and all(math.isfinite(v) for row in obj.data.uv_layers.active.data for v in row.uv),id=obj.name)

native=ROOT/'art/blender/front_lighting_finish_candidate.blend'
for image in bpy.data.images:
    if image.source=='FILE':image.filepath=bpy.path.relpath(bpy.path.abspath(image.filepath),start=str(native.parent))
bpy.ops.wm.save_as_mainfile(filepath=str(native))
bpy.ops.wm.open_mainfile(filepath=str(native))
for image in bpy.data.images:
    if image.source=='FILE' and image.users:
        check('saved native catalogue image resolves',Path(bpy.path.abspath(image.filepath)).is_file(),id=image.name)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review ambient');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.3
bpy.ops.object.camera_add(location=(.26,-.42,.22));camera=bpy.context.object
camera.rotation_euler=(Vector((0,-.02,0))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=65;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(-.12,-.24,.32));light=bpy.context.object;light.data.energy=.8;light.data.size=.3
light.rotation_euler=(Vector((0,-.02,0))-light.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'bored_rail.png');bpy.ops.render.render(write_still=True)
failures=[row for row in checks if not row['passed']]
report=dict(evidence_class='INERT',status='OFFLINE_PROTOTYPE_NOT_INSTALLED',checks=checks,failures=failures,
            native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(),
            source_profile_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            recipe_sha256_lf=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
            scope='One native picture-rail bridge and hollow conduit; no repeated-room, export, Godot or human acceptance.')
(OUT/'prototype.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('RAIL FITTING:',len(checks),'checks;',len(failures),'failures')
if failures:raise RuntimeError(str(failures))
