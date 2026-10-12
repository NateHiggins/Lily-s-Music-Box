"""Review saved faucet families with catalogue PBR and retained sink envelopes."""
from pathlib import Path
import ast,json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-kitchen-sinks-20261012/native';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/kitchen_faucet.blend'))
sets=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
source=Path(__file__).with_name('inspect_domestic_door_leaves.py');tree=ast.parse(source.read_text(encoding='utf-8'))
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='material'],type_ignores=[]),str(source),'exec'))
skins={key:material(key,(1,1,1)) for key in ['faucet_nickel','porcelain_fixture','cast_iron']}
for obj in bpy.context.scene.objects:
    if obj.type=='MESH':
        key=obj.data.materials[0].name;obj.data.materials.clear();obj.data.materials.append(skins[key])
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('KitchenReview');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.3
for at,power,size in [((-1,-2,3),110,2),((2,0,2),95,1)]:
    d=bpy.data.lights.new('Softbox','AREA');d.energy=power;d.size=size;o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('ReviewCamera');c=bpy.data.objects.new(d.name,d);scene.collection.objects.link(c);scene.camera=c;d.lens=60;d.clip_start=.001
def visible(name,on):
    for o in bpy.data.objects[name].children_recursive:o.hide_render=not on
visible('IndependentFrame',False)

for family in ['Standard','Compact']:
    visible('Standard',family=='Standard');visible('Compact',family=='Compact');visible('StandardBearers',False)
    c.location=(.40,.65,1.33);c.rotation_euler=(Vector((0,-.12,1.08))-c.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(family+'.png'));bpy.ops.render.render(write_still=True)
visible('Standard',True);visible('Compact',False);visible('StandardBearers',True);visible('IndependentFrame',True)
# Neutral envelope reproduces the retained procedural basin and drainboard.
for at,size in [((0,.76,0),(.54,.018,.39)),((0,.897,.0),(.0,.0,.0)),
                ((-.279,.825,0),(.028,.15,.41)),((.279,.825,0),(.028,.15,.41)),
                ((0,.825,-.204),(.56,.15,.028)),((0,.825,.204),(.56,.15,.028)),
                ((0,.9,-.23),(.645,.025,.035)),((0,.9,.23),(.645,.025,.035)),
                ((-.305,.9,0),(.035,.025,.46)),((.305,.9,0),(.035,.025,.46)),
                ((.515,.897,0),(.42,.026,.46)),((0,.975,.226),(.64,.16,.035))]:
    if size[0]==0:continue
    bpy.ops.mesh.primitive_cube_add(size=1,location=(at[0],-at[2],at[1]));o=bpy.context.object;o.name='RetainedBasinEnvelope';o.dimensions=(size[0],size[2],size[1]);o.data.materials.append(skins['porcelain_fixture'])
c.location=(1.5,2.1,1.7);c.rotation_euler=(Vector((.2,0,.7))-c.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'bearing_assembly.png');bpy.ops.render.render(write_still=True)
for o in list(bpy.context.scene.objects):
    if o.name.startswith('RetainedBasinEnvelope'):bpy.data.objects.remove(o,do_unlink=True)
visible('Standard',False);visible('StandardBearers',False);visible('IndependentFrame',False)
visible('Compact',True)
with bpy.data.libraries.load(str(ROOT/'art/blender/domestic_storage.blend'),link=False) as (src,dst):
    dst.objects=['CounterCompact__metal']
for obj in dst.objects:scene.collection.objects.link(obj);obj.hide_render=False
c.location=(1.2,1.9,1.5);c.rotation_euler=(Vector((0,0,.65))-c.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'compact_frame.png');bpy.ops.render.render(write_still=True)
