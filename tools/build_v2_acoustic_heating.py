"""Derive V2 steam transmission from installed native supply routes.

No physical stock, heating simulation, tuning or V1 graph is rewritten.
Junctions add no artificial delay/damping; legacy emitter tuning stays intact.
"""
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
from heating_pipe_fittings import fitted_stations

ROOT = Path(__file__).resolve().parents[1]
AUTHORED = [
    'art/blender/heating_distribution/heating_routes_exact.json',
    'art/blender/heating_distribution/lobby_takeoff.json',
    'art/data/orison_v2/heating_refit_authoring.json',
]
BINDINGS = [
    'game/data/acoustic_graph.json', 'game/data/orison_v2_blockout.json',
    'game/data/orison_v2/heating.json',
    'game/scripts/building/orison_v2_heating.gd',
    'game/scripts/building/orison_v2_heating_distribution.gd',
    'game/scripts/building/orison_v2_boiler_pipework.gd',
    'game/assets/props/heating_distribution.glb',
    'game/assets/props/boiler_pipework.glb',
]


def build(layout, heating, legacy, routes, takeoff, retrofit):
    old = {n['id']: n for n in legacy['nodes'] if n['network'] == 'heating'}
    anchors = {a['id']: a for a in layout['anchors']}
    levels = {l['id']: l['y'] for l in layout['levels']}
    installed = {n['id']: n for n in heating['installed']}
    branches = copy.deepcopy(routes['branches'] + [takeoff['child']] + retrofit['routes']['branches'])
    by_id = {n['id']: n for n in branches}
    if len(by_id) != len(branches) or set(by_id) != set(installed):
        raise ValueError('Native routes must cover every installed radiator exactly once')
    if set(old) != set(installed) | {'BASEMENT_HEADER_WEST', 'BASEMENT_HEADER_EAST', 'B1_BOILER_01'}:
        raise ValueError('Unaccounted legacy heating identity')
    nodes, edges = {}, []

    def node(identity, point, room, role, riser=None):
        if identity in nodes or len(point) != 3 or not all(map(math.isfinite, point)):
            raise ValueError('Duplicate or invalid physical node: ' + identity)
        row = copy.deepcopy(old.get(identity, old['BASEMENT_HEADER_WEST']))
        row.update(id=identity, pos=[point[0], -point[2], point[1]], room=room,
                   connections=[], physical_role=role)
        if identity not in old:
            row.update(delay_ms=0, damping=0, infection_receptivity=0, transit_only=True)
        else:
            # External bridges retain their authored direction and identity.
            row['connections'] = [n for n in old[identity]['connections'] if n not in old]
        if riser: row['riser'] = riser
        nodes[identity] = row

    def edge(a, b, points, owner, terminal=None):
        if a == b or b in nodes[a]['connections']:
            raise ValueError('Duplicate physical connection')
        if len(points) < 2 or any(not all(map(math.isfinite, p)) for p in points):
            raise ValueError('Invalid physical route')
        nodes[a]['connections'].append(b); nodes[b]['connections'].append(a)
        row = dict(start=a, end=b, points_local_godot=points, owner=owner)
        if terminal: row['terminal_carrier'] = terminal
        edges.append(row)

    def anchor_point(identity):
        a = anchors[identity]
        p = a['position'].copy(); p[1] += levels[a['level']]
        if a.get('space') not in {s['id'] for s in layout['spaces']}:
            raise ValueError('Carrier has no explicit V2 room: ' + identity)
        return p, a['space']

    receiver = next(r['bounds'] for r in layout['riser_openings'] if r['id'] == 'HEAT_STEAM_RECEIVER_CLEAR')
    center = [(receiver[i] + receiver[i+3])*.5 for i in range(3)]
    direct = [b for b in branches if not b.get('parent_branch')]
    roots = {}
    for branch in direct:
        if branch['riser'] != installed[branch['id']]['riser']:
            raise ValueError('Branch disagrees with heating authority')
        x, _, z = branch['points_local_godot'][0]
        if branch['riser'] in roots and math.dist([x,z],roots[branch['riser']]) > 1e-6:
            raise ValueError('Main axis changes without an authored fitting')
        roots[branch['riser']] = [x,z]
    if set(roots) != {'H-A','H-B','H-C','H-D'}:
        raise ValueError('Incomplete four-main supply')
    west = [min(p[0] for p in roots.values()), center[1], center[2]]
    east = [max(p[0] for p in roots.values()), center[1], center[2]]
    node('BASEMENT_HEADER_WEST',west,'B1_BOILER_ROOM','receiver_west')
    node('BASEMENT_HEADER_EAST',east,'B1_BOILER_ROOM','receiver_east')
    edge('BASEMENT_HEADER_WEST','BASEMENT_HEADER_EAST',[west,east],'HeatingDistribution/Heating_SHAFT')
    for identity in installed:
        p, room = anchor_point(identity)
        node(identity,p,room,'radiator',installed[identity]['riser'])
        # Native floor stub is fixed at -0.67 on the radiator's local X.
        a=anchors[identity]; yaw=float(a.get('yaw',0)); end=by_id[identity]['points_local_godot'][-1]
        expected=[p[0]-.67*math.cos(yaw),levels[a['level']],p[2]+.67*math.sin(yaw)]
        if math.dist(end,expected)>.0001:
            raise ValueError('Native branch misses actual radiator stub: '+identity)
    taps={}
    for b in direct:
        identity='V2_HEAT_TAP_'+b['id'];p=b['points_local_godot'][0]
        node(identity,p,b['level'],'branch_junction',b['riser'])
        taps[b['id']]=identity
    for riser, (x,z) in sorted(roots.items()):
        identity='V2_HEAT_BASE_'+riser.replace('-','_');p=[x,receiver[4],z]
        if not (receiver[0]<x<receiver[3] and receiver[2]<z<receiver[5]):
            raise ValueError('Main misses cast receiver')
        node(identity,p,'B1_BOILER_ROOM','main_base',riser)
        header='BASEMENT_HEADER_WEST' if x==west[0] else 'BASEMENT_HEADER_EAST'
        hp=west if x==west[0] else east
        edge(header,identity,[hp,[x,center[1],z],p],'HeatingDistribution/Heating_SHAFT')
        previous=identity;point=p
        for b in sorted((b for b in direct if b['riser']==riser),key=lambda b:b['points_local_godot'][0][1]):
            current=taps[b['id']];q=b['points_local_godot'][0]
            edge(previous,current,[point,q],'HeatingDistribution/Heating_SHAFT')
            previous=current;point=q
    parent=takeoff['parent_branch'];join=takeoff['join_local_godot'];split=int(takeoff['parent_segment'])
    lobby=takeoff['child']['id'];junction='V2_HEAT_TAP_'+lobby
    node(junction,join,takeoff['anchor_candidate']['level'],'branch_takeoff',installed[lobby]['riser'])
    for b in direct:
        identity=b['id'];points=b['points_local_godot'];owner='HeatingDistribution/Heating_'+b['level']
        if identity==parent:
            a,c=points[split],points[split+1]
            if abs(math.dist(a,join)+math.dist(join,c)-math.dist(a,c))>1e-6:
                raise ValueError('Lobby takeoff no longer lies on its parent supply')
            edge(taps[identity],junction,[p for p,_ in fitted_stations(points[:split+1]+[join])],owner)
            edge(junction,identity,[p for p,_ in fitted_stations([join]+points[split+1:])],owner,identity)
        else:
            edge(taps[identity],identity,[p for p,_ in fitted_stations(points)],owner,identity)
    child=[join]+takeoff['child']['points_local_godot']
    edge(junction,lobby,[p for p,_ in fitted_stations(child)],'HeatingDistribution/Heating_F01',lobby)
    plant, room=anchor_point('B1_BOILER_01')
    # The production boiler is grounded after mounting its inspection-height anchor.
    plant[1]=levels[anchors['B1_BOILER_01']['level']]
    node('B1_BOILER_01',plant,room,'boiler')
    # The supply attaches to the original boiler's top takeoff, not its semantic centre.
    stance=anchors['B1_BOILER_CONTROL_STANCE']['position'];a=anchors['B1_BOILER_01']
    angle=math.atan2(-(stance[0]-a['position'][0]),-(stance[2]-a['position'][2]))
    base=levels[a['level']]
    start=[plant[0]+math.cos(angle)*.05+math.sin(angle)*.02,base+2.02,
           plant[2]-math.sin(angle)*.05+math.cos(angle)*.02]
    high=[start[0],base+2.65,start[2]];feed=[center[0],base+2.65,receiver[2]]
    if abs(feed[1]-center[1])>1e-6:raise ValueError('Receiver and boiler takeoff differ in height')
    feed_path=[p for p,_ in fitted_stations([start,high,[feed[0],high[1],high[2]],feed],radius=.14)]
    # Last leg is inside the common receiver cavity and preserves the original east header identity.
    edge('B1_BOILER_01','BASEMENT_HEADER_EAST',feed_path+[center,east],'BoilerPipework', 'B1_BOILER_01')
    return dict(nodes=list(nodes.values()),routes=edges,retirements=[],
                external_bridges=[dict(start=n['id'],end=t) for n in old.values() for t in n['connections'] if t not in old])


def projection(root=ROOT):
    root=Path(root);read=lambda p:json.loads((root/p).read_text(encoding='utf-8'))
    result=build(read(BINDINGS[1]),read(BINDINGS[2]),read(BINDINGS[0]),*[read(p) for p in AUTHORED])
    bindings=[]
    for name in BINDINGS:
        raw=(root/name).read_bytes();text=not name.endswith('.glb')
        if text:raw=raw.replace(b'\r\n',b'\n')
        bindings.append(dict(path='res://'+name.removeprefix('game/'),sha256=hashlib.sha256(raw).hexdigest(),normalize_lines=text))
    result.update(schema_version=1,network='heating',coordinate_frame='blockout_local_blender',source_bindings=bindings)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();result=projection();args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
    print(f"{len(result['nodes'])} heating nodes, {len(result['routes'])} physical connections")
