"""Bind the composed V2 surface qualification to rendering inputs and review.

Changes never inherit an old pass. Text is LF-normalized; imported cache UIDs
are excluded. The test itself writes runtime_contract.json. This tool checks
that receipt, independently re-evaluates its inventory, and checks review files.
"""
import argparse,gzip,hashlib,json,re,sys,subprocess
from pathlib import Path
from audit_v2_surfaces import evaluate

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/renders/orison_v2/surface_requirements_20261011'
TEXT={'.gd','.tscn','.tres','.godot','.json','.py','.gdshader','.gdshaderinc','.gltf','.import'}
ASSETS={'.glb','.gltf','.bin','.rg8','.png','.jpg','.jpeg','.webp','.tres','.tscn'}

def test_dependency_paths(root,seeds):
    """Bind transitive test helpers/assets as well as the selected root tests."""
    root=Path(root).resolve();tests=root/'game/tests';result=set(seeds)
    pending=[p for p in result if p.resolve().is_relative_to(tests)]
    seen=set()
    while pending:
        path=pending.pop().resolve()
        if path in seen:continue
        seen.add(path)
        if not path.is_file() or path.suffix not in TEXT:continue
        for reference in re.findall(r'res://tests/[A-Za-z0-9_/.-]+',path.read_text(encoding='utf-8')):
            dependency=(root/'game'/reference.removeprefix('res://')).resolve()
            if not dependency.is_relative_to(root):raise ValueError('Test dependency escapes repository: '+reference)
            if dependency.is_file() and dependency not in result:
                result.add(dependency);pending.append(dependency)
    return result

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
                               ('art/blender/front_lighting_candidate',{'.py'}),
                               ('art/blender/front_lighting_finish',{'.py'}),
                               ('art/textures/ai_materials',{'.json'}),('game/tests/fixtures',{'.json'})]:
        paths.update(p for p in (root/directory).rglob('*') if p.is_file() and p.suffix in suffixes and p.relative_to(root).as_posix() in versioned)
    paths.update(root/p for p in ['game/project.godot','game/tests/orison_v2_surface_inventory.gd',
                 'game/tests/v2_front_restoration_review.gd',
                 'game/tests/OrisonV2SurfaceInventory.tscn','tools/audit_v2_surfaces.py',
                 'tools/v2_surface_evidence.py','art/tools/fix_runtime_texture_imports.py',
                 'art/tools/fix_v2_mesh_imports.py','art/tools/generate_runtime_materials.py',
                 'art/tools/ingest_material_sources.py','art/tools/build_clear_water_maps.py',
                 'art/data/gen_layout.py','art/data/material_catalog.json','art/textures/catalog_mapping.json'])
    for name in ('toast_crumb','leather_worn','mineral_scale'):
        paths.add(root/f'art/textures/ai_sources/{name}.png')
    paths.add(root/'art/textures/ai_sources/v2_surface_stock_20261011.json')
    paths.add(root/'art/tools/build_bathroom_tiles.py')
    # Front lighting ships from this native recipe family rather than the
    # older scripts directory. Its source and projection are rendering inputs.
    paths.update(root/p for p in (
        'art/blender/front_lighting_candidate.blend',
        'art/data/front_lighting_plan.json',
        'art/data/orison_v2/front_lighting_source.json',
        'art/data/orison_v2/front_lighting_supply_export.json',
        'art/blender/front_lighting_finish_candidate.blend',
        'art/blender/front_lighting_cornice_candidate.blend',
        'art/blender/millwork_profile.blend',
        'art/data/orison_v2/front_trim_layout_source.json',
        'art/data/orison_v2/front_trim_export_source.json',
        'tools/plan_v2_front_trim.py',
        'tools/plan_v2_front_lighting.py','tools/prepare_v2_front_lighting.py'))
    paths.update(root/p for p in (
        'art/blender/heating_distribution.blend',
        'art/blender/heating_distribution_base19.blend',
        'art/data/orison_v2/heating_refit_authoring.json',
        'art/data/orison_v2/heating_refit_layout_source.json',
        'tools/prepare_v2_heating_refit.py'))
    paths.add(root/'art/textures/material_sources/bathroom_ivory_glaze.png')
    paths.update(root/p for p in ('art/blender/domestic_seating.blend',
        'art/blender/domestic_seating_construction.json','art/data/domestic_seating/source_plan.json'))
    paths.add(root/'art/blender/annunciator_dispatch.blend')
    paths.add(root/'art/blender/light_switch.blend')
    paths.update(root/p for p in ('art/blender/construction_shed.blend',
        'tools/plan_v2_construction_shed.py','art/tools/build_site_softwood.py',
        'game/tests/v2_construction_shed_review.gd',
        'art/textures/ai_sources/site_softwood_20261017.png',
        'art/textures/ai_sources/site_softwood_20261017.json'))
    for key in ('site_softwood','site_softwood_endgrain'):
        for filename in ('material.json','albedo.png','normal.png','roughness.png','height.png'):
            paths.add(root/f'art/textures/procedural/{key}/{filename}')
    paths.add(root/'game/tests/v2_control_finish_review.gd')
    paths.add(root/'tools/preflight_spatial_test_bindings.py')
    paths.update(root/p for p in ('tools/build_v2_public_regions.py',
        'game/tests/public_region_programme_bench.gd',
        'game/tests/public_region_walk_probe.gd'))
    paths.update(root/p for p in ('game/tests/radiator_joint_review.gd',
        'art/blender/radiator_mechanisms.blend','art/tools/build_radiator_cast_iron.py',
        'art/textures/procedural/radiator_cast_iron/material.json',
        'art/reviews/v2_radiator_native_20261017/native_recipe/export_mechanisms.py'))
    from check_v2_recipe_projections import evaluate as recipe_dependencies
    _,authored_recipes=recipe_dependencies(root)
    paths.update(authored_recipes)
    paths.add(root/'tools/check_v2_recipe_projections.py')
    # Installed arcade fabric owns its actual native recipes and custom maps.
    paths.update(root/p for p in (
        'tools/plan_v2_arcade_clock.py','tools/publish_v2_arcade_clock.py',
        'art/blender/arcade_fabric_candidate/build_arcade_clock.py',
        'art/blender/arcade_clock.blend', 'game/tests/arcade_clock_bench.gd',
        'game/tests/ArcadeClockBench.tscn'))
    paths.update(root/p for p in (
        'tools/plan_v2_arcade_lantern.py','tools/publish_v2_arcade_lantern.py',
        'art/blender/arcade_fabric_candidate/build_arcade_lantern.py',
        'art/blender/arcade_lantern.blend'))
    paths.update(root/p for p in (
        'art/blender/arcade_fabric_candidate/build_arcade_canopy.py',
        'art/blender/arcade_fabric_candidate/build_arcade_throat.py',
        'art/blender/arcade_throat.blend', 'art/blender/arcade_throat_construction.json',
        'art/blender/arcade_canopy.blend',
        'art/reviews/v2_arcade_install_20261018/canopy/arcade_canopy.blend',
        'art/reviews/v2_arcade_install_20261018/canopy/canopy_plan.json',
        'tools/plan_v2_arcade_canopy.py', 'tools/publish_v2_arcade_canopy.py',
        'art/tools/build_arcade_terrazzo.py', 'art/tools/build_arcade_masonry.py',
        'art/tools/publish_arcade_materials.py',
        'game/tests/v2_arcade_fabric_review.gd', 'game/tests/arcade_fabric_bench.gd',
        'game/tests/v2_furnishing_clearance_review.gd'))
    for name in ('arcade_fine_terrazzo_20261018.png','arcade_dark_terrazzo_20261018.png',
                 'arcade_terrazzo_20261018.json','arcade_brick_face_20261018.png',
                 'arcade_brick_face_20261018.json'):
        paths.add(root/'art/textures/ai_sources'/name)
    for key in ('arcade_terrazzo','arcade_terrazzo_dark','arcade_brick_face','arcade_brick_bond','arcade_lime_mortar'):
        for filename in ('material.json','albedo.png','normal.png','roughness.png','height.png'):
            paths.add(root/f'art/textures/procedural/{key}/{filename}')
    paths.update(root/p for p in ('art/blender/annunciator_controls.blend',
        'art/tools/build_bakelite.py','art/textures/procedural/bakelite/material.json',
        'art/tools/build_radiator_service_brass.py','art/textures/procedural/radiator_service_brass/material.json'))
    for key in ('bath_wall_tile','bath_floor_tile'):
        paths.add(root/f'art/textures/procedural/{key}/material.json')
    for name in ('v2_bathroom_tile_review.gd','v2_millwork_weather_review.gd','v2_millwork_weather_test.gd','v2_window_treatments_review.gd','v2_window_treatments_test.gd','v2_watch_stations_review.gd','orison_v2_patrol_stations_test.gd','v2_mail_bank_review.gd','v2_fire_service_review.gd','v2_electrical_service_review.gd','v2_electrical_connections_review.gd','orison_v2_domestic_objects_test.gd','orison_v2_domestic_native_test.gd','orison_v2_service_instruments_test.gd'):
        paths.add(root/'game/tests'/name)
    paths.update(root/'game/tests'/name for name in ('orison_v2_front_facade_test.gd','v2_kitchen_sink_review.gd','orison_v2_domestic_storage_test.gd','orison_v2_domestic_seating_test.gd','orison_v2_bedding_test.gd','watch_station_hand_test.gd','v2_millwork_culling_review.gd','millwork_unculled_reference.gd'))
    paths.update(root/'game/tests'/name for name in ('v2_street_optics_probe.gd','v2_street_uv_bench.gd','orison_v2_bodega_frontage_test.gd','orison_v2_signage_test.gd','v2_glazing_optical_probe.gd'))
    # Texture source bindings and selective UV precision settings are authored
    # inputs. Cache destinations, generated UIDs, and line endings are not.
    imports=list((root/'game/assets/building/textures').glob('*.png.import'))
    imports.extend((root/'game/assets/environment/weather').glob('*.png.import'))
    sys.path.insert(0,str(root/'art/tools'))
    from fix_v2_mesh_imports import ASSETS as UV_IMPORTS
    imports.extend(root/'game/assets'/(asset+'.import') for asset in UV_IMPORTS)
    imports.extend(p for p in (root/'game/assets/characters/mina_vale').glob('*.png.import') if p.relative_to(root).as_posix() in versioned)
    imports.extend(p for p in (root/'game/assets/ui/telegram').glob('*.png.import') if p.relative_to(root).as_posix() in versioned)
    paths.update(test_dependency_paths(root,paths))
    manifest=sorted([p.relative_to(root).as_posix(),file_hash(p)] for p in paths)
    for path in sorted(imports):
        text=path.read_text(encoding='utf-8').replace('\r\n','\n')
        if '[params]' not in text:raise ValueError('import has no parameters: '+str(path))
        manifest.append([path.relative_to(root).as_posix(),hashlib.sha256(text.split('[params]',1)[1].strip().encode()).hexdigest()])
    manifest.sort()
    return {'algorithm':'sha256/LF-normalized-text-and-import-parameters/v1','files':len(manifest),
            'sha256':hashlib.sha256(json.dumps(manifest,separators=(',',':')).encode()).hexdigest()}

def suite_run_defects(packet,contract,root):
    """Corroborate the test-written contract; never promote a wrapper alone."""
    run=json.loads((packet/'suite_run.receipt.json').read_text())
    defects=[]
    if (run.get('schema')!='orison.run-receipt.v1' or run.get('schema_version')!=1
            or run.get('evidence_kind')!='suite_run'
            or run.get('scene')!='res://tests/OrisonV2SurfaceInventory.tscn'
            or not run.get('windowed')):
        defects.append('invalid surface suite-run identity')
    execution=run.get('execution',{})
    if not execution.get('completed') or execution.get('exit_code')!=0 or execution.get('timed_out'):
        defects.append('surface suite run did not complete successfully')
    source=contract.get('source',{})
    expected='game/tests/orison_v2_surface_inventory.gd'
    if source.get('test_path')!=expected or source.get('test_sha256')!=file_hash(root/expected):
        defects.append('runtime contract does not bind the current surface test')
    for field in ('test_path','test_sha256','runtime_inputs_sha256'):
        if not source.get(field) or run.get('source',{}).get(field)!=source[field]:
            defects.append('suite/contract source mismatch: '+field)
    log=run.get('log',{})
    if log.get('script_error_count',1)!=0 or log.get('fail_count',1)!=0:
        defects.append('surface suite reported script errors or failed checks')
    for channel in ('stdout','stderr'):
        raw=gzip.decompress((packet/('suite_run.'+channel+'.log.gz')).read_bytes())
        if hashlib.sha256(raw).hexdigest()!=log.get(channel+'_sha256'):
            defects.append('suite log changed: '+channel)
        if any(line.lstrip().startswith(('ERROR:','SCRIPT ERROR:'))
               for line in raw.decode('utf-8','replace').splitlines()):
            defects.append('Godot errors in surface '+channel)
    return defects


def qualify(packet=PACKET,root=ROOT):
    defects=[]
    try:
        receipt=json.loads((packet/'runtime_contract.json').read_text())
        defects.extend(suite_run_defects(packet,receipt,root))
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
