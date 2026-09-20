"""Source-only geometry audit; does not execute GDScript or prove playability."""
import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, 'C:/Users/nate_/.cache/orison-source-tools/gdtoolkit')
from gdtoolkit.parser import parser

def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))

def one(records, identity):
    matches = [r for r in records if r['id'] == identity]
    assert len(matches) == 1, identity
    return matches[0]

config = read('game/data/orison_v2/world_connection.json')
layout = read('game/data/orison_v2_blockout.json')
regions = read('game/data/orison_v2/exterior/regions.json')
geometry = read('game/data/orison_v2/exterior/exterior_geometry.json')
door = one(layout['doors'], config['door_id'])
inside = one(layout['spaces'], config['inside_space_id'])
outside = one(layout['spaces'], config['outside_space_id'])
assert set(door['connects']) == {inside['id'], outside['id']}
assert outside['open_shell']
template = one(regions['surface_templates'], config['template_id'])
surface = one(template['surfaces'], config['surface_id'])
assert surface['normal'] == [0, 0, 1]
assert surface['point_m'] == [0, 0, 0]
assert 0 < door['width'] <= surface['size_m'][0]
assert 0 < door['height'] <= surface['size_m'][1]
rect = inside['rect']
threshold = [door['center'][0], one(layout['levels'], door['level'])['y'], door['center'][1]]
room_center = [(rect[0]+rect[2])/2, threshold[1], (rect[1]+rect[3])/2]
outward = [threshold[i]-room_center[i] for i in range(3)]
yaw = math.atan2(surface['normal'][0], surface['normal'][2]) - math.atan2(outward[0], outward[2])

def rotate(p):
    return [math.cos(yaw)*p[0]+math.sin(yaw)*p[2], p[1], -math.sin(yaw)*p[0]+math.cos(yaw)*p[2]]

origin = [surface['point_m'][i]-rotate(threshold)[i] for i in range(3)]

def transform(p):
    return [rotate(p)[i]+origin[i] for i in range(3)]

assert all(abs(v) < 1e-8 for v in transform(threshold))
assert transform(room_center)[2] < 0
assert rotate(outward)[2] > 0
opened = copy.deepcopy(one(geometry['templates'], config['template_id']))
for identity in config['remove_boxes'] + config['split_boxes']:
    one(opened['boxes'], identity)
opened['boxes'] = [b for b in opened['boxes'] if b['id'] not in config['remove_boxes']]
for identity in config['split_boxes']:
    box = one(opened['boxes'], identity)
    assert box['yaw_degrees'] == 0
    left = box['position_m'][0] - box['size_m'][0]/2
    right = box['position_m'][0] + box['size_m'][0]/2
    half = surface['size_m'][0]/2
    opened['boxes'].remove(box)
    for a, b, suffix in [(left, -half, 'left'), (half, right, 'right')]:
        assert b > a
        part = copy.deepcopy(box)
        part['id'] += '_' + suffix
        part['position_m'][0] = (a+b)/2
        part['size_m'][0] = b-a
        opened['boxes'].append(part)

# Inspect the full door-width corridor above the retained threshold step.
# This is axis-aligned source AABB clearance, not Godot collision or walking.
blockers = []
for box in opened['boxes']:
    if not box['collision']:
        continue
    p, size = box['position_m'], box['size_m']
    angle = math.radians(box['yaw_degrees'])
    sx = abs(math.cos(angle))*size[0] + abs(math.sin(angle))*size[2]
    sz = abs(math.sin(angle))*size[0] + abs(math.cos(angle))*size[2]
    if (p[0]+sx/2 > -door['width']/2 and p[0]-sx/2 < door['width']/2
        and p[1]+size[1]/2 > .15 and p[1]-size[1]/2 < door['height']
        and p[2]+sz/2 > -.6 and p[2]-sz/2 < .6):
        blockers.append(box['id'])
assert not blockers, blockers

paths = ['game/scripts/building/orison_v2_world_connection.gd',
         'game/scripts/building/orison_v2_runtime_root.gd',
         'game/scripts/building/orison_v2_blockout.gd',
         'game/scripts/game/first_shift_director.gd',
         'game/tests/orison_v2_connected_world_test.gd']
for path in paths:
    parser.parse((ROOT/path).read_text(encoding='utf-8'))
protected = ['game/scripts/building/building_root_selector.gd',
             'game/data/building_layout.json', 'art/data/building_layout.json']
for level in ['01', '02', '03', '04', '05', '06', 'b1']:
    for extension in ['gltf', 'bin']:
        protected.append(f'game/assets/building/floor_{level}.{extension}')
for path in protected:
    assert (ROOT/path).exists(), path
assert subprocess.run(['git', 'diff', '--exit-code', 'HEAD', '--', *protected], cwd=ROOT).returncode == 0
receipt = {
    'status': 'SOURCE_CHECKS_PASS_NATIVE_UNRUN',
    'scope': 'gdtoolkit 4.5 syntax parser and independent authored-geometry calculation only',
    'native_godot_started': False,
    'interior_yaw_degrees': math.degrees(yaw),
    'interior_origin': origin,
    'transformed_vestibule_center': transform(room_center),
    'door_corridor_source_blockers': blockers,
    'preserved_protected_paths': protected,
    'files': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths + [
        'game/data/orison_v2/world_connection.json', 'game/tests/OrisonV2ConnectedWorldTest.tscn']},
    'pending': ['Godot compilation', 'two-cycle composed test', 'capsule walk both directions',
                'bodega purchase in the shared work order', 'matched player-view captures',
                'streaming, full V2 completion, performance and human acceptance'],
}
(Path(__file__).parent/'source_checks.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt, indent=2))
