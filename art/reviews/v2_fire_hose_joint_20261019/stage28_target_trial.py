from pathlib import Path
import json
p=Path('tmp/v2-fire-hand-20261019/stage28_sqp_newcase.py')
s=p.read_text().replace("x=np.asarray(c['result'])", "x=np.asarray(c['target'])")
scope={'__file__':str(p.resolve()),'__name__':'experiment'}
exec(compile(s,str(p),'exec'),scope)
r=scope['solve'](Path('game/tests/fixtures/fire_hose_globalization_case.json'))
Path('tmp/v2-fire-hand-20261019/stage28_target_trial.json').write_text(json.dumps(r,indent=2))
print('Float32',r['final_float32_errors'])
