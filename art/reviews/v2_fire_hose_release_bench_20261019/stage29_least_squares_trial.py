from pathlib import Path
import numpy as np,json,time
p=Path('tmp/v2-fire-hand-20261019/stage28_second_order_trial.py');scope={'__file__':str(p.resolve()),'__name__':'trial'}
exec(compile(p.read_text().split('trace=[]')[0],str(p),'exec'),scope)
from scipy.optimize import least_squares
x=scope['x'];eq=len(x)-1;anchor=x[-1].copy()
def unpack(v):return np.vstack([v.reshape((-1,3)),anchor])
def fun(v):
 j,g=scope['rows'](unpack(v));g[eq:]=np.minimum(0,g[eq:]);return g
def jac(v):
 j,g=scope['rows'](unpack(v));mask=np.ones(len(g));mask[eq:]=(g[eq:]<0);return j.multiply(mask[:,None]).tocsr()[:,:-3]
out=[]
for mode in ['raw','smoothed']:
 seed=x.copy()
 if mode=='smoothed':
  for i in range(16):seed[1:-1]=.5*seed[1:-1]+.25*(seed[:-2]+seed[2:])
 started=time.perf_counter();r=least_squares(fun,seed[:-1].ravel(),jac=jac,method='trf',tr_solver='lsmr',ftol=1e-12,gtol=1e-12,xtol=1e-12,max_nfev=256,tr_options={'maxiter':512})
 g=fun(r.x);m=[max(abs(g[:eq])),abs(sum(g[:eq])),max(0,-min(g[eq:]))]
 print(mode,'seconds',time.perf_counter()-started,'evals',r.nfev,'metrics',m,'message',r.message,flush=True);out.append({'seed':mode,'metrics':m,'evals':r.nfev,'message':r.message})
Path('tmp/v2-fire-hand-20261019/stage29_least_squares_trial.json').write_text(json.dumps({'evidence_class':'INERT','runs':out},indent=2))
