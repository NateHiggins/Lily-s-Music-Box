"""Preservation, regeneration, geometry controls, category replay and syntax.

No Godot execution. Engine assertions are only prepared source at this stage.
"""
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path
import build as batch

ROOT, OUT = batch.ROOT, batch.OUT
BASE = 'd7f9f8e'


def main():
    protected = ['game/data/building_layout.json', 'game/data/orison_v2_blockout.json',
                 'game/data/prop_catalog.json', 'game/data/acoustic_graph.json',
                 'game/data/runtime_material_sets.json',
                 'game/scripts/props/toaster_prop.gd', 'game/scripts/props/medicine_cabinet_prop.gd',
                 'game/scripts/props/functional_prop.gd', 'game/scripts/player/player_controller.gd',
                 'game/scripts/building/building_root_selector.gd']
    protected += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/data/orison_v2').glob('*.json')
                  if p.relative_to(ROOT).as_posix() != batch.TARGET]
    for path in protected:
        prior = subprocess.check_output(['git', 'show', BASE+':'+path], cwd=ROOT)
        assert (ROOT/path).read_bytes().replace(b'\r\n', b'\n') == prior.replace(b'\r\n', b'\n'), ('protected source changed', path)
    source = batch.load(batch.TARGET)
    assert source == batch.manifest()
    failures = []
    for name, index, axis, value in [('floating_toaster', 0, 1, .95), ('unsupported_toaster', 0, 0, .5),
                                      ('cabinet_inside_wall', 1, 2, .30)]:
        bad = copy.deepcopy(source)
        bad['accessories'][index]['position'][axis] = value
        try:
            batch.geometry(bad)
        except AssertionError as error:
            failures.append(dict(control=name, rejected=str(error)))
        else:
            raise AssertionError('negative control accepted: '+name)
    before = (ROOT/batch.TARGET).read_bytes()
    runs = []
    for _ in range(2):
        result = subprocess.run([sys.executable, str(OUT/'build.py'), '--apply'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8')
        assert result.returncode == 0, result.stdout+result.stderr
        assert before == (ROOT/batch.TARGET).read_bytes(), 'non-deterministic generation'
        runs.append(hashlib.sha256((ROOT/batch.TARGET).read_bytes()).hexdigest())
    # Each replay is the current category's source checker, not its historical
    # fixed-count validator. Output stays bounded and exact exits are retained.
    categories = [
        ('v2_apartment_batches_01','build.py'), ('v2_apartment_seating_batch_01','build.py'),
        ('v2_apartment_lighting_batch_01','build.py'), ('v2_apartment_doors_batch_01','check.py'),
        ('v2_apartment_walls_batch_01','build.py'), ('v2_surface_props_batch_01','build.py'),
        ('v2_storage_tables_boards_batch_01','build.py'), ('v2_household_radios_batch_01','build.py'),
        ('v2_prep_cabinets_batch_01','build.py'), ('v2_specialist_devices_batch_01','build.py'),
        ('v2_projectors_batch_01','build.py'), ('v2_household_completion_01','build.py'),
        ('v2_heating_batch_01','build.py')]
    results = []
    for folder, script in categories:
        path = 'design/astra/work/'+folder+'/'+script
        run = subprocess.run([sys.executable, path], cwd=ROOT, capture_output=True, text=True, encoding='utf-8')
        results.append(dict(path=path, exit=run.returncode, stdout=run.stdout, stderr=run.stderr))
        print(folder, run.returncode, flush=True)
    (OUT/'category_checks.json').write_text(json.dumps(results, indent=2)+'\n', encoding='utf-8')
    assert all(r['exit'] == 0 for r in results), 'category replay failed'
    sys.path.insert(0, 'C:/Users/nate_/AppData/Local/Temp/astra-gdscript-parser')
    from gdtoolkit.parser import parser
    scripts = ['orison_v2_household_accessories.gd', 'orison_v2_toaster.gd',
               'orison_v2_medicine_cabinet.gd', 'orison_v2_runtime_root.gd', 'planar_mirror_renderer.gd']
    paths = ['game/scripts/building/'+s for s in scripts]+['game/tests/orison_v2_apartment_batch_test.gd']
    for path in paths:
        parser.parse((ROOT/path).read_text(encoding='utf-8'))
    (OUT/'syntax_checks.json').write_text(json.dumps(dict(status='SYNTAX_ONLY_NOT_GODOT_COMPILATION', paths=paths), indent=2)+'\n', encoding='utf-8')
    inventory = batch.load('design/astra/work/v2_household_completion_01/current_inventory.json')
    for unit in inventory['units']:
        unit['accessories'] = [r['id'] for r in source['accessories'] if r['unit'] == unit['unit']]
    inventory['batch'] = 'v2_household_accessories_01'
    inventory['totals'].update(toasters=6, medicine_cabinets=6, installed_radiators=6)
    (OUT/'current_inventory.json').write_text(json.dumps(inventory, indent=2)+'\n', encoding='utf-8')
    report = dict(status='SOURCE_PASS_RUNTIME_PENDING', godot='NOT_RUN', base=BASE,
                  protected_files=len(protected), negative_controls=failures, regeneration_sha256=runs,
                  category_checks=len(results), syntax_parses=len(paths),
                  pending='Engine compilation, production rays/cycles, single reflection behavior, audio/acoustic restore, disposal, actual traversal, materials/voxel shadows and performance.')
    (OUT/'source_validation.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
