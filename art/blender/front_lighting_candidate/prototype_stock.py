"""Check both analytic support orientations before rebuilding the full assembly."""
from pathlib import Path
import json,math,sys
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from stock import hanger
OUT=ROOT/'tmp/v2-front-lighting-20261017';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(ROOT/'art/blender/front_lighting_candidate.blend'),link=False) as (available,loaded):
    loaded.materials=['iron_neutral']
checks=[]
for name,direction in [('X',(1,0,0)),('Z',(0,0,1))]:
    obj=hanger('Hanger_'+name,direction,.05,loaded.materials[0]);mesh=obj.data;mesh.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(mesh);bm.normal_update();tree=BVHTree.FromBMesh(bm)
    checks.append(dict(check='closed_positive',orientation=name,passed=all(e.is_manifold for e in bm.edges) and bm.calc_volume(signed=True)>0))
    bm.free();uv=mesh.uv_layers.active
    bad=0
    for tri in mesh.loop_triangles:
        p=[Vector(uv.data[i].uv) for i in tri.loops]
        if abs((p[1]-p[0]).cross(p[2]-p[0]))<1e-13:bad+=1
    checks.append(dict(check='UVs',orientation=name,passed=bad==0,triangles=len(mesh.loop_triangles)))
    axis=Vector((direction[0],-direction[2],direction[1]));u=axis.cross(Vector((0,0,1))).normalized();v=axis.cross(u)
    for j in range(48):
        d=u*math.cos(j*math.tau/48)+v*math.sin(j*math.tau/48)
        hit,normal,_,distance=tree.ray_cast(Vector((0,0,0)),d,.025)
        checks.append(dict(check='unobstructed_bore',orientation=name,angle=j,passed=hit is not None and .01258<distance<.01272 and normal.dot(d)<-.98,distance=distance))
    hit,normal,_,_=tree.ray_cast(Vector((.010,0,.055)),Vector((0,0,-1)),.012)
    checks.append(dict(check='ceiling_seat',orientation=name,passed=hit is not None and abs(hit.z-.05)<1e-6 and normal.z>.99))
report=dict(evidence_class='INERT',checks=checks,failures=[c for c in checks if not c['passed']],scope='Analytic hanger prototype only; no full-world/runtime acceptance.')
(OUT/'stock_prototype.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'stock_prototype.blend'))
print('STOCK PROTOTYPE',len(checks),'checks',len(report['failures']),'failures')
if report['failures']:raise RuntimeError(str(report['failures'][:3]))
