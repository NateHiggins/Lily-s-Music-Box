"""Source-only counter assembly and fixture installation. No engine is used."""
import hashlib
import itertools
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def read(path): return json.loads((ROOT/path).read_text(encoding='utf-8'))
layout=read('game/data/building_layout.json')
floor=next(f for f in layout['floors'] if f['id']=='F04')
original=[r for r in floor['furniture'] if r['id'].startswith('4B_kitchen_countertop_')]
assert len(original)==4
# Keep the four original boards relative to the authored compact sink centre.
blocks=[]
for r in original:
    x0,y0,x1,y1=r['rect']
    blocks.append(dict(id=r['id'],material='countertop',
        low=[x0+9.93,r['z0'],-(y1-9.31)],
        high=[x1+9.93,r['z0']+r['h'],-(y0-9.31)]))
# New V2 support frame: end posts and perimeter rails bear the original top.
# The open middle below the sink does not counterfeit cabinet doors or fill its bowl.
for x,z in itertools.product([-.90,.28],[-.22,.22]):
    blocks.append(dict(id='post_%s_%s'%(x,z),material='wood_dark',
        low=[x-.035,0,z-.035],high=[x+.035,.86,z+.035]))
for z in [-.255,.255]:
    blocks.append(dict(id='rail_'+str(z),material='wood_dark',
        low=[-.935,.69,z-.025],high=[.315,.86,z+.025]))
for x in [-.90,.28]:
    blocks.append(dict(id='end_'+str(x),material='wood_dark',
        low=[x-.035,.69,-.245],high=[x+.035,.86,.245]))

surfaces={}
for box in blocks:
    lo,hi=box['low'],box['high']
    assert all(hi[i]>lo[i] for i in range(3))
    surface=surfaces.setdefault(box['material'],dict(material=box['material'],vertices=[],normals=[]))
    # Corners are counterclockwise viewed from the outside, reversed for Godot.
    for axis in range(3):
        u,v=(axis+1)%3,(axis+2)%3
        for side in [0,1]:
            corners=[]
            for a,b in [(0,0),(1,0),(1,1),(0,1)]:
                point=lo.copy();point[axis]=hi[axis] if side else lo[axis]
                point[u]=hi[u] if a else lo[u];point[v]=hi[v] if b else lo[v]
                corners.append(point)
            n=[0,0,0];n[axis]=1 if side else -1
            order=[0,2,1,0,3,2] if side else [0,1,2,0,2,3]
            for i in order:
                surface['vertices']+=corners[i];surface['normals']+=n
record=dict(id='4B_sink_counter',kind='counter',collision_boxes=[[b['low'],b['high']] for b in blocks],
    bounds=[[min(b['low'][i] for b in blocks) for i in range(3)],
            [max(b['high'][i] for b in blocks) for i in range(3)]],surfaces=list(surfaces.values()))
target='game/data/orison_v2/domestic_furniture.json'
furniture=read(target)
furniture['furniture']=[r for r in furniture['furniture'] if r['id']!=record['id']]+[record]
(ROOT/target).write_text(json.dumps(furniture,separators=(',',':'))+'\n',encoding='utf-8',newline='\n')

anchor_base=dict(level='F04',space='F04_B_KITCHEN',yaw=0)
anchors=[dict(anchor_base,id='4B_sink_counter',position=[-14.42,0,5.85],kind='furniture'),
         dict(anchor_base,id='F04_4B_KITCHEN_SINK_01',position=[-14.42,0,5.85],kind='fixture'),
         dict(anchor_base,id='F04_4B_KITCHEN_SINK_STANCE',position=[-14.42,0,4.7],kind='clearance')]
path=ROOT/'game/data/orison_v2_blockout.json';text=path.read_text(encoding='utf-8')
existing=json.loads(text)['anchors'];ids={a['id'] for a in anchors}
installed=[a for a in existing if a['id'] in ids]
if installed: assert installed==anchors
else:
    start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
    text=text[:end].rstrip()+',\n'+',\n'.join('    '+json.dumps(a,separators=(',',': ')) for a in anchors)+'\n  '+text[end:]
    path.write_text(text,encoding='utf-8',newline='\n')
target='game/data/orison_v2/domestic_fittings.json';fittings=read(target)
sink=dict(id='F04_4B_KITCHEN_SINK_01',kind='sink',unit='4B',
    properties=dict(fixture='kitchen_sink',compact_kitchen=True,has_drainboard=False,drain_side=1))
previous=[r for r in fittings['fittings'] if r['id']==sink['id']]
if previous: assert previous==[sink]
else:
    fittings['fittings'].append(sink)
    (ROOT/target).write_text(json.dumps(fittings,indent=2)+'\n',encoding='utf-8',newline='\n')
(HERE/'assembly.json').write_text(json.dumps(dict(source_records=original,blocks=blocks,anchors=anchors,
    source_sha256=hashlib.sha256((ROOT/'game/data/building_layout.json').read_bytes()).hexdigest()),indent=2)+'\n')
print('Counter: %d triangles; compact sink installed through existing owner'%sum(len(s['vertices'])//9 for s in record['surfaces']))
