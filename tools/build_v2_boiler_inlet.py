"""Project the retained boiler feed's bounded structural crossings."""
import argparse
import copy
import json
from pathlib import Path
from build_v2_roof import render, upsert_records

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/data/orison_v2/boiler_inlet_source.json'
TARGET=ROOT/'game/data/orison_v2_blockout.json'

def project(layout,source):
    if source.get('schema_version')!=1:raise ValueError('Unsupported boiler inlet source')
    result=copy.deepcopy(layout)
    for table,rows in source['records'].items():
        if table not in ['wall_service_openings','riser_openings']:
            raise ValueError('Unowned boiler inlet table: '+table)
        if any(not r['id'].startswith('HEAT_') for r in rows):
            raise ValueError('Foreign boiler inlet identity')
        result[table]=upsert_records(result.get(table,[]),rows)
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    original=TARGET.read_text(encoding='utf-8')
    before=json.loads(original)
    after=project(before,json.loads(SOURCE.read_text(encoding='utf-8')))
    if args.check:
        if before!=after:raise SystemExit('Boiler inlet projection is stale')
        print('Boiler inlet matches authored source')
    else:TARGET.write_text(render(original,after),encoding='utf-8',newline='\n')

if __name__=='__main__':main()
