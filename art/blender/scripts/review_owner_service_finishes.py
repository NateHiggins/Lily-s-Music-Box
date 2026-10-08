"""Apply the shared finish recipes to retained native service geometry.

This review assembly is reproducible from unchanged source blends. It exports
no geometry: the runtime uses the same original meshes plus material overrides.
"""
from pathlib import Path
import hashlib,json,math
import bpy,numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-improvement/service-finish-native';OUT.mkdir(parents=True,exist_ok=True)
profiles={g['id']:{r['source_key']:r for r in g['recipes']} for g in json.loads((ROOT/'game/data/orison_v2/owner_finish_profiles.json').read_text())['groups']}
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.32,.34,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'

def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
def material(key,recipe):
    m=bpy.data.materials.new('OwnerFinish_'+key);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;b=n.get('Principled BSDF')
    b.inputs['Base Color'].default_value=tuple(linear(v) for v in recipe['color'][:3])+(1,)
    b.inputs['Metallic'].default_value=recipe['metallic'];b.inputs['Roughness'].default_value=recipe['roughness']
    if recipe.get('untextured'):return m
    spec=catalog[recipe.get('catalog',key)];coord=n.new('ShaderNodeTexCoord');scale=n.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];l.new(coord.outputs['Object'],scale.inputs[0])
    for i,target in enumerate(['Base Color','Roughness','Normal']):
        t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True);t.projection='BOX';t.projection_blend=.2
        if i:t.image.colorspace_settings.name='Non-Color'
        l.new(scale.outputs[0],t.inputs[0])
        if i==0:
            mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=tuple(linear(v) for v in recipe['color'][:3])+(1,);l.new(t.outputs[0],mix.inputs[1]);l.new(mix.outputs[0],b.inputs[target])
            if 'pigment' in recipe:
                sample=t.image.copy();sample.scale(32,32);mean=np.array(sample.pixels[:]).reshape(32,32,4)[:,:,:3].mean((0,1));bpy.data.images.remove(sample)
                contrast=n.new('ShaderNodeMixRGB');contrast.inputs[0].default_value=recipe['pigment'];contrast.inputs[1].default_value=(*mean,1);l.new(t.outputs[0],contrast.inputs[2]);l.new(contrast.outputs[0],mix.inputs[1])
        elif i==1:
            mult=n.new('ShaderNodeMath');mult.operation='MULTIPLY';mult.inputs[1].default_value=recipe['roughness'];l.new(t.outputs[0],mult.inputs[0]);l.new(mult.outputs[0],b.inputs[target])
        else:
            norm=n.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=recipe['normal'];l.new(t.outputs[0],norm.inputs['Color']);l.new(norm.outputs[0],b.inputs[target])
    return m

def main():
    views=[]
    for family,scope in [('boiler_body','heating'),('bath_lavatory','bath'),('bath_shower','bath'),('bath_water_closet','bath')]:
        path=ROOT/'art/blender'/(family+'.blend')
        with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
        objects=[o for o in dst.objects if o is not None]
        for o in objects:
            scene.collection.objects.link(o);o.hide_render=False
            if o.type=='MESH':
                for slot in o.material_slots:
                    if not slot.material:continue
                    key=slot.material.name.split('.')[0]
                    if family=='boiler_body':key={'Iron':'cast_iron','Steel':'metal','Jacket':'linen'}.get(key,key)
                    if key=='shower_duck':key='linen'
                    if key in profiles[scope]:slot.material=material(key,profiles[scope][key])
        # Show the drawn curtain only; both alternative poses remain in the source.
        for o in objects:
            ancestor=o
            while ancestor:
                if 'Gathered' in ancestor.name:o.hide_render=True
                ancestor=ancestor.parent
        bpy.context.view_layer.update()
        points=[o.matrix_world@Vector(c) for o in objects if o.type=='MESH' and not o.hide_render for c in o.bound_box]
        low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)*.5;span=max(high-low)
        bpy.ops.object.camera_add(location=center+Vector((1.35,2.5,.85))*span);camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=span*1.35;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
        lights=[]
        for offset,power in [((-1.3,-1.5,2),180),((1.5,1.2,1.3),130)]:
            bpy.ops.object.light_add(type='AREA',location=center+Vector(offset)*span);o=bpy.context.object;o.data.energy=power*span*span;o.data.size=span*1.6;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler();lights.append(o)
        scene.render.filepath=str(OUT/(family+'.png'));bpy.ops.render.render(write_still=True)
        views.append({'family':family,'source':path.relative_to(ROOT).as_posix(),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'scope':'Retained native geometry with shared V2 finish profiles; source controls and independent state geometry reviewed in runtime.'})
        for o in objects+[camera,*lights]:bpy.data.objects.remove(o,do_unlink=True)
    (OUT/'review.json').write_text(json.dumps({'evidence_class':'INERT','views':views},indent=2)+'\n',newline='\n')

if __name__=="__main__":main()
