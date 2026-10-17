"""Actual native collar/casting fit, with conservative fixed-stock bounds."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import json, hashlib
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
P = output_directory()
B = output_directory()
bpy.ops.wm.open_mainfile(filepath=str(P / 'sliding_wall_ties_candidate.blend'))
stocks = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
with bpy.data.libraries.load(str(B / 'packed_union_candidate.blend'), link=False) as (available, loaded):
    loaded.objects = ['CastSectionThreeColumnCandidate']
casting = loaded.objects[0]
bpy.context.collection.objects.link(casting)
mounts = json.loads((P / 'sliding_wall_ties_review.json').read_text())['mounts']
poses = json.loads((B / 'pitch_kinematics_review.json').read_text())['poses']
plan = json.loads((P / 'wall_tie_mount_plan.json').read_text())['ties']

def tree(obj, xf):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(xf)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result
checks = []
for mount, tie in zip(mounts, plan):
    assert (mount['actor'], mount['side']) == (tie['actor'], tie['side'])
    count = tie['sections']
    half = (count - 1) * 0.092 / 2
    shift = max(0, half - 0.322)
    column = Vector(tie['column_local_blender'])
    moving = tree(stocks[mount['rod']], Matrix.Translation(column))
    for index in range(count):
        cast = tree(casting, Matrix.Translation(((index - (count - 1) / 2) * 0.092 + shift, 0.03, 0.105)))
        hits = moving.overlap(cast)
        checks.append(dict(label='rigidly attached collar/tie clears every casting', passed=not hits, actor=tie['actor'], side=tie['side'], index=index, triangle_pairs=len(hits)))
    fixed_y = max((stocks['SlottedWallBracket'].bound_box[i][1] for i in range(8))) + tie['bracket_front_y']
    hardware_y = max((v.co.y for v in stocks[mount['hardware']].data.vertices)) + tie['bracket_front_y']
    for row in [r for r in poses if r['sections'] == count]:
        body = Matrix(row['body_matrix'])
        minimum = min(((body @ (v.co + Vector((shift, 0.03, 0.105)))).y for v in casting.data.vertices))
        checks.append(dict(label='fixed bracket/hardware have separated depth bounds from cast stock through pitch', passed=max(fixed_y, hardware_y) < minimum, actor=tie['actor'], side=tie['side'], pitch=row['pitch'], minimum_depth_clearance_m=minimum - max(fixed_y, hardware_y)))
report = dict(evidence_class='INERT', scope='Actual regenerated native casting vs moving ties; common-body relative-transform invariance, and fixed stock separated depth bounds. No wall contact or runtime proof.', support_native_sha256=hashlib.sha256((P / 'sliding_wall_ties_candidate.blend').read_bytes()).hexdigest(), family_native_sha256=hashlib.sha256((B / 'packed_union_candidate.blend').read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'tie_casting_fit_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('TIE CASTING FIT', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError('Refit native ties to the actual casting')
