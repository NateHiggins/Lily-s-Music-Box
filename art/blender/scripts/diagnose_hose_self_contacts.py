"""INERT classification of native crossing pairs in a retained deformed solid."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import os
import bpy
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
SOURCE=Path(os.environ['ORISON_HOSE_DEFORMED_BLEND']).resolve()
OUT=Path(os.environ['ORISON_HOSE_SELF_OUT']).resolve()
assert SOURCE.is_relative_to(ROOT/'tmp') and OUT.is_relative_to(ROOT/'tmp')
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
obj=bpy.data.objects['Capacity study hose']
names={group.index:int(group.name.removeprefix('HoseRing')) for group in obj.vertex_groups}
rings=[names[next(group.group for group in vertex.groups if group.weight>1e-6)] for vertex in obj.data.vertices]
vertices=[vertex.co.copy() for vertex in obj.data.vertices]
faces=[tuple(polygon.vertices) for polygon in obj.data.polygons]
sets=[set(face) for face in faces]
tree=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
histogram=Counter();local=Counter();distant=Counter();pairs=0
for a,b in tree.overlap(tree):
    if a>=b or sets[a].intersection(sets[b]):continue
    ra=[rings[index] for index in faces[a]];rb=[rings[index] for index in faces[b]]
    separation=max(min(ra)-max(rb),min(rb)-max(ra),0)
    histogram[separation]+=1;pairs+=1
    if separation<=3:local[min(ra+rb)]+=1
    else:distant[(min(ra),min(rb))]+=1
report={'evidence_class':'INERT','scope':'Native crossing classification only. No self-contact handling or runtime acceptance.',
        'pairs':pairs,'ring_separation_histogram':dict(sorted(histogram.items())),
        'local_pairs_separation_le_3':sum(count for distance,count in histogram.items() if distance<=3),
        'distant_pairs_separation_gt_3':sum(count for distance,count in histogram.items() if distance>3),
        'worst_local_rings':local.most_common(20),'worst_distant_ring_pairs':distant.most_common(20),
        'source_bindings':{path.relative_to(ROOT).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in [SOURCE,Path(__file__)]}}
(OUT/'crossing_classification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
print('HOSE CROSSING CLASSIFICATION',json.dumps({k:v for k,v in report.items() if k not in ['ring_separation_histogram','source_bindings']}))
