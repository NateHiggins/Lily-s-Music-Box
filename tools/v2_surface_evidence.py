"""Bind the composed V2 surface qualification to rendering inputs and review.

Changes never inherit an old pass. Text is LF-normalized; imported cache UIDs
are excluded. The test itself writes runtime_contract.json. This tool checks
that receipt, independently re-evaluates its inventory, and checks review files.
"""
import argparse,hashlib,json,sys,subprocess
from pathlib import Path
from audit_v2_surfaces import evaluate

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/renders/orison_v2/surface_requirements_20261011'
TEXT={'.gd','.tscn','.tres','.godot','.json','.py','.gdshader','.gdshaderinc','.gltf','.import'}
ASSETS={'.glb','.gltf','.bin','.rg8','.png','.jpg','.jpeg','.webp','.tres','.tscn'}

def file_hash(path):
    raw=path.read_bytes()
    if path.suffix in TEXT:raw=raw.replace(b'\r\n',b'\n')
    return hashlib.sha256(raw).hexdigest()

def inputs(root=ROOT):
    # Imported GLB extracts and ingest caches are derived local state. Track
    # authored inputs, including new nonignored additions, before qualification.
    versioned=set(subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=root).decode().split('\0'))
    paths=set()
    for directory,suffixes in [('game/scripts',{'.gd'}),('game/scenes',{'.tscn','.tres'}),
                               ('game/data',{'.json'}),('game/shaders',{'.gdshader','.gdshaderinc'}),
                               ('game/assets',ASSETS),('art/blender/scripts',{'.py'}),
                               ('art/textures/ai_materials',{'.json'}),('game/tests/fixtures',{'.json'})]:
        paths.update(p for p in (root/directory).rglob('*') if p.is_file() and p.suffix in suffixes and p.relative_to(root).as_posix() in versioned)
    paths.update(root/p for p in ['game/project.godot','game/tests/orison_v2_surface_inventory.gd',
                 'game/tests/OrisonV2SurfaceInventory.tscn','tools/audit_v2_surfaces.py',
                 'tools/v2_surface_evidence.py','art/tools/fix_runtime_texture_imports.py',
                 'art/tools/fix_v2_mesh_imports.py','art/tools/generate_runtime_materials.py',
                 'art/tools/ingest_material_sources.py','art/tools/build_clear_water_maps.py',
                 'art/data/gen_layout.py','art/data/material_catalog.json','art/textures/catalog_mapping.json'])
    for name in ('toast_crumb','leather_worn','mineral_scale'):
        paths.add(root/f'art/textures/ai_sources/{name}.png')
    paths.add(root/'art/textures/ai_sources/v2_surface_stock_20261011.json')
    for name in ('v2_millwork_weather_review.gd','v2_millwork_weather_test.gd','v2_window_treatments_review.gd','v2_window_treatments_test.gd'):
        paths.add(root/'game/tests'/name)
    # Texture source bindings and selective UV precision settings are authored
    # inputs. Cache destinations, generated UIDs, and line endings are not.
    imports=list((root/'game/assets/building/textures').glob('*.png.import'))
    imports.extend((root/'game/assets/environment/weather').glob('*.png.import'))
    sys.path.insert(0,str(root/'art/tools'))
    from fix_v2_mesh_imports import ASSETS as UV_IMPORTS
    imports.extend(root/'game/assets'/(asset+'.import') for asset in UV_IMPORTS)
    imports.extend(p for p in (root/'game/assets/characters/mina_vale').glob('*.png.import') if p.relative_to(root).as_posix() in versioned)
    imports.extend(p for p in (root/'game/assets/ui/telegram').glob('*.png.import') if p.relative_to(root).as_posix() in versioned)
    manifest=sorted([p.relative_to(root).as_posix(),file_hash(p)] for p in paths)
    for path in sorted(imports):
        text=path.read_text(encoding='utf-8').replace('\r\n','\n')
        if '[params]' not in text:raise ValueError('import has no parameters: '+str(path))
        manifest.append([path.relative_to(root).as_posix(),hashlib.sha256(text.split('[params]',1)[1].strip().encode()).hexdigest()])
    manifest.sort()
    return {'algorithm':'sha256/LF-normalized-text-and-import-parameters/v1','files':len(manifest),
            'sha256':hashlib.sha256(json.dumps(manifest,separators=(',',':')).encode()).hexdigest()}

def qualify(packet=PACKET,root=ROOT):
    defects=[]
    try:
        receipt=json.loads((packet/'runtime_contract.json').read_text())
        inventory_path=packet/'surface-inventory.json'
        inventory=json.loads(inventory_path.read_text())
        if receipt.get('schema_version')!=2 or receipt.get('evidence_kind')!='runtime_contract' or receipt.get('selector')!='v2' or not receipt.get('production_runtime'):
            defects.append('invalid runtime-contract identity')
        execution=receipt.get('execution',{})
        if not execution.get('completed') or execution.get('exit_code')!=0 or execution.get('timed_out'):
            defects.append('runtime qualification did not complete successfully')
        for key in ('production_composition','surface_requirements','teardown'):
            contract=receipt.get('contracts',{}).get(key,{})
            if contract.get('status')!='PASS' or not contract.get('executed'):defects.append('contract not passed: '+key)
        current=inputs(root)['sha256']
        if receipt.get('surface_inputs_sha256')!=current:defects.append('stale surface qualification: rendering inputs changed')
        if receipt.get('inventory_sha256')!=file_hash(inventory_path):defects.append('inventory changed after runtime qualification')
        report=evaluate(inventory)
        defects.extend(f['id']+':'+','.join(f['reasons']) for f in report['findings'])
        coverage=inventory.get('coverage',{})
        if not coverage.get('production_world') or not coverage.get('space_count') or not coverage.get('resident_cells'):
            defects.append('composed-world coverage missing')
        review=json.loads((packet/'visual_review.json').read_text())
        if review.get('surface_inputs_sha256')!=current or review.get('status')!='PASS' or not review.get('images'):
            defects.append('missing or stale rendered review')
        for row in review.get('images',[]):
            path=packet/row['file']
            if not path.is_file() or file_hash(path)!=row['sha256'] or not row.get('observation'):
                defects.append('unreviewed/changed render: '+row['file'])
        counts={'draws':len(inventory['draws']),'materials':len(inventory['materials']),'textures':len(inventory['textures'])}
    except (OSError,ValueError,KeyError,TypeError) as exc:
        defects.append(str(exc));counts={}
    return {'result':'FAIL' if defects else 'PASS','counts':{'defects':len(defects)},'defects':defects,'coverage':counts}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot',action='store_true');parser.add_argument('--out');parser.add_argument('--packet',type=Path,default=PACKET)
    args=parser.parse_args();report=inputs() if args.snapshot else qualify(args.packet)
    text=json.dumps(report,indent=2)+'\n'
    if args.out:Path(args.out).write_text(text,newline='\n')
    print(text,end='')
    return 1 if report.get('defects') else 0

if __name__=='__main__':raise SystemExit(main())
