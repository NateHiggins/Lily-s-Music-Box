#!/usr/bin/env python3
"""Project fitted placements, deriving identities from the original lamp markers."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def project():
    layout = json.loads((ROOT / 'art/data/building_layout.json').read_text(encoding='utf-8'))
    plan = json.loads((ROOT / 'art/data/task_lamp_installations/source_plan.json').read_text())
    markers = [m for floor in layout['floors'] for m in floor.get('markers', []) if m.get('kind') == 'lamp']
    source = {m['id']: m for m in markers}
    # The five original lamps take their identity from the legacy markers. A lamp added since names its own
    # variant and unit and the ruling that placed it (Lily's lamp in 3C: flat_3c_furnishing_20261115).
    added = [p for p in plan['placements'] if p['id'] not in source]
    assert len(source) == 5 and set(source) <= {p['id'] for p in plan['placements']}
    assert all(p.get('ruling') and p.get('variant') and p.get('unit') for p in added), 'an added lamp names its ruling'
    rows = []
    for row in plan['placements']:
        if row['id'] in source:
            m = source[row['id']]
            assert m['network'] == 'electrical'
            rows.append({**row, 'variant': m['variant'], 'unit': m['unit']})
        else:
            rows.append({k: v for k, v in row.items() if k != 'ruling'})
    return {'schema_version': 1, 'lamps': rows, 'terminal_fit': plan['terminal_fit']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    path = ROOT / 'game/data/orison_v2/task_lamp_installations.json'
    text = json.dumps(project(), indent=2) + '\n'
    if args.check:
        assert path.read_text(encoding='utf-8') == text, 'task lamp projection is stale'
    else:
        path.write_text(text, encoding='utf-8', newline='\n')
    print('TASK LAMP INSTALLATIONS: five source identities and the lamps added since, fitted support-local placements')
