"""Inventory explicit V2 acoustic owners without approving topology or guessing aliases."""
import argparse
import hashlib
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LIGHT_KINDS = {'pendant_shade', 'flush_dome', 'sconce_globe', 'kitchen_linear',
               'cage_bulb', 'chandelier', 'eye_pendant', 'street_lamp'}


def fitted_layout(layout, retained, nook):
    """Source projections of the nook bodies and facade blade's masonry seat."""
    result = dict(layout, anchors=list(layout['anchors']))
    levels = {r['id']: r['y'] for r in layout['levels']}
    for row in nook['assemblies']:
        x, y, z = row['position']
        result['anchors'].append({'id': row['id'], 'level': 'B1', 'kind': 'furniture',
            'position': [x, y+nook['floor_y']-levels['B1'], z], 'yaw': row['yaw'],
            'projection_source': 'game/data/orison_v2/reading_nook.json'})
    doors = [d for d in layout['doors'] if d['id'] == 'F01_DOOR_06']
    blades = [m for f in retained['floors'] if f['id'] == 'F01'
              for m in f['markers'] if m['id'] == 'F01_NEON_BLADE']
    if len(doors) != 1 or len(blades) != 1:
        raise ValueError('Unique facade door and blade marker required')
    door, marker = doors[0], blades[0]
    reach = layout['dimensions']['outer_wall']-layout['dimensions']['partition_wall']*.5
    seats = []
    for level in ('F02', 'F03'):
        candidates = [s for s in layout['spaces'] if s['level'] == level
            and not s.get('open_shell', False)
            and 'south' in s.get('wall_sides', ['south','north','west','east'])
            and s['rect'][2] < -door['width']*.5 and s['rect'][1] <= door['center'][1]]
        if not candidates: raise ValueError('Missing facade masonry seat')
        seat = max(candidates, key=lambda s: s['rect'][2])
        seats.append([seat['rect'][2]-.25, seat['rect'][1]-reach])
    if any(abs(a-b) > .00001 for a,b in zip(*seats)):
        raise ValueError('Facade blade seats disagree between floors')
    result['anchors'].append({'id': marker['id'], 'level': 'F01', 'kind': 'fixture',
        'position': [seats[0][0], marker['pos'][2]-levels['F01'], seats[0][1]],
        'projection_source': 'game/scripts/building/orison_v2_front_facade.gd'})
    return result


def region_markers(retained_layout, registry, street_frame):
    """Project retained actors through their explicit production region datums."""
    markers = [m for floor in retained_layout['floors'] if floor['id'] == 'F01'
               for m in floor['markers']]
    entrances = [m for m in markers if m['id'] == 'F01_DOOR_06']
    bars = [c for c in registry['cells'] if c['id'] == 'CELL_SHOP_BAR']
    if len(entrances) != 1 or len(bars) != 1 or entrances[0].get('yaw_deg') != 0:
        raise ValueError('Unique authored entrance and bar registry required')
    entry = entrances[0]
    ex, ey, ez = entry['pos']
    passage_origin = [-ex-entry['w']*.5, -ez, ey]
    bar_ids = set(bars[0]['semantic_owners'])
    output = defaultdict(list)
    for m in markers:
        kind = m['kind']
        passage = m.get('zone') == 'PASSAGE' or m['id'].startswith('PASSAGE_PORTAL_LT_')
        region = ''
        if passage and kind in LIGHT_KINDS:
            origin, region = passage_origin, 'VantryArcade'
        elif m['id'] in bar_ids and kind in LIGHT_KINDS | {'neon_sign', 'speaker'}:
            origin, region = [0, 0, -street_frame['source_threshold_z']], 'Harukiya'
        if not region:
            continue
        x, y, z = m['pos']
        output[m['id']].append({'region': region, 'marker': m,
            'position_world_godot': [x+origin[0], z+origin[1], -y+origin[2]]})
    return output


def observation_errors(observation, receipt, observer_bytes, graph_bytes, runtime_digest):
    """Check an observational run's provenance; never promote it to runtime proof."""
    errors = []
    execution = receipt.get('execution', {})
    if receipt.get('evidence_kind') != 'suite_run' or execution.get('completed') is not True or execution.get('exit_code') != 0 or execution.get('timed_out') is not False:
        errors.append('observer did not complete successfully')
    if receipt.get('log', {}).get('script_error_count', 0) or receipt.get('log', {}).get('fail_count', 0):
        errors.append('observer log contains failures')
    if receipt.get('source', {}).get('runtime_inputs_sha256') != runtime_digest:
        errors.append('observed production inputs are stale')
    if observation.get('observer_sha256') != hashlib.sha256(observer_bytes).hexdigest():
        errors.append('observer source changed')
    if observation.get('legacy_graph_sha256') != hashlib.sha256(graph_bytes).hexdigest():
        errors.append('observed legacy graph changed')
    if observation.get('graph_restored_exactly') is not True:
        errors.append('shared graph restoration was not confirmed')
    if not observation.get('interior_frame'):
        errors.append('world registration frame missing')
    return errors


def ownership(layout, graph, observation=None, terminal_fit=None, fitted_boiler=False, attachments=(), regions=None):
    levels = {row['id']: row['y'] for row in layout['levels']}
    anchors = defaultdict(list)
    for row in layout['anchors']:
        anchors[row['id']].append(row)
    for row in attachments:
        supports = anchors.get(row['support'], [])
        if row.get('existing') or len(supports) != 1:
            continue
        parent = supports[0]
        yaw = parent.get('yaw', 0)
        dx, dy, dz = row['position']
        px, py, pz = parent['position']
        anchors[row['id']].append({'id': row['id'], 'level': parent['level'],
            'space': parent.get('space'), 'kind': 'fixture',
            'position': [px+math.cos(yaw)*dx+math.sin(yaw)*dz, py+dy,
                         pz-math.sin(yaw)*dx+math.cos(yaw)*dz],
            'yaw': yaw+row.get('yaw', 0), 'attachment_source': row['source'],
            'support': row['support']})
    live = {row['id']: row for row in (observation or {}).get('nodes', [])}
    records = []
    for node in graph['nodes']:
        identity = node['id']
        matches = anchors.get(identity, [])
        seen = live.get(identity, {})
        owners = seen.get('named_owners', [])
        regional = (regions or {}).get(identity, [])
        record = {'id': identity, 'network': node['network'],
                  'legacy_room': node.get('room'), 'legacy_position_blender': node['pos'],
                  'anchor_candidates': matches, 'observed_owners': owners,
                  'observed_bound_consumers': seen.get('bound_consumers', []),
                  'status': 'UNRESOLVED', 'notes': []}
        if len(matches) > 1 or len(owners) > 1 or len(regional) > 1 or (matches and regional):
            record['status'] = 'AMBIGUOUS'
        elif len(matches) == 1:
            anchor = matches[0]
            x, y, z = anchor['position']
            position = [x, levels[anchor['level']] + y, z]
            record.update(status='EXPLICIT_ANCHOR', position_local_godot=position,
                          v2_space=anchor.get('space'), anchor_kind=anchor['kind'])
            if 'attachment_source' in anchor:
                record['status'] = 'EXPLICIT_ATTACHMENT'
                record['fit_source'] = anchor['attachment_source']
            if 'projection_source' in anchor:
                record['status'] = 'EXPLICIT_FITTED_OWNER'
                record['fit_source'] = anchor['projection_source']
            if fitted_boiler and identity == 'B1_BOILER_01':
                position = [x, levels[anchor['level']], z]
                record['fit_source'] = 'game/scripts/building/orison_v2_runtime_root.gd: boiler grounded to basement level'
                record['status'] = 'EXPLICIT_FITTED_OWNER'
            if terminal_fit and identity == terminal_fit['id']:
                supports = anchors.get(terminal_fit['support'], [])
                if len(supports) != 1:
                    record['status'] = 'AMBIGUOUS'
                    record['notes'].append('Terminal fit requires one explicit support anchor.')
                else:
                    yaw = supports[0].get('yaw', 0)
                    dx, dy, dz = terminal_fit['offset']
                    position = [position[0]+math.cos(yaw)*dx+math.sin(yaw)*dz,
                                position[1]+dy, position[2]-math.sin(yaw)*dx+math.cos(yaw)*dz]
                    record['fit_source'] = 'game/data/orison_v2/task_lamp_installations.json: terminal_fit'
                    record['status'] = 'EXPLICIT_FITTED_OWNER'
            record['fitted_position_local_godot'] = position
            if anchor['kind'] != 'fixture':
                record['notes'].append('Interaction/clearance position is not a physical carrier.')
            frame = (observation or {}).get('interior_frame')
            if frame:
                position = [frame['origin'][i] + sum(frame['basis_columns'][j][i]*position[j] for j in range(3)) for i in range(3)]
                record['position_world_godot'] = position
                record['position_world_blender'] = [position[0], -position[2], position[1]]
            if owners and not frame:
                record['notes'].append('World registration frame absent; local coordinates cannot be compared with observed world positions.')
            if owners and frame:
                delta = sum((a-b)**2 for a, b in zip(position, owners[0]['position_godot']))**.5
                record['observed_position_delta_m'] = delta
                if delta > .001:
                    record['status'] = 'SOURCE_RUNTIME_DISAGREEMENT'
        elif len(regional) == 1:
            candidate = regional[0]
            position = candidate['position_world_godot']
            record.update(status='EXPLICIT_REGION_MARKER', region=candidate['region'],
                          marker_source=candidate['marker'], position_world_godot=position,
                          position_world_blender=[position[0], -position[2], position[1]])
            if owners:
                delta = sum((a-b)**2 for a,b in zip(position, owners[0]['position_godot']))**.5
                record['observed_position_delta_m'] = delta
                if delta > .001: record['status'] = 'SOURCE_RUNTIME_DISAGREEMENT'
        elif len(owners) == 1:
            record['status'] = 'OBSERVED_ONLY'
            record['notes'].append('Locate the procedural/source owner before generating a graph position.')
        if not record['observed_bound_consumers'] and observation is not None:
            record['notes'].append('No FunctionalProp binding observed; this alone does not imply a missing carrier.')
        records.append(record)
    identities = {row['id'] for row in records}
    missing_targets = [[row['id'], target] for row in graph['nodes']
                       for target in row.get('connections', []) if target not in identities]
    # These are actual authored V2 route declarations, not inferred acoustic edges.
    routes = []
    for row in layout.get('service_connections', []):
        routes.append(dict(row))
    return {'schema': 'orison.v2-acoustic-ownership.v1', 'evidence_class': 'INERT',
            'scope': 'Exact identity/source ownership candidates only. No alias guessing, graph publication, runtime proof or listening acceptance.',
            'counts': dict(Counter(row['status'] for row in records)),
            'nodes': records, 'legacy_missing_targets': missing_targets,
            'v2_service_connections': routes,
            'duplicate_legacy_ids': sorted(k for k, n in Counter(row['id'] for row in graph['nodes']).items() if n > 1)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--observation', type=Path,
                        help='Optional INERT runtime owner inventory; requires its receipt and observer source.')
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--observer-script', type=Path)
    args = parser.parse_args()
    sources = {'layout': ROOT/'game/data/orison_v2_blockout.json',
               'graph': ROOT/'game/data/acoustic_graph.json',
               'terminal': ROOT/'game/data/orison_v2/task_lamp_installations.json',
               'accessories': ROOT/'game/data/orison_v2/household_accessories.json',
               'retained': ROOT/'game/data/building_layout.json',
               'registry': ROOT/'game/data/floor_01_cell_registry.json',
               'street': ROOT/'game/data/orison_v2/exterior/street_frame.json',
               'nook': ROOT/'game/data/orison_v2/reading_nook.json'}
    if args.observation:
        sources['observation'] = args.observation.resolve()
    data = {key: json.loads(path.read_text(encoding='utf-8')) for key, path in sources.items()}
    if args.observation:
        if not args.receipt or not args.observer_script:
            parser.error('--observation requires --receipt and --observer-script')
        from audit_orison_v2_completeness import runtime_inputs_sha256
        receipt = json.loads(args.receipt.read_text(encoding='utf-8'))
        errors = observation_errors(data['observation'], receipt, args.observer_script.read_bytes(),
                                    sources['graph'].read_bytes(), runtime_inputs_sha256(ROOT))
        for key in ('stdout', 'stderr'):
            log = receipt.get('log', {})
            path = Path(log.get(key, ''))
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != log.get(key+'_sha256'):
                errors.append('observer '+key+' log missing or changed')
        if errors:
            parser.error('; '.join(errors))
        sources.update(receipt=args.receipt.resolve(), observer=args.observer_script.resolve())
    attachments = [dict(row, source=str(sources[key])) for key, collection in
                   [('terminal', 'lamps'), ('accessories', 'accessories')]
                   for row in data[key][collection]]
    report = ownership(fitted_layout(data['layout'], data['retained'], data['nook']), data['graph'], data.get('observation'),
                       data['terminal']['terminal_fit'], fitted_boiler=True, attachments=attachments,
                       regions=region_markers(data['retained'], data['registry'], data['street']))
    sources['boiler_fit_owner'] = ROOT/'game/scripts/building/orison_v2_runtime_root.gd'
    sources['terminal_fit_owner'] = ROOT/'game/scripts/building/orison_v2_task_lamp_installations.gd'
    sources['passage_owner'] = ROOT/'game/scripts/building/orison_v2_passage_region.gd'
    sources['bar_owner'] = ROOT/'game/scripts/building/orison_v2_bar_region.gd'
    sources['nook_owner'] = ROOT/'game/scripts/building/orison_v2_reading_nook.gd'
    sources['facade_owner'] = ROOT/'game/scripts/building/orison_v2_front_facade.gd'
    report['inputs'] = {key: {'path': str(path),
        'sha256_lf': hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()}
        for key, path in sources.items()}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'counts': report['counts'], 'legacy_missing_targets': len(report['legacy_missing_targets']),
                      'v2_service_connections': len(report['v2_service_connections']),
                      'scope': report['scope']}))
    return 1 if report['duplicate_legacy_ids'] or report['legacy_missing_targets'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
