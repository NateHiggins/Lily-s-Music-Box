"""Record completed bounded resident proof without promoting ordinary-day status."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[4]
path = ROOT / 'design/astra/reviews/production_obligations.json'
rows = json.loads(path.read_text(encoding='utf-8'))
ambient = next(row for row in rows if row['id'] == 'ASTRA-AGENT-AMBIENT')
assert ambient['status'] == 'PROGRAMMED'
ambient.update({
    'current_state': 'Applied portal-centre and wall-normal approaches, public lift waiting, a public F01 destination and guarded short direct routes. One actual Transient Guests owner completes arrival/dwell/return in three source-bound V1 runs. The shared persistent ordinary-day agent outcome remains incomplete.',
    'automated_proof': 'Direct-route original25/33/native8 and corrected33/33/native0; exact nav-call omission20/21/native1 and old-coordinate omission15/21/native1. Both restore to complete31/31 journeys. Existing waiting40/40 and Passage26/26 pass with assertions unchanged. Earlier fixture errors/timeouts and audit-capsule limits are retained.',
    'composed_runtime_proof': 'Three full31-check actual-V1 runs cover untouched4D home departure, real lift readiness, actual Body-clear public F01 route, reached destination, normal44.274-second dwell draw, expiry, real return readiness and same-home return, then root retirement. One _step per real physics frame; other resident choices/player held and campaign clock frozen. This retains the production layer-zero walk-through actor and hidden lift-rider abstraction. Wrapper/process duration is not a performance or physical player-traversal result. Known host-loader/RGB8/found-art diagnostics remain separately classified.',
    'next_decisive_action': 'Extend one resident to a persistent ordinary day with located perception, venue and prop use, social encounter, interruption and reload; prove the shared framework with a second character from data.',
    'open_defects': [
        'No complete ordinary-day, venue/social, interruption, persistence or human embodiment acceptance',
        'The existing graph fallback is not generally capsule-safe; the new short-leg admission adds no crowd avoidance and physical support is sampled',
        'Production Body remains layer/mask0 and scripted walk-through movement; lift riders are hidden during the real readiness-controlled ride',
        'Earlier waiting/approach audit capsule0.33/1.524/+0.80 is not actual Body0.28/1.55/+0.775 or uniformly conservative; the new direct envelope0.33/1.65/+0.825 has a separate containment proof',
        'Navigation repair awaits its named commit/evidence checkpoint at this update',
    ],
})
ambient['provenance']['sources'] = list(dict.fromkeys(ambient['provenance']['sources'] + [
    'evidence/resident_f01_haunt/nav_validation/nav_direct_03/runs/01_original_focused/result.json',
    'evidence/resident_f01_haunt/nav_validation/nav_direct_03/runs/02_candidate_focused/result.json',
    'evidence/resident_f01_haunt/nav_validation/nav_direct_03/runs/03_candidate_lifecycle/result.json',
]))
perf = next(row for row in rows if row['id'] == 'ASTRA-PERF')
perf['current_state'] = ('Full V1 renderer candidate305/305 and matched bookkeeping omission/restoration remain scoped proof. '
    'The roughly523ms encroachment phase and duplicate registration are established. Ownership repair7c54c passes36/36 '
    'with four independent omission/restoration controls, but actual-build material invariants, composed stability and '
    'uninstrumented cost remain pending. The one-census optimization is still unapplied.')
perf['next_decisive_action'] = ('Validate actual build/material consumers and measure ownership7c54c alone; prove exact '
    'one-census equivalence before considering that optimization, then measure a matched pair. Complete private-viewport '
    'omission/restoration, applicable V2 and final composed runs. Preserve the Harukiya historical failure.')
perf['open_defects'] = [
    item.replace('Registry and material identity repair pending',
                 'Focused ownership repair passes36/36; composed installed identity and registry stability remain pending')
    for item in perf['open_defects']]
perf['provenance']['sources'] = list(dict.fromkeys(perf['provenance']['sources'] + [
    'evidence/apartment_material_binding/validation.json', 'reviews/apartment_material_binding_review.md']))
path.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8', newline='\n')
print('Updated bounded journey/material evidence; broad status remains PROGRAMMED.')
