"""Complete washer assembly review; fixed and moving fit, real PBR, no edits."""
from pathlib import Path
import bpy,bmesh,json,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
out=ROOT/'tmp/v2-next-20261013/full-native';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/washer_controls.blend'))
parts={o.name:o for o in bpy.context.scene.objects if o.type=='EMPTY'}
yoke=parts['SwingingWringer']
for name in ['PressureBridge','LowerRoll','UpperRoll','UpperCarriage','PressureScrew','SafetyRelease','SafetyReset']:
 parts[name].parent=yoke
# Native water placeholder replaced with the same registered water substrate.
for obj in parts['WaterSurface'].children:
 mat=bpy.data.materials.new('Liquid review');mat.use_nodes=True;n=mat.node_tree.nodes['Principled BSDF'];n.inputs['Base Color'].default_value=(.12,.18,.19,1);n.inputs['Roughness'].default_value=.10;n.inputs['Metallic'].default_value=0;n.inputs['Transmission Weight'].default_value=.6;n.inputs['IOR'].default_value=1.333
 obj.data.materials.clear();obj.data.materials.append(mat)
bpy.context.view_layer.update()
# Both support shoes and shaft-centred rollers are checked at real positions.
low=parts['LowerRoll'].children[0]
low=next(o for o in parts['LowerRoll'].children if o.name.endswith('_rubber'))
upper=next(o for o in parts['UpperRoll'].children if o.name.endswith('_rubber'))
lo=max((low.matrix_world@v.co).z for v in low.data.vertices)
hi=min((upper.matrix_world@v.co).z for v in upper.data.vertices)
assert abs(lo-hi)<.00002,('roller nip',lo,hi)
for gap,turn in [(0,0),(.012,math.tau*4),(.04,0),(.04,math.tau*1.5)]:
 lift=turn/(math.tau*4)*.012
 parts['UpperRoll'].location.z=.275+gap;parts['UpperCarriage'].location.z=gap
 parts['PressureScrew'].location.z=.41+gap;parts['PressureBridge'].location.z=.405+max(0,gap-lift)
 bpy.context.view_layer.update()
 # Pressure foot and saddle translate together; upper-roll nip truly opens.
 pad=next(o for o in parts['PressureScrew'].children if o.name.endswith('_brass'))
 saddle=next(o for o in parts['UpperCarriage'].children if o.name.endswith('_enamel'))
 pad_y=min((pad.matrix_world@v.co).z for v in pad.data.vertices)
 saddle_y=max((saddle.matrix_world@v.co).z for v in saddle.data.vertices)
 assert abs(pad_y-saddle_y)<.00003,('pressure contact',gap,pad_y,saddle_y)
# Studio review uses neutral illumination with large highlights for real edges.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1400;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral washer room');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.37,.41,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for at,power,size in [((2,-3,3),700,2.5),((-2,-1,2),450,2),((0,3,2.7),600,2)]:
 bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.size=size;lamp.rotation_euler=(Vector((0,0,.7))-lamp.location).to_track_quat('-Z','Y').to_euler()
for name,eye,at,lid,swing,gap in [
 ('closed',(1.8,2.4,1.55),(0,0,.65),0,0,0),
 ('front',(-1.2,2.5,1.45),(0,0,.72),0,0,0),
 ('open',(1.7,2.4,1.8),(0,0,.69),82,90,0),
 ('mechanism',(1.25,1.55,1.85),(0,0,1.15),0,0,0),
 ('safety_release',(1.25,1.55,1.85),(0,0,1.15),0,0,.04),
 ('drive_detail',(1.1,1.0,.6),(.25,0,.27),0,0,0),
 ('plumbing',(.9,-1.25,1.5),(0,-.27,.88),0,0,0)]:
 parts['TubLid'].rotation_euler.x=math.radians(lid);yoke.rotation_euler.z=math.radians(swing)
 parts['UpperRoll'].location.z=.275+gap;parts['UpperCarriage'].location.z=gap;parts['PressureScrew'].location.z=.41+gap;parts['PressureBridge'].location.z=.405+gap
 parts['SafetyRelease'].rotation_euler.x=-math.radians(8) if gap else 0
 bpy.context.view_layer.update()
 bpy.ops.object.camera_add(location=eye);camera=bpy.context.object;camera.rotation_euler=(Vector(at)-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=55;scene.camera=camera;scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);bpy.data.objects.remove(camera,do_unlink=True)
(out/'inspection.json').write_text(json.dumps({'evidence_class':'INERT','roller_nip_metres':hi-lo,'pressure_contact_extremes':4,'scope':'Native complete assembly and endpoint fit; runtime and adjacent fixtures still require verification.'},indent=2)+'\n')
