from pathlib import Path
import bpy,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-millwork-weather-20261011/native';OUT.mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/millwork_profile.blend'))
keep=['WainscotBacking','WainscotFrame','WainscotCap','BeadedTrim']
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH' or obj.name not in keep:bpy.data.objects.remove(obj,do_unlink=True)
cat=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for obj in list(bpy.context.scene.objects):
 key='trim' if obj.name=='BeadedTrim' else 'wood_dark';spec=cat[key]
 sizes={'WainscotBacking':(2.4,.016,1.154),'WainscotFrame':(2.4,.036,.03),'WainscotCap':(2.4,.050,.04),'BeadedTrim':(2.4,.032,.14)}
 obj.scale=sizes[obj.name];obj.location=(0,0,{'WainscotBacking':.743,'WainscotFrame':1.255,'WainscotCap':1.34,'BeadedTrim':.07}[obj.name])
 for poly in obj.data.polygons:
  for loop in poly.loop_indices:
   uv=obj.data.uv_layers.active.data[loop].uv
   uv.x*=obj.scale.x;uv.y*=obj.scale.z
   if obj.name!='WainscotBacking':uv.x,uv.y=uv.y,uv.x
 mat=bpy.data.materials.new(key);mat.use_nodes=True;obj.data.materials.clear();obj.data.materials.append(mat)
 shader=mat.node_tree.nodes['Principled BSDF'];shader.inputs['Roughness'].default_value=.6
 for index,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][index]),check_existing=True)
  if index:tex.image.colorspace_settings.name='Non-Color'
  if index==2:
   nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.12;mat.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],shader.inputs[socket])
  else:mat.node_tree.links.new(tex.outputs['Color'],shader.inputs[socket])
# Duplicate stiles; align their UV long axis with the upright.
frame=bpy.data.objects['WainscotFrame']
for x in [-1.16,-.58,0,.58,1.16]:
 obj=frame.copy();obj.data=frame.data.copy();bpy.context.collection.objects.link(obj);obj.rotation_euler.y=-math.pi/2;obj.scale=(1.014,.036,.036);obj.location=(x,-.018,.733)
 for uv in obj.data.uv_layers.active.data:
  uv.uv.y *= 1.014/2.4
for offset,power in [((0,-3,4),550),((-3,-1,2),250)]:
 d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=3;o=bpy.data.objects.new('Softbox',d);bpy.context.collection.objects.link(o);o.location=offset;o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Review');o=bpy.data.objects.new('Review',d);bpy.context.collection.objects.link(o);o.location=(2,-3,1.8);o.rotation_euler=(Vector((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=3.1
s=bpy.context.scene;s.camera=o;s.render.engine='CYCLES';s.cycles.samples=32;s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.15,.15,1);s.render.resolution_x=1280;s.render.resolution_y=800;s.render.resolution_percentage=100;s.render.filepath=str(OUT/'millwork.png');bpy.ops.render.render(write_still=True)
