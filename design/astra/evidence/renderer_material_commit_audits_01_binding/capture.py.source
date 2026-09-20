"""Bind the existing static audit suite to explicit current text inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'design/astra/evidence/renderer_material_commit_audits_01'
BIND = ROOT / 'design/astra/evidence/renderer_material_commit_audits_01_binding'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, stderr=subprocess.DEVNULL)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')


def snapshot(label):
    paths = set(git('ls-files', '-z', '--', 'game', 'tools', 'art', 'design').decode().split('\0'))
    paths.update(git('ls-files', '--others', '--exclude-standard', '-z', '--', 'game', 'tools', 'art', 'design').decode().split('\0'))
    suffixes = {'.json', '.py', '.md', '.gltf', '.godot', '.tscn', '.gd', '.gdshader',
        '.gdshaderinc', '.glsl', '.tres', '.csv', '.toml', '.js', '.ts', '.ps1', '.txt', '.yml', '.yaml'}
    inputs = {p: sha(ROOT / p) for p in sorted(paths) if p and not p.startswith('design/astra/')
        and Path(p).suffix in suffixes and (ROOT / p).is_file()}
    write(BIND / (label + '.json'), inputs)
    (BIND / (label + '.diff')).write_bytes(git('diff', 'HEAD', '--binary', '--', 'game', 'tools', 'art', 'design', ':!design/astra'))
    return inputs


parser = argparse.ArgumentParser()
parser.add_argument('--expected-head', required=True)
args = parser.parse_args()
head = git('rev-parse', 'HEAD').decode().strip()
assert head == args.expected_head
assert not git('diff', '--cached', '--name-only')
assert not OUT.exists() and not BIND.exists()
BIND.mkdir(parents=True)
(BIND / 'capture.py.source').write_bytes(Path(__file__).read_bytes())
before = snapshot('before')
command = [sys.executable, '-B', 'tools/astra_run_audits.py', '--out', str(OUT)]
process = subprocess.run(command, cwd=ROOT, capture_output=True)
(BIND / 'orchestrator.stdout.txt').write_bytes(process.stdout)
(BIND / 'orchestrator.stderr.txt').write_bytes(process.stderr)
after = snapshot('after')
receipt = {'head': head, 'command': command, 'orchestrator_exit': process.returncode,
    'source_unchanged': before == after, 'input_count': len(before),
    'scope': 'Explicit tracked/untracked game/tools/art/design text and glTF inputs in before/after maps; design/astra reports/evidence excluded. Native assets remain bound by separate protected/runtime manifests. Wider text suffix coverage than the historical navigation audit; no retroactive rebinding.',
    'before_sha256': sha(BIND / 'before.json'), 'after_sha256': sha(BIND / 'after.json'),
    'child_receipt': (OUT / 'receipt.json').relative_to(ROOT).as_posix(),
    'child_receipt_sha256': sha(OUT / 'receipt.json') if (OUT / 'receipt.json').is_file() else None,
    'changed_paths': sorted(p for p in set(before) | set(after) if before.get(p) != after.get(p))}
write(BIND / 'receipt.json', receipt)
print(process.stdout.decode(errors='replace'))
print(json.dumps({'orchestrator_exit': process.returncode, 'source_unchanged': before == after, 'input_count': len(before), 'binding_sha256': sha(BIND / 'receipt.json')}, indent=2))
raise SystemExit(int(process.returncode != 0 or before != after))
