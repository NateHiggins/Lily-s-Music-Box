"""Stage only the named source reconstruction and its closed evidence families."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'design/astra/work/f01_source_checkpoint_01'
BASE = '77dc5f75cd7cb68be6d1f3d0be4f57ff1b06c3d4'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.PIPE)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8', newline='\n')


assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert not git('diff', '--cached', '--name-only')
assert not git('diff', 'HEAD', '--name-only', '--', 'game', 'tools', 'art')
source_receipt = json.loads((ROOT / 'design/astra/evidence/f01_source_replay/installed_01/receipt.json').read_text())
sources = source_receipt['allowed_paths']
assert len(sources) == 10
assert set(git('ls-files', '--others', '--exclude-standard', '--', 'game', 'tools', 'art').decode().splitlines()) == set(sources)
protected = json.loads((ROOT / 'design/astra/evidence/f01_source_replay/installed_01/protected.after.json').read_text())
assert len(protected) == 17
for path, row in protected.items():
    assert sha(ROOT / path) == row['raw_sha256']
    assert git('rev-parse', 'HEAD:' + path).decode().strip() == row['working_clean_blob']
roots = [
    'design/astra/work/f01_reconstruction_review',
    'design/astra/evidence/f01_source_replay',
    'design/astra/evidence/f01_source_export',
    'design/astra/evidence/renderer_material_commit_audits_01',
    'design/astra/evidence/renderer_material_commit_audits_01_binding',
    'design/astra/work/renderer_material_checkpoint/staging_01',
    'design/astra/work/renderer_material_checkpoint/review_after_selection_01',
]
names = sources + [
    'design/astra/DECISION_LOG.md', 'design/astra/INTEGRATION_REGISTER.md',
    'design/astra/LIVE_STATE.json', 'design/astra/MASTER_COMPLETION_LEDGER.json',
    'design/astra/MASTER_COMPLETION_LEDGER.md', 'design/astra/RELEASE_EVIDENCE_MATRIX.md',
    'design/astra/reviews/production_obligations.json',
    'design/astra/reviews/c1_source_installation_review.json',
    'design/astra/reviews/c1_source_installation_review.md',
    'design/astra/evidence/renderer_material_commit_checkpoint.json',
    'design/astra/work/renderer_material_checkpoint/record_commit_01.py',
    'design/astra/work/renderer_material_checkpoint/capture_postcommit_audits_01.py',
    'design/astra/work/f01_source_checkpoint_01.py',
]
for family in roots:
    names.extend(p.relative_to(ROOT).as_posix() for p in (ROOT / family).rglob('*') if p.is_file())
names = sorted(set(names))
assert all((ROOT / p).is_file() and '__pycache__' not in p and '/APPDATA/' not in p for p in names)
assert not any(p.startswith('game/') for p in names)
assert set(p for p in names if p.startswith(('art/', 'tools/'))) == set(sources)
OUT.mkdir(exist_ok=False)
write(OUT / 'selection.json', {'base_head': BASE, 'selected': {p: sha(ROOT / p) for p in names},
    'protected_17': protected, 'live_sources': sources,
    'scope': 'Clean source/tool reconstruction and deterministic external export evidence. No game source or generated production asset adoption.'})
names += ['design/astra/work/f01_source_checkpoint_01/selection.json',
    'design/astra/work/f01_source_checkpoint_01/paths.nul']
names = sorted(names)
(OUT / 'paths.nul').write_bytes(b''.join(p.encode() + b'\0' for p in names))
process = subprocess.run(['git', 'add', '--pathspec-from-file=' + str(OUT / 'paths.nul'),
    '--pathspec-file-nul'], cwd=ROOT, capture_output=True)
(OUT / 'stage.stdout.log').write_bytes(process.stdout)
(OUT / 'stage.stderr.log').write_bytes(process.stderr)
assert process.returncode == 0
staged = git('diff', '--cached', '--name-only', '-z').decode().split('\0')
staged = [p for p in staged if p]
assert set(staged) == set(names), 'Unexpected staged path set'
rows = []
for path in names:
    raw = (ROOT / path).read_bytes()
    blob = git('rev-parse', ':' + path).decode().strip()
    expected = git('hash-object', '--path=' + path, path).decode().strip()
    assert blob == expected, path
    if path.startswith(('design/astra/work/', 'design/astra/evidence/')):
        assert git('show', ':' + path) == raw, path
    rows.append({'path': path, 'raw_sha256': hashlib.sha256(raw).hexdigest(), 'staged_blob': blob})
for row in source_receipt['installed']:
    assert git('rev-parse', ':' + row['path']).decode().strip() == row['source_blob']
write(OUT / 'staging.json', {'base_head': BASE, 'paths': rows, 'path_count': len(rows),
    'source_count': 10, 'game_paths': 0, 'exact_c1_blobs': True, 'protected_unchanged': True})
print(json.dumps({'status': 'NAMED_STAGE_VERIFIED', 'path_count': len(rows), 'source_count': 10,
    'game_paths': 0, 'selection_sha256': sha(OUT / 'selection.json')}))
