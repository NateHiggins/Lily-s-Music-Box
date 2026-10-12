"""Read-only catalogue PBR and source-owned bulkhead-contact review."""
from pathlib import Path
import json,sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from fabrication_native_batch import material
OUT=ROOT/'tmp/v2-roof-supply-20261012/review';OUT.mkdir(parents=True,exist_ok=True)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
bpy.ops.wm.read_factory_settings(use_empty=True)
layout=json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
half=layout['dimensions']['partition_wall']/2
# These bulkheads are the retained procedural wall owner. ExteriorMasonry
# has no roof leaf; reconstruct only the two actual source wall solids here.
for x in [5.4,9.5]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-1,20.7))
    wall=bpy.context.object;wall.dimensions=(half*2,1,3)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-1,21.9))
    cutter=bpy.context.object;cutter.dimensions=(.3,.08,.08)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=wall
    mod=wall.modifiers.new('Source service opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
masonry=[o for o in bpy.context.scene.objects if o.type=='MESH']
verts=[];faces=[]
for obj in masonry:
    offset=len(verts);verts.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
bvh=BVHTree.FromPolygons(verts,faces)
def point(p):return Vector((p[0],-p[2],p[1]))
contacts=[]
for label,x,direction,expected in [('Public',5.8,-1,5.47),('Service',9.1,1,9.43)]:
    hit,normal,_,distance=bvh.ray_cast(point([x,22.0,1]),Vector((direction,0,0)),.5)
    assert hit is not None and abs(hit.x-expected)<.0001 and normal.x*direction<-.99,(label,hit,normal)
    contacts.append({'owner':label,'contact':list(hit),'normal':list(normal)})
for x in [5.4,9.5]:
    hit,_,_,_=bvh.ray_cast(point([x-.5,21.9,1]),Vector((1,0,0)),1.)
    assert hit is None,('bulkhead bore blocked',x,hit)
for obj in masonry:
    if max((obj.matrix_world@v.co).z for v in obj.data.vertices)<19:obj.hide_render=True
    obj.data.materials.clear()
    obj.data.materials.append(material(ROOT,'brick',dict(catalog_key='brick',tint=[1,1,1,1],pigment=1,normal=.08,roughness=1),catalog))
bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets/props/roof_lighting_supply.glb'))
origin=Vector((9.39,-1,21.9))
roots=[o for o in bpy.context.selected_objects if o.parent is None]
for obj in roots:obj.location+=origin
mapped={}
for obj in bpy.context.selected_objects:
    if obj.type!='MESH':continue
    for slot in obj.material_slots:
        key=slot.material.name.split('.')[0]
        if key not in mapped:mapped[key]=material(ROOT,key,dict(catalog_key=key,tint=[1,1,1,1],pigment=1,normal=.08,roughness=catalog[key]['roughness_multiplier']),catalog)
        slot.material=mapped[key]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
bpy.ops.object.light_add(type='AREA',location=point([7,25,-3]));light=bpy.context.object;light.data.energy=1800;light.data.size=5
light.rotation_euler=(point([7,21.9,1])-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();camera=bpy.context.object;scene.camera=camera;camera.data.lens=48
for label,at,target in [('bridge',[7.3,21.1,-4],[7.45,21.95,1]),('public_bearing',[6.2,21.65,.2],[5.76,22,1]),('cross',[9.1,21.65,.1],[9.39,21.9,1])]:
    camera.location=point(at);camera.rotation_euler=(point(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
(OUT/'contacts.json').write_text(json.dumps({'evidence_class':'INERT','contacts':contacts,'bulkhead_bores_clear':2,'scope':'Blender source-owned bulkhead contacts and native catalogue appearance; runtime route remains required.'},indent=2)+'\n',encoding='utf-8',newline='\n')
