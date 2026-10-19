"""Validate played service thresholds; this module does not admit ledger evidence."""
import json
import math
import re
from pathlib import Path

from spatial_access_evidence import validate as validate_rooms


def _literal(source, name):
    pattern = rf'^const {name}[ \t]*(?::[ \t]*float)?[ \t]*(?::=|=)[ \t]*([0-9]+(?:\.[0-9]+)?)[ \t]*(?:#.*)?$'
    match = re.search(pattern, source, re.MULTILINE)
    if not match or float(match[1]) <= 0:
        raise ValueError('explicit positive controller literal required: ' + name)
    return float(match[1])


def _inside(point, room, floor):
    r = room['rect']
    return r[0] <= point[0] <= r[2] and r[1] <= point[2] <= r[3] and abs(point[1]-floor) < .15


def validate_connections(data, root, runtime_digest, surface_digest):
    """A valid room receipt alone is insufficient to claim its connecting cutout."""
    root = Path(root).resolve()
    errors = validate_rooms(data, root, runtime_digest, surface_digest)
    if errors:
        return errors
    try:
        from audit_orison_v2_completeness import V2Model
        layout = json.loads((root/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
        identities = [r['id'] for key in ['doors', 'openings'] for r in layout.get(key, [])]
        if len(identities) != len(set(identities)):
            return ['duplicate source connection identity']
        model = V2Model(layout)
        source = (root/'game/scripts/player/player_controller.gd').read_text(encoding='utf-8')
        radius, height = (_literal(source, name) for name in ['BODY_RADIUS', 'STANDING_HEIGHT'])
        thickness = float(layout['dimensions']['partition_wall'])
        if not math.isfinite(thickness) or thickness <= 0:
            return ['positive finite partition wall thickness required']
        admitted = {r['id']: (hall, core, r) for floor in model.levels
                    for hall, core, r in model.service_route_parts(floor)[2]}
        contract = data['contracts']['room_connections']
        claims = contract['connections']
        if contract.get('executed') is not True or contract.get('status') != 'PASS' or not isinstance(claims, dict) or not claims:
            return ['executed PASS with service connection claims required']
        legs = {leg['name']: leg['trace'] for leg in data['legs']}
        room_claims = data['contracts']['room_access']['rooms']
        for identity, claim in claims.items():
            if identity not in admitted or claim.get('id') != identity:
                errors.append('not an actual typed direct service threshold: ' + identity)
                continue
            hall, core, record = admitted[identity]
            pair = {hall['id'], core['id']}
            if {claim['from'], claim['to']} != pair or not pair <= room_claims.keys() or claim['level'] != record['level']:
                errors.append('visited source hall/core endpoints required: ' + identity)
                continue
            coordinates = record['center']+[record['width'], record['height']]
            if not all(type(v) in (int, float) and math.isfinite(v) for v in coordinates) or record['height'] < height:
                errors.append('finite capsule-sized aperture required: ' + identity)
                continue
            trace = legs[claim['leg']]
            before, after = claim['before_index'], claim['after_index']
            if type(before) is not int or type(after) is not int or not 0 <= before < after < len(trace):
                errors.append('ordered actual crossing indices required: ' + identity)
                continue
            points = [row['actual'] for row in trace[before:after+1]]
            if claim['before'] != points[0] or claim['after'] != points[-1]:
                errors.append('crossing points differ from original trace: ' + identity)
                continue
            floor = float(model.levels[record['level']]['y'])
            rooms = {hall['id']: hall, core['id']: core}
            if not _inside(points[0], rooms[claim['from']], floor) or not _inside(points[-1], rooms[claim['to']], floor):
                errors.append('crossing does not enter its declared endpoints: ' + identity)
            if any(not any(_inside(p, room, floor) for room in rooms.values()) for p in points):
                errors.append('crossing detours outside direct source room pair: ' + identity)
            boundary = model._shared_boundary(hall, core)
            normal, along = (0, 2) if boundary['axis'] == 'z' else (2, 0)
            fixed = boundary['fixed']
            centre = record['center'][1 if along == 2 else 0]
            clear = float(record['width'])*.5-radius-.005
            reach = radius+thickness*.5
            first, last = points[0][normal]-fixed, points[-1][normal]-fixed
            if clear <= 0 or first*last >= 0 or min(abs(first), abs(last)) < reach:
                errors.append('full capsule must clear both sides of source wall: ' + identity)
            crossed = False
            for a, b in zip(points, points[1:]):
                difference = b[normal]-a[normal]
                if abs(difference) < 1e-9:
                    if abs(a[normal]-fixed) <= reach and max(abs(a[along]-centre), abs(b[along]-centre)) > clear:
                        errors.append('capsule clips aperture jamb: ' + identity)
                    continue
                for plane in [fixed-reach, fixed, fixed+reach]:
                    t = (plane-a[normal])/difference
                    if 0 <= t <= 1:
                        if abs(a[along]+t*(b[along]-a[along])-centre) > clear:
                            errors.append('capsule clips aperture jamb: ' + identity)
                        if plane == fixed:
                            crossed = True
            if not crossed:
                errors.append('trace never crosses source wall plane: ' + identity)
            if identity in model.doors:
                hand = claim['door_input']
                angles = [hand['actual_angle'], hand['stop_angle']]
                if hand.get('owner') != identity or hand.get('kind') != 'grab_mouse_release' or any(hand.get(k) is not True for k in ['released', 'follows_cursor', 'ready_for_passage']):
                    errors.append('actual acquired/moved/released door input required: ' + identity)
                if not all(type(v) in (int, float) and math.isfinite(v) for v in angles) or abs(angles[1]) < .5 or abs(angles[0]-angles[1]) > .01:
                    errors.append('actual door body must reach its open stop: ' + identity)
    except (KeyError, TypeError, ValueError, OSError, AttributeError, IndexError, OverflowError) as exc:
        errors.append('malformed service connection receipt: ' + str(exc))
    return errors
