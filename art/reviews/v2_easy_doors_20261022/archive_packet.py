"""Exact diagnostic packet for passage-first architectural-door changes."""
from pathlib import Path
import subprocess,gzip,hashlib,json
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
SOURCES=['.gitattributes','DOCS.md','game/scripts/props/door_prop.gd','game/scripts/props/landmark_entry_door.gd','game/scripts/props/easy_door_motion.gd','game/scripts/props/easy_door_motion.gd.uid','game/scripts/building/orison_v2_passage_shop_door.gd','game/scripts/player/constrained_grab.gd','game/tests/v2_easy_door_bench.gd','game/tests/v2_easy_door_bench.gd.uid','game/tests/V2EasyDoorBench.tscn','game/tests/direct_manipulation_test.gd','design/V2_EASY_DOORS_2026-10-22.md','design/V2_BATHROOM_WET_GLASS_BRIEF_2026-10-22.md']
rows=[]
def put(data,dest,original):
 dest=OUT/'archive'/(dest+'.gz');dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(gzip.compress(data,mtime=0));rows.append(dict(original=original,archive=dest.relative_to(OUT).as_posix(),sha256=hashlib.sha256(data).hexdigest(),bytes=len(data)))
for path in SOURCES:put((ROOT/path).read_bytes(),'source/'+path,path)
for path in sorted(OUT.glob('*.log*')):
 if path.is_file():put(path.read_bytes(),'runs/'+path.name,path.relative_to(ROOT).as_posix())
for path in ['game/scripts/props/door_prop.gd','game/scripts/player/constrained_grab.gd','game/scripts/building/orison_v2_passage_shop_door.gd']:
 put(subprocess.check_output(['git','show','e801168b:'+path],cwd=ROOT),'baseline/'+path,'e801168b:'+path)
for name in ['easy_door_spatial_final.json','easy_door_spatial_reviewed.json']:
 p=ROOT/'tmp'/name
 if p.exists():put(p.read_bytes(),'static/'+name,p.relative_to(ROOT).as_posix())
(OUT/'packet.json').write_text(json.dumps(dict(evidence_class='INERT',scope='Architectural DoorProp input diagnostics only; no broader runtime or performance acceptance.',source_base='e801168b',records=rows),indent=2)+'\n',encoding='utf-8',newline='\n')
print('Archived',len(rows),'exact diagnostic/source records')
