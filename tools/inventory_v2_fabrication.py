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
                building_asset_references=references, blender_generators=generators)

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
