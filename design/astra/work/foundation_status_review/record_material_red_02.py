"""Record completed material failures and scoped equivalence; never promote tiers."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[4]
PACKET = ROOT / 'design/astra'


def read(rel):
    return json.loads((PACKET / rel).read_text(encoding='utf-8'))


def sha(rel):
    return hashlib.sha256((PACKET / rel).read_bytes()).hexdigest()


def write(rel, value):
    (PACKET / rel).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


bindings = {
    'evidence/composed_material_ownership/typed_baseline_review_02.json': 'e6f2c6559c54e997125b8b8b93f0f897f26e4bc3abac31ef8231ccbb207cf8de',
    'evidence/composed_material_ownership/typed_baseline_additive_signed_ids_02.json': 'da9af865effe036669da03c483899d0ce3388cd5750f69f3329cba5ea9fddc27',
    'evidence/encroachment_sweep/equivalence_runtime/ownership_7c54c_01/aggregate.json': '5d1fce454d80018d9e4aa072de7bf9f02b276879277bc5e6fad9f24865810b11',
    'reviews/material_full02_binding_review.json': '8d71671218bc1d97b1cdee720a5ceec3e1fd2a76e67124151cc5b7119d6c63d4',
}
assert all(sha(path) == expected for path, expected in bindings.items())
review = read(next(iter(bindings)))
assert (review['checks'], review['passed'], review['native_exit']) == (314, 306, 1)
assert len(review['failed_checks']) == 8 and review['original_renderer_checks_passed'] == 305
decisions = (PACKET / 'DECISION_LOG.md').read_text(encoding='utf-8')
assert 'ASTRA-D031' not in decisions, 'One-time record; do not overwrite history.'
changed = ['DECISION_LOG.md', 'reviews/production_obligations.json', 'PLAYTEST_FINDINGS.md',
           'RISK_REGISTER.md', 'RELEASE_EVIDENCE_MATRIX.md']
before = {path: sha(path) for path in changed}

rows = read('reviews/production_obligations.json')
perf = next(row for row in rows if row['id'] == 'ASTRA-PERF')
assert perf['status'] == 'PROGRAMMED' and perf['severity'] == 'BLOCKER'
perf['current_state'] = (
    'Actual ownership7c54c full02 completes306/314, native/gate1: eight material observations fail; '
    'all305 original renderer checks and new material retirement pass. Unique registries have no '
    'duplicate/invalid slots, but adjacent-floor wardrobe claims leave stale rows or wrong fields. '
    'Floor-identity admission repair and stronger observer are pending composed proof. One-census '
    'equivalence against7c54c passes171/171 candidate/restored with independent14/16-check reds; '
    'the optimizer remains unapplied and must be rebased to any new ownership source.')
perf['next_decisive_action'] = (
    'Prove the floor-identity repair using actual wardrobe producers, then the full building with '
    'complete lifecycle snapshot/restoration. Rebase and rerun one-census equivalence against that '
    'owner before a matched composed cost comparison. Complete private-viewport omission/restoration, '
    'applicable V2 and final uninstrumented runs; preserve Harukiya historical red.')
perf['open_defects'][:2] = [
    'Latest completed ownership7c54c full02 still stalls: Street-to-Passage1375.2615ms, reverse1370.949ms '
    '(six each). Earlier approximately610ms and instrumented523ms callback results bind older sources; '
    'the changed observer/composition prevents isolated attribution.',
    'Duplicate registry growth is absent in all eight full02 observations, but installed identity '
    'fails on adjacent-floor wardrobe leaves. Focused36 does not clear actual-build ownership. '
    'New floor admission candidate is under focused proof; full composition remains required.',
]
perf['performance']['measured_result'] += (
    ' Later failed ownership7c54c/full02 with typed material observerc2642de6: Street-to-Passage '
    'median1375.2615ms and reverse1370.949ms, n6 each. Material probes sit outside apply timers but '
    'change run context; this is neither an isolated dedup delta nor performance acceptance.')
perf['provenance']['sources'] = list(dict.fromkeys(perf['provenance']['sources'] + list(bindings)))
write('reviews/production_obligations.json', rows)

(PACKET / 'DECISION_LOG.md').write_text(decisions + '\n- ASTRA-D031: preserve both actual material '
    'attempts: the first has eight fixture parse errors and timeout124; typed full02 completes306/314 '
    'with eight ownership failures, native/gate1. Correcting signed ObjectID parsing removes7691 false '
    'classifier reasons while retaining all101 genuine reasons. The actual adjacent-floor wardrobe '
    'defect requires floor-identity admission proof and renewed composition. Preserve the earlier '
    '171/171 one-census equivalence and14/16 selective reds as7c54c-only proof; the optimization '
    'remains unapplied and needs rebasing after ownership repair. No acceptance tier changes.\n',
    encoding='utf-8', newline='\n')

updates = {
    'PLAYTEST_FINDINGS.md': {
        '- TRANSITION-STALL-CURRENT:': '- TRANSITION-STALL-CURRENT: latest completed ownership7c54c full02 '
        'measures Street-to-Passage1375.2615ms and reverse1370.949ms (six each). Earlier approximately610ms '
        'and the523.691ms phase attribution bind older sources. The changed observer/composition prevents '
        'isolated dedup attribution. Final uninstrumented correction and frame-budget acceptance remain open.',
        '- MATERIAL-REGISTRATION-GROWTH:': '- MATERIAL-REGISTRATION-GROWTH: historical duplicate growth '
        'is preserved by the43-observation phase census. In ownership7c54c full02 all eight registries '
        'are unique with zero invalid entries; nevertheless wrong-floor wardrobe claims leave stale '
        'row materials or mismatched installed fields. Focused36 is valid for its smaller scope. '
        'Floor admission and complete-building identity remain the active repair.',
    },
    'RISK_REGISTER.md': {
        'Current measured additions:': 'Current measured additions: ownership7c54c full02 has eight '
        'actual material failures and approximately1.375-second Street/Passage transitions. The earlier '
        '523ms callback profile and approximately610ms baseline remain source-bound history. Duplicate '
        'registration is absent in full02, but adjacent-floor wardrobe claims break current material '
        'ownership. Floor admission proof, renewed composed validation and matched optimization remain open.',
    },
    'RELEASE_EVIDENCE_MATRIX.md': {
        '| CPU/GPU/physics/streaming |': '| CPU/GPU/physics/streaming | renderer_foundations_checkpoint.json, '
        'visibility_phase_census_summary.json and composed_material_ownership/typed_baseline_review_02.json '
        '| Partial renderer controls clear pairing diagnostics. Latest full02 has eight ownership failures '
        'and approximately1.375-second transitions; older approximately610ms/523ms results retain their '
        'source limits | Repair floor ownership and remeasure; full target-machine p95, warm/cold and '
        'two-cycle ownership remain open |',
    },
}
for rel, replacements in updates.items():
    lines = (PACKET / rel).read_text(encoding='utf-8').splitlines()
    for prefix, replacement in replacements.items():
        matched = [i for i, line in enumerate(lines) if line.startswith(prefix)]
        assert len(matched) == 1, (rel, prefix)
        lines[matched[0]] = replacement
    (PACKET / rel).write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
findings = PACKET / 'PLAYTEST_FINDINGS.md'
findings.write_text(findings.read_text(encoding='utf-8') + '\n- MATERIAL-ACTUAL-FULL02: all18 images '
    'were inspected; wardrobe membership is established by actual draw/row IDs, not the fixed cameras. '
    'Raw refresh probes fail propagation but restore their recorded force, facts, intensity and sampled '
    'case states. Their lifecycle snapshot omitted non-case registry materials, and comparisons '
    'short-circuited after failure; a stronger observer must prove complete restoration and count '
    'evaluated comparisons independently. Harukiya darkness, rough apparatus and striped reflection '
    'remain presentation debt. No visual or human acceptance follows from the305 renderer checks.\n',
    encoding='utf-8', newline='\n')
write('evidence/material_red_status_02.json', {
    'status': 'COMPLETED_RED_AND_SCOPED_EQUIVALENCE_RECORDED_NO_TIER_CHANGE',
    'evidence_bindings': bindings, 'before': before,
    'after': {path: sha(path) for path in changed},
    'source_or_raw_evidence_mutated': False, 'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
})
print('Recorded actual material red and source-scoped equivalence; no tier, source or raw-evidence change.')
