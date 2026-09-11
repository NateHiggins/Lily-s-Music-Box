"""Source geometry checks only. Does not launch Blender or Godot."""
import hashlib
import importlib.util
import itertools
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
spec = importlib.util.spec_from_file_location('furnishing_extract', HERE/'extract.py')
extract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extract)
data = json.loads((ROOT/'game/data/orison_v2/domestic_furniture.json').read_text())
blockout = json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text())
materials = json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
anchors = {a['id']: a for a in blockout['anchors']}
assert len(anchors) == len(blockout['anchors']), 'duplicate anchor'
records = {r['id']: r for r in data['furniture']}
generated = extract.generate()['furniture']
assert generated == extract.generate()['furniture'], 'nondeterministic extraction'
assert all(records[r['id']] == r for r in generated), 'installed geometry differs'

def world_bounds(record, anchor):
    lo, hi = record['bounds']
    c, s = math.cos(anchor['yaw']), math.sin(anchor['yaw'])
    px, _, pz = anchor['position']
    corners = [(px+c*x+s*z, pz-s*x+c*z)
               for x,z in itertools.product([lo[0],hi[0]], [lo[2],hi[2]])]
    return [min(p[0] for p in corners), min(p[1] for p in corners),
            max(p[0] for p in corners), max(p[1] for p in corners)]

def segment_clear(a, b, box, radius=.25):
    # Exact segment versus an expanded rectangle (conservative capsule test).
    t0,t1 = 0.0,1.0
    for axis in range(2):
        lo,hi = box[axis]-radius,box[axis+2]+radius
        delta = b[axis]-a[axis]
        if abs(delta) < 1e-10:
            if not lo <= a[axis] <= hi:
                return True
        else:
            u,v = sorted(((lo-a[axis])/delta, (hi-a[axis])/delta))
            t0,t1 = max(t0,u),min(t1,v)
            if t0 > t1:
                return True
    return False

route = [(-8.0,0.0),(-12.65,-1.8),(-8.45,-2.45),(-9.9,1.25),(-10.05,3.45)]
room = next(r for r in blockout['spaces'] if r['id']=='F04_B_MAIN')['rect']
margin = blockout['dimensions']['outer_wall']/2
report = {'status':'SOURCE_PASS_RUNTIME_PENDING', 'route_radius_m':.25,
          'main_room_route':route, 'furniture':[], 'texture_sha256':{}}
aliases = {'floor_oak':'oak_quartered','fabric_cool':'linen'}
for record in generated:
    anchor = anchors[record['id']]
    assert anchor['space']=='F04_B_MAIN' and anchor['position'][1]==0
    box = world_bounds(record,anchor)
    assert all(box[i] >= room[i]+margin for i in [0,1]), 'wall overlap'
    assert all(box[i] <= room[i]-margin for i in [2,3]), 'wall overlap'
    assert record['bounds'][0][1]>=0 and record['bounds'][1][1]<3
    assert all(segment_clear(a,b,box) for a,b in zip(route,route[1:])), 'blocked route'
    triangle_count=0
    for surface in record['surfaces']:
        key=aliases.get(surface['material'],surface['material'])
        assert key in materials, 'unbound material: '+key
        vertices,normals=surface['vertices'],surface['normals']
        assert len(vertices)==len(normals) and len(vertices)%9==0
        assert all(math.isfinite(x) for x in vertices+normals)
        for i in range(0,len(normals),3):
            assert abs(sum(v*v for v in normals[i:i+3])-1)<1e-6
        triangle_count+=len(vertices)//9
        for name in materials[key]['files']:
            path=ROOT/'game/assets/building/textures'/name
            assert path.is_file(), 'missing texture: '+name
            report['texture_sha256'][name]=hashlib.sha256(path.read_bytes()).hexdigest()
    report['furniture'].append({'id':record['id'],'world_bounds_xz':box,
                               'triangles':triangle_count,'source_record_retained':True})
# Deliberate blocker must be rejected by the same clearance calculation.
assert not segment_clear(route[0],route[1],[-10.8,-1.5,-9.2,.5])
out=ROOT/'design/astra/evidence/v2_4b_main_furnishing_01'
out.mkdir(parents=True,exist_ok=True)
(out/'source_checks.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: deterministic geometry, unique anchors, room containment, route clearance, normals and shipped materials')
print('Godot was not launched; runtime, interactions and visual presentation remain unverified.')
