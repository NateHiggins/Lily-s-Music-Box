"""Review registered PBR stock before the composed-world electrical import."""
from pathlib import Path
import json,math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-electrical-service-20261011/blender';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/electrical_service.blend'))
stocks={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
for key in ('iron_neutral','galvanized_roof','brass_dull'):
    mat=bpy.data.materials[key];p=mat.node_tree.nodes['Principled BSDF']
    p.inputs['Metallic'].default_value=.75 if key!='brass_dull' else .65
    files=catalog[key]['files']
    if key=='brass_dull':files=['mailbank/T_mailbank_brass_albedo.png','mailbank/T_mailbank_brass_rough.png',files[2]]
    for i,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
        t=mat.node_tree.nodes.new('ShaderNodeTexImage')
        t.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/files[i]),check_existing=True)
        if i:t.image.colorspace_settings.name='Non-Color'
        if i==2:
            n=mat.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.15
            mat.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);mat.node_tree.links.new(n.outputs['Normal'],p.inputs[socket])
        elif i==0 and key=='iron_neutral':
            mix=mat.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
            mix.inputs[2].default_value=(.35,.37,.39,1)
            mat.node_tree.links.new(t.outputs['Color'],mix.inputs[1]);mat.node_tree.links.new(mix.outputs[0],p.inputs[socket])
        else:mat.node_tree.links.new(t.outputs['Color'],p.inputs[socket])
for o in stocks.values():
    o.hide_render=True
    for loop in o.data.uv_layers.active.data:loop.uv/=.65
made=[]
def part(name,y=0,length=1,offset=(0,0,0)):
    o=stocks[name].copy();o.data=o.data.copy();bpy.context.collection.objects.link(o)
    o.hide_render=False;o.location=(offset[0],-offset[2],y+offset[1]);made.append(o)
    if name=='ConduitUnit':
        for f in o.data.polygons:
            if abs(f.normal.z)<max(abs(f.normal.x),abs(f.normal.y)):
                for i in f.loop_indices:o.data.uv_layers.active.data[i].uv.y*=length
        for v in o.data.vertices:v.co.z*=length
    return o
def assembly(exploded=False):
    for o in made:bpy.data.objects.remove(o,do_unlink=True)
    made.clear()
    part('ConduitUnit',-.440,.64);part('ConduitUnit',.440,.64)
    for y in (-.45,.45):
        part('WallSaddle',y);part('SaddleScrews',y);part('ThreadedCoupling',y+.10)
    for name in ('JunctionCasting','EntryBushUpper','EntryBushLower'):part(name)
    for name in ('JunctionCover','CoverScrews'):part(name,offset=(0,0,.13 if exploded else 0))
    for name in ('FloorSleeve','FloorEscutcheon'):part(name,-.76)
    part('ConduitCap',.764)

for at,power in [((.8,-1.4,1.8),90),((-.8,-.5,.2),45)]:
    d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=1
    o=bpy.data.objects.new('Softbox',d);bpy.context.collection.objects.link(o);o.location=at
    o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Review');cam=bpy.data.objects.new('Review',d);bpy.context.collection.objects.link(cam)
s=bpy.context.scene;s.camera=cam;s.render.engine='CYCLES';s.cycles.samples=32
s.render.resolution_x=1000;s.render.resolution_y=1100;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1)
for label,exploded,scale,at in [('assembly',False,1.85,(.6,-2,.45)),('casting',True,.48,(.45,-1,.32)),('saddle',False,.28,(.45,-1,.48))]:
    assembly(exploded);target=Vector((0,0,.45 if label=='saddle' else 0))
    cam.location=at;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    d.type='ORTHO';d.ortho_scale=scale;s.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
