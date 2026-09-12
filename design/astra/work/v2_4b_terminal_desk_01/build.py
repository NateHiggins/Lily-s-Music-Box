"""Authored V2 terminal support within the existing schematic desk footprint."""
import hashlib
import itertools
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def read(path): return json.loads((ROOT/path).read_text(encoding='utf-8'))
blocks=[dict(id='oak_top',material='oak_quartered',low=[-.29,.705,-.625],high=[.29,.75,.625])]
for x,z in itertools.product([-.23,.23],[-.565,.565]):
    blocks.append(dict(id='leg_%s_%s'%(x,z),material='wood_dark',low=[x-.0275,0,z-.0275],high=[x+.0275,.705,z+.0275]))
for x in [-.23,.23]:
    blocks.append(dict(id='side_apron_'+str(x),material='wood_dark',low=[x-.0175,.58,-.565],high=[x+.0175,.705,.565]))
for z in [-.565,.565]:
    blocks.append(dict(id='end_apron_'+str(z),material='wood_dark',low=[-.23,.58,z-.0175],high=[.23,.705,z+.0175]))
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
record=dict(id='4B_terminal_desk',kind='desk',
    bounds=[[min(b['low'][i] for b in blocks) for i in range(3)],
            [max(b['high'][i] for b in blocks) for i in range(3)]],surfaces=list(surfaces.values()))
target='game/data/orison_v2/domestic_furniture.json'
furniture=read(target)
furniture['furniture']=[r for r in furniture['furniture'] if r['id']!=record['id']]+[record]
(ROOT/target).write_text(json.dumps(furniture,separators=(',',':'))+'\n',encoding='utf-8',newline='\n')

anchor=dict(id='4B_terminal_desk',level='F04',space='F04_B_MAIN',position=[-9.05,0,1.25],yaw=0,kind='furniture')
path=ROOT/'game/data/orison_v2_blockout.json';text=path.read_text(encoding='utf-8')
existing=[a for a in json.loads(text)['anchors'] if a['id']==anchor['id']]
if existing: assert existing==[anchor]
else:
    start=text.index('[',text.index('"anchors"'));_,size=json.JSONDecoder().raw_decode(text[start:]);end=start+size-1
    text=text[:end].rstrip()+',\n    '+json.dumps(anchor,separators=(',',': '))+'\n  '+text[end:]
    path.write_text(text,encoding='utf-8',newline='\n')
(HERE/'assembly.json').write_text(json.dumps(dict(blocks=blocks,anchor=anchor,design_basis='Existing 0.58 x 1.25 m terminal support footprint; top matches 0.75 m instrument anchor. New wooden frame, not a recovered historical assembly.'),indent=2)+'\n')
print('Terminal desk: %d triangles'%sum(len(s['vertices'])//9 for s in record['surfaces']))
