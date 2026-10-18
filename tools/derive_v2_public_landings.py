"""Measure public landing programmes from retained physical platform ownership.

Read-only diagnosis: emits no runtime acceptance and never edits the layout.
The rectangular review shells are not a description of walkable floor.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def union(rectangles):
    """Exact axis-aligned union area and exposed (including hole) edges."""
    if not rectangles:
        raise ValueError("Landing requires physical support rectangles")
    for r in rectangles:
        if len(r) != 4 or not all(type(v) in (int, float) and math.isfinite(v) for v in r):
            raise ValueError("Finite four-coordinate rectangles required")
        if r[0] >= r[2] or r[1] >= r[3]:
            raise ValueError("Positive platform footprint required")
    xs = sorted({v for r in rectangles for v in (r[0], r[2])})
    zs = sorted({v for r in rectangles for v in (r[1], r[3])})
    filled = set()
    for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
        for j, (z0, z1) in enumerate(zip(zs, zs[1:])):
            x, z = (x0+x1)/2, (z0+z1)/2
            if any(r[0] < x < r[2] and r[1] < z < r[3] for r in rectangles):
                filled.add((i, j))
    area = 0.0
    edges = []
    for i, j in sorted(filled):
        x0, x1, z0, z1 = xs[i], xs[i+1], zs[j], zs[j+1]
        area += (x1-x0)*(z1-z0)
        for neighbour, edge in [((i-1, j), [[x0,z0],[x0,z1]]),
                                ((i+1, j), [[x1,z0],[x1,z1]]),
                                ((i, j-1), [[x0,z0],[x1,z0]]),
                                ((i, j+1), [[x0,z1],[x1,z1]])]:
            if neighbour not in filled:
                edges.append(edge)
    return area, edges


def contains(rectangles, point):
    x, z = point
    return any(r[0] <= x <= r[2] and r[1] <= z <= r[3] for r in rectangles)


def segment_distance(point, edge):
    x,z = point; (ax,az),(bx,bz) = edge
    dx,dz = bx-ax,bz-az
    t = max(0.0,min(1.0,((x-ax)*dx+(z-az)*dz)/(dx*dx+dz*dz)))
    return math.hypot(x-ax-t*dx,z-az-t*dz)


def capsule_supported(rectangles, point, radius):
    """A complete horizontal disc must fit, including around concave holes."""
    if not math.isfinite(radius) or radius <= 0:
        raise ValueError("Positive finite capsule radius required")
    if not contains(rectangles,point):
        return False
    _,edges = union(rectangles)
    return all(segment_distance(point,edge) >= radius-1e-9 for edge in edges)


def capsule_segment_supported(rectangles, start, end, radius):
    """Check the whole straight axis-aligned sweep, not only its endpoints."""
    if start[0] != end[0] and start[1] != end[1]:
        raise ValueError('Axis-aligned landing route segment required')
    if not capsule_supported(rectangles,start,radius) or not capsule_supported(rectangles,end,radius):
        return False
    if start == end:
        return True
    _,edges = union(rectangles)
    segment = [start,end]
    for edge in edges:
        # Axis-aligned segments intersect iff both bounding intervals overlap.
        if all(max(min(start[k],end[k]),min(edge[0][k],edge[1][k])) <=
               min(max(start[k],end[k]),max(edge[0][k],edge[1][k])) for k in [0,1]):
            return False
        distance = min(segment_distance(p,edge) for p in segment)
        distance = min(distance,*(segment_distance(p,segment) for p in edge))
        if distance < radius-1e-9:
            return False
    return True


def body_radius(source):
    match = re.search(r'^const BODY_RADIUS\s*:=\s*([0-9]+(?:\.[0-9]+)?)\s*$',source,re.MULTILINE)
    if not match or float(match.group(1)) <= 0:
        raise ValueError('Explicit positive production BODY_RADIUS literal required')
    return float(match.group(1))


def derive(layout, capsule_radius):
    levels = {r['id']:r for r in layout['levels']}
    platforms = layout['platforms']
    identities = [r['id'] for r in platforms]
    if len(set(identities)) != len(identities):
        raise ValueError("Duplicate physical platform identity")
    output = []
    for floor in [f'F{i:02d}' for i in range(1,7)]:
        if floor not in levels:
            raise ValueError("Missing canonical floor: "+floor)
        prefix = floor+'_PUBLIC_LANDING_'
        owners = [r for r in platforms if r['id'].startswith(prefix)]
        if not owners or any(r.get('level') != floor for r in owners):
            raise ValueError("Missing or foreign-floor landing stock: "+floor)
        rects = [r['rect'] for r in owners]
        area,edges = union(rects)
        spaces = [r for r in layout['spaces'] if r['id'] == floor+'_LANDING']
        legacy = [r for r in spaces if 'floor_platforms' not in r]
        programmes = [r for r in spaces if 'floor_platforms' in r]
        for space in programmes:
            from v2_space_footprints import programme_errors
            if programme_errors(layout,space):
                raise ValueError('Invalid installed landing programme: '+floor)
        old_area = 0.0
        if legacy:
            r = legacy[0]['rect']
            total,_ = union(rects+[r])
            old_area = total-area
        reviews = [r for r in layout['anchors'] if r['id'] == floor+'_LANDING_REVIEW']
        witness = [reviews[0]['position'][0],reviews[0]['position'][2]] if reviews else None
        candidates = []
        for owner in owners:
            r = owner['rect']
            point = [(r[0]+r[2])/2,(r[1]+r[3])/2]
            if capsule_supported(rects,point,capsule_radius):
                candidates.append({'support_id':owner['id'],
                                   'position':[point[0],levels[floor]['y'],point[1]]})
        output.append({'id':floor+'_PUBLIC_LANDING_PROGRAMME','level':floor,
                       'support_ids':[r['id'] for r in owners],
                       'support_rects':rects,'union_area_m2':round(area,9),
                       'exposed_edges':edges,
                       'legacy_space_id':legacy[0]['id'] if legacy else None,
                       'programme_space_id':programmes[0]['id'] if programmes else None,
                       'legacy_unsupported_area_m2':round(old_area,9),
                       'review_stance':witness,
                       'geometric_stance_candidates':candidates,
                       'review_stance_supports_capsule':
                           capsule_supported(rects,witness,capsule_radius) if witness else None})
    return {'evidence_class':'INERT','scope':'Physical footprint derivation only. No runtime or spatial acceptance; no floor or shaft geometry changed.',
            'source':'game/data/orison_v2_blockout.json',
            'capsule_radius_m':capsule_radius,'landings':output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path)
    args = parser.parse_args()
    source = (ROOT/'game/data/orison_v2_blockout.json').read_bytes().replace(b'\r\n',b'\n')
    controller_path = 'game/scripts/player/player_controller.gd'
    controller = (ROOT/controller_path).read_bytes().replace(b'\r\n',b'\n')
    result = derive(json.loads(source.decode('utf-8')),body_radius(controller.decode('utf-8')))
    result['source_sha256_lf'] = hashlib.sha256(source).hexdigest()
    result['controller_source'] = controller_path
    result['controller_sha256_lf'] = hashlib.sha256(controller).hexdigest()
    text = json.dumps(result,indent=2)+'\n'
    if args.out:
        destination = args.out.resolve()
        if not destination.is_relative_to(ROOT/'tmp'):
            raise SystemExit('Diagnosis output must remain below repository tmp/')
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_text(text,encoding='utf-8',newline='\n')
    else:
        print(text,end='')


if __name__ == '__main__':
    main()
