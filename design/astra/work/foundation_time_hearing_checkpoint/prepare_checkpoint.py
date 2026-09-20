"""Verify and explicitly select the completed time/hearing repair checkpoint.

Run only after the engine lane is released. This never edits game sources or
historical receipts. --stage is a named-path Git mutation, not a commit.
"""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], stderr=subprocess.DEVNULL)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('name')
    parser.add_argument('--stage', action='store_true')
    args = parser.parse_args()
    assert args.name.replace('_', '').isalnum()
    assert not git('diff', '--cached', '--name-only'), 'Index must start empty'
    dest = BASE / args.name
    assert not dest.exists(), 'Use a fresh receipt name'
    sources = {}
    aggregates = {}
    run_count = artifact_count = 0
    for family in ('world_timestamps', 'hearing_presence'):
        path = ROOT / 'design/astra/evidence' / family / 'validation.json'
        aggregate = json.loads(path.read_text(encoding='utf-8'))
        aggregates[path.relative_to(ROOT).as_posix()] = sha(path)
        for rel, expected in aggregate['final_owned_source_sha256'].items():
            assert sha(ROOT / rel) == expected, 'Owned source changed: ' + rel
            sources[rel] = expected
        for row in aggregate['runs']:
            receipt_path = ROOT / row['receipt_path']
            assert sha(receipt_path) == row['receipt_sha256'], str(receipt_path)
            receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
            for rel, expected in receipt['artifact_hashes'].items():
                artifact = (receipt_path.parent / rel).resolve()
                assert artifact.is_relative_to(receipt_path.parent.resolve()), rel
                assert sha(artifact) == expected, str(artifact)
                artifact_count += 1
            run_count += 1
    assert run_count == 20 and artifact_count == 668
    protected = []
    old = json.loads((ROOT / 'design/astra/evidence/final_batch.json').read_text())
    for row in old['protected_paths']:
        rel = row['path']
        head_blob = git('rev-parse', 'HEAD:' + rel).decode().strip()
        working_blob = git('hash-object', '--path=' + rel, rel).decode().strip()
        assert head_blob == working_blob == row['current_blob'], rel
        protected.append({'path': rel, 'blob': head_blob})
    assert len(protected) == 17
    paths = set(sources)
    paths.update([
        'tools/audit_systemic_situation_authority.py',
        'tools/tests/test_systemic_situation_authority.py',
        'design/astra/reviews/world_timestamp_review.md',
        'design/astra/reviews/hearing_presence_review.md',
        'design/astra/evidence/.gitignore',
        Path(__file__).resolve().relative_to(ROOT).as_posix(),
    ])
    # Exact named package directories only. Git's ignore rules exclude profiles
    # and caches; a second explicit check below prevents accidental inclusion.
    for parent, families in (
        ('evidence', ('world_timestamps', 'hearing_presence', 'foundation_period_01',
                      'foundation_repairs_audits_01', 'foundation_repairs_audits_01_binding')),
        ('work', ('world_timestamps', 'hearing_presence', 'save_recovery/unix_audit')),
    ):
        for family in families:
            paths.update(filter(None, git('ls-files', '--cached', '--others',
                '--exclude-standard', '-z', '--', 'design/astra/' + parent + '/' + family
            ).decode().split('\0')))
    assert all(not any(part.lower() in {'appdata', 'userdata', '.godot', '__pycache__'}
        for part in Path(p).parts) for p in paths), 'Profile/cache selected'
    assert all((ROOT / p).is_file() for p in paths)
    rows = [{'path': p, 'raw_sha256': sha(ROOT / p),
             'git_blob': git('hash-object', '--path=' + p, p).decode().strip()}
            for p in sorted(paths)]
    receipt = {'head_before_commit': git('rev-parse', 'HEAD').decode().strip(),
        'scope': 'Six time/hearing production owners, associated fixtures and stronger host-time audit; other live foundation candidates are excluded from staging. Historical composed receipts explicitly bind their then-current uncommitted overlay, not just this commit.',
        'verified_runs': run_count, 'verified_artifacts': artifact_count,
        'aggregate_hashes': aggregates, 'protected': protected, 'selected_paths': rows,
        'full_game_complete': False, 'human_or_release_acceptance': False}
    dest.mkdir()
    receipt_path = dest / 'selection.json'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8', newline='\n')
    paths.add(receipt_path.relative_to(ROOT).as_posix())
    spec = dest / 'paths.nul'
    spec.write_bytes(b'\0'.join(p.encode() for p in sorted(paths)) + b'\0')
    if args.stage:
        subprocess.run(['git', '-C', str(ROOT), 'add', '--pathspec-from-file=' + str(spec),
                        '--pathspec-file-nul'], check=True)
        staged = set(filter(None, git('diff', '--cached', '--name-only', '-z').decode().split('\0')))
        assert staged == paths, (staged - paths, paths - staged)
        for row in rows:
            assert git('rev-parse', ':' + row['path']).decode().strip() == row['git_blob'], row['path']
        # Evidence/work must enter Git as the exact raw bytes named by receipts.
        for rel in sorted(paths):
            if rel.startswith(('design/astra/evidence/', 'design/astra/work/')):
                assert git('show', ':' + rel) == (ROOT / rel).read_bytes(), rel
    print(json.dumps({'selected_files': len(paths), 'runs': run_count,
        'artifacts': artifact_count, 'protected_paths': len(protected), 'staged': args.stage}))


if __name__ == '__main__':
    main()
