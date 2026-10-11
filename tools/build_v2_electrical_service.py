"""Project native electrical service reservation and bounded slab ports."""
import argparse,json
from pathlib import Path
from build_v2_roof import render,upsert_records
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    target=ROOT/'game/data/orison_v2_blockout.json';original=target.read_text(encoding='utf-8')
    before=json.loads(original);after=json.loads(original)
    source=json.loads((ROOT/'art/data/electrical_service/layout_records.json').read_text())
    assert source['schema_version']==1
    for table,rows in source['records'].items():after[table]=upsert_records(after[table],rows)
    if args.check:
        if after!=before:raise SystemExit('Electrical service projection is stale')
        print('Electrical service projection matches authored source')
    else:target.write_text(render(original,after),encoding='utf-8',newline='\n')
if __name__=='__main__':main()
