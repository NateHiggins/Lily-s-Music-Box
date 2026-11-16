"""Restore generated pet PNGs from their tracked GLBs before Godot import.

Godot 4.7.1 can skip extraction when a tracked PNG.import generator hash matches,
even if the ignored PNG is absent. Preserve those import settings and restore the
exact embedded bytes; never overwrite a different existing file.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import struct
import tempfile

PNG = b'\x89PNG\r\n\x1a\n'


def embedded_pngs(asset):
    raw = asset.read_bytes()
    if len(raw) < 20 or raw[:4] != b'glTF':
        raise ValueError(f'{asset.name}: not a GLB')
    version, length = struct.unpack_from('<II', raw, 4)
    if version != 2 or length != len(raw):
        raise ValueError(f'{asset.name}: invalid GLB header')
    chunks = {}
    offset = 12
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise ValueError(f'{asset.name}: truncated chunk')
        size, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        if size % 4 or offset + size > len(raw) or kind in chunks:
            raise ValueError(f'{asset.name}: invalid chunk bounds')
        chunks[kind] = raw[offset:offset + size]
        offset += size
    if 0x4E4F534A not in chunks or 0x004E4942 not in chunks:
        raise ValueError(f'{asset.name}: missing JSON/BIN chunk')
    document = json.loads(chunks[0x4E4F534A])
    binary = chunks[0x004E4942]
    outputs = {}
    for image in document.get('images', []):
        name = image.get('name', '')
        if not re.fullmatch(r'[A-Za-z0-9_-]+', name) or image.get('mimeType') != 'image/png':
            raise ValueError(f'{asset.name}: unsupported image name or format')
        index = image.get('bufferView')
        views = document.get('bufferViews', [])
        if type(index) is not int or not 0 <= index < len(views):
            raise ValueError(f'{asset.name}: invalid image buffer view')
        view = views[index]
        start, size = view.get('byteOffset', 0), view.get('byteLength')
        if view.get('buffer') != 0 or type(start) is not int or type(size) is not int or start < 0 or size <= 0 or start + size > len(binary):
            raise ValueError(f'{asset.name}: invalid embedded image range')
        data = binary[start:start + size]
        if not data.startswith(PNG):
            raise ValueError(f'{asset.name}: embedded image is not PNG')
        target = asset.with_name(asset.stem + '_' + name + '.png')
        if target.name in outputs:
            raise ValueError(f'{asset.name}: duplicate image name')
        outputs[target.name] = (target, data)
    if not outputs:
        raise ValueError(f'{asset.name}: no embedded PNGs')
    return list(outputs.values())


def prepare(project, check=False, force_scene_import=False):
    project = Path(project).resolve()
    folder = project / 'assets/characters/harukiya_pets'
    planned = []
    sources = []
    for name in ['judge.glb', 'lafitte.glb']:
        asset = folder / name
        if not asset.is_file():
            continue  # Other/minimal projects do not ship this asset family.
        sources.append({'file': name, 'sha256': hashlib.sha256(asset.read_bytes()).hexdigest()})
        planned.extend(embedded_pngs(asset))
    records = []
    # Validate the complete plan first. A conflict must not leave a partial restore.
    for target, data in planned:
        if target.resolve().parent != folder.resolve():
            raise ValueError('Generated map leaves its asset directory: ' + target.name)
        exists = target.exists()
        if exists and (not target.is_file() or target.read_bytes() != data):
            raise ValueError('Existing map differs from its embedded source; preserved: ' + target.name)
        records.append({'file': target.name, 'sha256': hashlib.sha256(data).hexdigest(),
                        'state': 'unchanged' if exists else ('missing' if check else 'restored')})
    if not check:
        for (target, data), record in zip(planned, records):
            if record['state'] != 'restored':
                continue
            handle, temporary = tempfile.mkstemp(prefix=target.name + '.', suffix='.restore', dir=folder)
            try:
                with os.fdopen(handle, 'wb') as stream:
                    stream.write(data)
                # Preserve a concurrently created file rather than replacing it.
                try:
                    if os.name == 'nt':
                        os.rename(temporary, target)  # Windows rename never replaces an existing target.
                    else:
                        os.link(temporary, target)
                except FileExistsError:
                    if target.read_bytes() != data:
                        raise ValueError('Concurrent map differs; preserved: ' + target.name)
            finally:
                Path(temporary).unlink(missing_ok=True)
    invalidated = []
    imports_required = False
    for source in sources:
        asset = folder / source['file']
        descriptor = asset.with_name(asset.name + '.import')
        if not descriptor.is_file():
            imports_required = True
            continue
        match = re.search(r'^path="res://(\.godot/imported/[^"\r\n]+\.scn)"$',
                          descriptor.read_text(encoding='utf-8'), re.MULTILINE)
        if not match or not re.fullmatch(re.escape(asset.name) + r'-[0-9a-f]{32}\.scn', Path(match[1]).name):
            raise ValueError('Unexpected pet scene import path: ' + asset.name)
        scene = project / match[1]
        marker = scene.with_suffix('.md5')
        if marker.resolve().parent != (project / '.godot/imported').resolve():
            raise ValueError('Scene import marker leaves the project import cache')
        restored = any(r['state'] == 'restored' and r['file'].startswith(asset.stem + '_') for r in records)
        if (restored or force_scene_import) and not check and marker.is_file():
            prior = marker.read_bytes()
            invalidated.append({'file': marker.relative_to(project).as_posix(),
                                'sha256': hashlib.sha256(prior).hexdigest(), 'prior_bytes_hex': prior.hex()})
            # Only this exact generated freshness marker is retired. Keep the
            # cached scene itself; the next editor import must reconstruct it.
            marker.unlink()
        imports_required = imports_required or restored or not marker.is_file() or not scene.is_file()
    missing = sum(r['state'] == 'missing' for r in records)
    return {'status': 'FAIL' if missing else 'PASS', 'sources': sources, 'maps': records,
            'restored': sum(r['state'] == 'restored' for r in records), 'missing': missing,
            'imports_required': imports_required, 'invalidated_scene_imports': invalidated,
            'scope': 'Exact embedded PNG byte restoration; Godot import/loaded mip verification remains required.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--quiet', action='store_true')
    parser.add_argument('--require-ready', action='store_true', help='Refuse runtime until editor import has rebuilt pet scenes.')
    parser.add_argument('--force-scene-import', action='store_true', help='Refresh pet scenes after the PNG texture import pass.')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    try:
        result = prepare(args.project, args.check, args.force_scene_import)
    except (OSError, ValueError, KeyError, TypeError, struct.error) as error:
        parser.exit(1, 'Pet map preparation failed: ' + str(error) + '\n')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    if args.quiet and (result['restored'] or result['missing']):
        print('[PET MAPS] ' + json.dumps({k: result[k] for k in ['status', 'restored', 'missing', 'imports_required']}))
    elif not args.quiet:
        print(json.dumps(result, indent=2))
    if args.require_ready and result['imports_required']:
        print('Pet scenes need editor import after map restoration; run the lane import twice before runtime.', file=__import__('sys').stderr)
        return 2
    return 0 if result['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
