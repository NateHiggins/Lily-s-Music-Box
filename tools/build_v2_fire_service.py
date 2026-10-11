"""Project dedicated fire-service anchors and explicit architectural ports."""
import argparse,json
from pathlib import Path
from build_v2_roof import render,upsert_records
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/data/fire_service/layout_records.json'
TARGET=ROOT/'game/data/orison_v2_blockout.json'
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');args=p.parse_args()
 original=TARGET.read_text(encoding='utf-8');before=json.loads(original);after=json.loads(original)
 source=json.loads(SOURCE.read_text(encoding='utf-8'));assert source['schema_version']==1
 for table,rows in source['records'].items():after[table]=upsert_records(after[table],rows)
 if args.check:
  if after!=before:raise SystemExit('Fire service projection is stale')
  print('Fire service projection matches authored source')
 else:TARGET.write_text(render(original,after),encoding='utf-8',newline='\n')
if __name__=='__main__':main()
