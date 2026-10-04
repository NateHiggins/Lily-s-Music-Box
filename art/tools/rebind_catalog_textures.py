"""Refresh only named catalogue texture pins after a reviewed material rebuild.

This preserves the proven cell geometry, lineage, inputs and resource paths.
It refuses unrelated texture changes and a changed protected input before writing.
"""
from pathlib import Path
import argparse
import copy
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.m11c2_floor01_production.export_floor01_cells import (
    PROTECTED_RELATIVE_PATHS, _json_bytes,
)

MANIFEST = Path('game/assets/building/floor_01_cells/floor01_asset_manifest.json')
REGISTRY = Path('game/data/floor_01_cell_registry.json')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_base(revision, path):
    return subprocess.check_output(['git', 'show', revision + ':' + path.as_posix()], cwd=ROOT)


def plan(base, keys):
    for key in keys:
        if not re.fullmatch(r'[a-z][a-z0-9_]*', key):
            raise ValueError('Invalid catalogue key: ' + key)
    mapping = json.loads((ROOT / 'art/textures/catalog_mapping.json').read_bytes())
    if not keys.issubset(mapping):
        raise ValueError('Unknown catalogue keys: ' + ', '.join(sorted(keys - mapping.keys())))
    old_manifest_bytes = (ROOT / MANIFEST).read_bytes()
    manifest = json.loads(old_manifest_bytes)
    registry = json.loads((ROOT / REGISTRY).read_bytes())
    if manifest != json.loads(read_base(base, MANIFEST)) or registry != json.loads(read_base(base, REGISTRY)):
        raise ValueError('Production metadata already differs from the reviewed base')
    if registry['asset_manifest_sha256'] != digest(old_manifest_bytes):
        raise ValueError('Current registry does not bind its current asset manifest')
    changed_protected = subprocess.check_output([
        'git', 'diff', '--name-only', base, '--',
        *[p.as_posix() for p in PROTECTED_RELATIVE_PATHS]], cwd=ROOT).decode().strip()
    if changed_protected:
        raise ValueError('Protected inputs differ: ' + changed_protected)
    # Validate every retained production cell against its bound immutable bytes.
    for cell in manifest['cells']:
        for kind in ('gltf', 'bin'):
            if digest((ROOT / cell[kind + '_path']).read_bytes()) != cell[kind + '_sha256']:
                raise ValueError('Cell geometry differs: ' + cell['id'])
    allowed = {'res://assets/building/textures/T_ai_materials_' + key + '_' + suffix + '.png'
               for key in keys for suffix in ('albedo', 'normal', 'rough')}
    revised = copy.deepcopy(manifest)
    rebound = []
    found = set()
    for row in revised['texture_bindings']:
        resource = row['resource_path']
        if not resource.startswith('res://assets/building/textures/'):
            raise ValueError('Unexpected texture binding: ' + resource)
        relative = Path('game') / resource.removeprefix('res://')
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT / 'game/assets/building/textures'):
            raise ValueError('Texture leaves the catalogue directory')
        data = path.read_bytes()
        current_hash = digest(data)
        if resource in allowed:
            found.add(resource)
            if digest(read_base(base, relative)) != row['sha256']:
                raise ValueError('Previous texture pin does not match the reviewed base: ' + resource)
            if current_hash != row['sha256'] or len(data) != row['bytes']:
                rebound.append({'resource_path': resource, 'before': row['sha256'], 'after': current_hash})
            row.update(sha256=current_hash, bytes=len(data))
        elif current_hash != row['sha256'] or len(data) != row['bytes']:
            raise ValueError('Unscoped texture differs: ' + resource)
    if found != allowed:
        raise ValueError('Some requested textures are not in the production cell catalogue')
    revised_bytes = _json_bytes(revised)
    revised_registry = copy.deepcopy(registry)
    revised_registry['asset_manifest_sha256'] = digest(revised_bytes)
    return revised_bytes, _json_bytes(revised_registry), rebound


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True, help='reviewed commit before this material change')
    parser.add_argument('--key', action='append', required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    manifest, registry, rebound = plan(args.base, set(args.key))
    if args.write:
        (ROOT / MANIFEST).write_bytes(manifest)
        (ROOT / REGISTRY).write_bytes(registry)
    print(json.dumps({'mode': 'write' if args.write else 'check', 'rebound': rebound,
                      'cell_geometry_unchanged': True, 'protected_inputs_unchanged': True}, indent=2))


if __name__ == '__main__':
    main()
