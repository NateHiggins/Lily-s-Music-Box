"""Native switch travel/finish views, not game or circuit acceptance."""
from pathlib import Path
import bpy,bmesh,math,json
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=R/'tmp/v2-control-finish-20261017/light_switch_native';O.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'art/blender/light_switch.blend'))
checks=[]
for obj in bpy.context.scene.collection.objects:
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    checks.append({'name':obj.name,'closed':all(e.is_manifold for e in bm.edges),'volume':bm.calc_volume(signed=True)});bm.free()
    assert checks[-1]['closed'] and checks[-1]['volume']>0,checks[-1]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=64;scene.cycles.use_denoising=True
scene.render.resolution_x=700;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral switch room');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.27,.30,.34,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
def p(v):return Vector((v[0],-v[2],v[1]))
target=p((0,0,-.025))
for at,power,size in [((.10,.15,-.20),3,.12),((-.15,-.06,-.10),1,.15)]:
    bpy.ops.object.light_add(type='AREA',location=p(at));light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=p((.12,.08,-.36)));camera=bpy.context.object
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=55;scene.camera=camera
for name,angle in [('off',-22),('on',22)]:
    bpy.data.objects['TogglePivot'].rotation_euler.x=math.radians(angle)
    scene.render.filepath=str(O/(name+'.png'));bpy.ops.render.render(write_still=True)
(O/'review.json').write_text(json.dumps({'evidence_class':'INERT','stocks':checks,'scope':'Closed native switch stock and both posed finish views; no circuit or player-input proof.'},indent=2)+'\n',newline='\n')
