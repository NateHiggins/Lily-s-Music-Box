"""Compile the existing native leaf proof into its minimal runtime sidecar.

Default: shipped full native proof. --proof selects one explicit new producer
proof for deliberate intake AFTER its GLB has been copied to the shipping path.
--check never writes. Neither mode edits the full proof/native evidence.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import re

from prepare_arcade_native_projection import NativeGLB

ROOT=Path(__file__).resolve().parents[1]
PROOF=Path('game/tests/fixtures/arcade_door_leaf_native.json')
OUTPUT=Path('game/data/orison_v2/arcade_door_leaves.json')
ASSET='res://assets/props/arcade_door_leaves.glb'
SCHEMA='orison.v2.arcade-door-leaves.v1'
DRAW_KEYS={side+suffix:key for side in ['Left','Right'] for suffix,key in
           [('Wood','door_oak'),('Glass','glass_drawn_expressive'),
            ('Brass','door_brass'),('FixedBrass','door_brass')]}


def require(ok,message):
    if not ok:raise ValueError(message)


def bound(value,label):
    require(isinstance(value,list) and len(value)==3 and
            all(type(n) in (int,float) and math.isfinite(n) for n in value),
            'finite three-coordinate bound required: '+label)
    return list(value)


def box(value,label):
    require(isinstance(value,dict),'box missing: '+label)
    low=bound(value.get('low'),label+'/low');high=bound(value.get('high'),label+'/high')
    require(all(a<b for a,b in zip(low,high)),'nonpositive box: '+label)
    return dict(low=low,high=high)


def _verify_sources(root,proof):
    bindings=proof.get('source_bindings')
    require(isinstance(bindings,dict) and bindings,'original source bindings missing')
    for name,binding in bindings.items():
        require(isinstance(name,str) and isinstance(binding,dict),'invalid source binding')
        path=(root/name).resolve()
        require(not Path(name).is_absolute() and path.is_relative_to(root.resolve())
                and path.is_file(),'source binding path unavailable: '+name)
        kind=binding.get('kind')
        require(kind in ['lf','raw'],'source byte convention missing: '+name)
        raw=path.read_bytes()
        if kind=='lf':raw=raw.replace(b'\r\n',b'\n')
        require(hashlib.sha256(raw).hexdigest()==binding.get('sha256'),
                'original producer source changed: '+name)


def build(root=ROOT,proof=None,verify_source_bindings=False):
    root=Path(root)
    if proof is None:proof=json.loads((root/PROOF).read_text(encoding='utf-8'))
    require(isinstance(proof,dict) and proof.get('schema')==SCHEMA,'native proof schema')
    require(proof.get('asset')==ASSET,'fixed shipping asset required')
    asset=root/'game'/ASSET[6:]
    digest=proof.get('asset_sha256')
    require(isinstance(digest,str) and re.fullmatch('[0-9a-f]{64}',digest)
            and asset.is_file() and hashlib.sha256(asset.read_bytes()).hexdigest()==digest,
            'shipping GLB SHA does not match native proof')
    dimensions=proof.get('dimensions')
    require(isinstance(dimensions,dict) and type(dimensions.get('nominal_width_m')) in (int,float)
            and dimensions['nominal_width_m']==1.0 and
            type(dimensions.get('nominal_height_m')) in (int,float)
            and dimensions['nominal_height_m']==2.3,'native1m/2.3m dimensions required')
    rows=proof.get('draws')
    require(isinstance(rows,list) and len(rows)==8,'exact eight native draws required')
    draws={}
    for row in rows:
        require(isinstance(row,dict),'invalid native draw record')
        name=row.get('name');key=row.get('material_key');count=row.get('triangles')
        require(isinstance(name,str) and name in DRAW_KEYS and name not in draws,
                'unknown/duplicate native draw')
        require(key==DRAW_KEYS[name],'native material changed: '+name)
        require(type(count) is int and count>0,'positive triangle count required: '+name)
        draws[name]=dict(name=name,key=key,triangles=count)
    require(set(draws)==set(DRAW_KEYS),'native draw inventory incomplete')
    native=NativeGLB(asset)
    require(set(native.names)==set(DRAW_KEYS),'actual GLB draw inventory differs')
    identity=[[int(i==j) for j in range(4)] for i in range(4)]
    for name,row in draws.items():
        i=native.names[name];matrix=native.transform(i)
        require(all(abs(matrix[a][b]-identity[a][b])<=1e-8 for a in range(4) for b in range(4)),
                'actual GLB must retain local identity hinge frame: '+name)
        require(native.triangles(name)==row['triangles'],'actual GLB triangle count differs: '+name)
        mesh=native.doc['meshes'][native.doc['nodes'][i]['mesh']]
        require(len(mesh['primitives'])==1,'one native material draw required: '+name)
        material=native.doc['materials'][mesh['primitives'][0]['material']]
        require(material.get('name')=='M_'+row['key'],'actual GLB material differs: '+name)
    cores=proof.get('core_collision_boxes');pulls=proof.get('pull_collision_boxes')
    require(isinstance(cores,dict) and set(cores)=={'Left','Right'} and
            isinstance(pulls,dict) and set(pulls)=={'Left','Right'},'exact two leaf collider owners required')
    boxes=[]
    for side in ['Left','Right']:
        core=box(cores[side],side+'Core')
        # The physical opaque/glazed core is bounded by the ACTUAL shipping
        # timber mesh, not an arbitrary finite box supplied by a prose claim.
        mesh=native.doc['meshes'][native.doc['nodes'][native.names[side+'Wood']]['mesh']]
        positions=native.doc['accessors'][mesh['primitives'][0]['attributes']['POSITION']]
        require(all(abs(core[k][i]-positions[key][i])<=1e-7
                    for k,key in [('low','min'),('high','max')] for i in range(3)),
                'core box differs from actual shipping timber: '+side)
        boxes.append(dict(name=side+'Core',side=side,**core))
        rows=pulls[side]
        require(isinstance(rows,list) and len(rows)==2,'exact two pull faces required: '+side)
        faces={}
        for row in rows:
            require(isinstance(row,dict) and type(row.get('face')) is int and
                    row['face'] in [-1,1] and row['face'] not in faces,'duplicate/invalid pull face: '+side)
            value=box(row,side+'Pull'+str(row['face']))
            require(value['high'][0]-value['low'][0]<.1 and
                    min(abs(value['low'][0]),abs(value['high'][0]))>.8 and
                    value['low'][1]>.89,'pull box includes hinge/keyhole region: '+side)
            require(value['low'][2]>0 if row['face']==1 else value['high'][2]<0,
                    'pull face depth has wrong sign: '+side)
            faces[row['face']]=value
        for face in [-1,1]:boxes.append(dict(name=side+'Pull'+str(face),side=side,**faces[face]))
    if verify_source_bindings:_verify_sources(root,proof)
    return dict(schema=SCHEMA,asset=ASSET,asset_sha256=digest,
                leaf_width_m=float(dimensions['nominal_width_m']),height_m=float(dimensions['nominal_height_m']),
                parts=[draws[k] for k in sorted(draws)],collider_boxes=boxes)


def render(data):return json.dumps(data,indent=2,allow_nan=False)+'\n'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--proof',type=Path,help='one explicit alternate full producer proof; shipping asset must already match')
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--verify-source-bindings',action='store_true',
                        help='also require the original producer/helper versions to remain byte-identical')
    args=parser.parse_args()
    proof=json.loads(args.proof.read_text(encoding='utf-8')) if args.proof else None
    text=render(build(args.root,proof,args.verify_source_bindings))
    target=args.root/OUTPUT
    if args.check:
        require(target.is_file() and target.read_text(encoding='utf-8').replace('\r\n','\n')==text,
                'runtime leaf intake stale; explicitly regenerate after reviewing native intake')
        print('ARCADE DOOR INTAKE OK; no render/runtime acceptance implied')
    else:
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(text,encoding='utf-8',newline='\n')
        print('WROTE '+str(OUTPUT))
    return 0


if __name__=='__main__':raise SystemExit(main())
