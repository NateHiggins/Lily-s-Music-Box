"""Verify and reproduce the seven-stock public fitting declaration, without Godot."""
from pathlib import Path
import argparse
import hashlib
import json
import sys
from prepare_arcade_native_projection import NativeGLB

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
import arcade_clock_suspension_geometry as Clock
import arcade_hatch_geometry as Hatches


def need(ok,message):
    if not ok: raise ValueError(message)


def sha(path):
    data=Path(path).read_bytes()
    if Path(path).suffix not in {'.png','.blend','.glb'}: data=data.replace(b'\r\n',b'\n')
    return hashlib.sha256(data).hexdigest()


def build(proof,delivery,root=ROOT):
    root=Path(root);delivery=Path(delivery)
    need(proof.get('status')=='NATIVE_EXPORT_PASS_UNRENDERED_NOT_INSTALLED','native export not complete')
    bindings=proof.get('source_bindings',{})
    for path in ['game/data/building_layout.json','game/data/orison_v2/arcade_clock.json',
                 'art/data/arcade_plaza/source_plan.json','art/data/arcade_plaza/roof_plan.json',
                 'game/data/runtime_material_sets.json','art/blender/scripts/build_arcade_public_fittings.py',
                 'art/blender/scripts/arcade_hatch_geometry.py','art/blender/scripts/arcade_clock_suspension_geometry.py']:
        need(path in bindings,'missing required source binding '+path)
    for name,digest in bindings.items():
        path=(root/name).resolve()
        need(path.is_relative_to(root.resolve()),'binding escapes root')
        need(sha(path)==digest,'changed public fitting source '+name)
    load=lambda name:json.loads((root/name).read_text(encoding='utf-8'))
    layout=load('game/data/building_layout.json');clock=load('game/data/orison_v2/arcade_clock.json')
    plan=load('art/data/arcade_plaza/source_plan.json');roof=load('art/data/arcade_plaza/roof_plan.json')
    need(proof['clock']==Clock.build(layout,clock,plan,roof),'clock receiver proof changed')
    need(proof['hatches']==Hatches.build(layout,plan),'hatch receiver proof changed')
    data=proof['runtime'];asset=delivery/'game/assets/props/arcade_public_fittings.glb'
    need(sha(asset)==data['asset_sha256'],'native public payload changed')
    need(sha(delivery/'art/blender/arcade_public_fittings.blend')==proof['blend_sha256'],'editable public source changed')
    native=NativeGLB(asset);parts=data['parts']
    sources={r['name']:r for r in proof['clock']['stocks']+proof['hatches']['stocks']}
    names=set(sources)
    need(len(parts)==7 and len({r['name'] for r in parts})==7 and set(native.names)==names,'seven original public identities required')
    for row in parts:
        name=row['name'];need(name==row['source_id'] and name in names,'public source identity changed')
        stock=sources[name];kind='clock' if name in {Clock.STEM,Clock.DROP} else 'hatch'
        need(row['kind']==kind and row['material']==stock['material'],'public kind/material changed')
        need(native.triangles(name)==row['triangles']==sum(len(face)-2 for face in stock['faces']),'public native count changed')
        origin=clock['origin'] if kind=='clock' else [plan['source_origin_blender_m'][0],plan['source_origin_blender_m'][2],-plan['source_origin_blender_m'][1]]
        expected=[[1,0,0,origin[0]],[0,1,0,origin[1]],[0,0,1,origin[2]],[0,0,0,1]]
        need(row['transform']==expected,'public declaration source frame changed')
        actual=native.transform(native.names[name])
        need(all(abs(actual[i][j]-row['transform'][i][j])<.00001 for i in range(4) for j in range(4)),'public source frame changed')
    need(data['fabrication_sha256_lf']==sha(root/'game/data/building_layout.json'),'fabrication runtime binding changed')
    need(data['clock_source_sha256_lf']==sha(root/'game/data/orison_v2/arcade_clock.json'),'clock runtime binding changed')
    need(data['clock_asset_sha256']==sha(root/'game'/clock['asset'][6:]),'original clock native binding changed')
    need(data['clock_delta']==proof['clock']['proof']['delta'],'whole-clock projection changed')
    return data


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--delivery',type=Path,required=True)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    proof=json.loads((args.delivery/'PUBLIC_FITTINGS.json').read_text(encoding='utf-8'))
    text=json.dumps(build(proof,args.delivery),indent=2)+'\n'
    destination=args.delivery/'game/data/orison_v2/arcade_public_fittings.json'
    if args.check: need(destination.read_text(encoding='utf-8')==text,'stale public declaration')
    else: destination.write_text(text,encoding='utf-8',newline='\n')
    print('ARCADE_PUBLIC_FITTINGS_INTAKE_PASS seven native source identities')


if __name__=='__main__': main()
