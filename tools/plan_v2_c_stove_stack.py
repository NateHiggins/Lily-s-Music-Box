"""Source design for the sealed C-room stove stack; no installation acceptance."""
import argparse,copy,hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LAYOUT=ROOT/'game/data/orison_v2_blockout.json'

def plan(layout):
    rooms={r['id']:r for r in layout['spaces']};levels={r['id']:r['y'] for r in layout['levels']}
    thickness=float(layout['dimensions']['partition_wall']);x=7.1;z=10.05
    # The sleeve begins at the room-side plaster face, not the semantic centre.
    face=x-thickness/2-.002;back=x+thickness/2
    outer=float(layout['dimensions']['outer_wall'])
    rect=[x+outer,z-.35,x+outer+.58,z+.35];wall=.10
    roof=rooms['ROOF_DECK_NORTH'];r=roof['rect']
    if not(r[0]<=rect[0]<rect[2]<=r[2] and r[1]<=rect[1]<rect[3]<=r[3]):raise ValueError('Stack has no explicit roof owner')
    ports=[];wall_openings=[];riser_openings=[];masonry_openings=[]
    shaft={'id':'C_STOVE_FLUE','rect':rect,'from_y':-3.2,'to_y':19.2,'class':'service'}
    riser_openings.append({'id':'C_STOVE_FLUE_AIRWAY','riser':shaft['id'],'bounds':[rect[0]+wall,-3.1,rect[1]+wall,rect[2]-wall,19.2,rect[3]-wall]})
    for floor in range(2,7):
        level=f'F{floor:02d}';space=f'{level}_C_BED2' if floor!=3 else 'F03_C_RESTRICTED'
        room=rooms[space];bounds=room['rect']
        if abs(bounds[2]-x)>1e-8 or not(bounds[1]+.224<z<bounds[3]-.224) or 'east' not in room.get('wall_sides',['south','north','west','east']):raise ValueError('Missing clear owning east wall: '+space)
        for window in layout['windows']:
            if window['space']==space and window['axis']=='z' and abs(window['center'][0]-x)<.001 and abs(window['center'][1]-z)<window['width']/2+.224:raise ValueError('Stack blocks a window')
        y=float(levels[level])+1.44;identity=f'{level}_FLUE_BREAST'
        ports.append({'id':identity,'level':level,'space':space,'unit':f'{floor}C','position':[face,0,z],'center_y':y,'yaw':math.pi/2,'plaster_patch_bounds':[x-thickness/2,y-.15,z-.15,back,y+.15,z+.15]})
        wall_openings.append({'id':identity+'_WALL_PORT','space':space,'side':'east','bounds':[x-thickness/2,y-.15,z-.15,back,y+.15,z+.15]})
        riser_openings.append({'id':identity+'_STACK_PORT','riser':shaft['id'],'bounds':[rect[0],y-.14,z-.14,rect[0]+wall+.001,y+.14,z+.14]})
        masonry_openings.append({'id':identity+'_OUTER_LEAF_PORT','owner':'ExteriorMasonry','bounds':[back,y-.15,z-.15,rect[0],y+.15,z+.15]})
    return {'schema_version':1,'evidence_class':'INERT','scope':'Authored physical candidate. Native, actual-room contact, masonry connection and source renewal required before acceptance.',
        'riser':shaft,'native_top_y':21.36,'native_footing_bottom_y':-3.6,'wall_m':wall,'ports':ports,
        'wall_service_openings':wall_openings,'riser_openings':riser_openings,'masonry_service_openings':masonry_openings,
        'slab_openings':[{'id':'C_STOVE_FLUE_ROOF_PORT','space':roof['id'],'surface':'Floor','rect':[rect[0]+wall,rect[1]+wall,rect[2]-wall,rect[3]-wall]},
            {'id':'C_STOVE_FLUE_APRON_PORT','space':'F01_REAR_APRON','surface':'Floor','rect':[7.8,rect[1]+wall,rect[2]-wall,rect[3]-wall]}],
        'furniture_moves':[{'id':'2C_blanket_b','z':10.95},{'id':'5C_pigment_table','z':10.95},{'id':'5C_pigment_table_STANCE','z':10.95},{'id':'6C_archive_shelf_02','z':11.0},{'id':'6C_archive_shelf_02_STANCE','z':11.0}],
        'masonry_coupling':{'kind':'roof slab vibration; independent sealed stove and live boiler airways','points_local_godot':[[rect[0]+.05,19.11,z],[rect[0]+.05,19.11,10.75],[15.10,19.11,10.75],[15.10,19.11,2.15]],'owners':['ROOF_DECK_NORTH/Floor','ROOF_DECK_NORTHEAST/Floor','ROOF_DECK_EAST/Floor'],'probe_spacing_m':.10}}

def project(layout,proposal):
    result=copy.deepcopy(layout)
    additions={k:proposal[k] for k in ['wall_service_openings','riser_openings','slab_openings','masonry_service_openings']}
    additions['risers']=[proposal['riser']]
    additions['anchors']=[{'id':p['id'],'level':p['level'],'space':p['space'],'position':p['position'],'yaw':p['yaw'],'kind':'prop'} for p in proposal['ports']]
    for table,rows in additions.items():
        existing={r['id']:r for r in result[table]}
        for row in rows:
            if row['id'] in existing:
                if existing[row['id']]!=row:raise ValueError('Conflicting existing owner: '+row['id'])
            else:result[table].append(copy.deepcopy(row))
    for move in proposal['furniture_moves']:
        records=[r for r in result['anchors'] if r['id']==move['id']]
        if len(records)!=1:raise ValueError('Missing furniture move owner: '+move['id'])
        records[0]['position'][2]=move['z']
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--layout-out',type=Path)
    args=parser.parse_args();layout=json.loads(LAYOUT.read_bytes());proposal=plan(layout)
    proposal['source_bindings']={'game/data/orison_v2_blockout.json':hashlib.sha256(LAYOUT.read_bytes().replace(b'\r\n',b'\n')).hexdigest()}
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(proposal,indent=2)+'\n',newline='\n')
    if args.layout_out:args.layout_out.write_text(json.dumps(project(layout,proposal),indent=2)+'\n',newline='\n')
    print('C stove stack: 5 room wall/outer-leaf ports, 6 shaft cuts, roof/apron penetrations; 3 furnishings relocated. Production unchanged.')
