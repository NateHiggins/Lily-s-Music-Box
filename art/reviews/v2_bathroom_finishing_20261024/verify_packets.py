"""INERT source/log integrity only; failed runs retain their original verdicts."""
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PACKETS = [HERE, ROOT / 'art/reviews/v2_shop_finish_ownership_20261024']
digest = lambda raw: hashlib.sha256(raw).hexdigest()
archives = {}
for packet in PACKETS:
    for path in packet.rglob('*.gz'):
        raw = gzip.decompress(path.read_bytes())
        for data in [raw, raw.replace(b'\r\n', b'\n')]:
            archives.setdefault(digest(data), []).append(str(path.relative_to(ROOT)))
checks = []
for packet in PACKETS:
    for path in sorted(packet.glob('*.receipt.json')):
        receipt = json.loads(path.read_text(encoding='utf-8'))
        row = {'receipt': str(path.relative_to(ROOT)), 'execution': receipt['execution'],
               'script_errors': receipt['log']['script_error_count']}
        for name in ['stdout', 'stderr']:
            log = Path(receipt['log'][name])
            assert log.is_file(), log
            assert digest(log.read_bytes()) == receipt['log'][name + '_sha256'], log
        source = receipt['source']
        wanted = source.get('test_sha256')
        if wanted:
            matches = list(archives.get(wanted, []))
            live = ROOT / source['test_path']
            if live.exists() and wanted in [digest(live.read_bytes()), digest(live.read_bytes().replace(b'\r\n', b'\n'))]:
                matches.append(source['test_path'])
            row['top_level_source_matches'] = matches
            if not matches:
                row['limitation'] = 'Unbound historical diagnostic source; no source-bound qualification claimed.'
        stderr = Path(receipt['log']['stderr']).read_text(encoding='utf-8', errors='replace')
        row['engine_error_lines'] = sum(line.startswith('ERROR:') for line in stderr.splitlines())
        row['warning_lines'] = sum(line.startswith('WARNING:') for line in stderr.splitlines())
        checks.append(row)
protected = json.loads((ROOT / 'art/reviews/v2_nook_shelf_dressing_20261024/source_controls.json').read_text())['protected']
for row in protected:
    raw = (ROOT / row['path']).read_bytes()
    assert digest(raw if row['hash_mode'] == 'raw' else raw.replace(b'\r\n', b'\n')) == row['sha256'], row['path']
manifest = json.loads((ROOT / 'tools/orison_spatial_dependency_manifest.json').read_text(encoding='utf-8'))
owned = json.loads((HERE / 'owned_spatial_rows.json').read_text())
keys = {row['key'] for row in owned}
original = {**manifest, 'records': [row for row in manifest['records'] if row['key'] not in keys]}
assert digest(json.dumps(original, sort_keys=True, separators=(',', ':')).encode()) == (HERE / 'manifest_before_sha256.txt').read_text().strip()
result = {'evidence_class': 'INERT',
          'scope': 'Wrapper logs, top-level diagnostic source matches, protected paths and original shared manifest preservation. No runtime_contract or dirty-tree reconstruction.',
          'checks': checks, 'protected_unchanged': len(protected), 'owned_manifest_rows': len(owned)}
(HERE / 'source_checks.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8', newline='\n')
print('Verified', len(checks), 'receipt log pairs;', len(protected), 'protected paths; original shared manifest unchanged.')
