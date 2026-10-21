"""Derive physical boiler/stove flue transmission, including roof-slab vibration."""
import argparse,copy,hashlib,json
from pathlib import Path
from plan_v2_c_stove_stack import plan
ROOT=Path(__file__).resolve().parents[1]
BINDINGS=['game/data/acoustic_graph.json','game/data/orison_v2_blockout.json',
 'game/scripts/building/orison_v2_boiler_flue.gd','game/scripts/building/c_stove_stack_stock.gd',
 'game/scripts/building/orison_v2_c_stove_stack.gd','game/scripts/props/flue_breast_prop.gd',
 'game/assets/props/c_stove_stack.glb','game/assets/props/flue_breast_fitting.glb']

def build(layout,legacy,asset_hash):
    proposal=plan(layout);shaft=next(r for r in layout['risers'] if r['id']=='C_STOVE_FLUE')
    if shaft!=proposal['riser']:raise ValueError('Stove stack differs from reviewed footprint')
    boiler=next(r for r in layout['risers'] if r['id']=='B1_BOILER_FLUE');r=boiler['rect'];bx=(r[0]+r[2])/2;bz=(r[1]+r[3])/2
    cr=shaft['rect'];cx=(cr[0]+cr[2])/2;cz=(cr[1]+cr[3])/2
    anchors={a['id']:a for a in layout['anchors']};levels={r['id']:r['y'] for r in layout['levels']}
    old={n['id']:n for n in legacy['nodes'] if n['network']=='flue'};nodes={};routes=[]
    def put(identity,point,room,role,unit=None):
        row=copy.deepcopy(old[identity]) if identity in old else dict(id=identity,network='flue',frequency_band=[30,1500],delay_ms=0,damping=0,infection_receptivity=0,transit_only=True)
        row.update(pos=[point[0],-point[2],point[1]],room=room,physical_role=role,connections=[])
        if unit is not None:row['unit']=unit
        nodes[identity]=row
    def point(identity):
        p=nodes[identity]['pos'];return [p[0],p[2],-p[1]]
    def edge(a,b,owners,kind,points=None):
        points=points or [point(a),point(b)]
        if points[0]!=point(a) or points[-1]!=point(b):raise ValueError('Physical route misses endpoint')
        for p,q in zip(points,points[1:]):
            if sum(abs(p[i]-q[i])>1e-6 for i in range(3))>1:raise ValueError('Unfabricated diagonal route')
        nodes[a]['connections'].append(b);nodes[b]['connections'].append(a)
        routes.append(dict(start=a,end=b,owners=owners,kind=kind,points_local_godot=points))
    for identity,row in old.items():
        if identity.endswith('_FLUE_BREAST'):continue
        room='B1_BOILER_ROOM' if identity=='B1_FLUE_BASE' else row['room']
        put(identity,[bx,row['pos'][2],bz],room,'boiler_column')
    main=['B1_FLUE_BASE']+[f'F{f:02d}_FLUE' for f in range(1,7)]+['ROOF_FLUE_TOP']
    for a,b in zip(main,main[1:]):edge(a,b,['B1_BOILER_FLUE','BoilerFlue/FittedChimneyCrown'],'boiler_airway')
    previous=None
    for port in proposal['ports']:
        identity=port['id'];anchor=anchors.get(identity)
        if anchor is None or anchor['position']!=port['position'] or anchor['space']!=port['space']:raise ValueError('Missing installed thimble anchor: '+identity)
        y=levels[port['level']]+1.44
        put(identity,[anchor['position'][0]-.083,y,cz],port['space'],'thimble',port['unit'])
        junction='V2_FLUE_C_'+port['level'];put(junction,[cx,y,cz],port['space'],'stove_column')
        edge(identity,junction,['CStoveStack',identity],'sealed_thimble')
        if previous:edge(previous,junction,['CStoveStack'],'stove_airway')
        previous=junction
    roof_points=proposal['masonry_coupling']['points_local_godot']
    put('V2_FLUE_C_ROOF_CORE',[cx,19.11,cz],'ROOF_DECK_NORTH','stove_column')
    edge(previous,'V2_FLUE_C_ROOF_CORE',['CStoveStack'],'stove_airway')
    labels=['V2_FLUE_C_ROOF_WALL','V2_FLUE_NORTH_SLAB','V2_FLUE_EAST_SLAB','V2_FLUE_BOILER_SLAB']
    rooms=['ROOF_DECK_NORTH','ROOF_DECK_NORTH','ROOF_DECK_EAST','ROOF_DECK_EAST']
    for identity,p,room in zip(labels,roof_points,rooms):put(identity,p,room,'masonry_transfer')
    edge('V2_FLUE_C_ROOF_CORE',labels[0],['CStoveStack'],'stove_wall')
    for a,b in zip(labels,labels[1:]):edge(a,b,proposal['masonry_coupling']['owners'],'structural_slab')
    put('V2_FLUE_BOILER_ROOF_WALL',[15.1,21.3,bz],'ROOF_DECK_EAST','masonry_transfer')
    edge(labels[-1],'V2_FLUE_BOILER_ROOF_WALL',['B1_BOILER_FLUE','BoilerFlue/FittedChimneyCrown'],'boiler_wall')
    edge('V2_FLUE_BOILER_ROOF_WALL','ROOF_FLUE_TOP',['BoilerFlue/FittedChimneyCrown'],'boiler_wall')
    external=[dict(start=n['id'],end=target,owner='BoilerFlue') for n in old.values() for target in n['connections'] if target not in old]
    if external!=[dict(start='B1_FLUE_BASE',end='B1_BOILER_01',owner='BoilerFlue')]:raise ValueError('Unreviewed cross-network flue bridge')
    for row in external:nodes[row['start']]['connections'].append(row['end'])
    return dict(stock=dict(riser=shaft['id'],rect=shaft['rect'],from_y=shaft['from_y'],to_y=shaft['to_y'],asset_sha256=asset_hash),nodes=list(nodes.values()),routes=routes,external_bridges=external)

def projection(root=ROOT):
    root=Path(root);read=lambda p:json.loads((root/p).read_bytes())
    result=build(read(BINDINGS[1]),read(BINDINGS[0]),hashlib.sha256((root/BINDINGS[6]).read_bytes()).hexdigest())
    bindings=[]
    for name in BINDINGS:
        raw=(root/name).read_bytes();normalize=not name.endswith('.glb')
        if normalize:raw=raw.replace(b'\r\n',b'\n')
        bindings.append(dict(path='res://'+name.removeprefix('game/'),sha256=hashlib.sha256(raw).hexdigest(),normalize_lines=normalize))
    return dict(schema_version=1,network='flue',coordinate_frame='blockout_local_blender',source_bindings=bindings,**result)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args();data=projection()
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(data,indent=2)+'\n',newline='\n');print(len(data['nodes']),'flue nodes;',len(data['routes']),'physical routes')
