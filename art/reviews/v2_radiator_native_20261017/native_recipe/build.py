"""Build a disposable native radiator kit; never installs game assets.

python build.py --root C:/PleaseRemainOnTheLine --out C:/ov/radiator-native
  --blender "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
Add --reuse to verify unchanged sources AND artifact hashes without rerunning.
"""
from pathlib import Path
import argparse,hashlib,json,os,runpy,subprocess,sys,time,shutil
import numpy as np
import PIL
HERE=Path(__file__).resolve().parent
def digest(path):
    raw=path.read_bytes()
    if path.suffix in {'.py','.gd','.json'}:raw=raw.replace(b'\r\n',b'\n')
    return hashlib.sha256(raw).hexdigest()
def inputs(root,blender,render):
    paths=list(HERE.glob('*.py'))+[HERE/'package_lineage.json',HERE/'mount_plan.json',root/'art/blender/heating_distribution.blend',root/'game/scripts/props/radiator_prop.gd',root/'game/data/runtime_material_sets.json']
    paths+=list((root/'art/blender/scripts').rglob('*.py'))
    paths+=list((root/'game/assets/building/textures').rglob('*.png'))
    records={('recipe/'+p.relative_to(HERE).as_posix() if p.is_relative_to(HERE) else p.relative_to(root).as_posix()):digest(p) for p in sorted(set(paths))}
    records.update({'toolchain/blender_binary_sha256':digest(blender),'toolchain/python':sys.version,'toolchain/numpy':np.__version__,'toolchain/pillow':PIL.__version__,'recipe/render_requested':str(render)})
    for folder in blender.parent.glob('*/scripts/addons_core/io_scene_gltf2'):
        for path in folder.rglob('*.py'):records['toolchain/gltf_exporter/'+path.relative_to(folder).as_posix()]=digest(path)
    return hashlib.sha256(json.dumps(records,sort_keys=True,separators=(',',':')).encode()).hexdigest(),records
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,required=True);parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--blender',type=Path,required=True);parser.add_argument('--reuse',action='store_true');parser.add_argument('--render',action='store_true')
    args=parser.parse_args();root=args.root.resolve(strict=True);out=args.out.resolve()
    assert (root/'game/project.godot').is_file(),root
    assert out!=root and not out.is_relative_to(root/'game') and not out.is_relative_to(root/'art'),'Use a disposable output directory; this builder never installs production assets'
    blender=args.blender.resolve(strict=True)
    out.mkdir(parents=True,exist_ok=True);signature,records=inputs(root,blender,args.render);manifest=out/'build_manifest.json'
    if args.reuse and manifest.is_file():
        previous=json.loads(manifest.read_text())
        if previous.get('status')=='PASS' and previous.get('input_sha256')==signature and all((out/name).is_file() and digest(out/name)==sha for name,sha in previous['outputs_sha256'].items()):
            print('RADIATOR REUSE: source and output hashes verified; no new execution',flush=True);return
    os.environ['ORISON_RADIATOR_BUILD_ROOT']=str(root);os.environ['ORISON_RADIATOR_BUILD_OUT']=str(out)
    os.environ['ORISON_RADIATOR_RENDER']='1' if args.render else '0'
    shutil.copyfile(HERE/'mount_plan.json',out/'wall_tie_mount_plan.json')
    sys.path.insert(0,str(HERE));runpy.run_path(str(HERE/'graphited_cloth.py'),run_name='__main__')
    started=time.monotonic()
    with (out/'blender_build.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([str(blender),'-b','--python-exit-code','1','--python',str(HERE/'worker.py')],cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=600)
    final,_=inputs(root,blender,args.render)
    passed=result.returncode==0 and final==signature
    artifacts={p.relative_to(out).as_posix():digest(p) for p in sorted(out.rglob('*')) if p.is_file() and p.suffix in {'.blend','.glb','.json','.png'} and p.name!='build_manifest.json'}
    report=dict(evidence_class='INERT',scope='Reproducible native candidate kit; component checks and scratch base/morph buffers only. No runtime installation, loaded mipmaps, controls, walking or human acceptance.',status='PASS' if passed else 'FAIL',blender_exit_code=result.returncode,input_sha256=signature,input_sha256_after=final,elapsed_seconds=round(time.monotonic()-started,3),inputs=records,outputs_sha256=artifacts)
    manifest.write_text(json.dumps(report,indent=2)+'\n',newline='\n')
    print('RADIATOR BUILD',report['status'],report['elapsed_seconds'],'seconds;',len(artifacts),'artifacts; log',out/'blender_build.log',flush=True)
    if not passed:raise SystemExit(result.returncode or 1)
if __name__=='__main__':main()
