"""Regenerate the INERT fabrication work index; discovery is not acceptance.

Lists every semantic space and structural record plus installed data tables.
Keeps mesh buffers out of the index. Runtime visibility, clearance and finish
acceptance must still be recorded by rendered inspection and focused tests.
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parents[1]
STRUCTURE = ('spaces', 'doors', 'openings', 'windows', 'envelopes', 'fixtures',
             'platforms', 'lift_landings', 'stairs', 'risers')
IDENTITY = ('id', 'kind', 'class', 'level', 'unit', 'room', 'space', 'anchor',
            'fabrication', 'fabrication_part', 'purpose', 'model')

def city_index(root):
    """Source ownership of the composed city, including registered omissions.

    Active means referenced by the production composition. It says nothing
    about visible quality, successful traversal or runtime acceptance.
    """
    passage_path = root/'game/scripts/building/orison_v2_passage_region.gd'
    passage = passage_path.read_text(encoding='utf-8')
    roster = re.search(r'const CELLS := \[(.*?)\]', passage, re.S)
    cells = re.findall(r'"([^"]+)"', roster.group(1))
    registry = json.loads((root/'game/data/floor_01_cell_registry.json').read_text(encoding='utf-8'))
    runtime = (root/'game/scripts/building/orison_v2_runtime_root.gd').read_text(encoding='utf-8')
    bar_active = 'bar_region = BarRegion.new()' in runtime
    adopted = {'passage', *cells}
    if bar_active: adopted.add('shop_bar')
    retained = []
    for row in registry['cells']:
        name = Path(row['resource_path']).stem
        composition = 'dormant'
        if name in adopted:
            composition = 'active'
        if name in ('passage', 'site_street_common'):
            composition = 'derived_geometry'
        retained.append(dict(id=row['id'], asset=row['resource_path'],
            production_composition=composition,
            semantic_owners=row['semantic_owners'],
            lifecycle=row['lifecycle']))
    return dict(
        interpretation='INERT source discovery; active/dormant is composition, not acceptance.',
        imported_frame=dict(authority='game/data/orison_v2/exterior/street_frame.json',
            transform='Godot translation Z = -source_threshold_z; coordinates via GameBoot.b2g'),
        buckets={
            'orison': dict(shell='game/scripts/building/orison_v2_blockout.gd',
                source='game/data/orison_v2_blockout.json',
                outer_leaf='art/blender/scripts/build_exterior_masonry.py',
                connection='game/scripts/building/orison_v2_world_connection.gd'),
            'bodega': dict(shell='game/scripts/building/orison_v2_exterior_cell.gd',
                geometry='game/data/orison_v2/exterior/exterior_geometry.json',
                frames='game/data/orison_v2/exterior/regions.json',
                state='game/scripts/building/orison_v2_shop_bucket_registry.gd'),
            'arcade': dict(shell=passage_path.relative_to(root).as_posix(),
                cells=cells, gateway='tools/build_v2_passage_gateway.py',
                residency='game/scripts/building/orison_v2_passage_residency.gd',
                seating='game/scripts/building/orison_v2_shop_seating.gd',
                seating_native='art/blender/shop_seating.blend',
                seating_source='art/data/shop_seating/source_plan.json',
                laundry_fittings='game/scripts/building/orison_v2_laundry_fittings.gd',
                laundry_native='art/blender/laundry_fittings.blend',
                laundry_source='art/data/laundry_fittings/source_plan.json',
                hours='game/scripts/building/passage_hours_director.gd'),
            'street': dict(geometry='game/data/orison_v2/exterior/exterior_geometry.json',
                boundaries='game/scripts/building/orison_v2_street_boundaries.gd',
                front_pavement='art/blender/scripts/build_front_pavement.py',
                rear_alley='art/blender/scripts/build_service_alley.py',
                alley_groundworks='art/blender/scripts/build_alley_groundworks.py',
                orison_ground='art/blender/scripts/build_orison_ground.py',
                ground_source='art/data/orison_ground/retained_grade_source.json'),
            'bar': dict(active=bar_active,
                shell='game/assets/building/floor_01_cells/shop_bar.gltf',
                composition='game/scripts/building/orison_v2_bar_region.gd',
                source='art/data/gen_layout.py',
                actors='game/data/floor_01_cell_registry.json:CELL_SHOP_BAR',
                hours='game/scripts/building/harukiya_state_director.gd'),
            'cityscape': dict(shell='art/blender/scripts/build_city_shells.py',
                closure='art/blender/scripts/build_city_closure.py',
                retained_native='art/blender/city_shells.blend',
                closed_native='art/blender/city_closure.blend',
                closure_source='art/data/city_closure/source_plan.json',
                source='art/data/building_layout.json',
                composition='game/scripts/building/orison_v2_city_shells.gd',
                omitted='old ground, active shop interiors, unsupported antenna fragments'),
        }, registered_cells=retained)

def index(root):
    layout = json.loads((root/'game/data/orison_v2_blockout.json').read_text(encoding='utf-8'))
    structure = {k: [{f: row[f] for f in IDENTITY if f in row} for row in layout[k]]
                 for k in STRUCTURE}
    installed = {}
    for path in sorted((root/'game/data/orison_v2').glob('*.json')):
        data = json.loads(path.read_text(encoding='utf-8'))
        tables = {}
        for key, rows in data.items():
            if not isinstance(rows, list) or not rows or not isinstance(rows[0], dict):
                continue
            # Keep only installation/program identities, never spatial buffers.
            records = [{f: row[f] for f in IDENTITY if f in row} for row in rows]
            records = [row for row in records if row]
            if records: tables[key] = records
        if tables: installed[path.relative_to(root).as_posix()] = tables
    references = {}
    for path in sorted((root/'game/scripts/building').glob('orison_v2*.gd')):
        assets = sorted(set(re.findall(r'res://assets/[^"\s]+', path.read_text(encoding='utf-8'))))
        if assets: references[path.relative_to(root).as_posix()] = assets
    generators = [p.relative_to(root).as_posix() for p in sorted(
        (root/'art/blender/scripts').glob('build_*.py'))]
    return dict(evidence_class='INERT', schema='orison.fabrication-work-index.v1',
                acceptance='All discovered records require review; existence does not mean complete.',
                structure=structure, installed=installed,
                building_asset_references=references, blender_generators=generators,
                city_composition=city_index(root))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',default='art/blender/v2_fabrication_inventory.json')
    args=parser.parse_args()
    data=index(ROOT)
    path=Path(args.out)
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Structural records:',{k:len(v) for k,v in data['structure'].items()})
    print('Installed data files:',len(data['installed']))

if __name__=='__main__': main()
