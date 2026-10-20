from pathlib import Path
import sys,json,time
import numpy as np
sys.path.insert(0,str(Path('tmp/v2-fire-hand-20261019/scipy_deps').resolve()))
from scipy import sparse
from scipy.sparse.linalg import splu
c=json.loads(Path('game/tests/fixtures/fire_hose_globalization_case.json').read_text())
x=np.asarray(c['result']);lengths=np.asarray(c['lengths']);spans=np.asarray(c['bend_spans']);w=1/np.asarray(c['masses']);w[-1]=0;w3=np.repeat(w,3);n=len(x)
ids=np.array([p['ring'] for p in c['planes']]);norm=np.array([p['normal'] for p in c['planes']]);off=np.array([p['offset'] for p in c['planes']])
def rows(p):
 out=[];gs=[]
 for hop,rest in [(1,lengths),(2,spans)]:
  a=np.arange(n-hop);b=a+hop;d=p[a]-p[b];dist=np.linalg.norm(d,axis=1);v=d/dist[:,None]
  out.append(sparse.csr_matrix((np.concatenate([v,-v],axis=1).ravel(),(np.repeat(a,6),np.concatenate([3*a[:,None]+np.arange(3),3*b[:,None]+np.arange(3)],axis=1).ravel())),shape=(n-hop,x.size)))
  gs.append(dist-rest)
 out.append(sparse.csr_matrix((norm.ravel(),(np.repeat(np.arange(len(ids)),3),(3*ids[:,None]+np.arange(3)).ravel())),shape=(len(ids),x.size)))
 gs.append(np.sum(norm*p[ids],axis=1)-off)
 return sparse.vstack(out,format='csr'),np.concatenate(gs)
def merit(p):
 j,g=rows(p)
 return abs(g[:n-1]).sum()+np.maximum(0,-g[n-1:]).sum()
def direction(p):
 j,g=rows(p);active=set();eq=n-1
 for k in range(512):
  take=np.r_[np.arange(eq),np.array(sorted(active),dtype=int)];a=j[take]
  lam=splu((a.multiply(w3)@a.T).tocsc()).solve(g[take]);d=-w3*(a.T@lam)
  violation=g+j@d;add=set(np.flatnonzero(violation[eq:] < -1e-9)+eq)-active
  if add:active.update(add);continue
  if active and max(lam[eq:])>1e-10:active.remove(int(take[eq+np.argmax(lam[eq:]) ]));continue
  return d.reshape((-1,3))
 raise ValueError('QP ceiling')
trace=[]
for iteration in range(64):
 old=merit(x);d=direction(x);a=1.;accepted=False
 for look in range(3):
  trial=x+d
  if merit(trial)<old*(1-.01):x=trial;accepted=True;break
  # A second normal correction counters distance curvature before deciding
  # whether the full first tangent step was useful.
  d+=direction(trial)
 if not accepted:
  d=direction(x)
  while a>=1/4096:
   trial=x+a*d
   if merit(trial)<=old*(1-.01*a):x=trial;accepted=True;break
   a*=.5
 if not accepted:print('stalled');break
 j,g=rows(x);m=[max(abs(g[:n-1])),abs(sum(g[:n-1])),max(0,-min(g[n-1:]))];print(iteration,merit(x),m,flush=True);trace.append(m)
 if m[0]<=2e-5 and m[1]<=2e-5 and m[2]<=1e-6:break
Path('tmp/v2-fire-hand-20261019/stage28_second_order_trial.json').write_text(json.dumps({'evidence_class':'INERT','trace':trace}))
