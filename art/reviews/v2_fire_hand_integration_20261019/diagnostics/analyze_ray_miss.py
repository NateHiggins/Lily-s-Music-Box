from pathlib import Path
import json,numpy as np
root=Path(__file__).parent
data=json.loads((root/'rack_matrix3/arm_ray_miss.json').read_text())
out={}
for dtype in [np.float32,np.float64]:
    faces=np.asarray(data['triangles'],dtype=np.float32).astype(dtype).reshape(-1,3,3)
    origin=np.asarray(data['origin'],dtype=np.float32).astype(dtype)
    direction=np.asarray(data['direction'],dtype=np.float32).astype(dtype)
    e=faces[:,1]-faces[:,0];f=faces[:,2]-faces[:,0]
    p=np.cross(direction,f);det=np.sum(e*p,axis=1)
    valid=np.abs(det)>1e-12
    inv=np.divide(1.,det,out=np.zeros_like(det),where=valid)
    s=origin-faces[:,0];q=np.cross(s,e)
    u=inv*np.sum(s*p,axis=1);v=inv*np.sum(direction*q,axis=1);t=inv*np.sum(f*q,axis=1)
    rows=[]
    for eps in [0.,1e-15,1e-12]:
        hits=np.flatnonzero(valid&(u>=-eps)&(u<=1.+eps)&(v>=-eps)&(u+v<=1.+eps)&(t>1e-5))
        rows.append({'barycentric_epsilon':eps,'hits':[{'triangle':int(i),'u':float(u[i]),'v':float(v[i]),'t_mm':float(t[i])} for i in hits[np.argsort(t[hits])]][:8]})
    out[np.dtype(dtype).name]=rows
(root/'rack_matrix3/offline_intersections.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=1))
