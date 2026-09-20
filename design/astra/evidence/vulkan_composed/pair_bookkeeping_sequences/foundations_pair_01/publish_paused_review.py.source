"""Retain pure-Python controls and already-inspected failed-run evidence; no Godot."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from summarize_cost import summarize

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
EVIDENCE = ROOT / 'design/astra/evidence/vulkan_composed'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
dump = lambda p, data: p.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


def main():
    controls = EVIDENCE / 'viewport_boundary_repair/parser_controls'
    controls.mkdir(exist_ok=False)
    files = ['gate.py', 'test_gate.py', 'variant_case.py', 'test_variant_case.py', 'run_case.py']
    before = {name: sha(BASE / name) for name in files}
    for name in files: shutil.copyfile(BASE / name, controls / (name + '.source'))
    started = time.perf_counter()
    result = subprocess.run([sys.executable, '-m', 'unittest', 'test_gate', 'test_variant_case', '-v'], cwd=BASE, capture_output=True)
    elapsed = time.perf_counter() - started
    (controls / 'stdout.log').write_bytes(result.stdout)
    (controls / 'stderr.log').write_bytes(result.stderr)
    dump(controls / 'receipt.json', {'actual_exit': result.returncode, 'elapsed_seconds': elapsed,
        'command': [sys.executable, '-m', 'unittest', 'test_gate', 'test_variant_case', '-v'],
        'sources': before, 'sources_unchanged': before == {name: sha(BASE / name) for name in files},
        'scope': '25 synthetic parser/source-transform controls only. No engine, render or GDScript compile claim.'})
    assert result.returncode == 0
    controls_exit = result.returncode
    notes = {
        'initial_street': ('REFINE', 'Facade and street remain visible, but the central utility structure/pole obscures much of the scene; dark image and carried device limit inspection.'),
        'initial_passage': ('SALVAGEABLE', 'Continuous hall, glazed roof, shop grilles and signs are legible. Carried device obscures lower-right architecture.'),
        'initial_orison': ('SALVAGEABLE', 'Door, mail bank and lobby remain visible. Repeating/warped surface appearance is conspicuous; no causal shader attribution is made.'),
        'initial_f04': ('SALVAGEABLE', 'Continuous corridor walls, ceiling and lights are visible; carried device blocks the lower-right. A still does not prove actor ownership checks.'),
        'initial_harukiya': ('REFINE', 'Very underexposed interior; bar, tables and floor are only partly discernible. Insufficient for detailed interior quality inspection.'),
        'return_harukiya': ('REFINE', 'Returned bar/cafe composition is present but similarly underexposed. No arcade screen is legibly shown, so owner reactivation rests on runtime checks, not this image.'),
        'initial_street_phone': ('REFINE', 'Phone viewport renders the street without the carried device, but the central structure still obscures the architectural target.'),
        'initial_passage_phone': ('SALVAGEABLE', 'Phone viewport shows the shop corridor and signs without the carried device. Low resolution limits detail inspection.'),
        'initial_orison_phone': ('SALVAGEABLE', 'Phone viewport shows the doorway/mail bank without the carried device; repeated surface appearance remains visible.'),
        'actual_f04_mirror': ('SALVAGEABLE', 'Actual cabinet mirror displays a reflection in its frame. Image is distorted/blurred and the carried device obscures the right; no helper-caused distortion is inferred.'),
        'actual_f04_reflection': ('SALVAGEABLE', 'Borrowed reflection viewport contains door, toilet and partition geometry. This establishes visible content only; main-world borrowing is a separate runtime assertion.'),
        'separate_world_initial': ('SALVAGEABLE', 'Controlled own-world image contains the orange square against gray, matching the intended presence control.'),
        'separate_world_blocked': ('SALVAGEABLE', 'Controlled own-world image is uniformly gray; orange geometry is absent as intended during the blocker control.'),
        'separate_world_restored': ('SALVAGEABLE', 'Orange square is visible again in the controlled own-world viewport. Full retirement is not established by this still.'),
        'before_retirement_passage': ('SALVAGEABLE', 'Hall, shop grilles, signs and cart remain visible after repeated transitions. Device obscures lower-right; this precedes retirement.'),
        'before_retirement_passage_phone': ('SALVAGEABLE', 'Phone viewport retains the hall/cart after repeated transitions. This is a shared-world content check, not physical handset operation.'),
    }
    rows, runs = [], []
    for name in ['raw_v1_01', 'candidate_v1_diag_01']:
        folder = EVIDENCE / 'runs' / name
        result = json.loads((folder / 'result.json').read_text())
        runs.append({'run': name, 'receipt': (folder / 'result.json').relative_to(ROOT).as_posix(),
                     'receipt_sha256': sha(folder / 'result.json'), 'actual_engine_exit': result['actual_engine_exit'],
                     'elapsed_seconds': result['elapsed_seconds'], 'gate': result['gate'], 'source_unchanged': result['source_unchanged']})
        for path in sorted((folder / 'frames').glob('*.png')):
            verdict, observation = notes[path.stem]
            rows.append({'run': name, 'frame': path.name, 'path': path.relative_to(ROOT).as_posix(),
                         'sha256': sha(path), 'directly_viewed': True, 'composition_inspection_verdict': verdict,
                         'observation': observation})
    assert len(rows) == 29
    review = {'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'runs': runs, 'images': rows,
              'scope': 'All 29 retained PNGs directly inspected with view_image. Composition inspection only; no human acceptance, traversal, current-source green, causal shader or release-performance claim.',
              'comparison': 'The initial five raw/candidate compositions retain the same broad architectural arrangement. No obvious missing architectural population is visible in those stills. Different frame/actor state and failed runs prevent stronger equivalence claims.'}
    dump(EVIDENCE / 'failed_runs_visual_review.json', review)
    costs = summarize(EVIDENCE / 'runs/candidate_v1_diag_01/frames/probe.json')
    costs['limits'] += ' This is one FAILED mixed-cause helper-only run. Raw crashed without a final/progress timing receipt. No matched timing comparison is available.'
    dump(EVIDENCE / 'candidate_diagnostic_cost_summary.json', costs)
    lines = ['# Paused composed Vulkan diagnostic review', '',
        'Both executed V1 cases remain failed mixed-cause evidence. They are not valid intended-only renderer reds or current-source greens.', '',
        '- Raw: engine 3221225477 (access violation), 75.514 s, diagnostic gate 1; two unpair errors, 2,222 independent soft-shadow underflows, one resident-route error. No final probe or retirement proof; 13 PNGs retained.',
        '- Helper-only candidate: engine 1, 118.331 s, diagnostic gate 1; zero unpair/underflow/retention diagnostics, one resident-route error, 297 checks with 39 failed arcade labels. Actual shell/world retirement passed; all 16 PNGs retained.', '',
        'The candidate red proves a real viewport-boundary defect: still-live ArcadeMachine geometry retained its own World3D but entered Passage foreign geometry indices and acquired mask 0 instead of 1. At the first failure the cabinet remained booted and its away timer was below the unload delay. This is independent of legitimate later app retirement. Later missing-ID observations in that old fixture must not be read as requiring immortal arcade meshes.', '',
        'Only `_late_owner_is_dynamic` now refuses a SubViewport ancestor. Exact before/after bytes and the three-line repair are in `../evidence/vulkan_composed/viewport_boundary_repair`. It has not run yet. The fixture now retains observed legitimate retirement history through later reboot and separately checks the current own-world population. The viewport-omission control removes only the new guard; raw/helper-omission controls derive from the current candidate and retain the corrected viewport boundary and any unrelated current fixes.', '',
        'The F04 route error is separate and remains fatal. Schedule dispatch and campaign time are frozen, but production ResidentRoutines timers remain live. Its shaft-interior wait target is suspect; the cause of graph disconnection is not established by these logs. Focused diagnosis owns the engine lane before the renderer matrix resumes.', '',
        'Harukiya is exactly 247 eligible/indexed geometry nodes at the authored 03:00 time in the candidate census. The separate StreetCore `>250` contract remains unresolved and unchanged. The 1.6-second delay plus eight frames is a disclosed settle heuristic, not a builder-completion signal.', '',
        'The candidate records 36 transitions and 144 following frames, with live SurfacePass governor state. `../evidence/vulkan_composed/candidate_diagnostic_cost_summary.json` retains station distributions. Raw timing arrays were lost in its crash; no valid matched performance comparison exists. Diagnostic logging and adaptive material state also limit future comparisons.', '',
        'All 29 PNGs below were directly viewed. Verdicts are for composition inspection only. The initial raw/candidate frames show the same broad architecture; darkness, foreground obstructions, live state and failed runs preclude stronger equivalence. No human acceptance, traversal or final visual quality is claimed.', '',
        '| Run | Frame | Inspection verdict | Observation |', '|---|---|---|---|']
    for row in rows: lines.append(f"| {row['run']} | {row['frame']} | {row['composition_inspection_verdict']} | {row['observation']} |")
    lines += ['', 'The machine-readable image review retains every PNG hash and links the exact run receipts. No existing red receipt was rewritten or promoted. The Python parser/source-transform controls passed 25/25 with actual exit 0; that is a tool-control result, not a GDScript compilation or renderer result.', '']
    (ROOT / 'design/astra/reviews/vulkan_composed_diagnostic_review.md').write_text('\n'.join(lines), encoding='utf-8')
    print(json.dumps({'controls_exit': controls_exit, 'image_count': len(rows), 'review': 'design/astra/reviews/vulkan_composed_diagnostic_review.md'}, indent=2))


if __name__ == '__main__': main()
