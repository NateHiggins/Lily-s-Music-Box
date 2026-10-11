"""Assemble the source pivots and current PBR stock before production review."""
from pathlib import Path
import json,math,bpy
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-next-batch-20261011/native';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/watch_stations.blend'))
stocks={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
for o in stocks.values():o.hide_render=True
catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
for name,key in [(o.name,o.data.materials[0].name) for o in stocks.values()]:
 o=stocks[name];spec=catalog[key];mat=bpy.data.materials.new(key+'_review');mat.use_nodes=True
 o.data.materials.clear();o.data.materials.append(mat);p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Metallic'].default_value=spec['metallic']
 for i,socket in [(0,'Base Color'),(1,'Roughness'),(2,'Normal')]:
  tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/spec['files'][i]),check_existing=True)
  if i:tex.image.colorspace_settings.name='Non-Color'
  if i==2:
   n=mat.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.25;mat.node_tree.links.new(tex.outputs['Color'],n.inputs['Color']);mat.node_tree.links.new(n.outputs['Normal'],p.inputs[socket])
  else:mat.node_tree.links.new(tex.outputs['Color'],p.inputs[socket])
 for loop in o.data.uv_layers.active.data:loop.uv/=spec['meters_per_tile']
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def pose(at=(0,0,0),axis='Y',angle=0):return Matrix.Translation(Vector(at))@Matrix.Rotation(angle,4,axis)
made=[]
def part(name,at=(0,0,0),parent=None,axis='Y',angle=0):
 o=stocks[name].copy();o.data=stocks[name].data;bpy.context.collection.objects.link(o);o.hide_render=False
 o.matrix_world=C@((parent or Matrix.Identity(4))@pose(at,axis,angle))@C.inverted();made.append(o);return o
def assemble(opened,marked=False):
 for o in made:bpy.data.objects.remove(o,do_unlink=True)
 made.clear();part('StationCase',(0,.160,.013));part('CaseLining',(0,.160,.028));part('CaseBead',(0,.286,.122));part('StationConduit',(0,.352,.030))
 door=pose((-.108,.160,.118),angle=-1.15 if opened else 0)
 for name,at in [('DoorLeaf',(.108,0,0)),('DoorSash',(.108,.026,.004)),('StationPlate',(.108,.112,.009)),('LatchSpring',(.212,0,.006))]:part(name,at,door)
 part('DoorHandle',(.196,-.060,.014),door,'Z',math.pi*.5)
 for y in [-.1,0,.1]:part('HingeBarrel',(0,y,0),door)
 part('TourKeySocket',(-.062,.236,.074));part('SocketKeyway',(-.062,.236,.080))
 crank=pose((.052,.198,.084));part('CrankBoss',parent=crank,axis='X',angle=math.pi*.5);part('CrankArm',(0,.033,.006),crank);part('CrankGrip',(0,.056,.012),crank,'X',math.pi*.5)
 wheel=pose((-.030,.120,.076),'Z',-2.1 if marked else 0);part('WheelDisc',parent=wheel,axis='X',angle=math.pi*.5)
 for i in range(5):part('WheelTooth',(math.sin(.42*i)*.034,math.cos(.42*i)*.034,0),wheel,'Z',-.42*i)
 part('PawlArm',(.014 if marked else .030,.120,.082))
 drop=pose((.020,.108,.090),'Z',0 if marked else 1.35);part('DropFlag',(0,-.038,0),drop);part('DropFace',(0,-.038,.004),drop)
 # Glass plate uses the real aperture; no text is baked into any texture.
 bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object;o.dimensions=(.130,.004,.090);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.matrix_world=C@door@pose((.108,.026,.021))@C.inverted();made.append(o)
 glass=bpy.data.materials.new('ReviewGlazing');glass.use_nodes=True;p=glass.node_tree.nodes['Principled BSDF'];p.inputs['Transmission Weight'].default_value=1;p.inputs['Roughness'].default_value=.1;p.inputs['IOR'].default_value=1.5;o.data.materials.append(glass)
for at,power in [((1,-2,2),100),((-1,-1,1),45)]:
 d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=1;o=bpy.data.objects.new('Softbox',d);bpy.context.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,-.07,.18))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Review');o=bpy.data.objects.new('Review',d);bpy.context.collection.objects.link(o);o.location=(.6,-1.4,.6);o.rotation_euler=(Vector((-.015,-.06,.19))-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=.53
s=bpy.context.scene;s.camera=o;s.render.engine='CYCLES';s.cycles.samples=24;s.world=bpy.data.worlds.new('World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.15,.15,1);s.render.resolution_x=1000;s.render.resolution_y=1000;s.render.resolution_percentage=100
for opened,marked,name in [(False,False,'closed'),(True,False,'open_ready'),(True,True,'open_marked')]:
 assemble(opened,marked);s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
