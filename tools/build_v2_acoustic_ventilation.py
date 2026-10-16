"""Build a candidate acoustic ventilation network from authored V2 duct routes.

This does not install a graph or grant runtime/listening acceptance.
"""
import argparse
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def build(layout, ventilation, legacy, frame):
    anchors = {r['id']: r for r in layout['anchors']}
    if len(anchors) != len(layout['anchors']): raise ValueError('Duplicate layout anchor')
    assignments = [r['anchor'] for r in ventilation['registers']]
    if len(assignments) != len(set(assignments)): raise ValueError('Duplicate ventilation assignment')
    levels = {r['id']: r['y'] for r in layout['levels']}
    old = {r['id']: r for r in legacy['nodes'] if r['network'] == 'ventilation'}
    nodes, routes, retired = {}, [], []

    def local(identity):
        a = anchors[identity]
        x,y,z = a['position']
        return [x, y+levels[a['level']], z]

    def node(identity, position, room=None, riser=None):
        if identity in nodes: raise ValueError('Duplicate generated identity: '+identity)
        if identity not in old: raise ValueError('No authored acoustic tuning for '+identity)
        row = copy.deepcopy(old[identity])
        world = [frame['origin'][i]+sum(frame['basis_columns'][j][i]*position[j] for j in range(3)) for i in range(3)]
        row['pos'] = [world[0], -world[2], world[1]]
        row['connections'] = []
        if room is not None: row['room'] = room
        if riser is not None: row['riser'] = riser
        nodes[identity] = row

    def edge(a, b, points, owner):
        if a == b: raise ValueError('Self connection')
        if b not in nodes[a]['connections']: nodes[a]['connections'].append(b)
        if a not in nodes[b]['connections']: nodes[b]['connections'].append(a)
        routes.append({'from': a, 'to': b, 'owner': owner, 'points_local_godot': points})

    for stack in ventilation['stacks']:
        key = stack['id']
        assigned = [r['anchor'] for r in ventilation['registers'] if r['stack'] == key]
        if not assigned: raise ValueError('Stack without registers: '+key)
        fan = 'ROOF_VENT_FAN_'+key
        roof = local(fan)
        top = [stack['riser'][0], roof[1]-ventilation['roof_branch_drop_m'], stack['riser'][1]]
        branch_offsets = {round(anchors[a]['position'][1]+.09, 6) for a in assigned}
        if len(branch_offsets) != 1: raise ValueError('Explicit branch junction heights required: '+key)
        branch_offset = branch_offsets.pop()
        bottom = min(local(a)[1]+.09 for a in assigned)
        junctions = []
        for floor, y in sorted(levels.items(), key=lambda pair: pair[1]):
            identity = floor+'_V_'+key+'_RISER'
            if identity not in old: continue
            point = [top[0], y+branch_offset, top[2]]
            if point[1] < bottom-.00001 or point[1] > top[1]+.00001:
                retired.append({'id': identity, 'reason': 'Outside the installed vertical duct extent',
                                'stack': key, 'duct_bottom_y': bottom, 'duct_top_y': top[1]})
                continue
            node(identity, point, floor, 'V-'+key)
            junctions.append((identity, point))
        for register in assigned:
            a = anchors[register]
            grille = local(register)
            start = [grille[0], grille[1]+.09, grille[2]]
            end = [top[0], start[1], top[2]]
            junction = a['level']+'_V_'+key+'_RISER'
            if junction not in nodes: raise ValueError('Register has no physical stack junction')
            node(register, grille, a.get('space', old[register]['room']), 'V-'+key)
            corner = [end[0],start[1],start[2]] if stack['branch_axis']=='xz' else [start[0],start[1],end[2]]
            edge(register, junction, [grille,start,corner,end], 'VentilationDucts/Stack_'+key)
        for (a, pa), (b, pb) in zip(junctions, junctions[1:]):
            edge(a, b, [pa,pb], 'VentilationDucts/Stack_'+key)
        node(fan, roof, anchors[fan].get('space', old[fan]['room']), 'V-'+key)
        last, point = junctions[-1]
        edge(last, fan, [point,top,[roof[0],top[1],top[2]],
                        [roof[0],top[1],roof[2]],[roof[0],roof[1]+.08,roof[2]],roof],
             'VentilationDucts/Stack_'+key)
    expected = set(old)-{r['id'] for r in retired}
    if set(nodes) != expected: raise ValueError('Unaccounted ventilation identities: '+str(expected ^ set(nodes)))
    external = [[n['id'], dest] for n in old.values() for dest in n['connections'] if dest not in old]
    if external: raise ValueError('Cross-network connections require explicit physical routing: '+str(external))
    for n in nodes.values(): n['connections'].sort()
    return {'evidence_class': 'INERT', 'status': 'CANDIDATE_NOT_INSTALLED',
            'scope': 'Source-derived ventilation positions/routes only; requires installed route, propagation and listening verification.',
            'nodes': sorted(nodes.values(), key=lambda n:n['id']), 'routes': routes, 'retirements': retired}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ownership-report', required=True, type=Path)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    ownership = json.loads(args.ownership_report.read_text())
    # Input report must have been produced by the provenance-checking ownership CLI.
    import hashlib
    for record in ownership['inputs'].values():
        raw = Path(record['path']).read_bytes().replace(b'\r\n',b'\n')
        if hashlib.sha256(raw).hexdigest() != record['sha256_lf']:
            raise SystemExit('Stale ownership input: '+record['path'])
    observed = json.loads(Path(ownership['inputs']['observation']['path']).read_text())
    receipt = json.loads(Path(ownership['inputs']['receipt']['path']).read_text())
    from audit_orison_v2_completeness import runtime_inputs_sha256
    if receipt['source']['runtime_inputs_sha256'] != runtime_inputs_sha256(ROOT):
        raise SystemExit('Production sources changed since the ownership observation')
    read = lambda p: json.loads((ROOT/p).read_text())
    candidate = build(read('game/data/orison_v2_blockout.json'),
        read('game/data/orison_v2/completion_interiors.json')['ventilation'],
        read('game/data/acoustic_graph.json'), observed['interior_frame'])
    source_paths = ['game/data/orison_v2_blockout.json', 'game/data/orison_v2/completion_interiors.json',
                    'game/data/acoustic_graph.json', 'game/scripts/building/orison_v2_ventilation.gd']
    candidate['source_sha256_lf'] = {p: hashlib.sha256((ROOT/p).read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in source_paths}
    candidate['ownership_report_sha256'] = hashlib.sha256(args.ownership_report.read_bytes()).hexdigest()
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(candidate,indent=2)+'\n')
    print(json.dumps({'candidate_nodes':len(candidate['nodes']), 'routes':len(candidate['routes']),
                      'retirements':candidate['retirements'],'installed':False}))


if __name__ == '__main__': main()
