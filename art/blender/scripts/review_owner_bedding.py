"""Neutral bedding inspection using the production role recipes and metre charts."""
from pathlib import Path
import sys,json,hashlib
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from review_owner_service_finishes import material,profiles,scene
out=ROOT/'tmp/v2-improvement/bedding-native';out.mkdir(parents=True,exist_ok=True)
path=ROOT/'art/blender/bedding.blend'
with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
objects=[o for o in dst.objects if o]
for o in objects:scene.collection.objects.link(o)
materials={}
for role,key,group in [('Frame','oak_quartered','domestic'),('Mattress','linen','bedding_Mattress'),('Blanket','fabric_warm','bedding_Blanket'),('Pillows','linen','bedding_Pillows')]:
    materials[role]=material(key,profiles[group][key])
    # The export has metre-scaled UVs. Match runtime UV projection exactly.
    for node in materials[role].node_tree.nodes:
        if node.type=='TEX_COORD':
            for link in list(node.outputs['Object'].links):materials[role].node_tree.links.new(node.outputs['UV'],link.to_socket)
        elif node.type=='TEX_IMAGE':node.projection='FLAT'
for o in objects:
    if o.type=='MESH':o.data.materials[0]=materials[o.data.materials[0].name.split('.')[0]]
bpy.context.view_layer.update()
views=[]
for owner in [o for o in objects if o.type=='EMPTY']:
    selected=[o for o in objects if o.parent==owner and o.type=='MESH']
    for o in objects:
        if o.type=='MESH':o.hide_render=o not in selected
    points=[o.matrix_world@Vector(c) for o in selected for c in o.bound_box]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
    for detail in [False,True]:
        target=Vector((0,low.y+.36,.54)) if detail else center
        bpy.ops.object.camera_add(location=target+Vector((1.2,1.8,2.3)))
        camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=1.15 if detail else span*1.35;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
        lights=[]
        for offset,power in [((-1,-1.2,2),450),((1.8,1.6,1.7),200)]:
            bpy.ops.object.light_add(type='AREA',location=center+Vector(offset));light=bpy.context.object;light.data.energy=power;light.data.size=1.7;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler();lights.append(light)
        name=owner.name+('_pillow' if detail else '_whole')+'.png';scene.render.filepath=str(out/name);bpy.ops.render.render(write_still=True)
        views.append(name)
        for o in [camera,*lights]:bpy.data.objects.remove(o,do_unlink=True)
(out/'review.json').write_text(json.dumps({'evidence_class':'INERT','source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'views':views,'scope':'Three accepted size variants; representative oak/warm blanket. Source-selected household tints reviewed in production.'},indent=2)+'\n',encoding='utf-8',newline='\n')
