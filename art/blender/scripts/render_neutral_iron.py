"""Review the unmodified generated plate as a tiled PBR surface in Blender."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector

root=Path(__file__).resolve().parents[3]
out=root/'art/renders/orison_v2/iron_neutral_20261008'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=48
scene.render.resolution_x=1400;scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.32,.32,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'
mat=bpy.data.materials.new('iron_neutral');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=nodes['Principled BSDF']
bsdf.inputs['Metallic'].default_value=.65
for filename,target in [('albedo','Base Color'),('roughness','Roughness'),('normal','Normal')]:
    tex=nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(root/'art/textures/ai_materials/iron_neutral'/(filename+'.png')))
    if filename!='albedo':tex.image.colorspace_settings.name='Non-Color'
    if filename=='normal':
        normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color'])
        links.new(normal.outputs[0],bsdf.inputs[target])
    else:links.new(tex.outputs['Color'],bsdf.inputs[target])

# A single 0.8 m plane with four repeats exposes both tile joins directly.
bpy.ops.mesh.primitive_plane_add(size=.8,location=(-.27,0,.011))
plate=bpy.context.object;plate.name='Four repeats at 0.4 metres per tile'
for loop in plate.data.uv_layers.active.data:loop.uv*=2
plate.data.materials.append(mat)
bpy.ops.mesh.primitive_uv_sphere_add(segments=96,ring_count=64,radius=.17,location=(.40,.06,.18))
sphere=bpy.context.object;sphere.data.materials.append(mat)
for polygon in sphere.data.polygons:polygon.use_smooth=True
for loop in sphere.data.uv_layers.active.data:loop.uv.x*=math.tau*.17/.4;loop.uv.y*=math.pi*.17/.4
bpy.ops.mesh.primitive_cube_add(size=1,location=(.39,-.25,.04))
body=bpy.context.object;body.dimensions=(.34,.15,.06)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bevel=body.modifiers.new('Machined edge','BEVEL');bevel.width=.006;bevel.segments=4
bpy.ops.object.modifier_apply(modifier=bevel.name)
body.data.materials.append(mat)
for polygon in body.data.polygons:
    axis=max(range(3),key=lambda i:abs(polygon.normal[i]));axes=[i for i in range(3) if i!=axis]
    for index in polygon.loop_indices:
        co=body.data.vertices[body.data.loops[index].vertex_index].co
        body.data.uv_layers.active.data[index].uv=(co[axes[0]]/.4,co[axes[1]]/.4)

floor=bpy.data.materials.new('Neutral backing');floor.diffuse_color=(.20,.20,.20,1)
bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(floor)
for at,energy,size in [((-.45,-.55,1.2),120,1.2),((.6,.65,.9),65,.7)]:
    bpy.ops.object.light_add(type='AREA',location=at)
    light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1.05,-1.45,1.60))
camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=1.35
camera.rotation_euler=(Vector((0,0,.035))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera=camera;scene.render.filepath=str(out/'neutral_iron_review.png')
bpy.ops.render.render(write_still=True)
(out/'review.json').write_text(json.dumps({'evidence_class':'INERT','material':'iron_neutral',
    'tile_metres':.4,'plane_repeats':[2,2],'metallic':.65,'normal_strength':1,
    'lighting':'two neutral area lights, neutral world, AgX',
    'scope':'Material appearance, tile boundaries and curved/flat response; no runtime proof.'},indent=2)+'\n',newline='\n')
