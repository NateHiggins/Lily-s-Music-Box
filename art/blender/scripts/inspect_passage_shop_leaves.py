"""Batch native joinery/handle/floor review with the installed custom PBR maps."""
from pathlib import Path
import ast, json, os
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(os.environ.get('PASSAGE_SHOP_REVIEW_DIR',str(ROOT/'art/reviews/v2_shop_door_repair_20261021/native')));OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/passage_shop_leaves.blend'))
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf8'))['materials']
source=Path(__file__).with_name('inspect_domestic_door_leaves.py')
tree=ast.parse(source.read_text(encoding='utf8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='material'],type_ignores=[]),str(source),'exec'))
mats={'oak_quartered':material('oak_quartered',(.42,.30,.20)),
      'door_brass':material('door_brass',(1,1,1)),
      'glass_drawn_expressive':material('glass_drawn_expressive',(1,1,1))}
glass=mats['glass_drawn_expressive'].node_tree.nodes['Principled BSDF']
glass.inputs['Transmission Weight'].default_value=1
glass.inputs['IOR'].default_value=1.52
for node in mats['oak_quartered'].node_tree.nodes:
 if node.type=='VECT_MATH' and node.operation=='SCALE':node.inputs['Scale'].default_value=1/(sets['oak_quartered']['meters_per_tile']*.8)
for node in mats['glass_drawn_expressive'].node_tree.nodes:
 if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=1.0
for obj in list(bpy.context.scene.objects): obj.data.materials.append(mats[obj['material_key']])
# Original terrazzo datum, independent of the fitted 16 mm lower timber edge.
bpy.ops.mesh.primitive_cube_add(size=1,location=(.475,0,-.04))
floor=bpy.context.object;floor.name='OriginalFloorDatum';floor.dimensions=(1.6,1.2,.10)
floor.data.materials.append(material('terrazzo',(1,1,1)))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=1000
scene.world=bpy.data.worlds.new('NativeReview');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
for at,power,size in [((-1,-2,3),130,2),((2,1,2),100,1)]:
 data=bpy.data.lights.new('Softbox','AREA');data.energy=power;data.size=size
 light=bpy.data.objects.new(data.name,data);scene.collection.objects.link(light);light.location=at
 light.rotation_euler=(Vector((.475,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera);scene.camera=camera;data.lens=55;data.clip_start=.001
for name,at,target in [('leaf',(1.25,-3.8,1.55),(.475,0,1.05)),('pull',(1.08,-.65,1.12),(.885,0,1.03)),('clearance',(.6,-.42,.09),(.475,0,.02))]:
 camera.location=at;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
