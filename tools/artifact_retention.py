"""Inventory and retire explicitly released visual artifacts from Orison reports."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path, PureWindowsPath
import re
import stat
import subprocess
import sys


REPORTS = Path('C:/ov/reports')
TOOLS = Path(__file__).resolve().parent
MANIFEST = '.orison-retention.json'
QUARANTINE = '.orison-quarantine'
VISUAL = {'.png', '.jpg', '.jpeg', '.webp', '.mp4', '.mov', '.mkv', '.avi', '.exr', '.tif', '.tiff'}
METADATA = {'.json', '.jsonl', '.md', '.txt', '.csv', '.tsv', '.log'}
HOLD_DAYS = {'preview': 14, 'rejected-seed': 30}
QUARANTINE_DAYS = 14


def now():
    return datetime.now(timezone.utc)


def check(condition, message):
    if not condition:
        raise ValueError(message)


def plain(path):
    """lstat, including junctions and other Windows reparse points."""
    info = path.lstat()
    check(not stat.S_ISLNK(info.st_mode) and not (
        getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT
    ), f'Reparse point refused: {path}')
    return info


def relative(name):
    parts = name.split('/')
    check(not PureWindowsPath(name).anchor and all(
        part and not part.startswith('.') and not part.endswith((' ', '.'))
        and not any(c in '\\:*?"<>|' or ord(c) < 32 for c in part)
        and not PureWindowsPath(part).is_reserved()
        for part in parts
    ), f'Use a plain slash-separated relative path: {name}')
    return Path(*parts)


def directory(path, *, create=False):
    if create:
        path.mkdir(exist_ok=True)
    check(stat.S_ISDIR(plain(path).st_mode), f'Not a directory: {path}')
    return path


def rooted(root, child, *, create=False):
    path = root
    for part in child.parts:
        path = directory(path / part, create=create)
        check(not os.path.lexists(path / '.git'), f'Git checkout refused: {path}')
    return path


def report_root(root):
    root = root.absolute()
    for folder in (*reversed(root.parents), root):
        directory(folder)
        check(not os.path.lexists(folder / '.git'), f'Git checkout refused: {folder}')
    return root


def file_state(path):
    before = plain(path)
    check(stat.S_ISREG(before.st_mode) and before.st_nlink == 1, f'Not an ordinary single-link file: {path}')
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    after = plain(path)
    check(after.st_nlink == 1 and all(getattr(before, key) == getattr(after, key) for key in (
        'st_dev', 'st_ino', 'st_size', 'st_mtime_ns', 'st_ctime_ns'
    )), f'File changed while reading: {path}')
    return {'bytes': after.st_size, 'mtime_ns': after.st_mtime_ns, 'sha256': digest}


def member(case, name, *, create=False):
    path = relative(name)
    return rooted(case, path.parent, create=create) / path.name


def matches(path, expected):
    check(file_state(path) == expected, f'File no longer matches the plan: {path}')


def read(path):
    plain(path)
    return json.loads(path.read_bytes())


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode('utf-8')


def write_new(path, value):
    # The lock makes the temporary name private to this transaction. A leftover
    # temporary file is kept for inspection and never silently overwritten.
    temp = path.with_name(path.name + '.pending')
    check(not os.path.lexists(path), f'Already exists: {path}')
    with temp.open('xb') as stream:
        stream.write(encoded(value))
        stream.flush()
        os.fsync(stream.fileno())
    temp.rename(path)


@contextmanager
def mutation():
    """Use the existing Godot mutex without queueing or preempting a producer."""
    import ctypes
    from ctypes import wintypes

    check(sys.platform == 'win32', 'Report mutations require the Windows project host')
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateMutexW.argtypes = [wintypes.LPVOID, wintypes.BOOL, wintypes.LPCWSTR]
    kernel.CreateMutexW.restype = wintypes.HANDLE
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.WaitForSingleObject.restype = wintypes.DWORD
    kernel.ReleaseMutex.argtypes = kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel.CreateMutexW(None, False, 'Global\\OrisonGodotSingleInstance')
    check(handle, 'Could not open the Godot lane mutex')
    acquired = False
    try:
        acquired = kernel.WaitForSingleObject(handle, 0) in (0, 0x80)
        check(acquired, 'Godot lane is active. Retry after it releases.')
        result = subprocess.run(['pwsh', '-NoProfile', '-Command',
            ". ./lane_common.ps1; if (@(Get-OrisonLaneQueue).Count -or "
            "@(Get-Process -Name 'Godot*' -ErrorAction SilentlyContinue).Count) { exit 73 }"],
            cwd=TOOLS, check=False)
        check(result.returncode == 0, 'Live or queued lane work, or lane census unavailable')
        yield
    finally:
        if acquired:
            kernel.ReleaseMutex(handle)
        kernel.CloseHandle(handle)


def completed(path):
    value = read(path)
    execution = value.get('execution', {})
    receipt = execution.get('completed') is True and type(execution.get('exit_code')) is int
    terminal = isinstance(value.get('finished_utc'), str) and (
        type(value.get('batch_exit')) is int or type(value.get('exit')) is int)
    check(receipt or terminal, 'Expected a completed run receipt or terminal record')


def case_path(root, name):
    return rooted(root, relative(name))


def verify_local_references(case, files, producer_records):
    # A secondary guard for the manifests, receipts and review notes beside a
    # run. The owner still checks consumers outside the case before release.
    needles = [(row['path'], (relative(row['path']).name.casefold(), row['state']['sha256'])) for row in files]
    for name, expected in producer_records.items():
        matches(member(case, name), expected)

    def unavailable(error):
        raise error

    for folder, dirs, names in os.walk(case, followlinks=False, onerror=unavailable):
        folder = Path(folder)
        for name in dirs:
            directory(folder / name)
            check(name != '.git', f'Nested Git directory refused: {folder / name}')
        for name in names:
            check(name != '.git', f'Nested Git checkout refused: {folder}')
            if name == MANIFEST:
                check(folder == case, f'Overlapping retention case: {folder}')
                continue
            path = folder / name
            if path.suffix.casefold() not in METADATA or path.relative_to(case).as_posix() in producer_records:
                continue
            check(stat.S_ISREG(plain(path).st_mode), f'Not a regular metadata file: {path}')
            with path.open('rb') as stream:
                bom = stream.read(2)
            encoding = 'utf-16' if bom in (b'\xff\xfe', b'\xfe\xff') else 'utf-8-sig'
            with path.open(encoding=encoding, errors='replace') as stream:
                for line in stream:
                    folded = line.casefold()
                    for visual, tokens in needles:
                        check(not any(token in folded for token in tokens), f'{path} may reference {visual}')


def record(root, case_name, owner, terminal, previews, rejected, pins, producer_records=()):
    case = case_path(root, case_name)
    check(owner.strip() and (previews or rejected), 'Record an owner and at least one exact disposable file')
    terminal_path = member(case, terminal)
    check(terminal_path.suffix.casefold() == '.json', 'Terminal must be a JSON file')
    completed(terminal_path)
    protected = [terminal, *pins]
    for name in pins:
        file_state(member(case, name))
    names = [*protected, *previews, *rejected, *producer_records]
    check(len(set(name.casefold() for name in names)) == len(names), 'Duplicate or pinned paths in release list')
    closed = now()
    files = []
    for kind, group in (('preview', previews), ('rejected-seed', rejected)):
        for name in group:
            path = member(case, name)
            check(path.suffix.casefold() in VISUAL, f'Only visual outputs can be released: {name}')
            files.append({'path': name, 'kind': kind, 'state': file_state(path)})
    for parent in case.parents:
        if parent == root:
            break
        check(not os.path.lexists(parent / MANIFEST), f'Overlapping retention case: {parent}')
    provenance = {}
    for name in producer_records:
        path = member(case, name)
        check(path.suffix.casefold() in {'.json', '.log', '.txt'}, f'Not an output index or log: {name}')
        provenance[name] = file_state(path)
    verify_local_references(case, files, provenance)
    manifest = {'schema': 1, 'case': case_name, 'owner': owner, 'recorded_utc': closed.isoformat(),
                'eligible_utc': (closed + timedelta(days=max(HOLD_DAYS[f['kind']] for f in files))).isoformat(),
                'terminal': terminal, 'terminal_state': file_state(terminal_path),
                'pins': pins, 'producer_records': provenance, 'files': files}
    write_new(case / MANIFEST, manifest)
    return plan(root, case_name)


def plan_id(manifest):
    return hashlib.sha256(encoded(manifest)).hexdigest()


def plan(root, case_name):
    case = case_path(root, case_name)
    manifest = read(case / MANIFEST)
    check(manifest['schema'] == 1 and manifest['case'] == case_name, 'Manifest does not belong to this case')
    validate_rows(manifest)
    matches(member(case, manifest['terminal']), manifest['terminal_state'])
    return {**manifest, 'plan_id': plan_id(manifest), 'eligible': now() >= datetime.fromisoformat(manifest['eligible_utc']),
            'logical_bytes': sum(row['state']['bytes'] for row in manifest['files'])}


def validate_rows(manifest):
    files = manifest['files']
    keys = {name.casefold() for name in [manifest['terminal'], *manifest['pins']]}
    for name in manifest['producer_records']:
        check(name.casefold() not in keys and relative(name).suffix.casefold() in {'.json', '.log', '.txt'},
              f'Invalid producer record: {name}')
        keys.add(name.casefold())
    check(files, 'Empty release list')
    for row in files:
        name = row['path']
        check(name.casefold() not in keys and relative(name).suffix.casefold() in VISUAL
              and row['kind'] in HOLD_DAYS, f'Invalid release path: {name}')
        keys.add(name.casefold())
    earliest = datetime.fromisoformat(manifest['recorded_utc']) + timedelta(days=max(HOLD_DAYS[f['kind']] for f in files))
    check(datetime.fromisoformat(manifest['eligible_utc']) == earliest, 'Release date differs from retention policy')


def journal_path(root, identity, *, create=False):
    check(re.fullmatch(r'[0-9a-f]{64}', identity), 'Use the full plan ID')
    quarantine = directory(root / QUARANTINE, create=create)
    return directory(quarantine / identity, create=create)


def transfer(case, payload, files, *, restore=False):
    # Validate every original and quarantined location before moving any file.
    # The immutable plan plus the actual location of each hash is the journal.
    moves = []
    for row in files:
        src = member(case, row['path'])
        dst = member(payload, row['path'], create=True)
        if restore:
            src, dst = dst, src
        at_source, at_target = os.path.lexists(src), os.path.lexists(dst)
        check(at_source != at_target, f'Missing or colliding file: {row["path"]}')
        matches(src if at_source else dst, row['state'])
        if at_source:
            check(src.stat().st_dev == dst.parent.stat().st_dev, 'Quarantine must stay on the original volume')
            moves.append((src, dst, row['state']))
    for src, dst, expected in moves:
        matches(src, expected)
        check(not os.path.lexists(dst), f'Destination occupied: {dst}')
        src.rename(dst)


def quarantine(root, case_name, identity):
    proposed = plan(root, case_name)
    check(proposed.pop('plan_id') == identity, 'Approval does not match the current plan')
    check(proposed.pop('eligible'), 'Retention period has not elapsed')
    proposed.pop('logical_bytes')
    case = case_path(root, case_name)
    verify_local_references(case, proposed['files'], proposed['producer_records'])
    journal = journal_path(root, identity, create=True)
    manifest_path = journal / 'plan.json'
    if not manifest_path.exists():
        write_new(manifest_path, proposed)
    check(read(manifest_path) == proposed, 'Quarantine plan differs from the approved plan')
    check(not any(os.path.lexists(journal / f) for f in ('restoring.json', 'purging.json')),
          'This plan is already restoring or purging')
    transfer(case, directory(journal / 'files', create=True), proposed['files'])
    marker = journal / 'quarantined.json'
    if not marker.exists():
        write_new(marker, {'utc': now().isoformat()})


def transaction(root, identity):
    journal = journal_path(root, identity)
    manifest = read(journal / 'plan.json')
    check(plan_id(manifest) == identity, 'Quarantine plan hash differs')
    validate_rows(manifest)
    return journal, manifest


def restore(root, identity):
    journal, manifest = transaction(root, identity)
    check(not os.path.lexists(journal / 'purging.json'), 'Purge has started')
    marker = journal / 'restoring.json'
    if not marker.exists():
        write_new(marker, {'utc': now().isoformat()})
    transfer(case_path(root, manifest['case']), directory(journal / 'files', create=True),
             manifest['files'], restore=True)
    if not (journal / 'restored.json').exists():
        write_new(journal / 'restored.json', {'utc': now().isoformat()})


def purge(root, identity):
    journal, manifest = transaction(root, identity)
    check(not os.path.lexists(journal / 'restoring.json'), 'Restore has started')
    earliest = datetime.fromisoformat(read(journal / 'quarantined.json')['utc']) + timedelta(days=QUARANTINE_DAYS)
    check(now() >= earliest, 'Quarantine period has not elapsed')
    case = case_path(root, manifest['case'])
    check(read(case / MANIFEST) == manifest, 'Source release has changed')
    matches(member(case, manifest['terminal']), manifest['terminal_state'])
    verify_local_references(case, manifest['files'], manifest['producer_records'])
    marker = journal / 'purging.json'
    prior = os.path.lexists(marker)
    if prior:
        check(read(marker)['plan_id'] == identity, 'Purge approval differs')
    payload = directory(journal / 'files')
    remaining = []
    for row in manifest['files']:
        check(not os.path.lexists(member(case, row['path'])), f'Original path is occupied: {row["path"]}')
        path = member(payload, row['path'])
        if prior and not os.path.lexists(path):
            continue
        matches(path, row['state'])
        remaining.append((path, row['state']))
    if not prior:
        write_new(marker, {'utc': now().isoformat(), 'plan_id': identity})
    for path, state in remaining:
        matches(path, state)
        path.unlink()
    if not (journal / 'purged.json').exists():
        write_new(journal / 'purged.json', {'utc': now().isoformat(), 'files': len(manifest['files'])})


def inventory(root):
    totals = {}
    skipped = 0
    def unavailable(_error):
        nonlocal skipped
        skipped += 1

    for folder, dirs, files in os.walk(root, followlinks=False, onerror=unavailable):
        folder = Path(folder)
        parts = folder.relative_to(root).parts
        group = parts[0] if parts else '(root files)'
        row = totals.setdefault(group, {'files': 0, 'logical_bytes': 0, 'visual_bytes': 0})
        for name in [*dirs, *files]:
            try:
                info = plain(folder / name)
            except (ValueError, OSError):
                skipped += 1
                if name in dirs:
                    dirs.remove(name)
                continue
            if stat.S_ISREG(info.st_mode):
                row['files'] += 1
                row['logical_bytes'] += info.st_size
                if Path(name).suffix.casefold() in VISUAL:
                    row['visual_bytes'] += info.st_size
    return {'groups': dict(sorted(totals.items(), key=lambda item: -item[1]['logical_bytes'])),
            'skipped_entries': skipped}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command')
    commands.add_parser('inventory', help='read-only logical sizes (the default)')
    for name in ('record', 'plan', 'quarantine'):
        command = commands.add_parser(name)
        command.add_argument('case', help='slash-separated path under C:/ov/reports')
        if name == 'record':
            command.add_argument('--owner', required=True)
            command.add_argument('--terminal', required=True)
            command.add_argument('--preview', action='append', default=[])
            command.add_argument('--rejected-seed', action='append', default=[])
            command.add_argument('--pin', action='append', default=[])
            command.add_argument('--producer-record', action='append', default=[],
                                 help='exact output-only index or log, checked and preserved by hash')
            command.add_argument('--confirm-closed-and-unreferenced', action='store_true', required=True)
        if name == 'quarantine':
            command.add_argument('--approve', required=True, help='exact plan ID from plan')
    commands.add_parser('restore').add_argument('plan_id')
    commands.add_parser('purge').add_argument('--approve', required=True, help='exact quarantined plan ID')
    args = parser.parse_args()
    try:
        root = report_root(REPORTS)
        if args.command in (None, 'inventory'):
            result = inventory(root)
        elif args.command == 'plan':
            result = plan(root, args.case)
        else:
            with mutation():
                if args.command == 'record':
                    result = record(root, args.case, args.owner, args.terminal, args.preview,
                                    args.rejected_seed, args.pin, args.producer_record)
                elif args.command == 'quarantine':
                    quarantine(root, args.case, args.approve)
                    result = {'quarantined': args.approve}
                elif args.command == 'restore':
                    restore(root, args.plan_id)
                    result = {'restored': args.plan_id}
                else:
                    purge(root, args.approve)
                    result = {'purged': args.approve}
        print(json.dumps(result, indent=2))
    except (OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, f'Retention refused: {exc}\n')


if __name__ == '__main__':
    main()
