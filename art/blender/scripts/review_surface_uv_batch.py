"""Render the changed native stock with catalogue maps for UV review."""
from pathlib import Path
import json,math,os
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-surfaces-20261011/native-review';OUT.mkdir(parents=True,exist_ok=True)
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
assets=['props/basement_airer.glb','props/breeching.glb','props/stair_ironwork_service.glb','props/stair_ironwork_public.glb','props/bedding.glb','props/boiler_pipework.glb','props/roof_coping.glb','building/v2_lift_drive.glb','building/v2_coal_delivery.glb','props/bath_lavatory.glb','props/bath_shower.glb','props/bath_towel.glb','props/radiator_section.glb','props/boiler_body.glb','props/bookcase_lift_door.glb']
aliases={'Stair Iron':'iron_neutral','Rail Steel':'nickel_plated','Handrail Wood':'wood_dark','Frame':'wood_dark','Mattress':'linen','Blanket':'fabric_warm','Pillows':'linen','iron':'iron_neutral','steel':'nickel_plated','timber':'wood_dark','cast_iron':'iron_neutral','metal':'iron_neutral','CastSection':'iron_neutral','Hearth':'brick','Iron':'iron_neutral','Jacket':'iron_neutral','Lining':'brick','LiveCoal':'soot','Soot':'soot','Steel':'nickel_plated','glassish':'milk_glass'}
if os.environ.get('SURFACE_REVIEW_ASSETS'):assets=json.loads(os.environ['SURFACE_REVIEW_ASSETS'])
for asset in assets:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'game/assets'/asset))
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH':continue
        if not obj.data.materials:obj.data.materials.append(bpy.data.materials.new('CastSection'))
        for mat in obj.data.materials:
            if mat is None:continue
            key=aliases.get(mat.name,mat.name)
            if key not in catalog:raise ValueError('Unreviewed material alias: '+mat.name)
            spec=catalog[key];mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear();output=nodes.new('ShaderNodeOutputMaterial');shader=nodes.new('ShaderNodeBsdfPrincipled');mat.node_tree.links.new(shader.outputs[0],output.inputs[0]);shader.inputs['Metallic'].default_value=spec['metallic']
            if mat.name=='glassish':
                spec=dict(spec,files=[spec['files'][0],'T_glass_rough.png','T_glass_normal.png'])
                shader.inputs['Transmission Weight'].default_value=1.;shader.inputs['IOR'].default_value=1.5
            coordinate=nodes.new('ShaderNodeTexCoord');scale=nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/spec['meters_per_tile'];mat.node_tree.links.new(coordinate.outputs['UV'],scale.inputs[0])
            for number,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
                texture=nodes.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][number]),check_existing=True)
                if number:texture.image.colorspace_settings.name='Non-Color'
                mat.node_tree.links.new(scale.outputs['Vector'],texture.inputs['Vector'])
                if number==2:
                    normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.35;mat.node_tree.links.new(texture.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],shader.inputs[socket])
                else:mat.node_tree.links.new(texture.outputs['Color'],shader.inputs[socket])
    bpy.context.view_layer.update()
    points=[obj.matrix_world@Vector(p) for obj in bpy.context.scene.objects if obj.type=='MESH' for p in obj.bound_box]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(low+high)/2;radius=max(high-low)
    camera_data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',camera_data);bpy.context.collection.objects.link(camera);camera.location=center+Vector((1.3,-1.7,1.1))*radius;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=radius*1.6;bpy.context.scene.camera=camera
    for offset,power,size in [((1,-1,2),150,2),((-1,-.5,1),90,2),((0,1,1.5),120,1)]:
        light_data=bpy.data.lights.new('ReviewLight','AREA');light_data.energy=power*radius*radius;light_data.shape='DISK';light_data.size=size*radius;light=bpy.data.objects.new('ReviewLight',light_data);bpy.context.collection.objects.link(light);light.location=center+Vector(offset)*radius;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.12,.12,1);scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/(Path(asset).stem+'.png'));bpy.ops.render.render(write_still=True)
print('NATIVE SURFACE REVIEW:',len(assets),'catalogue-bound images')
