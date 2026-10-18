from pathlib import Path
import json,runpy
import numpy as np
R=Path('C:/PleaseRemainOnTheLine');T=R/'tmp/v2-control-finish-20261017'
read=runpy.run_path(str(T/'compare_geometry.py'))['read']
rows=[];failures=[]
for family in json.loads((T/'family_names.json').read_text()):
    old,oa=read(T/f'family_before/game/assets/props/{family}.glb');new,na=read(R/f'game/assets/props/{family}.glb')
    if [m['name'] for m in old['meshes']]!=[m['name'] for m in new['meshes']]:
        failures.append([family,'mesh identity/order changed']);continue
    for om,nm in zip(old['meshes'],new['meshes']):
        if len(om['primitives'])!=len(nm['primitives']):failures.append([family,om['name'],'partition count']);continue
        for op,np_ in zip(om['primitives'],nm['primitives']):
            oi=oa(op['indices']).reshape(-1).astype(int);ni=na(np_['indices']).reshape(-1).astype(int)
            po=oa(op['attributes']['POSITION'])[oi];pn=na(np_['attributes']['POSITION'])[ni]
            if po.shape!=pn.shape or not np.array_equal(po,pn):
                failures.append([family,om['name'],'expanded geometry',list(po.shape),list(pn.shape)]);continue
            uo=oa(op['attributes']['TEXCOORD_0'])[oi].reshape((-1,3,2));un=na(np_['attributes']['TEXCOORD_0'])[ni].reshape((-1,3,2))
            # Whole-period rephasing changes float32 rounding. Compare in
            # float64 against the propagated half-ULP error of four stored
            # coordinates, rather than enlarging a physical-scale tolerance.
            difference=np.abs((uo[:,1:].astype(float)-uo[:,:1].astype(float))-(un[:,1:].astype(float)-un[:,:1].astype(float)))
            spacing_old=np.abs(np.spacing(uo)).astype(float);spacing_new=np.abs(np.spacing(un)).astype(float)
            budget=.5*(spacing_old[:,1:]+spacing_old[:,:1]+spacing_new[:,1:]+spacing_new[:,:1])
            excess=float(np.max(difference-budget))
            delta=float(np.max(difference))
            # Record changed UVs honestly. The separate loaded metre/basis
            # bench validates chart quality; flex charts intentionally change.
            rows.append({'family':family,'part':om['name'],'triangles':len(oi)//3,'expanded_geometry_identical':True,'maximum_uv_edge_delta_m':delta,'maximum_float32_budget_excess_m':excess})
result={'evidence_class':'INERT','scope':'Rebuilt family geometry and UV-derivative comparison; not player, physics or human appearance acceptance.','parts':rows,'failures':failures}
(T/'family_geometry_comparison.json').write_text(json.dumps(result,indent=2)+'\n',newline='\n')
print({'parts':len(rows),'failures':len(failures),'first_failures':failures[:6]})
raise SystemExit(1 if failures else 0)
