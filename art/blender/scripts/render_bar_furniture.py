"""Close native views; no lighting or camera is exported to the game."""
from pathlib import Path
import bpy,json
from mathutils import Vector
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
out=ROOT/'tmp/v2-improvement/bar-furniture-native';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bar_furniture.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral construction review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.46,.48,1.)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.view_settings.view_transform='AgX'
draws=list(bpy.data.collections['RuntimePartitions'].objects);views=[]
for identity,label,offset in [('Piano','audience',(.6,2.1,.55)),('Piano','keys',(.75,1.65,1.3)),('Microphone','complete',(.5,-2.,.55)),('DartsCabinet','front',(2.1,.55,.4)),('DartsCabinet','oblique',(1.6,1.5,.7)),('DartsCabinet','target',(2.1,.15,.15)),('ScorePanel','front',(2.2,.3,.4))]:
    chosen=[o for o in draws if o.name.startswith(identity+'__')]
    for obj in draws:obj.hide_render=obj not in chosen
    bpy.context.view_layer.update()
    points=[o.matrix_world@v.co for o in chosen for v in o.data.vertices]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(lo+hi)*.5;span=max(hi-lo)
    if label=='target':center=Vector((-11.406,-33,-1.07));span=.50
    bpy.ops.object.camera_add(location=center+Vector(offset)*span);camera=bpy.context.object;camera.data.lens=52;camera.data.clip_start=.001;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
    lights=[]
    for delta,energy in [((-1,1.5,2.),180),((1,-1,1),80)]:
        if identity in ['DartsCabinet','ScorePanel']:delta=(delta[1],delta[0],delta[2])
        bpy.ops.object.light_add(type='AREA',location=center+Vector(delta)*span);lamp=bpy.context.object;lamp.data.energy=energy*span*span;lamp.data.shape='DISK';lamp.data.size=span*2;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler();lights.append(lamp)
    filename=identity+'_'+label+'.png';scene.render.filepath=str(out/filename);bpy.ops.render.render(write_still=True)
    views.append({'assembly':identity,'file':filename,'scope':'Native construction and local calibrated catalogue finish; no lettering, control or game lighting added.'})
    for obj in [camera,*lights]:bpy.data.objects.remove(obj,do_unlink=True)
(out/'views.json').write_text(json.dumps({'evidence_class':'INERT','views':views},indent=2)+'\n')
