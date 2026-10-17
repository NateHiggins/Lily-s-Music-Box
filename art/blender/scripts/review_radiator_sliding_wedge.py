"""Actual native shoe/wedge contact through continuous pitch, four lengths.

Uses all shoe vertices and real wedge BVH, not a preset-pose visual surrogate.
Render-only review assembly does not alter installed native source files.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
import bmesh
import numpy as np
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-radiator-polish-20261017/pitch_wedge_views'
OUT.mkdir(parents=True,exist_ok=True)
native=ROOT/'art/blender/radiator_sliding_wedge.blend'
foot_native=ROOT/'art/blender/radiator_mechanisms.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
stock=bpy.data.objects['SlidingPitchWedge_timber']
source=json.loads((ROOT/'game/data/orison_v2/radiator_sliding_wedge.json').read_text())
slope=source['rise_per_m'];length=source['length_m'];width=source['width_m'];clip=source['corner_clip_m']
with bpy.data.libraries.load(str(foot_native),link=False) as (_,data):data.objects=['CastShoeFoot']
shoe=data.objects[0];bpy.context.collection.objects.link(shoe)
points=np.array([v.co[:] for v in shoe.data.vertices])
bm=bmesh.new();bm.from_mesh(stock.data);tree=BVHTree.FromBMesh(bm);bm.free()
tip_y=float(points[:,1].max())+.03
checks=[];poses=[]
def check(label,passed,**detail):checks.append(dict(label=label,passed=bool(passed),**detail))

for count in [7,8,9,10]:
    half=(count-1)*.092*.5;shift=max(0,half-.322)
    fixed=np.array([-.455,.085,.19]);joint=np.array([-half+shift-.071,.085,.19])
    feed=joint[0]-fixed[0]
    for pitch in np.linspace(-1,1,101):
        theta=math.radians(float(pitch)*1.15)
        rotation=np.array([[math.cos(theta),0,-math.sin(theta)],[0,1,0],[math.sin(theta),0,math.cos(theta)]])
        both=np.concatenate([points+np.array([x+shift,.03,0]) for x in [-half,half]])
        lowest=((both-joint)@rotation.T)[:,2].min()
        beta=math.asin((-fixed[2]-lowest)/feed)
        at=fixed+np.array([feed*math.cos(beta),0,feed*math.sin(beta)])
        transformed=(both-joint)@rotation.T+at
        check('all actual shoe vertices stay above floor',transformed[:,2].min()>-1e-8,sections=count,pitch=float(pitch))
        check('lower actual shoe bears on floor',abs(transformed[:,2].min())<1e-8,sections=count,pitch=float(pitch))
        check('rigid feed length and both spherical angles remain valid',abs(np.linalg.norm(at-fixed)-feed)<1e-9 and max(abs(beta),abs(beta-theta))<math.radians(22),sections=count,pitch=float(pitch))
        body=np.eye(4);body[:3,:3]=rotation;body[:3,3]=at-rotation@joint
        depths={}
        for side,sign in [('supply',-1),('far',1)]:
            centre=shift+sign*half
            skin=(points+np.array([centre,.03,0])-joint)@rotation.T+at
            if pitch*sign<=0:
                depths[side]=0.
                continue
            # Native Y becomes -Godot Z. The fixed stock's top is slope*Y;
            # moving its tip toward the shoe adds slope*depth of support.
            witness=int(np.argmin(skin[:,2]-slope*skin[:,1]))
            depth=float((skin[:,2]-slope*skin[:,1]).min()/slope+tip_y)
            depths[side]=depth
            local=skin-np.array([centre,tip_y-depth,0])
            check('fixed wedge supports without reshaping or exhausting its heel',0<=depth<length,sections=count,pitch=float(pitch),depth_m=depth)
            check('actual contact lies within unclipped timber bearing face',abs(local[witness,0])<width/2-clip and 0<=local[witness,1]<=length,sections=count,pitch=float(pitch))
            contact=Vector(local[witness])
            hit=tree.ray_cast(contact+Vector((0,0,.001)),Vector((0,0,-1)),.003)
            check('actual wedge BVH meets actual shoe skin',hit[0] is not None and abs(hit[3]-.001)<1e-6,sections=count,pitch=float(pitch),observed_m=hit[3])
            check('entire actual shoe clears wedge top plane',float((local[:,2]-slope*local[:,1]).min())>-1e-8,sections=count,pitch=float(pitch))
        poses.append(dict(sections=count,pitch=float(pitch),depths=depths,body_matrix=body.tolist()))

report=dict(evidence_class='INERT',scope='Native fixed wedge/whole-shoe contact and feed-joint sampling only; no controls, room access or human acceptance.',
            source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [native,foot_native]},
            checks=checks,poses=poses,failures=[c for c in checks if not c['passed']])
(OUT.parent/'pitch_wedge_fit.json').write_text(json.dumps(report,indent=2)+'\n')
print('SLIDING WEDGE FIT:',len(checks),'checks;',len(report['failures']),'failures',flush=True)
assert not report['failures'],report['failures'][:8]

scene=bpy.context.scene
for obj in scene.objects:obj.hide_render=True
shoe.hide_render=False;stock.hide_render=False
shoe_other=shoe.copy();shoe_other.data=shoe.data;bpy.context.collection.objects.link(shoe_other);shoe_other.hide_render=False
stock_other=stock.copy();stock_other.data=stock.data;bpy.context.collection.objects.link(stock_other);stock_other.hide_render=False
bpy.ops.mesh.primitive_plane_add(size=3,location=(0,0,-.0003))
floor=bpy.context.object;floor.hide_render=False
floor_material=bpy.data.materials.new('Diagnostic neutral floor');floor_material.diffuse_color=(.16,.16,.16,1)
floor.data.materials.append(floor_material)
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1100;scene.render.resolution_y=700;scene.render.resolution_percentage=100
world=bpy.data.worlds.new('Neutral foot support review');world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.4;scene.world=world
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';scene.camera=camera
bpy.ops.object.light_add(type='AREA');lamp=bpy.context.object;lamp.data.energy=20;lamp.data.size=.25
for pitch in [-1.,0.,.35,1.]:
    pose=next(p for p in poses if p['sections']==8 and abs(p['pitch']-pitch)<1e-6) if pitch!=.35 else min((p for p in poses if p['sections']==8),key=lambda p:abs(p['pitch']-pitch))
    # The continuous sample contains .34/.36; render its actual nearest pose,
    # retaining the sampled pitch in the filename rather than relabeling it.
    half=7*.092*.5;shift=max(0,half-.322);body=Matrix(pose['body_matrix'])
    for side,sign,foot,wedge in [('supply',-1,shoe,stock),('far',1,shoe_other,stock_other)]:
        centre=shift+sign*half
        foot.matrix_world=body@Matrix.Translation((centre,.03,0))
        wedge.matrix_world=Matrix.Translation((centre,tip_y-pose['depths'][side],0))
    target=Vector((0,.09,.05));camera.location=target+Vector((.50,.75,.30))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=.94
    lamp.location=target+Vector((.1,.2,.6));lamp.rotation_euler=(target-lamp.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/('pitch_%+.2f.png'%pose['pitch']))
    bpy.ops.render.render(write_still=True)
