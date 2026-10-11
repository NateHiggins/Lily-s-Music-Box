from pathlib import Path
import bpy,json,math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-window-treatments-20261011/native';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/window_treatments.blend'))
stock={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
metrics={}
for name,o in stock.items():
 o.data.calc_loop_triangles();uv=o.data.uv_layers.active;bad=0
 for tri in o.data.loop_triangles:
  a,b,c=[uv.data[i].uv for i in tri.loops]
  if tri.area>1e-12 and abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))<1e-10:bad+=1
 metrics[name]={'triangles':len(o.data.loop_triangles),'degenerate_uv':bad}
(OUT/'native-uv.json').write_text(json.dumps(metrics,indent=2)+'\n')
cat=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for o in stock.values():o.hide_render=True

def part(name,at,scale,key):
 source=stock[name];o=source.copy();o.data=source.data.copy();bpy.context.collection.objects.link(o);o.hide_render=False;o.location=at;o.scale=scale
 spec=cat[key];mat=bpy.data.materials.new(key);mat.use_nodes=True;o.data.materials.clear();o.data.materials.append(mat);p=mat.node_tree.nodes['Principled BSDF']
 for i,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
  if i:tex.image.colorspace_settings.name='Non-Color'
  if i==2:
   nm=mat.node_tree.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.12;mat.node_tree.links.new(tex.outputs['Color'],nm.inputs['Color']);mat.node_tree.links.new(nm.outputs['Normal'],p.inputs[socket])
  else:mat.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
 for loop in o.data.uv_layers.active.data:
  loop.uv.x*=scale[0];loop.uv.y*=scale[2] if name=='PleatedSewnPanel' else 1
  if key=='trim':loop.uv.x,loop.uv.y=loop.uv.y,loop.uv.x
 return o
part('HeadRail',(0,0,2.1),(1.45,1,1),'trim')
part('BottomRail',(0,0,.68),(1.41,1,1),'trim')
for i in range(32):
 o=part('CrownedWoodSlat',(0,0,2.045-i*.043),(1.41,1,1),'trim');o.rotation_euler.x=math.radians(35)
for x in [-.42,.42]:part('CordStock',(x,0,1.38),(1,1,1.41),'linen')
for x in [-.72,.72]:part('PleatedSewnPanel',(x,-.13,2.17),(.32,1,1.50),'linen')
for pos,power in [((0,-3,4),450),((-3,-1,2),200)]:
 d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=3;o=bpy.data.objects.new('Softbox',d);bpy.context.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,1.4))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Review');o=bpy.data.objects.new('Review',d);bpy.context.collection.objects.link(o);o.location=(1.5,-4,2.5);o.rotation_euler=(Vector((0,0,1.4))-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=2.5
s=bpy.context.scene;s.camera=o;s.render.engine='CYCLES';s.cycles.samples=24;s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.15,.15,1);s.render.resolution_x=1100;s.render.resolution_y=900;s.render.resolution_percentage=100;s.render.filepath=str(OUT/'stock.png');bpy.ops.render.render(write_still=True)
