"""Derive arcade actor door frames from pinned authoring/fabrication sources.

Diagnostic data only: no runtime installation or moving-leaf clearance claim.
python -B tools/prepare_arcade_door_frames.py [--check]
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
PLAN=Path('art/data/arcade_plaza/source_plan.json')
FABRICATION=Path('game/data/building_layout.json')
FIXTURE=Path('game/tests/fixtures/arcade_door_frames.json')
PLAN_SHA256_LF='59cdf999e4b78e766eeb322504e75bbd4db9d5f61a50ce529573dfc929689786'
FABRICATION_SHA256_LF='e700ffdebc6e28932722d9d6fc4c5afb9237498d10ef244fee7f0afd301ca998'
CELLS=frozenset('shop_'+s for s in ('funeral_parlour','shoe_rebuilding','keys_cut','news_cigars','photo_supplies','otis_son','radio_service','pawnbroker','model_laundry','hardware_paint','luncheonette'))
BASES={90:[[0,0,1],[0,1,0],[-1,0,0]],-90:[[0,0,-1],[0,1,0],[1,0,0]],180:[[-1,0,0],[0,1,0],[0,0,-1]]}
ROOT_ORIGIN=[1.18,0,38.6]


def require(condition,message):
    if not condition: raise ValueError(message)


def sha(data):
    return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()


def marker_id(cell):
    # Original authored Otis spelling is not the normalized cell spelling.
    suffix='OTIS___SON' if cell=='shop_otis_son' else cell.removeprefix('shop_').upper()
    return 'SITE_SHOP_DOOR_'+suffix


def point(value,length):
    require(isinstance(value,list) and len(value)==length and all(type(v) in (int,float) and math.isfinite(v) for v in value),'invalid finite datum')
    return value


def frame(centre,yaw,width):
    basis=BASES[yaw]
    world_centre=[ROOT_ORIGIN[0]+centre[0],ROOT_ORIGIN[1],ROOT_ORIGIN[2]+centre[1]]
    start=[world_centre[k]-basis[k][0]*width*.5 for k in range(3)]
    return [basis[k]+[start[k]] for k in range(3)]+[[0,0,0,1]]


def derive(plan,fabrication):
    require(plan['source_origin_blender_m']==[1.18,-38.6,0.0],'source origin changed')
    require(plan['front_frame_clear_m']==2.0 and plan['stock_frame_clear_m']==1.0 and plan['door_height_m']==2.3,'door clear dimensions changed')
    require(plan['reference_sources_sha256_lf'].get(FABRICATION.as_posix())==FABRICATION_SHA256_LF,'immutable fabrication reference changed')
    shops=plan['shops']
    require(len(shops)==11 and {s['id'] for s in shops}==CELLS,'eleven exact unique cells required')
    floors=[f for f in fabrication['floors'] if f['id']=='F01']
    require(len(floors)==1,'unique F01 source required')
    source_markers={}
    wanted={marker_id(c) for c in CELLS}
    for marker in floors[0]['markers']:
        if marker['id'] in wanted:
            require(marker['id'] not in source_markers,'duplicate original door marker')
            require(marker['kind']=='door' and marker.get('zone')=='PASSAGE','original door marker role changed')
            source_markers[marker['id']]=marker
    require(set(source_markers)==wanted,'missing original door marker IDs')
    frames=[]
    for shop in shops:
        cell=shop['id']; front=shop['front']; centre=point(shop['entrance_center_m'],2)
        rect=point(shop['rect_m'],4); partition=point(shop['partition_rect_m'],4)
        stock=point(shop['stock_rect_m'],4)
        require(rect[2]>rect[0] and rect[3]>rect[1] and partition[2]>partition[0] and partition[3]>partition[1],'invalid door owning rectangle')
        require(front in ('east','west','north'),'unsupported front orientation')
        if front=='east':
            require(centre[0]==rect[2] and stock[2]<=partition[0],'west stock/front datum mismatch')
            yaw=90
        elif front=='west':
            require(centre[0]==rect[0] and stock[0]>=partition[2],'east stock/front datum mismatch')
            yaw=-90
        else:
            require(centre[1]==rect[1]==22.3 and stock[1]>=partition[3],'rear stock/front datum mismatch')
            yaw=180
        along=centre[1] if front!='north' else centre[0]
        lower,upper=(rect[1],rect[3]) if front!='north' else (rect[0],rect[2])
        require(lower<=along-1 and along+1<=upper,'front aperture exceeds wall')
        identity=marker_id(cell)
        original=copy.deepcopy(source_markers[identity])
        frames.append(dict(id=identity,cell=cell,frame_kind='front_pair',paired=True,width=2.0,height=2.3,
            opening_center_m=centre,frame_transform=frame(centre,yaw,2.0),yaw_deg=yaw,opening_angle_deg=90,
            source_marker_id=identity,source_marker=original))
        midpoint=[(partition[0]+partition[2])*.5,(partition[1]+partition[3])*.5]
        stock_centre=point(shop.get('stock_opening_center_m',midpoint),2)
        # Explicit offset moves along the partition only, not off its central plane.
        cross=0 if front!='north' else 1
        require(abs(stock_centre[cross]-midpoint[cross])<=1e-12,'stock opening off partition centre plane')
        along_index=1-cross
        low=partition[along_index]; high=partition[along_index+2]
        require(low<=stock_centre[along_index]-.5 and stock_centre[along_index]+.5<=high,'stock aperture exceeds partition')
        suffix=cell.removeprefix('shop_').upper()
        frames.append(dict(id='ARCADE_STOCK_DOOR_'+suffix,cell=cell,frame_kind='stock_single',paired=False,width=1.0,height=2.3,
            opening_center_m=stock_centre,opening_center_authority='stock_opening_center_m' if 'stock_opening_center_m' in shop else 'partition_rect_m_midpoint',
            frame_transform=frame(stock_centre,yaw,1.0),yaw_deg=yaw,opening_angle_deg=90))
    require(len({r['id'] for r in frames})==22,'duplicate target door identity')
    return frames


def build(root=ROOT):
    plan_bytes=(root/PLAN).read_bytes(); fabrication_bytes=(root/FABRICATION).read_bytes()
    require(sha(plan_bytes)==PLAN_SHA256_LF,'source plan drift; requires explicit receiving review')
    require(sha(fabrication_bytes)==FABRICATION_SHA256_LF,'immutable fabrication drift')
    frames=derive(json.loads(plan_bytes),json.loads(fabrication_bytes))
    return dict(schema_version=1,classification='DIAGNOSTIC_DOOR_FRAME_CONTRACT_NOT_RUNTIME_INSTALLATION',
        source_bindings={PLAN.as_posix():dict(kind='lf',sha256=PLAN_SHA256_LF),FABRICATION.as_posix():dict(kind='lf',sha256=FABRICATION_SHA256_LF)},
        coordinate_frame='Godot source building frame; plan U maps +X and V maps +Z',root_origin_godot=ROOT_ORIGIN,
        external_vantry_root_z=-9.795,external_vantry_applied=False,
        counts=dict(front_pairs=11,stock_singles=11,frames=22),frames=frames)


def render(document):
    return json.dumps(document,indent=1,allow_nan=False)+'\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--check',action='store_true')
    args=parser.parse_args();text=render(build(args.root));output=args.root/FIXTURE
    if args.check:
        require(output.is_file() and output.read_text(encoding='utf-8').replace('\r\n','\n')==text,'door frames stale; rerun producer')
        print('ARCADE DOOR FRAMES OK: 11 front pairs + 11 stock singles')
    else:
        output.write_text(text,encoding='utf-8',newline='\n');print('WROTE '+str(FIXTURE))
    return 0

if __name__=='__main__': raise SystemExit(main())
