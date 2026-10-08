"""Measured native contacts and neutral reviews for the wet-cloth dossier pass."""
from pathlib import Path
import json,hashlib,sys,math
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from review_owner_service_finishes import material,profiles
OUT=ROOT/'tmp/v2-improvement/wet-cloth-native';OUT.mkdir(parents=True,exist_ok=True)
proof={'evidence_class':'INERT','checks':[],'views':[]}
def require(ok,label,**data):
    proof['checks'].append({'pass':bool(ok),'label':label,**data})
    assert ok,(label,data)
def tree(o):
    return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[tuple(f.vertices) for f in o.data.polygons])
def set_materials(group):
    cache={}
    for o in bpy.context.scene.objects:
        if o.type!='MESH':continue
        for slot in o.material_slots:
            key=slot.material.name.split('.')[0]
            if key=='shower_duck':key='linen'
            if key in profiles[group]:
                if key not in cache:cache[key]=material(key,profiles[group][key])
                slot.material=cache[key]
def render(label,center,offset,span):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Neutral light');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.34,.37,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    scene.view_settings.view_transform='AgX';center=Vector(center)
    bpy.ops.object.camera_add(location=center+Vector(offset));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=span;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
    lights=[]
    for pos,power,size in [((2,3,4),340,3),((-2,-1,3),250,2)]:
        bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler();lights.append(o)
    scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
    proof['views'].append(label+'.png')
    for o in [camera,*lights]:bpy.data.objects.remove(o,do_unlink=True)

native=ROOT/'art/blender/basement_airer.blend';bpy.ops.wm.open_mainfile(filepath=str(native));set_materials('airer')
# Every authored foot bears at zero; cloth underside touches the actual lath.
for o in bpy.context.scene.objects:
    if 'Foot' in o.name:
        low=min((o.matrix_world@v.co).z for v in o.data.vertices)
        require(abs(low)<.00003,'airer floor bearing',name=o.name,z=low)
for i,(x,z) in enumerate([(-.31,-.11),(.20,.11),(.43,-.11)]):
    cloth=bpy.data.objects[f'Cloth{i}'];lath=bpy.data.objects[f'Lath{z}'];ct=tree(cloth);lt=tree(lath)
    for dx in [-.025,0,.025]:
        start=Vector((x+dx,-z,.016));hit=ct.ray_cast(start,Vector((0,0,1)),.010)[0]
        support=lt.ray_cast(Vector((x+dx,-z,.023)),Vector((0,0,-1)),.010)[0]
        require(hit is not None and support is not None and abs(hit.z-support.z)<.00003,'cloth crown bears on lath',cloth=i,x=x+dx,gap_m=hit.z-support.z if hit and support else None)
for i,x in enumerate([-.32,.32]):
    hit=tree(bpy.data.objects[f'RinseTub{i}']).ray_cast(Vector((x,0,.9)),Vector((0,0,-1)),1)[0]
    require(hit is not None and abs(hit.z-.444)<.00003,'rinse cavity remains open',tub=i,inner_bottom=hit.z if hit else None)
rack=bpy.data.objects['Rack'];rack.location.z=1.98
template=bpy.data.objects['Rope'];template.hide_render=True
for o in template.children:o.hide_render=True
for side in [-1,1]:
    bottom=Vector((side*.56,0,2.055));top=Vector((side*.52,0,2.42));direction=top-bottom
    source=bpy.data.objects['SuspensionRope'];o=source.copy();o.data=source.data;o.parent=None;bpy.context.collection.objects.link(o);o.hide_render=False
    o.location=bottom;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(direction.normalized());o.scale.z=direction.length
bpy.context.view_layer.update()
render('airer_full',(0,0,1.5),(2,4,2),3.35)
render('airer_cloth',(0,0,1.86),(1,3,1.1),1.38)
rack.hide_render=True
for o in rack.children:o.hide_render=True
render('rinse_tubs',(0,0,.6),(1.2,2,2),1.5)
proof['airer_sha256']=hashlib.sha256(native.read_bytes()).hexdigest()

native=ROOT/'art/blender/bath_shower.blend';bpy.ops.wm.open_mainfile(filepath=str(native));set_materials('bath')
for state in ['CurtainDrawn','CurtainGathered']:
    points=[o.matrix_world@v.co for o in bpy.data.objects[state].children if o.type=='MESH' and 'shower_duck' in o.name for v in o.data.vertices]
    require(min(p.z for p in points)>=.1539,'shower hem clears receptor',pose=state,low=min(p.z for p in points))
    for other in ['CurtainDrawn','CurtainGathered']:
        for o in bpy.data.objects[other].children:o.hide_render=other!=state
    render('shower_'+state,(0,0,1.1),(2,4,1.7),2.5)
proof['shower_sha256']=hashlib.sha256(native.read_bytes()).hexdigest()
(OUT/'review.json').write_text(json.dumps(proof,indent=2)+'\n',newline='\n')
