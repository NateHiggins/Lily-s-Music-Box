"""Bind the two bar receiver cases to their actual shipping source triangles."""
from pathlib import Path
import ast,collections,json,math,numpy as np
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
layout=json.loads((ROOT/'art/data/building_layout.json').read_text(encoding='utf-8'))
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
selected=[rows['retail_bar_cab01'],rows['retail_bar_cab02']]
text=(ROOT/'art/blender/scripts/build_orison.py').read_text(encoding='utf-8-sig')
function=next(n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef) and n.name=='asm_arcade_cab')
namespace={};exec(compile(ast.Module(body=[function],type_ignores=[]),'source-assembler','exec'),namespace)
class Collector:
    def __init__(self):self.counts=collections.Counter()
    def box(self,key,*args):self.counts[key]+=12
    def cyl(self,key,*args):self.counts[key]+=int(args[-1])*4
    def hull(self,*args):self.counts['hull']+=12
expected=collections.Counter()
for row in selected:
    collector=Collector();namespace['asm_arcade_cab'](collector,row);expected.update(collector.counts)
doc=json.loads((ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf').read_text())
binary=(ROOT/'game/assets/building/floor_01_cells/shop_bar.bin').read_bytes()
def values(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    dt=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);width={'SCALAR':1,'VEC3':3}[a['type']]
    return np.ndarray((a['count'],width),dtype=dt,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*width),dt.itemsize)).astype(float)
retirement=[];counts=collections.Counter()
for node in doc['nodes']:
    name=node.get('name','')
    if 'mesh' not in node or '_furnish_' not in name:continue
    key=name.split('_furnish_')[1].removesuffix('-colonly')
    if key not in expected:continue
    mesh=doc['meshes'][node['mesh']];assert len(mesh['primitives'])==1
    p=mesh['primitives'][0];tri=values(p['attributes']['POSITION'])[values(p['indices']).astype(int).reshape((-1,3))]
    mask=np.zeros(len(tri),dtype=bool)
    for row in selected:
        # Isolated original assembly envelopes, checked against every material
        # count emitted by the unchanged source assembler; exact faces bind runtime.
        source=tri[:,:,[0,2,1]].copy();source[:,:,1]*=-1
        source-=np.array([*row['at'],row['z0']]);angle=math.radians(row['yaw'])
        c,s=math.cos(angle),math.sin(angle)
        local=source@np.array([[c,-s,0],[s,c,0],[0,0,1]])
        hit=((local>=np.array([-.39,-.5,0])-3e-5)&(local<=np.array([.39,.36,[1.83,1.9][row['variant']]])+3e-5)).all(axis=(1,2))
        mask|=hit
    if mask.any():
        counts[key]+=int(mask.sum())
        retirement.append({'name':name.removesuffix('-colonly'),'kind':'hull' if key=='hull' else 'draw','source_triangles':len(tri),'triangles':tri[mask].tolist(),'count':int(mask.sum())})
assert counts==expected,(counts,expected)
plan={'evidence_class':'INERT','classification':'ADAPTATION','source_records':selected,'floor':rows['retail_bar_deck_s'],'retirement':retirement,
      'native_sources':[{'family':'news_receiving','source':'storm_shopcab_news_cigars0','target':'retail_bar_cab01'},{'family':'diner_receiving','source':'storm_shopcab_luncheonette0','target':'retail_bar_cab02'}],
      'adaptation':'Reuse accepted Blender closed stock for the matching original chassis variants. Keep all scope/control/header datums. Fit four iron feet per cabinet to the authored raised south deck; add seated foot pads. No new programme, supply circuit or moving service owner.',
      'expected_source_triangles':dict(expected)}
p=ROOT/'art/data/bar_receiving/source_plan.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8',newline='\n')
print('BAR RECEIVING SOURCE',dict(counts),'total',sum(counts.values()))
