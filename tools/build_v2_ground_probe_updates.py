"""Qualify three fixed historic probes now covered by the north storage roof.

The original 48-station fixture is immutable. This explicit overlay admits only
the current named room, with fresh measured collision and visible-mesh checks.
"""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ROOM='B1_STORAGE_NORTH_BAY'
OWNER='OrisonV2Blockout/CeilingTopClosures/'+ROOM+'_Top_00_00_00Collision'

def build(layout,source,survey):
    if survey.get('failures')!=0:raise ValueError('Failed survey')
    rooms=[r for r in layout['spaces'] if r['id']==ROOM]
    if len(rooms)!=1 or rooms[0]['level']!='B1':raise ValueError('Expected current north storage bay')
    owners=[r for r in survey['records'] if r['owner']==OWNER]
    if len(owners)!=1 or not owners[0]['aligned'] or owners[0]['shape_type']!='BoxShape3D':raise ValueError('Expected one measured aligned north storage roof')
    b=owners[0]['bounds'];rect=rooms[0]['rect'];depth=layout['dimensions']['slab_thickness']
    if max(abs(x-y) for x,y in zip([b[0],b[2],b[3],b[5]],rect))>.00003 or abs(b[4])>.00003 or abs(b[1]+depth)>.00003:raise ValueError('Roof geometry changed; inspect its ownership')
    rows=[]
    for ri,station in enumerate(source['stations']['records']):
        for pi,point in enumerate(station['points']):
            x,y,z=point
            if not (rect[0]<x<rect[2] and rect[1]<z<rect[3]):continue
            if station['post']!='North3' or abs(y)>.000001:raise ValueError('Unexpected original probe inside current roof')
            prior=source['prior_records'][ri]['samples'][pi]
            if prior['first_owner'] or prior['first_y'] is not None:raise ValueError('Never replace an existing historical owner')
            rows.append(dict(record_index=ri,point_index=pi,point=point,source_room=ROOM,collider=OWNER,visual_name=OWNER.rsplit('/',1)[1].removesuffix('Collision'),bounds=b,expected_y=0.))
    if len(rows)!=3:raise ValueError('Exactly three unchanged North3 probes require ownership renewal')
    return dict(evidence_class='INERT',schema='orison.ground-probe-ownership.v1',records=rows,scope='Three source-qualified current roof contacts; original station coordinates and historical results remain unchanged. Not human or whole-building acceptance.')

def digest(path):
    data=path.read_bytes();return hashlib.sha256(data if path.suffix in {'.glb','.bin','.blend'} else data.replace(b'\r\n',b'\n')).hexdigest()

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True);args=parser.parse_args()
    paths=['game/data/orison_v2_blockout.json','game/tests/fixtures/orison_ground_source.json','art/data/orison_ground/discovery/runtime_survey.json']
    values=[json.loads((ROOT/p).read_text()) for p in paths]
    from run_receipt import runtime_inputs_sha256
    if values[2]['source']['runtime_inputs_sha256']!=runtime_inputs_sha256(ROOT):raise ValueError('Fresh runtime survey required')
    result=build(*values)
    paths+=['game/scripts/building/orison_v2_ceiling_top_closures.gd','game/assets/props/ceiling_top_closures.glb','tools/build_v2_ground_probe_updates.py']
    result['bindings']={p:digest(ROOT/p) for p in paths}
    args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(result,indent=2)+'\n',newline='\n')
    print('Qualified three unchanged North3 points against the current storage roof; original fixture untouched')

if __name__=='__main__':main()
