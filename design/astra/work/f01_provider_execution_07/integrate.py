"""Adopt only the exact optional provider inputs admitted at 37f0307."""
from pathlib import Path
import hashlib, json, subprocess
ROOT = Path(__file__).resolve().parents[4]
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
admission = read(Path(__file__).with_name('preflight.json'))
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip() == admission['head']
owner = 'game/scripts/building/building_root.gd'
base = ROOT / 'design/astra/work/f01_provider_parity_01/revisions/imported_resource_controls_02'
assert sha(ROOT / owner) == read(base / 'sealed.json')['source_root_sha256']
paths = []
for row in admission['install_paths']:
    path = ROOT / row['target']
    candidate = Path(row['source']) if row['target'] == owner else path
    assert sha(candidate) == row['expected_sha256'], row['target']
    paths.append(row['target'])
for rel, row in admission['protected'].items():
    assert sha(ROOT / rel) == row['sha256'], rel
for row in admission['install_paths']:
    if row['target'] == owner:
        (ROOT / owner).write_bytes(Path(row['source']).read_bytes())
for rel in list(paths):
    uid = ROOT / (rel + '.uid')
    if rel.endswith('.gd') and uid.exists():
        paths.append(rel + '.uid')
subprocess.run(['git', 'add', '--', *paths], cwd=ROOT, check=True)
receipt = {'status': 'EXACT_TESTED_OPTIONAL_PROVIDER_INTEGRATED_LEGACY_DEFAULT',
           'base_head': admission['head'], 'files': {rel: sha(ROOT / rel) for rel in paths}}
(ROOT / 'design/astra/evidence/f01_provider_execution_07/integration.json').write_text(json.dumps(receipt, indent=2)+'\n')
print('Integrated and staged', len(paths), 'explicit provider paths')
