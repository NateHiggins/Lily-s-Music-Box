import bpy,math,json
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
root=Path('C:/PleaseRemainOnTheLine')
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(root/'art/blender/fire_nozzle_joint.blend'),link=False) as (available,loaded):
 loaded.objects=['NozzleNut_Editable','NozzleSpigot_Editable']
nut,male=loaded.objects
def tree(obj,frame):
 return BVHTree.FromPolygons([frame@v.co for v in obj.data.vertices],[list(f.vertices) for f in obj.data.polygons])
rows=[]
for axial in [.04065,.041,.0415,.0418]:
 for radial in [0.,.00025]:
  spigot=tree(male,Matrix.Translation((radial,0,axial)))
  failures=[]
  for i in range(64):
   phase=math.tau*i/64
   pairs=tree(nut,Matrix.Rotation(phase,4,'Z')).overlap(spigot)
   if pairs:failures.append([i,len(pairs)])
  rows.append(dict(axial_m=axial,radial_m=radial,crossing_phases=failures))
print('NATIVE PILOT EXPLORATION',json.dumps(rows))
(root/'tmp/v2-fire-hand-20261019/nozzle_pilot_exploration.json').write_text(json.dumps(rows,indent=2)+'\n')
