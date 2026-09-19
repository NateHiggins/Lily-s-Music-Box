"""Separately declared paired-bookkeeping negative evidence; never suppress errors.

The existing gate and strict unpair-only predicate are deliberately unchanged.
Only a complete helper-only omission followed by exact restored clean evidence
can satisfy this contract. Per-run recognition alone is never final acceptance.
"""
from collections import Counter
import hashlib

from variant_case import GUARD, select_variant

CONTRACT = 'astra.vulkan_composed.expected_pair_bookkeeping_red.v1'
BUILDING_ROOT = 'game/scripts/building/building_root.gd'
ENGINE_SOURCE = 'design/astra/evidence/vulkan_layer_pairing/source_review/a13da4feb_servers__rendering__renderer_scene_cull.cpp'
ENGINE_SOURCE_SHA256 = '80f0761682f6df8abe683f843f6fc8fd1fc9a646783298491d597f2634b5e810'
UNPAIR_HEADER = 'ERROR: BUG, indexing did not unpair geometries from light.'
SOFT_HEADER = 'ERROR: geom->softshadow_count==0 - BUG!'
SITES = {
    UNPAIR_HEADER: {
        'at: instance_set_base (servers/rendering/renderer_scene_cull.cpp:616)',
        'at: instance_set_scenario (servers/rendering/renderer_scene_cull.cpp:844)',
    },
    SOFT_HEADER: {'at: _instance_unpair (servers/rendering/renderer_scene_cull.cpp:348)'},
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def native_sites(stdout, stderr):
    """Require each exact native header's immediately following source location."""
    records, invalid = [], []
    for stream, text in [('stdout', stdout), ('stderr', stderr)]:
        lines = text.splitlines()
        for index, line in enumerate(lines):
            header = line.strip()
            if header not in SITES:
                continue
            site = lines[index + 1].strip() if index + 1 < len(lines) else ''
            record = {'stream': stream, 'line': index + 1, 'header': header, 'site': site}
            records.append(record)
            if site not in SITES[header]:
                invalid.append(record)
    counts = Counter(row['header'] for row in records)
    return {'records': records, 'invalid_sites': invalid,
            'unpair': counts[UNPAIR_HEADER], 'soft_shadow': counts[SOFT_HEADER]}


def assess_omission(result, stdout, stderr, probe, candidate, selected,
                    declared_contract, source_review_bound):
    """Return provisional negative evidence; caller must still verify restoration."""
    reasons = []
    gate = result.get('gate', {})
    if declared_contract != CONTRACT:
        reasons.append('separate paired-bookkeeping contract not declared')
    if not source_review_bound:
        reasons.append('retained a13da4feb source hash not bound')
    try:
        exact_transform = selected == select_variant(candidate, 'omission')
    except ValueError:
        exact_transform = False
    if not exact_transform or selected.replace(b'\r\n', b'\n').count(GUARD) != 1:
        reasons.append('not exact helper-only omission retaining current viewport guard')
    if result.get('root') != 'v1' or result.get('variant') != 'omission':
        reasons.append('contract requires actual V1 helper omission')
    if result.get('actual_engine_exit') != 0:
        reasons.append('actual engine did not exit zero')
    if result.get('source_unchanged') is not True:
        reasons.append('runtime source or wrapper not stable')
    for label in ['before', 'after']:
        if result.get(label, {}).get('files', {}).get(BUILDING_ROOT) != sha(selected):
            reasons.append(label + ' source snapshot does not bind exact omission bytes')
    if not probe or probe.get('root') != 'v1' or probe.get('variant') != 'omission' or probe.get('execution_scope') != result.get('execution_scope'):
        reasons.append('actual probe identity does not match declared case')
    checks = (probe or {}).get('checks', [])
    for label in ['actual shell retired', 'actual selected world retired']:
        matches = [c for c in checks if c.get('label') == label]
        if len(matches) != 1 or matches[0].get('passed') is not True:
            reasons.append('actual retirement check missing or failed: ' + label)
    native = native_sites(stdout, stderr)
    if not native['unpair'] or not native['soft_shadow']:
        reasons.append('both exact signatures were not reproduced')
    if native['invalid_sites']:
        reasons.append('native signature has missing or unexpected source site')
    if native['unpair'] != gate.get('unpair_errors') or native['soft_shadow'] != gate.get('soft_shadow_underflows'):
        reasons.append('signature counts differ from strict diagnostic gate')
    headers = gate.get('non_inherited_error_headers', {})
    expected_headers = {UNPAIR_HEADER: native['unpair'], SOFT_HEADER: native['soft_shadow']}
    if headers != expected_headers:
        reasons.append('non-inherited headers are not exclusively both exact native signatures')
    # A misleading indented header must not evade the ordinary header parser.
    stripped_errors = [line.strip() for line in (stdout + '\n' + stderr).splitlines()
                       if line.strip().startswith(('ERROR:', 'SCRIPT ERROR:'))]
    inherited = Counter(row['header'] for row in gate.get('inherited_manifest_errors', []))
    if Counter(stripped_errors) != Counter(expected_headers) + inherited:
        reasons.append('unaccounted diagnostic header')
    allowed_reasons = {
        f"{native['unpair'] + native['soft_shadow']} non-inherited error headers",
        f"{native['unpair']} geometry-light unpair errors",
        f"{native['soft_shadow']} independent soft-shadow underflow errors",
    }
    if set(gate.get('reasons', [])) != allowed_reasons or gate.get('diagnostic_gate_exit') != 1:
        reasons.append('strict gate reports missing completion or unrelated failure')
    if gate.get('retention') or gate.get('functional_checks_meaningful') is not True:
        reasons.append('retention or functional proof is not clean')
    return {'contract': CONTRACT, 'pair_bookkeeping_omission_evidence_complete': not reasons,
            'expected_pair_bookkeeping_red_observed': False,
            'restored_clean_required': True, 'reasons': reasons, 'native_sites': native,
            'diagnostic_gate_exit': 1, 'strict_unpair_only_unchanged': True}


def assess_pair(omission_assessment, omission, restored, restored_probe,
                omission_transaction, restored_transaction, candidate, selected,
                preparation_unchanged):
    """Close only matched omission -> exact restoration -> clean completed run."""
    reasons = list(omission_assessment.get('reasons', []))
    if omission_assessment.get('pair_bookkeeping_omission_evidence_complete') is not True:
        reasons.append('omission evidence incomplete')
    if not preparation_unchanged:
        reasons.append('contract assessor or execution preparation changed during sequence')
    candidate_sha, selected_sha = sha(candidate), sha(selected)
    for label, tx, variant, expected_sha in [
        ('omission', omission_transaction, 'omission', selected_sha),
        ('restored', restored_transaction, 'candidate', candidate_sha),
    ]:
        if (tx.get('root') != 'v1' or tx.get('variant') != variant
                or tx.get('execution_scope') != omission.get('execution_scope')
                or tx.get('candidate_sha256') != candidate_sha
                or tx.get('selected_sha256') != expected_sha
                or tx.get('restored_sha256') != candidate_sha
                or tx.get('candidate_restored_exactly') is not True):
            reasons.append(label + ' transaction does not prove exact restoration')
    gate = restored.get('gate', {})
    if (restored.get('root') != 'v1' or restored.get('variant') != 'candidate'
            or restored.get('execution_scope') != omission.get('execution_scope')
            or restored.get('actual_engine_exit') != 0 or restored.get('source_unchanged') is not True
            or gate.get('diagnostic_gate_exit') != 0 or gate.get('reasons')
            or gate.get('unpair_errors') != 0 or gate.get('soft_shadow_underflows') != 0
            or gate.get('retention') or gate.get('functional_checks_meaningful') is not True):
        reasons.append('restored candidate is not clean in the identical selected scope')
    if not restored_probe or restored_probe.get('root') != 'v1' or restored_probe.get('variant') != 'candidate' or restored_probe.get('execution_scope') != omission.get('execution_scope'):
        reasons.append('restored actual probe identity mismatch')
    for label in ['actual shell retired', 'actual selected world retired']:
        matches = [c for c in (restored_probe or {}).get('checks', []) if c.get('label') == label]
        if len(matches) != 1 or matches[0].get('passed') is not True:
            reasons.append('restored actual retirement missing or failed: ' + label)
    for label in ['before', 'after']:
        old_files = dict(omission.get(label, {}).get('files', {}))
        new_files = dict(restored.get(label, {}).get('files', {}))
        if not old_files or not new_files or old_files.pop(BUILDING_ROOT, None) != selected_sha or new_files.pop(BUILDING_ROOT, None) != candidate_sha or old_files != new_files:
            reasons.append(label + ' source/assets differ beyond the single helper operation')
    engines = omission.get('engines_before')
    if not engines or len(engines) != 2 or any(row != engines for row in [omission.get('engines_after'), restored.get('engines_before'), restored.get('engines_after')]):
        reasons.append('installed launcher/engine binding differs across pair')
    if not omission.get('wrapper_inputs') or omission.get('wrapper_inputs') != restored.get('wrapper_inputs'):
        reasons.append('runner or strict gate binding differs across pair')
    if not omission.get('started_at_utc') or not restored.get('started_at_utc') or restored['started_at_utc'] <= omission['started_at_utc']:
        reasons.append('restored run did not follow omission')
    return {'contract': CONTRACT, 'expected_pair_bookkeeping_red_observed': not reasons,
            'reasons': reasons, 'diagnostic_gate_exit': 1, 'candidate_clearance': False,
            'scope': omission.get('execution_scope'),
            'limits': 'Observed source-only negative control in the completed selected scope; no broad-cause, performance, separate-world (when excluded), or human acceptance claim.'}
