"""Native staged retainer backoff and 40mm service withdrawal; uninstalled."""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import json, hashlib, math
import bpy, bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
P = output_directory()
native = P / 'articulated_union_finished_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
objects = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
poses = json.loads((P / 'pitch_kinematics_review.json').read_text())['poses']

def tree(name, xf):
    bm = bmesh.new()
    bm.from_mesh(objects[name].data)
    bm.transform(xf)
    bm.normal_update()
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result
checks = []
for row in poses:
    a = Vector(row['fixed_joint'])
    b = Vector(row['header_joint'])
    beta = row['feed_angle_radians']
    theta = row['body_angle_radians']
    count = row['sections']
    up = Matrix.Translation(a) @ Matrix.Rotation(-beta, 4, 'Y')
    down = Matrix.Translation(b) @ Matrix.Rotation(-theta, 4, 'Y')
    bearing = Matrix.Translation(b) @ Matrix.Rotation(-beta, 4, 'Y')
    for progress in [0, 0.2, 0.4, 0.7, 1]:
        backoff = 0.001 * min(progress / 0.4, 1)
        opening = 0.04 * max((progress - 0.4) / 0.6, 0)
        shift = Matrix.Translation((opening, 0, 0))
        body = shift @ Matrix(row['body_matrix'])
        parts = {'neck': tree('SphericalNeck_%d' % count, up), 'header_ring': tree('FloatingMetalBearingRing', bearing), 'valve_nut': tree('ValveSphericalRetainer', up), 'socket': tree('HeaderSphericalSocket', shift @ down), 'header_nut': tree('HeaderSphericalRetainer', shift @ down @ Matrix.Translation((backoff, 0, 0)))}
        for first, second in [('header_nut', 'neck'), ('header_nut', 'valve_nut'), ('header_nut', 'header_ring'), ('header_nut', 'socket'), ('socket', 'neck'), ('socket', 'header_ring')]:
            hits = parts[first].overlap(parts[second])
            checks.append(dict(label='staged native service parts clear', passed=not hits, sections=count, pitch=row['pitch'], progress=progress, opening_m=opening, backoff_m=backoff, a=first, b=second, triangle_pairs=len(hits)))
        half = (count - 1) * 0.092 / 2
        offset = max(0, half - 0.322)
        for index in range(count):
            casting = tree('CastSectionThreeColumnCandidate', body @ Matrix.Translation(((index - (count - 1) / 2) * 0.092 + offset, 0.03, 0.105)))
            hits = casting.overlap(parts['header_nut'])
            checks.append(dict(label='backed-off retainer clears withdrawn casting', passed=not hits, sections=count, pitch=row['pitch'], progress=progress, index=index, triangle_pairs=len(hits)))
report = dict(evidence_class='INERT', scope='Uninstalled staged union-retainer backoff and horizontal body withdrawal; actual native triangle intersections across100poses. No removable packing, room fit, pressure, runtime controls or human acceptance.', native_sha256=hashlib.sha256(native.read_bytes()).hexdigest(), checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'union_service_motion_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('UNION SERVICE', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError('Service motion needs refitting')
