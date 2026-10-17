"""Project the four-emitter retrofit while preserving existing world authorities."""
import argparse
import copy
import json
import math
from pathlib import Path
from build_v2_roof import render

ROOT = Path(__file__).resolve().parents[1]
TABLES = {'anchors', 'wall_service_openings', 'riser_openings', 'slab_openings', 'masonry_service_openings'}

def _box_valid(bounds):
    return isinstance(bounds, list) and len(bounds) == 6 and all(type(v) in (int, float) and math.isfinite(v) for v in bounds) and all(bounds[i] < bounds[i+3] for i in range(3))

def _enclosed(bounds, owner):
    return _box_valid(bounds) and all(owner[i]-1e-5 <= bounds[i] and bounds[i+3] <= owner[i+3]+1e-5 for i in range(3))

def project(layout, heating, authoring):
    if authoring.get('schema_version') != 1 or authoring.get('evidence_class') != 'INERT':
        raise ValueError('Unknown heating authoring schema')
    source = authoring['projection']
    if set(source['records']) != TABLES:
        raise ValueError('Retrofit must name only its five owned layout tables')
    result, heat = copy.deepcopy(layout), copy.deepcopy(heating)
    rooms = {row['id']: row for row in layout['spaces']}
    risers = {row['id']: row for row in layout['risers']}
    levels = {row['id']: row['y'] for row in layout['levels']}
    dimensions = layout['dimensions']
    demands = {row['id']: row for row in heating['network']}
    if len(demands) != 23 or len(heating['network']) != 23:
        raise ValueError('The original twenty-three-demand budget must remain complete')
    additions = source['append_installed_radiators']
    if {row['unit'] for row in additions} != {'2D', '3C', '5D', '6D'} or len(additions) != 4:
        raise ValueError('Unexpected installed household set')
    if {row['id'] for row in source['records']['anchors']} != {row['id'] for row in additions} or len(source['records']['anchors']) != 4:
        raise ValueError('Each added demand needs exactly one spatial anchor')
    for row in additions:
        if row != {key: demands.get(row['id'], {}).get(key) for key in ['id', 'unit', 'riser', 'sections']}:
            raise ValueError('Installation disagrees with original demand: '+row['id'])
    identities = {}
    for table, rows in layout.items():
        if not isinstance(rows, list): continue
        for row in rows:
            if isinstance(row, dict) and 'id' in row:
                identities.setdefault(row['id'], []).append((table, row))
    incoming = [row['id'] for rows in source['records'].values() for row in rows]
    if len(incoming) != len(set(incoming)):
        raise ValueError('Duplicate projected id across layout tables')
    for table, rows in source['records'].items():
        for row in rows:
            previous = identities.get(row['id'], [])
            if previous and previous != [(table, row)]:
                raise ValueError('Refusing to overwrite an existing owner: '+row['id'])
            if table == 'anchors':
                room = rooms.get(row['space'])
                point = row['position']
                if room is None or room['level'] != row['level'] or len(point) != 3 or not all(type(v) in (int, float) and math.isfinite(v) for v in point):
                    raise ValueError('Invalid emitter anchor frame')
                if not (room['rect'][0] < point[0] < room['rect'][2] and room['rect'][1] < point[2] < room['rect'][3]) or abs(point[1]-.75) > 1e-8:
                    raise ValueError('Emitter anchor exceeds its room or mounting datum')
                if row.get('kind') != 'interaction' or type(row.get('yaw')) not in (int, float) or not math.isfinite(row['yaw']):
                    raise ValueError('Invalid emitter interaction frame')
            elif table == 'slab_openings':
                room = rooms.get(row['space']); rect = row['rect']
                if room is None or row['surface'] not in ['Floor', 'Ceiling'] or len(rect) != 4 or not all(type(v) in (int, float) and math.isfinite(v) for v in rect) or not (rect[0] < rect[2] and rect[1] < rect[3]):
                    raise ValueError('Invalid owned slab opening')
                if not (room['rect'][0] <= rect[0] and room['rect'][1] <= rect[1] and rect[2] <= room['rect'][2] and rect[3] <= room['rect'][3]):
                    raise ValueError('Slab cut exceeds its owner')
            elif table == 'wall_service_openings':
                room = rooms.get(row['space']); side = row['side']
                if room is None or side not in ['north', 'south', 'west', 'east']:
                    raise ValueError('Invalid wall owner')
                rect = room['rect']; y = levels[room['level']]; half = dimensions['partition_wall']/2
                height = dimensions['floor_to_floor'] if room.get('no_ceiling') else dimensions['clear_height']
                if side in ['north', 'south']:
                    fixed = rect[3 if side == 'north' else 1]; bounds = [rect[0], y, fixed-half, rect[2], y+height, fixed+half]
                else:
                    fixed = rect[2 if side == 'east' else 0]; bounds = [fixed-half, y, rect[1], fixed+half, y+height, rect[3]]
                if not _enclosed(row['bounds'], bounds): raise ValueError('Wall cut exceeds its owner')
            elif table == 'riser_openings':
                shaft = risers.get(row['riser'])
                if shaft is None: raise ValueError('Missing shaft owner')
                x, z, xx, zz = shaft['rect']
                if not _enclosed(row['bounds'], [x, shaft['from_y'], z, xx, shaft['to_y'], zz]): raise ValueError('Shaft cut exceeds its owner')
            elif row.get('owner') != 'ExteriorMasonry' or not _box_valid(row['bounds']):
                raise ValueError('Invalid masonry cut')
            if not previous: result.setdefault(table, []).append(copy.deepcopy(row))
    replacements = source['replace_riser_openings']
    if len(replacements) != 1 or replacements[0]['id'] != 'HEAT_H-D_MAIN_CLEAR':
        raise ValueError('Only the existing H-D main bore may be extended')
    replacement = replacements[0]
    previous = [row for row in result['riser_openings'] if row['id'] == replacement['id']]
    if len(previous) != 1 or previous[0]['riser'] != replacement['riser'] or previous[0]['bounds'][:4] != replacement['bounds'][:4] or previous[0]['bounds'][5] != replacement['bounds'][5] or previous[0]['bounds'][4] > replacement['bounds'][4]:
        raise ValueError('Main bore extension would alter another dimension or shorten the main')
    previous[0]['bounds'][4] = replacement['bounds'][4]
    shaft = risers[replacement['riser']]; x, z, xx, zz = shaft['rect']
    if not _enclosed(replacement['bounds'], [x, shaft['from_y'], z, xx, shaft['to_y'], zz]):
        raise ValueError('Extended main bore exceeds its shaft')
    installed = {row['id']: row for row in heat['installed']}
    for row in additions:
        if row['id'] in installed and installed[row['id']] != row:
            raise ValueError('Refusing to replace an existing emitter owner')
        if row['id'] not in installed: heat['installed'].append(copy.deepcopy(row))
    if len(heat['installed']) != 23 or len({row['unit'] for row in heat['installed']}) != 23:
        raise ValueError('Installed roster must cover exactly twenty-three distinct demands')
    if heat['network'] != heating['network']:
        raise ValueError('Thermal demand authority changed')
    return result, heat

def revise(layout, heating, authoring, previous):
    """Replace only a fully matched earlier owned projection, never foreign data."""
    for key in ['base_native', 'source_layout', 'authority_lf']:
        if authoring[key] != previous[key]:
            raise ValueError('Revision changes pinned authority: '+key)
    if authoring['projection']['append_installed_radiators'] != previous['projection']['append_installed_radiators']:
        raise ValueError('Revision changes installed demand authority')
    if authoring['projection']['records']['anchors'] != previous['projection']['records']['anchors']:
        raise ValueError('Revision relocates an emitter owner')
    # The previous declaration must describe the actual installed records;
    # missing or modified records require review instead of being recreated.
    result = copy.deepcopy(layout)
    for table, records in previous['projection']['records'].items():
        if table not in TABLES:
            raise ValueError('Unknown previous owned table')
        for record in records:
            existing = [row for row in result.get(table, []) if row.get('id') == record['id']]
            if existing != [record]:
                raise ValueError('Previous owned record changed: '+record['id'])
        identities = {row['id'] for row in records}
        result[table] = [row for row in result.get(table, []) if row.get('id') not in identities]
    return project(result, heating, authoring)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--plan', type=Path, default=ROOT/'art/data/orison_v2/heating_refit_authoring.json')
    parser.add_argument('--previous-plan', type=Path, help='Explicit exact-match revision of an already installed owned projection')
    args = parser.parse_args()
    layout_path = ROOT/'game/data/orison_v2_blockout.json'; heat_path = ROOT/'game/data/orison_v2/heating.json'
    raw = layout_path.read_bytes().decode('utf-8'); layout = json.loads(raw); heating = json.loads(heat_path.read_text())
    authoring = json.loads(args.plan.read_text())
    new_layout, new_heat = (revise(layout, heating, authoring, json.loads(args.previous_plan.read_text()))
                            if args.previous_plan else project(layout, heating, authoring))
    changed = layout != new_layout or heating != new_heat
    if args.apply:
        ending = '\r\n' if '\r\n' in raw else '\n'
        layout_path.write_bytes(render(raw.replace('\r\n', '\n'), new_layout).replace('\n', ending).encode('utf-8'))
        heat_path.write_text(json.dumps(new_heat, indent=2)+'\n', encoding='utf-8', newline='\n')
    print(json.dumps({'applied': args.apply, 'projection_changed': changed, 'installed_emitters': len(new_heat['installed']), 'thermal_demands_unchanged': True}))
    return 0 if args.apply or not changed else 1

if __name__ == '__main__':
    raise SystemExit(main())
