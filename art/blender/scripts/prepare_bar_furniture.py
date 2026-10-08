"""Bind passive replacements to exact source records and shipping triangles."""
from pathlib import Path
import json, numpy as np

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
layout=json.loads((ROOT/'art/data/building_layout.json').read_text(encoding='utf-8'))
rows={r['id']:r for f in layout['floors'] if f['id']=='F01' for r in f['furniture']}
identities=['retail_bar_piano_body','retail_bar_piano_lid','retail_bar_piano_keys','retail_bar_mic']
identities += [k for k in rows if k.startswith('retail_bar_darts_') and 'ledge' not in k]
selected=[rows[k] for k in identities]
doc=json.loads((ROOT/'game/assets/building/floor_01_cells/shop_bar.gltf').read_text())
binary=(ROOT/'game/assets/building/floor_01_cells/shop_bar.bin').read_bytes()
def values(index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    dt=np.dtype({5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);w={'SCALAR':1,'VEC3':3}[a['type']]
    return np.ndarray((a['count'],w),dtype=dt,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',dt.itemsize*w),dt.itemsize)).astype(float)
def box_bounds(row):
    x0,y0,x1,y1=row['rect'];return np.array([min(x0,x1),row['z0'],-max(y0,y1)]),np.array([max(x0,x1),row['z0']+row['h'],-min(y0,y1)])
retirement=[];counts={}
for node in doc['nodes']:
    if 'mesh' not in node:continue
    name=node['name'];mesh=doc['meshes'][node['mesh']]
    if not any(s in name for s in ['_retail_bar_','_furnish_']):continue
    if 'hull' in name or 'fx_shadow' in name:continue
    assert len(mesh['primitives'])==1
    p=mesh['primitives'][0];v=values(p['attributes']['POSITION']);ind=values(p['indices']).astype(int).reshape((-1,3));tri=v[ind]
    normals=values(p['attributes']['NORMAL'])[ind].mean(axis=1)
    mask=np.zeros(len(tri),dtype=bool)
    for row in selected:
        if 'rect' in row:
            if not name.removesuffix('-col').endswith('_'+row['mat']):continue
            lo,hi=box_bounds(row);inside=((tri>=lo-3e-5)&(tri<=hi+3e-5)).all(axis=(1,2))
            r=row['rect'];orientation=1 if (r[2]-r[0])*(r[3]-r[1])>0 else -1
            # Require an actual boundary face, not arbitrary contained stock.
            boundary=np.zeros(len(tri),dtype=bool)
            for axis in range(3):
                for plane,sign in [(lo[axis],-1),(hi[axis],1)]:boundary |= (abs(tri[:,:,axis]-plane)<3e-5).all(axis=1)&(normals[:,axis]*sign*orientation>.999)
            hit=inside&boundary
            if hit.any():
                assert hit.sum()==12,(row['id'],name,int(hit.sum()))
                assert row['id'] not in counts,row['id']
                mask |= hit;counts[row['id']]=12
    if '_furnish_' in name:
        # All target tubes occupy an isolated wall assembly. Exact original
        # coordinates below are retained for runtime triangle matching.
        for group,lo,hi,keys in [
            ('target',[-11.501,-1.32,32.749],[-11.38,-.82,33.251],['soot','linen','lacquer_red','safety_orange','brass_bright','fabric_green','book_teal','stairwell_teal','felt_violet','brass']),
            ('microphone',[-.836,-2.581,36.614],[-.564,-1.23,37.14],['metal','soot'])]:
            if not any(name.endswith('_'+k) for k in keys):continue
            hit=((tri>=np.array(lo)-3e-5)&(tri<=np.array(hi)+3e-5)).all(axis=(1,2))
            mask |= hit;counts[group]=counts.get(group,0)+int(hit.sum())
    if mask.any():retirement.append({'name':name.removesuffix('-col'),'colliding':name.endswith('-col'),'source_triangles':len(tri),'triangles':tri[mask].tolist(),'count':int(mask.sum())})
assert counts['target']==26*40,counts
assert counts['microphone']==80+32+24+32,counts
for r in selected:
    if 'rect' not in r:continue
    x0,y0,x1,y1=r['rect']
    expected=0 if x1-x0<1e-4 or y1-y0<1e-4 else 12
    assert counts.get(r['id'],0)==expected,(r['id'],expected,counts)
    counts[r['id']]=expected
def finish(key,tint,normal,roughness,pigment=1.,metallic=None):
    d={'catalog_key':key,'tint':tint+[1.],'normal':normal,'roughness':roughness,'pigment':pigment}
    if metallic is not None:d['metallic']=metallic
    return d
finishes={
    'case':finish('wood_dark',[.42,.40,.38],.025,.60,.55),
    'keybed':finish('wood_dark',[.34,.32,.30],.018,.45,.45),
    'key_white':finish('porcelain',[.81,.80,.76],.008,.34,.08),
    'key_white_b':finish('porcelain',[.79,.79,.75],.008,.34,.08),
    'key_black':finish('bakelite_black',[.50,.50,.50],.012,.30,.25),
    'iron':finish('iron_blackened',[.48,.48,.48],.025,.58),
    'brass':finish('brass',[.58,.54,.48],.015,.43),
    'nickel':finish('nickel_plated',[.74,.74,.74],.018,.36),
    'cloth':finish('linen',[.20,.18,.16],.08,.82),
    'target':finish('timber',[.64,.58,.48],.022,.92,.12),
    'score':finish('soot',[.62,.64,.65],.008,.94,.035),
}
for i,hexcolor in enumerate(['c0392b','d97b1f','d8b429','3f8f4a','2f6fb5','3b3f8f','7a4a9e']):
    # Literal seven-colour palette and darkened single fields come from the
    # retained DartsPanel, whose ring sizes come from DartsGame. Geometry
    # shows that same topology, rather than preserving the old coarse marks.
    tint=[int(hexcolor[j:j+2],16)/255 for j in [0,2,4]]
    finishes['sector_'+str(i)]=finish('linen',tint,.018,.90,.06)
    finishes['sector_'+str(i)+'_single']=finish('linen',[v*.66 for v in tint],.018,.90,.06)
plan={'schema':'orison.bar-furniture.source-plan.v1','classification':'ADAPTATION','dossier_items':['G09','G11'],
    'source_records':selected,'retirement':retirement,'source_counts':counts,'finishes':finishes,
    'keyboard':{'source_key_count':None,'adapted_key_count':73,'naturals':43,'accidentals':30,'range':'C to C, six octaves','span_m':1.,'rationale':'The source supplies a one-metre undivided strip, not a count. Explicit compact passive 73-key adaptation fits that span with 23.26 mm natural-key pitch; this is no recovered historical maker identification.'},
    'target':{'radial_groups':7,'ring_radii_m':[.099,.107,.162,.17],'bull_radii_m':[.00635,.0159],'substrate':'inferred timber target with painted fields; no assertion of a compressed-sisal competition blank','preserve':'Original Rainbow Round UI, scoring, E owner and oche; no physical projectiles or new numerals. Refine the 21 old radial marker bars into the exact seven coloured scoring fields and four wire radii already drawn by DartsPanel/DartsGame.','left_door':'The original source rectangle has descending Y endpoints. MeshBuf.add_box skipped it. Reconstruct that authored parked door using sorted endpoints, without changing the protected source.'},
    'microphone':{'preserve':'Original stage base, boom and capsule endpoints. Cable follows stand between head fitting and seated passive base socket. No new power, recorder or input owner.'},
    'references':[{'url':'https://patents.google.com/patent/US1525339A/en','use':'1925 target patent informs the existence of different target substrates; no image copied or modern sisal construction inferred.'}],
    'supports':['Original stage floor','Original west wall above dado'],
    'left_leaf_fit':'Park the recovered left leaf at 90 degrees about its source hinge to clear the two retained gallery pictures. Keep the source leaf span/height and hinge anchors; the never-rendered flat source pose is unsuitable in the assembled gallery. The right leaf retains its source parked plane.',
    'no_new_authority':['piano action','pedal action','microphone capture','dart scoring','cabinet door simulation','scene text','light output']}
path=ROOT/'art/data/bar_furniture/source_plan.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(plan,indent=2)+'\n',encoding='utf-8',newline='\n')
print('BAR FURNITURE SOURCE',counts,'draws',len(retirement),'triangles',sum(r['count'] for r in retirement))
