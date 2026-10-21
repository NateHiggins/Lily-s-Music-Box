"""Derive the real boiler-chimney aperture set without rewriting other owners.

The plan is not installation proof. Roof falls and membrane must also be cut
in Blender before the complete airway can be accepted in the composed world.
"""
import argparse
import copy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


def plan(layout):
    shafts=[r for r in layout['risers'] if r['id']=='B1_BOILER_FLUE']
    if len(shafts)!=1:raise ValueError('Exactly one authored boiler chimney is required')
    shaft=shafts[0];x0,z0,x1,z1=shaft['rect'];wall=.10
    if x1-x0<=2*wall or z1-z0<=2*wall:raise ValueError('Chimney walls leave no airway')
    anchor=next(a for a in layout['anchors'] if a['id']=='B1_BOILER_01')
    floor=next(l['y'] for l in layout['levels'] if l['id']==anchor['level'])
    high=floor+2.65;center_z=(z0+z1)*.5;radius=.17;clearance=.01
    if z1-z0-2*wall<2*(radius+clearance):raise ValueError('Breeching cannot fit between chimney cheeks')
    roof=next(s for s in layout['spaces'] if s['id']=='ROOF_DECK_EAST')
    r=roof['rect']
    if not (r[0]<=x0<x1<=r[2] and r[1]<=z0<z1<=r[3]):raise ValueError('Chimney moved outside its explicit roof slab owner')
    return dict(schema_version=1,evidence_class='INERT',scope='Source aperture design only; native roof layers and composed airway remain to be verified.',
        riser_openings=[
            dict(id='BOILER_FLUE_CONTINUOUS_AIRWAY',riser=shaft['id'],bounds=[x0+wall,float(shaft['from_y'])+wall,z0+wall,x1-wall,float(shaft['to_y']),z1-wall]),
            dict(id='BOILER_FLUE_BREECHING_PORT',riser=shaft['id'],bounds=[x0,high-radius-clearance,center_z-radius-clearance,x0+wall+.001,high+radius+clearance,center_z+radius+clearance])],
        slab_openings=[dict(id='BOILER_FLUE_ROOF_PENETRATION',space=roof['id'],surface='Floor',rect=[x0+wall,z0+wall,x1-wall,z1-wall])],
        wall_thimble=dict(position=[x0-.002,high,center_z],yaw=1.5707963267948966,bore_radius_m=.1715,sleeve_length_m=.095,plate_width_m=.48),
        native_roof_cut=dict(owner=roof['id'],rect=[x0+wall,z0+wall,x1-wall,z1-wall]))


def project(layout,proposal):
    result=copy.deepcopy(layout)
    for table in ['riser_openings','slab_openings']:
        ids={r['id'] for r in proposal[table]}
        existing=[r for r in layout.get(table,[]) if r['id'] in ids]
        if existing and existing!=proposal[table]:raise ValueError('Existing flue aperture differs; review instead of replacing it')
        result[table]=[r for r in result.get(table,[]) if r['id'] not in ids]+copy.deepcopy(proposal[table])
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();proposal=plan(json.loads((ROOT/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8')))
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(proposal,indent=2)+'\n',encoding='utf-8')
    print('Planned continuous airway, breeching wall port and roof penetration; production source unchanged.')
