import bpy,json,os,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=Path(os.environ['HOSE_CANDIDATE'])
bpy.ops.wm.open_mainfile(filepath=str(p/'fire_hose_stock.blend'))
rows=[]
for name in ['OutletStock','NozzleStock']:
    obj=bpy.data.objects[name];tree=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[list(f.vertices) for f in obj.data.polygons])
    blocked=[]
    for j in range(128):
        angle=math.tau*j/128.;radius=.01905-.0001
        hit=tree.ray_cast(Vector((radius*math.cos(angle),-radius*math.sin(angle),-.05)),Vector((0,0,1)),1.)
        if hit[0] is not None:blocked.append(j)
    rows.append(dict(stock=name,rays=128,blocked=blocked))
(p/'full_bore_review.json').write_text(json.dumps(dict(evidence_class='INERT',rows=rows),indent=2)+'\n')
print('FULL BORE REVIEW',json.dumps(rows))
assert all(not r['blocked'] for r in rows),'Nominal circular bore constricted between the coarse samples'
