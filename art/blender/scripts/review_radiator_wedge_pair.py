"""Two independent native wedges: contact, rigid joints and real service bores."""
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
OUT=ROOT/'tmp/v2-radiator-polish-20261017/pitch_wedge_pair_fit.json'
native=ROOT/'art/blender/radiator_mechanisms.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
stocks={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
with bpy.data.libraries.load(str(ROOT/'art/blender/radiator_sliding_wedge.blend'),link=False) as (_,data):
    data.objects=['SlidingPitchWedge_timber']
wedge=data.objects[0]
points=np.array([v.co[:] for v in stocks['CastShoeFoot'].data.vertices])
tip_y=float(points[:,1].max())+.03
spec=json.loads((ROOT/'game/data/orison_v2/radiator_sliding_wedge.json').read_text())
slope=spec['rise_per_m'];limit=math.radians(1.15)
checks=[];poses=[];rejected=[]
def check(label,passed,**detail):checks.append(dict(label=label,passed=bool(passed),**detail))
def tree(obj,pose=Matrix.Identity(4)):
    bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(pose);bm.normal_update()
    result=BVHTree.FromBMesh(bm);bm.free();return result
wedge_tree=tree(wedge)
housing_tree=tree(stocks['ArticulatedValveHousing'])

def solve(count,supply,far):
    half=(count-1)*.092*.5;shift=max(0,half-.322)
    joint=np.array([-half+shift-.071,.085,.19]);fixed=np.array([-.455,.085,.19]);length=joint[0]-fixed[0]
    def terms(theta):
        vertical=math.sin(theta)*points[:,0]+math.cos(theta)*points[:,2]
        return vertical.min(),(vertical-slope*(points[:,1]+.03-tip_y)).min()
    def difference(theta):
        floor,ramp=terms(theta)
        return 2*half*math.sin(theta)+min(floor,ramp-slope*far)-min(floor,ramp-slope*supply)
    if difference(-limit)>2e-8 or difference(limit)<-2e-8:return None
    low,high=-limit,limit
    for _ in range(30):
        mid=(low+high)/2
        if difference(mid)<0:low=mid
        else:high=mid
    theta=(low+high)/2
    floor,ramp=terms(theta)
    clearance=math.sin(theta)*(-half+shift-joint[0])-math.cos(theta)*joint[2]+min(floor,ramp-slope*supply)
    sine=(-clearance-fixed[2])/length
    if abs(sine)>=1:return None
    beta=math.asin(sine)
    if max(abs(beta),abs(beta-theta))>math.radians(22):return None
    at=fixed+np.array([length*math.cos(beta),0,length*math.sin(beta)])
    rotation=np.array([[math.cos(theta),0,-math.sin(theta)],[0,1,0],[math.sin(theta),0,math.cos(theta)]])
    body=np.eye(4);body[:3,:3]=rotation;body[:3,3]=at-rotation@joint
    return dict(sections=count,pitch=theta/limit,body_matrix=body.tolist(),fixed_joint=fixed.tolist(),header_joint=at.tolist(),
                feed_angle_radians=beta,body_angle_radians=theta,independent_wedges=True,depths={'supply':supply,'far':far})

for count in [7,8,9,10]:
    half=(count-1)*.092*.5;offset=max(0,half-.322)
    for supply in [0,.04,.10,.176]:
        for far in [0,.04,.10,.176]:
            pose=solve(count,supply,far)
            if pose is None:rejected.append(dict(sections=count,supply=supply,far=far,reason='pitch or spherical joint physical stop'));continue
            poses.append(pose)
            body=np.array(pose['body_matrix']);at=pose['header_joint'];beta=pose['feed_angle_radians'];theta=pose['body_angle_radians']
            for side,sign,depth in [('supply',-1,supply),('far',1,far)]:
                centre=offset+sign*half
                skin=(points+np.array([centre,.03,0]))@body[:3,:3].T+body[:3,3]
                local=skin-np.array([centre,tip_y-depth,0])
                gaps=local[:,2]-slope*local[:,1]
                floor=float(skin[:,2].min());ramp=float(gaps.min())
                check('entire native shoe clears floor and fixed wedge plane',floor>-1e-7 and ramp>-1e-7,sections=count,supply=supply,far=far,side=side)
                check('actual shoe is supported by floor or timber',abs(min(floor,ramp))<1e-7,sections=count,supply=supply,far=far,side=side)
                if ramp<=floor and depth>0:
                    witness=local[int(np.argmin(gaps))]
                    check('timber contact is within actual fixed stock',abs(witness[0])<spec['width_m']/2-spec['corner_clip_m'] and 0<=witness[1]<=spec['length_m'],sections=count,supply=supply,far=far,side=side)
                    hit=wedge_tree.ray_cast(Vector(witness)+Vector((0,0,.001)),Vector((0,0,-1)),.003)
                    check('real BVH timber surface meets actual shoe',hit[0] is not None and abs(hit[3]-.001)<1e-6,sections=count,supply=supply,far=far,side=side)
            up=Matrix.Translation(pose['fixed_joint'])@Matrix.Rotation(-beta,4,'Y')
            down=Matrix.Translation(at)@Matrix.Rotation(-theta,4,'Y')
            bearing=Matrix.Translation(at)@Matrix.Rotation(-beta,4,'Y')
            fixed_parts={'neck':tree(stocks['SphericalNeck_%d'%count],up),
                         'valve_nut':tree(stocks['ValveSphericalRetainer'],up),
                         'valve_ring':tree(stocks['FloatingMetalBearingRing'],Matrix.Translation(pose['fixed_joint'])),
                         'housing':housing_tree,
                         'header_ring':tree(stocks['FloatingMetalBearingRing'],bearing)}
            for first,second in [('housing','neck'),('housing','valve_ring'),('housing','valve_nut'),('neck','valve_ring'),('neck','valve_nut'),('valve_ring','valve_nut')]:
                hits=fixed_parts[first].overlap(fixed_parts[second])
                check('actual fixed valve and spherical feed surfaces clear',not hits,sections=count,supply=supply,far=far,parts=[first,second],triangle_pairs=len(hits))
            for progress in [0,.4,1.]:
                slide=Matrix.Translation((.04*max((progress-.4)/.6,0),0,0))
                parts=dict(fixed_parts)
                parts['socket']=tree(stocks['PackedHeaderSocket'],slide@down)
                parts['header_nut']=tree(stocks['HeaderSphericalRetainer'],slide@down@Matrix.Translation((.001*min(progress/.4,1),0,0)))
                for first,second in [('header_nut','neck'),('header_nut','valve_nut'),('header_nut','header_ring'),('header_nut','socket'),('socket','neck'),('socket','header_ring')]:
                    hits=parts[first].overlap(parts[second])
                    check('actual spherical service surfaces clear at two-wedge pose',not hits,sections=count,supply=supply,far=far,progress=progress,parts=[first,second],triangle_pairs=len(hits))
                for index in range(count):
                    casting=tree(stocks['CastSectionThreeColumnCandidate'],slide@Matrix(pose['body_matrix'])@Matrix.Translation(((index-(count-1)/2)*.092+offset,.03,.105)))
                    for name in ['socket','header_nut','header_ring','neck']:
                        hits=casting.overlap(parts[name])
                        check('actual casting clears articulated service surfaces',not hits,sections=count,supply=supply,far=far,progress=progress,index=index,part=name,triangle_pairs=len(hits))

mount_source=ROOT/'game/data/orison_v2/radiator_wall_mounts.json'
installations=json.loads(mount_source.read_text())['installations']
names={'SlottedWallBracket'}|{tie['rod'] for installation in installations for tie in installation['ties']}
with bpy.data.libraries.load(str(ROOT/'art/blender/radiator_wall_support.blend'),link=False) as (_,data):data.objects=sorted(names)
supports={obj.name:obj for obj in data.objects}
for installation in installations:
    for tie_index,tie in enumerate(installation['ties']):
        column=Vector((tie['column'][0],-tie['column'][2],tie['column'][1]))
        plate=tree(supports['SlottedWallBracket'],Matrix.Translation((column.x,-tie['bracket_z'],column.z)))
        for pose in [p for p in poses if p['sections']==installation['sections']]:
            for opening in [0,.04]:
                rod=tree(supports[tie['rod']],Matrix.Translation((opening,0,0))@Matrix(pose['body_matrix'])@Matrix.Translation(column))
                hits=rod.overlap(plate)
                check('actual anti-tip rod clears real fixed wall slot',not hits,actor=installation['id'],side=tie_index,depths=pose['depths'],opening_m=opening,triangle_pairs=len(hits))
report=dict(evidence_class='INERT',scope='Two-support native whole-skin/BVH contact and actual union service-surface samples. No room navigation, runtime save or human acceptance.',
            source_sha256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [native,ROOT/'art/blender/radiator_sliding_wedge.blend',ROOT/'art/blender/radiator_wall_support.blend',mount_source]},
            checks=checks,poses=poses,rejected_physical_stops=rejected,failures=[c for c in checks if not c['passed']])
OUT.write_text(json.dumps(report,indent=2)+'\n')
print('WEDGE PAIR FIT:',len(poses),'supported poses;',len(rejected),'stopped candidates;',len(checks),'checks;',len(report['failures']),'failures',flush=True)
assert not report['failures'],report['failures'][:10]
