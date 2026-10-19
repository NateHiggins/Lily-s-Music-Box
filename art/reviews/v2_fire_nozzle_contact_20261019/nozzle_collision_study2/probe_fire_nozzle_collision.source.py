"""Temporary native collision simplification study, no canonical publication.
Full rendering meshes stay untouched. Compare both directions on vertices,
edge midpoints and triangle centroids; preserve native positive bores/caps.
"""
from pathlib import Path
import bpy,bmesh,json,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'tmp/v2-fire-hand-20261019/nozzle_collision_study2';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
with bpy.data.libraries.load(str(ROOT/'art/blender/fire_nozzle_joint.blend'),link=False) as (available,loaded):
    loaded.objects=['NozzleNut_Editable']
source=loaded.objects[0];assert source is not None;bpy.context.collection.objects.link(source)
bm=bmesh.new();bm.from_mesh(source.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(source.data);bm.free()
def tree(obj):return BVHTree.FromPolygons([v.co for v in obj.data.vertices],[list(p.vertices) for p in obj.data.polygons])
original=tree(source)
def samples(obj):
    for v in obj.data.vertices:yield v.co
    for e in obj.data.edges:yield sum((obj.data.vertices[i].co for i in e.vertices),Vector())*.5
    for f in obj.data.polygons:yield sum((obj.data.vertices[i].co for i in f.vertices),Vector())/len(f.vertices)
def deviation(obj,target):return max(target.find_nearest(p)[3] for p in samples(obj))
results=[]
for ratio in [.12,.125,.15]:
    obj=source.copy();obj.data=source.data.copy();bpy.context.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Collision-only reduction','DECIMATE');mod.ratio=ratio;mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(not e.is_manifold for e in bm.edges);volume=bm.calc_volume(signed=True);bm.free()
    reduced=tree(obj);a=deviation(source,reduced);c=deviation(obj,original)
    row=dict(ratio=ratio,triangles=len(obj.data.polygons),vertices=len(obj.data.vertices),nonmanifold_edges=bad,volume_m3=volume,source_to_reduced_m=a,reduced_to_source_m=c)
    print('NOZZLE COLLISION STUDY',json.dumps(row),flush=True);results.append(row)
    (OUT/f'ratio_{ratio}.json').write_text(json.dumps(dict(vertices=[[v.co.x,v.co.z,-v.co.y] for v in obj.data.vertices],indices=[i for f in obj.data.polygons for i in f.vertices]),separators=(',',':'))+'\n')
    bpy.data.objects.remove(obj,do_unlink=True)
(OUT/'study.json').write_text(json.dumps(results,indent=2)+'\n')
