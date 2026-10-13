#!/usr/bin/env python3
"""Check spatial receipt SOURCES closure before spending time in Godot.

Read-only. This checks declarations, not runtime behavior or receipt acceptance.
"""
import argparse
import re
from pathlib import Path

REFERENCES = re.compile(r'res://tests/[A-Za-z0-9_/.-]+')
SOURCES = re.compile(r'const\s+SOURCES\s*(?::[^=\n]+)?\s*(?::=|=)\s*\[(.*?)\]', re.S)


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
    args = parser.parse_args(argv)
    root = args.root.resolve()
    paths = {root / name for name in args.paths}
    if args.all:
        paths.update(p for p in (root / 'game/tests').glob('*.gd')
                     if 'test_dependencies' in p.read_text(encoding='utf-8')
                     and 'const SOURCES' in p.read_text(encoding='utf-8'))
    if not paths:
        parser.error('provide receipt scripts or --all')
    failed = 0
    for path in sorted(paths):
        errors = check(path, root)
        failed += bool(errors)
        print(f'{path.name}: ' + ('FAIL' if errors else 'PASS'))
        for error in errors:
            print('  ' + error)
    print(f'{len(paths)} scripts; {failed} failed; source preflight only')
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
