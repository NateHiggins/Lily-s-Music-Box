"""Explicitly reuse unchanged full-board checks after focused source repairs."""
from pathlib import Path
import copy,hashlib,json,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from gate_board import compare,render_markdown
base=ROOT/'art/reviews/v2_library_editorial_20261022/board/board.json'
full=OUT/'full_board_v1/board.json';repair=OUT/'repair_board_v1/board.json';tint=OUT/'tint_source_board_v1/board.json'
stable=OUT/'stable_frame_final_board_v1/board.json'
board=copy.deepcopy(json.loads(full.read_text(encoding='utf-8')))
updates={g['id']:g for g in json.loads(repair.read_text(encoding='utf-8'))['gates']}
updates.update({g['id']:g for g in json.loads(tint.read_text(encoding='utf-8'))['gates']})
updates.update({g['id']:g for g in json.loads(stable.read_text(encoding='utf-8'))['gates']})
board['gates']=[updates.get(g['id'],g) for g in board['gates']]
board['composition']={'evidence_class':'INERT','kind':'composed_board_not_full_rerun',
 'sources':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [full,repair,tint,stable]},
 'overlaid_gates':sorted(updates),'repairs':['Add the identical registered wool entry to gen_layout.MATERIAL_CATALOG; actual persistence test passes.','Register only three reviewed TEST_CONTRACT route/drop fixtures; existing manifest records preserved and all 59 spatial tests pass.'],
 'limitations':'Other checks reuse full_board_v1. Existing qualification/completeness failures remain failures.'}
comparison=compare(json.loads(base.read_text(encoding='utf-8')),board)
(OUT/'composed_board.json').write_text(json.dumps(board,indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'composed_comparison.json').write_text(json.dumps(comparison,indent=2)+'\n',encoding='utf-8',newline='\n')
(OUT/'composed_board.md').write_text(('Explicit composed diagnostic board; not a second full execution.\n\n'+render_markdown(board,comparison)).rstrip()+'\n',encoding='utf-8',newline='\n')
print('Regressions:',comparison['regressions'])
