"""Compile exact original all-shop raw-stock selections; no installer or geometry rewrite.

Only game/tests/fixtures/arcade_all_raw_projection.json is generated. Diner's
existing raw_projection remains authoritative. No import settings are changed.
"""
from __future__ import annotations
import argparse
import collections
import copy
import json
from pathlib import Path
import re
from prepare_arcade_native_projection import (
    SourceCell, RAW_TOLERANCE, boundary_match, matrix, raw_bounds, raw_projection,
    require, resource, select_raw_faces, sha, transformed_bounds, validate_box_faces,
)
from prepare_arcade_retained_equipment import normalized_record_hash

ROOT = Path(__file__).resolve().parents[1]
PLAN = Path('art/data/arcade_plaza/retained_equipment_placements.json')
REGISTRY = Path('game/data/floor_01_cell_registry.json')
FIXTURE = Path('game/tests/fixtures/arcade_all_raw_projection.json')
KEEP_ACTIONS = {'retained_raw_stock_needing_native_rebuild_placement', 'KEEP_ORIGINAL_SOURCE_STOCK_RIGID_CANDIDATE'}
# Actual original source material identities. These stocks are still six-face
# boxes; their unbaked material names must not be rewritten to invented _b keys.
UNSUFFIXED_MATERIALS = {
    'storm_shop_radio_service_scope_face': 'M_screen',
    'site_rear_funeral_parlour_chapel_rail_cap': 'M_oak_quartered',
}


def records_for_floor(fabrication):
    floors = [f for f in fabrication['floors'] if f['id'] == 'F01']
    require(len(floors) == 1, 'F01 source missing or duplicate')
    records = {}
    for row in floors[0]['furniture']:
        require(row['id'] not in records, 'duplicate fabrication stock')
        records[row['id']] = row
    return records


def select_original_faces(cell, stocks):
    normal = [s for s in stocks if s['id'] not in UNSUFFIXED_MATERIALS]
    selected = select_raw_faces(cell, normal)
    for stock in stocks:
        if stock['id'] not in UNSUFFIXED_MATERIALS:
            continue
        material = UNSUFFIXED_MATERIALS[stock['id']]
        require(material == 'M_' + stock['source_record']['mat'], 'exception source material changed')
        selected[stock['id']] = [f for f in cell.faces if f['binding']['material_name'] == material
                                 and boundary_match(f['points'], stock['source_low'], stock['source_high'])]
    owners = {}
    for stock in stocks:
        for f in selected[stock['id']]:
            key = (f['binding']['node_index'], f['binding']['primitive_index'], f['triangle'])
            require(key not in owners, 'duplicate original facet ownership: ' + stock['id'])
            owners[key] = stock['id']
    return selected


def selection_contract(faces, stock):
    try:
        require(len(faces) == 12, 'expected12 actual box triangles')
        validate_box_faces(faces, stock)
    except ValueError as exc:
        # Do not omit an unsupported stock or replace it by its source AABB.
        # The original source/geometry witness remains visible in this refusal.
        witness = dict(id=stock['id'], source_record=stock['source_record'],
                       source_low=stock['source_low'], source_high=stock['source_high'],
                       selected_faces=[dict(node=f['binding']['node'], primitive=f['binding']['primitive_index'],
                                            triangle=f['triangle'], indices=f['indices'], points=f['points'],
                                            material=f['binding']['material_name']) for f in faces])
        raise ValueError('unsupported original raw shape: ' + json.dumps(witness, sort_keys=True) + ': ' + str(exc)) from exc
    primitives = {}
    for face in faces:
        key = (face['binding']['node_index'], face['binding']['primitive_index'])
        if key not in primitives:
            primitives[key] = dict(face['binding'], selected_triangle_indices=[], selected_indices=[])
        primitives[key]['selected_triangle_indices'].append(face['triangle'])
        primitives[key]['selected_indices'].extend(face['indices'])
    return dict(id=stock['id'], group=stock['group'], source_record=stock['source_record'],
                source_low=stock['source_low'], source_high=stock['source_high'],
                delta_transform=stock['delta_transform'], target_low=stock['target_low'], target_high=stock['target_high'],
                expected_triangles=len(faces), source_selections=list(primitives.values()),
                selection_kind='original_box_unsuffixed_material' if stock['id'] in UNSUFFIXED_MATERIALS else 'original_box')


def build(root=ROOT, plan=None):
    root = Path(root)
    doc = json.loads((root/PLAN).read_text(encoding='utf-8')) if plan is None else copy.deepcopy(plan)
    require(doc.get('schema_version') == 1 and len(doc['cells']) == 11 and len(set(doc['cells'])) == 11, 'all11 cells required')
    bindings = {}
    for name, binding in doc['source_bindings'].items():
        require(binding['kind'] in ('lf', 'raw'), 'unknown source binding kind')
        path = root/name
        require(path.resolve().is_relative_to(root.resolve()), 'source escapes repository')
        require(sha(path, binding['kind'] == 'lf') == binding['sha256'], 'source binding changed: ' + name)
        bindings[name] = binding
    fabrication = json.loads((root/doc['fabrication']).read_text(encoding='utf-8'))
    records = records_for_floor(fabrication)
    diner = json.loads((root/doc['diner_plan']).read_text(encoding='utf-8'))
    expected = {r['id'] for r in doc['source_dispositions'] if r['action'] in KEEP_ACTIONS}
    require(len(expected) == 102, 'all102 retained original raw IDs required')
    groups = []
    for group in doc['groups']:
        require(group['cell'] != 'shop_luncheonette', 'Diner declarations must use authoritative raw_projection')
        groups.append(group)
    # Original Diner raw_projection validates its records, group relationship,
    # source import precision and facets; never fork that logic here.
    diner_rows, diner_bindings = raw_projection(root, diner)
    by_cell = collections.defaultdict(list)
    seen = set()
    group_ids = set()
    for group in groups:
        require(group['cell'] in doc['cells'], 'foreign raw cell')
        key = (group['cell'], group['id'])
        require(key not in group_ids, 'duplicate placement group')
        group_ids.add(key)
        delta = matrix(group['delta_transform'], rigid=True)
        for row in group['raw_stocks']:
            identity = row['id']
            require(identity in expected and identity in records, 'missing or foreign original stock: ' + identity)
            require(identity not in seen, 'duplicate retained raw stock')
            seen.add(identity)
            require(row['source_record'] == records[identity], 'literal original stock record changed: ' + identity)
            low, high = raw_bounds(records[identity])
            require((row['source_low'], row['source_high']) == (low, high), 'false raw source bounds')
            target_low, target_high = transformed_bounds(delta, low, high)
            require(max(abs(a-b) for a,b in zip(target_low+target_high, row['target_low']+row['target_high'])) <= 1e-10, 'raw target differs from rigid source')
            by_cell[group['cell']].append(dict(row, cell=group['cell'], group=group['id'], delta_transform=delta))
    for row in diner_rows:
        require(row['id'] not in seen and row['id'] in expected, 'duplicate or foreign Diner raw stock')
        seen.add(row['id'])
    require(seen == expected, 'missing retained raw stocks')
    projected = {(r['cell'], r['id']): r for r in doc['projection']['raw_entries']}
    require(len(projected) == len(doc['projection']['raw_entries']) == 102, 'projection raw IDs missing or duplicated')
    all_rows = [r for rows in by_cell.values() for r in rows] + [dict(r, cell='shop_luncheonette') for r in diner_rows]
    require(set(projected) == {(r['cell'], r['id']) for r in all_rows}, 'raw projection inventory differs')
    for row in all_rows:
        p = projected[(row['cell'], row['id'])]
        for key in ('source_low', 'source_high', 'delta_transform', 'target_low', 'target_high'):
            require(p[key] == row[key], 'canonical raw projection changed: ' + row['id'] + '/' + key)
        require(p['source_record_sha256'] == normalized_record_hash('furniture', row['source_record']), 'canonical raw record hash changed')
    registry = json.loads((root/REGISTRY).read_text(encoding='utf-8'))
    bindings[REGISTRY.as_posix()] = dict(kind='lf', sha256=sha(root/REGISTRY, True))
    manifest_name = registry['asset_manifest_path']
    require(sha(resource(root, manifest_name), True) == registry['asset_manifest_sha256'], 'original asset manifest changed')
    bindings['game/'+manifest_name[6:]] = dict(kind='lf', sha256=registry['asset_manifest_sha256'])
    cells = []
    for identity in sorted(doc['cells']):
        source = 'res://assets/building/floor_01_cells/' + identity + '.gltf'
        registered = [r for r in registry['cells'] if r['resource_path'] == source]
        require(len(registered) == 1, 'original cell absent or duplicated: ' + identity)
        registered = registered[0]
        require(sha(resource(root, source), True) == registered['gltf_sha256'], 'original cell source changed: ' + identity)
        buffers = {registered['bin_resource_path']: registered['bin_sha256']}
        cell_bindings = {source: dict(kind='lf', sha256=registered['gltf_sha256'])}
        if identity == 'shop_luncheonette':
            require(source == diner['cell_source'] and buffers == diner['cell_buffers'], 'Diner original cell binding differs')
            rows = [dict(r, group=projected[(identity, r['id'])]['group'], selection_kind='authoritative_diner_original_box') for r in diner_rows]
            cell_bindings.update(diner_bindings)
        else:
            cell = SourceCell(root, source, buffers)
            cell_bindings.update(cell.buffer_bindings)
            selected = select_original_faces(cell, by_cell[identity])
            rows = [selection_contract(selected[r['id']], r) for r in by_cell[identity]]
        imported = source + '.import'
        text = resource(root, imported).read_text(encoding='utf-8')
        cell_bindings[imported] = dict(kind='lf', sha256=sha(resource(root, imported), True))
        # Merely record existing state. Other cell compression needs real loaded
        # evidence before any change; this compiler never edits .import files.
        compression = re.search(r'^meshes/force_disable_compression=(true|false)$', text, re.M)
        bindings.update({'game/'+name[6:]: binding for name, binding in cell_bindings.items()})
        ownership = set()
        for row in rows:
            for selection in row['source_selections']:
                require(len(selection['selected_indices']) == 3*len(selection['selected_triangle_indices']), 'raw triangle/index contract differs')
                for triangle in selection['selected_triangle_indices']:
                    key = (selection['node_index'], selection['primitive_index'], triangle)
                    require(key not in ownership, 'duplicate/coincident original triangle ownership')
                    ownership.add(key)
        cells.append(dict(schema_version=1, cell=identity, fabrication_source='res://'+doc['fabrication'].removeprefix('game/'),
                          fabrication_sha256_lf=doc['source_bindings'][doc['fabrication']]['sha256'], cell_source=source, cell_source_sha256_lf=registered['gltf_sha256'],
                          cell_buffers=buffers, source_bindings=cell_bindings,
                          existing_force_disable_compression=(compression.group(1) == 'true') if compression else None,
                          raw_stock_ids=[r['id'] for r in rows], raw_stocks=rows,
                          expected_triangles=sum(r['expected_triangles'] for r in rows)))
    require(sum(len(c['raw_stocks']) for c in cells) == 102, 'raw contract incomplete')
    return dict(schema_version=1, evidence_class='INERT source-derived contracts, not installation or source-disposal acceptance',
                placement_source=PLAN.as_posix(), placement_sha256_lf=sha(root/PLAN, True),
                source_bindings=bindings, cells=cells,
                counts=dict(cells=len(cells), raw_stocks=102, triangles=sum(c['expected_triangles'] for c in cells)),
                boundary_tolerance_m=RAW_TOLERANCE,
                limits='Original arrays/materials/indices only. Compression state bound, not changed. Actual imported extraction and target contact remain unqualified.')


def render(doc):
    return json.dumps(doc, indent=1, allow_nan=False) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    text = render(build(args.root))
    path = args.root/FIXTURE
    if args.check:
        require(path.read_text(encoding='utf-8').replace('\r\n', '\n') == text, 'all raw projection fixture stale')
        print('ARCADE ALL RAW PROJECTION OK 11cells 102stocks 1224original triangles')
    else:
        path.write_text(text, encoding='utf-8', newline='\n')
        print('WROTE ' + str(FIXTURE))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
