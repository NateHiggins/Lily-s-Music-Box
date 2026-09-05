"""Authorized one-case diagnostic; exact two original files restored in finally."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[4]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')


def main():
    name = 'visibility_phase_census_01'
    out = ROOT / 'design/astra/evidence/vulkan_composed/profile_transactions' / name
    if out.exists():
        raise ValueError('fresh immutable diagnostic transaction required')
    preparation = json.loads((BASE / 'preparation.json').read_text(encoding='utf-8'))
    originals, diagnostic = {}, {}
    for rel, binding in preparation['bindings'].items():
        originals[rel] = (BASE.parent / 'originals' / rel).read_bytes()
        diagnostic[rel] = (BASE / 'proposed' / rel).read_bytes()
        if (sha(originals[rel]) != binding['original_sha256']
                or sha(diagnostic[rel]) != binding['diagnostic_sha256']
                or (ROOT / rel).read_bytes() != originals[rel]):
            raise ValueError('exact original/diagnostic/live binding mismatch: ' + rel)
    out.mkdir(parents=True)
    for folder, files in [('originals', originals), ('diagnostic', diagnostic)]:
        for rel, data in files.items():
            dest = out / folder / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
    (out / 'driver.py.source').write_bytes(Path(__file__).read_bytes())
    record = {'name': name, 'scope': 'one actual V1 root_retirement candidate; diagnostic phase attribution only',
              'bindings': preparation['bindings'], 'parent_preparation_unchanged': True,
              'engine_started': False, 'originals_restored_exactly': False}
    dump(out / 'receipt.json', record)
    try:
        for rel, data in diagnostic.items():
            (ROOT / rel).write_bytes(data)
        command = [sys.executable, str(ROOT / 'design/astra/work/vulkan_composed/run_case.py'),
                   'v1', 'candidate', name, '--scope', 'root_retirement']
        record.update(engine_started=True, command=command)
        dump(out / 'receipt.json', record)
        process = subprocess.run(command, cwd=ROOT, capture_output=True)
        (out / 'wrapper.stdout.log').write_bytes(process.stdout)
        (out / 'wrapper.stderr.log').write_bytes(process.stderr)
        record['child_diagnostic_exit'] = process.returncode
    finally:
        for rel, data in originals.items():
            (ROOT / rel).write_bytes(data)
        record['restored_sha256'] = {rel: sha((ROOT / rel).read_bytes()) for rel in originals}
        record['originals_restored_exactly'] = all((ROOT / rel).read_bytes() == data for rel, data in originals.items())
        dump(out / 'receipt.json', record)
        print(json.dumps({'receipt': str(out / 'receipt.json'),
                          'child_diagnostic_exit': record.get('child_diagnostic_exit'),
                          'originals_restored_exactly': record['originals_restored_exactly']}, indent=2), flush=True)
    return record.get('child_diagnostic_exit', 2) if record['originals_restored_exactly'] else 2


if __name__ == '__main__':
    raise SystemExit(main())
