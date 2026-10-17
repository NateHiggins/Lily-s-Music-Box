"""Native mating-surface clearance over complete screw travel, plus a wrong-
phase collision control. No blanket waiver of thread/shoulder intersections.
"""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).parent))
from radiator_cap_thread import SPEC,SPEC_PATH

p=argparse.ArgumentParser();p.add_argument('--native',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(args.native.resolve()))
body,cap=[bpy.data.objects[n] for n in ['VentBody','VentCap']]
checks=[]
def check(label,passed,**facts):checks.append(dict(label=label,passed=bool(passed),**facts))
def tree(obj,pose=Matrix.Identity(4)):
    bm=bmesh.new();bm.from_mesh(obj.data);bm.transform(pose);bm.normal_update()
    result=BVHTree.FromBMesh(bm);bm.free();return result
fixed=tree(body)
minimum=math.inf;turns=SPEC['engagement_m']/SPEC['pitch_m'];origin=Vector((.043,0,0))
for step in range(65):
    lift=SPEC['engagement_m']*step/64
    angle=math.tau*lift/SPEC['pitch_m']
    pose=Matrix.Translation((.043,0,lift))@Matrix.Rotation(angle,4,'Z')@Matrix.Translation((-.043,0,0))
    moving=tree(cap,pose)
    pairs=moving.overlap(fixed)
    bad=[]
    for a,b in pairs:
        # A flange face can touch the upper edge of a vertical neck face.
        # The shoulder plane must separate both entire triangles; requiring
        # both triangles to be planar would misclassify this edge contact.
        shoulder=step==0 and all(cap.data.vertices[i].co.z>=SPEC['shoulder_m']-1e-7 for i in cap.data.polygons[a].vertices) and all(body.data.vertices[i].co.z<=SPEC['shoulder_m']+1e-7 for i in body.data.polygons[b].vertices)
        if not shoulder:bad.append((a,b))
    check('actual mating shells clear through matched screw travel',not bad,step=step,turns=angle/math.tau,unexpected_pairs=len(bad))
    low=SPEC['stem_bottom_m']+lift+.00025;high=SPEC['shoulder_m']-.00025
    if low>=high:continue
    for fraction in [.15,.5,.85]:
        z=low+(high-low)*fraction
        center=origin+Vector((0,0,z))
        for sample in range(16):
            direction=Vector((math.cos(math.tau*sample/16),math.sin(math.tau*sample/16),0))
            hole=fixed.ray_cast(center,direction,.025)
            stem=moving.ray_cast(center+direction*.025,-direction,.025)
            gap=hole[3]-(.025-stem[3]) if hole[0] is not None and stem[0] is not None else -1
            minimum=min(minimum,gap)
            check('actual root/flank/crest retain radial running clearance',gap>.00005,step=step,level=fraction,azimuth=sample,gap_m=gap)
wrong=Matrix.Translation((.043,0,.003))@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Translation((-.043,0,0))
witness=tree(cap,wrong).overlap(fixed)
check('wrong screw phase really collides with the female thread',len(witness)>0,triangle_pairs=len(witness))
check('engagement has eight real pitched turns',abs(turns-8)<1e-8)
report=dict(evidence_class='INERT',scope='Actual native thread travel and radial surface samples; no runtime/carry/disk proof.',
            native_sha256=hashlib.sha256(args.native.read_bytes()).hexdigest(),specification=SPEC,
            specification_lf_sha256=hashlib.sha256(SPEC_PATH.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
            minimum_sampled_radial_clearance_m=minimum,checks=checks,failures=[c for c in checks if not c['passed']])
args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(report,indent=2)+'\n')
print('NATIVE CAP THREAD:',len(checks),'checks;',len(report['failures']),'failures; minimum gap',minimum,flush=True)
if report['failures']:raise RuntimeError(report['failures'][:4])
