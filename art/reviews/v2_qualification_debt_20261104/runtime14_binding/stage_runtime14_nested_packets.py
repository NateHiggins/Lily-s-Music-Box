"""Stage exact runtime14-only packets externally after its original final guard qualifies.

Never publishes, repins receipts or overwrites original evidence.
"""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import os
import runpy
import subprocess
import sys

ROOT = Path('C:/PleaseRemainOnTheLine')
BASE = Path(__file__).parent
PRODUCER_SHA = '423771d0ee6a076e0d7f74bee9bc87a8e7eb5d9e63dfaa226320a9acc520873f'
FREEZE_SHA = '7f76d8fadf522788b20a410bf0a6b3376bd090cb5500b4842cffaf09294c6abe'
QUALIFICATION_HEAD = 'dd1d6f652b9087c410b82a81b40284124c92e92c'
TRACKER_PATHS = {'HANDOFF.md', 'TASKS.md'}
INSTRUMENT_PATH = 'art/reviews/v2_surface_renewal_20261021/verify_first_slice.py'
INSTRUMENT_LF_SHA = 'a10053640090016739aa5ef0579156022db77ca46fbb2cc6613f6a3c13a552a1'
sys.path.insert(0, str(ROOT / 'tools'))
from publish_v2_spatial_packet import verify, current_digests


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def stage(source, destination, name, contract_name, freeze, actual_staging_head):
    wrapper_path = source / (name + '.log.receipt.json')
    receipt = wrapper_path.read_bytes()
    wrapper = json.loads(receipt)
    assert source.resolve() == (BASE / 'runtime_14').resolve(), 'Only original runtime14 evidence admitted'
    wrapper_head = wrapper['source']['repository_head']
    # The complete freeze->staging interval was already checked commit by
    # commit/all merge parents by staging_head(), before any staging output.
    # Wrappers may capture an intermediate tracker-only descendant at launch.
    for ancestor, descendant in [(QUALIFICATION_HEAD, wrapper_head),
                                 (wrapper_head, actual_staging_head)]:
        ancestry = subprocess.run(['git', 'merge-base', '--is-ancestor', ancestor, descendant], cwd=ROOT)
        assert ancestry.returncode == 0, 'Wrapper HEAD outside qualified tracker-only ancestry interval'
    assert wrapper['source']['runtime_inputs_sha256'] == freeze['inputs']['runtime']
    assert wrapper['scene'] == {'first_slice': 'res://tests/orison_v2_first_slice_contract_test.tscn',
                               'apartments': 'res://tests/OrisonV2RemainingApartmentAccessContractTest.tscn'}[name]
    assert wrapper['windowed'] is True and Path(wrapper['shot_dir']).resolve() == (source / name).resolve()
    execution = wrapper['execution']
    assert execution['completed'] and execution['exit_code'] == 0 and not execution['timed_out']
    contract_path = source / name / contract_name
    contract = contract_path.read_bytes()
    contract_source = json.loads(contract)['source']
    for key in ['repository_head', 'runtime_inputs_sha256']:
        assert contract_source[key] == wrapper['source'][key], 'Original contract/wrapper binding mismatch: ' + key
    if name != 'first_slice':
        for key in ['test_path', 'test_sha256']:
            assert contract_source[key] == wrapper['source'][key], 'Original contract/wrapper test binding mismatch: ' + key
    # First-slice binding is checked by its strengthened validator below:
    # exact non-NULL equality, or the narrowly proven nested-scene NULL case.
    for key, suffix in [('stdout', '.log'), ('stderr', '.log.stderr')]:
        assert Path(wrapper['log'][key]).resolve() == (source / (name + suffix)).resolve(), 'Cross-run log refused'
    logs = {key: Path(wrapper['log'][key]).read_bytes() for key in ['stdout', 'stderr']}
    assert all(sha(raw) == wrapper['log'][key + '_sha256'] for key, raw in logs.items())
    target = destination / ('packaged_' + name)
    temporary = target.with_name(target.name + '.staging')
    assert not target.exists() and not temporary.exists(), 'Fresh staging targets required'
    temporary.mkdir()
    (temporary / contract_name).write_bytes(contract)
    (temporary / 'suite_run.receipt.json').write_bytes(receipt)
    for key, raw in logs.items():
        compressed = gzip.compress(raw, mtime=0)
        assert gzip.decompress(compressed) == raw
        (temporary / ('suite_run.' + key + '.log.gz')).write_bytes(compressed)
    if name == 'first_slice':
        validator = runpy.run_path(str(ROOT / 'art/reviews/v2_surface_renewal_20261021/verify_first_slice.py'))
        result = validator['verify'](temporary)
    else:
        qualified = verify(contract, receipt, logs, ROOT, current_digests(ROOT))
        assert len(qualified['contracts']['room_access']['rooms']) == 60
        assert len(qualified['legs']) == 9
        result = {'evidence_class': 'INERT', 'result': 'PASS', 'rooms': 60, 'legs': 9}
    assert (temporary / contract_name).read_bytes() == contract_path.read_bytes()
    assert (temporary / 'suite_run.receipt.json').read_bytes() == wrapper_path.read_bytes()
    (temporary / 'verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    temporary.rename(target)
    return {'name': name, 'source_run': str(source), 'target': str(target),
            'original_contract_sha256': sha(contract), 'original_wrapper_sha256': sha(receipt),
            'original_log_sha256': {key: sha(raw) for key, raw in logs.items()},
            'original_repository_head': wrapper_head,
            'qualification_freeze_head': QUALIFICATION_HEAD, 'actual_staging_head': actual_staging_head}


def staging_head(frozen_head):
    assert frozen_head == QUALIFICATION_HEAD, 'Unexpected original qualification head'
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT).strip(), 'Keep candidate clean before external staging'
    ancestry = subprocess.run(['git', 'merge-base', '--is-ancestor', frozen_head, actual], cwd=ROOT)
    assert ancestry.returncode == 0, 'Staging HEAD must descend from the qualification freeze'
    commits = subprocess.check_output(['git', 'rev-list', frozen_head + '..' + actual], cwd=ROOT, text=True).splitlines()
    changed = set()
    for commit in commits:
        # Inspect every commit, including every merge parent: a source edit
        # followed by its reversal must not disappear in an endpoint diff.
        raw = subprocess.check_output(['git', 'diff-tree', '--no-commit-id', '--name-only',
                                       '--no-renames', '-r', '-m', '--root', '-z', commit], cwd=ROOT)
        commit_paths = {path.decode('utf-8') for path in raw.split(b'\0') if path}
        if INSTRUMENT_PATH in commit_paths:
            blob = subprocess.check_output(['git', 'show', commit + ':' + INSTRUMENT_PATH], cwd=ROOT)
            assert sha(blob.replace(b'\r\n', b'\n')) == INSTRUMENT_LF_SHA, 'Unreviewed verifier edit in descendant history'
        changed.update(commit_paths)
    # This successor admits exactly the reviewed instrument-only repair.
    # Keep the runtime14 freeze head and wrappers original; do not repin them.
    assert changed <= TRACKER_PATHS | {INSTRUMENT_PATH}, 'Unreviewed descendant changes refuse staging: ' + repr(sorted(changed - TRACKER_PATHS - {INSTRUMENT_PATH}))
    assert sha((ROOT / INSTRUMENT_PATH).read_bytes().replace(b'\r\n', b'\n')) == INSTRUMENT_LF_SHA, 'Reviewed binding verifier changed'
    return actual, sorted(changed)


def main():
    if sys.flags.optimize:
        raise SystemExit('Assertions must remain enabled; run without -O/PYTHONOPTIMIZE')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', choices=['runtime_14'])
    args = parser.parse_args()
    run = BASE / args.run
    after = run / 'after.log'
    if not after.is_file() or 'V2 RENEWAL SOURCE/CONTRACT GUARD PASS after' not in after.read_text(encoding='utf-8').splitlines():
        raise SystemExit('NOT READY: original final source/contract guard has not passed; no packet staged')
    original_after = after.read_bytes()
    freeze_raw = (run / 'SOURCE_FREEZE.json').read_bytes()
    assert sha(freeze_raw) == FREEZE_SHA, 'Original runtime14 freeze changed'
    freeze = json.loads(freeze_raw)
    assert 'reused_evidence' not in freeze, 'Runtime14 never stages old-engine reused evidence'
    producer = BASE / 'prepare_runtime14.py'
    assert sha(producer.read_bytes()) == freeze['preparer_sha256'] == PRODUCER_SHA
    actual_head, tracker_changes = staging_head(freeze['repository_head'])
    index_path = run / 'PACKET_STAGING.json'
    assert not index_path.exists(), 'Fresh staging index required'
    for name in ['first_slice', 'apartments']:
        target = run / ('packaged_' + name)
        assert not target.exists() and not target.with_name(target.name + '.staging').exists(), 'Fresh staging targets required'
    # Exclusive staging logs also claim this one staging attempt. Never
    # overwrite the original after log, earlier staging logs, or staged packets.
    guard_log = run / 'PACKET_STAGING_NESTED_GUARD.log'
    guard_err = run / 'PACKET_STAGING_NESTED_GUARD.stderr'
    assert not guard_log.exists() and not guard_err.exists(), 'Fresh staging guard logs required'
    env = os.environ.copy()
    env.pop('PYTHONOPTIMIZE', None)
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    env['ORISON_GODOT_EXE'] = freeze['engine']['path']
    # The immutable producer's AFTER mode performs read-only source, engine,
    # binary, endpoint/profile/batch, native PNG and current contract checks.
    # Its prepare/review/launch paths are never invoked by this stager.
    with guard_log.open('xb') as stdout, guard_err.open('xb') as stderr:
        result = subprocess.run([sys.executable, '-B', str(producer), str(run), 'after'],
                                capture_output=True, env=env)
        stdout.write(result.stdout)
        stderr.write(result.stderr)
    assert result.returncode == 0, 'Current runtime14 source/engine/contracts guard rejected staging'
    assert 'V2 RENEWAL SOURCE/CONTRACT GUARD PASS after' in result.stdout.decode('utf-8').splitlines()
    assert (run / 'SOURCE_FREEZE.json').read_bytes() == freeze_raw
    assert after.read_bytes() == original_after, 'Original runtime14 after log changed'
    assert sha(producer.read_bytes()) == PRODUCER_SHA
    # Refuse if the checkout changed while the full guard was evaluating it.
    assert staging_head(freeze['repository_head']) == (actual_head, tracker_changes), 'Staging checkout changed during guard'
    staged = [stage(run, run, 'first_slice', 'runtime_authority_receipt.json', freeze, actual_head),
              stage(run, run, 'apartments', 'runtime_contract.json', freeze, actual_head)]
    # Both independent byte/source validators have passed before the index can
    # advertise a complete staging result. Preserve partial output on failure.
    assert staging_head(freeze['repository_head']) == (actual_head, tracker_changes), 'Staging checkout changed during packaging'
    assert (run / 'SOURCE_FREEZE.json').read_bytes() == freeze_raw
    assert after.read_bytes() == original_after
    assert sha(producer.read_bytes()) == PRODUCER_SHA
    index = {'evidence_class': 'INERT', 'scope': 'External byte-exact packet staging only; no publication or artistic acceptance',
             'candidate_head': actual_head, 'qualification_freeze_head': freeze['repository_head'],
             'staging_head': actual_head, 'tracker_only_changed_paths': [path for path in tracker_changes if path in TRACKER_PATHS],
             'reviewed_instrument_path': INSTRUMENT_PATH, 'reviewed_instrument_lf_sha256': INSTRUMENT_LF_SHA, 'packets': staged,
             'source_freeze_raw_sha256': sha(freeze_raw), 'producer_raw_sha256': PRODUCER_SHA,
             'original_after_raw_sha256': sha(original_after),
             'staging_guard_stdout_sha256': sha(result.stdout), 'staging_guard_stderr_sha256': sha(result.stderr),
             'engine': freeze['engine'], 'diagnostic_audio_output': freeze['diagnostic_audio_output'],
             'isolated_profiles': freeze['isolated_profiles'],
             'prior_engine_evidence_qualification_credit': False,
             'human_played': False, 'artistically_accepted': False}
    with index_path.open('x', encoding='utf-8') as handle:
        handle.write(json.dumps(index, indent=2) + '\n')
    print('STAGED externally: runtime14 original first-slice and 60-room/nine-leg apartment packets only. No publication.')


if __name__ == '__main__':
    main()
