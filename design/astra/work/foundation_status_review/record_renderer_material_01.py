"""Record completed renderer/material evidence without promoting release tiers."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[4]
PACKET = ROOT / 'design/astra'


def read(path):
    return json.loads((PACKET / path).read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256((PACKET / path).read_bytes()).hexdigest()


def write(path, value):
    (PACKET / path).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


def replace_line(path, prefix, replacement):
    file = PACKET / path
    lines = file.read_text(encoding='utf-8').splitlines()
    found = [i for i, line in enumerate(lines) if line.startswith(prefix)]
    assert len(found) == 1, (path, prefix, found)
    lines[found[0]] = replacement
    file.write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')


def replace_bullet(path, label, replacement):
    file = PACKET / path
    content = file.read_text(encoding='utf-8')
    pattern = re.compile(r'^- ' + re.escape(label) + r':[^\n]*(?:\n[ \t]+[^\n]*)*', re.M)
    assert len(pattern.findall(content)) == 1, label
    file.write_text(pattern.sub(lambda _: '- ' + label + ': ' + replacement, content), encoding='utf-8', newline='\n')


bindings = {
    'evidence/vulkan_composed/runs/material_one_census_v1_full_01/result.json': 'ad119d32fa1c0b48de3dd567921356d2af821dd79ca64a6d137ac5adca0d8496',
    'evidence/composed_material_ownership/material_one_census_v1_full_01_additive_v2.json': '1a20117f82c9e1dc55fd3bd9158d66e3fd134e6faede9c1fc69233ec19663802',
    'reviews/one_census_matched_execution_review.json': 'bfaf35b5fabac0fc659a6b8c8badf81a1f59eee23e950be52e75e33a1887faf2',
    'evidence/vulkan_composed/runs/candidate_v1_material_final_01/result.json': '94babcd295c78c1212b8eaddb5aef55aa4f7e54f86606ee5ebbc8a1e04b89f9d',
    'reviews/final_v1_material_execution_review.json': '27e6f1f6b21a637c3400656c16a39742cd914845aafcc80ebad6d1c899c05d3c',
    'evidence/encroachment_sweep/equivalence_runtime/ownership_2a440_01/aggregate.json': '773d942b756327ddfd764bdb414240b32b08edfcb4720797f1e8ca0c9748e270',
    'evidence/vulkan_composed/viewport_guard_sequences/viewport_guard_final_01/validation.json': '0dc82668a4c9a033798f71bfd9d60de0db3afa408646a00b50af576448978ef1',
}
assert all(sha(path) == digest for path, digest in bindings.items())
for name, count in [('material_one_census_v1_full_01', 314), ('candidate_v1_material_final_01', 305), ('candidate_v2_foundations_01', 14)]:
    prefix = 'evidence/vulkan_composed/runs/' + name
    result, probe = read(prefix + '/result.json'), read(prefix + '/frames/probe.json')
    assert result['actual_engine_exit'] == result['gate']['diagnostic_gate_exit'] == 0
    assert len(probe['checks']) == count and all(row['passed'] is True for row in probe['checks'])
decisions = PACKET / 'DECISION_LOG.md'
assert 'ASTRA-D033' not in decisions.read_text(encoding='utf-8')
rows = read('reviews/production_obligations.json')
perf = next(row for row in rows if row['id'] == 'ASTRA-PERF')
assert perf['status'] == 'PROGRAMMED'
perf['current_state'] = ('Owner1a1b067f retains correct authored-floor admission and exact installed registries in all eight actual V1 observations; '
    '314/314 and native/base/additive gates0. Rebasing one-census passes171/171 with14/16 selective reds and exact restoration; '
    'actual wardrobe regression63/63. Final base V1 passes305/305 with actual retirement and no pairing/retention errors. '
    'The private-viewport omission fails39 arcade checks and exact restoration passes305. V2 structural/render/retirement14 passes, '
    'but its bedside camera sees a wall instead of a readable terminal. The current production candidates await their named checkpoint.')
perf['automated_proof'] = ('Historical operation omission emits1174 unpair and2316 underflow diagnostics; exact restoration296/296 removes both. '
    'Guard-only viewport omission266/305 has39 intended arcade reds; restored305/305. Material36, wardrobe63 and rebased equivalence171 '
    'regressions pass with retained selective reds and source-bound restoration. Failed parse/ownership attempts remain preserved.')
perf['composed_runtime_proof'] = ('Final current owner1a/cde44/base5ec:305/305,18 PNGs directly reviewed,36 main-loop transitions, actual shell/world retirement, '
    'native/gate0. Separate d67 instrumented run314/314 restores every recorded registry lifecycle target and retires case resources. '
    'V2 base14/14 releases both roots, with2 directly reviewed but unreadable terminal views. Retained loader/RGB8/found-art warnings; no human or release acceptance.')
perf['next_decisive_action'] = ('Land the reviewed foundation sources and evidence. Correct the V2 viewing fixture using the existing authored operator stance, '
    'then reconstruct attributable clean C1 ownership exports/provider for the actual V2 world. Continue content-equivalent residency/frame-budget work; '
    'do not treat sparse V2 or adaptive-quality deltas as release performance.')
perf['open_defects'] = [
    'Final base V1 Street-to-Passage1195.793ms and reverse1182.595ms medians (n6 each) remain visible stalls; main-loop quality budget varies from1.0 to0.0.',
    'Sole-source-change two-run medians fall1385.249 to1188.5935ms and1377.8 to1179.5735ms, but adaptive governor and some population rows differ; no isolated fixed-workload speedup claim.',
    'No ordinary production carry path for case-tagged household props was found; future/debug Vantry relocation and transported-residue policy remain separately unspecified, not an established ordinary-play defect.',
    'V2 bedside-to-terminal capture is occluded by the private hall; its14 structural checks do not establish terminal readability or player interaction.',
    'Current renderer/material source checkpoint is pending; no-op native-call count remains explicitly unproved.',
    'Harukiya >250 remains red despite247/247 measured indexing and36 source-eligible groups; historical264 discrepancy unresolved.',
    'Full-game steady frame pacing, equal-quality workloads, target-machine performance and long-running ownership growth remain unproved.',
    'Inherited loader diagnostics, RGB8 conversions and found-art placement warnings remain; dark venues, reflection bands and coarse apparatus need production art and human/listening review.',
]
perf['performance']['measured_result'] += (' Final matched one-census1a/d67:1188.5935/1179.5735ms(n6), observed -14.20/-14.39 percent. '
    'Only owner source differs, but baseline budgets1.0x124/0.75x20 versus candidate1.0x113/0.75x25/0.5x6 and25/43 equal population rows prevent isolated speedup acceptance. '
    'Final base1a/5ec:1195.793/1182.595ms(n6), with adaptive budgets1.0 through0.0; these are visibility-call durations, not frame p95. V2 startup report1008.039ms/whole fixture6.209s is sparse-root context only.')
perf['provenance']['sources'] = list(dict.fromkeys(perf['provenance']['sources'] + list(bindings) + [
    'reviews/one_census_matched_execution_review.md', 'reviews/final_v1_material_execution_review.md',
    'reviews/material_one_census_visual_review.md', 'reviews/carry_reparent_policy_review.md',
    'reviews/viewport_guard_final_01_review.md',
    'evidence/vulkan_composed/v2_candidate_reviews/candidate_v2_foundations_01/validation.json']))
write('reviews/production_obligations.json', rows)
replace_bullet('PLAYTEST_FINDINGS.md', 'TRANSITION-STALL-CURRENT', perf['open_defects'][0] + ' ' + perf['open_defects'][1])
replace_bullet('PLAYTEST_FINDINGS.md', 'MATERIAL-REGISTRATION-GROWTH',
    'Historical duplicate growth and wrong-floor wardrobe failures remain preserved. Corrected floor admission plus one-census1a passes all eight actual ownership observations and complete lifecycle restoration. Focused36/63/171 regressions and selective reds bind their exact sources. Actual instrumented314 and final base305 pass; no whole-game performance acceptance.')
replace_bullet('PLAYTEST_FINDINGS.md', 'ARCADE-WORLD-BOUNDARY',
    'The current ancestry guard keeps actual cabinet SubViewport worlds out of building late indexing. Guard-only omission fails39 arcade checks with6369 repeated live-mask corruption observations, not unique geometry. Exact restoration305/305 and final material1a/base305/305 pass. Cabinet screenshots do not depict every corrupted instant; runtime observations supply the transition witness.')
findings = PACKET / 'PLAYTEST_FINDINGS.md'
findings.write_text(findings.read_text(encoding='utf-8') + '\n- V2-TERMINAL-VIEW: actual V2 starts/renders/retires14/14, native/gate0. Both directly reviewed bedside-view images show a wall and teal slab, not a readable terminal. Source trace places the line of sight through the private-hall wall; the authored F04_B_MONITOR_STANCE provides a separate operator view to test. No wall removal or visual acceptance follows.\n', encoding='utf-8', newline='\n')
replace_line('RISK_REGISTER.md', '| Layer-change control and frame-cost scope |',
    '| Layer-change control and frame-cost scope | RELEASE_CRITICAL | Current final V1 base305/305 and historical operation omission/restoration prove bounded native repair; V2 structural14 passes but terminal view is occluded | Equal-quality content and full target-machine frame budgets; correct V2 inspection and preserve perceptual red |')
replace_line('RISK_REGISTER.md', '| Cabinet-world boundary integration |',
    '| Cabinet-world boundary integration | RELEASE_CRITICAL | Guard-only omission has39 arcade failures; exact restoration305/305 and final owner1a/base305/305 pass with actual world retirement | Preserve per-viewport ownership and lifecycle; no capture-time corruption or full-game acceptance extrapolation |')
replace_line('RISK_REGISTER.md', 'Current measured additions:',
    'Current measured additions: floor admission and one-census1a pass314/314 actual material checks with complete lifecycle restoration; final base V1 passes305/305. The observed matched two-run delta is about14 percent, qualified by differing adaptive quality/population decisions. Final uninstrumented Street/Passage medians remain1195.793/1182.595ms. Dark venues, striped reflections, coarse apparatus, RGB8 warnings and the failed V2 terminal viewing composition remain open.')
replace_line('RELEASE_EVIDENCE_MATRIX.md', '| CPU/GPU/physics/streaming |',
    '| CPU/GPU/physics/streaming | one_census_matched_execution_review and final_v1_material_execution_review; viewport/V2 receipts | Actual ownership314 and final base305 pass with retirement. Guard-only39 arcade reds restore to305. V2 structural14 passes but its terminal view is unreadable. Final Street/Passage1195.793/1182.595ms; adaptive quality prevents fixed-workload delta acceptance | Correct V2 viewing and actual world content; equal-quality target-machine p95, warm/cold and two-cycle ownership; human review |')
matrix = PACKET / 'RELEASE_EVIDENCE_MATRIX.md'
text = matrix.read_text(encoding='utf-8')
text = text.replace('Private-viewport-only omission, applicable V2 and final\ncomposition after subsequent repairs remain pending.',
    'That earlier pending sequence is now complete for its declared machine scope: private-viewport omission/restoration, applicable V2 structural14 and final owner1a/base V1 composition305. The V2 terminal images fail their perceptual purpose and remain open.')
matrix.write_text(text, encoding='utf-8', newline='\n')
decisions.write_text(decisions.read_text(encoding='utf-8') + '\n- ASTRA-D033: one-census1a passes rebased171 equivalence with14/16 selective reds, actual wardrobe63 and actual instrumented V1 314 with complete lifecycle restoration. All124 comparison artifacts verify; only apartment source differs across4045 inputs. The observed14 percent timing delta has different adaptive budgets/populations and is not isolated speedup acceptance. Final base V1 305 passes with18 reviewed images and approximately1.19-second Street/Passage calls. The separate guard-only39 arcade reds restore to305. V2 structural14 retires cleanly, but two bedside images show intervening walls; correct its viewing fixture using the existing operator anchor without deleting authored geometry. Preserve all failures, warning/art debt and human/release limits; no tier promotion.\n', encoding='utf-8', newline='\n')
write('evidence/renderer_material_status_01.json', {'bindings': bindings, 'decision': 'ASTRA-D033',
    'full_game_complete': False, 'acceptance_promoted': False, 'source_commit_pending': True,
    'metadata_hashes': {path: sha(path) for path in ['reviews/production_obligations.json', 'PLAYTEST_FINDINGS.md', 'RISK_REGISTER.md', 'RELEASE_EVIDENCE_MATRIX.md', 'DECISION_LOG.md']}})
print('Current renderer/material status recorded; no human/release tier promoted.')
