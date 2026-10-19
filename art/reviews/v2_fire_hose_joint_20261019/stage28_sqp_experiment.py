from pathlib import Path
import sys,json,time
import numpy as np
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tmp/v2-fire-hand-20261019/scipy_deps'))
from scipy import sparse
from scipy.sparse.linalg import splu

def pairs_jac(p,first,last):
 d=p[first]-p[last];distance=np.linalg.norm(d,axis=1);unit=d/distance[:,None]
 rows=np.repeat(np.arange(len(first)),6);cols=np.concatenate([first[:,None]*3+np.arange(3),last[:,None]*3+np.arange(3)],axis=1).ravel()
 return sparse.csr_matrix((np.concatenate([unit,-unit],axis=1).ravel(),(rows,cols)),shape=(len(first),p.size)),distance

def solve(path):
 c=json.loads(path.read_text());target=np.asarray(c['target']);x=target.copy();lengths=np.asarray(c['lengths']);spans=np.asarray(c['bend_spans']);w=1/np.asarray(c['masses']);w[-1]=0;w3=np.repeat(w,3);n=len(x)
 plane_ids=np.array([row['ring'] for row in c['planes']],dtype=int);normals=np.array([row['normal'] for row in c['planes']]).reshape((-1,3));offsets=np.array([row['offset'] for row in c['planes']])
 jp=sparse.csr_matrix((normals.ravel(),(np.repeat(np.arange(len(plane_ids)),3),(plane_ids[:,None]*3+np.arange(3)).ravel())),shape=(len(plane_ids),x.size))
 def metrics(p):
  le=np.linalg.norm(p[:-1]-p[1:],axis=1)-lengths;be=spans-np.linalg.norm(p[:-2]-p[2:],axis=1);pe=offsets-np.sum(normals*p[plane_ids],axis=1)
  return [float(np.abs(le).max()),float(le.sum()),float(max(0,be.max())),float(max(0,pe.max())) if pe.size else 0.]
 def merit(p):
  le=np.linalg.norm(p[:-1]-p[1:],axis=1)-lengths;be=spans-np.linalg.norm(p[:-2]-p[2:],axis=1);pe=offsets-np.sum(normals*p[plane_ids],axis=1)
  return np.abs(le).sum()+np.maximum(0,be).sum()+np.maximum(0,pe).sum()
 trace=[];started=time.perf_counter()
 for iteration in range(64):
  jl,dl=pairs_jac(x,np.arange(n-1),np.arange(1,n));jb,db=pairs_jac(x,np.arange(n-2),np.arange(2,n));ji=sparse.vstack([jb,jp],format='csr')
  gl=dl-lengths;gi=np.concatenate([db-spans,np.sum(normals*x[plane_ids],axis=1)-offsets]);u=np.zeros(x.size);active=set();inner=0
  for inner in range(256):
   ids=np.array(sorted(active),dtype=int);j=sparse.vstack([jl,ji[ids]],format='csr');g=np.concatenate([gl,gi[ids]])
   a=(j.multiply(w3)@j.T).tocsc();lam=splu(a).solve(g+j@u);delta=u-w3*(j.T@lam)
   violation=gi+ji@delta
   add=set(np.flatnonzero(violation < -1e-9))-active
   if add:active.update(add);continue
   if len(ids) and np.max(lam[len(gl):])>1e-10:
    active.remove(int(ids[np.argmax(lam[len(gl):]) ]));continue
   break
  else:raise RuntimeError('QP active set exceeded budget')
  direction=delta.reshape((-1,3));alpha=1.;old_merit=merit(x)
  while alpha>1/4096 and merit(x+alpha*direction)>old_merit*(1-.01*alpha):alpha*=.5
  if alpha<=1/4096:print('LINE SEARCH STALLED',flush=True);break
  x=x+alpha*direction;m=metrics(x);trace.append({'iteration':iteration,'active':len(active),'qp_steps':inner+1,'errors':m})
  print(path.parent.name,iteration,'active',len(active),'qp',inner+1,'um',np.array(m)*1e6,flush=True)
  if m[0]<1e-6 and abs(m[1])<5e-6 and m[2]<1e-6 and m[3]<1e-7:break
 return {'evidence_class':'INERT','case':str(path),'seconds':time.perf_counter()-started,'trace':trace,'final_float32_errors':metrics(x.astype(np.float32).astype(float)),'solution':x.tolist()}
if __name__=='__main__':
 out=[]
 for stem in ['stage27_mass9','stage27_mass10']:
  out.append(solve(ROOT/'art/reviews/v2_fire_hose_mass_20261019/cases'/stem/'kernel_case.json'))
 (ROOT/'tmp/v2-fire-hand-20261019/stage28_sqp_cases.json').write_text(json.dumps(out,indent=2)+'\n')



