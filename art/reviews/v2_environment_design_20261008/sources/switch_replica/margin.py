import json, sys, numpy as np
res = json.load(open(sys.argv[1]))['results']
TOL=.001
rows=[]
for r in res:
    o=r['data']['wide']; g=np.array(o['gap']); lat=np.array(o['lat']); emb=o['emb']
    ok=np.array([np.isfinite(g[i]) and abs(g[i])<=TOL and not emb[i] for i in range(len(g))])
    lx=lat[:,0]
    # nearest bad sample beyond the rim on each side
    def clear(sign):
        bad=[abs(x) for x,k in zip(lx,ok) if not k and sign*x>=0]
        return (min(bad)-0.06)*1000 if bad else 999
    rows.append((min(clear(1),clear(-1)), r['id'], round(clear(-1),1), round(clear(1),1)))
rows.sort()
for m,i,a,b in rows[:int(sys.argv[2]) if len(sys.argv)>2 else 40]: print(f"{i:28s} min {m:7.1f} mm  (-X {a:7.1f}, +X {b:7.1f})")
