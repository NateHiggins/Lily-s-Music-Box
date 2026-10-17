"""Read-only qualification of this scoped installation and native provenance."""
import hashlib
import gzip
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
PACKET = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT/'tools'))
from audit_orison_v2_completeness import runtime_inputs_sha256
from v2_surface_evidence import inputs as rendering_inputs

IDS = ('F02_D_RADIATOR_01', 'F03_C_RADIATOR_01', 'F05_D_RADIATOR_01', 'F06_D_RADIATOR_01')
def sha(path, lf=False):
    data = path.read_bytes()
    return hashlib.sha256(data.replace(b'\r\n', b'\n') if lf else data).hexdigest()

def qualify():
    errors = []
    receipt = json.loads((PACKET/'installation/runtime_contract.json').read_text())
    wrapper = json.loads((PACKET/'installation.log.receipt.json').read_text())
    runtime = runtime_inputs_sha256(ROOT)
    for name, data in [('test', receipt), ('wrapper', wrapper)]:
        execution = data.get('execution', {})
        if execution.get('completed') is not True or execution.get('timed_out') is not False or type(execution.get('exit_code')) is not int or execution['exit_code'] != 0:
            errors.append(name+' did not complete successfully')
        if data.get('source', {}).get('runtime_inputs_sha256') != runtime:
            errors.append(name+' runtime binding is stale')
    if receipt.get('schema_version') != 2 or receipt.get('evidence_kind') != 'runtime_contract' or receipt.get('production_runtime') is not True or receipt.get('selector') != 'v2':
        errors.append('production V2 schema-2 contract required')
    expected_sources = {'game/tests/'+name for name in ('heating_refit_installation_test.gd', 'heating_hand_driver.gd', 'watch_station_hand_test.gd')}
    sources = receipt['source'].get('test_sources', {})
    if set(sources) != expected_sources: errors.append('complete executed helper binding required')
    for relative, digest in sources.items():
        if relative not in expected_sources or sha(ROOT/relative, True) != digest: errors.append('stale helper: '+relative)
    relative = 'game/tests/heating_refit_installation_test.gd'
    if receipt['source'].get('test_path') != relative or receipt['source'].get('test_sha256') != sha(ROOT/relative, True) or wrapper['source'].get('test_sha256') != sha(ROOT/relative):
        errors.append('executed test source binding is stale')
    for key in ('production_composition', 'direct_manipulation', 'save_reconstruction'):
        value = receipt.get('contracts', {}).get(key, {})
        if value.get('executed') is not True or value.get('status') != 'PASS': errors.append('unexecuted component: '+key)
    observations = receipt.get('observations', [])
    if receipt.get('checks') != 108 or len(observations) != 108 or receipt.get('failures') or any(row.get('passed') is not True for row in observations):
        errors.append('complete successful installation observations required')
    for identity in IDS:
        for label in ('primary click grabs the installed valve: ', 'mouse movement turns the installed valve: ', 'release retains physical valve position: '):
            if sum(row.get('check') == label+identity and row.get('passed') is True for row in observations) != 3:
                errors.append('three actual physical operations required: '+identity)
    for filename, field in [('installation.log', 'stdout_sha256'), ('installation.log.stderr', 'stderr_sha256')]:
        if sha(PACKET/filename) != wrapper['log'].get(field): errors.append('executed log bytes changed: '+filename)
    if wrapper['log'].get('script_error_count') != 0 or wrapper['log'].get('fail_count') != 0:
        errors.append('wrapper records script errors or failed checks')
    disk = json.loads((PACKET/'installation/disk_save.json').read_text())['v2_household_controls']['records']
    for index, identity in enumerate(IDS):
        if abs(float(disk.get(identity, {}).get('value', -1))-(.25+index*.15)) >= .01:
            errors.append('partial valve disk value missing: '+identity)
    fixture = json.loads((ROOT/'game/tests/fixtures/orison_heating_distribution.json').read_text())
    export = json.loads((PACKET/'export_review.json').read_text())
    package = json.loads((PACKET/'native_packaging.json').read_text())
    build = json.loads((PACKET/'build_review.json').read_text())
    if fixture['asset_sha256'] != sha(ROOT/'game/assets/props/heating_distribution.glb') or fixture['asset_sha256'] != export['asset_sha256']:
        errors.append('native exported asset changed')
    if fixture['native_sha256'] != sha(ROOT/'art/blender/heating_distribution.blend') or fixture['native_sha256'] != package['native_sha256']:
        errors.append('packaged native source changed')
    if package['failures'] or package['source_sha256'] != export['native_sha256'] or package['geometry_sha256_before'] != package['geometry_sha256_after']:
        errors.append('portable native packaging lineage failed')
    if build['failures'] or build['asset_sha256'] != export['asset_sha256'] or export['exported_tangents']['status'] != 'PASS':
        errors.append('strict native build/export qualification failed')
    for relative, digest in build['source_bindings'].items():
        if sha(ROOT/relative, Path(relative).suffix != '.blend') != digest:
            errors.append('native authoring binding changed: '+relative)
    try:
        rendering = rendering_inputs(ROOT)['sha256']
        context = json.loads((PACKET/'context/context.json').read_text())
        context_run = json.loads((PACKET/'context.log.receipt.json').read_text())
        diagnostic = json.loads((PACKET/'context_contacts.json').read_text())
        disposition = json.loads((PACKET/'context_review.json').read_text())
        review = json.loads((PACKET/'capture_review.json').read_text())
        execution = context_run.get('execution', {})
        if execution.get('completed') is not True or execution.get('exit_code') != 0 or execution.get('timed_out') is not False or context_run.get('log', {}).get('script_error_count') != 0:
            errors.append('actual context acquisition did not complete cleanly')
        if sha(PACKET/'context.log') != context_run['log']['stdout_sha256'] or sha(PACKET/'context.log.stderr') != context_run['log']['stderr_sha256']:
            errors.append('context acquisition logs changed')
        if context_run['source'].get('test_sha256') != sha(ROOT/'game/tests/heating_retrofit_context_probe.gd'):
            errors.append('executed context probe source changed')
        if context.get('valid') is not True or context.get('runtime_inputs_sha256') != runtime or context.get('rendering_inputs_sha256') != rendering:
            errors.append('acquired geometry/captures describe stale production inputs')
        acquired_hash = hashlib.sha256()
        with gzip.open(PACKET/'context/context.glb.gz','rb') as acquired:
            for block in iter(lambda: acquired.read(1024*1024), b''): acquired_hash.update(block)
        if acquired_hash.hexdigest() != context['context_sha256']:
            errors.append('archived acquired geometry bytes changed')
        if diagnostic.get('context_is_current') is not True or diagnostic.get('context_sha256') != context['context_sha256'] or diagnostic.get('current_runtime_inputs_sha256') != runtime or diagnostic.get('current_rendering_inputs_sha256') != rendering:
            errors.append('native/world intersection diagnostic is stale')
        if diagnostic.get('native_sha256') != fixture['native_sha256'] or diagnostic.get('reviewer_sha256_lf') != sha(ROOT/'tools/review_v2_heating_mesh_contacts.py', True):
            errors.append('native/world diagnostic source or native assembly changed')
        if disposition.get('diagnostic_sha256') != sha(PACKET/'context_contacts.json') or disposition.get('reviewer_sha256_lf') != sha(ROOT/'tools/review_v2_heating_contacts.py', True):
            errors.append('contact disposition source/binding changed')
        if disposition.get('contact_review_status') != 'REVIEW_CLEAR' or disposition.get('unexplained') or disposition.get('containments'):
            errors.append('contact review has unresolved findings')
        if review.get('rendering_inputs_sha256') != rendering or review.get('runtime_inputs_sha256') != runtime or review.get('human_acceptance') is not False:
            errors.append('scoped capture review is stale or overclaims acceptance')
        expected = {'context/'+identity+suffix+'.png' for identity in IDS for suffix in ('_body','_supply','_shaft_exit','_ceiling_entry')}
        if len(review.get('images', [])) != 16 or {row['file'] for row in review['images']} != expected:
            errors.append('all sixteen inspected current context views required')
        coverage = json.loads((PACKET/'context_coverage.json').read_text())
        if context.get('route_sha256') != sha(PACKET/'context_coverage.json'):
            errors.append('acquired route coverage changed')
        branches = coverage.get('branches', [])
        if len(branches) != 5 or {row.get('id') for row in branches} != set(IDS)|{'REVIEW_MAIN_H_D_EXTENSION'}:
            errors.append('four installed branches and full main extension coverage required')
        authored = json.loads((ROOT/'art/data/orison_v2/heating_refit_authoring.json').read_text())['routes']['branches']
        if any(sum(row == branch for row in branches) != 1 for branch in authored):
            errors.append('acquired installed routes differ from native authoring')
        main = next((row for row in branches if row.get('id') == 'REVIEW_MAIN_H_D_EXTENSION'), {})
        pipe = json.loads((PACKET/'pipe_review.json').read_text())
        if main.get('points_local_godot') != [[8.74, pipe['old_main_end_y'], .59], [8.74, pipe['new_main_end_y'], .59]]:
            errors.append('acquisition does not cover the full changed main height')
        assembly = json.loads((PACKET/'assembly_contacts.json').read_text())
        if assembly.get('native_sha256') != package['source_sha256'] or assembly.get('unexpected') or assembly.get('reviewer_sha256_lf') != sha(ROOT/'tools/review_v2_heating_assembly_contacts.py', True):
            errors.append('native assembly contact diagnostic is stale or has unexpected contacts')
        for row in review.get('images', []):
            if row['file'] not in expected or sha(PACKET/row['file']) != row['sha256'] or not row.get('observation'):
                errors.append('capture changed or was not inspected: '+row['file'])
        for capture in context.get('captures', []):
            path = PACKET/'context'/Path(capture['path']).name
            if capture.get('saved') is not True or sha(path) != capture['sha256']:
                errors.append('raw acquired context image changed: '+path.name)
    except (OSError, KeyError, ValueError, TypeError) as exc:
        errors.append('missing or invalid scoped geometry review: '+str(exc))
    return {'evidence_class': 'INERT', 'status': 'SCOPED_PASS' if not errors else 'FAIL',
            'scope': 'Four-emitter control/save runtime contract, native build provenance and separately source-bound acquired-corridor contact/capture review. Sampled containment only; no walking access, full-surface qualification, whole V2 completion or human acceptance.',
            'runtime_inputs_sha256': runtime, 'checks': receipt.get('checks'), 'errors': errors}

if __name__ == '__main__':
    result = qualify()
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['status'] == 'SCOPED_PASS' else 1)
