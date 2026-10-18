"""Check explicit V2 projections of physically calibrated runtime recipes.

Supplements the universal loaded UV/PBR/mip gate; grants no surface exemption
or runtime proof. Finds stale tile/normal snapshots before a composed boot.
"""
from pathlib import Path
import argparse,ast,json,math
ROOT=Path(__file__).resolve().parents[1]

def calibrated(root):
    tree=ast.parse((root/'art/tools/generate_runtime_materials.py').read_text(encoding='utf-8'))
    assignment=next(n for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='RUNTIME_POLICY' for t in n.targets))
    return {k:v for k,v in ast.literal_eval(assignment.value).items() if 'normal_scale' in v}

def evaluate(root=ROOT,policies=None):
    root=Path(root);policies=calibrated(root) if policies is None else policies
    catalogue=json.loads((root/'game/data/runtime_material_sets.json').read_text(encoding='utf-8'))['materials']
    wrong=[];checked=0;dependencies=set();families=set()
    for file in sorted((root/'game/data/orison_v2').glob('*.json')):
        data=json.loads(file.read_text(encoding='utf-8'));matched=False
        def check(value,expected,path,field):
            if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or abs(value-expected)>1e-6:
                wrong.append(f'{file.relative_to(root).as_posix()}:{path}/{field}: {value!r} != {expected}')
        def walk(value,path=''):
            nonlocal checked,matched
            if isinstance(value,dict):
                key=value.get('catalog_key',value.get('key'))
                if isinstance(key,str) and key in policies:
                    matched=True
                    if key not in catalogue:wrong.append('unregistered calibrated key: '+key)
                    elif 'tile' in value:
                        checked+=1;check(value['tile'],float(catalogue[key]['meters_per_tile']),path,'tile')
                    for field in ['normal','normal_scale']:
                        if isinstance(value.get(field),(int,float)):check(value[field],float(policies[key]['normal_scale']),path,field)
                    finish=value.get('finish',{})
                    if isinstance(finish,dict) and 'normal_scale' in finish:check(finish['normal_scale'],float(policies[key]['normal_scale']),path+'/finish','normal_scale')
                for key,child in value.items():walk(child,path+'/'+key)
            elif isinstance(value,list):
                for i,child in enumerate(value):walk(child,path+'/'+str(i))
        walk(data)
        if matched and isinstance(data,dict) and str(data.get('asset','')).startswith('res://assets/props/'):
            family=Path(data['asset']).stem;families.add(family)
            for relative in [f'art/blender/{family}.blend',f'art/data/{family}/source_plan.json']:
                source=root/relative
                if source.exists():dependencies.add(source)
                elif relative.endswith('.blend'):wrong.append('missing native recipe source: '+relative)
    return {'scope':'calibrated_recipe_projections','counts':{'wrong':len(wrong)},'wrong':wrong,'checked_tiles':checked,'families':sorted(families)},dependencies

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=ROOT);parser.add_argument('--json',action='store_true');args=parser.parse_args()
    result,_=evaluate(args.root);print(json.dumps(result,indent=2));return 1 if result['wrong'] else 0

if __name__=='__main__':raise SystemExit(main())
