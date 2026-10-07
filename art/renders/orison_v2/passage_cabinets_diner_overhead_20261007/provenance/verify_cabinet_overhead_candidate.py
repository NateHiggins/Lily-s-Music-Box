from pathlib import Path
import json,sys,subprocess
R=Path('C:/PleaseRemainOnTheLine');T=R/'tmp/v2-finish-review';sys.path.insert(0,str(R/'tools'));import verify_candidate as v,gate_board
base='a37ca398d32e620bdc44f88e1f800acd61da3a53';head='b2cb465c30300cbdfed807fbfe599f2935ceb86b'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip()==head
board=json.loads((T/'a37ca398-clean-board.json').read_text(encoding='utf-8'));assert not v.validate_baseline_board(board,base)
work=Path('C:/ov');target=work/f'c-{head[:8]}';assert target.resolve().is_relative_to(work.resolve()) and not target.exists(),target
cache=work/'boards'/f'{base}.v{gate_board.TOOL_VERSION}.json'
cache.parent.mkdir(parents=True,exist_ok=True)
if cache.exists():assert json.loads(cache.read_text(encoding='utf-8'))==board,'existing cache differs'
else:cache.write_text(json.dumps(board,indent=1)+'\n',encoding='utf-8',newline='\n')
scenes=['DinerOverhead','DinerApparatus','DinerUrns','DinerBackbar','DinerTill','DinerCounter','LaundryFittings','PhotoProcess','DinerReceiving','PassageResidency','PassageLoadTeardown','ShopSimulation']
args=[sys.executable,str(R/'tools/verify_candidate.py'),head,'--base',base,'--no-fetch','--work-dir',str(work),'--out',str(T/'cabinet-overhead-candidate-verified')]
for name in scenes:
 scene=f'res://tests/OrisonV2{name}Test.tscn';assert (R/'game'/scene.removeprefix('res://')).is_file(),scene;args.extend(['--windowed-suite',scene])
print('Verifying one temporary clean checkout; reusing the complete clean a37 baseline; automatic worktree cleanup; 12 scoped suites plus two imports.',flush=True)
raise SystemExit(subprocess.run(args,cwd=R).returncode)
