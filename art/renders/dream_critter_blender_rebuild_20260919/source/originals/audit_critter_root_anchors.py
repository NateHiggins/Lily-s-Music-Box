"""Source-only manifest-anchor/actual evaluated root-group correspondence."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

parser=argparse.ArgumentParser(allow_abbrev=False)
parser.add_argument('--blend',required=True,type=Path)
parser.add_argument('--manifest',required=True,type=Path)
parser.add_argument('--out',required=True,type=Path)
parser.add_argument('--checker',required=True,type=Path)
parser.add_argument('--count',required=True,type=int)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
spec=importlib.util.spec_from_file_location('checker',str(args.checker))
checker=importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
path,before,c,objects,rig=checker.load_source(args.blend)
manifest=json.loads(args.manifest.read_text())
anchors=manifest['cilium_anchors']
expected={0:8,1:12,2:5,4:12,6:12,7:6,8:36,10:1,11:12,12:2,15:12}
assert args.count==expected[c['species_id']] and manifest['species_id']==c['species_id']
assert len(anchors)==19 and all(len(row)==args.count for row in anchors)
skin=objects['Skin']
weights=[]
for index in range(args.count):
    group=skin.vertex_groups['cilium_%d_root'%index]
    values=[next((g.weight for g in v.groups if g.group==group.index),0.) for v in skin.data.vertices]
    assert sum(values)>0
    weights.append(values)
bindings={}
for loop in skin.data.loops:
    x,y=skin.data.uv_layers['AnatomyBinding'].data[loop.index].uv
    binding=(float(x),1.-float(y)) # Same V convention as glTF TEXCOORD_1.
    if loop.vertex_index in bindings: assert bindings[loop.vertex_index]==binding
    bindings[loop.vertex_index]=binding
def valid_role(identifier):
    if abs(identifier-round(identifier))>1e-6: return False
    kind=c['species_id']
    if kind==0: return -9<=identifier<=-1
    if kind==1: return -13<=identifier<=4
    if kind==2: return -6<=identifier<=7 or identifier in (-20,-21)
    return identifier==-1 or -1-args.count<=identifier<=-2
# These three explicit source contracts keep semantic ids at welded zero-weight
# rings and include positive prop/leg roles and separate negative jaw roles.
invalid_zero=[index for index,(identifier,weight) in bindings.items() if weight<=1e-7 and not valid_role(identifier)]
invalid_positive=[index for index,(identifier,weight) in bindings.items() if weight>1e-7 and not valid_role(identifier)]
records=[]
for pose_index,pose in enumerate(c['poses']):
    checker.apply_pose(c,objects,rig,pose)
    geometry=checker.evaluated_geometry(skin,bpy.context.evaluated_depsgraph_get())
    for index,values in enumerate(weights):
        centroid=sum((p*w for p,w in zip(geometry['points'],values)),Vector())/sum(values)
        centroid=Vector((centroid.x,centroid.z,-centroid.y))
        claimed=Vector(anchors[pose_index][index])
        records.append({'pose':pose['name'],'index':index,'claimed_godot':list(claimed),
                        'root_weighted_centroid_godot':list(centroid),'deviation':(claimed-centroid).length})
maximum=max(records,key=lambda r:r['deviation'])
result={'schema':'dream_critter_cilium_anchor_audit.v1','evidence_class':'INERT',
    'blend_sha256':before,'manifest_sha256':checker.sha256(args.manifest),
    'checker_sha256':checker.sha256(checker.__file__),'script_sha256':checker.sha256(__file__),
    'passed':maximum['deviation']<=1e-6 and not invalid_zero and not invalid_positive,'max_deviation':maximum,'records':records,'checked_anchor_states':len(records),
    'uv1':{'vertices':len(bindings),'invalid_zero_weight_ids':invalid_zero,'invalid_positive_bindings':invalid_positive},
    'source_unchanged':checker.sha256(path)==before,
    'limitations':['Weighted semantic root-group centroid correspondence only; native10/11/12 collapsed branch fan and rendered surface remain separate checks.',
                   'Coordinates are normalized source-template units, not final controller dimensions.']}
checker.write_report(args.out,result)
print('[CILIUM ANCHORS]',len(records),'max_deviation',maximum['deviation'],'pose',maximum['pose'],'bundle',maximum['index'])

raise SystemExit(0 if result['passed'] and result['source_unchanged'] else 1)
