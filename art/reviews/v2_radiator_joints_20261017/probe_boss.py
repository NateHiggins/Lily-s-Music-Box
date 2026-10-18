from pathlib import Path
import bpy,json,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path('C:/PleaseRemainOnTheLine');T=R/'tmp/v2-radiator-joints-20261017'
bpy.ops.wm.open_mainfile(filepath=str(R/'art/blender/radiator_mechanisms.blend'))
o=bpy.data.objects['CastSectionThreeColumnCandidate'];m=o.data
v=[p.co for p in m.vertices];f=[tuple(p.vertices) for p in m.polygons];tree=BVHTree.FromPolygons(v,f,all_triangles=True)
rows=[]
for z in [.085,.615]:
 for x in [.040,.043,.0448,.0455,.0459,.04599]:
  radii=[]
  for i in range(32):
   axis=Vector((0,math.cos(i*math.tau/32),math.sin(i*math.tau/32)))
   center=Vector((x,.055,z));hit=tree.ray_cast(center+axis*.06,-axis,.04)[0]
   radii.append(None if hit is None else (hit-center).length)
  good=[r for r in radii if r is not None];rows.append(dict(z=z,x=x,minimum=min(good) if good else None,maximum=max(good) if good else None,missing=32-len(good)))
print(json.dumps(rows,indent=2));(T/'boss_probe.json').write_text(json.dumps(rows,indent=2)+'\n')
