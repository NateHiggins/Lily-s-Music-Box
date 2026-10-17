"""Author the complete restored-front lighting fabrication candidate, without installation.

Coordinates are Godot metres. Routes are fixed electrical fabric, not a second
circuit or save authority. Wall cuts remain proposals until native/composed review.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def wall_segments(layout, level):
    for space in layout['spaces']:
        if space['level'] != level or space.get('open_shell'):
            continue
        rect = space['rect']
        for segment in ([{'side': s} for s in space.get('wall_sides', ['south', 'north', 'west', 'east'])]
                        + space.get('wall_extensions', [])):
            side = segment['side']
            axis = 0 if side in ('west', 'east') else 2
            along = 2 - axis
            fixed = rect[{'west': 0, 'east': 2, 'south': 1, 'north': 3}[side]]
            yield dict(space=space['id'], side=side, axis=axis, along=along, fixed=fixed,
                       low=segment.get('start', rect[1 if axis == 0 else 0]),
                       high=segment.get('end', rect[3 if axis == 0 else 2]))


def plan(layout, electrical):
    clear = float(layout['dimensions']['clear_height'])
    if clear != 3.0:
        raise ValueError('Review fixture mounting for changed ceiling height')
    levels = {r['id']: float(r['y']) for r in layout['levels']}
    spaces = [s for s in layout['spaces'] if '_FRONT_' in s['id']]
    if len(spaces) != 20:
        raise ValueError('Review changed restored-front program')
    result = dict(schema_version=1, status='NATIVE_CANDIDATE_NOT_INSTALLED',
                  scope='All twenty restored-front spaces; retained switch, light, circuit and save owners.',
                  fixtures=[], switches=[], routes=[], junctions=[], wall_ports=[], supports=[],
                  source_junctions=[], remaining_acceptance=[
                      'Native source-cover and lamp-canopy entry bores, seating and conductor continuity',
                      'Exact shell/riser/door/furniture collision review of candidate and bounded wall ports',
                      'Authoring projection, catalogue/native import and actual loaded mip validation',
                      'Actual pointer grab/motion/release, circuit authority and disk reconstruction',
                      'Day/night composed visual review, walking routes, light budget and performance',
                      'Human visual and navigation acceptance'])
    routes = result['routes']

    def route(identity, level, points, owner, kind='ceiling'):
        world = [[round(p[0], 6), round(levels[level] + p[1], 6), round(p[2], 6)] for p in points]
        compact = [world[0]]
        for p in world[1:]:
            if p != compact[-1]:
                compact.append(p)
        if len(compact) < 2:
            raise ValueError('Empty route ' + identity)
        routes.append(dict(id=identity, level=level, owner=owner, kind=kind, points=compact,
                           outside_radius=.0125, inside_radius=.0105))

    for level in ['F01', 'F02', 'F03', 'F04', 'F05', 'F06']:
        station = next(s for s in electrical['stations'] if s['id'] == level + '_ELECTRICAL_JUNCTION')
        # Original junction front faces west after WALL_BASIS rotation. The
        # replacement bored cover is fixed fabric, with identical retained screws.
        x, z = electrical['axis']
        sy = station['y'] - levels[level]
        result['source_junctions'].append(dict(id=station['id'], level=level,
            retained='casting, screws, vertical entries and all electrical authorities',
            cover_face=[x - .039, station['y'], z], bore_radius=.0107,
            replace='JunctionCover only; original solid cover must be removed'))
        route(level + '_FRONT_FEED', level,
              [[x - .037, sy, z], [9.30, sy, z], [9.30, 2.95, z], [8.9, 2.95, z]],
              station['id'], 'source')
        route(level + '_FRONT_SPINE', level, [[8.9, 2.95, z], [8.9, 2.95, -11.95]], station['id'])

    for space in spaces:
        identity, level = space['id'], space['level']
        x0, z0, x1, z1 = space['rect']
        name = identity.split('_FRONT_')[1]
        z = (z0 + z1) / 2
        count = 3 if name == 'GALLERY' else 2 if name == 'HALL' else 1
        kind = 'cage_bulb' if name in ('WORKROOM', 'SERVICE_RETURN') else 'flush_dome'
        variant = 'cage_bulb_rise300' if kind == 'cage_bulb' else 'flush_dome'
        y = 2.62 if kind == 'cage_bulb' else 2.92
        xs = [x0 + (x1 - x0) * (n + .5) / count for n in range(count)]
        for n, x in enumerate(xs, 1):
            light = identity + '_LT_' + str(n)
            result['fixtures'].append(dict(id=light, room=identity, level=level, kind=kind,
                variant=variant, position=[round(x, 6), y, round(z, 6)], yaw=0,
                properties=dict(range_clamp=4.6 if count > 1 else 3.0, energy_scale=1.2),
                canopy_seat=[round(x, 6), levels[level] + clear - .08, round(z, 6)],
                ceiling_seat=[round(x, 6), levels[level] + clear, round(z, 6)]))
        # A single lateral distribution per room avoids coincident overlapping
        # home runs to individual lights; the native builder splits at every tee.
        if abs(8.9 - min(xs)) > 1e-6:
            route(identity + '_DISTRIBUTION', level,
                  [[8.9, 2.95, z], [min(xs), 2.95, z]], identity)
        for n, x in enumerate(xs, 1):
            route(identity + '_CANOPY_' + str(n), level,
                  [[x, 2.95, z], [x, 2.918, z]], identity, 'canopy')
        if name in ('GALLERY', 'WORKROOM'):
            position, yaw = [8.198, 1.2, -11.65], math.pi / 2
        elif name == 'HALL':
            position, yaw = [8.198, 1.2, -6.8], math.pi / 2
        elif name == 'SERVICE_RETURN':
            position, yaw = [8.402, 1.2, -11.65], -math.pi / 2
        elif name == 'WEST_BAY':
            position, yaw = [-2.502, 1.2, -11.95], math.pi / 2
        elif name == 'EAST_BAY':
            position, yaw = [5.298, 1.2, -11.4], math.pi / 2
        elif name == 'STORE_ALCOVE':
            # The recess is shallower than the player capsule plus working
            # clearance. Keep the control on its backing wall, reachable from
            # the adjoining lobby rather than requiring entry into the recess.
            position, yaw = [5.55, 1.2, -3.952], 0.0
        else:
            raise ValueError(name)
        # Keep the complete box above the 1.36 m wainscot cap and below the
        # 1.65 m picture rail. Cutting a cap around a switch looks improvised.
        position[1] = 1.48
        # Forty-millimetre hollow surface box: rear bears on the partition,
        # native gasket bears on its front, and 25mm conduit fits in its depth.
        result['switches'].append(dict(id=identity + '_SWITCH', room=identity, level=level,
            position=position, yaw=yaw, backbox_size=[.110, .174, .040],
            backbox_local_center=[0, 0, .012]))
        sx, _, sz = position
        sx += math.sin(yaw) * .012
        sz += math.cos(yaw) * .012
        route(identity + '_SWITCH_FEED', level,
              [[8.9, 2.95, sz], [sx, 2.95, sz], [sx, position[1]+.08, sz]], identity, 'switch')

    # Deduplicate/split all axis-aligned stock at crossings, branches and tips.
    # Native boxes own the resulting vertices: no closed pipes merely cross.
    raw = []
    for row in routes:
        for a, b in zip(row['points'], row['points'][1:]):
            axes = [i for i in range(3) if abs(a[i] - b[i]) > 1e-7]
            if len(axes) != 1:
                raise ValueError('Non-orthogonal route ' + row['id'])
            raw.append((row, a, b, axes[0]))
    vertices = {tuple(p) for _, a, b, _ in raw for p in (a, b)}
    for row, a, b, axis in raw:
        for other, c, d, perpendicular in raw:
            if axis == perpendicular or row['level'] != other['level']:
                continue
            p = list(a)
            p[axis] = c[axis]
            if all(min(a[i], b[i]) - 1e-7 <= p[i] <= max(a[i], b[i]) + 1e-7 and
                   min(c[i], d[i]) - 1e-7 <= p[i] <= max(c[i], d[i]) + 1e-7 for i in range(3)):
                vertices.add(tuple(p))
    edges = {}
    for row, a, b, axis in raw:
        points = sorted((p for p in vertices if all(
            min(a[i], b[i]) - 1e-7 <= p[i] <= max(a[i], b[i]) + 1e-7 for i in range(3))),
            key=lambda p: p[axis])
        for c, d in zip(points, points[1:]):
            key = (c, d)
            if key not in edges:
                edges[key] = dict(level=row['level'], a=list(c), b=list(d), owners=[])
            if row['owner'] not in edges[key]['owners']:
                edges[key]['owners'].append(row['owner'])
    result['segments'] = list(edges.values())
    adjacency = {}
    for segment in result['segments']:
        for p, q in [(segment['a'], segment['b']), (segment['b'], segment['a'])]:
            adjacency.setdefault(tuple(p), set()).add(tuple(q))
    for p, neighbours in sorted(adjacency.items()):
        directions = [tuple(round((q[i] - p[i]) / math.dist(p, q), 6) for i in range(3)) for q in neighbours]
        # Degree-two straight joins use a coupling; corners/tees a bored box.
        straight = len(directions) == 2 and all(abs(sum(d[i] for d in directions)) < 1e-6 for i in range(3))
        result['junctions'].append(dict(position=list(p), directions=directions,
            kind='terminal' if len(directions) == 1 else 'coupling' if straight else 'bored_box'))
    for n, segment in enumerate(result['segments']):
        a, b = segment['a'], segment['b']
        horizontal = abs(a[1] - b[1]) < 1e-6
        length = math.dist(a, b)
        if horizontal and length > .15:
            count = max(1, math.ceil(length / .65))
            for j in range(count):
                at = [a[i] + (b[i] - a[i]) * (j + .5) / count for i in range(3)]
                result['supports'].append(dict(segment=n, position=at,
                    seat=[at[0], levels[segment['level']] + clear, at[2]], owner='ceiling'))
    # Every transverse wall intersection is explicit, including opposing owners
    # of shared partitions. Ports are not permission to cut unrelated masonry.
    for n, segment in enumerate(result['segments']):
        a, b = segment['a'], segment['b']
        for wall in wall_segments(layout, segment['level']):
            axis, along = wall['axis'], wall['along']
            if not min(a[axis], b[axis]) < wall['fixed'] < max(a[axis], b[axis]):
                continue
            t = (wall['fixed'] - a[axis]) / (b[axis] - a[axis])
            p = [a[i] + t * (b[i] - a[i]) for i in range(3)]
            if wall['low'] <= p[along] <= wall['high']:
                result['wall_ports'].append(dict(segment=n, space=wall['space'], side=wall['side'],
                    center=p, half_width=.019, note='Proposed bounded bore, not installed'))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    paths = ['game/data/orison_v2_blockout.json', 'game/data/orison_v2/electrical_service.json']
    data = [json.loads((ROOT / p).read_text(encoding='utf-8')) for p in paths]
    result = plan(*data)
    result['source_bindings_lf'] = {p: hashlib.sha256((ROOT / p).read_bytes().replace(b'\r\n', b'\n')).hexdigest() for p in paths}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
    print({key: len(result[key]) for key in ('fixtures', 'switches', 'segments', 'junctions', 'wall_ports', 'supports')})


if __name__ == '__main__':
    main()
