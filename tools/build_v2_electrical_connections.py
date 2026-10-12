"""Project source-owned electrical branch wall ports and utility slab entry."""
import argparse,json
from pathlib import Path
from build_v2_roof import render,upsert_records
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    target=ROOT/'game/data/orison_v2_blockout.json';original=target.read_text(encoding='utf-8')
    before=json.loads(original);after=json.loads(original)
    data=json.loads((ROOT/'art/data/electrical_service/connections_layout_records.json').read_text())
    assert data['schema_version']==1
    for table,rows in data['records'].items():after[table]=upsert_records(after[table],rows)
    if args.check:
        if after!=before:raise SystemExit('Electrical connection projection is stale')
        print('Electrical connection projection matches authored source')
    else:target.write_text(render(original,after),encoding='utf-8',newline='\n')
if __name__=='__main__':main()
