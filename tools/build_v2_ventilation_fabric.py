"""Project explicit ventilation wall/chase/outer-leaf clearances, preserving owners."""
import argparse
import copy
import json
from pathlib import Path
from build_v2_roof import render, upsert_records

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/data/orison_v2/ventilation_fabric_source.json'
TARGET=ROOT/'game/data/orison_v2_blockout.json'

def project(layout,source):
    if source.get('schema_version')!=1:raise ValueError('Unsupported ventilation fabric source')
    result=copy.deepcopy(layout)
    for table,rows in source['records'].items():
        if table not in ['wall_service_openings','riser_openings','masonry_service_openings']:
            raise ValueError('Unowned ventilation fabric table: '+table)
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
        if before!=after:raise SystemExit('Ventilation fabric projection is stale')
        print('Ventilation fabric matches authored source')
    else:TARGET.write_text(render(original,after),encoding='utf-8',newline='\n')

if __name__=='__main__':main()
