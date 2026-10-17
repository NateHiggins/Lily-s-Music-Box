"""Actual refined castings against retained feet, ties and service hardware.

Blender --python-exit-code 1 --python this_file -- --native FILE
--reference-dir DIR --out FILE. Native fit only, not runtime acceptance.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--native', type=Path, required=True)
parser.add_argument('--reference-dir', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
reference = args.reference_dir.resolve()
bpy.ops.wm.open_mainfile(filepath=str(args.native.resolve()))
stocks = {obj.name:obj for obj in bpy.context.scene.objects if obj.type=='MESH'}
# Hardware/rod names are authority values, not a naming convention.
mounts = json.loads((reference/'sliding_wall_ties_review.json').read_text())['mounts']
needed = {str(m[k]) for m in mounts for k in ['hardware','rod']} | {'SlottedWallBracket'}
with bpy.data.libraries.load(str(reference/'sliding_wall_ties_candidate.blend'),link=False) as (available,loaded):
    loaded.objects = sorted(needed)
supports = {obj.name:obj for obj in loaded.objects}
for obj in loaded.objects: bpy.context.scene.collection.objects.link(obj)
poses = json.loads((reference/'pitch_kinematics_review.json').read_text())['poses']
plan = json.loads((reference/'wall_tie_mount_plan.json').read_text())['ties']
checks = []


def check(ok,label,**detail):
    checks.append(dict(passed=bool(ok),label=label,**detail))


def tree(obj,pose):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(pose)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result


casting,shoe = stocks['CastSectionThreeColumnCandidate'],stocks['CastShoeFoot']
for row in poses:
    count = row['sections']
    half = (count-1)*.092/2
    shift = max(0,half-.322)
    body = Matrix(row['body_matrix'])
    minimum = min((body@(v.co+Vector((x+shift,.03,0)))).z
                  for x in [-half,half] for v in shoe.data.vertices)
    check(abs(minimum)<1e-7,'refined shoe retains actual floor bearing in retained rigid pose',
          sections=count,pitch=row['pitch'],minimum_foot_z=minimum)
    # Check the changed cast stock against actual captive retainer geometry
    # at all five stages of each count/pitch service movement.
    down = Matrix.Translation(row['header_joint'])@Matrix.Rotation(-row['body_angle_radians'],4,'Y')
    for progress in [0,.2,.4,.7,1]:
        opening = .04*max((progress-.4)/.6,0)
        slide = Matrix.Translation((opening,0,0))
        nut = tree(stocks['HeaderSphericalRetainer'],slide@down@Matrix.Translation((.001*min(progress/.4,1),0,0)))
        for index in range(count):
            pose = slide@body@Matrix.Translation(((index-(count-1)/2)*.092+shift,.03,.105))
            hits = tree(casting,pose).overlap(nut)
            check(not hits,'retained retainer clears refined casting through service travel',
                  sections=count,pitch=row['pitch'],progress=progress,index=index,triangle_pairs=len(hits))

for x in [-.322,.322]:
    cast = tree(casting,Matrix.Translation((x,.03,.105)))
    for index in range(8):
        angle = index*math.tau/8
        hit,normal,face,distance = cast.ray_cast(Vector((x+.02*math.cos(angle),.03+.02*math.sin(angle),.1)),Vector((0,0,1)),.01)
        check(hit is not None and abs(hit.z-.105)<1e-6 and normal.z<-.99,
              'real casting underside seats on retained shoe top',side=x,ray=index)

for mount,tie in zip(mounts,plan):
    assert (mount['actor'],mount['side'])==(tie['actor'],tie['side'])
    count = tie['sections']
    half = (count-1)*.092/2
    shift = max(0,half-.322)
    moving = tree(supports[mount['rod']],Matrix.Translation(tie['column_local_blender']))
    for index in range(count):
        pose = Matrix.Translation(((index-(count-1)/2)*.092+shift,.03,.105))
        hits = moving.overlap(tree(casting,pose))
        check(not hits,'actual sliding tie clears refined casting',actor=tie['actor'],side=tie['side'],index=index,triangle_pairs=len(hits))
    fixed_depth = max(max(v.co.y for v in supports['SlottedWallBracket'].data.vertices),
                      max(v.co.y for v in supports[mount['hardware']].data.vertices))+tie['bracket_front_y']
    for row in [p for p in poses if p['sections']==count]:
        body = Matrix(row['body_matrix'])
        minimum = min((body@(v.co+Vector((shift,.03,.105)))).y for v in casting.data.vertices)
        check(fixed_depth<minimum,'fixed bracket/hardware remain behind refined castings through pitch',
              actor=tie['actor'],side=tie['side'],pitch=row['pitch'],clearance_m=minimum-fixed_depth)

result = dict(evidence_class='INERT',scope='Actual native revised cast geometry vs retained floor/seat datums, service retainer and 46 surveyed ties. No game controls, room navigation, save or human acceptance.',
              native_sha256=hashlib.sha256(args.native.read_bytes()).hexdigest(),
              checks=checks,failures=[row for row in checks if not row['passed']])
args.out.parent.mkdir(parents=True,exist_ok=True)
args.out.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print('REFINED CAST FIT:',len(checks),'checks;',len(result['failures']),'failures',flush=True)
assert not result['failures'],result['failures'][:10]
