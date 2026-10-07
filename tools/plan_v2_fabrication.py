#!/usr/bin/env python3
"""Read-only dirty-family inventory. A snapshot is a queue, never acceptance evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXT = {'.json', '.gd', '.gdshader', '.gdshaderinc', '.py', '.gltf', '.import', '.tscn', '.tres', '.godot'}
BATCH_MODULES = {'work_tables', 'reading_nook', 'task_lamps', 'photo_radio_fittings', 'radio_display', 'cobbler_fittings', 'druggist_cupboard', 'locksmith_fittings', 'hardware_stock', 'news_fittings', 'shop_clerestories', 'shop_joinery', 'diner_counter', 'diner_till', 'hardware_tools', 'photo_cameras',
                 'photo_counter', 'photo_enlargers', 'photo_portraits', 'photo_stock', 'radio_wire',
                 'pawn_clocks', 'pawn_display', 'pawn_fittings',
                 'laundry_fittings', 'laundry_apparatus', 'laundry_trade'}
# These older fixtures precede the common filename/runtime.asset convention.
ALIASES = {'front_pavement_construction': 'front_pavement'}
ASSETS = {'city_closure': 'res://assets/props/city_shells.glb'}

def digest(path: Path) -> str:
    if not path.is_file():
        return 'MISSING'
    data = path.read_bytes()
    if path.suffix in TEXT:
        data = data.replace(b'\r\n', b'\n')
    return hashlib.sha256(data).hexdigest()


def signature(values: dict) -> str:
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()


def make_plan(root: Path, baseline: dict | None = None, selected: list[str] | None = None) -> dict:
    hashes: dict[str, str] = {}

    def hashed(relative: str) -> str:
        path = (root / relative).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError(f'Input escapes repository: {relative}')
        if relative not in hashes:
            hashes[relative] = digest(path)
        return hashes[relative]

    def inputs(paths) -> dict:
        return {p: hashed(p) for p in sorted(set(paths))}

    # A shared runtime/shader/material edit invalidates every registered family.
    # This costs hashes, not world launches. Cache shared bytes once per plan.
    shared_paths = ['game/project.godot']
    for folder in ['game/scripts', 'game/shaders', 'game/scenes/building', 'game/data/orison_v2']:
        shared_paths += [p.relative_to(root).as_posix() for p in (root / folder).rglob('*')
                         if p.is_file() and p.suffix in TEXT]
    shared = signature(inputs(shared_paths))
    previous = {row['family']: row for row in (baseline or {}).get('families', [])}
    families = []
    builders = set()
    for fixture in sorted((root / 'game/tests/fixtures').glob('orison_*.json')):
        data = json.loads(fixture.read_text(encoding='utf-8'))
        if not isinstance(data, dict) or not data.get('source_bindings'):
            continue
        family = fixture.stem.removeprefix('orison_')
        stem = ALIASES.get(family, family)
        sources = data['source_bindings']
        builder = f'art/blender/scripts/build_{stem}.py'
        inspector = f'art/blender/scripts/inspect_{stem}.py'
        if (root / builder).is_file(): builders.add(builder)
        asset = data.get('runtime', {}).get('asset', ASSETS.get(family, f'res://assets/props/{stem}.glb'))
        asset = asset.removeprefix('res://')
        asset = 'game/' + asset
        native = f'art/blender/{stem}.blend'
        runtime_data = f'game/data/orison_v2/{stem}.json'
        validator = f'game/tests/orison_v2_{stem}_test.gd'
        paths = list(sources) + [fixture.relative_to(root).as_posix(), asset, native]
        paths += [p for p in [runtime_data, builder, inspector, validator] if (root / p).is_file()]
        # Include inherited test helpers: changing a helper must invalidate QA reuse.
        import re
        parent = root / validator
        while parent.is_file():
            paths.append(parent.relative_to(root).as_posix())
            match = re.search(r'^extends "res://([^\"]+)"', parent.read_text(encoding='utf-8'))
            if not match: break
            next_parent = root / 'game' / match[1]
            if next_parent == parent or next_parent.relative_to(root).as_posix() in paths: break
            parent = next_parent
        current = inputs(paths)
        stale = [p for p, expected in sources.items() if current[p] != expected]
        if current[asset] != data.get('asset_sha256'): stale.append(asset)
        prior = previous.get(family)
        changed = [p for p in sorted(set(current) | set((prior or {}).get('inputs', {})))
                   if current.get(p) != (prior or {}).get('inputs', {}).get(p)]
        runtime_changed = prior is None or prior.get('shared_runtime') != shared
        dirty = bool(changed or runtime_changed)
        families.append({
            'family': family, 'builder': builder if (root / builder).is_file() else None,
            'inspector': inspector if (root / inspector).is_file() else None,
            'batch_module': family if family in BATCH_MODULES else None,
            'source_status': 'REVIEW_DRIFT' if stale else 'BOUND',
            'stale_bindings': stale, 'missing': [p for p, h in current.items() if h == 'MISSING'],
            'dirty': dirty, 'changed_inputs': changed, 'shared_runtime_changed': runtime_changed,
            'inputs': current, 'shared_runtime': shared,
            'fingerprint': signature({'inputs': current, 'shared_runtime': shared}),
        })
    names = {row['family'] for row in families}
    if selected and set(selected) - names:
        raise ValueError('Unregistered families: ' + ', '.join(sorted(set(selected) - names)))
    selected_rows = [row for row in families if not selected or row['family'] in selected]
    dirty_rows = [row for row in selected_rows if row['dirty']]
    return {
        'schema': 'orison.fabrication-plan.v1', 'evidence_class': 'INERT',
        'scope': 'Build/review triage only. BOUND means source hashes match, not that appearance is accepted.',
        'families': families, 'selected': [row['family'] for row in selected_rows],
        'queue': [row['family'] for row in dirty_rows],
        'review_queue': [row['family'] for row in selected_rows if row['stale_bindings'] or row['missing']],
        'batch_modules': [row['batch_module'] for row in dirty_rows if row['batch_module']],
        'standalone_validators': [row['family'] for row in dirty_rows if not row['batch_module']],
        'unregistered_builders': sorted(p.relative_to(root).as_posix()
            for p in (root / 'art/blender/scripts').glob('build_*.py')
            if p.relative_to(root).as_posix() not in builders),
        'summary': {'registered': len(families), 'selected': len(selected_rows), 'dirty': len(dirty_rows),
                    'source_drift': sum(bool(row['stale_bindings']) for row in selected_rows),
                    'missing': sum(bool(row['missing']) for row in selected_rows)},
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, help='Earlier plan; unchanged fingerprints may reuse its separately retained QA')
    parser.add_argument('--family', action='append', help='Limit queue; inventory still covers every bound family')
    parser.add_argument('--out', type=Path, default=Path('tmp/v2-fabrication/plan.json'))
    args = parser.parse_args()
    baseline = json.loads(args.baseline.read_text()) if args.baseline else None
    if baseline and baseline.get('schema') != 'orison.fabrication-plan.v1':
        parser.error('baseline must be a fabrication-plan.v1 snapshot')
    plan = make_plan(ROOT, baseline, args.family)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(plan, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps({'plan': str(args.out), **plan['summary'], 'batch_modules': plan['batch_modules'],
                      'unregistered_builders': len(plan['unregistered_builders'])}))


if __name__ == '__main__':
    main()
