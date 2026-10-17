"""Render changed stocks and probe actual contact/shaft surfaces in their
original board frames. No source native file is rewritten by this diagnostic.
"""
from pathlib import Path
import json,math,sys
import bpy,bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'tmp/v2-radiator-polish-20261017/annunciator_native_views';OUT.mkdir(exist_ok=True)
if '--out' in sys.argv:OUT=Path(sys.argv[sys.argv.index('--out')+1]);OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/annunciator_controls.blend'))
source=next(a for a in json.loads((ROOT/'art/data/service_instruments/source_plan.json').read_text())['actors'] if a['id']=='M01')
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
bridge=Vector(source['meshes'][26]['position']);reset=Vector(source['meshes'][27]['position']);checks=[]
def check(label,passed,**facts):checks.append(dict(label=label,passed=bool(passed),**facts))
def tree(obj,pose=Matrix.Identity(4)):
    bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(pose);bm.normal_update();result=BVHTree.FromBMesh(bm);bm.free();return result
def pose(at,angle=0,shaft=False):return C@Matrix.Translation(at)@Matrix.Rotation(angle,4,'Z')@(Matrix.Rotation(math.pi/2,4,'X') if shaft else Matrix.Identity(4))@C.inverted()
fixed=bpy.data.objects['FixedContactMetal'];moving=bpy.data.objects['MovingContactMetal'];bearing=bpy.data.objects['ResetBearing'];knob=bpy.data.objects['ResetKnob']
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    check('finished native stock has no boundary or nonmanifold edge',all(e.is_manifold for e in bm.edges),stock=obj.name)
    check('finished native stock has positive solid volume',bm.calc_volume(signed=True)>0,stock=obj.name)
    bm.free()
f=tree(fixed)
for angle in [0.,-.044,.044,-.1948]:
    m=tree(moving,pose(bridge,angle))
    for x in [-.035,.035]:
        at=Vector((x,bridge.y,0))
        front=f.ray_cast((C@Vector((*at[:2],.075,1))).xyz,(C@Vector((0,0,-1,0))).xyz,.06)
        back=m.ray_cast((C@Vector((*at[:2],.035,1))).xyz,(C@Vector((0,0,1,0))).xyz,.04)
        if abs(angle)<.05:
            gap=(C.inverted()@Vector((*back[0],1))).z-(C.inverted()@Vector((*front[0],1))).z if back[0] is not None and front[0] is not None else 1
            check('real contact surfaces meet within allowed alignment',abs(gap)<.0000003,angle=angle,x=x,gap_m=gap)
        else:check('misaligned contact really misses fixed leaf',back[0] is None,angle=angle,x=x)
for step in range(13):
    angle=math.pi*.5*step/12
    k=tree(knob,pose(reset,angle,True))
    check('real reset shaft clears bearing through travel',not k.overlap(tree(bearing)),angle=angle)
shifted=reset+Vector((.001,0,0))
check('misfitted shaft negative control collides',bool(tree(knob,pose(shifted,0,True)).overlap(tree(bearing))))
flag=bpy.data.objects['FlagArm'];seat=bpy.data.objects['FlagSeat'];journals=bpy.data.objects['FlagBearings']
flag_at=Vector(source['meshes'][4]['position']);seat_at=Vector(source['meshes'][3]['position'])
def flag_pose(angle=0,shift=Vector((0,0,0))):return C@Matrix.Translation(flag_at+shift)@Matrix.Rotation(angle,4,'X')@C.inverted()
fixed_seat=tree(seat,pose(seat_at));fixed_journals=tree(journals,pose(flag_at))
for step in range(43):
    angle=math.radians(-8+step)
    moving_flag=tree(flag,flag_pose(angle))
    check('flag clears its real ivory bezel through travel',not moving_flag.overlap(fixed_seat),angle=angle)
    check('flag axle clears both fixed journals through travel',not moving_flag.overlap(fixed_journals),angle=angle)
check('displaced flag axle negative control collides',bool(tree(flag,flag_pose(0,Vector((0,.0004,0)))).overlap(fixed_journals)))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100
world=bpy.data.worlds.new('Neutral contact review');world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.17,.17,.17,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45;scene.world=world
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';scene.camera=camera
bpy.ops.object.light_add(type='AREA');light=bpy.context.object;light.data.energy=12;light.data.size=.12
for label,angle,shaft in [('contact_open',-.1948,False),('contact_closed',0,False),('reset_rest',0,True),('reset_turned',math.pi/2,True),('flag_rest',math.radians(-8),False),('flag_lifted',math.radians(34),False)]:
    for obj in scene.objects:
        if obj.type=='MESH':obj.hide_render=True
    subjects=[knob,bearing] if shaft else [fixed,moving,bpy.data.objects['FixedContactInsulators']]
    for obj in subjects:obj.hide_render=False
    moving.matrix_world=pose(bridge,angle if not shaft else 0)
    knob.matrix_world=pose(reset,angle if shaft else 0,True)
    target=(C@Vector((*(reset if shaft else bridge),1))).xyz
    if shaft:target+=(C@Vector((0,0,.020,0))).xyz
    if label.startswith('flag'):
        for obj in subjects:obj.hide_render=True
        subjects=[flag,seat,journals]
        for obj in subjects:obj.hide_render=False
        flag.matrix_world=flag_pose(angle);seat.matrix_world=pose(seat_at);journals.matrix_world=pose(flag_at)
        target=(C@Vector((*flag_at,1))).xyz
    camera.data.ortho_scale=.12 if not shaft else .095
    camera.location=target+(C@Vector((.07,.04,.13,0))).xyz;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    light.location=target+(C@Vector((.09,.10,.15,0))).xyz;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
report=dict(evidence_class='INERT',checks=checks,failures=[c for c in checks if not c['passed']],scope='Native added-stock contact/shaft fit and neutral views only; no runtime proof.')
(OUT/'fit.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n');print('ANNUNCIATOR FIT',len(checks),'checks;',len(report['failures']),'failures',flush=True)
if report['failures']:raise RuntimeError(report['failures'])
