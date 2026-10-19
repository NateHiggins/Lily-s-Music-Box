from pathlib import Path
import numpy as np,json
p=Path('tmp/v2-fire-hand-20261019/stage28_second_order_trial.py')
s=p.read_text().split('trace=[]')[0].replace('from scipy import sparse','from scipy import sparse')
s=s.replace("lam=splu((a.multiply(w3)@a.T).tocsc()).solve(g[take]);d=-w3*(a.T@lam)","matrix=(a.multiply(w3)@a.T).tocsc();matrix=matrix+sparse.diags(matrix.diagonal()*damping);lam=splu(matrix.tocsc()).solve(g[take]);d=-w3*(a.T@lam)")
scope={'__file__':str(p.resolve()),'__name__':'trial'};exec(compile(s,str(p),'exec'),scope)
initial=scope['x'].copy();trace=[]
for damping in [1e-5,1e-4,.001,.01,.1,1.]:
 scope['damping']=damping;x=initial.copy()
 for it in range(128):
  d=scope['direction'](x);old=scope['merit'](x);alpha=1.
  while alpha>=1/4096 and scope['merit'](x+alpha*d)>old*(1-.001*alpha):alpha*=.5
  if alpha<1/4096:break
  x=x+alpha*d;j,g=scope['rows'](x);eq=len(x)-1
  m=[max(abs(g[:eq])),abs(sum(g[:eq])),max(0,-min(g[eq:]))]
  if m[0]<=2e-5 and m[1]<=2e-5 and m[2]<=1e-6:break
 print('damping',damping,'iterations',it+1,'metrics',m,flush=True);trace.append({'damping':damping,'iterations':it+1,'metrics':m})
Path('tmp/v2-fire-hand-20261019/stage29_damping_trial.json').write_text(json.dumps({'evidence_class':'INERT','trace':trace},indent=2))
