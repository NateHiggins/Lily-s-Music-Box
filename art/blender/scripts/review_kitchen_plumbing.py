"""Native closed-stock and open-waste-bore review before composed captures."""
from pathlib import Path
import json,math
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parents[3];out=root/'tmp/v2-kitchen-plumbing-20261019/native'
bpy.ops.wm.open_mainfile(filepath=str(root/'art/blender/kitchen_plumbing.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Stock inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.50,.58,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for at,power in [((1,-2,2),220),((-1,.5,1.3),160)]:
    bpy.ops.object.light_add(type='AREA',location=at);o=bpy.context.object;o.data.energy=power;o.data.size=1.5;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
report=json.loads((root/'art/blender/kitchen_plumbing_construction.json').read_text());failures=[];checks=0
draws=[o for o in scene.objects if o.type=='MESH' and '__' in o.name]
for profile in report['profiles']:
    if profile['kind']!='waste':continue
    selected=[o for o in draws if o.name.startswith(profile['template']+'__')]
    vertices=[];faces=[]
    for obj in selected:
        offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        faces.extend(tuple(offset+i for i in polygon.vertices) for polygon in obj.data.polygons)
    bvh=BVHTree.FromPolygons(vertices,faces)
    points=[Vector((q[0],-q[2],q[1])) for q in profile['points']]
    for a,b in zip(points,points[1:]):
        checks+=1;direction=(b-a).normalized();hit=bvh.ray_cast(a+direction*.000001,direction,(b-a).length-.000002)
        if hit[0] is not None:failures.append({'template':profile['template'],'blocked_waste_bore':list(hit[0])})
images=[]
for identity in ['Standard410','Compact430Timber']:
    selected=[o for o in draws if o.name.startswith(identity+'__')]
    for obj in draws:obj.hide_render=obj not in selected
    template=next(row for row in json.loads((root/'art/data/kitchen_plumbing/source_plan.json').read_text())['templates'] if row['id']==identity)
    copies=[]
    for wheel in [o for o in draws if o.name.startswith('StopWheel__')]:
        for x in [-.095,.095]:
            obj=wheel.copy();scene.collection.objects.link(obj);obj.hide_render=False;obj.location=Vector((x,-(template['riser_z']-.065),.345));copies.append(obj)
    target=Vector((0,-.16,.66));eye=target+Vector((.85,-1.6,.30))
    bpy.ops.object.camera_add(location=eye);cam=bpy.context.object;cam.data.lens=57;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
    scene.render.filepath=str(out/(identity+'.png'));bpy.ops.render.render(write_still=True);images.append(identity+'.png')
    bpy.data.objects.remove(cam,do_unlink=True)
    for obj in copies:bpy.data.objects.remove(obj,do_unlink=True)
(out/'review.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Native waste bores and posed source services; water-stop internals and installed collision are separate.','bore_segments':checks,'failures':failures,'images':images},indent=2)+'\n')
assert not failures,failures
