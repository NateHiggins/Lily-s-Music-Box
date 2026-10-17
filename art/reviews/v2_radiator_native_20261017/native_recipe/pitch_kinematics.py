"""UNINSTALLED kinematic fit from actual shoe vertices and two joint centres.

Only the body, feet and ideal rigid feed-neck poses are solved here. Native
spherical seats/retainers are NOT supplied by this diagnostic.
"""
from recipe_paths import repository_root, output_directory, primitive_source
from pathlib import Path
import bpy, json, math, hashlib
from mathutils import Vector, Matrix
P = output_directory()
bpy.ops.wm.open_mainfile(filepath=str(P / 'family_uv_candidate.blend'))
foot = bpy.data.objects['CastShoeFoot']
checks = []
poses = []

def check(label, passed, **detail):
    checks.append(dict(label=label, passed=bool(passed), **detail))
for count in [7, 8, 9, 10]:
    half = (count - 1) * 0.092 / 2
    shift = max(0, half - 0.322)
    a = Vector((-0.455, 0.085, 0.19))
    b = Vector((-half + shift - 0.046 - 0.025, 0.085, 0.19))
    length = (b - a).length
    soles = [Vector((x + shift, 0.03, 0)) + v.co for x in [-half, half] for v in foot.data.vertices]
    for pitch in [-1, -0.35, 0, 0.35, 1]:
        theta = math.radians(pitch * 1.15)
        rotation = Matrix.Rotation(-theta, 3, 'Y')
        lowest = min(((rotation @ (point - b)).z for point in soles))
        sine = (-a.z - lowest) / length
        check('native feet admit a rigid-neck floor-contact pose', abs(sine) < 1, sections=count, pitch=pitch, sine=sine)
        beta = math.asin(sine)
        at = a + Vector((length * math.cos(beta), 0, length * math.sin(beta)))
        body = Matrix.Translation(at) @ rotation.to_4x4() @ Matrix.Translation(-b)
        transformed = [body @ point for point in soles]
        check('every actual shoe vertex stays above the floor', min((point.z for point in transformed)) > -1e-08, sections=count, pitch=pitch)
        check('one actual shoe vertex bears on the floor', abs(min((point.z for point in transformed))) < 1e-08, sections=count, pitch=pitch)
        first = body @ Vector((-half + shift, 0.03, 0.105))
        last = body @ Vector((half + shift, 0.03, 0.105))
        check('positive authority value raises the end away from the supply', abs(last.z - first.z - 2 * half * math.sin(theta)) < 1e-07 and (pitch == 0 or (last.z - first.z) * pitch > 0), sections=count, pitch=pitch, actual_rise_m=last.z - first.z, expected_rise_m=2 * half * math.sin(theta), residual_m=abs(last.z - first.z - 2 * half * math.sin(theta)))
        check('rigid feed-neck length is preserved without stretching', abs((at - a).length - length) < 1e-07, sections=count, pitch=pitch, residual_m=abs((at - a).length - length))
        joint_angle = abs(beta - theta)
        check('proposed spherical joints stay within 22degree design limit', abs(beta) < math.radians(22) and joint_angle < math.radians(22), sections=count, pitch=pitch, upstream_degrees=math.degrees(beta), header_degrees=math.degrees(beta - theta))
        poses.append(dict(sections=count, pitch=pitch, body_matrix=[list(row) for row in body], fixed_joint=list(a), header_joint=list(at), feed_length_m=length, feed_angle_radians=beta, body_angle_radians=theta, minimum_foot_height_m=min((point.z for point in transformed))))
report = dict(evidence_class='INERT', scope='UNINSTALLED kinematic constraint diagnostic from actual native feet, all four counts and five pitch settings. Does not model or prove spherical seat geometry, pressure/flow, shim construction, union-service travel, room fit of the articulated fittings, runtime or human acceptance.', numerical_tolerance_m=1e-07, numerical_basis='Float32 native transforms: measured largest analytic residual 4.25e-8m; 0.1micrometre tolerance, not a fabrication clearance waiver.', reference='https://patents.google.com/patent/US1076921A/en', reference_interpretation='Period ball/socket union and adjustable metal packing motivate an inferred repair fitting; this is not a replica or evidence of widespread radiator installation.', native_source_sha256=hashlib.sha256((P / 'family_uv_candidate.blend').read_bytes()).hexdigest(), poses=poses, checks=checks, failures=[c for c in checks if not c['passed']])
(P / 'pitch_kinematics_review.json').write_text(json.dumps(report, indent=2) + '\n')
print('PITCH KINEMATICS', len(checks), 'checks', len(report['failures']), 'failures', flush=True)
if report['failures']:
    raise RuntimeError(report['failures'])
