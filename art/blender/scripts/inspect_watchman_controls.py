"""Native detector cover open/closed review; no runtime acceptance."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=ROOT/'tmp/v2-patrol-20261013/native';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/service_instruments.blend'))
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
for obj in bpy.data.collections['Composed review'].objects:obj.hide_render=obj.get('actor')!='M03' or obj.hide_render
plan=json.loads((ROOT/'art/data/service_instruments/source_plan.json').read_text(encoding='utf-8'))
actor=next(a for a in plan['actors'] if a['actor']=='F01_WATCHMAN_DETECTOR')
glass=next(p for p in actor['meshes'] if p['name']=='GlassLid')
parts=[bpy.data.objects['M03_DoorFrame_review'],bpy.data.objects[f'M03_P{glass["index"]:03d}_review']]
original=[o.matrix_world.copy() for o in parts]
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=20
scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Detector review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.4,.44,.5,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'
center=C.to_3x3()@Vector((0,.20,.1))
for at,power in [((.8,1,1.5),100),((-.7,.5,.8),60)]:
 bpy.ops.object.light_add(type='AREA',location=C.to_3x3()@Vector(at));lamp=bpy.context.object
 lamp.data.energy=power;lamp.data.size=1;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=C.to_3x3()@Vector((.45,.32,.85)));camera=bpy.context.object
camera.data.lens=45;camera.data.clip_start=.01
camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
pivot=Matrix.Translation(Vector((-.159,.20,.195)))
def surface(obj):
 obj.data.calc_loop_triangles()
 return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[tuple(t.vertices) for t in obj.data.loop_triangles],all_triangles=True)
# Full fitted cover sweep against the retained internal mechanism. Cabinet
# rebates/hinge contacts are intentional and checked separately by rendering.
inside=[bpy.data.objects[f'M03_P{p["index"]:03d}_review'] for p in actor['meshes'] if 5<=p['index']<=48 and p['index']!=43 and p['visible']]
inside.extend(o for o in bpy.data.collections['Closed construction'].objects if o.type=='MESH' and o.name.startswith('M03_attachments__') and 'Hinge' not in o.name)
fixed=[(o.name,surface(o)) for o in inside]
glass_back=min((C.inverted()@parts[1].matrix_world@v.co).z for v in parts[1].data.vertices)
mechanism_front=max((C.inverted()@o.matrix_world@v.co).z for o in inside for v in o.data.vertices)
assert glass_back-mechanism_front>.0015,(glass_back,mechanism_front)
collisions=[]
for i in range(121):
 angle=-1.65*i/120
 transform=C@pivot@Matrix.Rotation(angle,4,'Y')@pivot.inverted()@C.inverted()
 for obj,basis in zip(parts,original):
  obj.matrix_world=transform@basis
  moving=surface(obj)
  for name,target in fixed:
   if moving.overlap(target):collisions.append({'pose':i,'moving':obj.name,'fixed':name})
(out/'detector_cover_sweep.json').write_text(json.dumps({'evidence_class':'INERT','sampled_poses':121,'closed_glass_clearance_m':glass_back-mechanism_front,'collisions':collisions},indent=2),encoding='utf-8')
assert not collisions,collisions[:10]
plunger=bpy.data.objects['M03_P047_review']
guide=bpy.data.objects['M03_P048_review']
home=plunger.matrix_world.copy()
guide_surface=surface(guide)
guide_z=[(C.inverted()@guide.matrix_world@v.co).z for v in guide.data.vertices]
engagement=[]
for i in range(121):
 travel=.024*i/120
 plunger.matrix_world=C@Matrix.Translation(Vector((0,0,-travel)))@C.inverted()@home
 positions=[(C.inverted()@plunger.matrix_world@v.co).z for v in plunger.data.vertices]
 depth=min(max(positions),max(guide_z))-max(min(positions),min(guide_z))
 assert depth>.0099,depth
 assert not surface(plunger).overlap(guide_surface),'plunger touches bored guide'
 engagement.append(depth)
plunger.matrix_world=home
(out/'detector_punch_guide.json').write_text(json.dumps({'evidence_class':'INERT','sampled_poses':121,'minimum_guide_engagement_m':min(engagement),'plunger_guide_collisions':0},indent=2),encoding='utf-8')
for label,angle in [('closed',0),('open',-1.65)]:
 transform=C@pivot@Matrix.Rotation(angle,4,'Y')@pivot.inverted()@C.inverted()
 for obj,basis in zip(parts,original):obj.matrix_world=transform@basis
 bpy.context.view_layer.update()
 scene.render.filepath=str(out/f'detector_{label}.png');bpy.ops.render.render(write_still=True)
print('DETECTOR NATIVE REVIEW rendered closed and open cover')
