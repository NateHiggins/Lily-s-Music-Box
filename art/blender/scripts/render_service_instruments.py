"""Neutral construction review; original live lettering stays in Godot."""
from pathlib import Path
import bpy,math,json
from mathutils import Vector
r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=r/'tmp/v2-improvement/b1-native';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(r/'art/blender/service_instruments.blend'));scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral fabrication review');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.42,.46,.5,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
scene.view_settings.view_transform='AgX'
review=bpy.data.collections['Composed review']
# The six installed work lights share accepted cage stock; show that exact
# source around each newly fabricated attachment, rather than a mount alone.
with bpy.data.libraries.load(str(r/'art/blender/fixed_lighting.blend'),link=False) as (available,loaded):
 loaded.objects=[n for n in available.objects if n.startswith('cage_bulb_rise300__') and ('__Body_' in n or '__Bulb_' in n)]
assert loaded.objects,'accepted cage review objects missing'
for variant in ['AlleyEast','AlleyWest','Shed']:
 aid='WorkLight'+variant
 for original in [bpy.data.objects[aid],*loaded.objects]:
  obj=original.copy();obj.name=aid+'_'+original.name+'_review';review.objects.link(obj);obj['actor']=aid;obj.hide_render=False
draws=list(review.objects);initial={o:o.hide_render for o in draws};views=[]
for aid in ['M01','M02','M03','M04','M05','M06','M07','M08','M09','WorkLightAlleyEast','WorkLightAlleyWest','WorkLightShed']:
 chosen=[o for o in draws if o.get('actor')==aid and not initial[o]]
 for o in draws:o.hide_render=o not in chosen
 points=[o.matrix_world@v.co for o in chosen for v in o.data.vertices];lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)));center=(lo+hi)*.5;span=max(hi-lo)
 sign=1 if aid=='M08' else -1
 bpy.ops.object.camera_add(location=center+Vector((.38,sign*2.5,.55))*span);camera=bpy.context.object;camera.data.lens=60;camera.data.clip_start=.001;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
 lights=[]
 for offset,power in [((-1.2,sign*1.7,2.0),150),((1.2,sign,1),65)]:
  bpy.ops.object.light_add(type='AREA',location=center+Vector(offset)*span);lamp=bpy.context.object;lamp.data.energy=power*span*span;lamp.data.shape='DISK';lamp.data.size=span*2;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler();lights.append(lamp)
 scene.render.filepath=str(out/(aid+'.png'));bpy.ops.render.render(write_still=True)
 views.append({'id':aid,'file':aid+'.png','scope':'Native geometry and materials; lettering and live mechanism state remain in the composed runtime.'})
 for o in [camera,*lights]:bpy.data.objects.remove(o,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views},indent=2)+'\n')
