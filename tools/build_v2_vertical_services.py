"""Project explicit V2 shaft construction without rewriting other rooms."""
import argparse
import copy
import json
from pathlib import Path
from build_v2_roof import render, upsert_records

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/data/orison_v2/vertical_services_source.json'
TARGET = ROOT / 'game/data/orison_v2_blockout.json'


def project(layout, source):
    result = copy.deepcopy(layout)
    assert source['schema_version'] == 1
    for table, additions in source['records'].items():
        result[table] = upsert_records(result[table], additions)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    original = TARGET.read_text(encoding='utf-8')
    before = json.loads(original)
    after = project(before, json.loads(SOURCE.read_text(encoding='utf-8')))
    if args.check:
        if after != before:
            raise SystemExit('Vertical services projection is stale')
        print('Vertical services projection matches authored source')
    else:
        TARGET.write_text(render(original, after), encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
