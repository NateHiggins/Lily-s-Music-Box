"""Render saved native joinery with the shipped paint/brass PBR maps."""
from pathlib import Path
import json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-door-polish-20261012/domestic-native';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/domestic_door_leaves.blend'))
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
def material(key,tint):
    spec=sets[key];mat=bpy.data.materials.new(key);mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links
    shader=nodes['Principled BSDF'];shader.inputs['Metallic'].default_value=spec['metallic']
    coords=nodes.new('ShaderNodeTexCoord');scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];links.new(coords.outputs['UV'],scale.inputs[0])
    for i,target in enumerate(['Base Color','Roughness','Normal']):
        image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
        if i:image.colorspace_settings.name='Non-Color'
        tex=nodes.new('ShaderNodeTexImage');tex.image=image;links.new(scale.outputs['Vector'],tex.inputs['Vector'])
        if i==0:
            mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
            mix.inputs[2].default_value=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in tint)+(1,)
            links.new(tex.outputs['Color'],mix.inputs[1]);links.new(mix.outputs[0],shader.inputs[target])
        elif i==2:
            normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],shader.inputs[target])
        else:links.new(tex.outputs['Color'],shader.inputs[target])
    return mat
paint=material('door_paint',(.69,.66,.58));brass=material('door_brass',(1,1,1))
leaves=list(bpy.context.scene.objects)
for obj in leaves:obj.hide_render=True;obj.data.materials.append(paint)
with bpy.data.libraries.load(str(ROOT/'art/blender/door_knob_set.blend'),link=False) as (src,dst):dst.objects=list(src.objects)
knobs=[]
for obj in dst.objects:
    bpy.context.scene.collection.objects.link(obj);obj.data.materials.clear();obj.data.materials.append(brass);knobs.append(obj)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('JoineryReview');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
for at,power,size in [((-1,-2,3),150,2),((2,-1,2),90,1)]:
    data=bpy.data.lights.new('GrazingSoftbox','AREA');data.energy=power;data.size=size
    light=bpy.data.objects.new(data.name,data);scene.collection.objects.link(light);light.location=at
    light.rotation_euler=(Vector((.4,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('JoineryCamera');camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera);scene.camera=camera;data.lens=50;data.clip_start=.001
for name,width in [('Leaf0760x2130',.76),('Leaf1050x2130',1.05)]:
    obj=bpy.data.objects[name];obj.hide_render=False
    for knob in knobs:knob.location=(width-.085,-.022,1)
    for detail in [False,True]:
        at=(width*.5+1,-3,1.45) if not detail else (width-.05,-.48,1.02)
        target=(width*.5,0,1.05) if not detail else (width-.15,0,.9)
        camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/(name+('_detail' if detail else '')+'.png'));bpy.ops.render.render(write_still=True)
    obj.hide_render=True
