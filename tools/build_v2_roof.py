"""Project the roof's authored program into V2 without rebuilding older floors.

Only ROOF records, the two F06 ceiling flags, and the two F06-to-roof flights
are owned here. Re-running is deterministic and retains unrelated layout work.
"""
import argparse
import copy
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/data/orison_v2/roof_source.json'
TARGET = ROOT / 'game/data/orison_v2_blockout.json'


def project(layout, source):
    result = copy.deepcopy(layout)
    assert source['schema_version'] == 1
    for table, additions in source['records'].items():
        owned = {r['id'] for r in additions}
        result[table] = [r for r in result[table] if r['id'] not in owned] + copy.deepcopy(additions)
    for core in ['PUBLIC', 'SERVICE']:
        room = next(r for r in result['spaces'] if r['id'] == f'F06_{core}_CORE')
        room['no_ceiling'] = True
    for kind in ['PRIMARY', 'SERVICE']:
        flight = copy.deepcopy(next(r for r in result['stairs'] if r['id'] == f'{kind}_F05_F06'))
        flight.update(id=f'{kind}_F06_ROOF', **{'from': 'F06', 'to': 'ROOF'})
        result['stairs'] = [r for r in result['stairs'] if r['id'] != flight['id']] + [flight]
    return result


def render(original, result):
    """Keep existing record spelling rather than reformatting the whole world."""
    decoder = json.JSONDecoder()
    edits = []
    for match in re.finditer(r'^  "([^"]+)": ', original, re.MULTILINE):
        key = match.group(1)
        start = match.end()
        value, end = decoder.raw_decode(original, start)
        if value == result[key]:
            continue
        if not isinstance(value, list):
            raise ValueError(f'Unexpected non-table change: {key}')
        old = {}
        cursor = start + 1
        while cursor < end:
            while original[cursor] in ' \t\r\n,':
                cursor += 1
            if original[cursor] == ']':
                break
            record, stop = decoder.raw_decode(original, cursor)
            old[record['id']] = (record, original[cursor:stop])
            cursor = stop
        rows = []
        for record in result[key]:
            previous, raw = old.get(record['id'], (None, None))
            rows.append(raw if record == previous else json.dumps(record, separators=(',', ':')))
        edits.append((start, end, '[\n    ' + ',\n    '.join(rows) + '\n  ]'))
    for start, end, text in reversed(edits):
        original = original[:start] + text + original[end:]
    if json.loads(original) != result:
        raise ValueError('Formatting changed layout semantics')
    return original


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    original = TARGET.read_text(encoding='utf-8')
    layout = json.loads(original)
    result = project(layout, json.loads(SOURCE.read_text(encoding='utf-8')))
    if args.check:
        if layout != result:
            raise SystemExit('Roof projection is stale; run tools/build_v2_roof.py')
        print('Roof projection matches authored source')
    else:
        TARGET.write_text(render(original, result), encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
