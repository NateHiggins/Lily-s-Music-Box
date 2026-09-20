"""Open the sidewalk over the relocated stair without changing its perimeter."""
from pathlib import Path
import json
def open_stair(template):
    candidates=[b for b in template['boxes'] if b['id'].startswith('passage_pavement_slab')]
    assert candidates
    old=candidates[0]
    assert old['position_m'][1]==-.08 and old['size_m'][1]==.16
    # Inner tiled cheek faces bound the opening; leave the plinth supported.
    hole=(-.045,15.475,4.095,16.525)
    bounds=(-20.3,14.099,22,18.521)
    x0,z0,x1,z1=bounds
    a,b,c,d=hole
    rects={'west':(x0,z0,a,z1),'east':(c,z0,x1,z1),
           'street':(a,z0,c,b),'arcade':(a,d,c,z1)}
    index=template['boxes'].index(old)
    pieces=[]
    for label,(lo_x,lo_z,hi_x,hi_z) in rects.items():
        piece=dict(old,id='passage_pavement_slab_'+label,
                   position_m=[(lo_x+hi_x)/2,-.08,(lo_z+hi_z)/2],
                   size_m=[hi_x-lo_x,.16,hi_z-lo_z])
        pieces.append(piece)
    template['boxes']=[b for b in template['boxes'] if b not in candidates]
    template['boxes'][index:index]=pieces

if __name__=='__main__':
    from build_v2_street_section import readable
    root=Path(__file__).resolve().parents[1]
    path=root/'game/data/orison_v2/exterior/exterior_geometry.json'
    data=json.loads(path.read_text())
    open_stair(next(t for t in data['templates'] if t['id']=='TEMPLATE_STREET_SEGMENT_V1'))
    path.write_text(readable(data)+'\n')
    print('Relocated subway opening applied; sidewalk perimeter preserved')
