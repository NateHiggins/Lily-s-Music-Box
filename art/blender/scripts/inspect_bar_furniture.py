"""Check native key clearances, passive pedal bearing and assembled drapes."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/bar_furniture.blend'))
bpy.context.view_layer.update()
stocks=list(bpy.data.collections['ClosedConstruction'].objects)
def tree(obj):
    return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons],epsilon=0.)
def intersections(a,b):return len(tree(a).overlap(tree(b)))
keys=[o for o in stocks if '__Natural' in o.name or '__Accidental' in o.name]
assert len(keys)==73 and sum('__Natural' in o.name for o in keys)==43
bad=[]
for i,a in enumerate(keys):
    for b in keys[i+1:]:
        if intersections(a,b):bad.append([a.name,b.name])
for a in keys:
    for b in stocks:
        if any(t in b.name for t in ['RaisedFallboard','KeyCheek','KeySlip']) and intersections(a,b):bad.append([a.name,b.name])
assert not bad,bad
pedals=[o for o in stocks if '__PedalToe' in o.name];assert len(pedals)==2
assert all(min(v.co.z for v in o.data.vertices)>.061 for o in pedals)
puncture_depths=[]
for i in range(7):
    for band in [0,2]:
        obj=next(o for o in stocks if o.name=='DartsCabinet__ScoringField'+str(i)+'_'+str(band))
        local=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[p.vertices[:] for p in obj.data.polygons])
        for mark in range(3):
            angle=i*math.tau/7+(.11,.15,-.09)[mark]
            radius=(.071 if band==0 else .135)+(.003,-.006,.009)[mark]
            hit=local.ray_cast(Vector((-radius*math.sin(angle),.10,.62+radius*math.cos(angle))),Vector((0,-1,0)))
            assert hit[0] is not None
            depth=.094-hit[0].y;assert .001<depth<.0014,depth
            puncture_depths.append(depth)
new_draws=list(bpy.data.collections['RuntimePartitions'].objects)
with bpy.data.libraries.load(str(ROOT/'art/blender/bar_stage.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if n.startswith('Stage__')]
stage=list(dst.objects)
for o in stage:bpy.context.scene.collection.objects.link(o)
bpy.context.view_layer.update()
context_crossings=[]
for a in new_draws:
    if not a.name.startswith(('Piano__','Microphone__')):continue
    for b in stage:
        if intersections(a,b):context_crossings.append([a.name,b.name])
assert not context_crossings,context_crossings
with bpy.data.libraries.load(str(ROOT/'art/blender/bar_gallery.blend'),link=False) as (src,dst):dst.objects=[n for n in src.objects if n.startswith('Gallery__')]
gallery=list(dst.objects)
for o in gallery:bpy.context.scene.collection.objects.link(o);o.hide_render=True
bpy.context.view_layer.update()
gallery_crossings=[]
for a in new_draws:
    if not a.name.startswith(('DartsCabinet__','ScorePanel__')):continue
    for b in gallery:
        if intersections(a,b):gallery_crossings.append([a.name,b.name])
assert not gallery_crossings,gallery_crossings
for o in stage:o.hide_render=False
# Native stage context is read-only. The retained curtain/support source is
# appended for inspection, never exported into this family.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1400;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral stage inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.46,.48,1.);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
for o in new_draws:o.hide_render=not o.name.startswith(('Piano__','Microphone__'))
center=Vector((-.7,-37.15,-1.72))
bpy.ops.object.camera_add(location=center+Vector((1.8,4.9,1.2)));camera=bpy.context.object;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.lens=45;scene.camera=camera
for delta,energy in [((-1,2,3),650),((2,1,1),300)]:
    bpy.ops.object.light_add(type='AREA',location=center+Vector(delta));lamp=bpy.context.object;lamp.data.energy=energy;lamp.data.size=4.;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
out=ROOT/'tmp/v2-improvement/bar-furniture-native';out.mkdir(parents=True,exist_ok=True)
scene.view_settings.view_transform='AgX';scene.render.filepath=str(out/'stage_context.png');bpy.ops.render.render(write_still=True)
result={'evidence_class':'INERT','keys':{'total':73,'naturals':43,'accidentals':30,'surface_crossings':bad},'pedals':{'count':2,'minimum_floor_clearance_m':min(min(v.co.z for v in o.data.vertices) for o in pedals)},'target_punctures':{'count':len(puncture_depths),'minimum_depth_m':min(puncture_depths),'maximum_depth_m':max(puncture_depths)},'drape_surface_crossings':context_crossings,'gallery_surface_crossings':gallery_crossings,'image':'stage_context.png','scope':'Native intersections only; runtime supplies physical bearing, approach and original input checks.'}
(out/'inspection.json').write_text(json.dumps(result,indent=2)+'\n')
print('BAR FURNITURE INSPECTION',result)
