"""Check acoustic route samples against unchanged shipping pipe triangles.

No model or export is written. This tests radial pipe-wall presence, not steam
performance, global source ownership, collision or human listening acceptance.
"""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
source=ROOT/'game/data/orison_v2/acoustic_heating.json'
data=json.loads(source.read_text(encoding='utf-8'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
assets=['game/assets/props/heating_distribution.glb','game/assets/props/boiler_pipework.glb']
for name in assets:bpy.ops.import_scene.gltf(filepath=str(ROOT/name))
trees=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH':continue
    mesh=obj.data;mesh.calc_loop_triangles()
    trees.append(BVHTree.FromPolygons([obj.matrix_world@v.co for v in mesh.vertices],
                 [tuple(t.vertices) for t in mesh.loop_triangles],all_triangles=True))
cv=lambda p:Vector((p[0],-p[2],p[1]))
checks=[];failures=[];count=0
for route in data['routes']:
    # Receiver cavities have rectangular walls; they are checked against their
    # source volume by the builder. This survey concerns cylindrical stock.
    if route['owner']=='HeatingDistribution/Heating_SHAFT':
        a,b=route['points_local_godot'][0],route['points_local_godot'][-1]
        if abs(a[0]-b[0])+abs(a[2]-b[2])>1e-6:continue
    points=route['points_local_godot']
    if route['owner']=='BoilerPipework':points=points[:-2]
    failed=[];samples=0
    for index,(left,right) in enumerate(zip(points,points[1:])):
        a,b=cv(left),cv(right);delta=b-a;length=delta.length
        if length<1e-7:continue
        axis=delta/length
        u=axis.cross(Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0))).normalized();v=axis.cross(u)
        # Exclude fitting mouths; test interior stations along every straight
        # and actual sampled bend, never the unrounded control polygon.
        steps=max(1,math.ceil(length/.30))
        for step in range(steps):
            point=a+delta*((step+.5)/steps);hits=0;distances=[]
            for side in range(8):
                angle=side*math.tau/8;direction=u*math.cos(angle)+v*math.sin(angle)
                found=[t.ray_cast(point,direction,.12)[3] for t in trees]
                values=[float(n) for n in found if n is not None]
                d=min(values) if values else None;distances.append(d)
                low,high=(.052,.092) if route['owner']=='BoilerPipework' else (.016,.044)
                if d is not None and low<=d<=high:hits+=1
            # Tee mouths can remove several radial wall hits at a junction.
            if hits<4:failed.append(dict(segment=index,step=step,point=list(point),radial_hits=hits,distances=distances))
            samples+=1
    row=dict(start=route['start'],end=route['end'],samples=samples,failures=len(failed))
    checks.append(row);count+=samples
    failures.extend(dict(route=row,**item) for item in failed)
result=dict(evidence_class='INERT',scope='Actual unchanged shipping triangle radial-presence survey only; not lumen continuity, runtime, listening or visual acceptance.',
            source_sha256_lf=hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
            assets={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in assets},
            samples=count,checks=checks,failures=failures)
args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('HEATING ACOUSTIC NATIVE SURVEY',count,'samples',len(failures),'failures',flush=True)
if failures:raise RuntimeError('Acoustic centreline differs from installed native pipe stock')
