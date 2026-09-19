"""Finish interrupted metadata preparation; retain pre-reboot metadata verbatim."""
from pathlib import Path
import hashlib
import json

BASE = Path(__file__).resolve().parent / 'v2_reservation_runtime_03'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding='utf-8'))
def write(p, value):
    p.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')

backup = BASE / 'interrupted_metadata'
backup.mkdir(exist_ok=False)
for name in ('seal.json','preparation.json','runtime/package.json'):
    target = backup / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((BASE/name).read_bytes())
controls = read(BASE/'offline_validation_03/receipt.json')
for rel, value in controls['sources_sha256'].items():
    assert sha(BASE/rel) == value, rel
for rel, value in controls['artifacts_sha256'].items():
    assert sha(BASE/'offline_validation_03'/rel) == value, rel
plan = read(BASE/'preparation.json')
plan['independent_review']['scope'] = 'Historical runtime02 review only; runtime03 reviewed locally after reboot.'
plan['files_sha256'] = {
    p.relative_to(BASE).as_posix():sha(p) for p in sorted(BASE.rglob('*'))
    if p.is_file() and p.relative_to(BASE).parts[0] != 'runtime'
    and p.name not in ('preparation.json','seal.json') and '__pycache__' not in p.parts
}
write(BASE/'preparation.json', plan)
package = read(BASE/'runtime/package.json')
package['files'] = {rel:sha(BASE/'runtime'/rel) for rel in package['files']}
package['parent_preparation_sha256'] = sha(BASE/'preparation.json')
write(BASE/'runtime/package.json', package)
seal = {
    'schema':'astra.v2-reservation.execution-seal.v3',
    'status':'ROOT_REVIEWED_PREPARED_NO_NATIVE_EXECUTION',
    'required_head':plan['required_install_head'],
    'preparation_sha256':sha(BASE/'preparation.json'),
    'runtime_package_sha256':sha(BASE/'runtime/package.json'),
    'run_sha256':sha(BASE/'runtime/run.py'),
    'offline_validation_receipt_sha256':sha(BASE/'offline_validation_03/receipt.json'),
    'all_package_files_sha256': {
        p.relative_to(BASE).as_posix():sha(p) for p in sorted(BASE.rglob('*'))
        if p.is_file() and p != BASE/'seal.json' and '__pycache__' not in p.parts
    }
}
write(BASE/'seal.json',seal)
print(json.dumps({'status':seal['status'],'files':len(seal['all_package_files_sha256']),'seal_sha256':sha(BASE/'seal.json')}))
