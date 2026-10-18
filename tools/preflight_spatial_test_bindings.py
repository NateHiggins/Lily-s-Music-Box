#!/usr/bin/env python3
"""Check spatial receipt SOURCES closure before spending time in Godot.

Read-only. This checks declarations, not runtime behavior or receipt acceptance.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from pathlib import PureWindowsPath

REFERENCES = re.compile(r'res://tests/[A-Za-z0-9_/.-]+')
SOURCES = re.compile(r'const\s+SOURCES\s*(?::[^=\n]+)?\s*(?::=|=)\s*\[(.*?)\]', re.S)
TEXT_SUFFIXES = {'.json','.gd','.py','.gltf','.godot','.tscn','.tres','.gdshader','.gdshaderinc','.import','.txt','.md','.ps1'}


def check_fixture(path: Path, root: Path) -> list[str]:
    """Read-only native authoring bindings; this grants no runtime acceptance."""
    root=root.resolve();path=path.resolve()
    if not path.is_relative_to(root/'game/tests/fixtures') or not path.is_file():
        return ['fixture must be an existing file inside game/tests/fixtures']
    try:
        data=json.loads(path.read_text(encoding='utf-8'))
    except (ValueError,UnicodeError):
        return ['fixture is not a UTF-8 JSON object']
    bindings=data.get('source_bindings') if isinstance(data,dict) else None
    if not isinstance(bindings,dict) or not bindings:
        return ['fixture requires nonempty source_bindings']
    errors=[]
    for relative,expected in bindings.items():
        target=(root/relative).resolve()
        if PureWindowsPath(relative).is_absolute() or Path(relative).is_absolute() or '..' in Path(relative).parts or not target.is_relative_to(root):
            errors.append('fixture dependency escapes repository: '+relative);continue
        if not isinstance(expected,str) or not re.fullmatch('[0-9a-f]{64}',expected):
            errors.append('invalid fixture digest: '+relative);continue
        if not target.is_file():
            errors.append('missing fixture dependency: '+relative);continue
        raw=target.read_bytes()
        if target.suffix.lower() in TEXT_SUFFIXES:raw=raw.replace(b'\r\n',b'\n')
        if hashlib.sha256(raw).hexdigest()!=expected:
            errors.append('stale fixture dependency: '+relative)
    return sorted(errors)


def check(entry: Path, root: Path) -> list[str]:
    root = root.resolve()
    entry = entry.resolve()
    tests = root / 'game/tests'
    if not entry.is_relative_to(tests) or not entry.is_file():
        return ['entry must be an existing file inside game/tests']
    text = entry.read_text(encoding='utf-8')
    declaration = SOURCES.search(text)
    if not declaration:
        return ['missing static SOURCES declaration']
    declared = set(REFERENCES.findall(declaration.group(1)))
    own = 'res://' + entry.relative_to(root / 'game').as_posix()
    pending = list(declared | {own})
    visited = set()
    errors = []
    while pending:
        reference = pending.pop()
        if reference in visited:
            continue
        visited.add(reference)
        path = (root / 'game' / reference.removeprefix('res://')).resolve()
        if not path.is_relative_to(tests):
            errors.append('dependency escapes game/tests: ' + reference)
            continue
        if not path.is_file():
            errors.append('missing dependency file: ' + reference)
            continue
        if reference not in declared:
            errors.append('unbound dependency: ' + reference)
        pending.extend(REFERENCES.findall(path.read_text(encoding='utf-8')))
    return sorted(set(errors))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='*', help='game/tests receipt-writing GDScripts')
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--all', action='store_true', help='check every spatial SOURCES declaration')
    parser.add_argument('--fixture', action='append', default=[], help='native fixture whose source_bindings must be current before Godot')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    paths = {root / name for name in args.paths}
    if args.all:
        paths.update(p for p in (root / 'game/tests').glob('*.gd')
                     if 'test_dependencies' in p.read_text(encoding='utf-8')
                     and 'const SOURCES' in p.read_text(encoding='utf-8'))
    if not paths and not args.fixture:
        parser.error('provide receipt scripts or --all')
    failed = 0
    for path in sorted(paths):
        errors = check(path, root)
        failed += bool(errors)
        print(f'{path.name}: ' + ('FAIL' if errors else 'PASS'))
        for error in errors:
            print('  ' + error)
    for name in args.fixture:
        path=root/name;errors=check_fixture(path,root);failed+=bool(errors)
        print(f'{path.name}: '+('FAIL' if errors else 'PASS'))
        for error in errors:print('  '+error)
    print(f'{len(paths)} scripts; {len(args.fixture)} fixtures; {failed} failed; source preflight only')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
