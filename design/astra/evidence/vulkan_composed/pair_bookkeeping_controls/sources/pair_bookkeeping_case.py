"""Pending explicit Godot/source handoff: sole-owner omission/restored sequence.

This is an opt-in negative contract, never called by ordinary candidate runs.
Each child keeps the unchanged serial runner and its own <=180s cap. Diagnostic
reds return 1 even when the paired negative evidence has been established.
"""
from pathlib import Path
import argparse
import datetime
import json
import re
import subprocess
import sys

from gate import classify
from pair_bookkeeping import (CONTRACT, ENGINE_SOURCE, ENGINE_SOURCE_SHA256,
                              assess_omission, assess_pair, sha)
from variant_case import BASE, ROOT, LIVE, select_variant


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def load_run(name):
    folder = ROOT / 'design/astra/evidence/vulkan_composed/runs' / name
    result = json.loads((folder / 'result.json').read_text(encoding='utf-8'))
    stdout = (folder / 'stdout.log').read_text(encoding='utf-8-sig')
    stderr = (folder / 'stdout.log.stderr').read_text(encoding='utf-8-sig')
    probe = json.loads((folder / 'frames/probe.json').read_text(encoding='utf-8'))
    # Re-read artifact hashes: no final aggregate over changed logs/probe/source.
    if any(not (folder / p).is_file() or sha((folder / p).read_bytes()) != digest
           for p, digest in result['artifacts'].items()):
        raise ValueError('retained run artifact changed: ' + name)
    bound = len(result['engines_before']) == 2 and result['engines_before'] == result['engines_after']
    current_gate = classify(result['actual_engine_exit'], stdout, stderr, probe,
                            result['source_unchanged'], bound)
    if current_gate != result['gate']:
        raise ValueError('retained strict gate does not reproduce: ' + name)
    transaction = ROOT / 'design/astra/evidence/vulkan_composed/variant_transactions' / (name + '.json')
    return result, stdout, stderr, probe, json.loads(transaction.read_text(encoding='utf-8'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('name')
    parser.add_argument('--candidate-sha256', required=True)
    parser.add_argument('--scope', choices=['full', 'root_retirement'], default='root_retirement')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]+', args.name):
        parser.error('simple fresh sequence name required')
    candidate = LIVE.read_bytes()
    if sha(candidate) != args.candidate_sha256:
        parser.error('current source differs from explicit handoff; no mutation')
    try:
        selected = select_variant(candidate, 'omission')
    except ValueError as error:
        parser.error(str(error))
    engine_source = ROOT / ENGINE_SOURCE
    if not engine_source.is_file() or sha(engine_source.read_bytes()) != ENGINE_SOURCE_SHA256:
        parser.error('retained expected native source binding unavailable')
    omission_name, restored_name = args.name + '_omission', args.name + '_restored'
    for name in [omission_name, restored_name]:
        if (ROOT / 'design/astra/evidence/vulkan_composed/runs' / name).exists() or (ROOT / 'design/astra/evidence/vulkan_composed/variant_transactions' / (name + '.json')).exists():
            parser.error('fresh child run/transaction names required')
    out = ROOT / 'design/astra/evidence/vulkan_composed/pair_bookkeeping_sequences' / args.name
    out.mkdir(parents=True, exist_ok=False)
    inputs = {p.name: sha(p.read_bytes()) for p in BASE.glob('*.py')}
    for name in inputs:
        (out / (name + '.source')).write_bytes((BASE / name).read_bytes())
    (out / 'candidate.gd.txt').write_bytes(candidate)
    (out / 'omission.gd.txt').write_bytes(selected)
    record = {'contract': CONTRACT, 'status': 'declared_before_execution',
              'started_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'root': 'v1', 'scope': args.scope, 'candidate_sha256': sha(candidate),
              'selected_sha256': sha(selected), 'engine_source_path': ENGINE_SOURCE,
              'engine_source_sha256': ENGINE_SOURCE_SHA256, 'preparation_inputs': inputs,
              'omission_run': omission_name, 'restored_run': restored_name,
              'expected_pair_bookkeeping_red_observed': False, 'children': []}
    dump(out / 'receipt.json', record)
    try:
        for variant, name in [('omission', omission_name), ('candidate', restored_name)]:
            if LIVE.read_bytes() != candidate:
                raise ValueError('candidate source changed before child: ' + name)
            command = [sys.executable, str(BASE / 'variant_case.py'), 'v1', variant, name,
                       '--candidate-sha256', args.candidate_sha256, '--scope', args.scope]
            process = subprocess.run(command, cwd=ROOT, capture_output=True)
            (out / (name + '.wrapper.stdout.log')).write_bytes(process.stdout)
            (out / (name + '.wrapper.stderr.log')).write_bytes(process.stderr)
            record['children'].append({'name': name, 'variant': variant, 'command': command,
                                       'diagnostic_exit': process.returncode})
            dump(out / 'receipt.json', record)
            if LIVE.read_bytes() != candidate:
                raise ValueError('child did not restore exact candidate')
        old, stdout, stderr, probe, old_tx = load_run(omission_name)
        new, _, _, new_probe, new_tx = load_run(restored_name)
        unchanged = (inputs == {p.name: sha(p.read_bytes()) for p in BASE.glob('*.py')}
                     and LIVE.read_bytes() == candidate
                     and sha(engine_source.read_bytes()) == ENGINE_SOURCE_SHA256)
        provisional = assess_omission(old, stdout, stderr, probe, candidate, selected,
                                      CONTRACT, unchanged)
        aggregate = assess_pair(provisional, old, new, new_probe, old_tx, new_tx,
                                candidate, selected, unchanged)
        record.update(status='completed_assessment', omission_assessment=provisional,
                      aggregate=aggregate, preparation_unchanged=unchanged,
                      expected_pair_bookkeeping_red_observed=aggregate['expected_pair_bookkeeping_red_observed'])
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        # An AV/missing final probe stays incomplete even if its text contains both
        # signatures. The restored child still ran when exact source permitted it.
        record.update(status='incomplete_or_invalid', error=str(error),
                      expected_pair_bookkeeping_red_observed=False)
    finally:
        record['final_live_sha256'] = sha(LIVE.read_bytes())
        record['candidate_restored_exactly'] = LIVE.read_bytes() == candidate
        dump(out / 'receipt.json', record)
        print(json.dumps({'receipt': str(out / 'receipt.json'),
                          'expected_pair_bookkeeping_red_observed': record['expected_pair_bookkeeping_red_observed'],
                          'status': record['status']}, indent=2), flush=True)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
