"""Six-home native accessory placement, checked without an engine launch."""
import argparse
import copy
import importlib.util
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
TARGET = 'game/data/orison_v2/household_accessories.json'
UNITS = ['2A', '2B', '3A', '3B', '4A', '4B']
OFFSETS = dict(zip(UNITS, [.242, .202, .242, .392, .202, .222]))


def load(path):
    return json.loads((ROOT/path).read_text(encoding='utf-8'))


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def transform(anchor, point):
    c, s = math.cos(anchor['yaw']), math.sin(anchor['yaw'])
    x, y, z = point
    p = anchor['position']
    return [p[0]+c*x+s*z, p[1]+y, p[2]-s*x+c*z]


def world_pose(record, anchors):
    support = anchors[record['support']]
    return dict(position=transform(support, record['position']),
                yaw=support['yaw']+record['yaw'], level=support['level'])


def manifest():
    markers = [m for f in load('game/data/building_layout.json')['floors']
               for m in f.get('markers', [])]
    rows = []
    for unit in UNITS:
        for kind in ['toaster', 'mirror']:
            source = next(m for m in markers if m.get('unit') == unit and m.get('kind') == kind)
            toaster = kind == 'toaster'
            row = dict(id=source['id'], unit=unit, kind=kind,
                       support=unit+'_prep_cabinet' if toaster else 'F0'+unit[0]+'_'+unit+'_SINK_01',
                       position=[0, .9, 0] if toaster else [0, .04, OFFSETS[unit]], yaw=0)
            if toaster:
                row['tray_axis'] = source.get('tray_axis', '-z')
                row['bounds'] = [[-.16, 0, -.15], [.16, .20, .08]]
                row['motion_bounds'] = [[-.29 if unit == '4B' else -.16, 0, -.15 if unit == '4B' else -.235], [.16, .20, .08]]
            else:
                row['hinge_side'] = source.get('hinge_side', 'left')
                row['bounds'] = [[-.254, 1.176, -.10], [.254, 1.834, .058]]
            # Feet stance is relative to the existing floor-mounted support.
            row['stance'] = [0, 0, -.78 if unit == '3B' and not toaster else -.85]
            rows.append(row)
    return dict(schema_version=1, accessories=rows)


def geometry(data):
    geo = module('design/astra/work/v2_storage_tables_boards_batch_01/build.py', 'accessory_geo')
    walls = module('design/astra/work/v2_apartment_walls_batch_01/build.py', 'accessory_walls')
    doors = module('design/astra/work/v2_apartment_doors_batch_01/check.py', 'accessory_doors')
    surfaces = module('design/astra/work/v2_surface_props_batch_01/build.py', 'accessory_surfaces')
    layout = load('game/data/orison_v2_blockout.json')
    anchors = {a['id']: a for a in layout['anchors']}
    furniture = load('game/data/orison_v2/domestic_furniture.json')['furniture']
    by_id = {r['id']: r for r in furniture}
    owned = {r['id'] for r in data['accessories']}
    obstacles = [r for r in geo.obstacles(layout, furniture) if r[0] not in owned]
    volumes = [(r['id'], anchors[r['support']]['level'], geo.volume(r['bounds'], world_pose(r, anchors)))
               for r in data['accessories']]
    all_obstacles = obstacles + volumes
    wall_list = walls.owned(layout)
    thickness = layout['dimensions']['partition_wall']/2
    contact_points = 0
    sweep_poses = 0
    sight_samples = 0
    backing = []
    motion_volumes = []
    for row in data['accessories']:
        pose = world_pose(row, anchors)
        identity, level = row['id'], pose['level']
        b = geo.volume(row['bounds'], pose)
        if row['kind'] == 'toaster':
            assert row['position'][1] == .9, ('countertop height', identity)
            for x in [-.119, -.091, .091, .119]:
                for z in [-.059, -.031, .031, .059]:
                    local = transform(dict(position=row['position'], yaw=row['yaw']), [x, 0, z])
                    assert surfaces.on_surface(by_id[row['support']], [local[0], local[2]], local[1]), ('unsupported toaster foot', identity)
                    contact_points += 1
            b = geo.volume(row['motion_bounds'], pose)
            sweep_poses += 1
            motion_volumes.append((identity, level, b))
        else:
            # Union adjacent collinear walls: 4B straddles its explicit wall
            # extension. Check real solid backing at 33 points, not a marker.
            owners = set()
            for i in range(33):
                point = transform(pose, [-.254+.508*i/32, 1.505, .058])
                matches = []
                for wall in wall_list:
                    if wall['level'] != level:
                        continue
                    axis = 0 if wall['axis'] == 'x' else 2
                    fixed = 2-axis
                    if abs(abs(point[fixed]-wall['fixed'])-thickness) > 1e-6:
                        continue
                    if not wall['start']-1e-6 <= point[axis] <= wall['end']+1e-6:
                        continue
                    if any(c['start'] < point[axis] < c['end'] and
                           min(b[4], c['sill']+c['height']) > max(b[1], c['sill'])
                           for c in walls.apertures(layout, wall)):
                        continue
                    matches.append(wall['owner']+':'+wall['side'])
                assert matches, ('cabinet lacks continuous solid backing', identity, point)
                owners.update(matches)
                contact_points += 1
            backing.append(dict(id=identity, walls=sorted(owners)))
            side = 1 if row['hinge_side'] == 'left' else -1
            for degrees in range(96):
                hinge = transform(pose, [side*.23, 1.505, -.060])
                leaf_pose = dict(position=hinge, yaw=pose['yaw']-side*math.radians(degrees))
                # Include the pull, nickel trim, backing and moving collider.
                low_x, high_x = sorted([0, -side*.46])
                leaf = geo.volume([[low_x-.012, -.305, -.041], [high_x+.012, .305, .028]], leaf_pose)
                for other, floor, c in all_obstacles:
                    if floor == level and other != identity:
                        assert not geo.overlap(leaf, c), ('cabinet swing overlap', identity, other, degrees)
                for wall in wall_list:
                    if wall['level'] != level:
                        continue
                    axis = 0 if wall['axis'] == 'x' else 2
                    wb = ([wall['start'], 0, wall['fixed']-thickness, wall['end'], 2.5, wall['fixed']+thickness]
                          if axis == 0 else [wall['fixed']-thickness, 0, wall['start'], wall['fixed']+thickness, 2.5, wall['end']])
                    assert not geo.overlap(leaf, wb), ('cabinet leaf hits wall', identity, degrees, wall['owner'])
                motion_volumes.append((identity, level, leaf))
                sweep_poses += 1
        for other, floor, c in all_obstacles:
            if floor == level and other != identity:
                assert not geo.overlap(b, c), ('accessory overlap', identity, other)
        stance = transform(anchors[row['support']], row['stance'])
        for other, floor, c in all_obstacles:
            if floor == level and c[1] < 1.574 and c[4] > .02:
                assert doors.distance([stance[0], stance[2]], doors.rect_polygon([c[0], c[2], c[3], c[5]])) >= .38, ('blocked accessory stance', identity, other)
        target = transform(pose, [0, .11, 0] if row['kind'] == 'toaster' else [0, 1.505, -.08])
        eye = [stance[0], 1.41, stance[2]]
        assert math.dist(eye, target) < 2.1, ('accessory beyond reach', identity)
        for n in range(101):
            point = [eye[i]+(target[i]-eye[i])*n/100 for i in range(3)]
            for other, floor, c in all_obstacles:
                if floor == level and other != identity:
                    assert not all(c[i] < point[i] < c[i+3] for i in range(3)), ('blocked accessory sightline', identity, other)
            sight_samples += 1
    samples, sweeps = geo.check_routes_and_doors(layout, volumes)
    # Actual cabinet motion is also checked against all established routes.
    geo.check_routes_and_doors(layout, motion_volumes)
    return dict(contact_points=contact_points, mechanism_poses=sweep_poses,
                sightline_samples=sight_samples, route_samples=samples, domestic_door_sweeps=sweeps, backing=backing)


def build(apply=False):
    data = manifest()
    assert len(data['accessories']) == 12
    checks = geometry(data)
    if apply:
        (ROOT/TARGET).write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')
    else:
        assert load(TARGET) == data, 'generated accessory manifest drift'
    receipt = dict(status='SOURCE_PASS_RUNTIME_PENDING', godot='NOT_RUN', base='d7f9f8e',
                   toasters=6, medicine_cabinets=6, reflection_viewports=1, checks=checks,
                   limits='Native mechanisms and material bindings reused; no new electrical supply model. Source envelopes/contact/swing checks do not prove compiled execution, interaction rays, reflection appearance, voxel lighting, lifecycle, traversal or performance.')
    (OUT/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(receipt))


if __name__ == '__main__':
    args = argparse.ArgumentParser()
    args.add_argument('--apply', action='store_true')
    build(args.parse_args().apply)
