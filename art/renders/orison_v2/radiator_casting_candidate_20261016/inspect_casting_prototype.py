from pathlib import Path
import bpy,bmesh,json,hashlib,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path.cwd();OUT=ROOT/'tmp/v2-radiator-next-20261016';native=OUT/'radiator_casting_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(native))
body=bpy.data.objects['CastSection'];mesh=body.data
bm=bmesh.new();bm.from_mesh(mesh);bvh=BVHTree.FromBMesh(bm)
checks=[]
def check(ok,label):checks.append({'ok':bool(ok),'label':label})
def clear(a,b,label):
    a,b=Vector(a),Vector(b);delta=b-a
    check(bvh.ray_cast(a,delta.normalized(),delta.length)[0] is None,label)
check(all(e.is_manifold for e in bm.edges),'saved source is closed manifold')
check(bm.calc_volume(signed=True)>0,'saved casting has positive solid volume')
for height in [.085,.615]:
    clear((-.07,.055,height),(.07,.055,height),'actual nipple through-bore '+str(height))
    clear((0,-.075,height),(0,.075,height),'connected header waterway '+str(height))
    for side in [-1,1]:
        for i in range(16):
            angle=math.tau*i/16;origin=Vector((side*.07,.055+.023*math.cos(angle),height+.023*math.sin(angle)))
            hit,normal,index,distance=bvh.ray_cast(origin,Vector((-side,0,0)),.14)
            check(hit is not None and abs(distance-.024)<.001,'annular nipple seat '+str((height,side,i)))
for cy in [-.075,0,.075]:
    clear((0,cy,.1),(0,cy,.60),'continuous vertical waterway '+str(cy))
    hit,normal,index,distance=bvh.ray_cast(Vector((0,cy,.72)),Vector((0,0,-1)),.1)
    check(hit is not None and abs(distance-.05)<.001 and normal.z>.1,'closed outward crown '+str(cy))
bm.free();mesh.calc_loop_triangles();uv=mesh.uv_layers.active.data;bad=[]
for tri in mesh.loop_triangles:
    a,b,c=[mesh.vertices[i].co for i in tri.vertices]
    if (b-a).cross(c-a).length_squared<=1e-18:continue
    a,b,c=[uv[i].uv for i in tri.loops]
    if abs((b-a).cross(c-a))<=1e-12:bad.append(tri.index)
check(not bad,'saved native metre charts have no meaningful collapsed UVs')
report={'evidence_class':'INERT','scope':'Independent saved-native geometry and bore checks only; no installed fit, runtime or human acceptance.','blend_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'inspection_recipe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'checks':checks,'failures':[r['label'] for r in checks if not r['ok']]}
(OUT/'bore_inspection.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'checks':len(checks),'failures':report['failures']}))
if report['failures']:raise RuntimeError('Saved native inspection failed')
